#!/bin/sh

#  change_bundle_id.sh
#
#
#  Created by nguyen.van.hung on 7/03/18.
#

INFO_PATH=$1
BUNDLE_ID=$2

defaults write ${INFO_PATH} CFBundleIdentifier -string ${BUNDLE_ID}
