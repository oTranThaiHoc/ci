#!/bin/sh

#  autobuild.sh
#
#
#  Created by nguyen.van.hung on 4/19/18.
#

echo ""
echo "Usage: autobuild.sh CONFIG_FILE IPA_FILE_NAME"
echo ""
echo ""

CONFIG_FILE="$1"
IPA_FILE_NAME="$2"
BUILD_VERSION="$3"

if ! [ -f "${CONFIG_FILE}" ]; then
    echo "${CONFIG_FILE} not found."
    exit 1
fi

SCRIPT_DIR="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )"; pwd )"

WORKSPACE=$(defaults read "${CONFIG_FILE}" workspace)
INFOPLIST_PATH=$(defaults read "${CONFIG_FILE}" infoplist)
SCHEME=$(defaults read "${CONFIG_FILE}" scheme)
CONFIGURATION=$(defaults read "${CONFIG_FILE}" configuration)
PROVISIONING_PROFILE_FILE=$(defaults read "${CONFIG_FILE}" mobileprovision)
PROVISIONING_CERT=$(defaults read "${CONFIG_FILE}" p12)
EXPORT_METHOD=$(defaults read "${CONFIG_FILE}" exportmethod)
BUNDLEID=$(defaults read "${CONFIG_FILE}" bundleid)
PRESCRIPT=$(defaults read "${CONFIG_FILE}" prescript)

CERT_PASSWORD=""
PROVISIONING_PROFILE_UUID=""
TEMP_KEYCHAIN=$HOME/Library/Keychains/xcodebuild.keychain
TEMP_KEYCHAIN_PASSWORD=""
CODE_SIGN_IDENTITY=""
PROVISIONING_PROFILE_NAME=""
DEVELOPMENT_TEAM=""
BUILD_DIR=$(sed 's/ //g' <<< "${SCRIPT_DIR}/build_${SCHEME}")

shopt -s extglob  # more powerful pattern matching

function checkParameters() {
    # check workspace
    if ! [ -n "${WORKSPACE##+([[:space:]])}" ]; then
        echo "You must provide WORKSPACE"
        exit 1
    else
        echo "Building workspace ${WORKSPACE}"
    fi

    # check build scheme
    if ! [ -n "${SCHEME##+([[:space:]])}" ]; then
        echo "You must provide SCHEME"
        exit 1
    else
        echo "Building scheme ${SCHEME}"
    fi

    # check build configuration
    if ! [ -n "${CONFIGURATION##+([[:space:]])}" ]; then
        CONFIGURATION='In-House'
        echo "Using default configuration ${CONFIGURATION}"
    fi

    # check provisioning profile
    if ! [ -n "${PROVISIONING_PROFILE_FILE##+([[:space:]])}" ]; then
        echo "You must provide PROVISIONING_PROFILE_FILE"
        exit 1
    fi

    # check certificate
    if ! [ -n "${PROVISIONING_CERT##+([[:space:]])}" ]; then
        echo "You must provide PROVISIONING_CERT"
        exit 1
    fi

    # check export method
    if ! [ -n "${EXPORT_METHOD##+([[:space:]])}" ]; then
        echo "You must provide EXPORT_METHOD"
        exit 1
    fi

    # check bundle_id
    if ! [ -n "${BUNDLEID##+([[:space:]])}" ]; then
        echo "You must provide BUNDLEID"
        exit 1
    fi

    # check name, default ${SCHEME}.ipa
    if ! [ -n "${IPA_FILE_NAME##+([[:space:]])}" ]; then
        IPA_FILE_NAME=${SCHEME}.ipa
        echo "Using default name ${IPA_FILE_NAME}"
    fi
}

function getKeychainPassword() {
    # The keychain needs to be unlocked for signing, which requires the keychain
    # password. This is stored in a file in the build account only accessible to
    # the build account user
    if [ ! -f $HOME/.pass ] ; then
        echo "No keychain password file available"
        exit 1
    fi

    case `stat -L -f "%p" $HOME/.pass`
    in
        *400) ;;
        *)
            echo "Keychain password file permissions are not restrictive enough"
            echo "chmod 400 $HOME/.pass"
            exit 1
            ;;
    esac
}

function cleanup() {
    echo "Delete keychain"
    security delete-keychain ${TEMP_KEYCHAIN}
    security list-keychains -s $HOME/Library/Keychains/login.keychain
    security default-keychain -s $HOME/Library/Keychains/login.keychain
    echo "Delete exportOptions.plist"
    rm -f exportOptions.plist
}

