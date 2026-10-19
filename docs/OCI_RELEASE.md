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
