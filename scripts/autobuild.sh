#!/bin/sh

#  autobuild.sh
#  
#
#  Created by nguyen.van.hung on 4/19/18.
#  

echo ""
echo "Usage: autobuild.sh WORKSPACE SCHEME CONFIGURATION VERSION"
echo ""
echo ""

WORKSPACE=$1
SCHEME=$2
CONFIGURATION=$3
VERSION=$4
BUILD_DIR=${PWD}/build

shopt -s extglob  # more powerful pattern matching

if ! [ -n "${WORKSPACE##+([[:space:]])}" ]; then
    echo "You must provide WORKSPACE"
    exit 1
else
	echo "Building workspace ${WORKSPACE}"
fi

if ! [ -n "${SCHEME##+([[:space:]])}" ]; then
    echo "You must provide SCHEME"
    exit 1
else
	echo "Building scheme ${SCHEME}"
fi

if ! [ -n "${CONFIGURATION##+([[:space:]])}" ]; then
	CONFIGURATION='In-House'
    echo "Using default configuration ${CONFIGURATION}"
fi

if ! [ -n "${VERSION##+([[:space:]])}" ]; then
    VERSION='1.0.0'
    echo "Using default version ${VERSION}"
fi

echo ""

if [[ ! -e $BUILD_DIR ]]; then
    mkdir $BUILD_DIR
fi

rm -rf ${PWD}/build/*
xcodebuild -workspace ${WORKSPACE} -scheme ${SCHEME} -sdk iphoneos -configuration ${CONFIGURATION} archive -archivePath ${PWD}/build/${SCHEME}.xcarchive
if test $? -eq 0
    then
        echo "** ARCHIVE ${SCHEME} SUCCEEDED **"
    else
        echo "** ARCHIVE ${SCHEME} FAILED **"
        exit 1
fi

xcodebuild -exportArchive -archivePath ${PWD}/build/${SCHEME}.xcarchive -exportOptionsPlist exportOptions.plist -exportPath ${PWD}/build

if test $? -eq 0
    then
        echo "** EXPORT ${SCHEME} SUCCEEDED **"
        mv ${PWD}/build/${SCHEME}.ipa ${PWD}/build/${SCHEME}.${VERSION}.ipa 
    else
        echo "** EXPORT ${SCHEME} FAILED **"
        exit 1
fi

exit 0
