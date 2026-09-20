# OCI container image

CAP's OCI image contains the complete locked Linux x86-64 runtime: CAP, its
pinned TRASH_2 submodule, Nextflow, Java, R/Bioconductor, Python packages,
MAFFT, HMMER, model files, and the compiled CTW/BCT executable.

## Reproducibility model

The build uses three pinned inputs:

- the Debian Bookworm slim base image is selected by OCI digest;
- the Miniconda installer has a fixed version and verified SHA-256 checksum;
- `conda-linux-64.lock` lists the exact Conda package URLs.

Conda is used only while building the image to materialize `/opt/cap-env`.
The runtime stage copies that complete environment and puts its `bin` directory
on `PATH`. Nextflow therefore runs inside the already-created environment; it
does not activate, solve, or manage a Conda environment at runtime. CTW/BCT is
compiled in a separate stage with the pinned Debian base's native compiler so
its glibc requirement cannot exceed the runtime base.

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
docker build --platform linux/amd64 -t cap:local .
```

Or with Podman:

```bash
podman build --platform linux/amd64 -t cap:local .
```

The build needs network access to download the verified Miniconda installer and
the exact package URLs in the lock. Normal container execution does not install
or download CAP dependencies.

## Run

Create host directories and mount input read-only while keeping results and
Nextflow work writable:

```bash
mkdir -p results work
podman run --rm \
  -v "$PWD/data:/data:ro" \
  -v "$PWD/results:/results" \
  -v "$PWD/work:/work" \
  cap:local \
  --assembly /data/genome.fasta \
  --outdir /results \
  -work-dir /work/nextflow
```

Replace `podman` with `docker` for Docker. The image runs as non-root user
`cap` (UID/GID 1000), so mounted output directories must be writable by that
user. Rootless Podman commonly maps this user automatically; site policies may
require adjusting ownership or using an explicit runtime user.

Optional CAP parameters, including `--te_gff`, `--gene_gff`, `--metadata`,
`--trash2`, and `--cores`, follow the normal workflow interface. Do not select
the Nextflow `docker` profile: the whole workflow is already running inside the
CAP image.

For diagnostics, open a shell in the image with:

```bash
podman run --rm -it cap:local --shell
```

## Validation and publication

A candidate release image must pass `scripts/test-container-image.sh` inside a
clean container before publication. The test requires 16 nonempty outputs and
checks exact hashes for all 15 non-PNG outputs. The PNG is not byte-compared
because font discovery and rasterization can vary with the base OS even when R
packages are locked; it must still be present and nonempty. Record the image's
immutable OCI digest and generate an SBOM and license inventory. Public registry
publication and release archives must wait until redistribution terms for all
bundled dependencies and the model have been reviewed.
