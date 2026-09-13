# CAP: Centromere Analysis Pipeline

**CAP** is a Nextflow pipeline for centromere prediction and repeat analysis in genomic assemblies. It integrates **TRASH_2** for tandem-repeat detection, processes optional transposon and gene annotations, and produces plots and tables.

## Conda quick start

The tested packaging path is Conda on Linux x86-64. Conda must already be installed; Nextflow, Java, R, Python, Git, and scientific dependencies are installed in one CAP environment.

```bash
git clone --branch reproducible-conda-pipeline --recurse-submodules \
  https://github.com/MellifluousJDG/CAP.git
cd CAP

# Create the default cap-pipeline environment and compile CTW/BCT.
make install

# Run the bundled one-core regression test and verify all 16 checksums.
make test-conda

# Run CAP on a genome assembly in FASTA format.
make run ASSEMBLY=/path/to/genome.fasta
```

`ASSEMBLY` is a Make variable containing the path to the input genome assembly. The `run` target passes it to Nextflow as `--assembly`.

## Conda installation

### Reproducible Linux installation

On Linux x86-64, `setup_conda.sh` creates the environment from the committed `conda-linux-64.lock`. The lock contains the exact package URLs used by the tested environment.

On another platform, setup falls back to solving `environment.yml`. That fallback is convenient but does not have the same exact-package reproducibility guarantee. Linux is currently the supported and tested platform.

A recursive clone is preferred:

```bash
git clone --branch reproducible-conda-pipeline --recurse-submodules \
  https://github.com/MellifluousJDG/CAP.git
cd CAP
make install
```

If CAP was cloned without `--recurse-submodules`, `make install` initializes the TRASH_2 submodule using Git from the Conda environment.

The setup script does not activate the environment in the calling shell. To work in it interactively, run:

```bash
conda activate cap-pipeline
```

The Make targets use `conda run`, so activation is not required for `make run` or `make test-conda`.

### Custom environment name

The default environment name is `cap-pipeline`. Use `ENV_NAME` consistently with Make:

```bash
make install ENV_NAME=my-cap
make test-conda ENV_NAME=my-cap
make run ENV_NAME=my-cap ASSEMBLY=/path/to/genome.fasta
make remove-env ENV_NAME=my-cap
```

When invoking the setup script directly, use `CAP_ENV_NAME`:

```bash
CAP_ENV_NAME=my-cap bash setup_conda.sh
```

### Make targets

- `make install` creates or reuses the environment, initializes TRASH_2 when necessary, and compiles CTW/BCT.
- `make compile` recompiles CTW/BCT in the selected environment.
- `make run ASSEMBLY=...` runs CAP on the supplied FASTA assembly.
- `make test-conda` performs the bundled deterministic one-core regression test.
- `make remove-env` removes the selected Conda environment.
- `make clean-build` removes the generated `bin/ctw-calc` binary without removing the environment.
- `make clean` is deprecated because its name is ambiguous; it currently explains the replacement and delegates to `make remove-env`.

### Removing the environment

```bash
make remove-env
```

This removes the Conda environment but not Nextflow work or result directories.

## Usage

Run through Make:

```bash
make run ASSEMBLY=/path/to/genome.fasta
```

For options beyond `ASSEMBLY` and `ENV_NAME`, invoke Nextflow directly as shown below.

Or activate the environment and invoke Nextflow directly:

```bash
conda activate cap-pipeline
nextflow run . --assembly /path/to/genome.fasta
```

### Required argument

- `--assembly`: path to the genome assembly in FASTA format.

A genome assembly contains one or more reconstructed genomic DNA sequences, such as chromosomes, scaffolds, or contigs.

### Optional arguments

- `--te_gff`: EDTA transposable-element annotation in GFF3 format; default `null`.
- `--gene_gff`: Helixer gene annotation in GFF format; default `null`.
- `--trash2`: existing TRASH_2 results directory, which skips the TRASH_2 run; default `null`.
- `--cores`: number of CPU cores; default `1`.
- `--outdir`: output directory; default `./results`.
- `--max_rep_size`: maximum tandem-repeat size; default `1000`.
- `--min_rep_size`: minimum tandem-repeat size; default `7`.

Example with annotations:

```bash
conda activate cap-pipeline
nextflow run . \
  --assembly data/arabidopsis.fasta \
  --te_gff data/EDTA.TEanno.split.gff3 \
  --gene_gff data/helixer.gff \
  --cores 1 \
  --outdir results_arabidopsis
```

## Reproducibility and smoke testing

Run:

```bash
make test-conda
```

The test:

1. uses the bundled small FASTA assembly;
2. requires the TRASH_2 submodule and compiled `bin/ctw-calc`;
3. runs all ten CAP processes with one core and fresh result/work directories;
4. requires 16 nonempty output files, including CSV, PNG, and RDS output;
5. verifies every result against `test/expected-results.sha256`.

The exact checksum guarantee currently applies to the tested Linux x86-64 environment, committed model and dependencies, bundled input, published TRASH_2 revision, and one-core execution. A fixed sampling seed is used, but deterministic multiprocessing has not yet been established. Do not interpret the one-core regression test as a guarantee that every multicore run is byte-identical.

