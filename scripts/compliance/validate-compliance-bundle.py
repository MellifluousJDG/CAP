#!/usr/bin/env python3

"""Validate that a CAP compliance bundle is complete for publication."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import subprocess


def rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    required = [
        "RELEASE-METADATA.txt",
        "SHA256SUMS",
        "source-obligations-reviewed.csv",
        "source/conda-all/source-to-binary.csv",
        "source/debian/source-files.csv",
        "notices/conda/conda-notice-manifest.csv",
        "notices/conda-source/final-review.csv",
        "sbom/cap-primary.cdx.json",
    ]
    missing = [name for name in required if not (bundle / name).is_file()]
    if missing:
        raise SystemExit("Missing required bundle files: " + ", ".join(missing))

    policy = rows(bundle / "source-obligations-reviewed.csv")
    if not policy or any(row["collect_source"].lower() != "yes" for row in policy):
        raise SystemExit("Source-obligation review contains unresolved rows")
    review = rows(bundle / "notices/conda-source/final-review.csv")
    if not review or any(not row.get("final_resolution") for row in review):
        raise SystemExit("Conda source-notice review contains unresolved rows")

    manifests = list(bundle.rglob("SHA256SUMS"))
    if manifests != [bundle / "SHA256SUMS"]:
        raise SystemExit("Expected exactly one whole-bundle SHA256SUMS manifest")
    subprocess.run(
        ["sha256sum", "--check", "SHA256SUMS"],
        cwd=bundle,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    print(f"Compliance bundle publication checks passed: {bundle}")


if __name__ == "__main__":
    main()
