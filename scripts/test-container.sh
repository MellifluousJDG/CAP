#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$PROJECT_DIR/Dockerfile"
IGNORE_FILE="$PROJECT_DIR/.dockerignore"
ENTRYPOINT="$PROJECT_DIR/scripts/cap-container-entrypoint.sh"

required_dockerfile_text=(
    'ARG DEBIAN_IMAGE=docker.io/library/debian@sha256:'
    'ARG MINICONDA_SHA256='
    'ARG CAP_REVISION=UNSPECIFIED'
    'ARG TRASH_2_REVISION=UNSPECIFIED'
    'org.opencontainers.image.licenses="MIT AND (GPL-2.0-only OR GPL-3.0-only)"'
    'COPY conda-runtime-linux-64.lock /tmp/conda-runtime-linux-64.lock'
    'conda create --yes --prefix /opt/cap-env'
    '--override-channels'
    'make -C bin/src/BCT'
    'COPY --from=env-builder /opt/cap-env /opt/cap-env'
    'COPY --from=ctw-builder --chown=cap:cap /opt/CAP/bin/ctw-calc'
    'USER cap'
    'ENTRYPOINT ["/usr/local/bin/cap"]'
)
for text in "${required_dockerfile_text[@]}"; do
    grep -F -- "$text" "$DOCKERFILE" >/dev/null || {
        echo "Dockerfile requirement missing: $text" >&2
        exit 1
    }
done

if grep -Eq 'micromamba|environment\.yml|git clone|curl[^#]*get\.nextflow|conda run|conda activate' \
    "$DOCKERFILE" "$ENTRYPOINT"; then
    echo "Dockerfile bypasses the tested lock/source inputs." >&2
    exit 1
fi

for ignored in '.git' '.nextflow' 'work' 'work_*' 'results' 'results_*' \
    'bin/ctw-calc' 'modules/TRASH_2/dep/hmmer' \
    'modules/TRASH_2/dep/mafft-7.520-win64-signed' \
    'modules/TRASH_2/dep/new.hor' 'modules/TRASH_2/temp'; do
    grep -Fx -- "$ignored" "$IGNORE_FILE" >/dev/null || {
        echo ".dockerignore requirement missing: $ignored" >&2
        exit 1
    }
done

grep -F 'exec nextflow run "$CAP_DIR" "$@"' "$ENTRYPOINT" >/dev/null
bash -n "$ENTRYPOINT" \
    "$PROJECT_DIR/scripts/test-container-image.sh" \
    "$PROJECT_DIR/scripts/generate-oci-inventory.sh" \
    "$PROJECT_DIR/scripts/generate-oci-compliance-bundle.sh"
python3 - <<PY
from pathlib import Path
compile(
    Path("$PROJECT_DIR/scripts/classify-source-obligations.py").read_text(),
    "classify-source-obligations.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/collect-conda-sources.py").read_text(),
    "collect-conda-sources.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/apply-source-review-policy.py").read_text(),
    "apply-source-review-policy.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/collect-conda-notices.py").read_text(),
    "collect-conda-notices.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/collect-debian-sources.py").read_text(),
    "collect-debian-sources.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/collect-conda-notice-sources.py").read_text(),
    "collect-conda-notice-sources.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/collect-conda-source-notices.py").read_text(),
    "collect-conda-source-notices.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/finalize-conda-source-notices.py").read_text(),
    "finalize-conda-source-notices.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/generate-cyclonedx-sbom.py").read_text(),
    "generate-cyclonedx-sbom.py",
    "exec",
)
compile(
    Path("$PROJECT_DIR/scripts/review-sbom-coverage.py").read_text(),
    "review-sbom-coverage.py",
    "exec",
)
PY
bash "$PROJECT_DIR/scripts/test-source-obligations.sh"
python3 "$PROJECT_DIR/scripts/test-source-review-policy.py"
bash "$PROJECT_DIR/scripts/test-collect-conda-sources.sh"
bash "$PROJECT_DIR/scripts/test-collect-conda-notices.sh"
python3 "$PROJECT_DIR/scripts/test-collect-debian-sources.py"
bash "$PROJECT_DIR/scripts/test-conda-source-notices.sh"
bash "$PROJECT_DIR/scripts/test-sbom.sh"

runtime_lock="$PROJECT_DIR/conda-runtime-linux-64.lock"
full_lock="$PROJECT_DIR/conda-linux-64.lock"
test -s "$runtime_lock"
while IFS= read -r package_url; do
    grep -Fqx "$package_url" "$full_lock" || {
        echo "Runtime lock URL is absent from the validated full lock: $package_url" >&2
        exit 1
    }
done < <(grep '^https://' "$runtime_lock")
for build_package in gcc_impl_linux-64 gxx_impl_linux-64 \
    gfortran_impl_linux-64 binutils_impl_linux-64 cmake make git; do
    if grep -Eq "/${build_package}-[0-9]" "$runtime_lock"; then
        echo "Build package present in runtime lock: $build_package" >&2
        exit 1
    fi
done

test -f "$PROJECT_DIR/modules/TRASH_2/src/TRASH.R" || {
    echo "TRASH_2 submodule is not initialized." >&2
    exit 1
}
for license_file in \
    "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" \
    "$PROJECT_DIR/TODO.md" \
    "$PROJECT_DIR/docs/DEPENDENCY_SOURCE_REVIEW.md" \
    "$PROJECT_DIR/bin/src/BCT/NOTICE" \
    "$PROJECT_DIR/licenses/GPL-2.0.txt" \
    "$PROJECT_DIR/licenses/GPL-3.0.txt"; do
    test -s "$license_file" || {
        echo "Required licensing file missing or empty: $license_file" >&2
        exit 1
    }
done

echo "OCI container static checks passed."
