ENV_NAME ?= cap-pipeline
ASSEMBLY ?=

.PHONY: install compile run test-conda remove-env clean

install:
	@echo "Setting up Conda environment '$(ENV_NAME)'..."
	CAP_ENV_NAME="$(ENV_NAME)" bash setup_conda.sh

compile:
	conda run -n "$(ENV_NAME)" make -C bin/src/BCT

run:
	@test -n "$(ASSEMBLY)" || { \
		echo "Usage: make run ASSEMBLY=path/to/genome.fasta" >&2; \
		exit 1; \
	}
	conda run -n "$(ENV_NAME)" nextflow run . --assembly "$(ASSEMBLY)"

test-conda:
	CAP_ENV_NAME="$(ENV_NAME)" bash scripts/test-conda.sh

remove-env:
	@echo "Removing Conda environment '$(ENV_NAME)'..."
	conda env remove -n "$(ENV_NAME)"

clean:
	@echo "DEPRECATED: 'make clean' removes the Conda environment. Use 'make remove-env' instead."
	@$(MAKE) remove-env ENV_NAME="$(ENV_NAME)"
