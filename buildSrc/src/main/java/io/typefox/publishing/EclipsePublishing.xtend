/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import com.google.common.collect.AbstractIterator
import com.google.common.io.Files
import io.typefox.publishing.tasks.JarSignTask
import io.typefox.publishing.tasks.Pack200Task
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.FilenameFilter
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.Charset
import java.util.concurrent.Callable
import java.util.jar.JarFile
import java.util.jar.JarOutputStream
import java.util.zip.ZipEntry
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.gradle.api.GradleException
import org.gradle.api.InvalidUserDataException
import org.gradle.api.Project
import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.bundling.Zip
import org.tukaani.xz.LZMA2Options
import org.tukaani.xz.XZOutputStream
import org.w3c.dom.Document
import org.w3c.dom.Element
import pw.prok.download.Download

@FinalFieldsConstructor
class EclipsePublishing {
	
	static val ECLIPSE_HOME = '/opt/public/common/buckminster-4.3'
	
	val extension Project project
	val PublishingPluginExtension osspub
	
	def void configure() {
		configureTasks()
	}
	
	private def void configureTasks() {
		val copyEclipsePublisherTask = tasks.create('''copyEclipsePublisherScripts''', Copy) [
			group = 'Eclipse'
			description = 'Copy the publisher scripts required for Eclipse publishing to the build result directory'
			from = 'eclipse'
			into = '''«rootDir»/build-result'''
		]
		
		for (repository : osspub.p2Repositories) {
			if (repository.name.nullOrEmpty)
				throw new InvalidUserDataException('Repository name must be defined.')
			if (repository.url.nullOrEmpty)
				throw new InvalidUserDataException('Repository URL must be defined.')
			val repoName = repository.name
			
			val downloadP2Task = tasks.create('''download«repoName»P2Repository''', Download) [
				group = 'P2'
				description = '''Download the zipped P2 repository for «repoName»'''
				src(repository.url)
				dest('''«buildDir»/p2-«repoName.toLowerCase»/repository-unsigned.zip''')
			]
			
			val unzipP2Task = tasks.create('''unzip«repoName»P2Repository''', Copy) [
				group = 'P2'
				description = '''Unzip the P2 repository for «repoName»'''
				dependsOn(downloadP2Task)
				from = zipTree('''«buildDir»/p2-«repoName.toLowerCase»/repository-unsigned.zip''')
				into = '''«buildDir»/p2-«repoName.toLowerCase»/repository-unsigned'''
			]
			
			val FilenameFilter jarFilter = [ dir, name |
				name.endsWith('.jar')
			]
			val FilenameFilter namespaceFilter = [ dir, name |
				repository.namespaces.empty || repository.namespaces.exists[name.startsWith(it)]
			]
			val FilenameFilter nonSourceFilter = [ dir, name |
				!name.matches('.+\\.source_.+\\.jar')
			]
			if (osspub.packJars) {
				tasks.create('''repack«repoName»P2Plugins''', Pack200Task) [
					group = 'Build'
					description = '''Repacks the plugins of the «repoName» P2 repository with pack200'''
					dependsOn(unzipP2Task)
					from = files(listFiles(new File(buildDir, '''p2-«repoName.toLowerCase»/repository-unsigned/plugins'''),
							jarFilter && namespaceFilter && nonSourceFilter))
					repack = true
				]
			}
			
			if (osspub.signJars || osspub.packJars) {
				val signPluginsTask = if (osspub.signJars) tasks.create('''sign«repoName»P2Plugins''', JarSignTask) [
					group = 'Signing'
					description = '''Send the plugins of the «repoName» P2 repository to the JAR signing service'''
					dependsOn(unzipP2Task)
					from = files(listFiles(new File(buildDir, '''p2-«repoName.toLowerCase»/repository-unsigned/plugins'''),
							jarFilter && namespaceFilter))
					outputDir = file('''«rootDir»/build-result/p2.repository/plugins''')
					if (osspub.packJars) {
						dependsOn('''repack«repoName»P2Plugins''')
					} else {
						alternateSourceDir = MavenPublishing.getArtifactsDir(project)
						alternateTargetDir = MavenPublishing.getSignedArtifactsDir(project)
						failOnInconsistency = osspub.failOnInconsistentJars
						acceptedDifferingJars += repository.acceptedDifferingJars
					}
				]
				
				val packPluginsTask = if (osspub.packJars) tasks.create('''pack«repoName»P2Plugins''', Pack200Task) [
					group = 'Build'
					description = '''Packs the plugins of the «repoName» P2 repository with pack200'''
					if (osspub.signJars) {
						dependsOn(signPluginsTask)
						from = files(listFiles(new File(rootDir, '''build-result/p2.repository/plugins'''),
								jarFilter && namespaceFilter && nonSourceFilter))
					} else {
						dependsOn('''repack«repoName»P2Plugins''')
						from = files(listFiles(new File(buildDir, '''p2-«repoName.toLowerCase»/repository-unsigned/plugins'''),
								jarFilter && namespaceFilter && nonSourceFilter))
					}
					outputDir = file('''«rootDir»/build-result/p2.repository/plugins''')
				]
				
				val signFeaturesTask = if (osspub.signJars) tasks.create('''sign«repoName»P2Features''', JarSignTask) [
					group = 'Signing'
					description = '''Send the features of the «repoName» P2 repository to the JAR signing service'''
					dependsOn(unzipP2Task)
					from = files(listFiles(new File(buildDir, '''p2-«repoName.toLowerCase»/repository-unsigned/features'''),
							jarFilter && namespaceFilter))
					outputDir = file('''«rootDir»/build-result/p2.repository/features''')
				]
				
				tasks.create('''update«repoName»ArtifactsChecksum''') => [
					if (osspub.signJars) 
						dependsOn(signPluginsTask, signFeaturesTask)
					if (osspub.packJars) 
						dependsOn(packPluginsTask)
					doLast [
						updateArtifactsXml('''«buildDir»/p2-«repoName.toLowerCase»/repository-unsigned''',
							'''«rootDir»/build-result/p2.repository''', repository)
					]
				]
			}
			
			val copyP2MetadataTask = tasks.create('''copy«repoName»P2Metadata''', Copy) [
				group = 'P2'
				description = '''Copy the «repoName» P2 repository metadata to the build result directory'''
				dependsOn(unzipP2Task)
				if (osspub.packJars)
					dependsOn('''repack«repoName»P2Plugins''')
				from = '''«buildDir»/p2-«repoName.toLowerCase»/repository-unsigned'''
				into = '''«rootDir»/build-result/p2.repository'''
				if (osspub.signJars || osspub.packJars)
					exclude('**/artifacts.*')
				if (osspub.signJars) {
					for (namespace : repository.namespaces) {
						exclude('''**/«namespace»*.jar''')
					}
				}
			]
			
			val zipP2RepoTask = tasks.create('''zip«repoName»P2Repository''', Zip) [
				group = 'P2'
				description = '''Create a zip file from the «repoName» P2 repository'''
				dependsOn(copyP2MetadataTask)
				if (osspub.signJars || osspub.packJars)
					dependsOn('''update«repoName»ArtifactsChecksum''')
				from = '''«rootDir»/build-result/p2.repository'''
				destinationDir = file('''«rootDir»/build-result/downloads''')
				doFirst[ task2 |
					val it = task2 as Zip
					if (repository.group.nullOrEmpty)
						archiveName = '''«repoName.toLowerCase»-Update-«repository.buildQualifier».zip'''
					else {
						val firstSegmentIndex = repository.group.indexOf('.')
						if (firstSegmentIndex < 0)
							archiveName = '''«repository.group»-Update-«repository.buildQualifier».zip'''
						else
							archiveName = '''«repository.group.substring(firstSegmentIndex + 1).replace('.', '-')»-Update-«repository.buildQualifier».zip'''
					}
				]
			]
			
			if (!repository.referenceFeature.nullOrEmpty) {
				val generatePropertiesTask = tasks.create('''generateEclipse«repoName»PublisherProperties''') [
					group = 'Eclipse'
					description = 'Generate properties files required by scripts for Eclipse publishing'
					dependsOn(copyEclipsePublisherTask, unzipP2Task)
					val promotePropertiesFile = file('''«rootDir»/build-result/promote.properties''')
					val publisherPropertiesFile = file('''«rootDir»/build-result/publisher.properties''')
					doLast[
						Files.write(generatePromoteProperties(repository), promotePropertiesFile, Charset.defaultCharset)
						Files.write(generatePublisherProperties(repository), publisherPropertiesFile, Charset.defaultCharset)
					]
					outputs.file(promotePropertiesFile)
					outputs.file(publisherPropertiesFile)
				]
				
				tasks.create('''publishEclipse«repoName»''') [
					group = 'Eclipse'
					description = 'Set up the build result directory used for Eclipse publishing'
					dependsOn(zipP2RepoTask, generatePropertiesTask)
				]
			}
		}
	}
	
