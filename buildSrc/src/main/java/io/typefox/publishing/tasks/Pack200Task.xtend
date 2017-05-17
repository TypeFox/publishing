/*******************************************************************************
 * Copyright (c) 2017 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing.tasks

import java.io.File
import java.io.FileOutputStream
import java.io.FileWriter
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import org.eclipse.xtend.lib.annotations.Accessors
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.FileCollection
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction
import org.gradle.api.tasks.incremental.IncrementalTaskInputs

/**
 * Invokes the pack200 tool for jar files.
 */
class Pack200Task extends DefaultTask {
	
	@Accessors@InputFiles
	FileCollection from
	
	@Accessors@OutputDirectory
	File outputDir = new File('')
	
	@Accessors
	boolean repack
	
	File logFile
	
	@TaskAction
	def void execute(IncrementalTaskInputs inputs) {
		new File(project.buildDir, 'logs').mkdirs()
		val executionTime = DateTimeFormatter.ofPattern('yyyyMMdd_A').format(LocalDateTime.now())
		logFile = new File(project.buildDir, '''logs/pack200_«executionTime».log''')
		val log = new FileWriter(logFile)
		log.write('### Executable: ' + pack200 + '\n')
		log.close()
		
		inputs.outOfDate[
			val target = if (!outputDir.path.empty) new File(outputDir, file.name + '.pack.gz')
			processFile(file, target)
		]
	}
	
	private def void processFile(File source, File target) {
		val message = '''«IF repack»Repack«ELSE»Pack«ENDIF» «source.withoutRootPath»'''
		logger.lifecycle(message)
		writeToLogFile('### ' + message + '\n')
		try {
			val output = new FileOutputStream(logFile, true)
			project.exec[
				executable = pack200
				if (repack) {
					if (target === null)
						args = #[ '--verbose', '--repack', source.path ]
					else
						args = #[ '--verbose', '--repack', target.path, source.path ]
				} else {
					args = #[ '--verbose', target.path, source.path ]
				}
				standardOutput = output
				errorOutput = output
			]
			output.close()
		} catch (GradleException exception) {
			project.logger.error('''Error during pack200 execution; see «logFile.withoutRootPath» for details.''')
			throw exception
		}
	}
	
	private def writeToLogFile(String message) {
		val log = new FileWriter(logFile, true)
		log.write(message)
		log.close()
	}
	
	private def withoutRootPath(File file) {
		if (file.path.startsWith(project.rootDir.path))
			file.path.substring(project.rootDir.path.length + 1)
		else
			file.path
	}
	
	private def getPack200() {
		val javaHome = System.getProperty('java.home')
		if (javaHome.nullOrEmpty)
			return 'pack200'
		else
			return '''«javaHome»/bin/pack200'''
	}
	
}
