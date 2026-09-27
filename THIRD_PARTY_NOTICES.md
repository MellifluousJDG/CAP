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

Pending rightsholder confirmation, CAP treats `bin/src/BCT` and the resulting
`bin/ctw-calc` executable as licensed under:

    GPL-2.0-only OR GPL-3.0-only

The full license texts are in:

- `licenses/GPL-2.0.txt`
- `licenses/GPL-3.0.txt`

This provisional expression follows the `GPL-2 | GPL-3` statement that was
bundled with the CAP adaptation. Current CRAN BCT metadata instead declares
`GPL (>= 2)`. That metadata supports GPL coverage but does not by itself prove
the license of the separate upstream C++ repository.

Distribution of a compiled `ctw-calc` must be accompanied by the complete
corresponding source used to build it, including CAP's modifications and build
instructions. The tracked `bin/src/BCT` directory is that source for CAP builds.

## Confirmation TODO

Before public distribution, ask the client to confirm with the upstream
rightsholder that the standalone C++ repository and CAP's adaptation may be
redistributed under `GPL-2.0-only OR GPL-3.0-only`, or record the corrected
license expression and notices supplied by the rightsholder.
