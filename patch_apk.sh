#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "usage: $0 [device-type]"
	exit 1
fi

device_type=$1

if ! [[ "$device_type" =~ ^((0x[0-9a-fA-F]+)|([0-9]+))$ ]]; then
	echo "device type must be a valid number."
fi

function log {
	echo -e "\e[1m[$0] $1\e[0m"
}

log "Cleaning up old files"
rm -rf \
	arcore-preview2_patched_apk \
	arcore-preview2-patched-unsigned.apk \
	arcore-preview2-patched-unsigned-aligned.apk \
	arcore-preview2-patched-signed.apk

log "Extracting apk"
apktool -q d -s -r arcore-preview2.apk -o arcore-preview2_patched_apk || exit 1

log "Patching libdevice_profile_loader.so using radare2, our lord and savior"
radare2 -w arcore-preview2_patched_apk/lib/arm64-v8a/libdevice_profile_loader.so -q -c "\"wa movz x0, $device_type;ret\" @ 0x000496a4" || exit 1

log "Re-building apk"
apktool -q b arcore-preview2_patched_apk -o arcore-preview2-patched-unsigned.apk || exit 1

if [ ! -f keystore.jks ]; then
	log "Keystore does not exist. Creating a new one."
	keytool -genkeypair -keystore keystore.jks -storepass 123456 -keypass 123456 -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown"
fi

log "Signing apk"
zipalign -p 4 arcore-preview2-patched-unsigned.apk arcore-preview2-patched-unsigned-aligned.apk || exit 1
apksigner sign -ks keystore.jks --ks-pass pass:123456 --key-pass pass:123456 --out arcore-preview2-patched-signed.apk arcore-preview2-patched-unsigned-aligned.apk || exit 1

log "Verifying apk"
apksigner verify arcore-preview2-patched-signed.apk || exit 1

log "Success! Now install arcore-preview2-patched-signed.apk on your device!"
