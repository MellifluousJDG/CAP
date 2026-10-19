#!/usr/bin/env python3

from __future__ import annotations

import csv
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).with_name("validate-compliance-bundle.py")
with tempfile.TemporaryDirectory() as directory:
    bundle = Path(directory) / "bundle"
    files = {
        "RELEASE-METADATA.txt": "cap_revision=test\n",
        "source-obligations-reviewed.csv": "name,collect_source\na,yes\n",
        "source/conda-all/source-to-binary.csv": "package,collected_path\na,a\n",
        "source/debian/source-files.csv": "source_package,filename\na,a\n",
        "notices/conda/conda-notice-manifest.csv": "name,notice_status\na,embedded\n",
        "notices/conda-source/final-review.csv": (
            "name,final_resolution\na,source-license-files\n"
        ),
        "sbom/cap-primary.cdx.json": "{}\n",
    }
    for name, content in files.items():
        path = bundle / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    with (bundle / "SHA256SUMS").open("w") as handle:
        for path in sorted(p for p in bundle.rglob("*") if p.is_file()):
            if path.name == "SHA256SUMS":
                continue
            result = subprocess.check_output(["sha256sum", str(path)], text=True)
            handle.write(result.split()[0] + "  " + path.relative_to(bundle).as_posix() + "\n")
    subprocess.run([str(script), str(bundle)], check=True)
    policy = bundle / "source-obligations-reviewed.csv"
    policy.write_text("name,collect_source\na,REVIEW\n")
    failed = subprocess.run([str(script), str(bundle)], capture_output=True, text=True)
    assert failed.returncode != 0
    assert "unresolved" in failed.stderr
print("Compliance bundle validator test passed.")
