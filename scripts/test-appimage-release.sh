#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PROJECT_DIR/scripts/appimage/build-appimage.sh"

grep -F 'appimage_version="${APPIMAGE_VERSION:-${cap_revision:0:7}}"' \
    "$SCRIPT" >/dev/null
grep -F 'APPIMAGE_VERSION must be a semantic version such as v1.0.1' \
    "$SCRIPT" >/dev/null
grep -F 'output="$OUTPUT_DIR/CAP-${appimage_version}-x86_64.AppImage"' \
    "$SCRIPT" >/dev/null
grep -F 'Release version: $appimage_version' "$SCRIPT" >/dev/null

echo "AppImage release naming checks passed."
