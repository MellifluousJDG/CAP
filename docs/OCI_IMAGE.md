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
https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees. The standalone
C++ repository has no separate explicit license notice, but the related BCT R
package published by the same author declares `GPL (>= 2)` in its CRAN metadata.
On that basis, CAP applies `GPL-2.0-or-later` to the adapted source and
`ctw-calc`; see `bin/src/BCT/README.md`.

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
environment at runtime. CTW/BCT is compiled in a separate build stage that uses
the same pinned Debian base as the final runtime image. This prevents the
executable from being built against a newer glibc version that would be missing
when the executable runs in the final image.

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
clean recursive checkout. The Dockerfile copies that checkout into `/opt/CAP`
in the image, while the build arguments record Git revisions in the image
labels. Local modifications or untracked files could therefore make the copied
source differ from the commits named by those labels. Normal container
execution does not install or download CAP dependencies.

## Run the published image

CAP 1.0.0 is public at:

```text
ghcr.io/mellifluousjdg/cap:1.0.0
ghcr.io/mellifluousjdg/cap@sha256:c6ec1c840e0a4184a249019b3ea317330754e5699f2550e009fe28b0729e889b
```

The tag is convenient and the digest selects the exact validated image. The
following rootless Podman example keeps input read-only and results/work
writable:

```bash
assembly=/path/to/genome.fasta
mkdir -p cap-run/data cap-run/results cap-run/work
cp "$assembly" cap-run/data/
assembly_name=$(basename "$assembly")
cd cap-run

image=ghcr.io/mellifluousjdg/cap:1.0.0
podman run --rm --userns=keep-id \
  -v "$PWD/data:/data:ro" \
  -v "$PWD/results:/results" \
  -v "$PWD/work:/work" \
  "$image" \
  --assembly "/data/$assembly_name" \
  --cores 1 \
  --outdir /results \
  -work-dir /work/nextflow
```

Final CSV, RDS, model, and
PNG files appear directly under `results/`. Nextflow intermediates are under
`work/nextflow` and may be removed after a successful run:

```bash
rm -rf work
podman image rm ghcr.io/mellifluousjdg/cap:1.0.0
```

The image runs as non-root user `cap` (UID/GID 1000). With rootless Podman,
`--userns=keep-id` was validated to keep bind-mounted output owned by the
invoking host user. On SELinux systems, add `:Z` to private mounts if policy
requires relabeling, for example `-v "$PWD/results:/results:Z"`. Do not add
`:Z` to shared directories without understanding the site's labeling policy.

For Docker, map the process to the host user and give Nextflow a writable home:

```bash
mkdir -p work/home results
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/home \
  -e NXF_HOME=/work/home/.nextflow \
  -v "$PWD/data:/data:ro" \
  -v "$PWD/results:/results" \
  -v "$PWD/work:/work" \
  ghcr.io/mellifluousjdg/cap:1.0.0 \
  --assembly /data/genome.fasta \
  --cores 1 \
  --outdir /results \
  -work-dir /work/nextflow
```

Docker was not available in the release environment, so this equivalent command
shape is documented but not release-tested. Optional CAP parameters, including
`--te_gff`, `--gene_gff`, `--metadata`, `--trash2`, and `--cores`, follow the
normal workflow interface. Do not select Nextflow's `docker` profile: the whole
workflow is already inside the CAP image.

### Diagnostics and troubleshooting

Display help or open an interactive shell:

```bash
podman run --rm ghcr.io/mellifluousjdg/cap:1.0.0 --help
podman run --rm --userns=keep-id -it \
  ghcr.io/mellifluousjdg/cap:1.0.0 --shell
```

Common problems:

- `No such file` for the assembly: ensure the host file is inside `data/` and
  use its exact basename as `/data/<basename>`.
- Permission denied under `results/` or `work/`: create both host directories
  before running, retain `--userns=keep-id`, and check SELinux labeling.
- Interrupted or failed execution: inspect `.nextflow.log` and retain
  `work/nextflow` for diagnosis; remove work only after success.
- A Nextflow version-check warning when offline is harmless; the bundled
  workflow and dependencies run without downloading packages.

The public digest was anonymously pulled with an empty credential file into an
empty Podman store. A one-core consumer run produced 16 files and matched all 15
deterministic non-PNG hashes; the PNG must be nonempty but its raster bytes may
vary with font/rendering details.

For cluster execution, see `docs/OCI_HPC.md`. For build details, inventories,
archives, and release procedure, see `docs/OCI_RELEASE.md`.

## Inventory

Generate an image inventory with either Podman or Docker:

```bash
scripts/compliance/generate-oci-inventory.sh cap:local oci-inventory
CONTAINER_RUNTIME=docker scripts/compliance/generate-oci-inventory.sh \
  cap:local oci-inventory-docker
```

The script records image configuration, Conda packages and declared licenses,
Debian packages, embedded component hashes, and checksums. These inventory
files are human-readable records of what the script found in the image and are
also inputs to the primary CycloneDX SBOM generated by the compliance-bundle
command below.

Generate the external compliance bundle in a path outside the repository:

```bash
scripts/compliance/generate-oci-compliance-bundle.sh \
  cap:local ../cap-compliance-bundle
```

The bundle adds repository and submodule revisions, exact Conda artifact URLs,
tracked license material, BCT corresponding source, a GPL/LGPL-family
source-obligation review manifest, and whole-bundle checksums. It always
produces a CycloneDX 1.6 primary SBOM directly from the exact Conda, Debian,
and embedded-component inventories. Conda records include package name, version,
and build string; Debian records include package name and version. Pass the
documented revision build arguments so image labels contain the intended
revisions; the generator compares those labels with the clean local checkout
and refuses to create a bundle if they differ. To include a Zstandard-compressed
OCI archive, use Podman and run:

```bash
CONTAINER_RUNTIME=podman INCLUDE_OCI_ARCHIVE=1 \
  scripts/compliance/generate-oci-compliance-bundle.sh \
  cap:local ../cap-compliance-bundle-with-image
```

Docker's `save` command creates a Docker archive rather than an OCI archive. If
a Docker archive is acceptable, create one separately:

```bash
docker image save -o cap.docker.tar cap:local
sha256sum cap.docker.tar > cap.docker.tar.sha256
```

To convert an image in the Docker daemon directly to an OCI archive, use a tool
such as Skopeo:

```bash
skopeo copy docker-daemon:cap:local \
  oci-archive:cap.oci.tar:cap:local
sha256sum cap.oci.tar > cap.oci.tar.sha256
```

The compliance-bundle script deliberately requires Podman when
`INCLUDE_OCI_ARCHIVE=1`; it does not silently substitute Docker's different
archive format.

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
bundled dependencies have been reviewed.
