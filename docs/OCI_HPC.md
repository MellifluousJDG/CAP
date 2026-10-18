# Running CAP containers on HPC systems

CAP's supported scheduler architecture uses one SLURM allocation for the whole
workflow. Nextflow keeps its local executor inside that allocation and must not
submit individual pipeline processes to SLURM.

```text
sbatch
└── one allocation on one node
    └── Docker, Podman, or Apptainer
        └── CAP image
            └── Nextflow local executor
```

Partition names, accounts, time limits, and filesystem paths are site-specific.
Supply them as `sbatch` options rather than hard-coding them in CAP.

## Before choosing a runtime

Ask the cluster administrators which container runtime is supported on compute
nodes. Docker is commonly prohibited because its daemon is privileged. Rootless
Podman may be available, while Apptainer/Singularity is the most common HPC
choice. Also determine whether compute nodes can reach GHCR; if not, pull or
convert the image in advance on a connected system.

The convenient release reference is
`ghcr.io/mellifluousjdg/cap:1.0.0`. For an exact immutable image, use
`ghcr.io/mellifluousjdg/cap@sha256:c6ec1c840e0a4184a249019b3ea317330754e5699f2550e009fe28b0729e889b`.

## Rootless Podman

Create a final-results directory on durable shared storage, and use node-local
storage for temporary Nextflow work:

```bash
#!/usr/bin/env bash
#SBATCH --cpus-per-task=4
#SBATCH --mem=36G

set -euo pipefail

image=ghcr.io/mellifluousjdg/cap:1.0.0
assembly=/shared/data/genome.fasta
outdir=/shared/results/genome-cap
work_root="${SLURM_TMPDIR:-${TMPDIR:-/tmp}}/cap-${SLURM_JOB_ID}"

mkdir -p "$outdir" "$work_root"
trap 'status=$?; if [ "$status" -eq 0 ]; then rm -rf "$work_root"; \
  else echo "Work retained at $work_root" >&2; fi; exit "$status"' EXIT

podman run --rm --userns=keep-id \
  -v "$(dirname "$assembly"):/data:ro" \
  -v "$outdir:/results" \
  -v "$work_root:/work" \
  "$image" \
  --assembly "/data/$(basename "$assembly")" \
  --outdir /results \
  --cores "${SLURM_CPUS_PER_TASK:-1}" \
  -work-dir /work/nextflow
```

`--userns=keep-id` is important for rootless Podman: it makes bind-mounted
outputs belong to the submitting host user instead of a subordinate UID.
SELinux-enabled hosts may require `:Z` on private bind mounts; consult the
cluster's container-runtime policy before relabeling shared paths.

## Docker

Use Docker only where administrators explicitly support it on compute nodes.
The command shape is similar, but map the runtime process to the submitting
user so bind-mounted outputs remain host-owned:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/home \
  -e NXF_HOME=/work/home/.nextflow \
  -v /shared/data:/data:ro \
  -v /shared/results/genome-cap:/results \
  -v "${SLURM_TMPDIR}/cap-work:/work" \
  ghcr.io/mellifluousjdg/cap:1.0.0 \
  --assembly /data/genome.fasta \
  --outdir /results \
  --cores "${SLURM_CPUS_PER_TASK:-1}" \
  -work-dir /work/nextflow
```

Create `/work/home` before launching if the container runtime does not create
it.

## Apptainer or Singularity

Because the image is public, a connected login or transfer node can normally
convert it to a SIF file:

```bash
apptainer pull cap-1.0.0.sif \
  docker://ghcr.io/mellifluousjdg/cap:1.0.0
```

Then copy the immutable SIF to shared storage and execute it in one allocation:

```bash
apptainer exec \
  --bind /shared/data:/data:ro \
  --bind /shared/results/genome-cap:/results \
  --bind "${SLURM_TMPDIR}/cap-work:/work" \
  cap-1.0.0.sif \
  /usr/local/bin/cap \
  --assembly /data/genome.fasta \
  --outdir /results \
  --cores "${SLURM_CPUS_PER_TASK:-1}" \
  -work-dir /work/nextflow
```

Apptainer does not necessarily honor an OCI image's entrypoint, so invoke
`/usr/local/bin/cap` explicitly.

## Offline transfer

For clusters without registry access, export an OCI archive on a connected
host:

```bash
podman save --format oci-archive \
  -o cap-1.0.0.oci.tar \
  ghcr.io/mellifluousjdg/cap:1.0.0
sha256sum cap-1.0.0.oci.tar > cap-1.0.0.oci.tar.sha256
```

Transfer both files, verify the checksum, and import with the cluster's
supported runtime. An OCI archive is not a substitute for an Apptainer SIF when
the cluster only supports Apptainer.
