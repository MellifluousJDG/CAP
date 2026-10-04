# Dependency source-obligation review

This review applies to packages in the **final Linux runtime image**, not the
larger development environment. Package metadata is evidence for review, not a
legal conclusion.

## Workflow

1. Generate a compliance bundle from the final image.
2. Classify GPL/LGPL-family candidates:

   ```bash
   scripts/classify-source-obligations.py \
     BUNDLE/inventory/conda-source-urls.csv \
     BUNDLE/source-obligations.csv
   ```

3. Review each row and replace `REVIEW` in `collect_source` with `yes` or `no`.
   Record the basis in `review_note`.
4. Collect rows marked `yes` with exact binary evidence and verified upstream
   archives:

   ```bash
   scripts/collect-conda-sources.py \
     BUNDLE/source-obligations.csv \
     BUNDLE/source/conda
   ```

   During review, `--conservative` collects all candidates, including unresolved
   `REVIEW` rows. This preserves source proactively but does not resolve their
   legal classification.
5. For every `yes`, preserve the exact upstream source archive and checksum,
   plus the exact package recipe, patches, and build scripts used for the
   distributed binary.
6. Preserve required copyright and license notices for every package regardless
   of whether corresponding source is required.

## Review classes

- `gpl-source-review`: GPL-family metadata without a listed alternative or
  exception. Normally collect corresponding source.
- `lgpl-source-review`: LGPL-family metadata. Review dynamic/static linkage and
  relinking requirements; collecting source is the conservative default.
- `alternative-license-review`: metadata contains `OR`; determine whether the
  distributed binary can be used under the non-copyleft alternative.
- `exception-review`: metadata names an exception, such as the GCC Runtime
  Library Exception or Classpath Exception. Preserve notices and verify that the
  distributed use satisfies the exception.

A missing feedstock commit in older package metadata does not prevent
collection: the extracted package evidence remains the authoritative exact
recipe snapshot.

## Exact package evidence

Conda packages commonly embed their rendered recipe, patches, build scripts,
and license files under `info/`. Use those files from the exact binary artifact
listed in `conda-source-urls.csv`; do not use the current recipe repository
branch as proof of how an older artifact was built.

A Conda binary URL is not corresponding source. The final external compliance
bundle must map each distributed copyleft binary to exact upstream source and
its recipe/patch material. `collect-conda-sources.py --conservative` was
validated against all 53 current runtime candidates: it produced 64 mappings to
48 unique checksum-verified source archives. Fifty artifacts record an exact
feedstock commit; the older `bioconductor-msa`, `glpk`, and `gsl` artifacts omit
that commit metadata but still embed their exact rendered recipes, build
scripts, patches, source URLs, and checksums. Debian packages require the
analogous mapping to the matching Debian source package and version.
