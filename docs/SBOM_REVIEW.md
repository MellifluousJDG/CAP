# OCI SBOM review

This document records the SBOM design and validation performed against the
latest fully regression-tested CAP image available during release preparation.
Repeat every generation and review step against the final digest-pinned image;
the current validation image is not a publication candidate.

## Outputs

The compliance bundle always contains:

- `sbom/cap-primary.cdx.json`: CycloneDX 1.6 primary SBOM generated from the
  exact image inventories;
- `sbom/coverage-review.json`: strict identity and relationship coverage report.

When Syft is available, it additionally contains:

- `sbom/syft-deep-scan.spdx.json`: SPDX JSON deep scan;
- `sbom/syft-deep-scan.cdx.json`: CycloneDX JSON deep scan.

The primary SBOM records exact Conda name/version/build/channel/license fields,
exact Debian package/version fields, CAP, TRASH_2, BCT/CTW, and the model. Its
root component is CAP, with dependency references to every recorded component.
The generator uses the image creation time and stable UUIDv5 identifiers, so
identical inventories and image identity produce deterministic output.

## Why two kinds of SBOM are retained

Syft provides valuable file-level and language-ecosystem discovery. It found
Python, R/CRAN, Maven, Go, Debian, and individual-file components. It does not,
however, catalog the locked environment as exact Conda package identities.
Therefore, the Syft documents are supplemental deep scans and do not replace
the inventory-derived primary SBOM.

This division is explicit in `coverage-review.json`. The release process must
not interpret zero exact Conda overlap in the Syft scan as zero Conda packages
in the image.

## Validation results

The primary CycloneDX SBOM passed exact coverage review for:

- 186 of 186 Conda package identities;
- 91 of 91 Debian package identities;
- four of four embedded components: CAP, TRASH_2, BCT/CTW, and the model;
- unique component references and no dangling dependency references.

The supplemental Syft 1.54.0 scan contained 3,885 CycloneDX components and 273
SPDX packages. It matched all 91 exact Debian identities and zero exact Conda
identities, as expected from Syft's ecosystem cataloging behavior.

The primary document was also validated against the official CycloneDX 1.6 JSON
schema from:

```text
https://raw.githubusercontent.com/CycloneDX/specification/1.6/schema/bom-1.6.schema.json
```

Validation used `jsonschema` 4.25.1 in a transient container. Syft 1.54.0 was
downloaded from its official GitHub release, and its Linux AMD64 archive matched
the published SHA-256:

```text
54a87372498168b2d033e876fd41fa4e8035b872699e525a57046e1f2f09c860
```

## Limitations and final-release requirements

- Debian licenses are preserved in the separate exact copyright/source corpus;
  the primary Debian SBOM components do not guess one package-wide expression.
- Conda license fields reproduce exact package metadata and can be imprecise.
  Reviewed notices and source evidence remain authoritative supplements.
- The SBOM records components and direct containment relationships; it does not
  infer a complete runtime call graph among all packages.
- The model's authorization record and the provisional BCT/CTW license still
  require the release records described in `TODO.md`.
- Generate fresh documents after building the clean final image, validate the
  CycloneDX schema again, and archive the bundle checksum with the image digest.
