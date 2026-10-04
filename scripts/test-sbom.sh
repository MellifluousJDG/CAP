#!/usr/bin/env bash

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/inventory"
cat > "$tmpdir/inventory/conda-packages.csv" <<EOF
name,version,build,channel,license
example,1.0,h123_0,https://conda.example/linux-64,MIT
example-r,2.0,r44_1,https://conda.example/noarch,GPL-3.0-only
EOF
cat > "$tmpdir/inventory/debian-packages.csv" <<EOF
package,version
base-files,12.4
libc6,2.36-9
EOF
a_hash="$(printf 'a%.0s' {1..64})"
b_hash="$(printf 'b%.0s' {1..64})"
c_hash="$(printf 'c%.0s' {1..64})"
d_hash="$(printf 'd%.0s' {1..64})"
cat > "$tmpdir/inventory/embedded-components.csv" <<EOF
component,revision_or_hash,license_expression,license_or_notice_file
CAP,$a_hash,MIT,/opt/CAP/LICENSE
BCT_ctw-calc,$b_hash,GPL-3.0-only,/opt/CAP/bin/src/BCT/NOTICE
TRASH_2,$c_hash,MIT,/opt/CAP/modules/TRASH_2/license.txt
model,$d_hash,Client-owned,/opt/CAP/THIRD_PARTY_NOTICES.md
EOF
cat > "$tmpdir/inventory/image-inspect.json" <<EOF
[{
  "Id": "0123", "Digest": "sha256:4567",
  "Created": "2026-01-01T00:00:00Z",
  "Architecture": "amd64", "Os": "linux"
}]
EOF
"$PROJECT_DIR/scripts/generate-cyclonedx-sbom.py" \
    "$tmpdir/inventory" "$tmpdir/sbom.json"
"$PROJECT_DIR/scripts/review-sbom-coverage.py" \
    "$tmpdir/inventory" "$tmpdir/sbom.json" "$tmpdir/review.json"
grep -F '"primary_coverage_status": "PASS"' "$tmpdir/review.json" >/dev/null
python3 - "$tmpdir/sbom.json" <<'PY'
import json,sys
path=sys.argv[1]
data=json.load(open(path))
data["components"]=[
    component for component in data["components"]
    if component.get("name") != "example"
]
open(path,"w").write(json.dumps(data))
PY
if "$PROJECT_DIR/scripts/review-sbom-coverage.py" \
    "$tmpdir/inventory" "$tmpdir/sbom.json" "$tmpdir/bad-review.json" \
    >/dev/null 2>&1; then
    echo "Coverage review accepted a missing component." >&2
    exit 1
fi
echo "CycloneDX SBOM generation and review test passed."
