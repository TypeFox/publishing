#!/bin/bash

# JAR signing script that follows the instructions at
#   https://wiki.eclipse.org/JAR_Signing
# This works only when invoked from the Eclipse build infrastructure.

mkdir -p $2

for ARTIFACT in $1/*.jar
do
	FILE=`basename $ARTIFACT`
	cp $1/$FILE $2/$FILE
	#curl -o $2/$FILE -F file=@$1/$FILE http://build.eclipse.org:31338/sign
done
