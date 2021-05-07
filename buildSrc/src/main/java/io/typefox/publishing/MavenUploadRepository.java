/**
 * Copyright (c) 2016, 2021 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package io.typefox.publishing;

public class MavenUploadRepository {
  private String name = "Maven";
  
  private String stagingUrl = "https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/";
  
  private String snapshotUrl = "https://oss.sonatype.org/content/repositories/snapshots/";
  
  public void name(Object input) {
    this.name = input.toString();
  }
  
  public void stagingUrl(Object input) {
    this.stagingUrl = input.toString();
  }
  
  public void snapshotUrl(Object input) {
    this.snapshotUrl = input.toString();
  }
  
  public String getName() {
    return this.name;
  }
  
  public String getStagingUrl() {
    return this.stagingUrl;
  }
  
  public String getSnapshotUrl() {
    return this.snapshotUrl;
  }
}
