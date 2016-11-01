#!/bin/bash

# JAR signing script that follows the instructions at
#   https://wiki.eclipse.org/JAR_Signing
# This works only when invoked from the Eclipse build infrastructure.

BUILD_DIR="build"
mkdir -p $BUILD_DIR/signedArtifacts

for ARTIFACT in "$@"
do
	curl -o $BUILD_DIR/signedArtifacts/$ARTIFACT -F file=@$BUILD_DIR/artifacts/$ARTIFACT http://build.eclipse.org:31338/sign
done
