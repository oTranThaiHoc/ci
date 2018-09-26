#!/bin/sh

#  remote_deploy.sh
#
#
#  Created by nguyen.van.hung on 5/10/18.
#

SOURCE_DIR="$1"
TARGET="$2"
TITLE="$3"
PULL_REQUEST="$4"
BUILD_VERSION="$5"
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
git checkout ${BRANCH}
git pull ${REMOTE} ${BRANCH}

if [ -n "${PULL_REQUEST##+([[:space:]])}" ]; then
    echo "Switch to pull request: ${PULL_REQUEST}"
    git branch -D local_build
    git fetch ${REMOTE} pull/${PULL_REQUEST}/head:local_build
    git checkout local_build
fi

${SCRIPT_DIR}/deploy_no_upload.sh "${CONFIG_FILE}" "${TITLE}" "${BUILD_VERSION}"
