/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import groovy.lang.Closure
import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class PublishingPluginExtension {
	
	String version
	
	String branch = 'master'
	
	String repositoryName = 'Maven'
	
	String stagingUrl = 'https://oss.sonatype.org/service/local/staging/deploy/maven2/'
	
	String snapshotUrl = 'https://oss.sonatype.org/content/repositories/snapshots/'
	
	boolean doSigning = true
	
	boolean doJarSigning = false
	
	List<PublishingProject> projects = newArrayList
	
	def project(Closure<PublishingProject> configure) {
		val result = new PublishingProject
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		projects += result
		return result
	}
	
}