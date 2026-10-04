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

3. Apply CAP's reviewed conservative policy. It fails if the candidate set has
   changed, forcing explicit review of new or removed dependencies:

   ```bash
   scripts/apply-source-review-policy.py \
     BUNDLE/source-obligations.csv \
     BUNDLE/source-obligations-reviewed.csv
   ```

   The current policy marks all 53 candidates `yes`. This preserves evidence for
   GPL/LGPL packages, permissive alternatives, and exception-bearing runtimes;
   it does not claim that every package legally requires source distribution.
4. Collect exact binary evidence and verified upstream archives:

   ```bash
   scripts/collect-conda-sources.py \
     BUNDLE/source-obligations-reviewed.csv \
     BUNDLE/source/conda
   ```

   During review, `--conservative` collects all candidates, including unresolved
   `REVIEW` rows. This preserves source proactively but does not resolve their
   legal classification.
5. For every `yes`, preserve the exact upstream source archive and checksum,
   plus the exact package recipe, patches, and build scripts used for the
   distributed binary.
6. Collect exact embedded Conda notice evidence for all runtime packages:

   ```bash
   scripts/collect-conda-notices.py \
     BUNDLE/inventory/conda-source-urls.csv \
     BUNDLE/notices/conda
   ```

   The current 186-package runtime has embedded license files in 113 exact
   artifacts. The other 73 are flagged `SOURCE_REVIEW_REQUIRED`; review their
   exact source archives and package payloads rather than treating a declared
   license expression as a complete notice.
7. Export the installed Debian binary-to-source map and copyright files, then
   collect exact Debian source:

   ```bash
   scripts/export-debian-compliance-inputs.sh IMAGE BUNDLE/debian-inputs
   scripts/collect-debian-sources.py \
     BUNDLE/debian-inputs/binary-to-source.csv \
     BUNDLE/debian-inputs/installed-copyright.tar.gz \
     BUNDLE/source/debian
   ```

   Validation mapped 91 binary packages to 65 exact source packages and
   checksum-verified 209 source files. Current Bookworm indices supplied 64
   versions; Debian Snapshot supplied the unavailable patched `pcre2` version.
8. Preserve required copyright and license notices for every package regardless
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
