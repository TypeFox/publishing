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
import org.apache.maven.settings.building.DefaultSettingsBuilderFactory
import org.apache.maven.settings.building.DefaultSettingsBuildingRequest
import org.apache.maven.settings.building.SettingsBuildingException
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.gradle.api.GradleException
import org.gradle.api.InvalidUserDataException
import org.gradle.api.Project
import org.gradle.api.artifacts.ConfigurablePublishArtifact
import org.gradle.api.artifacts.repositories.MavenArtifactRepository
import org.gradle.api.publish.PublishingExtension
import org.gradle.api.publish.maven.MavenPublication
import org.gradle.api.publish.maven.tasks.GenerateMavenPom
import org.gradle.api.publish.maven.tasks.PublishToMavenRepository
import org.gradle.api.tasks.Copy
import org.gradle.plugins.signing.SigningExtension
import org.sonatype.plexus.components.cipher.DefaultPlexusCipher
import org.sonatype.plexus.components.sec.dispatcher.DefaultSecDispatcher
import org.sonatype.plexus.components.sec.dispatcher.SecUtil

@FinalFieldsConstructor
class MavenPublishing {
	
	public static val CLASSIFIERS = #[null -> 'jar', 'sources' -> 'jar', 'javadoc' -> 'jar', null -> 'pom']
	
	static val LOCAL_REPO_NAME = 'local'
	
	static def getArtifactsDir(Project project) {
		new File(project.buildDir, 'artifacts')
	}
	
	static def getSignedArtifactsDir(Project project) {
		new File(project.buildDir, 'signedArtifacts')
	}
	
	val extension Project project
	val PublishingPluginExtension osspub
	
	def void configure() {
		configureRepositories()
		loadMavenSettings()
		configureTasks()
	}
	
	private def void configureRepositories() {
		val repoUsername = (findProperty('publishing.userName') ?: findProperty('PUBLISHING_USERNAME'))?.toString
		val repoPassword = (findProperty('publishing.password') ?: findProperty('PUBLISHING_PASSWORD'))?.toString
		val isSnapshot = osspub.version.endsWith('-SNAPSHOT')
		publishing.repositories [
			maven [
				val uploadRepo = osspub.mavenUploadRepository
				name = uploadRepo.name
				if (isSnapshot)
					url = uploadRepo.snapshotUrl
				else
					url = uploadRepo.stagingUrl
				if (repoUsername !== null && repoPassword !== null) {
					credentials [
						username = repoUsername
						password = repoPassword
					]
				}
			]
			maven [
				name = LOCAL_REPO_NAME
				url = '''file:«rootDir»/build-result/maven-repository'''
			]
		]
	}
	
