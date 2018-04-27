#!/bin/sh

#  autobuild.sh
#  
#
#  Created by nguyen.van.hung on 4/19/18.
#  

echo ""
echo "Usage: autobuild.sh WORKSPACE SCHEME CONFIGURATION VERSION"
echo ""
echo ""

WORKSPACE=$1
SCHEME=$2
CONFIGURATION=$3
VERSION=$4
BUILD_DIR=${PWD}/build
PROVISIONING_PROFILE_FILE=Mixi_Dev.mobileprovision
PROVISIONING_CERT=Certificates_En_Dev.p12
CERT_PASSWORD=""
PROVISIONING_PROFILE_UUID=""
TEMP_KEYCHAIN=$HOME/Library/Keychains/xcodebuild.keychain
TEMP_KEYCHAIN_PASSWORD=12345678
CODE_SIGN_IDENTITY="iPhone Developer: Hung Nguyen (C6DJV9RX9F)"

shopt -s extglob  # more powerful pattern matching

function checkParameters() {
    if ! [ -n "${WORKSPACE##+([[:space:]])}" ]; then
        echo "You must provide WORKSPACE"
        exit 1
    else
        echo "Building workspace ${WORKSPACE}"
    fi

    if ! [ -n "${SCHEME##+([[:space:]])}" ]; then
        echo "You must provide SCHEME"
        exit 1
    else
        echo "Building scheme ${SCHEME}"
    fi

    if ! [ -n "${CONFIGURATION##+([[:space:]])}" ]; then
        CONFIGURATION='In-House'
        echo "Using default configuration ${CONFIGURATION}"
    fi

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

function deleteKeychain() {
    echo "Delete keychain"
    security delete-keychain ${TEMP_KEYCHAIN}
    security list-keychains -s $HOME/Library/Keychains/login.keychain
    security default-keychain -s $HOME/Library/Keychains/login.keychain
}

function importCertificate() {
    security create-keychain -p "" ${TEMP_KEYCHAIN}
    security add-certificates -k ${TEMP_KEYCHAIN}
    security list-keychains -s ${TEMP_KEYCHAIN}
    security default-keychain -s ${TEMP_KEYCHAIN}
    security unlock-keychain -p "" ${TEMP_KEYCHAIN}
    security import $PROVISIONING_CERT -P "$CERT_PASSWORD" -A -k ${TEMP_KEYCHAIN} -T /usr/bin/codesign -T /usr/bin/xcodebuild -T /usr/bin/security
    security set-keychain-settings -t 3000 ${TEMP_KEYCHAIN}
    security set-key-partition-list -S apple-tool:,apple: -s -k "" ${TEMP_KEYCHAIN}

    IOS_IDENTITY=$(security find-identity -v -p codesigning "${TEMP_KEYCHAIN}" | head -1 | grep '"' | sed -e 's/[^"]*"//' -e 's/".*//')
    IOS_UUID=$(security find-identity -v -p codesigning "${TEMP_KEYCHAIN}" | head -1 | grep '"' | awk '{print $2}')

    echo "iOS identity: " ${IOS_IDENTITY}
    echo "iOS UUID: " ${IOS_UUID}

    trap "deleteKeychain;" EXIT
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

function buildIPA() {
    PROVISIONING_PROFILE_NAME=`/usr/libexec/plistbuddy -c Print:Name /dev/stdin <<< \`security cms -D -i ${PROVISIONING_PROFILE_FILE}\``

    xcodebuild -exportArchive -archivePath ${PWD}/build/${SCHEME}.xcarchive -exportOptionsPlist exportOptions.plist -exportPath ${PWD}/build

    if test $? -eq 0
        then
            echo "** EXPORT ${SCHEME} SUCCEEDED **"
            mv ${PWD}/build/${SCHEME}.ipa ${PWD}/build/${SCHEME}.${VERSION}.ipa 
        else
            echo "** EXPORT ${SCHEME} FAILED **"
            exit 1
    fi
}

checkParameters;
getKeychainPassword;
importCertificate;
copyProvisioningProfile;
archive;
buildIPA;

exit 0
