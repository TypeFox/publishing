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
class PublishingProject {
	
	String name
	
	String group
	
	List<PublishingArtifact> artifacts = newArrayList
	
	def void name(String name) {
		this.name = name
	}
	
	def void group(String group) {
		this.group = group
	}
	
	def artifact(Closure<PublishingArtifact> configure) {
		val result = new PublishingArtifact(this)
		configure.delegate = result
		configure.resolveStrategy = Closure.DELEGATE_FIRST
		configure.call()
		artifacts += result
		return result
	}
	
	def artifact(String name) {
		val result = new PublishingArtifact(this)
		result.name(name)
		artifacts += result
		return result
	}
	
}