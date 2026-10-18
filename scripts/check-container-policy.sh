#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DOCKERFILE="$PROJECT_DIR/Dockerfile"
IGNORE_FILE="$PROJECT_DIR/.dockerignore"
ENTRYPOINT="$PROJECT_DIR/scripts/cap-container-entrypoint.sh"

required_dockerfile_text=(
    'ARG DEBIAN_IMAGE=docker.io/library/debian@sha256:'
    'ARG MINICONDA_SHA256='
    'ARG CAP_REVISION=UNSPECIFIED'
    'ARG TRASH_2_REVISION=UNSPECIFIED'
    'org.opencontainers.image.licenses="MIT AND GPL-2.0-or-later"'
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
    echo "Dockerfile or entrypoint bypasses the tested lock/source inputs." >&2
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
if grep -F 'image inspect "$IMAGE" >' \
    "$PROJECT_DIR/scripts/compliance/generate-oci-inventory.sh" >/dev/null; then
    echo "OCI inventory records the complete runtime-specific inspect output." >&2
    exit 1
fi
if grep -Eq 'sha256sum .* > .*\.sha256' \
    "$PROJECT_DIR/scripts/compliance/generate-oci-compliance-bundle.sh"; then
    echo "Compliance bundle generator creates a redundant checksum sidecar." >&2
    exit 1
fi

echo "Container source-policy checks passed."