function importCertificate() {
    security create-keychain -p "${TEMP_KEYCHAIN_PASSWORD}" ${TEMP_KEYCHAIN}
    security add-certificates -k ${TEMP_KEYCHAIN}
    security list-keychains -s ${TEMP_KEYCHAIN}
    security default-keychain -s ${TEMP_KEYCHAIN}
    security unlock-keychain -p "${TEMP_KEYCHAIN_PASSWORD}" ${TEMP_KEYCHAIN}
    security import $PROVISIONING_CERT -P "$CERT_PASSWORD" -A -k ${TEMP_KEYCHAIN} -T /usr/bin/codesign -T /usr/bin/xcodebuild -T /usr/bin/security
    security set-keychain-settings -t 3000 ${TEMP_KEYCHAIN}
    security set-key-partition-list -S apple-tool:,apple: -s -k "${TEMP_KEYCHAIN_PASSWORD}" ${TEMP_KEYCHAIN}

    CODE_SIGN_IDENTITY=$(security find-identity -v -p codesigning "${TEMP_KEYCHAIN}" | head -1 | grep '"' | sed -e 's/[^"]*"//' -e 's/".*//')
    IOS_UUID=$(security find-identity -v -p codesigning "${TEMP_KEYCHAIN}" | head -1 | grep '"' | awk '{print $2}')

    echo "iOS identity: " ${CODE_SIGN_IDENTITY}
    echo "iOS UUID: " ${IOS_UUID}
    #
    # unlock the keychain, automatically lock keychain on script exit
    #
    # security unlock-keychain -p `cat $HOME/.pass` $HOME/Library/Keychains/login.keychain
    # security import $PROVISIONING_CERT -P "$CERT_PASSWORD" -k $HOME/Library/Keychains/login.keychain -T /usr/bin/codesign
    # trap "security lock-keychain $HOME/Library/Keychains/login.keychain" EXIT
}

function copyProvisioningProfile() {
    #
    # Extract the profile UUID from the checked in Provisioning Profile.
    #
    PROVISIONING_PROFILE_UUID=`/usr/libexec/plistbuddy -c Print:UUID /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``
    #
    # Copy the profile to the location XCode expects to find it and start the build,
    # specifying which profile and signing identity to use for the archived app
    #
    cp -f ${PROVISIONING_PROFILE_FILE} "$HOME/Library/MobileDevice/Provisioning Profiles/$PROVISIONING_PROFILE_UUID.mobileprovision"
}

function findProfileInfo() {
    PROVISIONING_PROFILE_NAME=`/usr/libexec/plistbuddy -c Print:Name /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``
    DEVELOPMENT_TEAM=`/usr/libexec/plistbuddy -c Print:TeamIdentifier:0 /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``
}

function runPrescript() {
    if [ -n "${PRESCRIPT##+([[:space:]])}" ]; then
        echo "Run script " ${PRESCRIPT}
        eval ${PRESCRIPT}
    fi
}

function updateVersion() {
    if [ -n "${BUILD_VERSION##+([[:space:]])}" ]; then
        if [ -n "${INFOPLIST_PATH##+([[:space:]])}" ]; then
            defaults write "${INFOPLIST_PATH}" "CFBundleShortVersionString" "${BUILD_VERSION}"
        fi  
    fi
}

function archive() {
    if [[ ! -e "$BUILD_DIR" ]]; then
        mkdir "$BUILD_DIR"
    fi

    rm -rf "$BUILD_DIR"/*

    case "${WORKSPACE}" in
        *.xcworkspace)
            xcodebuild -workspace "${WORKSPACE}" -scheme "${SCHEME}" -sdk iphoneos -configuration ${CONFIGURATION} archive -archivePath "$BUILD_DIR/${SCHEME}.xcarchive" CODE_SIGN_STYLE="Manual" PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_NAME}" CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}";
        ;;
        *.xcodeproj)
            xcodebuild -project "${WORKSPACE}" -scheme "${SCHEME}" -sdk iphoneos -configuration ${CONFIGURATION} archive -archivePath "$BUILD_DIR/${SCHEME}.xcarchive" CODE_SIGN_STYLE="Manual" PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_NAME}" CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}";
        ;;
    esac
    if test $? -eq 0
        then
            echo "** ARCHIVE ${SCHEME} SUCCEEDED **"
        else
            echo "** ARCHIVE ${SCHEME} FAILED **"
            exit 1
    fi
}

function createExportOptions() {
    # create exportOptions
    rm -f exportOptions.plist
    ${SCRIPT_DIR}/gen_export_options.sh "${EXPORT_METHOD}" "${BUNDLEID}" "${PROVISIONING_PROFILE_NAME}" "${DEVELOPMENT_TEAM}" "$1"
}

function buildIPA() {
    createExportOptions exportOptions.plist;

    xcodebuild -exportArchive -archivePath "$BUILD_DIR/${SCHEME}.xcarchive" -exportOptionsPlist exportOptions.plist -exportPath "$BUILD_DIR"

    if test $? -eq 0
        then
            echo "** EXPORT ${SCHEME} SUCCEEDED **"
            mv "$BUILD_DIR/${SCHEME}.ipa" "$BUILD_DIR/${IPA_FILE_NAME}"
        else
            echo "** EXPORT ${SCHEME} FAILED **"
            exit 1
    fi

    rm -f exportOptions.plist
}

function cleanupTrap() {
    trap "cleanup;" EXIT
}

cleanupTrap;
checkParameters;
# getKeychainPassword;
importCertificate;
copyProvisioningProfile;
findProfileInfo;
runPrescript;
updateVersion;
archive;
buildIPA;

exit 0
