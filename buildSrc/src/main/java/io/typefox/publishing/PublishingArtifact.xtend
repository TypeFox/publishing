/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@Accessors(PUBLIC_GETTER)
@FinalFieldsConstructor
class PublishingArtifact {
	
	val PublishingProject project
	
	String name
	
	String group
	
	val Set<String> excludedClassifiers = newHashSet
	
	val Set<String> excludedExtensions = newHashSet
	
	def void name(String name) {
		this.name = name
	}
	
	def void group(String group) {
		this.group = group
	}
	
	def getGroup() {
		group ?: project.group
	}
	
	def void excludeClassifier(String classifier) {
		excludedClassifiers += classifier
	}
	
	def void excludeExtension(String ext) {
		excludedExtensions += ext
	}
	
}