	private def Callable<File[]> listFiles(File dir, FilenameFilter filter) {
		[
			if (filter === null)
				dir.listFiles
			else
				dir.listFiles(filter)
		]
	}
	
	private def FilenameFilter &&(FilenameFilter f1, FilenameFilter f2) {
		[ dir, name |
			f1.accept(dir, name) && f2.accept(dir, name)
		]
	}
	
	private def generatePromoteProperties(P2Repository repository) '''
		java.home=«System.getenv('JAVA_HOME')»
		eclipse.home=«ECLIPSE_HOME»
		build.id=«buildPrefix»«repository.buildTimestamp»
		hudson.build.id=«System.getenv('BUILD_ID')»
	'''
	
	private def generatePublisherProperties(P2Repository repository) '''
		version=«osspub.baseVersion»
		scm.stream=«IF buildPrefix == 'R' && !osspub.version.endsWith('.0')»maintenance«ELSE»head«ENDIF»
		packages.base=downloads
		tests.base=test-results
		group.owner=«repository.group»
		downloads.area=/home/data/httpd/download.eclipse.org/«repository.deployPath ?: repository.group?.replace('.', '/')»/
	'''
	
	private def getBuildPrefix() {
		if (osspub.version.endsWith('-SNAPSHOT'))
			'N'
		else if (osspub.version.split('\\.').length == 3)
			'R'
		else
			'S'
	}
	
