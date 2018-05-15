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

SCRIPT_DIR="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )"; pwd )"

CONFIG_FILE=${SCRIPT_DIR}/$1
TITLE=$2

SCHEME=$(defaults read ${CONFIG_FILE} scheme)
BUNDLEID=$(defaults read ${CONFIG_FILE} bundleid)
SERVER=$(defaults read ${CONFIG_FILE} server)
BUILD_DIR=${SCRIPT_DIR}/build_${SCHEME}
DATE=`date '+%Y%m%d.%H%M%S'`
BINARY_FILE_NAME=${SCHEME}.${DATE}.ipa

# check title, default ${SCHEME}.${DATE}
if ! [ -n "${TITLE##+([[:space:]])}" ]; then
    TITLE=${SCHEME}.${DATE}
    echo "Using default title ${TITLE}"
fi

${SCRIPT_DIR}/autobuild.sh ${CONFIG_FILE} ${BINARY_FILE_NAME}

if test $? -eq 0
    then
        echo "** BUILD ${SCHEME} SUCCEEDED **"
    else
        echo "** BUILD ${SCHEME} FAILED **"
        exit 1
fi

echo "Uploading..."
curl -X POST -F uploadfile=@"${BUILD_DIR}/${BINARY_FILE_NAME}" --form bundleid="${BUNDLEID}" --form title="${TITLE}" --form target="${SCHEME}" ${SERVER}/upload

if test $? -eq 0; then
    echo ""
    echo "** UPLOAD ${BINARY_FILE_NAME} SUCCEEDED **"
fi

exit 0
