/**
 * Copyright (c) 2016, 2021 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package io.typefox.publishing;

import groovy.lang.Closure;

import java.util.ArrayList;
import java.util.List;
import org.gradle.api.Action;

public class MavenProject {
  private String name;
  
  private String group;
  
  private List<MavenArtifact> artifacts = new ArrayList<>();
  
  public void name(String name) {
    this.name = name;
  }
  
  public void group(String group) {
    this.group = group;
  }
  
  public MavenArtifact artifact(Closure<MavenArtifact> configure) {
    MavenArtifact result = new MavenArtifact(this);
    configure.setDelegate(result);
    configure.setResolveStrategy(Closure.DELEGATE_FIRST);
    configure.call();
    this.artifacts.add(result);
    return result;
  }
  
  public MavenArtifact artifact(Action<MavenArtifact> configure) {
    MavenArtifact result = new MavenArtifact(this);
    configure.execute(result);
    this.artifacts.add(result);
    return result;
  }
  
  public MavenArtifact artifact(String name) {
    MavenArtifact result = new MavenArtifact(this);
    result.name(name);
    this.artifacts.add(result);
    return result;
  }
  
  public String getName() {
    return this.name;
  }
  
  public String getGroup() {
    return this.group;
  }
  
  public List<MavenArtifact> getArtifacts() {
    return this.artifacts;
  }
}
