/**
 * Copyright (c) 2016, 2021 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package io.typefox.publishing;

import java.util.ArrayList;
import java.util.List;

public class P2Repository {
  private String name;
  
  private String group;
  
  private String url;
  
  private String deployPath;
  
  private final List<String> namespaces = new ArrayList<>();
  
  private String referenceFeature;
  
  private final List<String> acceptedDifferingJars = new ArrayList<>();
  
  public void name(Object input) {
    this.name = input.toString();
  }
  
  public void group(Object input) {
    this.group = input.toString();
  }
  
  public void url(Object input) {
    this.url = input.toString();
  }
  
  public void deployPath(Object input) {
    this.deployPath = input.toString();
  }
  
  public void namespace(Object input) {
    String _string = input.toString();
    this.namespaces.add(_string);
  }
  
  public void referenceFeature(Object input) {
    this.referenceFeature = input.toString();
  }
  
  public void acceptDifferingJars(Object input) {
    this.acceptedDifferingJars.add(input.toString());
  }
  
  public String getName() {
    return this.name;
  }
  
  public String getGroup() {
    return this.group;
  }
  
  public String getUrl() {
    return this.url;
  }
  
  public String getDeployPath() {
    return this.deployPath;
  }
  
  public List<String> getNamespaces() {
    return this.namespaces;
  }
  
  public String getReferenceFeature() {
    return this.referenceFeature;
  }
  
  public List<String> getAcceptedDifferingJars() {
    return this.acceptedDifferingJars;
  }
}
