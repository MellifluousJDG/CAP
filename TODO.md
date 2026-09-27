# Licensing and redistribution TODOs

- [ ] **Client confirmation — BCT/CTW:** Confirm with the upstream rightsholder
  that https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees and CAP's
  adaptation in `bin/src/BCT` may be redistributed under
  `GPL-2.0-only OR GPL-3.0-only`. If the intended license is instead
  `GPL-2.0-or-later` (as suggested by current CRAN BCT metadata), update the
  subtree notice, SPDX expression, bundled license texts, and compliance bundle.
- [ ] **TRASH_2 review:** Confirm the scope of its MIT-style `license.txt` and
  inventory any third-party material that will actually be included in a Linux
  release image. Its ignored Windows dependency bundle is not part of the
  pinned TRASH_2 Git revision and must not be treated as reproducible source.
- [ ] **Dependency corresponding source:** Review the exact Conda and Debian
  package inventories, collect exact corresponding source where required, and
  preserve source-to-binary mappings and license/notice files in the external
  compliance bundle.
- [ ] **SBOM:** Generate and review a standard SPDX or CycloneDX SBOM for the
  final digest-pinned image. The repository's CSV inventories are supplemental.
- [ ] **Release identity and archive:** Record the CAP tag, recursive submodule
  revision, immutable registry digest, validation log, compliance-bundle
  checksum, and OCI archive checksum/location.
- [ ] **Publication policy:** Agree the tag, rollback, archival-retention, and
  package-visibility policies before the client publishes the image.
