#!/bin/bash

BUILD_DIR="build"
mkdir -p $BUILD_DIR/signedArtifacts

for ARTIFACT in "$@"
do
	curl -o $BUILD_DIR/signedArtifacts/$ARTIFACT -F file=@$BUILD_DIR/artifacts/$ARTIFACT http://build.eclipse.org:31338/sign
done
