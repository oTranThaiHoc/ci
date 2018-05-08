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

CONFIG_FILE=${PWD}/$1

# echo "Current version: ${VERSION}"
# echo "Input new version: "
# read VERSION
# echo "New version: ${VERSION}"

SCHEME=$(defaults read ${CONFIG_FILE} scheme)
VERSION=$(defaults read ${CONFIG_FILE} version)
BUILD_DIR=${PWD}/build_${SCHEME}

${PWD}/autobuild.sh ${CONFIG_FILE}

if test $? -eq 0
    then
        echo "** BUILD ${SCHEME} SUCCEEDED **"
    else
        echo "** BUILD ${SCHEME} FAILED **"
        exit 1
fi

echo "Uploading..."
curl -F uploadfile=@"${BUILD_DIR}/${SCHEME}.${VERSION}.ipa" https://df612ad4.ngrok.io/upload

if test $? -eq 0; then
    echo ""
    echo "** UPLOAD ${SCHEME}.${VERSION}.ipa SUCCEEDED **"
    # defaults write ${CONFIG_FILE} version ${VERSION}
fi

exit 0
