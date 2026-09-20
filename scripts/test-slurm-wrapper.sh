#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WRAPPER="$PROJECT_DIR/scripts/run-cap-slurm.sh"
NEXTFLOW_CONFIG="$PROJECT_DIR/nextflow.config"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assembly="$tmp_dir/input genome.fasta"
outdir="$tmp_dir/results dir"
trash2="$tmp_dir/trash output"
mkdir -p "$trash2"
printf '>chr1\nACGT\n' > "$assembly"
printf 'repeat\n' > "$trash2/$(basename "$assembly")_repeats_with_seq.csv"
printf 'array\n' > "$trash2/$(basename "$assembly")_arrays.csv"

fake_conda="$tmp_dir/fake conda"
cat > "$fake_conda" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${FAKE_CONDA_ARGS:?}"
exit "${FAKE_CONDA_STATUS:-0}"
EOF
chmod +x "$fake_conda"

if grep -Eq "executor[[:space:]]*=[[:space:]]*['\"]slurm['\"]" \
    "$NEXTFLOW_CONFIG"; then
    echo "nextflow.config must not submit individual processes to SLURM." >&2
    exit 1
fi
if grep -Eq '^[[:space:]]*slurm[[:space:]]*\{' "$NEXTFLOW_CONFIG"; then
    echo "nextflow.config must not define a SLURM profile." >&2
    exit 1
fi

expect_failure() {
    expected=$1
    shift
    if "$@" > "$tmp_dir/failure.out" 2>&1; then
        echo "Command unexpectedly succeeded: $*" >&2
        exit 1
    fi
    grep -F -- "$expected" "$tmp_dir/failure.out" >/dev/null || {
        echo "Expected error not found: $expected" >&2
        cat "$tmp_dir/failure.out" >&2
        exit 1
    }
}

expect_failure "submit this script with sbatch" \
    bash "$WRAPPER" --assembly "$assembly" --outdir "$outdir" \
    --conda "$fake_conda"

expect_failure "--outdir is required" \
    env CAP_SLURM_LOCAL_TEST=1 bash "$WRAPPER" \
    --assembly "$assembly" --conda "$fake_conda"

expect_failure "invalid --trash2 directory" \
    env CAP_SLURM_LOCAL_TEST=1 bash "$WRAPPER" \
    --assembly "$assembly" --outdir "$outdir" \
    --trash2 "$tmp_dir" --conda "$fake_conda"

args_file="$tmp_dir/args.txt"
run_tmp="$tmp_dir/node tmp"
mkdir -p "$run_tmp"
FAKE_CONDA_ARGS="$args_file" \
CAP_SLURM_LOCAL_TEST=1 \
SLURM_CPUS_PER_TASK=4 \
SLURM_JOB_ID=1234 \
SLURM_TMPDIR="$run_tmp" \
bash "$WRAPPER" \
    --assembly "$assembly" \
    --outdir "$outdir" \
    --trash2 "$trash2" \
    --env-name test-cap \
    --conda "$fake_conda" \
    > "$tmp_dir/success.out"

grep -Fx -- "test-cap" "$args_file" >/dev/null
grep -Fx -- "--cores" "$args_file" >/dev/null
grep -Fx -- "4" "$args_file" >/dev/null
grep -Fx -- "--trash2" "$args_file" >/dev/null
grep -Fx -- "$trash2" "$args_file" >/dev/null
grep -Fx -- "-work-dir" "$args_file" >/dev/null
grep -Fx -- "$run_tmp/cap-nextflow-1234" "$args_file" >/dev/null
[ ! -e "$run_tmp/cap-nextflow-1234" ] || {
    echo "Successful run did not remove its temporary work directory." >&2
    exit 1
}

without_trash_args="$tmp_dir/without-trash.txt"
FAKE_CONDA_ARGS="$without_trash_args" \
CAP_SLURM_LOCAL_TEST=1 \
SLURM_JOB_ID=1235 \
SLURM_TMPDIR="$run_tmp" \
bash "$WRAPPER" \
    --assembly "$assembly" \
    --outdir "$outdir" \
    --conda "$fake_conda" \
    > "$tmp_dir/without-trash.out"
if grep -Fx -- "--trash2" "$without_trash_args" >/dev/null; then
    echo "Wrapper passed --trash2 when it was omitted." >&2
    exit 1
fi

failed_work="$run_tmp/cap-nextflow-1236"
expect_failure "CAP failed; Nextflow work directory retained at: $failed_work" \
    env FAKE_CONDA_ARGS="$tmp_dir/failed-args.txt" FAKE_CONDA_STATUS=9 \
    CAP_SLURM_LOCAL_TEST=1 SLURM_JOB_ID=1236 SLURM_TMPDIR="$run_tmp" \
    bash "$WRAPPER" --assembly "$assembly" --outdir "$outdir" \
    --conda "$fake_conda"
[ -d "$failed_work" ] || {
    echo "Failed run did not retain its work directory." >&2
    exit 1
}
rm -rf -- "$failed_work"

echo "Single-node SLURM wrapper tests passed without submitting a job."
