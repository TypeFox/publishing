/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class P2Repository {
	
	String name
	
	String group
	
	String url
	
	val List<String> namespaces = newArrayList
	
	String referenceFeature
	
	String timestampPrefix
	
	def void name(Object input) {
		this.name = input.toString
	}
	
	def void group(Object input) {
		this.group = input.toString
	}
	
	def void url(Object input) {
		this.url = input.toString
	}
	
	def void namespace(Object input) {
		this.namespaces += input.toString
	}
	
	def void referenceFeature(Object input) {
		this.referenceFeature = input.toString
	}
	
	def void timestampPrefix(Object input) {
		this.timestampPrefix = input.toString
	}
	
}