#!/usr/bin/env bash

set -euo pipefail

IMAGE="${1:-cap:local}"
OUTDIR="${2:-oci-compliance-bundle}"
RUNTIME="${CONTAINER_RUNTIME:-podman}"
GIT_COMMAND="${GIT_COMMAND:-git}"
INCLUDE_OCI_ARCHIVE="${INCLUDE_OCI_ARCHIVE:-0}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v "$RUNTIME" >/dev/null || {
    echo "Container runtime not found: $RUNTIME" >&2
    exit 1
}
git_available=0
if [[ "$GIT_COMMAND" == */* ]]; then
    [[ -x "$GIT_COMMAND" ]] && git_available=1
elif command -v "$GIT_COMMAND" >/dev/null; then
    git_available=1
fi

test ! -e "$OUTDIR" || {
    echo "Output path already exists: $OUTDIR" >&2
    exit 1
}
mkdir -p "$OUTDIR/inventory" "$OUTDIR/licenses" "$OUTDIR/source"

"$PROJECT_DIR/scripts/generate-oci-inventory.sh" \
    "$IMAGE" "$OUTDIR/inventory"

image_id="$($RUNTIME image inspect --format '{{.Id}}' "$IMAGE")"
image_digest="$($RUNTIME image inspect --format '{{index .RepoDigests 0}}' \
    "$IMAGE" 2>/dev/null || true)"
cap_revision="$($RUNTIME image inspect --format \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$IMAGE" 2>/dev/null || true)"
trash_revision="$($RUNTIME image inspect --format \
    '{{index .Config.Labels "org.cap-project.trash-2.revision"}}' \
    "$IMAGE" 2>/dev/null || true)"
if [[ "$git_available" == "1" ]]; then
    cap_revision="$($GIT_COMMAND -C "$PROJECT_DIR" rev-parse HEAD)"
    trash_revision="$($GIT_COMMAND -C "$PROJECT_DIR" \
        rev-parse HEAD:modules/TRASH_2)"
    if ! "$GIT_COMMAND" -C "$PROJECT_DIR" diff --quiet --ignore-submodules=none \
        || ! "$GIT_COMMAND" -C "$PROJECT_DIR" diff --cached --quiet \
            --ignore-submodules=none; then
        cap_revision="${cap_revision}-DIRTY"
    fi
fi
{
    printf 'image_reference=%s\n' "$IMAGE"
    printf 'image_id=%s\n' "$image_id"
    printf 'registry_digest=%s\n' "${image_digest:-UNAVAILABLE_FOR_LOCAL_IMAGE}"
    printf 'created_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'cap_revision=%s\n' "${cap_revision:-UNAVAILABLE}"
    printf 'trash_2_revision=%s\n' "${trash_revision:-UNAVAILABLE}"
} > "$OUTDIR/RELEASE-METADATA.txt"

cp "$PROJECT_DIR/LICENSE" "$OUTDIR/licenses/CAP-MIT.txt"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$OUTDIR/licenses/"
cp "$PROJECT_DIR/TODO.md" "$OUTDIR/licenses/"
cp "$PROJECT_DIR/docs/DEPENDENCY_SOURCE_REVIEW.md" "$OUTDIR/"
cp "$PROJECT_DIR/licenses/GPL-2.0.txt" "$OUTDIR/licenses/"
cp "$PROJECT_DIR/licenses/GPL-3.0.txt" "$OUTDIR/licenses/"
cp "$PROJECT_DIR/modules/TRASH_2/license.txt" \
    "$OUTDIR/licenses/TRASH_2-MIT.txt"

tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
    --numeric-owner -C "$PROJECT_DIR" -cJf \
    "$OUTDIR/source/BCT-corresponding-source.tar.xz" bin/src/BCT
sha256sum "$OUTDIR/source/BCT-corresponding-source.tar.xz" \
    > "$OUTDIR/source/BCT-corresponding-source.tar.xz.sha256"

"$RUNTIME" run --rm --interactive --entrypoint python3 "$IMAGE" - <<'PY' \
    > "$OUTDIR/inventory/conda-source-urls.csv"
import csv
import glob
import json
import sys

writer = csv.writer(sys.stdout, lineterminator="\n")
writer.writerow(["name", "version", "build", "license", "binary_url", "sha256"])
for path in sorted(glob.glob("/opt/cap-env/conda-meta/*.json")):
    with open(path, encoding="utf-8") as handle:
        item = json.load(handle)
    writer.writerow([
        item.get("name", ""),
        item.get("version", ""),
        item.get("build", ""),
        item.get("license", "UNKNOWN") or "UNKNOWN",
        item.get("url", ""),
        item.get("sha256", ""),
    ])
PY

test -s "$OUTDIR/inventory/conda-source-urls.csv" || {
    echo "Conda source URL inventory is empty." >&2
    exit 1
}
grep -q '^name,version,build,license,binary_url,sha256' \
    "$OUTDIR/inventory/conda-source-urls.csv"
"$PROJECT_DIR/scripts/classify-source-obligations.py" \
    "$OUTDIR/inventory/conda-source-urls.csv" \
    "$OUTDIR/source-obligations.csv"

if command -v syft >/dev/null; then
    syft "$IMAGE" -o spdx-json="$OUTDIR/sbom.spdx.json"
else
    printf '%s\n' \
        'Syft was unavailable; generate an SPDX or CycloneDX SBOM before release.' \
        > "$OUTDIR/SBOM-NOT-GENERATED.txt"
fi

if [[ "$INCLUDE_OCI_ARCHIVE" == "1" ]]; then
    command -v zstd >/dev/null || {
        echo "zstd is required when INCLUDE_OCI_ARCHIVE=1." >&2
        exit 1
    }
    archive="$OUTDIR/image.oci.tar.zst"
    "$RUNTIME" save --format oci-archive "$IMAGE" | \
        zstd -T0 -19 -o "$archive"
    sha256sum "$archive" > "$archive.sha256"
fi

cat > "$OUTDIR/README.txt" <<'EOF'
CAP OCI compliance bundle
=========================

This bundle records the image identity, package inventories, declared licenses,
repository revisions, and complete corresponding source for CAP's BCT-derived
ctw-calc executable. A revision ending in -DIRTY is not release-ready. Package
binary URLs identify exact Conda artifacts and are a starting point for
corresponding-source collection; they are not themselves source archives. Apply
scripts/apply-source-review-policy.py to source-obligations.csv, then run
scripts/collect-conda-sources.py against the reviewed CSV. Collect embedded
package notices with scripts/collect-conda-notices.py. Export and collect Debian
copyright/source evidence with scripts/export-debian-compliance-inputs.sh and
scripts/collect-debian-sources.py. These network-dependent collections are
external bundle steps, not part of basic bundle generation. The --conservative
option preserves all Conda candidates while review is pending; it does not
replace legal review. Obtain and preserve exact corresponding source for
packages whose licenses require it before public distribution.

An OCI archive is included only when INCLUDE_OCI_ARCHIVE=1. A standard SPDX or
CycloneDX SBOM is included only when Syft is installed. Resolve every item in
licenses/TODO.md before public release.
EOF

(
    cd "$OUTDIR"
    find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | \
        xargs -0 sha256sum > SHA256SUMS
)

echo "OCI compliance bundle written to $OUTDIR"
