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

SCHEME=$(defaults read ${CONFIG_FILE} scheme)
BUNDLEID=$(defaults read ${CONFIG_FILE} bundleid)
SERVER=$(defaults read ${CONFIG_FILE} server)
BUILD_DIR=${PWD}/build_${SCHEME}
DATE=`date '+%Y%m%d.%H%M%S'`
BINARY_FILE_NAME=${SCHEME}.${DATE}.ipa

${PWD}/autobuild.sh ${CONFIG_FILE} ${BINARY_FILE_NAME}

if test $? -eq 0
    then
        echo "** BUILD ${SCHEME} SUCCEEDED **"
    else
        echo "** BUILD ${SCHEME} FAILED **"
        exit 1
fi

echo "Uploading..."
curl -X POST -F uploadfile=@"${BUILD_DIR}/${BINARY_FILE_NAME}" --form bundleid="${BUNDLEID}" --form title="${SCHEME}.${DATE}" --form project="${SCHEME}" ${SERVER}/upload

if test $? -eq 0; then
    echo ""
    echo "** UPLOAD ${BINARY_FILE_NAME} SUCCEEDED **"
fi

exit 0
