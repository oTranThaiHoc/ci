#!/bin/sh

#  deploy.sh
#
#
#  Created by nguyen.van.hung on 4/19/18.
#

echo ""
echo "Usage: deploy.sh"
echo ""
echo ""

CONFIG_FILE=${PWD}/config.plist
BUILD_DIR=${PWD}/build

echo "Current version: ${VERSION}"
# echo "Input new version: "
# read VERSION
# echo "New version: ${VERSION}"

${PWD}/autobuild.sh ${CONFIG_FILE}

if test $? -eq 0
    then
        echo "** BUILD ${SCHEME} SUCCEEDED **"
    else
        echo "** BUILD ${SCHEME} FAILED **"
        exit 1
fi

echo "Uploading..."
curl -F uploadfile=@"${BUILD_DIR}/${SCHEME}.${VERSION}.ipa" http://localhost:3000/upload

if test $? -eq 0; then
    echo ""
    echo "** UPLOAD ${SCHEME}.${VERSION}.ipa SUCCEEDED **"
    # defaults write ${CONFIG_FILE} version ${VERSION}
fi

exit 0
