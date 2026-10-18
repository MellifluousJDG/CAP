#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE=${1:-}
[ -n "$IMAGE" ] || {
    echo "Usage: $0 path/to/CAP-x86_64.AppImage" >&2
    exit 1
}
IMAGE="$(cd -- "$(dirname -- "$IMAGE")" && pwd)/$(basename -- "$IMAGE")"
[ -x "$IMAGE" ] || {
    echo "AppImage is not executable: $IMAGE" >&2
    exit 1
}
[ -f "$IMAGE.sha256" ] || {
    echo "Checksum file missing: $IMAGE.sha256" >&2
    exit 1
}
(cd -- "$(dirname -- "$IMAGE")" && sha256sum --check "$(basename -- "$IMAGE").sha256")

TEST_DIR="${APPIMAGE_TEST_DIR:-$PROJECT_DIR/build/appimage/artifact-test}"
RUNTIME="$TEST_DIR/runtime"
RESULTS="$TEST_DIR/results"
WORK="$TEST_DIR/work"
HOME_DIR="$TEST_DIR/home"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/extract" "$TEST_DIR/cwd" "$HOME_DIR"
(
    cd "$TEST_DIR/extract"
    "$IMAGE" --appimage-extract >/dev/null
    mv squashfs-root "$RUNTIME"
)

export APPDIR="$RUNTIME"
export HOME="$HOME_DIR"
"$RUNTIME/AppRun" --shell -c '
    set -e
    for command in nextflow java Rscript python3 mafft nhmmer; do
        command -v "$command" >/dev/null
    done
    test "$(Rscript -e "cat(R.home())")" = "$APPDIR/usr/lib/R"
    Rscript -e "library(Biostrings); library(GenomicRanges); library(msa)"
    python3 -c "import sklearn, xgboost; assert sklearn.__version__ == '\''1.7.2'\''; assert xgboost.__version__ == '\''3.0.5'\''"
    test -x "$APPDIR/usr/lib/cap/bin/ctw-calc"
    test ! -e "$APPDIR/usr/lib/cap/modules/TRASH_2/dep/hmmer"
    test ! -e "$APPDIR/usr/lib/cap/modules/TRASH_2/dep/mafft-7.520-win64-signed"
'

cd "$TEST_DIR/cwd"
"$RUNTIME/AppRun" \
    --assembly "$PROJECT_DIR/test/ath_Chr1_extraction_trc.fasta" \
    --cores 1 \
    --outdir "$RESULTS" \
    -work-dir "$WORK"
file_count=$(find "$RESULTS" -maxdepth 1 -type f | wc -l)
test "$file_count" -eq 16 || {
    echo "Expected 16 outputs, found $file_count." >&2
    exit 1
}
find "$RESULTS" -maxdepth 1 -type f -name '*.png' -size +0c \
    -print -quit | grep -q .
grep -v '[.]png$' "$PROJECT_DIR/test/expected-results.sha256" \
    > "$TEST_DIR/expected-non-png.sha256"
(cd "$RESULTS" && sha256sum --check "$TEST_DIR/expected-non-png.sha256")

echo "AppImage artifact test passed: relocated runtime, 16 outputs, and all 15 non-PNG hashes match."
