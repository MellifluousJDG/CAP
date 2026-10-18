#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILDER="$PROJECT_DIR/scripts/appimage/build-appimage.sh"
APPRUN="$PROJECT_DIR/scripts/appimage/AppRun"
RSCRIPT="$PROJECT_DIR/scripts/appimage/Rscript"
ARTIFACT_TEST="$PROJECT_DIR/scripts/appimage/test-built-appimage.sh"
DESKTOP="$PROJECT_DIR/scripts/appimage/cap.desktop"
ICON="$PROJECT_DIR/scripts/appimage/cap.svg"
MAKEFILE="$PROJECT_DIR/Makefile"
IGNORE="$PROJECT_DIR/.gitignore"

bash -n "$BUILDER" "$APPRUN" "$RSCRIPT" "$ARTIFACT_TEST"

for text in \
    'MINICONDA_SHA256=dda3629462ba1cfa72eb74535214c2e315c77f1cfb0f02046537e99f1bf64abc' \
    'b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2' \
    'conda-runtime-linux-64.lock' \
    'git submodule update --init --recursive' \
    'git -C "$PROJECT_DIR" archive' \
    'git -C "$PROJECT_DIR/modules/TRASH_2" archive' \
    'APPIMAGE_EXTRACT_AND_RUN=1' \
    'sha256sum "$output"'; do
    grep -F -- "$text" "$BUILDER" >/dev/null || {
        echo "AppImage builder requirement missing: $text" >&2
        exit 1
    }
done

if grep -Eq 'environment\.yml|conda env create|git clone' "$BUILDER"; then
    echo "AppImage builder bypasses locked checked-out inputs." >&2
    exit 1
fi

for text in \
    'exec nextflow run "$CAP_DIR" "$@"' \
    'NXF_BIN=' \
    'NXF_HOME=' \
    'MAFFT_BINARIES=' \
    'R_HOME='; do
    grep -F -- "$text" "$APPRUN" >/dev/null || {
        echo "AppRun requirement missing: $text" >&2
        exit 1
    }
done
for text in \
    'PREFIX="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"' \
    'R_EXEC="$R_HOME/bin/exec/R"' \
    '"--file=$script" --args'; do
    grep -F -- "$text" "$RSCRIPT" >/dev/null || {
        echo "Relocatable Rscript requirement missing: $text" >&2
        exit 1
    }
done
if grep -F '/home/' "$RSCRIPT" >/dev/null; then
    echo "Relocatable Rscript contains a host path." >&2
    exit 1
fi

for path in "$DESKTOP" "$ICON"; do
    test -s "$path" || {
        echo "Required AppImage metadata missing: $path" >&2
        exit 1
    }
done
for target in appimage test-appimage clean-appimage; do
    grep -Eq "^${target}:" "$MAKEFILE" || {
        echo "Make target missing: $target" >&2
        exit 1
    }
done
for ignored in '/build/appimage/' '/dist/*.AppImage' '/dist/*.AppImage.sha256'; do
    grep -Fx -- "$ignored" "$IGNORE" >/dev/null || {
        echo ".gitignore requirement missing: $ignored" >&2
        exit 1
    }
done

test "$(uname -m)" = x86_64 || {
    echo "Static AppImage checks require Linux x86-64." >&2
    exit 1
}
test -f "$PROJECT_DIR/modules/TRASH_2/src/TRASH.R" || {
    echo "TRASH_2 submodule is not initialized." >&2
    exit 1
}

echo "AppImage static checks passed."
