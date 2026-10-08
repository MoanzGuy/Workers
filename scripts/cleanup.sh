#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================"
echo " SC BUILD CLEANUP"
echo "============================================"

PROJECT_DIR="${PROJECT_DIR:-${GITHUB_WORKSPACE:-$(pwd)}/project}"

if [ ! -d "${PROJECT_DIR}" ]; then
    echo "Project directory belum ada:"
    echo "${PROJECT_DIR}"
    exit 0
fi

echo "Project: ${PROJECT_DIR}"

rm -rf \
    "${PROJECT_DIR}/.dart_tool" \
    "${PROJECT_DIR}/build" \
    "${PROJECT_DIR}/android/.gradle" \
    "${PROJECT_DIR}/android/build" \
    2>/dev/null || true

echo "Cleanup completed."
