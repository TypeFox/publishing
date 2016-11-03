/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import java.io.File
import org.gradle.api.InvalidUserDataException
import org.gradle.api.internal.file.copy.DestinationRootCopySpec
import org.gradle.api.internal.tasks.SimpleWorkResult
import org.gradle.api.tasks.AbstractCopyTask

/**
 * JAR signing script that follows the instructions at
 *     https://wiki.eclipse.org/JAR_Signing
 * This works only when invoked from the Eclipse build infrastructure.
 */
class JarSignTask extends AbstractCopyTask {
	
	private def boolean signFile(File source, File target) {
		target.parentFile?.mkdirs()
		val result = project.exec[
			executable = 'curl'
			args = #['-o', target.path, '-F', '''file=@«source.path»''', 'http://build.eclipse.org:31338/sign']
		]
		return result.exitValue == 0
	}
	
	override protected createRootSpec() {
        instantiator.newInstance(DestinationRootCopySpec, fileResolver, super.createRootSpec())
    }
	
    override DestinationRootCopySpec getRootSpec() {
        super.rootSpec as DestinationRootCopySpec
    }
	
	override protected createCopyAction() {
		val destinationDir = rootSpec.destinationDir
        if (destinationDir === null)
            throw new InvalidUserDataException('No copy destination directory has been specified, use \'into\' to specify a target directory.')
        val fileResolver = fileLookup.getFileResolver(destinationDir)
        return [ stream |
        	val didWork = newBooleanArrayOfSize(1)
		    stream.process[
        		val target = fileResolver.resolve(relativePath.pathString)
                didWork.set(0, signFile(file, target))
        	]
		    return new SimpleWorkResult(didWork.get(0))
        ]
	}
	
}