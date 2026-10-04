#!/usr/bin/env python3

"""Review CAP CycloneDX SBOM coverage against authoritative OCI inventories."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import urllib.parse


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def purl_identity(purl: str) -> tuple[str, str, str, str] | None:
    if not purl.startswith("pkg:"):
        return None
    body = purl[4:].split("#", 1)[0]
    body, _, query = body.partition("?")
    package_type, _, name_version = body.partition("/")
    name, separator, version = name_version.rpartition("@")
    if not separator:
        return None
    qualifiers = urllib.parse.parse_qs(query)
    return (
        package_type,
        urllib.parse.unquote(name.rsplit("/", 1)[-1]),
        urllib.parse.unquote(version),
        qualifiers.get("build", [""])[0],
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("inventory", type=Path)
    parser.add_argument("cyclonedx_sbom", type=Path)
    parser.add_argument("review_output", type=Path)
    parser.add_argument("--syft-cyclonedx", type=Path)
    parser.add_argument("--syft-spdx", type=Path)
    args = parser.parse_args()

    conda = read_csv(args.inventory / "conda-packages.csv")
    debian = read_csv(args.inventory / "debian-packages.csv")
    embedded = read_csv(args.inventory / "embedded-components.csv")
    sbom = json.loads(args.cyclonedx_sbom.read_text(encoding="utf-8"))
    if sbom.get("bomFormat") != "CycloneDX" or sbom.get("specVersion") != "1.6":
        raise SystemExit("SBOM is not CycloneDX 1.6")
    root = sbom.get("metadata", {}).get("component", {})
    components = sbom.get("components", [])
    all_components = [root, *components]
    references = [component.get("bom-ref", "") for component in all_components]
    if "" in references or len(references) != len(set(references)):
        raise SystemExit("SBOM contains missing or duplicate component references")

    identities = {
        identity for component in components
        if (identity := purl_identity(component.get("purl", ""))) is not None
    }
    expected_conda = {
        ("conda", row["name"], row["version"], row["build"]) for row in conda
    }
    expected_debian = {
        ("deb", row["package"], row["version"], "") for row in debian
    }
    actual_embedded = {root.get("name", "")} | {
        component.get("name", "") for component in components
        if component.get("name", "") in {row["component"] for row in embedded}
    }
    expected_embedded = {row["component"] for row in embedded}
    missing_conda = sorted(expected_conda - identities)
    missing_debian = sorted(expected_debian - identities)
    missing_embedded = sorted(expected_embedded - actual_embedded)
    unexpected_primary = sorted(
        identities - expected_conda - expected_debian
    )
    dependency_refs = {
        ref for dependency in sbom.get("dependencies", [])
        for ref in [dependency.get("ref", ""), *dependency.get("dependsOn", [])]
    }
    dangling_refs = sorted(dependency_refs - set(references))

    review: dict[str, object] = {
        "cyclonedx_spec_version": sbom.get("specVersion"),
        "expected_conda_components": len(expected_conda),
        "matched_conda_components": len(expected_conda & identities),
        "missing_conda_components": ["|".join(item) for item in missing_conda],
        "expected_debian_components": len(expected_debian),
        "matched_debian_components": len(expected_debian & identities),
        "missing_debian_components": ["|".join(item) for item in missing_debian],
        "expected_embedded_components": len(expected_embedded),
        "matched_embedded_components": len(expected_embedded & actual_embedded),
        "missing_embedded_components": missing_embedded,
        "unexpected_primary_package_identities": [
            "|".join(item) for item in unexpected_primary
        ],
        "duplicate_or_missing_bom_refs": len(references) - len(set(references)),
        "dangling_dependency_refs": dangling_refs,
    }

    if args.syft_cyclonedx:
        syft = json.loads(args.syft_cyclonedx.read_text(encoding="utf-8"))
        syft_components = syft.get("components", [])
        syft_identities = {
            identity for component in syft_components
            if (identity := purl_identity(component.get("purl", ""))) is not None
        }
        review["syft_cyclonedx_component_count"] = len(syft_components)
        review["syft_exact_conda_overlap"] = len(expected_conda & syft_identities)
        review["syft_exact_debian_overlap"] = len(expected_debian & syft_identities)
        review["syft_role"] = (
            "Supplemental deep file/ecosystem scan; authoritative Conda and "
            "embedded-component coverage comes from the primary inventory SBOM."
        )
    if args.syft_spdx:
        syft = json.loads(args.syft_spdx.read_text(encoding="utf-8"))
        review["syft_spdx_package_count"] = len(syft.get("packages", []))
        review["syft_spdx_relationship_count"] = len(syft.get("relationships", []))

    failures = (
        missing_conda or missing_debian or missing_embedded
        or unexpected_primary or dangling_refs
        or len(references) != len(set(references))
    )
    review["primary_coverage_status"] = "FAIL" if failures else "PASS"
    args.review_output.parent.mkdir(parents=True, exist_ok=True)
    args.review_output.write_text(
        json.dumps(review, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if failures:
        raise SystemExit("SBOM primary inventory coverage review failed")
    print(
        f"SBOM coverage passed: {len(expected_conda)} Conda, "
        f"{len(expected_debian)} Debian, {len(expected_embedded)} embedded"
    )


if __name__ == "__main__":
    main()
