#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
NEXTFLOW_CONFIG="$PROJECT_DIR/nextflow.config"

if grep -Eq "executor[[:space:]]*=[[:space:]]*['\"]slurm['\"]" \
    "$NEXTFLOW_CONFIG"; then
    echo "nextflow.config must not submit individual processes to SLURM." >&2
    exit 1
fi
if grep -Eq '^[[:space:]]*slurm[[:space:]]*\{' "$NEXTFLOW_CONFIG"; then
    echo "nextflow.config must not define a SLURM profile." >&2
    exit 1
fi

echo "Nextflow execution-policy checks passed."
