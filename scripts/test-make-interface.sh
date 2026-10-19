#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$PROJECT_DIR"

mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/conda" <<'EOF'
#!/usr/bin/env bash
echo "make clean unexpectedly invoked conda" >&2
exit 99
EOF
chmod +x "$TMP_DIR/bin/conda"

set +e
PATH="$TMP_DIR/bin:$PATH" make clean >"$TMP_DIR/clean.log" 2>&1
status=$?
set -e

if [ "$status" -eq 0 ]; then
    echo "make clean unexpectedly succeeded." >&2
    exit 1
fi
if [ "$status" -eq 99 ]; then
    cat "$TMP_DIR/clean.log" >&2
    exit 1
fi

for text in \
    "make clean' is intentionally disabled" \
    "make remove-env" \
    "make clean-build" \
    "make clean-appimage"; do
    if ! grep -Fq "$text" "$TMP_DIR/clean.log"; then
        echo "make clean output is missing: $text" >&2
        cat "$TMP_DIR/clean.log" >&2
        exit 1
    fi
done

if grep -Fq -- "--branch reproducible-conda-pipeline" README.md; then
    echo "README still instructs users to clone a merged feature branch." >&2
    exit 1
fi

if [ "$(grep -Fc 'git clone --recurse-submodules' README.md)" -lt 2 ]; then
    echo "README clone examples do not use the default branch recursively." >&2
    exit 1
fi

echo "Make interface safety test passed."
