#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$PROJECT_DIR/Dockerfile"
IGNORE_FILE="$PROJECT_DIR/.dockerignore"
ENTRYPOINT="$PROJECT_DIR/scripts/cap-container-entrypoint.sh"

required_dockerfile_text=(
    'ARG DEBIAN_IMAGE=docker.io/library/debian@sha256:'
    'ARG MINICONDA_SHA256='
    'COPY conda-linux-64.lock /tmp/conda-linux-64.lock'
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
    'bin/ctw-calc'; do
    grep -Fx -- "$ignored" "$IGNORE_FILE" >/dev/null || {
        echo ".dockerignore requirement missing: $ignored" >&2
        exit 1
    }
done

grep -F 'exec nextflow run "$CAP_DIR" "$@"' "$ENTRYPOINT" >/dev/null
bash -n "$ENTRYPOINT" "$PROJECT_DIR/scripts/test-container-image.sh"

test -f "$PROJECT_DIR/modules/TRASH_2/src/TRASH.R" || {
    echo "TRASH_2 submodule is not initialized." >&2
    exit 1
}

echo "OCI container static checks passed."
