/**
 * Copyright (c) 2016, 2021 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package io.typefox.publishing;

import java.util.HashSet;
import java.util.Set;


public class MavenArtifact {
	private final MavenProject project;

	private String name;

	private String group;

	private final Set<String> excludedClassifiers = new HashSet<>();

	private final Set<String> excludedExtensions = new HashSet<>();

	public void name(String name) {
		this.name = name;
	}

	public void group(String group) {
		this.group = group;
	}

	public String getGroup() {
		if (this.group != null) {
			return this.group;
		} else {
			return this.project.getGroup();
		}
	}

	public void excludeClassifier(String classifier) {
		excludedClassifiers.add(classifier);
	}

	public void excludeExtension(String ext) {
		excludedExtensions.add(ext);
	}

	public MavenArtifact(MavenProject project) {
		this.project = project;
	}

	public MavenProject getProject() {
		return this.project;
	}

	public String getName() {
		return this.name;
	}

	public Set<String> getExcludedClassifiers() {
		return this.excludedClassifiers;
	}

	public Set<String> getExcludedExtensions() {
		return this.excludedExtensions;
	}
}
