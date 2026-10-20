#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

appdir="$TMP_DIR/CAP.AppDir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/lib/cap"
cp "$PROJECT_DIR/scripts/appimage/AppRun" "$appdir/AppRun"
cat > "$appdir/usr/bin/nextflow" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$LD_LIBRARY_PATH"
EOF
chmod +x "$appdir/AppRun" "$appdir/usr/bin/nextflow"

actual=$(APPDIR="$appdir" LD_LIBRARY_PATH=/host/lib \
    "$appdir/AppRun" ignored)
expected="$appdir/usr/lib:/host/lib"
if [ "$actual" != "$expected" ]; then
    echo "AppRun did not prioritize the AppImage library directory." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
fi

echo "AppImage runtime library-path test passed."
