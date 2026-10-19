# OCI image release and GHCR publication

GitHub Container Registry (GHCR) is an OCI registry. CAP images do not need to
be published to Docker Hub. The public image repository is:

```text
ghcr.io/mellifluousjdg/cap
```

CAP 1.0.0 is published under the immutable release tag and manifest digest:

```text
ghcr.io/mellifluousjdg/cap:1.0.0
ghcr.io/mellifluousjdg/cap@sha256:c6ec1c840e0a4184a249019b3ea317330754e5699f2550e009fe28b0729e889b
```

## Tag and digest policy

Published version tags are immutable. For each release, publish one full version
tag such as `1.1.0`; do not replace an existing version tag or rely on mutable
`latest`, major, or minor aliases. Documentation, release notes, and archived
validation records must also record the immutable manifest digest.

## Manual publication

Publish release images manually; do not configure automated registry pushes.
Create a GitHub personal access token with package write permission, then avoid
putting it on the command line or in shell history:

```bash
printf '%s' "$GHCR_TOKEN" | podman login ghcr.io \
  --username MellifluousJDG --password-stdin
```

Tag and push the tested release image, replacing `<version>` with the new version:

```bash
version=<version>
podman tag cap:local "ghcr.io/mellifluousjdg/cap:$version"
podman push "ghcr.io/mellifluousjdg/cap:$version"
```

After pushing, obtain and record the registry manifest digest. Do not confuse a
local image ID with the registry digest. Log out when finished:

```bash
podman logout ghcr.io
```

Set the GHCR package visibility deliberately in GitHub's package settings and
link the package to the CAP repository.

## Corresponding-source bundle

Generate the initial bundle from the final tested image as described in
`docs/OCI_IMAGE.md`, then complete the reviewed source and notice collection.
The following commands are intentionally explicit: generation requires network
access and can be lengthy, and each collector verifies downloaded checksums.

```bash
bundle=../cap-1.0.1-compliance-bundle
image=cap:local

scripts/compliance/apply-source-review-policy.py \
  "$bundle/source-obligations.csv" \
  "$bundle/source-obligations-reviewed.csv"
scripts/compliance/collect-conda-sources.py \
  "$bundle/source-obligations-reviewed.csv" \
  "$bundle/source/conda"
scripts/compliance/collect-conda-notices.py \
  "$bundle/inventory/conda-source-urls.csv" \
  "$bundle/notices/conda"
scripts/compliance/collect-conda-notice-sources.py \
  licenses/conda-notice-supplemental-sources.csv \
  "$bundle/source/conda-notice-supplemental"
```

Merge the two verified Conda corpora and their mappings without modifying the
primary or supplemental evidence:

```bash
scripts/compliance/merge-conda-source-corpora.py \
  "$bundle/source/conda" \
  "$bundle/source/conda-notice-supplemental" \
  "$bundle/source/conda-all"
```

Export the canonical R license texts from the exact image, resolve all reviewed
Conda notice gaps, and collect exact Debian sources:

```bash
mkdir "$bundle/notices/R-shared-licenses"
podman run --rm --entrypoint /bin/bash "$image" -c \
  'tar -C /opt/cap-env/lib/R/share/licenses -cf - .' | \
  tar -C "$bundle/notices/R-shared-licenses" -xf -
scripts/compliance/collect-conda-source-notices.py \
  "$bundle/notices/conda/conda-notice-manifest.csv" \
  "$bundle/source/conda-all/source-to-binary.csv" \
  "$bundle/source/conda-all" "$bundle/notices/conda-source" \
  --shared-license-dir "$bundle/notices/R-shared-licenses"
scripts/compliance/finalize-conda-source-notices.py \
  "$bundle/notices/conda-source/source-notice-manifest.csv" \
  licenses/conda-source-notice-review.csv \
  "$bundle/notices/R-shared-licenses" \
  "$bundle/notices/conda-source/final-review.csv"
scripts/compliance/export-debian-compliance-inputs.sh \
  "$image" "$bundle/debian-inputs"
scripts/compliance/collect-debian-sources.py \
  "$bundle/debian-inputs/binary-to-source.csv" \
  "$bundle/debian-inputs/installed-copyright.tar.gz" \
  "$bundle/source/debian"
scripts/compliance/finalize-compliance-checksums.sh "$bundle"
scripts/compliance/validate-compliance-bundle.py "$bundle"
```

The validator rejects unresolved reviewed policies or notices, requires the
complete source, notice, inventory, revision, and SBOM records, and verifies the
whole-bundle checksum manifest.

Create one deterministic Zstandard archive outside the checkout:

```bash
tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
  --numeric-owner -C "$(dirname "$bundle")" \
  -cf - "$(basename "$bundle")" | \
  zstd -T0 -19 -o ../cap-1.0.1-compliance-bundle.tar.zst
sha256sum ../cap-1.0.1-compliance-bundle.tar.zst
```

## Publish the corresponding source artifact

Authenticate ORAS without putting a token on the command line, then publish the
single tested archive under the immutable release version:

```bash
version=1.0.1
printf '%s' "$GHCR_TOKEN" | oras login ghcr.io \
  --username MellifluousJDG --password-stdin
oras push \
  --artifact-type application/vnd.cap.compliance-bundle.v1 \
  "ghcr.io/mellifluousjdg/cap-source:$version" \
  "../cap-$version-compliance-bundle.tar.zst:application/zstd"
oras logout ghcr.io
```

Record the returned manifest digest and archive SHA-256. Pull by digest into a
new directory, verify that the downloaded archive is byte-identical, and test
its complete checksum manifest before considering publication complete.

## Release artifacts

In addition to the registry image, preserve:

- the CAP Git tag and recursive submodule revision;
- the immutable GHCR digest;
- an immutable external compliance bundle from
  `scripts/compliance/generate-oci-compliance-bundle.sh`, including inventory files,
  revision records, BCT corresponding source, notices, and checksums;
- a CycloneDX 1.6 SBOM generated from the exact Conda, Debian, and
  embedded-component image inventories;
- exact corresponding-source archives and source-to-binary mappings required
  by bundled dependencies, following `docs/DEPENDENCY_SOURCE_REVIEW.md`;
- the validation log;
- optionally, a compressed OCI archive and SHA-256 checksum.

An OCI archive protects against registry loss but may be too large for GitHub's
normal release-asset limits. If so, store it in institutional archival storage
and publish its checksum and location in the release notes.

## Redistribution requirements

- Include CAP's root MIT license.
- Include the `bin/src/BCT` corresponding source and README, plus the GPL
  texts, with the compiled `ctw-calc`. The standalone BCT C++ repository has no
  separate explicit license notice; the related BCT R package published by the
  same author declares `GPL (>= 2)` in its CRAN metadata. On that basis, CAP
  applies `GPL-2.0-or-later` to the BCT-derived source and executable.
- Include TRASH_2's MIT-style `license.txt`. Its tracked Windows-only
  MAFFT/HMMER bundles and historical `temp/` outputs are excluded from the Linux
  image, which uses the locked Conda MAFFT/HMMER packages instead.
- Generate dependency inventories from the final image. If they differ from the
  reviewed candidate inventories, review the changed Conda and Debian packages
  and collect any additional notices or corresponding source before publication.
- Preserve the reviewed Conda notices and source mappings, plus the Debian
  copyright files, binary-to-source mappings, and corresponding source, in the
  external compliance bundle.
