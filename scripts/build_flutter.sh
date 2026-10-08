#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# SC BUILD - FLUTTER BUILD WORKER
# WEB TO APK BY DUTA
# ============================================================

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
BUILD_TYPE="${BUILD_TYPE:-release}"
LOG_FILE="${PROJECT_DIR}/flutter_build.log"

mkdir -p "${PROJECT_DIR}"

touch "${LOG_FILE}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo
echo "============================================"
echo " WEB TO APK BY DUTA"
echo " FLUTTER BUILD WORKER"
echo "============================================"
echo "Project : ${PROJECT_DIR}"
echo "Command : ${1:-}"
echo "Build   : ${BUILD_TYPE}"
echo "Flutter : $(flutter --version 2>/dev/null | head -n 1 || true)"
echo "============================================"
echo

# ------------------------------------------------------------
# ERROR HANDLER
# ------------------------------------------------------------

FAILED=0

trap 'FAILED=$?; echo; echo "============================================"; echo " BUILD SCRIPT ERROR"; echo " EXIT CODE: ${FAILED}"; echo "============================================"; echo; exit ${FAILED}' ERR

# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

die() {
    echo
    echo "::error::$1"
    echo
    exit 1
}

require_file() {
    if [ ! -f "$1" ]; then
        die "File tidak ditemukan: $1"
    fi
}

require_dir() {
    if [ ! -d "$1" ]; then
        die "Folder tidak ditemukan: $1"
    fi
}

# ------------------------------------------------------------
# CHECK PROJECT
# ------------------------------------------------------------

check_project() {
    echo "Checking Flutter project..."

    require_file "${PROJECT_DIR}/pubspec.yaml"
    require_dir "${PROJECT_DIR}/android"

    echo "pubspec.yaml : OK"
    echo "android/     : OK"

    if [ ! -f "${PROJECT_DIR}/android/gradlew" ]; then
        echo "gradlew belum ada."
    else
        chmod +x "${PROJECT_DIR}/android/gradlew"
    fi

    echo
}

# ------------------------------------------------------------
# GRADLE WRAPPER
# ------------------------------------------------------------

fix_gradle_wrapper() {
    local PROPERTIES="${PROJECT_DIR}/android/gradle/wrapper/gradle-wrapper.properties"

    echo "Checking Gradle wrapper..."

    if [ ! -f "${PROPERTIES}" ]; then
        echo "gradle-wrapper.properties tidak ditemukan."
        echo "Mencoba generate/update wrapper..."
        return 0
    fi

    local CURRENT_URL
    CURRENT_URL="$(grep -E '^distributionUrl=' "${PROPERTIES}" || true)"

    echo "Current:"
    echo "${CURRENT_URL:-unknown}"

    # Flutter sekarang membutuhkan minimal 8.14.x pada base
    # yang sebelumnya gagal di worker.
    local MIN_MAJOR=8
    local MIN_MINOR=14

    local VERSION=""
    if [[ "${CURRENT_URL}" =~ gradle-([0-9]+\.[0-9]+(\.[0-9]+)?)- ]]; then
        VERSION="${BASH_REMATCH[1]}"
    fi

    if [ -z "${VERSION}" ]; then
        echo "Versi Gradle tidak bisa dideteksi."
        echo "Menetapkan Gradle 8.14.3."
        VERSION="8.14.3"
    fi

    local MAJOR
    local MINOR

    MAJOR="$(echo "${VERSION}" | cut -d. -f1)"
    MINOR="$(echo "${VERSION}" | cut -d. -f2)"

    echo "Detected Gradle: ${VERSION}"

    local NEED_UPDATE=0

    if [ "${MAJOR}" -lt "${MIN_MAJOR}" ]; then
        NEED_UPDATE=1
    elif [ "${MAJOR}" -eq "${MIN_MAJOR}" ] && [ "${MINOR}" -lt "${MIN_MINOR}" ]; then
        NEED_UPDATE=1
    fi

    if [ "${NEED_UPDATE}" -eq 1 ]; then
        echo
        echo "Gradle ${VERSION} terlalu lama."
        echo "Updating Gradle wrapper to 8.14.3..."

        sed -i \
            's#distributionUrl=.*#distributionUrl=https\\://services.gradle.org/distributions/gradle-8.14.3-bin.zip#' \
            "${PROPERTIES}"

        echo "Gradle wrapper updated."
    else
        echo "Gradle version OK."
    fi

    echo
    grep -E '^distributionUrl=' "${PROPERTIES}" || true
    echo
}

