# BCT C++ implementation

This directory contains C++ source for the Bayesian Context Trees (BCT)
algorithm, adapted from the implementation by Ioannis Papageorgiou:

- C++ repository: https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees
- related R package: https://cran.r-project.org/package=BCT

## License

The standalone C++ repository does not contain a separate explicit license
notice. The related BCT R package published by the same author declares
`GPL (>= 2)` in its CRAN metadata. On that basis, CAP applies
`GPL-2.0-or-later` to the adapted source in this directory and the resulting
`bin/ctw-calc` executable. See `NOTICE` and the repository's
`THIRD_PARTY_NOTICES.md` for details.

CAP's remaining original code is licensed under MIT. Anyone who redistributes
this BCT-derived component or a compiled `ctw-calc` must comply with its GPL
terms and provide the complete corresponding source, including CAP's changes
and build instructions.
