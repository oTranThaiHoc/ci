#!/bin/sh

#  remote_deploy.sh
#
#
#  Created by nguyen.van.hung on 5/10/18.
#

SOURCE_DIR="$1"
TARGET="$2"
TITLE="$3"
CONFIG_FILE="config_${TARGET}.plist"

SCRIPT_DIR="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )"; pwd )"

REMOTE=$(defaults read "${SCRIPT_DIR}/${CONFIG_FILE}" gitremote)
BRANCH=$(defaults read "${SCRIPT_DIR}/${CONFIG_FILE}" gitbranch)

cd ${SOURCE_DIR}
git add -A
git checkout -f
if ! [ -n "${REMOTE##+([[:space:]])}" ]; then
    REMOTE=access
    echo "Using default remote ${REMOTE}"
fi
if ! [ -n "${BRANCH##+([[:space:]])}" ]; then
    BRANCH=master
    echo "Using default branch ${BRANCH}"
fi
git pull ${REMOTE} ${BRANCH}

${SCRIPT_DIR}/deploy_no_upload.sh "${CONFIG_FILE}" "${TITLE}"
