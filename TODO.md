# Licensing and redistribution TODOs

- [ ] **Client confirmation — BCT/CTW:** Confirm with the upstream rightsholder
  that https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees and CAP's
  adaptation in `bin/src/BCT` may be redistributed under
  `GPL-2.0-only OR GPL-3.0-only`. If the intended license is instead
  `GPL-2.0-or-later` (as suggested by current CRAN BCT metadata), update the
  subtree notice, SPDX expression, bundled license texts, and compliance bundle.
- [x] **TRASH_2 Linux image review:** Its MIT-style `license.txt` covers the
  pinned submodule code. The upstream revision also tracks Windows-only MAFFT
  and HMMER bundles plus historical `temp/` outputs; `.dockerignore` excludes
  those from Linux images, which use the exact locked Conda MAFFT/HMMER builds.
- [ ] **Dependency corresponding source:** All 53 Conda GPL/LGPL-family
  candidates are reviewed for conservative source collection, and all 64
  source mappings have passed checksum validation. Preserve the generated
  source corpus in the final bundle, collect license/notice files for all
  runtime packages, and complete Debian source mappings and notices.
- [ ] **SBOM:** Generate and review a standard SPDX or CycloneDX SBOM for the
  final digest-pinned image. The repository's CSV inventories are supplemental.
- [ ] **Release identity and archive:** Record the CAP tag, recursive submodule
  revision, immutable registry digest, validation log, compliance-bundle
  checksum, and OCI archive checksum/location.
- [ ] **Publication policy:** Agree the tag, rollback, archival-retention, and
  package-visibility policies before the client publishes the image.
