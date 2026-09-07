# CAP: Centromere Analysis Pipeline

**CAP** is a reproducible, containerized Nextflow pipeline for **centromere prediction and repeat analysis** in genomic assemblies. It integrates **TRASH2** for repeat detection, processes transposon and gene annotations, and generates publication-ready plots and tables.

---

## 🚀 Quick Start

```bash
# Using Docker (Recommended)
nextflow run vlothec/CAP -profile docker --assembly data/genome.fasta

# Using Conda
make install
nextflow run . -profile conda --assembly data/genome.fasta
```

---

## 🛠️ Installation

Choose **one** of the methods below.

### Option 1: Docker (Recommended)
Requires [Docker](https://www.docker.com/) and [Nextflow](https://www.nextflow.io/).

```bash
nextflow run vlothec/CAP -profile docker --assembly data/genome.fasta
```

### Option 2: Conda
Requires Conda on 64-bit Linux. Nextflow and Java are included in the CAP environment.

The setup script uses the committed `conda-linux-64.lock` by default on Linux x86-64, reproducing the exact tested package builds. `environment.yml` is the human-maintained dependency specification and is used to update the lock or when no matching platform lock exists.

**Linux x86-64:**
```bash
git clone --recursive https://github.com/vlothec/CAP.git
cd CAP

# One-step setup (creates environment and installs dependencies)
make install
# OR manually: bash setup_conda.sh

# Run the pipeline
conda activate cap-pipeline
nextflow run . --assembly data/genome.fasta
```

**Windows (PowerShell):**
```powershell
git clone --recursive https://github.com/vlothec/CAP.git
cd CAP

# One-step setup
.\setup_conda.ps1

# Run the pipeline
conda activate cap-pipeline
nextflow run . --assembly data/genome.fasta
```

### Option 3: R + renv (Manual)
For users who prefer a local R environment.

```bash
git clone https://github.com/vlothec/CAP.git
cd CAP

# Install R dependencies
R -e 'renv::restore()'

# Run
nextflow run . -profile renv --assembly data/genome.fasta
```

---

## ⚙️ Usage

```bash
nextflow run . [options] --assembly <fasta>
```

### Required Arguments
| Argument | Description |
|----------|-------------|
| `--assembly` | Path to the genome assembly in FASTA format. |

### Optional Arguments
| Argument | Description | Default |
|----------|-------------|---------|
| `--te_gff` | Path to EDTA TE annotation (`.gff3`). | `null` |
| `--gene_gff` | Path to Helixer gene annotation (`.gff`). | `null` |
| `--trash2` | Path to existing TRASH_2 results directory (skips TRASH run). | `null` |
| `--cores` | Number of CPU cores to use. | `1` |
| `--outdir` | Output directory. | `./results` |
| `--max_rep_size` | Maximum repeat size for TRASH. | `1000` |
| `--min_rep_size` | Minimum repeat size for TRASH. | `7` |

### Example Command
```bash
nextflow run . -profile docker \
  --assembly data/arabidopsis.fasta \
  --te_gff data/EDTA.TEanno.split.gff3 \
  --gene_gff data/helixer.gff \
  --cores 8 \
  --outdir results_arabidopsis
```

---

## 📂 Outputs

The pipeline generates the following key files in the output directory:

| File | Description |
|------|-------------|
| `*_CAP_plot.png` | **Main Visualization**: Centromere locations, repeat density, and genomic features. |
| `*_CAP_model.txt` | **Summary Report**: Text summary of identified centromeres. |
| `*_CAP_dotplot.png` | Dotplot visualization of the centromeric regions. |
| `*_CAP_repeat_families.csv` | Detailed statistics of identified repeat families. |
| `*_predictions.csv` | Raw prediction scores for centromere candidates. |

---

## 🧩 Pipeline Overview

1.  **Repeat Identification**: Runs **TRASH2** to find tandem repeats.
2.  **Filtering & Merging**: Filters repeats and merges similar classes.
3.  **Feature Extraction**: Parses TE and Gene annotations (if provided).
4.  **Scoring**: Calculates centromeric scores based on repeat characteristics and genomic context.
5.  **Prediction**: Uses a machine learning model to predict centromere locations.
6.  **Visualization**: Generates plots and summary reports.

---

## 📁 Directory Structure

```
CAP/
├── main.nf                  # Main Nextflow workflow script
├── nextflow.config          # Configuration (profiles, params)
├── environment.yml          # Human-maintained Conda requirements
├── conda-linux-64.lock      # Exact tested Linux x86-64 packages
├── setup_conda.sh           # Linux setup script
├── setup_conda.ps1          # Windows setup script
├── Makefile                 # Convenience commands
├── Dockerfile               # Docker image definition
├── bin/                     # R and Python scripts for pipeline steps
├── modules/                 # Submodules (TRASH2)
├── model/                   # Pre-trained ML models
└── test/                    # Test datasets
```

---

## 💻 HPC Usage (SLURM)

To run on a SLURM cluster, create a `conf/hpc.config` file:

```groovy
process {
  executor = 'slurm'
  queue = 'normal'
  cpus = 8
  memory = '32 GB'
}
```

Then run:
```bash
nextflow run . -profile docker,hpc --assembly genome.fasta
```

---

## 📜 License

[MIT License](LICENSE)

## 📧 Contact

For questions or issues, please open an issue on GitHub.





