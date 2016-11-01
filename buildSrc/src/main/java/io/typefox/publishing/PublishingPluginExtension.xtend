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
	
	boolean createSignatures = true
	
	boolean signJars = false
	
	String jarSigner
	
	List<PublishingProject> projects = newArrayList
	
	def void version(Object input) {
		this.version = input.toString
	}
	
	def void branch(Object input) {
		this.branch = input.toString
	}
	
	def void repositoryName(Object input) {
		this.repositoryName = input.toString
	}
	
	def void stagingUrl(Object input) {
		this.stagingUrl = input.toString
	}
	
	def void snapshotUrl(Object input) {
		this.snapshotUrl = input.toString
	}
	
	def void createSignatures(Object input) {
		if (input instanceof Boolean)
			this.createSignatures = input
		else if (input instanceof String)
			this.createSignatures = Boolean.valueOf(input)
	}
	
	def void signJars(Object input) {
		if (input instanceof Boolean)
			this.signJars = input
		else if (input instanceof String)
			this.signJars = Boolean.valueOf(input)
	}
	
	def void jarSigner(Object input) {
		this.jarSigner = input.toString
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