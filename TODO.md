# Licensing and redistribution TODOs

## Completed release engineering

- [x] **TRASH_2 Linux image review:** Its MIT-style `license.txt` covers the
  pinned submodule code. The upstream revision also tracks Windows-only MAFFT
  and HMMER bundles plus historical `temp/` outputs; `.dockerignore` excludes
  those from Linux images, which use the exact locked Conda MAFFT/HMMER builds.
- [x] **Dependency source and notice corpus:** All 53 conservative Conda
  GPL/LGPL-family candidates were reviewed. The final corpus has 77 source
  mappings covering 65 exact runtime identities, including supplemental notice
  sources. All 91 Debian binaries map to 65 exact source packages with 209
  verified source files. Notice review covers all 186 Conda artifacts: 154
  contain embedded evidence; the remaining 32 resolve to 11 source-license
  sets, 20 exact R canonical-license references, and one reviewed packaging
  exception. The checksum-verified corpora are preserved in the candidate
  compliance archive.
- [x] **SBOM:** The candidate has a schema-valid CycloneDX 1.6 primary SBOM with
  exact coverage of 186 Conda packages, 91 Debian packages, and four embedded
  components. The compliance archive also contains the passing coverage report
  and supplemental Syft 1.54.0 SPDX/CycloneDX deep scans.
- [x] **Candidate build, archive, and regression:** Commit `834ec72` and TRASH_2
  revision `4074700` were built with `--no-cache` from a clean recursive
  worktree. Both the pre-archive and post-import one-core regressions produced
  16 outputs and matched all 15 deterministic non-PNG hashes. The immutable OCI
  and compliance archives, checksums, validation logs, and release-candidate
  record are under the external `release-candidate-834ec72/` directory.

## Required before public publication

- [ ] **Client confirmation — BCT/CTW:** Confirm with the upstream rightsholder
  that https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees and CAP's
  adaptation in `bin/src/BCT` may be redistributed under
  `GPL-2.0-only OR GPL-3.0-only`. If the intended license is instead
  `GPL-2.0-or-later` (as suggested by current CRAN BCT metadata), update the
  subtree notice, SPDX expression, bundled license texts, image, SBOM, and
  compliance bundle.
- [ ] **Model authorization record:** Preserve the client's existing
  authorization to distribute the trained model in the external release record.
  Do not infer a separate model license that the client has not supplied.
- [ ] **Release version and Git tag:** Choose the release version, merge the
  reviewed branch, create the corresponding signed or annotated tag, and record
  the final recursive revisions. If merging changes the CAP revision, rebuild
  the image and regenerate/retest the release artifacts from that tagged commit.
- [ ] **Publication policy:** Agree GHCR visibility, mutable tag policy,
  rollback procedure, archival-retention period, and the durable location of
  the OCI and compliance archives.
- [ ] **Manual registry publication:** After the preceding items are resolved,
  the client may manually publish the rebuilt and validated tagged image. Record
  the immutable GHCR manifest digest, pull that digest into a clean image store,
  rerun `scripts/test-container-image.sh`, and archive the resulting log. Never
  substitute a local image ID or local archive digest for the registry digest.