The expected PNG omits the former rightmost `Cen probability` table column. Probability calculations and CSV output remain available.

Override disposable test locations if needed:

```bash
make test-conda \
  RESULTS_DIR=/tmp/cap-results \
  WORK_DIR=/tmp/cap-work
```

## Updating dependencies and the Linux lock

`environment.yml` is the human-maintained dependency specification. `conda-linux-64.lock` is the exact tested Linux x86-64 artifact and should not be edited casually.

When dependencies must change:

1. edit `environment.yml` intentionally;
2. solve a fresh Linux x86-64 environment using only its declared channels;
3. test imports and model loading, including scikit-learn and XGBoost compatibility;
4. compile CTW/BCT;
5. run `make test-conda` and investigate every output difference;
6. export exact package URLs from the validated environment:

   ```bash
   conda list -n cap-pipeline --explicit > conda-linux-64.lock
   ```

7. recreate a disposable environment from that lock:

   ```bash
   conda create -n cap-lock-test --file conda-linux-64.lock
   ```

8. repeat setup and the complete smoke test from a fresh recursive clone;
9. update `test/expected-results.sha256` only when output changes are understood and approved;
10. commit dependency specifications, lock changes, and intentional output-baseline changes separately where practical.

The lock must not contain local filesystem paths or private package URLs. Review the generated file before committing it.

## Outputs

CAP writes key files such as:

- `*_CAP_plot*.png`: centromere, repeat-density, and annotation visualization;
- `*_CAP_model.txt`: text summary of identified centromeres;
- `*_CAP_repeat_families.csv`: repeat-family statistics;
- `*_centromeric_scores.csv`: calculated centromeric features and scores;
- `*_centromeric_scores_predictions.csv`: model predictions;
- `*_CAP_Rdata.rds`: serialized R data used by the final report.

Additional intermediate CSV files contain detected, filtered, and reclassified repeats.

## Pipeline overview

1. **Repeat identification:** run TRASH_2 to identify tandem repeats.
2. **Filtering and merging:** filter repeats and merge related classes.
3. **Feature extraction:** process optional TE and gene annotations.
4. **Scoring:** calculate centromeric features from repeats and genomic context.
5. **Prediction:** apply the bundled machine-learning model.
6. **Visualization:** produce plots, summaries, and tabular results.

## Repository structure

```text
CAP/
├── main.nf                       # Nextflow workflow
├── nextflow.config               # Parameters and profiles
├── environment.yml               # Human-maintained dependencies
├── conda-linux-64.lock           # Exact tested Linux x86-64 packages
├── setup_conda.sh                # Conda setup and CTW compilation
├── Makefile                      # Convenience commands
├── scripts/test-conda.sh         # One-core deterministic smoke test
├── conf/slurm-site.example.config # Site-specific SLURM configuration template
├── test/expected-results.sha256  # Expected test-result checksums
├── bin/                          # Pipeline scripts and CTW source
├── modules/TRASH_2/              # Pinned Git submodule
├── model/                        # Pre-trained models
└── test/                         # Bundled test input
```

## HPC and SLURM

CAP uses the Nextflow-managed SLURM architecture: Nextflow remains the workflow controller and submits individual CAP processes to SLURM. CAP does not provide a competing wrapper that runs every process locally inside one large allocation.

First install the locked Conda environment on storage visible to the login and compute nodes:

```bash
make install
conda activate cap-pipeline
```

Then start Nextflow with the SLURM profile from a host where `sbatch` and the other SLURM client commands are available:

```bash
nextflow run . \
  -profile slurm \
  --assembly /shared/data/genome.fasta \
  --outdir /shared/results/cap
```

Use `-profile slurm`, not `-profile conda,slurm`. The latter asks Nextflow to create per-process environments from `environment.yml`; it does not use the validated named environment created from `conda-linux-64.lock`.

The repository does not hard-code a partition or account because those names are cluster-specific. They can be supplied as command-line parameters:

- `--slurm_queue`: SLURM partition/queue;
- `--slurm_account`: project or allocation account;
- `--slurm_time`: process time request, such as `24h`;
- `--slurm_memory`: process memory request, such as `16 GB`.

For example:

```bash
nextflow run . \
  -profile slurm \
  --slurm_queue compute \
  --slurm_account my-project \
  --slurm_time 24h \
  --slurm_memory '16 GB' \
  --assembly /shared/data/genome.fasta
```

Alternatively, copy and edit `conf/slurm-site.example.config`, which overrides the corresponding `process` directives directly, then supply it with:

```bash
nextflow run . \
  -profile slurm \
  -c /path/to/my-site.config \
  --assembly /shared/data/genome.fasta
```

The repository, Conda environment, input files, output directory, and Nextflow work directory must be accessible from the compute nodes. The profile can be checked locally for configuration composition, but actual scheduling, filesystem access, accounting, and resource behavior still require validation on a real SLURM cluster.

## Other packaging methods

OCI containers and AppImage packaging are planned after the Conda workflow. Existing Docker-related files have not yet been adopted as the reproducibility reference. Conda is currently the validated installation path.

## License

[MIT License](LICENSE)

## Contact

For questions or issues, open an issue on GitHub.
