#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

fake_conda="$TMP_DIR/conda"
cat > "$fake_conda" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
shift 3
exec "$@"
EOF
chmod +x "$fake_conda"

CAP_CONDA_EXE="$fake_conda" \
CAP_ENV_NAME=unused \
    bash "$PROJECT_DIR/scripts/build-ctw.sh" > "$TMP_DIR/build.log"
grep -Fq "ctw-calc compiled and passed its execution smoke test." \
    "$TMP_DIR/build.log"

workflow_dir="$TMP_DIR/workflow"
mkdir -p "$workflow_dir/bin"
cp "$PROJECT_DIR/bin/CTW.R" "$workflow_dir/bin/CTW.R"
cat > "$workflow_dir/bin/ctw-calc" <<'EOF'
#!/usr/bin/env bash
exit 126
EOF
chmod +x "$workflow_dir/bin/ctw-calc"

set +e
WORKFLOW_DIR="$workflow_dir" \
    Rscript "$workflow_dir/bin/CTW.R" \
    "$PROJECT_DIR/test/ath_Chr1_extraction_trc.fasta" \
    "$TMP_DIR/output.csv" > "$TMP_DIR/ctw.out" 2>&1
status=$?
set -e

if [ "$status" -eq 0 ]; then
    echo "CTW.R unexpectedly succeeded with a failing binary and no BCT package." >&2
    exit 1
fi
grep -Fq "ctw-calc exists but failed to execute" "$TMP_DIR/ctw.out"
if grep -Fq "ctw-calc binary not found" "$TMP_DIR/ctw.out"; then
    echo "CTW.R incorrectly reported the failing binary as absent." >&2
    exit 1
fi

echo "CTW build and failure-diagnostic tests passed."
