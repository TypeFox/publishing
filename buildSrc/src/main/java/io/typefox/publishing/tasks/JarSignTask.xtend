/*******************************************************************************
 * Copyright (c) 2016, 2021 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing.tasks

import com.google.common.io.Files
import io.typefox.publishing.MavenPublishing
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FilenameFilter
import java.io.IOException
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.FileCollection
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction
import org.gradle.api.tasks.incremental.IncrementalTaskInputs

import static extension io.typefox.publishing.FileChecksums.*

/**
 * JAR signing script that follows the instructions at
 *     https://wiki.eclipse.org/JAR_Signing
 * This works only when invoked from the Eclipse build infrastructure.
 */
@Accessors
class JarSignTask extends DefaultTask {
	
	static val SIGNING_SERVICE = 'https://cbi.eclipse.org/jarsigner/sign'
	
	static val STDOUT_FORMAT = '    %{size_upload} bytes uploaded, %{size_download} bytes downloaded (%{time_total} s)\\n'
	
	@InputFiles
	FileCollection from
	
	@OutputDirectory
	File outputDir
	
	File alternateSourceDir
	
	File alternateTargetDir
	
	boolean failOnInconsistency
	
	Set<String> acceptedDifferingJars = newHashSet
	
	@TaskAction
	def void execute(IncrementalTaskInputs inputs) {
		inputs.outOfDate[
			val target = new File(outputDir, file.name)
			processFile(file, target)
		]
	}
	
	private def void processFile(File source, File target) {
		target.parentFile?.mkdirs()
		if (alternateSourceDir !== null) {
			val sourceIdentifier = source.name.identifier
			val FilenameFilter filter = [dir, name | name.identifier == sourceIdentifier]
			val matching = alternateSourceDir.listFiles(filter)
			if (matching !== null && matching.length > 0) {
				val sourceChecksum = source.crcChecksum
				val equalSourceFile = matching.findFirst[crcChecksum == sourceChecksum]
				if (equalSourceFile === null) {
					if (!acceptedDifferingJars.contains(sourceIdentifier.key)) {
						val message = '''The artifact «source.withoutRootPath» matches «matching.map[withoutRootPath].join(', ')», but their content is unequal.'''
						if (failOnInconsistency)
							throw new GradleException(message)
						else
							logger.warn('Warning: ' + message)
					}
				} else if (alternateTargetDir !== null) {
					val alternateTargetFile = new File(alternateTargetDir, equalSourceFile.name)
					if (alternateTargetFile.exists) {
						logger.lifecycle('''Reusing signed artifact «alternateTargetFile.withoutRootPath»''')
						copyFile(alternateTargetFile, target)
						return
					}
				}
			}
		}
		signFile(source, target)
	}
	
	private def withoutRootPath(File file) {
		if (file.path.startsWith(project.rootDir.path))
			file.path.substring(project.rootDir.path.length + 1)
		else
			file.path
	}
	
	private def getIdentifier(String fileName) {
		val dashIndex = fileName.indexOf('-')
		val underscoreIndex = fileName.indexOf('_')
		val lastDotIndex = fileName.lastIndexOf('.')
		val artifactName = if (dashIndex >= 0 && underscoreIndex >= 0)
			fileName.substring(0, Math.min(dashIndex, underscoreIndex))
		else if (dashIndex >= 0)
			fileName.substring(0, dashIndex)
		else if (underscoreIndex >= 0)
			fileName.substring(0, underscoreIndex)
		else if (lastDotIndex >= 0)
			fileName.substring(0, lastDotIndex)
		else
			fileName
		val matching = MavenPublishing.CLASSIFIERS.map[
			if (key === null)
				'.' + value
			else
				'-' + key + '.' + value
		].filter[fileName.endsWith(it)]
		val suffix = if (!matching.empty)
			matching.maxBy[length]
		if (artifactName.endsWith('.source') && suffix == '.jar')
			return artifactName.substring(0, artifactName.length - '.source'.length) -> '-sources.jar'
		else
			return artifactName -> suffix
	}
	
	private def void signFile(File source, File target) {
		// Use this property to test the publishing process without access to the Jar signing service
		if (project.hasProperty('signing.skip') && project.property('signing.skip') == 'true') {
			logger.lifecycle('''Copy «source.withoutRootPath» (skipped signing)''')
			copyFile(source, target)
		} else {
			logger.lifecycle('''Sign «source.withoutRootPath»''')
			try {
				project.exec[
					executable = 'curl'
					args = #[
						'--fail',
						'--retry', '10',
						'--silent', '--show-error',
						'--write-out', STDOUT_FORMAT,
						'--output', target.path,
						'--form', '''file=@«source.path»''',
						SIGNING_SERVICE
					]
				]
			} catch (GradleException exception) {
				// Run again and print the service error message if it fails again
				val errorOutput = new ByteArrayOutputStream
				try {
					project.exec[
						executable = 'curl'
						args = #[
							'--silent',
							'--retry', '10',
							'--form', '''file=@«source.path»''',
							SIGNING_SERVICE
						]
						standardOutput = errorOutput
					]
				} catch (GradleException e2) {
					project.logger.error(errorOutput.toString)
				}
				throw exception
			}
		}
	}
	
	private def void copyFile(File source, File target) {
		try {
			Files.copy(source, target)
		} catch (IOException e) {
			throw new GradleException('''Failed to copy «source.withoutRootPath»''', e)
		}
	}
	
}
