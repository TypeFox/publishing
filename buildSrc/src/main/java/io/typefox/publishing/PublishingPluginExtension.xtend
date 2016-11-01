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

@Accessors(PUBLIC_GETTER)
class PublishingPluginExtension {
	
	String version
	
	String branch = 'master'
	
	String repositoryName = 'Maven'
	
	String stagingUrl = 'https://oss.sonatype.org/service/local/staging/deploy/maven2/'
	
	String snapshotUrl = 'https://oss.sonatype.org/content/repositories/snapshots/'
	
	boolean doSigning = true
	
	String jarSigner
	
	List<PublishingProject> projects = newArrayList
	
	def void version(Object version) {
		this.version = version.toString
	}
	
	def void branch(Object branch) {
		this.branch = branch.toString
	}
	
	def void repositoryName(Object repositoryName) {
		this.repositoryName = repositoryName.toString
	}
	
	def void stagingUrl(Object stagingUrl) {
		this.stagingUrl = stagingUrl.toString
	}
	
	def void snapshotUrl(Object snapshotUrl) {
		this.snapshotUrl = snapshotUrl.toString
	}
	
	def void doSigning(Object doSigning) {
		if (doSigning instanceof Boolean)
			this.doSigning = doSigning
		else if (doSigning instanceof String)
			this.doSigning = Boolean.valueOf(doSigning)
	}
	
	def void jarSigner(Object jarSigner) {
		this.jarSigner = jarSigner.toString
	}
	
	def project(Closure<PublishingProject> configure) {
		val result = new PublishingProject
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		projects += result
		return result
	}
	
}