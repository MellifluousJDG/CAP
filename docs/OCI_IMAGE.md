# OCI container image

CAP's OCI image contains the complete locked Linux x86-64 runtime: CAP, its
pinned TRASH_2 submodule, Nextflow, Java, R/Bioconductor, Python packages,
MAFFT, HMMER, model files, and the compiled CTW/BCT executable.

## Reproducibility model

The build uses three pinned inputs:

- the Debian Bookworm slim base image is selected by OCI digest;
- the Miniconda installer has a fixed version and verified SHA-256 checksum;
- `conda-runtime-linux-64.lock` is a tested subset of the exact development
  lock containing only runtime packages.

The bundled CTW/BCT source under `bin/src/BCT` identifies its upstream at
https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees. CAP
provisionally treats that source and `ctw-calc` as
`GPL-2.0-only OR GPL-3.0-only`; see `THIRD_PARTY_NOTICES.md`. Client
confirmation from the upstream rightsholder remains a pre-publication TODO.

The pinned TRASH_2 revision tracks Windows-only MAFFT/HMMER bundles and
historical output under `temp/`. They are excluded from the Linux image by
`.dockerignore`: Linux runs the exact locked Conda MAFFT/HMMER packages instead.
The image retains TRASH_2's R source, MIT-style license, and Linux `HOR.V3.3`
component.

Conda is used only while building the image to materialize `/opt/cap-env`.
The runtime lock retains exact package URLs from `conda-linux-64.lock` while
omitting compilers, headers, build tools, Git, and their implementation
packages. OpenMPI remains because the locked HMMER build links to
`libmpi.so.40`. The runtime lock is not independently re-solved, which prevents
validated runtime versions from drifting. The runtime stage puts
`/opt/cap-env/bin` on `PATH`; Nextflow does not activate, solve, or manage an
environment at runtime. CTW/BCT is compiled in a separate stage with the pinned
Debian base's native compiler so its glibc requirement cannot exceed the
runtime base.

The Dockerfile requires Linux x86-64 because the lock contains `linux-64`
packages. Build from a recursive Git clone so `modules/TRASH_2` is populated.
Source archives without Git submodule contents are unsupported.

## Build

Run the static checks first:

```bash
make test-container
```

Build with Docker:

```bash
docker build --platform linux/amd64 \
  --build-arg CAP_REVISION="$(git rev-parse HEAD)" \
  --build-arg TRASH_2_REVISION="$(git rev-parse HEAD:modules/TRASH_2)" \
  -t cap:local .
```

Or with Podman:

```bash
podman build --platform linux/amd64 \
  --build-arg CAP_REVISION="$(git rev-parse HEAD)" \
  --build-arg TRASH_2_REVISION="$(git rev-parse HEAD:modules/TRASH_2)" \
  -t cap:local .
```

The build needs network access to download the verified Miniconda installer and
the exact package URLs in the runtime lock. Build release images only from a
clean recursive checkout; otherwise the revision labels do not identify the
copied source tree. Normal container execution does not install or download CAP
dependencies.

## Run

Create host directories and mount input read-only while keeping results and
Nextflow work writable:

```bash
mkdir -p results work
podman run --rm --userns=keep-id \
  -v "$PWD/data:/data:ro" \
  -v "$PWD/results:/results" \
  -v "$PWD/work:/work" \
  cap:local \
  --assembly /data/genome.fasta \
  --outdir /results \
  -work-dir /work/nextflow
```

Replace `podman` with `docker` for Docker, omitting Podman's
`--userns=keep-id`. The image runs as non-root user `cap` (UID/GID 1000).
`--userns=keep-id` was validated with rootless Podman and keeps bind-mounted
results and work files owned by the invoking host user. Without it, those files
may appear under a subordinate UID and require `podman unshare` to manage.
Docker users should normally add `--user "$(id -u):$(id -g)"` and provide a
writable `HOME`/`NXF_HOME`; see `docs/OCI_HPC.md` for the command shape.

Optional CAP parameters, including `--te_gff`, `--gene_gff`, `--metadata`,
`--trash2`, and `--cores`, follow the normal workflow interface. Do not select
the Nextflow `docker` profile: the whole workflow is already running inside the
CAP image.

For diagnostics, open a shell in the image with:

```bash
podman run --rm --userns=keep-id -it cap:local --shell
```

For cluster execution, see `docs/OCI_HPC.md`. For image tags, GHCR publication,
archives, inventories, and the release checklist, see `docs/OCI_RELEASE.md`.
SBOM coverage, scanner limitations, and validation evidence are documented in
`docs/SBOM_REVIEW.md`.

## Inventory

Generate an image inventory with either Podman or Docker:

```bash
scripts/generate-oci-inventory.sh cap:local oci-inventory
CONTAINER_RUNTIME=docker scripts/generate-oci-inventory.sh \
  cap:local oci-inventory-docker
```

The script records image configuration, Conda packages and declared licenses,
Debian packages, embedded component hashes, and checksums for the inventory.
These files support review but are not a substitute for a standard SPDX or
CycloneDX SBOM from a tool such as Syft.

Generate the external compliance bundle in a path outside the repository:

```bash
scripts/generate-oci-compliance-bundle.sh \
  cap:local ../cap-compliance-bundle
```

The bundle adds repository and submodule revisions, exact Conda artifact URLs,
tracked license material, BCT corresponding source, a GPL/LGPL-family
source-obligation review manifest, and whole-bundle checksums. It always
produces a CycloneDX 1.6 primary SBOM from the exact Conda, Debian, and embedded
component inventories, then fails if any expected identity is missing. If Syft
is installed, it additionally produces SPDX JSON and CycloneDX JSON deep scans.
Syft discovers file-level and language-ecosystem components but does not
represent the Conda environment as 186 exact Conda package identities, so those
outputs supplement rather than replace the primary inventory SBOM. Pass the
documented revision build arguments so image labels contain the intended
revisions; the generator uses local Git as a fallback when available. To
include a Zstandard-compressed OCI archive, use:

```bash
INCLUDE_OCI_ARCHIVE=1 scripts/generate-oci-compliance-bundle.sh \
  cap:local ../cap-compliance-bundle-with-image
```

The bundle generator deliberately does not guess third-party source URLs or
claim that binary package URLs satisfy corresponding-source obligations.
Review and add exact source archives and mappings before public distribution.

## Validation and publication

A candidate release image must pass `scripts/test-container-image.sh` inside a
clean container before publication. The test requires 16 nonempty outputs and
checks exact hashes for all 15 non-PNG outputs. The PNG is not byte-compared
because font discovery and rasterization can vary with the base OS even when R
packages are locked; it must still be present and nonempty. Record the image's
immutable OCI digest and generate an SBOM and license inventory. Public registry
publication and release archives must wait until redistribution terms for all
bundled dependencies and the model have been reviewed.
