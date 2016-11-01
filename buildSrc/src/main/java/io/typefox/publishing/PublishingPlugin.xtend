/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import org.gradle.api.GradleScriptException
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.artifacts.ConfigurablePublishArtifact
import org.gradle.api.publish.PublishingExtension
import org.gradle.api.publish.maven.MavenPublication
import org.gradle.api.publish.maven.tasks.GenerateMavenPom
import org.gradle.api.publish.maven.tasks.PublishToMavenRepository
import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Exec
import org.gradle.plugins.signing.SigningExtension

class PublishingPlugin implements Plugin<Project> {
	
	val classifiersExtensions = #[null -> 'jar', 'sources' -> 'jar', 'javadoc' -> 'jar', null -> 'pom']
	
	extension Project project
	PublishingPluginExtension osspub
	
	override apply(Project project) {
		project.apply(#{'plugin' -> 'signing'})
		project.apply(#{'plugin' -> 'maven-publish'})
		this.project = project
		this.osspub = project.extensions.create('osspub', PublishingPluginExtension)
		project.afterEvaluate[
			configure()
		]
	}
	
	private def void configure() {
		// Configure version of projects to publish
		if (hasProperty('publish.version'))
			osspub.version = property('publish.version') as String
		else if (hasProperty('PUBLISH_VERSION'))
			osspub.version = property('PUBLISH_VERSION') as String
		else if (osspub.version.nullOrEmpty)
			throw new GradleScriptException('The version to be published has to be set with -Ppublish.version=<version>', null)
		
		// Configure signing credentials
		if (!hasProperty('signing.secretKeyRingFile') && hasProperty('SIGNING_SECRETKEYRINGFILE'))
			ext.set('signing.secretKeyRingFile', property('SIGNING_SECRETKEYRINGFILE'))
		if (!hasProperty('signing.keyId') && hasProperty('SIGNING_KEYID'))
			ext.set('signing.keyId', property('SIGNING_KEYID'))
		if (!hasProperty('signing.password') && hasProperty('SIGNING_PASSWORD'))
			ext.set('signing.password', property('SIGNING_PASSWORD'))
		if (hasProperty('signing.skip'))
			osspub.doSigning = property('signing.skip') != 'true'
		else if (hasProperty('SIGNING_SKIP'))
			osspub.doSigning = property('SIGNING_SKIP') != 'true'
		if (hasProperty('jar.signing'))
			osspub.doJarSigning = property('jar.signing') == 'true'
		else if (hasProperty('JAR_SIGNING'))
			osspub.doJarSigning = property('JAR_SIGNING') == 'true'
		
		// Configure remote repositories
		if (!hasProperty('publishing.userName') && hasProperty('PUBLISHING_USERNAME'))
			ext.set('publishing.userName', property('PUBLISHING_USERNAME'))
		if (!hasProperty('publishing.password') && hasProperty('PUBLISHING_PASSWORD'))
			ext.set('publishing.password', property('PUBLISHING_PASSWORD'))
		val isSnapshot = osspub.version.endsWith('-SNAPSHOT')
		publishing.repositories [
			maven [
				name = osspub.repositoryName
				if (isSnapshot)
					url = osspub.snapshotUrl
				else
					url = osspub.stagingUrl
				if (findProperty('publishing.userName') != null && findProperty('publishing.password') != null) {
					credentials [
						username = property('publishing.userName') as String
						password = property('publishing.password') as String
					]
				}
			]
		]
		
		// Create separate configurations for each source repository
		for (pubProject : osspub.projects) {
			if (pubProject.name.nullOrEmpty)
				throw new GradleScriptException('Project name must not be undefined.', null)
			val dependenciesConfig = configurations.create('''dependencies«pubProject.name»''')
			val archivesConfig = configurations.create('''archives«pubProject.name»''')
			val signaturesConfig = configurations.create('''signatures«pubProject.name»''')
			
			// Step 1: Specify dependencies to artifacts
			for (pubArtifact : pubProject.artifacts) {
				if (pubArtifact.name.nullOrEmpty)
					throw new GradleScriptException('''Artifact name must not be undefined (project: «pubProject.name»).''', null)
				classifiersExtensions.filter[!pubArtifact.excludes(it)].forEach [ cePair |
					dependencies.add(dependenciesConfig.name, #{
						'group' -> pubArtifact.group,
						'name' -> pubArtifact.name,
						'version' -> osspub.version,
						'classifier' -> cePair.key,
						'ext' -> cePair.value
					})
				]
			}
			
			// Step 2: Copy the dependencies to the local build folder
			val archivesCopyTask = task(#{'type' -> Copy}, '''copy«pubProject.name»''') => [ task |
				val it = task as Copy
				description = '''Copy the built artifacts of «pubProject.name» into the build folder'''
				from = dependenciesConfig
				into = '''«buildDir»/artifacts'''
				for (pubArtifact : pubProject.artifacts) {
					include('''**/«pubArtifact.name»-«osspub.version»*.jar''')
					include('''**/«pubArtifact.name»-«osspub.version».pom''')
				}
			]
		
			// Step 3: Send the artifacts to the JAR signing service
			if (osspub.doJarSigning) {
				task(#{'type' -> Exec}, '''sign«pubProject.name»Jars''') => [ task |
					val it = task as Exec
					description = '''Send the artifacts of «pubProject.name» to the JAR signing service'''
					group = 'Signing'
					dependsOn(archivesCopyTask)
					executable = './jar-sign.sh'
					args(pubProject.artifacts.map[pubArtifact | '''«pubArtifact.name»-«osspub.version».jar''' ])
					for (pubArtifact : pubProject.artifacts) {
						inputs.file(pubArtifact.getFileName(null, 'jar', 'artifacts'))
						outputs.file(pubArtifact.getFileName(null, 'jar', 'signedArtifacts'))
					}
				]
			}
		
			for (pubArtifact : pubProject.artifacts) {
				classifiersExtensions.filter[!pubArtifact.excludes(it)].forEach [ cePair |
					val archiveFile = file(pubArtifact.getFileName(cePair.key, cePair.value, null))
					artifacts.add(archivesConfig.name, archiveFile) => [ a |
						val it = a as ConfigurablePublishArtifact
						name = pubArtifact.name
						classifier = cePair.key
						builtBy(archivesCopyTask)
					]
				]
			}
			
			// Step 4: Sign the local artifacts with a separate signature file
			if (osspub.doSigning) {
				signing.sign(archivesConfig)
				val signTask = tasks.getByName('''signArchives«pubProject.name»''')
		
				for (pubArtifact : pubProject.artifacts) {
					classifiersExtensions.filter[!pubArtifact.excludes(it)].forEach [ cePair |
						val signatureFile = file(pubArtifact.getFileName(cePair.key, cePair.value, null) + '.asc')
						signTask.outputs.file(signatureFile)
						artifacts.add(signaturesConfig.name, signatureFile) => [ a |
							val it = a as ConfigurablePublishArtifact
							name = pubArtifact.name
							classifier = cePair.key
							extension = cePair.value + '.asc'
							builtBy(signTask)
						]
					]
				}
			}
		
			// Step 5: Create a publication for each project containing all artifacts and their signatures
			for (pubArtifact : pubProject.artifacts) {
				val publicationName = pubArtifact.publicationName
				publishing.publications.create(publicationName, MavenPublication) => [ publication |
					publication.groupId = pubArtifact.group
					publication.artifactId = pubArtifact.name
					publication.version = property('publish.version') as String
		
					archivesConfig.artifacts.filter[name == pubArtifact.name && extension != 'pom'].forEach[
						publication.artifact(it)
					]
					if (osspub.doSigning) {
						signaturesConfig.artifacts.filter[name == pubArtifact.name].forEach[
							publication.artifact(it)
						]
					}
				]
				
				task(#{'type' -> Copy}, '''copy«publicationName.toFirstUpper»Pom''') => [ task |
					val it = task as Copy
					description = '''Copy the POM file for «pubArtifact.name» to make it consumable by the maven-publish plugin'''
					from = pubArtifact.getFileName(null, 'pom', null)
					into = '''«buildDir»/publications/«publicationName»'''
					rename('.*', 'pom-default.xml')
					if (osspub.doJarSigning)
						dependsOn('''sign«pubProject.name»Jars''')
					else
						dependsOn(archivesCopyTask)
				]
			}
			
			task('''publish«pubProject.name»''') => [
				group = 'Publishing'
				description = '''Publishes all «pubProject.name» artifacts.'''
				for (artifact : pubProject.artifacts) {
					dependsOn('''publish«artifact.publicationName.toFirstUpper»PublicationTo«osspub.repositoryName.toFirstUpper»Repository''')
				}
			]
		}
		
		tasks.withType(GenerateMavenPom) [
			enabled = false
		]
		
		tasks.withType(PublishToMavenRepository) [
			dependsOn('''copy«publication.name.toFirstUpper»Pom''')
		]
	}
	
	private def String getFileName(PublishingArtifact pubArtifact, String classifierName, String extensionName,
			String artifactsDir) {
		'''«buildDir»/«artifactsDir ?: (
			if (osspub.doJarSigning && classifierName === null && extensionName == 'jar')
				'signedArtifacts'
			else
				'artifacts'
		)»/«pubArtifact.name»-«osspub.version»«IF classifierName !== null»-«classifierName»«ENDIF».«extensionName»'''
	}
	
	private def String getPublicationName(PublishingArtifact pubArtifact) {
		pubArtifact.name.replaceAll('\\.|-', '')
	}
	
	private def boolean excludes(PublishingArtifact pubArtifact, Pair<String, String> cePair) {
		pubArtifact.excludedClassifiers.contains(cePair.key) || pubArtifact.excludedExtensions.contains(cePair.value)
	}
	
	private def ext() {
		project.extensions.extraProperties
	}
	
	private def publishing() {
		project.extensions.getByName('publishing') as PublishingExtension
	}
	
	private def signing() {
		project.extensions.getByName('signing') as SigningExtension
	}
	
}