#!/bin/sh

#  gen_export_options.sh
#
#
#  Created by nguyen.van.hung on 4/19/18.
#

EXPORT_METHOD=$1
BUNDLEID=$2
PROVISIONING_PROFILE_NAME=$3
OPTIONS_FILE_NAME=$4

cat > ${OPTIONS_FILE_NAME} <<- EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${EXPORT_METHOD}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLEID}</key>
        <string>${PROVISIONING_PROFILE_NAME}</string>
    </dict>
</dict>
</plist>
EOM
