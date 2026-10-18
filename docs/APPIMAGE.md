# CAP AppImage

The CAP AppImage is a portable Linux x86-64 application containing CAP, its
pinned TRASH_2 module, Nextflow, Java, R/Bioconductor, Python, MAFFT, HMMER, the
prediction model, and CTW/BCT. It does not require Conda, Java, R, Python, or a
container runtime on the host.

## Download a release

Download these two assets from the CAP GitHub Release page:

```text
CAP-<version>-x86_64.AppImage
CAP-<version>-x86_64.AppImage.sha256
```

Keep both files in the same directory, verify the download, and make the
AppImage executable:

```bash
cd /path/to/downloads
sha256sum --check CAP-<version>-x86_64.AppImage.sha256
chmod +x CAP-<version>-x86_64.AppImage
```

Replace `<version>` with the version shown in the release. Use the checksum
published with that same release; do not reuse a checksum from another version.

The AppImage supports Linux x86-64 only. macOS, Windows, ARM64, and 32-bit Linux
are not supported by this artifact.

## Run CAP

Use absolute paths so input, output, and Nextflow work locations are
unambiguous:

```bash
appimage=/path/to/CAP-<version>-x86_64.AppImage
assembly=/path/to/genome.fasta
outdir=/path/to/cap-results
workdir=/path/to/cap-work

mkdir -p "$outdir" "$workdir"
"$appimage" \
  --assembly "$assembly" \
  --cores 1 \
  --outdir "$outdir" \
  -work-dir "$workdir"
```

Final CSV, RDS, model, and PNG files are written to `outdir`. Nextflow stores
intermediate files in `workdir`; remove that directory after a successful run
to reclaim space:

```bash
rm -rf /path/to/cap-work
```

Keep the work directory and `.nextflow.log` while diagnosing a failed run.

The number supplied to `--cores` should not exceed the CPUs available to the
process. CAP's default is one core. A larger assembly may also require more
memory and temporary storage.

### Optional inputs and parameters

The AppImage accepts the same workflow arguments as the Conda installation:

- `--te_gff`: EDTA transposable-element annotation in GFF3 format.
- `--gene_gff`: Helixer gene annotation in GFF format.
- `--metadata`: optional sample metadata.
- `--trash2`: existing TRASH_2 output directory.
- `--max_rep_size`: maximum tandem-repeat size; default `1000`.
- `--min_rep_size`: minimum tandem-repeat size; default `7`.

For example:

```bash
"$appimage" \
  --assembly /data/arabidopsis.fasta \
  --te_gff /data/EDTA.TEanno.split.gff3 \
  --gene_gff /data/helixer.gff \
  --cores 4 \
  --outdir /data/cap-results \
  -work-dir /data/cap-work
```

Run `"$appimage" --help` for Nextflow and pipeline help. See
`docs/PIPELINE_FLOW.md` for the complete output inventory and workflow details.

## Run on a system without FUSE

Normal execution may require FUSE support from the operating system. If direct
execution reports a FUSE, mount, or AppImage runtime error, explicitly extract
the AppImage and run the extracted application:

```bash
mkdir cap-appimage
cd cap-appimage
/path/to/CAP-<version>-x86_64.AppImage --appimage-extract

./squashfs-root/AppRun \
  --assembly /path/to/genome.fasta \
  --cores 1 \
  --outdir /path/to/cap-results \
  -work-dir /path/to/cap-work
```

Move the entire `squashfs-root` directory if desired; do not move individual
files out of it. CAP resolves its bundled runtime relative to that directory,
so extraction can be placed in any user-writable location. Remove the extracted
directory when it is no longer needed:

```bash
cd ..
rm -rf cap-appimage
```

Extraction is a user-selected execution mode. CAP does not silently switch
between normal and extracted execution.

## Offline use

The AppImage contains CAP and all required runtime dependencies. The pipeline
can run without downloading packages. Nextflow may print a harmless version
check warning when network access is unavailable.

For offline systems, download the AppImage and checksum on a connected machine,
verify them, and transfer both files. If the destination does not provide FUSE,
use the explicit extraction procedure above.

## Build from source

Building is supported on Linux x86-64. The build requires a recursive CAP Git
checkout, network access, and common host tools including Bash, Git, Make, a C++
compiler, `curl`, and `sha256sum`. Conda does not need to be installed: the build
downloads a checksum-verified Miniconda bootstrap locally.

```bash
git clone --recurse-submodules https://github.com/MellifluousJDG/CAP.git
cd CAP
make test-appimage
make appimage
```

The build downloads the exact packages named by
`conda-runtime-linux-64.lock`, compiles CTW/BCT, and writes the generated
AppImage and checksum under `dist/`. The output filename includes the short CAP
Git revision.

Test a built artifact with:

```bash
make test-appimage APPIMAGE=dist/CAP-<revision>-x86_64.AppImage
```

This verifies the checksum, extracts the artifact to a separate location,
checks the bundled runtimes, and runs CAP's complete regression test. The test
expects 16 outputs and verifies all deterministic output hashes.

Remove generated AppImage build directories and artifacts with:

```bash
make clean-appimage
```

## Troubleshooting

- `Permission denied`: run `chmod +x` on the AppImage. If the filesystem is
  mounted with `noexec`, move it to a user-writable executable filesystem or use
  extraction mode.
- FUSE or mount errors: use the explicit extraction procedure above.
- Assembly not found: use an absolute path and check that the file is readable.
- Output or work directory is not writable: create it in a location owned by
  your user and pass its absolute path.
- Interrupted or failed run: inspect `.nextflow.log` in the launch directory
  and retain the work directory for diagnosis.
- Disk usage grows during a run: Nextflow intermediates are stored under the
  path supplied with `-work-dir`; remove them only after a successful run.
- Cluster execution: ask administrators whether AppImage/FUSE is supported on
  compute nodes. Extraction mode may work where FUSE is unavailable. Use
  persistent storage for final results and node-local temporary storage for the
  Nextflow work directory when available.
