/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import groovy.lang.Closure
import java.io.File
import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class PublishingPluginExtension {
	
	String version
	
	String branch = 'master'
	
	String mavenUploadRepository = 'Maven'
	
	String stagingUrl = 'https://oss.sonatype.org/service/local/staging/deploy/maven2/'
	
	String snapshotUrl = 'https://oss.sonatype.org/content/repositories/snapshots/'
	
	boolean createSignatures = true
	
	boolean signJars = false
	
	File jarSigner
	
	List<PublishingProject> projects = newArrayList
	
	File userMavenSettings = new File(System.getProperty('user.home'), '.m2/settings.xml')
	
	File globalMavenSettings = new File(System.getenv('M2_HOME'), 'conf/settings.xml')
	
	File mavenSecurityFile = new File(System.getProperty('user.home'), '/.m2/settings-security.xml')
	
	String p2Repository
	
	def void version(Object input) {
		this.version = input.toString
	}
	
	def void branch(Object input) {
		this.branch = input.toString
	}
	
	def void mavenUploadRepository(Object input) {
		this.mavenUploadRepository = input.toString
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
		if (input instanceof File)
			this.jarSigner = input
		else
			this.jarSigner = new File(input.toString)
	}
	
	def project(Closure<PublishingProject> configure) {
		val result = new PublishingProject
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		projects += result
		return result
	}
	
	def userMavenSettings(Object input) {
		if (input instanceof File)
			this.userMavenSettings = input
		else
			this.userMavenSettings = new File(input.toString)
	}
	
	def globalMavenSettings(Object input) {
		if (input instanceof File)
			this.globalMavenSettings = input
		else
			this.globalMavenSettings = new File(input.toString)
	}
	
	def mavenSecurityFile(Object input) {
		if (input instanceof File)
			this.mavenSecurityFile = input
		else
			this.mavenSecurityFile = new File(input.toString)
	}
	
	def void p2Repository(Object input) {
		this.p2Repository = input.toString
	}
	
}