/**
 * Copyright (c) 2016, 2021 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package io.typefox.publishing;

import groovy.lang.Closure;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import org.gradle.api.Action;

public class PublishingPluginExtension {
	private String version;

	private String branch = "master";

	private MavenUploadRepository mavenUploadRepository = new MavenUploadRepository();

	private boolean createSignatures = true;

	private boolean signJars = false;

	private boolean packJars = false;

	private boolean failOnInconsistentJars = false;

	private final List<MavenProject> projects = new ArrayList<>();

	private File userMavenSettings = new File(System.getProperty("user.home"), ".m2/settings.xml");

	private File globalMavenSettings = new File(System.getenv("M2_HOME"), "conf/settings.xml");

	private File mavenSecurityFile = new File(System.getProperty("user.home"), "/.m2/settings-security.xml");

	private final List<P2Repository> p2Repositories = new ArrayList<>();

	public void version(Object input) {
		this.version = input.toString();
	}

	public String getBaseVersion() {
		if (this.version.endsWith("-SNAPSHOT")) {
			return this.version.substring(0, this.version.length() - "-SNAPSHOT".length());
		} else {
			if (this.version.split("\\.").length == 3) {
				return this.version;
			} else {
				return this.version.substring(0, this.version.lastIndexOf("."));
			}
		}
	}

	public void branch(Object input) {
		this.branch = input.toString();
	}

	public MavenUploadRepository mavenUploadRepository(String name) {
		MavenUploadRepository result = new MavenUploadRepository();
		result.name(name);
		this.mavenUploadRepository = result;
		return result;
	}

	public MavenUploadRepository mavenUploadRepository(Closure<MavenUploadRepository> configure) {
		MavenUploadRepository result = new MavenUploadRepository();
		configure.setDelegate(result);
		configure.setResolveStrategy(Closure.DELEGATE_FIRST);
		configure.call();
		this.mavenUploadRepository = result;
		return result;
	}

	public MavenUploadRepository mavenUploadRepository(Action<MavenUploadRepository> configure) {
		MavenUploadRepository result = new MavenUploadRepository();
		configure.execute(result);
		this.mavenUploadRepository = result;
		return result;
	}

	public void createSignatures(Object input) {
		if (input instanceof Boolean) {
			this.createSignatures = ((Boolean) input).booleanValue();
		} else {
			if (input instanceof String) {
				this.createSignatures = Boolean.parseBoolean((String) input);
			}
		}
	}

	public void signJars(Object input) {
		if (input instanceof Boolean) {
			this.signJars = ((Boolean) input).booleanValue();
		} else {
			if (input instanceof String) {
				this.signJars = Boolean.parseBoolean((String) input);
			}
		}
	}

	public void packJars(Object input) {
		if (input instanceof Boolean) {
			this.packJars = ((Boolean) input).booleanValue();
		} else {
			if (input instanceof String) {
				this.packJars = Boolean.parseBoolean((String) input);
			}
		}
	}

	public void failOnInconsistentJars(Object input) {
		if (input instanceof Boolean) {
			this.failOnInconsistentJars = ((Boolean) input).booleanValue();
		} else {
			if (input instanceof String) {
				this.failOnInconsistentJars = Boolean.parseBoolean((String) input);
			}
		}
	}

	public MavenProject project(Closure<MavenProject> configure) {
		MavenProject result = new MavenProject();
		configure.setDelegate(result);
		configure.setResolveStrategy(Closure.DELEGATE_FIRST);
		configure.call();
		this.projects.add(result);
		return result;
	}

	public MavenProject project(Action<MavenProject> configure) {
		MavenProject result = new MavenProject();
		configure.execute(result);
		this.projects.add(result);
		return result;
	}

	public File userMavenSettings(Object input) {
		if (input instanceof File) {
			return this.userMavenSettings = (File) input;
		} else {
			return this.userMavenSettings = new File(input.toString());
		}
	}

	public File globalMavenSettings(Object input) {
		if (input instanceof File) {
			return this.globalMavenSettings = (File) input;
		} else {
			return this.globalMavenSettings = new File(input.toString());
		}
	}

	public File mavenSecurityFile(Object input) {
		if (input instanceof File) {
			return this.mavenSecurityFile = (File) input;
		} else {
			return this.mavenSecurityFile = new File(input.toString());
		}
	}

	public P2Repository p2Repository(Closure<P2Repository> configure) {
		P2Repository result = new P2Repository();
		configure.setDelegate(result);
		configure.setResolveStrategy(Closure.DELEGATE_FIRST);
		configure.call();
		this.p2Repositories.add(result);
		return result;
	}

	public P2Repository p2Repository(Action<P2Repository> configure) {
		P2Repository result = new P2Repository();
		configure.execute(result);
		this.p2Repositories.add(result);
		return result;
	}

	public String getVersion() {
		return this.version;
	}

	public String getBranch() {
		return this.branch;
	}

	public MavenUploadRepository getMavenUploadRepository() {
		return this.mavenUploadRepository;
	}

	public boolean isCreateSignatures() {
		return this.createSignatures;
	}

	public boolean isSignJars() {
		return this.signJars;
	}

	public boolean isPackJars() {
		return this.packJars;
	}

	public boolean isFailOnInconsistentJars() {
		return this.failOnInconsistentJars;
	}

	public List<MavenProject> getProjects() {
		return this.projects;
	}

	public File getUserMavenSettings() {
		return this.userMavenSettings;
	}

	public File getGlobalMavenSettings() {
		return this.globalMavenSettings;
	}

	public File getMavenSecurityFile() {
		return this.mavenSecurityFile;
	}

	public List<P2Repository> getP2Repositories() {
		return this.p2Repositories;
	}
}
