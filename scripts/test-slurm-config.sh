#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_NAME="${CAP_ENV_NAME:-cap-pipeline}"
ASSEMBLY="${ASSEMBLY:-test/ath_Chr1_extraction_trc.fasta}"
SITE_CONFIG="conf/slurm-site.example.config"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "Conda environment '$ENV_NAME' does not exist; run make install first." >&2
    exit 1
fi

cd "$PROJECT_DIR"

if [ ! -f "$ASSEMBLY" ]; then
    echo "Assembly FASTA not found: $ASSEMBLY" >&2
    exit 1
fi

if [ ! -f "$SITE_CONFIG" ]; then
    echo "SLURM site configuration example not found: $SITE_CONFIG" >&2
    exit 1
fi

conda run -n "$ENV_NAME" nextflow config . -profile slurm -o flat \
    > "$tmp_dir/default.config"

# `nextflow config` has no `-c` option. Compose a disposable project config
# to validate the same direct process overrides used by the documented file.
cp "$PROJECT_DIR/nextflow.config" "$tmp_dir/nextflow.config"
cat "$PROJECT_DIR/$SITE_CONFIG" >> "$tmp_dir/nextflow.config"
(
    cd "$tmp_dir"
    conda run -n "$ENV_NAME" nextflow config . -profile slurm -o flat
) > "$tmp_dir/site.config"

assert_line() {
    local expected=$1
    local file=$2
    if ! grep -Fqx "$expected" "$file"; then
        echo "Expected configuration line not found: $expected" >&2
        echo "Resolved configuration: $file" >&2
        exit 1
    fi
}

assert_line "process.executor = 'slurm'" "$tmp_dir/default.config"
assert_line "process.queue = null" "$tmp_dir/default.config"
assert_line "process.clusterOptions = null" "$tmp_dir/default.config"
assert_line "process.time = null" "$tmp_dir/default.config"
assert_line "process.memory = '4 GB'" "$tmp_dir/default.config"

if grep -q '^process\.conda' "$tmp_dir/default.config"; then
    echo "The SLURM profile unexpectedly enables Nextflow-managed Conda." >&2
    exit 1
fi

assert_line "process.executor = 'slurm'" "$tmp_dir/site.config"
assert_line "process.queue = 'your-partition'" "$tmp_dir/site.config"
assert_line "process.clusterOptions = '--account=your-project-account'" \
    "$tmp_dir/site.config"
assert_line "process.time = '24h'" "$tmp_dir/site.config"
assert_line "process.memory = '16 GB'" "$tmp_dir/site.config"

conda run -n "$ENV_NAME" nextflow run . \
    -profile slurm \
    -preview \
    --assembly "$ASSEMBLY" \
    --slurm_queue test-partition \
    --slurm_account test-account \
    --slurm_time 1h \
    --slurm_memory '4 GB' \
    > "$tmp_dir/preview.log" 2>&1

if grep -q '^executor >' "$tmp_dir/preview.log"; then
    echo "Preview unexpectedly started process execution." >&2
    exit 1
fi

echo "SLURM configuration test passed without submitting scheduler jobs."
