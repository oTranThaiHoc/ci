#!/bin/sh

#  remote_deploy.sh
#
#
#  Created by nguyen.van.hung on 5/10/18.
#

SOURCE_DIR=$1
TARGET=$2
TITLE=$3
CONFIG_FILE=config_${TARGET}.plist

SCRIPT_DIR="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )"; pwd )"

cd ${SOURCE_DIR}
git add -A
git checkout -f
git pull origin master

${SCRIPT_DIR}/deploy.sh ${CONFIG_FILE} ${TITLE}
