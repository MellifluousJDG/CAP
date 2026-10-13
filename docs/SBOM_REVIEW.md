# OCI SBOM review

This document records the SBOM design and validation performed against the
latest fully regression-tested CAP image available during release preparation.
Repeat generation and schema validation against the final digest-pinned image;
the current validation image is not a publication candidate.

## Output

The compliance bundle contains `sbom/cap-primary.cdx.json`, a CycloneDX 1.6
SBOM generated directly from the exact image inventories.

The SBOM records Conda package name, version, build, channel, and declared
license fields; Debian package name and version; and CAP, TRASH_2, BCT/CTW, and
the model. Its root component is CAP, with dependency references to every
recorded component. The generator uses the image creation time and stable
UUIDv5 identifiers, so the same inventories and image digest or ID produce
deterministic output.

The generator rejects duplicate Conda name/version/build records, duplicate
Debian name/version records, and an embedded-component inventory without CAP.
Its fixture test checks representative Conda, Debian, embedded-component,
license, package-URL, and dependency output.

## Validation results

The candidate SBOM was generated from inventories containing:

- 186 Conda packages;
- 91 Debian packages;
- CAP, TRASH_2, BCT/CTW, and the model.

The document was validated against the official CycloneDX 1.6 JSON schema from:

```text
https://raw.githubusercontent.com/CycloneDX/specification/1.6/schema/bom-1.6.schema.json
```

Validation used `jsonschema` 4.25.1 in a transient container.

## Limitations and final-release requirements

- The SBOM is generated from the image inventories; schema validation confirms
  its structure but does not independently discover packages in the image.
- Debian licenses are preserved in the separate exact copyright/source corpus;
  the Debian SBOM components do not guess one package-wide expression.
- Conda license fields reproduce exact package metadata and can be imprecise.
  Reviewed notices and source evidence remain authoritative supplements.
- The SBOM records components and direct containment relationships; it does not
  infer a complete runtime call graph among all packages.
- The model's authorization record and the provisional BCT/CTW license require
  explicit external release records before public distribution.
- Generate and schema-validate a fresh document after building the clean final
  image, then archive it with the compliance-bundle checksum and image digest.