	private def String getBuildQualifier(P2Repository repository) {
		switch (buildPrefix) {
			case 'N': 'N'+buildPrefix+repository.buildTimestamp
			case 'S': osspub.version
			case 'R': osspub.version
		}
	}
	
	private def getBuildTimestamp(P2Repository repository) {
		if (!repository.referenceFeature.nullOrEmpty) {
			val referencePrefix = '''«repository.referenceFeature»_«osspub.baseVersion».'''
			val bundleDir = new File(buildDir, '''p2-«repository.name.toLowerCase»/repository-unsigned/features''')
			val FilenameFilter filter = [ dir, name |
				name.startsWith(referencePrefix) && name.endsWith('.jar')
			]
			val referenceFeatureFiles = bundleDir.listFiles(filter)
			if (referenceFeatureFiles.length > 0) {
				val fileName = referenceFeatureFiles.get(0).name
				val qualifier = fileName.substring(referencePrefix.length, fileName.length - '.jar'.length)
				val timestamp = new StringBuilder
				for (var i = 0; i < qualifier.length; i++) {
					val c = qualifier.charAt(i)
					if (Character.isDigit(c))
						timestamp.append(c)
				}
				return timestamp.toString
			}
		}
	}
	
	private def updateArtifactsXml(String sourceDir, String destDir, P2Repository repository) {
		var InputStream sourceStream
		var JarFile sourceJar
		var OutputStream targetStream
		var JarOutputStream targetJar
		var XZOutputStream targetXz
		try {
			val artifactsXmlFile = new File('''«sourceDir»/artifacts.xml''')
			val artifactsJarFile = new File('''«sourceDir»/artifacts.jar''')
			if (artifactsXmlFile.exists) {
				sourceStream = new FileInputStream(artifactsXmlFile)
			} else if (artifactsJarFile.exists) {
				sourceJar = new JarFile(artifactsJarFile)
				val artifactsEntry = sourceJar.getEntry('artifacts.xml')
				if (artifactsEntry === null)
					throw new GradleException('P2 repository: artifacts.jar does not contain artifacts.xml')
				sourceStream = sourceJar.getInputStream(artifactsEntry)
			} else {
				throw new GradleException('P2 repository does not contain artifacts.xml or artifacts.jar')
			}
			val builder = DocumentBuilderFactory.newInstance.newDocumentBuilder
			val document = builder.parse(sourceStream)
			postProcess(document, destDir, repository)
			
			val transformer = TransformerFactory.newInstance.newTransformer
			if (artifactsXmlFile.exists) {
				targetStream = new FileOutputStream('''«destDir»/artifacts.xml''')
				transformer.transform(new DOMSource(document), new StreamResult(targetStream))
			}
			
			if (artifactsJarFile.exists) {
				targetJar = new JarOutputStream(new FileOutputStream('''«destDir»/artifacts.jar'''))
				targetJar.putNextEntry(new ZipEntry('artifacts.xml'))
				transformer.transform(new DOMSource(document), new StreamResult(targetJar))
				targetJar.closeEntry()
			}
			
			val artifactsXmlXzFile = new File('''«sourceDir»/artifacts.xml.xz''')
			if (artifactsXmlXzFile.exists) {
				val options = new LZMA2Options
				targetXz = new XZOutputStream(new FileOutputStream('''«destDir»/artifacts.xml.xz'''), options)
				transformer.transform(new DOMSource(document), new StreamResult(targetXz))
			}
		} finally {
			try {
				targetXz?.close()
				targetJar?.close()
				targetStream?.close()
				sourceJar?.close()
				sourceStream?.close()
			} catch (IOException e) {}
		}
	}
	
