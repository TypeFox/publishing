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
import pw.prok.download.Download

@FinalFieldsConstructor
class EclipsePublishing {
	
	val extension Project project
	val PublishingPluginExtension osspub
	
	def void configure() {
		configureTasks()
	}
	
	private def void configureTasks() {
		if (osspub.p2Repository !== null) {
			val repository = osspub.p2Repository
			if (repository.name.nullOrEmpty)
				throw new GradleScriptException('Repository name must be defined.', null)
			if (repository.url.nullOrEmpty)
				throw new GradleScriptException('Repository URL must be defined.', null)
			
			val cleanResultTask = task(#{'type' -> Delete}, '''clean«repository.name»BuildResult''') => [ task |
				val it = task as Delete
				delete(file('''«rootDir»/build-result'''))
			]
			tasks.findByName('clean').dependsOn(cleanResultTask)
			
			val downloadP2Task = task(#{'type' -> Download}, '''download«repository.name»P2Repository''') => [ task |
				val it = task as Download
				group = 'P2'
				description = 'Download the zipped P2 repository'
				src(repository.url)
	    		dest('''«buildDir»/p2/repository.zip''')
			]
			
			val unzipP2Task = task(#{'type' -> Copy}, '''unzip«repository.name»P2Repository''') => [ task |
				val it = task as Copy
				group = 'P2'
				description = 'Unzip the P2 repository'
				dependsOn(downloadP2Task)
				from(zipTree('''«buildDir»/p2/repository.zip'''))
				into('''«buildDir»/p2/repository''')
			]
			
			if (osspub.signJars) {
				task(#{'type' -> JarSignTask}, '''sign«repository.name»P2Plugins''') => [ task |
					val it = task as JarSignTask
					group = 'Signing'
					description = 'Send the plugins of the P2 repository to the JAR signing service'
					dependsOn(unzipP2Task)
					inputDir = file('''«buildDir»/p2/repository/plugins''')
					outputDir = file('''«rootDir»/build-result/p2.repository/plugins''')
				]
				
				task(#{'type' -> JarSignTask}, '''sign«repository.name»P2Features''') => [ task |
					val it = task as JarSignTask
					group = 'Signing'
					description = 'Send the features of the P2 repository to the JAR signing service'
					dependsOn(unzipP2Task)
					inputDir = file('''«buildDir»/p2/repository/features''')
					outputDir = file('''«rootDir»/build-result/p2.repository/features''')
				]
			}
			
			val copyP2MetadataTask = task(#{'type' -> Copy}, '''copy«repository.name»P2Metadata''') => [ task |
				val it = task as Copy
				group = 'P2'
				description = 'Copy the P2 repository metadata to the build result directory'
				dependsOn(unzipP2Task)
				from('''«buildDir»/p2/repository''')
				into('''«rootDir»/build-result/p2.repository''')
				if (osspub.signJars)
					include('*')
			]
			
			val copyEclipsePublisherTask = task(#{'type' -> Copy}, '''copyEclipse«repository.name»PublisherScripts''') => [ task |
				val it = task as Copy
				group = 'Eclipse'
				description = 'Copy the publisher scripts required for Eclipse publishing to the build result directory'
				from('eclipse')
				into('''«rootDir»/build-result''')
			]
			
			val generatePropertiesTask = task('''generateEclipse«repository.name»PublisherProperties''') => [
				group = 'Eclipse'
				description = 'Generate properties files required by scripts for Eclipse publishing'
				dependsOn(copyEclipsePublisherTask)
				val promotePropertiesFile = file('''«rootDir»/build-result/promote.properties''')
				val publisherPropertiesFile = file('''«rootDir»/build-result/publisher.properties''')
				doLast[
					Files.write(generatePropoteProperties(repository), promotePropertiesFile, Charset.defaultCharset)
					Files.write(generatePublisherProperties(repository), publisherPropertiesFile, Charset.defaultCharset)
				]
				outputs.file(promotePropertiesFile)
				outputs.file(publisherPropertiesFile)
			]
			
			task('''publishEclipse«repository.name»''') => [
				group = 'Eclipse'
				description = 'Set up the build result directory used for Eclipse publishing'
				if (osspub.signJars)
					dependsOn('''sign«repository.name»P2Plugins''', '''sign«repository.name»P2Features''')
				dependsOn(copyP2MetadataTask, generatePropertiesTask)
			]
		}
	}
	
	private def generatePropoteProperties(P2Repository repository) '''
		java.home=«System.getenv('JAVA_HOME')»
		eclipse.home=«System.getenv('ECLIPSE_HOME')»
		build.id=«buildPrefix»«repository.buildTimestamp»
		hudson.build.id=«System.getenv('BUILD_ID')»
	'''
	
	private def generatePublisherProperties(P2Repository repository) '''
		version=«mainVersion»
		scm.stream=«osspub.branch»
		#packages.base=downloads
		#tests.base=test-results
		group.owner=«repository.group»
		downloads.area=/home/data/httpd/download.eclipse.org/«repository.group.replace('.', '/')»/
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
			val referencePrefix = repository.referenceBundle + '_' + mainVersion + '.v'
			val bundleDir = new File(buildDir, 'p2/repository/plugins')
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