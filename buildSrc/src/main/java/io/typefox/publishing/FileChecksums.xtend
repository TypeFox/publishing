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
import java.security.DigestInputStream
import java.security.MessageDigest
import java.util.zip.CRC32

class FileChecksums {
	
	static def long getCrcChecksum(File file) throws FileNotFoundException, IOException {
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
	
	static def byte[] getMd5Checksum(File file) throws FileNotFoundException, IOException {
		val messageDigest = MessageDigest.getInstance('MD5')
		getChecksum(file, messageDigest)
	}
	
	static def byte[] getSha256Checksum(File file) throws FileNotFoundException, IOException {
		val messageDigest = MessageDigest.getInstance('SHA-256')
		getChecksum(file, messageDigest)
	}
	
	static def byte[] getChecksum(File file, MessageDigest messageDigest) throws FileNotFoundException, IOException {
		var DigestInputStream digestInputStream
		try {
			digestInputStream = new DigestInputStream(new FileInputStream(file), messageDigest)
			val buffer = newByteArrayOfSize(4096)
			var int bytesRead
			do {
				bytesRead = digestInputStream.read(buffer)
			} while (bytesRead > 0)
		} finally {
			try {
				digestInputStream?.close()
			} catch (IOException e) {}
		}
		return messageDigest.digest()
	}
	
	static def String toString(byte[] bytes) {
		val result = new StringBuilder
		for (var i = 0; i < bytes.length; i++) {
			var value = bytes.get(i) as int
			if (value < 0)
				value += 0x100
			result.append(String.format('%02x', value))
		}
		return result.toString
	}
	
}