	private def postProcess(Document document, String destDir, P2Repository repository) {
		val xmlRoot = document.documentElement
		if (xmlRoot.tagName == 'repository') {
			for (artifacts : xmlRoot.getElements('artifacts')) {
				for (artifact : artifacts.getElements('artifact')) {
					val id = artifact.getAttribute('id')
					val version = artifact.getAttribute('version')
					val classifier = artifact.getAttribute('classifier')
					if (repository.namespaces.empty || repository.namespaces.exists[id.startsWith(it)]) {
						val isPacked = osspub.packJars && classifier == 'osgi.bundle' && !id.endsWith('.source')
						for (properties : artifact.getElements('properties')) {
							for (property : properties.getElements('property')) {
								switch property.getAttribute('name') {
									case 'artifact.size': {
										val size = computeSize(destDir, id, version, classifier, 'jar')
										if (size !== null)
											property.setAttribute('value', size)
									}
									case 'download.size': {
										val size = computeSize(destDir, id, version, classifier, if (isPacked) 'jar.pack.gz' else 'jar')
										if (size !== null)
											property.setAttribute('value', size)
									}
									case 'download.md5': {
										val md5 = computeMd5Checksum(destDir, id, version, classifier, if (isPacked) 'jar.pack.gz' else 'jar')
										if (md5 !== null)
											property.setAttribute('value', md5)
									}
									case 'download.checksum.md5': {
										val md5 = computeMd5Checksum(destDir, id, version, classifier, if (isPacked) 'jar.pack.gz' else 'jar')
										if (md5 !== null)
											property.setAttribute('value', md5)
									}
									case 'download.checksum.sha-256': {
										val sha256 = computeSha256Checksum(destDir, id, version, classifier, if (isPacked) 'jar.pack.gz' else 'jar')
										if (sha256 !== null)
											property.setAttribute('value', sha256)
									}
								}
							}
							if (isPacked) {
								val format = document.createElement('property')
								format.setAttribute('name', 'format')
								format.setAttribute('value', 'packed')
								properties.appendChild(format)
								properties.setAttribute('size', Integer.toString(properties.getElements('property').size))
							}
						}
						if (isPacked && artifact.getElements('processing').empty) {
							val processing = document.createElement('processing')
							processing.setAttribute('size', '1')
							artifact.appendChild(processing)
							val step = document.createElement('step')
							step.setAttribute('id', 'org.eclipse.equinox.p2.processing.Pack200Unpacker')
							step.setAttribute('required', 'true')
							processing.appendChild(step)
						}
					}
				}
			}
		}
	}
	
	private def Iterable<Element> getElements(Element e, String name) {
		val nodeList = e.getElementsByTagName(name)
		return [
			new AbstractIterator<Element> {
				int i = 0
				override protected computeNext() {
					if (i < nodeList.length)
						return nodeList.item(i++) as Element
					else
						return endOfData
				}
			}
		]
	}
	
	private def computeSize(String dir, String id, String version, String classifier, String ext) {
		val path = switch classifier {
			case 'osgi.bundle': '''«dir»/plugins/«id»_«version».«ext»'''
			case 'org.eclipse.update.feature': '''«dir»/features/«id»_«version».«ext»'''
			default: ''
		}
		val file = new File(path)
		if (file.exists) {
			return Long.toString(file.length)
		}
	}
	
	private def computeMd5Checksum(String dir, String id, String version, String classifier, String ext) {
		val path = switch classifier {
			case 'osgi.bundle': '''«dir»/plugins/«id»_«version».«ext»'''
			case 'org.eclipse.update.feature': '''«dir»/features/«id»_«version».«ext»'''
			default: ''
		}
		val file = new File(path)
		if (file.exists) {
			val bytes = FileChecksums.getMd5Checksum(file)
			return FileChecksums.toString(bytes)
		}
	}
	
	private def computeSha256Checksum(String dir, String id, String version, String classifier, String ext) {
		val path = switch classifier {
			case 'osgi.bundle': '''«dir»/plugins/«id»_«version».«ext»'''
			case 'org.eclipse.update.feature': '''«dir»/features/«id»_«version».«ext»'''
			default: ''
		}
		val file = new File(path)
		if (file.exists) {
			val bytes = FileChecksums.getSha256Checksum(file)
			return FileChecksums.toString(bytes)
		}
	}
	
}