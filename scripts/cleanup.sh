#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " SC BUILD • CLEANUP"
echo "======================================"

rm -rf \
    source.zip \
    project.zip \
    extracted \
    output \
    apk_output \
    .dart_tool \
    build \
    2>/dev/null || true

find . -type f \
    \( -name "*.log" -o -name "*.tmp" \) \
    -delete \
    2>/dev/null || true

echo "Cleanup selesai."
