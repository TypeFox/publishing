/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class MavenUploadRepository {
	
	String name = 'Maven'
	
	String stagingUrl = 'https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/'
	
	String snapshotUrl = 'https://oss.sonatype.org/content/repositories/snapshots/'
	
	def void name(Object input) {
		this.name = input.toString
	}
	
	def void stagingUrl(Object input) {
		this.stagingUrl = input.toString
	}
	
	def void snapshotUrl(Object input) {
		this.snapshotUrl = input.toString
	}
	
}