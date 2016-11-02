/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.gradle.api.Project
import org.gradle.api.tasks.Copy
import pw.prok.download.Download

@FinalFieldsConstructor
class EclipsePublishing {
	
	val extension Project project
	val PublishingPluginExtension osspub
	
	def void configure() {
		configureTasks()
	}
	
	private def void configureTasks() {
		val downloadP2Task = task(#{'type' -> Download}, 'downloadP2Repository') => [ task |
			val it = task as Download
			onlyIf[!osspub.p2Repository.nullOrEmpty]
			group = 'P2'
			src(osspub.p2Repository)
    		dest('''«buildDir»/p2/repository.zip''')
		]
		
		task(#{'type' -> Copy}, 'unzipP2Repository') => [ task |
			val it = task as Copy
			dependsOn(downloadP2Task)
			from(zipTree('''«buildDir»/p2/repository.zip'''))
			into('''«buildDir»/p2/repository''')
		]
	}
	
}