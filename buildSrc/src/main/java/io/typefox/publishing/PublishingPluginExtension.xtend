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
import org.gradle.api.Action

@Accessors(PUBLIC_GETTER)
class PublishingPluginExtension {
	
	String version
	
	String branch = 'master'
	
	MavenUploadRepository mavenUploadRepository = new MavenUploadRepository
	
	boolean createSignatures = true
	
	boolean signJars = false
	
	boolean failOnInconsistentJars = false
	
	val List<MavenProject> projects = newArrayList
	
	File userMavenSettings = new File(System.getProperty('user.home'), '.m2/settings.xml')
	
	File globalMavenSettings = new File(System.getenv('M2_HOME'), 'conf/settings.xml')
	
	File mavenSecurityFile = new File(System.getProperty('user.home'), '/.m2/settings-security.xml')
	
	val List<P2Repository> p2Repositories = newArrayList
	
	def void version(Object input) {
		this.version = input.toString
	}
	
	def String getBaseVersion() {
		if (version.endsWith('-SNAPSHOT'))
			version.substring(0, version.length - '-SNAPSHOT'.length)
		else if (version.split('\\.').length == 3)
			version
		else
			version.substring(0, version.lastIndexOf('.'))
	}
	
	def void branch(Object input) {
		this.branch = input.toString
	}
	
	def mavenUploadRepository(String name) {
		val result = new MavenUploadRepository
		result.name(name)
		mavenUploadRepository = result
		return result
	}
	
	def mavenUploadRepository(Closure<MavenUploadRepository> configure) {
		val result = new MavenUploadRepository
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		mavenUploadRepository = result
		return result
	}
	
	def mavenUploadRepository(Action<MavenUploadRepository> configure) {
		val result = new MavenUploadRepository
		configure.execute(result)
		mavenUploadRepository = result
		return result
	}
	
	def void createSignatures(Object input) {
		if (input instanceof Boolean)
			this.createSignatures = input
		else if (input instanceof String)
			this.createSignatures = Boolean.parseBoolean(input)
	}
	
	def void signJars(Object input) {
		if (input instanceof Boolean)
			this.signJars = input
		else if (input instanceof String)
			this.signJars = Boolean.parseBoolean(input)
	}
	
	def void failOnInconsistentJars(Object input) {
		if (input instanceof Boolean)
			this.failOnInconsistentJars = input
		else if (input instanceof String)
			this.failOnInconsistentJars = Boolean.parseBoolean(input)
	}
	
	def project(Closure<MavenProject> configure) {
		val result = new MavenProject
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		projects += result
		return result
	}
	
	def project(Action<MavenProject> configure) {
		val result = new MavenProject
		configure.execute(result)
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
	
	def p2Repository(Closure<P2Repository> configure) {
		val result = new P2Repository
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		p2Repositories += result
		return result
	}
	
	def p2Repository(Action<P2Repository> configure) {
		val result = new P2Repository
		configure.execute(result)
		p2Repositories += result
		return result
	}
	
}