	private def void configureTasks() {
		for (pubProject : osspub.projects) {
			if (pubProject.name.nullOrEmpty)
				throw new InvalidUserDataException('Project name must be defined.')
			val dependenciesConfig = configurations.create('''dependencies«pubProject.name»''')
			val archivesConfig = configurations.create('''archives«pubProject.name»''')
			val signaturesConfig = configurations.create('''signatures«pubProject.name»''')
			
			// Step 1: Specify dependencies to artifacts
			for (pubArtifact : pubProject.artifacts) {
				if (pubArtifact.name.nullOrEmpty)
					throw new InvalidUserDataException('''Artifact name must not be undefined (project: «pubProject.name»).''')
				CLASSIFIERS.filter[!pubArtifact.excludes(it)].forEach [ cePair |
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
			val archivesCopyTask = tasks.create('''copy«pubProject.name»''', Copy) [
				description = '''Copy the built artifacts of «pubProject.name» into the build folder'''
				from = dependenciesConfig
				into = project.artifactsDir
				for (pubArtifact : pubProject.artifacts) {
					include('''**/«pubArtifact.name»-«osspub.version»*.jar''')
					include('''**/«pubArtifact.name»-«osspub.version».pom''')
				}
			]
		
			// Step 3: Send the artifacts to the JAR signing service
			if (osspub.signJars) {
				tasks.create('''sign«pubProject.name»Jars''', JarSignTask) [
					group = 'Signing'
					description = '''Send the artifacts of «pubProject.name» to the JAR signing service'''
					dependsOn(archivesCopyTask)
					from = files(pubProject.artifacts.filter[!excludes(null -> 'jar')].map[ pubArtifact |
						'''«project.artifactsDir»/«pubArtifact.name»-«osspub.version».jar'''
					] + pubProject.artifacts.filter[!excludes('sources' -> 'jar')].map[ pubArtifact |
						'''«project.artifactsDir»/«pubArtifact.name»-«osspub.version»-sources.jar'''
					])
					outputDir = file('''«buildDir»/signedArtifacts''')
				]
			}
		
			for (pubArtifact : pubProject.artifacts) {
				CLASSIFIERS.filter[!pubArtifact.excludes(it)].forEach [ cePair |
					val archiveFile = file(pubArtifact.getFileName(cePair.key, cePair.value))
					artifacts.add(archivesConfig.name, archiveFile) => [ a |
						val it = a as ConfigurablePublishArtifact
						name = pubArtifact.name
						classifier = cePair.key
						builtBy(archivesCopyTask)
					]
				]
			}
			
			// Step 4: Sign the local artifacts with a separate signature file
			if (osspub.createSignatures) {
				signing.sign(archivesConfig)
				val signTask = tasks.getByName('''signArchives«pubProject.name»''')
		
				for (pubArtifact : pubProject.artifacts) {
					CLASSIFIERS.filter[!pubArtifact.excludes(it)].forEach [ cePair |
						val signatureFile = file(pubArtifact.getFileName(cePair.key, cePair.value) + '.asc')
						signTask.outputs.file(signatureFile)
						artifacts.add(signaturesConfig.name, signatureFile) => [ a |
							val it = a as ConfigurablePublishArtifact
							name = pubArtifact.name
							classifier = cePair.key
							extension = cePair.value + '.asc'
							builtBy(signTask)
						]
					]
					if (pubArtifact.isPomOnly) {
						// FIXME see explanation below
						val dummyFile = file('''«project.artifactsDir»/«pubArtifact.name».dummy''')
						tasks.create('''createDummyFor«pubArtifact.publicationName.toFirstUpper»''') [
							doLast [
								val content = '''
									This artifact is published using Gradle and the maven-publish plugin. We need
									to include a dummy artifact in order to prevent the maven-publish plugin from
									setting the signature file as main artifact, which would result in no
									signature being uploaded. This is a consequence of the lacking support for
									signing in maven-publish.
								'''
								Files.write(content, dummyFile, Charset.forName('UTF-8'))
							]
						]
						artifacts.add(signaturesConfig.name, dummyFile) => [ a |
							val it = a as ConfigurablePublishArtifact
							name = pubArtifact.name
							extension = 'dummy'
							builtBy(signTask)
						]
					}
				}
			}
			
			// Step 5: Create a publication for each project containing all artifacts and their signatures
			for (pubArtifact : pubProject.artifacts) {
				val publicationName = pubArtifact.publicationName
				publishing.publications.create(publicationName, MavenPublication) => [ publication |
					publication.groupId = pubArtifact.group
					publication.artifactId = pubArtifact.name
					publication.version = osspub.version
		
					archivesConfig.artifacts.filter[name == pubArtifact.name && extension != 'pom'].forEach[
						publication.artifact(it)
					]
					if (osspub.createSignatures) {
						signaturesConfig.artifacts.filter[name == pubArtifact.name].forEach[
							publication.artifact(it)
						]
					}
				]
				
				tasks.create('''copy«publicationName.toFirstUpper»Pom''', Copy) [
					description = '''Copy the POM file for «pubArtifact.name» to make it consumable by the maven-publish plugin'''
					from = pubArtifact.getFileName(null, 'pom')
					into = '''«buildDir»/publications/«publicationName»'''
					rename('.*', 'pom-default.xml')
					if (osspub.signJars)
						dependsOn('''sign«pubProject.name»Jars''')
					else
						dependsOn(archivesCopyTask)
				]
			}
			
			tasks.create('''publish«pubProject.name»''') [
				group = 'Publishing'
				description = '''Publishes all «pubProject.name» artifacts'''
				for (pubArtifact : pubProject.artifacts) {
					dependsOn('''publish«pubArtifact.publicationName.toFirstUpper»PublicationTo«osspub.mavenUploadRepository.name.toFirstUpper»Repository''')
				}
			]
			
			tasks.create('''deploy«pubProject.name»''') [
				group = 'Publishing'
				description = '''Deploys all «pubProject.name» artifacts to the local Maven repository'''
				for (pubArtifact : pubProject.artifacts) {
					dependsOn('''publish«pubArtifact.publicationName.toFirstUpper»PublicationTo«LOCAL_REPO_NAME.toFirstUpper»Repository''')
				}
			]
		}
		
		tasks.withType(GenerateMavenPom) [
			enabled = false
		]
		
		tasks.withType(PublishToMavenRepository) [
			val pubName = publication.name
			dependsOn('''copy«pubName.toFirstUpper»Pom''')
			for (pubProject : osspub.projects) {
				val pubArtifact = pubProject.artifacts.findFirst[publicationName == pubName]
				if (pubArtifact !== null && pubArtifact.isPomOnly)
					dependsOn('''createDummyFor«pubName.toFirstUpper»''')
			}
		]
	}
	
	private def boolean isPomOnly(MavenArtifact pubArtifact) {
		val filtered = CLASSIFIERS.filter[!pubArtifact.excludes(it)]
		return filtered.size == 1 && filtered.head.key === null && filtered.head.value == 'pom'
	}
	
	private def String getFileName(MavenArtifact pubArtifact, String classifierName, String extensionName) {
		'''«if (osspub.signJars && (classifierName === null || classifierName == 'sources') && extensionName == 'jar')
				project.signedArtifactsDir
			else
				project.artifactsDir
		»/«pubArtifact.name»-«osspub.version»«IF classifierName !== null»-«classifierName»«ENDIF».«extensionName»'''
	}
	
	private def String getPublicationName(MavenArtifact pubArtifact) {
		pubArtifact.name.replaceAll('\\.|-', '')
	}
	
	private def boolean excludes(MavenArtifact pubArtifact, Pair<String, String> cePair) {
		pubArtifact.excludedClassifiers.contains(cePair.key) || pubArtifact.excludedExtensions.contains(cePair.value)
	}
	
	private def void loadMavenSettings() {
		try {
			// Load settings.xml
			val settingsBuildingRequest = new DefaultSettingsBuildingRequest
			if (osspub.userMavenSettings.exists)
				logger.info('''Maven Settings: including user file «osspub.userMavenSettings»''')
			settingsBuildingRequest.userSettingsFile = osspub.userMavenSettings
			if (osspub.globalMavenSettings.exists)
				logger.info('''Maven Settings: including global file «osspub.globalMavenSettings»''')
			settingsBuildingRequest.globalSettingsFile = osspub.globalMavenSettings
			settingsBuildingRequest.systemProperties = System.properties
			val settingsBuilder = new DefaultSettingsBuilderFactory().newInstance()
			val mavenSettings = settingsBuilder.build(settingsBuildingRequest).effectiveSettings
			
			// Set up for decryption
			val cipher = new DefaultPlexusCipher
			val decryptionKey = if (osspub.mavenSecurityFile.exists && !osspub.mavenSecurityFile.isDirectory) {
				logger.info('''Maven Settings: including security file «osspub.mavenSecurityFile»''')
				val settingsSecurity = SecUtil.read(osspub.mavenSecurityFile.toString, true)
				cipher.decryptDecorated(settingsSecurity.master, DefaultSecDispatcher.SYSTEM_PROPERTY_SEC_LOCATION)
			}
			
			logger.info('''Maven Settings: found «mavenSettings.servers.size» server entries''')
			
			// Apply username and password from the Maven settings to all matching repositories
			publishing.repositories.filter(MavenArtifactRepository).forEach [ repository |
				val server = mavenSettings.servers.filter[username !== null && password !== null].findFirst[id == repository.name]
				if (server !== null) {
					repository.credentials [
						username = server.username
						if (cipher.isEncryptedString(server.password)) {
							if (decryptionKey === null)
								throw new GradleException('Missing settings-security.xml file.')
							logger.info('''Maven Settings: using encrypted server entry for «repository.name» repository''')
							password = cipher.decryptDecorated(server.password, decryptionKey)
						} else {
							logger.info('''Maven Settings: using server entry for «repository.name» repository''')
							password = server.password
						}
					]
				}
			]
			
			// Get the GPG key for creating signature files from the Maven settings
			val gpgServer = mavenSettings.servers.filter[passphrase !== null].findFirst[id == 'gpg.passphrase']
			if (gpgServer !== null) {
				if (cipher.isEncryptedString(gpgServer.passphrase)) {
					if (decryptionKey === null)
						throw new GradleException('Missing settings-security.xml file.')
					logger.info('Maven Settings: using encrypted server entry for pgp signing')
					ext.set(PublishingPlugin.SIGNING_PASSWORD, cipher.decryptDecorated(gpgServer.passphrase, decryptionKey))
				} else {
					logger.info('Maven Settings: using server entry for pgp signing')
					ext.set(PublishingPlugin.SIGNING_PASSWORD, gpgServer.passphrase)
				}
			}
		} catch (SettingsBuildingException e) {
			throw new GradleException('Error while loading Maven settings.', e)
		}
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