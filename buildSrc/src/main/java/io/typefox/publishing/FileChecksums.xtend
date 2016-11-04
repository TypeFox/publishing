/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.util.zip.CRC32

class FileChecksums {
	
	static def long getChecksum(File file) throws FileNotFoundException, IOException {
		val checksum = new CRC32
		var InputStream inputStream
		try {
			inputStream = new FileInputStream(file)
			val buffer = newByteArrayOfSize(4096)
			var bytesRead = inputStream.read(buffer)
			while (bytesRead >= 0) {
				checksum.update(buffer, 0, bytesRead)
				bytesRead = inputStream.read(buffer)
			}
			return checksum.value
		} finally {
			try {
				inputStream?.close()
			} catch (IOException e) {}
		}
	}
	
}