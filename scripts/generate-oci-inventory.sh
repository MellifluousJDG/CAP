#!/usr/bin/env bash

set -euo pipefail

IMAGE="${1:-cap:local}"
OUTDIR="${2:-oci-inventory}"
RUNTIME="${CONTAINER_RUNTIME:-podman}"

command -v "$RUNTIME" >/dev/null || {
    echo "Container runtime not found: $RUNTIME" >&2
    exit 1
}
mkdir -p "$OUTDIR"

"$RUNTIME" image inspect "$IMAGE" > "$OUTDIR/image-inspect.json"

"$RUNTIME" run --rm --entrypoint /bin/bash "$IMAGE" -c '
set -euo pipefail
printf "name,version,build,channel,license\n"
python3 - <<"PY"
import csv
import glob
import json
import sys

writer = csv.writer(sys.stdout, lineterminator="\n")
for path in sorted(glob.glob("/opt/cap-env/conda-meta/*.json")):
    with open(path, encoding="utf-8") as handle:
        item = json.load(handle)
    writer.writerow([
        item.get("name", ""),
        item.get("version", ""),
        item.get("build", ""),
        item.get("channel", ""),
        item.get("license", "UNKNOWN") or "UNKNOWN",
    ])
PY
' > "$OUTDIR/conda-packages.csv"

"$RUNTIME" run --rm --entrypoint /bin/bash "$IMAGE" -c '
set -euo pipefail
printf "package,version\n"
dpkg-query -W -f="\${Package},\${Version}\\n" | LC_ALL=C sort
' > "$OUTDIR/debian-packages.csv"

"$RUNTIME" run --rm --entrypoint /bin/bash "$IMAGE" -c '
set -euo pipefail
printf "component,revision_or_hash,license_expression,license_or_notice_file\n"
printf "CAP,%s,%s,%s\n" \
    "$(sha256sum /opt/CAP/main.nf | cut -d" " -f1)" \
    "MIT" \
    "/opt/CAP/LICENSE"
printf "BCT_ctw-calc,%s,%s,%s\n" \
    "$(sha256sum /opt/CAP/bin/ctw-calc | cut -d" " -f1)" \
    "GPL-2.0-only OR GPL-3.0-only (provisional)" \
    "/opt/CAP/bin/src/BCT/NOTICE"
printf "TRASH_2,%s,%s,%s\n" \
    "$(sha256sum /opt/CAP/modules/TRASH_2/src/TRASH.R | cut -d" " -f1)" \
    "See bundled license" \
    "/opt/CAP/modules/TRASH_2/license.txt"
printf "model,%s,%s,%s\n" \
    "$(sha256sum /opt/CAP/model/centromeric_model_v2.pkl | cut -d" " -f1)" \
    "Client-authorized distribution" \
    "UNCONFIRMED"
' > "$OUTDIR/embedded-components.csv"

(
    cd "$OUTDIR"
    sha256sum image-inspect.json conda-packages.csv debian-packages.csv \
        embedded-components.csv > SHA256SUMS
)

echo "OCI inventory written to $OUTDIR"
