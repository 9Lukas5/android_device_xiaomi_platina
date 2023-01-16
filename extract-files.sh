#!/bin/bash
#
# Copyright (C) 2018 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=platina
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

function blob_fixup() {
    case "${1}" in

    lib64/libwfdnative.so)
        "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
        ;;

    vendor/lib/hw/camera.sdm660.so)
        "${PATCHELF}" --add-needed camera.sdm660_shim.so "${2}"
        ;;

    vendor/lib64/libril-qc-hal-qmi.so)
        "${PATCHELF}" --replace-needed "libprotobuf-cpp-full.so" "libprotobuf-cpp-full-v29.so" "${2}"
        ;;

    lib/libwfdaudioclient.so)
        "${PATCHELF}" --set-soname "libwfdaudioclient.so" "${2}"
        ;;
    lib/libwfdmediautils.so)
        "${PATCHELF}" --set-soname "libwfdmediautils.so" "${2}"
        ;;
    lib/libwfdmmsink.so)
        "${PATCHELF}" --add-needed "libwfdaudioclient.so" "${2}"
        "${PATCHELF}" --add-needed "libwfdmediautils.so" "${2}"
        ;;

    esac

    device_blob_fixup "$@"
}

if ! typeset -f device_blob_fixup > /dev/null; then
    device_blob_fixup() {
        :
    }
fi

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

DEVICE_BLOB_ROOT="$ANDROID_ROOT"/vendor/"$VENDOR"/"$DEVICE"/proprietary

"${MY_DIR}/setup-makefiles.sh"
