/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import com.google.common.io.Files
import java.io.File
import java.nio.charset.Charset
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.gradle.api.GradleScriptException
import org.gradle.api.Project
import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.bundling.Zip
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
		val cleanResultTask = task(#{'type' -> Delete}, '''cleanBuildResult''') => [ task |
			val it = task as Delete
			delete(file('''«rootDir»/build-result'''))
		]
		tasks.findByName('clean').dependsOn(cleanResultTask)
		
		val copyEclipsePublisherTask = task(#{'type' -> Copy}, '''copyEclipsePublisherScripts''') => [ task |
			val it = task as Copy
			group = 'Eclipse'
			description = 'Copy the publisher scripts required for Eclipse publishing to the build result directory'
			from('eclipse')
			into('''«rootDir»/build-result''')
		]
		
		for (repository : osspub.p2Repositories) {
			if (repository.name.nullOrEmpty)
				throw new GradleScriptException('Repository name must be defined.', null)
			if (repository.url.nullOrEmpty)
				throw new GradleScriptException('Repository URL must be defined.', null)
			val repoName = repository.name
			
			val downloadP2Task = task(#{'type' -> Download}, '''download«repoName»P2Repository''') => [ task |
				val it = task as Download
				group = 'P2'
				description = '''Download the zipped P2 repository for «repoName»'''
				src(repository.url)
	    		dest('''«buildDir»/p2-«repoName.toLowerCase»/repository.zip''')
			]
			
			val unzipP2Task = task(#{'type' -> Copy}, '''unzip«repoName»P2Repository''') => [ task |
				val it = task as Copy
				group = 'P2'
				description = '''Unzip the P2 repository for «repoName»'''
				dependsOn(downloadP2Task)
				from(zipTree('''«buildDir»/p2-«repoName.toLowerCase»/repository.zip'''))
				into('''«buildDir»/p2-«repoName.toLowerCase»/repository''')
			]
			
			if (osspub.signJars) {
				task(#{'type' -> JarSignTask}, '''sign«repoName»P2Plugins''') => [ task |
					val it = task as JarSignTask
					group = 'Signing'
					description = '''Send the plugins of the «repoName» P2 repository to the JAR signing service'''
					dependsOn(unzipP2Task)
					inputDir = file('''«buildDir»/p2-«repoName.toLowerCase»/repository/plugins''')
					outputDir = file('''«rootDir»/build-result/p2-«repoName.toLowerCase»/plugins''')
				]
				
				task(#{'type' -> JarSignTask}, '''sign«repoName»P2Features''') => [ task |
					val it = task as JarSignTask
					group = 'Signing'
					description = '''Send the features of the «repoName» P2 repository to the JAR signing service'''
					dependsOn(unzipP2Task)
					inputDir = file('''«buildDir»/p2-«repoName.toLowerCase»/repository/features''')
					outputDir = file('''«rootDir»/build-result/p2-«repoName.toLowerCase»/features''')
				]
			}
			
			val copyP2MetadataTask = task(#{'type' -> Copy}, '''copy«repoName»P2Metadata''') => [ task |
				val it = task as Copy
				group = 'P2'
				description = '''Copy the «repoName» P2 repository metadata to the build result directory'''
				dependsOn(unzipP2Task)
				from('''«buildDir»/p2-«repoName.toLowerCase»/repository''')
				into('''«rootDir»/build-result/p2-«repoName.toLowerCase»''')
				if (osspub.signJars)
					include('*')
			]
			
			val zipP2RepoTask = task(#{'type' -> Zip}, '''zip«repoName»P2Repository''') => [ task |
				val it = task as Zip
				group = 'P2'
				description = '''Create a zip file from the «repoName» P2 repository'''
				dependsOn(copyP2MetadataTask)
				if (osspub.signJars)
					dependsOn('''sign«repoName»P2Plugins''', '''sign«repoName»P2Features''')
				from('''«rootDir»/build-result/p2-«repoName.toLowerCase»''')
				destinationDir = file('''«rootDir»/build-result/downloads''')
				if (repository.group.nullOrEmpty)
					archiveName = '''«repoName.toLowerCase»-Update-«buildPrefix»«repository.buildTimestamp».zip'''
				else {
					val firstSegmentIndex = repository.group.indexOf('.')
					if (firstSegmentIndex < 0)
						archiveName = '''«repository.group»-Update-«buildPrefix»«repository.buildTimestamp».zip'''
					else
						archiveName = '''«repository.group.substring(firstSegmentIndex + 1).replace('.', '-')»-Update-«buildPrefix»«repository.buildTimestamp».zip'''
				}
			]
			
			if (!repository.referenceBundle.nullOrEmpty) {
				val generatePropertiesTask = task('''generateEclipse«repoName»PublisherProperties''') => [
					group = 'Eclipse'
					description = 'Generate properties files required by scripts for Eclipse publishing'
					dependsOn(copyEclipsePublisherTask, unzipP2Task)
					val promotePropertiesFile = file('''«rootDir»/build-result/promote.properties''')
					val publisherPropertiesFile = file('''«rootDir»/build-result/publisher.properties''')
					doLast[
						Files.write(generatePropoteProperties(repository), promotePropertiesFile, Charset.defaultCharset)
						Files.write(generatePublisherProperties(repository), publisherPropertiesFile, Charset.defaultCharset)
					]
					outputs.file(promotePropertiesFile)
					outputs.file(publisherPropertiesFile)
				]
				
				task('''publishEclipse«repoName»''') => [
					group = 'Eclipse'
					description = 'Set up the build result directory used for Eclipse publishing'
					dependsOn(zipP2RepoTask, generatePropertiesTask)
				]
			}
		}
	}
	
	private def generatePropoteProperties(P2Repository repository) '''
		java.home=«System.getenv('JAVA_HOME')»
		eclipse.home=«ECLIPSE_HOME»
		build.id=«buildPrefix»«repository.buildTimestamp»
		hudson.build.id=«System.getenv('BUILD_ID')»
	'''
	
	private def generatePublisherProperties(P2Repository repository) '''
		version=«mainVersion»
		scm.stream=«osspub.branch»
		packages.base=downloads
		tests.base=test-results
		group.owner=«repository.group»
		downloads.area=/home/data/httpd/download.eclipse.org/«repository.group?.replace('.', '/')»/
	'''
	
	private def getBuildPrefix() {
		if (osspub.version.endsWith('-SNAPSHOT'))
			'N'
		else if (osspub.version.split('\\.').length == 3)
			'R'
		else
			'S'
	}
	
	private def getBuildTimestamp(P2Repository repository) {
		if (!repository.referenceBundle.nullOrEmpty) {
			val referencePrefix = '''«repository.referenceBundle»_«mainVersion».«repository.timestampPrefix»'''
			val bundleDir = new File(buildDir, '''p2-«repository.name.toLowerCase»/repository/plugins''')
			val referenceBundleFile = bundleDir?.listFiles?.findFirst[
				name.startsWith(referencePrefix) && name.endsWith('.jar')
			]
			if (referenceBundleFile !== null) {
				val fileName = referenceBundleFile.name
				return fileName.substring(referencePrefix.length, fileName.length - '.jar'.length)
			}
		}
	}
	
	private def getMainVersion() {
		switch buildPrefix {
			case 'N': osspub.version.substring(0, osspub.version.indexOf('-'))
			case 'S': osspub.version.substring(0, osspub.version.lastIndexOf('.'))
			case 'R': osspub.version
		}
	}
	
}