# ------------------------------------------------------------
# ANDROID PREPARE
# ------------------------------------------------------------

prepare_android() {
    echo "Preparing Android project..."

    require_dir "${PROJECT_DIR}/android"

    if [ -f "${PROJECT_DIR}/android/gradlew" ]; then
        chmod +x "${PROJECT_DIR}/android/gradlew"
    fi

    # Hapus cache/build sementara dari base agar tidak membawa
    # state build yang rusak dari komputer pembuat ZIP.
    rm -rf \
        "${PROJECT_DIR}/build" \
        "${PROJECT_DIR}/.dart_tool" \
        "${PROJECT_DIR}/android/.gradle" \
        "${PROJECT_DIR}/android/build" \
        2>/dev/null || true

    echo "Temporary build state cleaned."

    fix_gradle_wrapper

    echo "Android project ready."
    echo
}

# ------------------------------------------------------------
# FLUTTER PREPARE
# ------------------------------------------------------------

prepare_flutter() {
    echo "Preparing Flutter project..."

    cd "${PROJECT_DIR}"

    flutter config --no-analytics >/dev/null 2>&1 || true

    echo
    echo "Flutter doctor:"
    flutter doctor -v || true

    echo
    echo "Checking pubspec..."
    flutter pub get

    echo
    echo "Flutter project preparation completed."
}

# ------------------------------------------------------------
# BUILD
# ------------------------------------------------------------

build_apk() {
    cd "${PROJECT_DIR}"

    case "${BUILD_TYPE}" in
        release)
            echo "Building RELEASE APK..."
            flutter build apk \
                --release \
                --no-tree-shake-icons
            ;;

        debug)
            echo "Building DEBUG APK..."
            flutter build apk \
                --debug
            ;;

        *)
            echo "Unknown BUILD_TYPE=${BUILD_TYPE}"
            echo "Using release."
            flutter build apk \
                --release \
                --no-tree-shake-icons
            ;;
    esac

    echo
    echo "APK search:"
    find "${PROJECT_DIR}/build/app/outputs" \
        -type f \
        -name "*.apk" \
        -print 2>/dev/null || true

    APK="$(find "${PROJECT_DIR}/build/app/outputs" \
        -type f \
        -name "*.apk" \
        -print \
        | sort \
        | head -n 1 || true)"

    if [ -z "${APK}" ]; then
        echo
        echo "BUILD selesai tetapi APK tidak ditemukan."
        exit 1
    fi

    echo
    echo "============================================"
    echo " BUILD SUCCESS"
    echo "============================================"
    echo "APK:"
    echo "${APK}"
    echo

    ls -lh "${APK}"
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

COMMAND="${1:-prepare}"

case "${COMMAND}" in

    prepare)
        check_project
        prepare_android
        prepare_flutter
        ;;

    build)
        check_project
        build_apk
        ;;

    all)
        check_project
        prepare_android
        prepare_flutter
        build_apk
        ;;

    clean)
        echo "Cleaning Flutter project..."

        rm -rf \
            "${PROJECT_DIR}/build" \
            "${PROJECT_DIR}/.dart_tool" \
            "${PROJECT_DIR}/android/.gradle" \
            "${PROJECT_DIR}/android/build"

        echo "Clean completed."
        ;;

    *)
        echo "Usage:"
        echo "  build_flutter.sh prepare"
        echo "  build_flutter.sh build"
        echo "  build_flutter.sh all"
        echo "  build_flutter.sh clean"
        exit 2
        ;;
esac

echo
echo "============================================"
echo " SCRIPT FINISHED"
echo "============================================"
