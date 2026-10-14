# Third-party licensing notices

CAP's original workflow and application code is licensed under the root MIT
license except where a file or component states otherwise.

## Bayesian Context Trees / `ctw-calc`

The source in `bin/src/BCT` is adapted from the Bayesian Context Trees C++
implementation by Ioannis Papageorgiou:

- upstream repository: https://github.com/IoannisPapageorgiou/Bayesian-Context-Trees
- related CRAN package: https://cran.r-project.org/package=BCT
- associated paper: https://arxiv.org/abs/2007.14900
- CAP introduction commit: `57f08aa5d72e44ee33b90b62da6b06fe6cc8ce20`

The upstream algorithms include Context Tree Weighting (CTW), Bayesian Context
Trees (BCT), and k-BCT. CAP adds `main_ctw.cpp` and a Makefile to build the
CTW-specific command-line executable `bin/ctw-calc`. The executable is invoked
as a separate process by CAP.

The standalone C++ repository does not contain a separate explicit license
notice. The related BCT R package published by the same author declares
`GPL (>= 2)` in its CRAN metadata. On that basis, CAP applies this SPDX license
expression to `bin/src/BCT` and the resulting `bin/ctw-calc` executable:

    GPL-2.0-or-later

The full GPL version 2 and version 3 license texts are in:

- `licenses/GPL-2.0.txt`
- `licenses/GPL-3.0.txt`

Distribution of a compiled `ctw-calc` must be accompanied by the complete
corresponding source used to build it, including CAP's modifications and build
instructions. The tracked `bin/src/BCT` directory is that source for CAP builds.
