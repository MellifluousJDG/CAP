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

These examples are templates, not proof of compatibility with a particular
cluster. CAP's real-cluster container validation remains outstanding.

## Rootless Podman

Prepare persistent output and use node-local storage for Nextflow work:

```bash
#!/usr/bin/env bash
#SBATCH --cpus-per-task=4
#SBATCH --mem=36G

set -euo pipefail

image=ghcr.io/mellifluousjdg/cap:VERSION
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
SELinux-enabled hosts may require `:Z` on private bind mounts; follow site
policy before adding it.

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
  ghcr.io/mellifluousjdg/cap:VERSION \
  --assembly /data/genome.fasta \
  --outdir /results \
  --cores "${SLURM_CPUS_PER_TASK:-1}" \
  -work-dir /work/nextflow
```

Create `/work/home` before launching if the site runtime does not create it.
This Docker HPC template is not yet tested because Docker is unavailable in the
current development environment.

## Apptainer or Singularity

After a public image is available, a connected login or transfer node can
normally convert it to a SIF file:

```bash
apptainer pull cap-VERSION.sif \
  docker://ghcr.io/mellifluousjdg/cap:VERSION
```

Then copy the immutable SIF to shared storage and execute it in one allocation:

```bash
apptainer exec \
  --bind /shared/data:/data:ro \
  --bind /shared/results/genome-cap:/results \
  --bind "${SLURM_TMPDIR}/cap-work:/work" \
  cap-VERSION.sif \
  /usr/local/bin/cap \
  --assembly /data/genome.fasta \
  --outdir /results \
  --cores "${SLURM_CPUS_PER_TASK:-1}" \
  -work-dir /work/nextflow
```

Apptainer does not necessarily honor an OCI image's entrypoint, so invoke
`/usr/local/bin/cap` explicitly. This path remains untested until Apptainer and
a target cluster are available.

## Offline transfer

For sites without registry access, export an OCI archive on a connected host:

```bash
podman save --format oci-archive \
  -o cap-VERSION.oci.tar \
  ghcr.io/mellifluousjdg/cap:VERSION
sha256sum cap-VERSION.oci.tar > cap-VERSION.oci.tar.sha256
```

Transfer both files, verify the checksum, and import with the site's supported
runtime. An OCI archive is not a substitute for a tested Apptainer SIF when the
cluster only supports Apptainer.
