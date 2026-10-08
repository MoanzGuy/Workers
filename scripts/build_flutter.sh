#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-build}"

echo "======================================"
echo " SC BUILD • FLUTTER ENGINE"
echo " MODE: ${MODE}"
echo "======================================"

prepare_gradle() {
    if [ ! -f "android/gradle/wrapper/gradle-wrapper.properties" ]; then
        echo "Gradle wrapper tidak ditemukan."
        return 0
    fi

    FILE="android/gradle/wrapper/gradle-wrapper.properties"

    CURRENT="$(
        grep -oE 'gradle-[0-9]+\.[0-9]+(\.[0-9]+)?-' "$FILE" \
        | head -n 1 \
        | sed -E 's/gradle-//;s/-$//' \
        || true
    )"

    echo "Gradle wrapper saat ini: ${CURRENT:-unknown}"

    if [ -z "$CURRENT" ]; then
        return 0
    fi

    REQUIRED="8.14.0"

    if dpkg --compare-versions "$CURRENT" lt "$REQUIRED"; then
        echo "Gradle terlalu lama."
        echo "Upgrade ${CURRENT} -> ${REQUIRED}"

        sed -i \
          -E \
          's#gradle-[0-9]+\.[0-9]+(\.[0-9]+)?-#gradle-8.14.0-#' \
          "$FILE"

        echo "Gradle wrapper diperbaiki."
    else
        echo "Gradle wrapper sudah memenuhi minimum."
    fi
}

prepare_android() {
    if [ ! -d "android" ]; then
        echo "::error::Folder android tidak ditemukan."
        exit 1
    fi

    prepare_gradle

    if [ -f "android/gradlew" ]; then
        chmod +x android/gradlew || true
    fi
}

clean_project() {
    echo "Membersihkan project..."

    flutter clean || true

    rm -rf \
        .dart_tool \
        build \
        .gradle \
        android/.gradle \
        android/app/build \
        android/build \
        2>/dev/null || true
}

prepare_dependencies() {
    echo "Menyiapkan dependency..."

    flutter pub get
}

build_apk() {
    BUILD_TYPE="${BUILD_TYPE:-release}"

    echo "Build type: ${BUILD_TYPE}"

    if [ "$BUILD_TYPE" = "debug" ]; then
        flutter build apk --debug
    else
        flutter build apk --release
    fi
}

case "$MODE" in

    prepare)
        prepare_android
        ;;

    clean)
        clean_project
        ;;

    dependencies)
        prepare_android
        prepare_dependencies
        ;;

    build)
        prepare_android

        mkdir -p .

        set +e

        if [ "${BUILD_TYPE:-release}" = "debug" ]; then
            flutter build apk --debug 2>&1 | tee flutter_build.log
            STATUS="${PIPESTATUS[0]}"
        else
            flutter build apk --release 2>&1 | tee flutter_build.log
            STATUS="${PIPESTATUS[0]}"
        fi

        set -e

        if [ "$STATUS" -ne 0 ]; then
            echo "::error::Flutter build gagal."
            echo ""
            echo "===== LAST BUILD LOG ====="
            tail -120 flutter_build.log || true
            exit "$STATUS"
        fi
        ;;

    *)
        echo "Usage:"
        echo "  build_flutter.sh prepare"
        echo "  build_flutter.sh clean"
        echo "  build_flutter.sh dependencies"
        echo "  build_flutter.sh build"
        exit 1
        ;;

esac

echo "======================================"
echo " DONE"
echo "======================================"
