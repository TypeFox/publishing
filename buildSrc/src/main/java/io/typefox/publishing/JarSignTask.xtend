/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import java.io.File
import org.eclipse.xtend.lib.annotations.Accessors
import org.gradle.api.DefaultTask
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction
import org.gradle.api.tasks.incremental.IncrementalTaskInputs

/**
 * JAR signing script that follows the instructions at
 *     https://wiki.eclipse.org/JAR_Signing
 * This works only when invoked from the Eclipse build infrastructure.
 */
@Accessors
class JarSignTask extends DefaultTask {
	
	@InputDirectory
	File inputDir
	
	@OutputDirectory
	File outputDir
	
	@TaskAction
	def void execute(IncrementalTaskInputs inputs) {
		inputs.outOfDate[
			if (file.name.endsWith('.jar'))
				file.signJar
		]
		inputs.removed[new File(outputDir, file.name).delete()]
	}
	
	private def void signJar(File unsigned) {
		project.exec[
			executable = 'curl'
			args = #['-o', new File(outputDir, unsigned.name).path, '-F', '''file=@«unsigned»''', 'http://build.eclipse.org:31338/sign']
		]
	}
	
}