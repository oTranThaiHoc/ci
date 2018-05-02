#!/bin/sh

#  autobuild.sh
#
#
#  Created by nguyen.van.hung on 4/19/18.
#

echo ""
echo "Usage: autobuild.sh CONFIG_FILE"
echo ""
echo ""

CONFIG_FILE=$1

if ! [ -f "$CONFIG_FILE" ]; then
    echo "$CONFIG_FILE not found."
    exit 1
fi

WORKSPACE=$(defaults read ${CONFIG_FILE} workspace)
SCHEME=$(defaults read ${CONFIG_FILE} scheme)
CONFIGURATION=$(defaults read ${CONFIG_FILE} configuration)
PROVISIONING_PROFILE_FILE=$(defaults read ${CONFIG_FILE} mobileprovision)
PROVISIONING_CERT=$(defaults read ${CONFIG_FILE} p12)
EXPORT_METHOD=$(defaults read ${CONFIG_FILE} exportmethod)
BUNDLEID=$(defaults read ${CONFIG_FILE} bundleid)
VERSION=$(defaults read ${CONFIG_FILE} version)

CERT_PASSWORD=""
PROVISIONING_PROFILE_UUID=""
TEMP_KEYCHAIN=$HOME/Library/Keychains/xcodebuild.keychain
TEMP_KEYCHAIN_PASSWORD=""
CODE_SIGN_IDENTITY=""
BUILD_DIR=${PWD}/build

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

    # check version, default 1.0.0
    if ! [ -n "${VERSION##+([[:space:]])}" ]; then
        VERSION='1.0.0'
        echo "Using default version ${VERSION}"
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
    # Copy the profile to the location XCode expects to find it and start the build,
    # specifying which profile and signing identity to use for the archived app
    #
    cp -f ${PROVISIONING_PROFILE_FILE} "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
    #
    # Extract the profile UUID from the checked in Provisioning Profile.
    #
    PROVISIONING_PROFILE_UUID=`/usr/libexec/plistbuddy -c Print:UUID /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``
}

function archive() {
    if [[ ! -e $BUILD_DIR ]]; then
        mkdir $BUILD_DIR
    fi

    rm -rf ${PWD}/build/*
    PROVISIONING_PROFILE_NAME=`/usr/libexec/plistbuddy -c Print:Name /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``

    xcodebuild -workspace ${WORKSPACE} -scheme ${SCHEME} -sdk iphoneos -configuration ${CONFIGURATION} archive -archivePath ${PWD}/build/${SCHEME}.xcarchive CODE_SIGN_STYLE="Manual" PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_NAME}" CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}";
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
    PROVISIONING_PROFILE_NAME=`/usr/libexec/plistbuddy -c Print:Name /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``
    ${PWD}/gen_export_options.sh "${EXPORT_METHOD}" "${BUNDLEID}" "${PROVISIONING_PROFILE_NAME}" "$1"
}

function buildIPA() {
    createExportOptions exportOptions.plist;

    xcodebuild -exportArchive -archivePath ${PWD}/build/${SCHEME}.xcarchive -exportOptionsPlist exportOptions.plist -exportPath ${PWD}/build

    if test $? -eq 0
        then
            echo "** EXPORT ${SCHEME} SUCCEEDED **"
            mv ${PWD}/build/${SCHEME}.ipa ${PWD}/build/${SCHEME}.${VERSION}.ipa
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
archive;
buildIPA;

exit 0
