# apsimR <img src="man/figures/logo.png" align="right" height="139" alt="apsimR logo" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/max578/apsimR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/max578/apsimR/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/max578/apsimR/graph/badge.svg)](https://app.codecov.io/gh/max578/apsimR)
[![r-universe](https://max578.r-universe.dev/badges/apsimR)](https://max578.r-universe.dev/apsimR)
[![pkgdown](https://github.com/max578/apsimR/actions/workflows/pkgdown.yaml/badge.svg)](https://max578.github.io/apsimR/)
<!-- badges: end -->

apsimR is a typed R interface to APSIM Next Generation, the process-based
agricultural systems simulator. It drives the simulator for prediction over
scenario designs, parameter calibration, global sensitivity analysis,
Gaussian-process emulation and validation against observations, and it can
manufacture known-causal-structure test datasets for grading causal-inference
methods. Every verb returns a versioned, provenance-complete `apsim_manifest`
object, or a typed `apsim_abstention` when the simulator or its runtime is
absent -- apsimR installs, loads and its tests run with no simulator present.

## Related packages

- [apsimx](https://CRAN.R-project.org/package=apsimx) inspects, reads,
  edits and runs APSIM Next Generation and APSIM Classic simulation files.
- [sensitivity](https://CRAN.R-project.org/package=sensitivity) screens
  factors and runs global sensitivity analysis on the outputs of any
  model.
- [BayesianTools](https://CRAN.R-project.org/package=BayesianTools)
  provides MCMC and SMC samplers and diagnostics, with a focus on
  calibrating complex system models.

apsimx is the closest: it gives detailed control over individual APSIM
files. apsimR works one level up, running a simulation over a scenario
design and covering calibration, sensitivity analysis, emulation and
validation in one interface. Its results carry the inputs and simulator
version that produced them, and it returns a typed abstention instead of
an error when APSIM is not installed.

## Install

```r
# install.packages("remotes")
remotes::install_github("max578/apsimR")
```

Simulator-backed verbs additionally need a working install of
[APSIM Next Generation](https://www.apsim.info/) (>= 2024.1) and the .NET 8.0
runtime; `apsim_available()` reports whether apsimR can find one.

## Minimal example

```r
library(apsimR)

# Works with no simulator installed: every simulator-dependent verb
# abstains with a typed reason instead of erroring.
apsim_available()

# With APSIM installed, run the bundled Wheat example and read the yield
# report back as a provenance-complete manifest.
if (apsim_available()) {
  m <- apsim_predict(apsim_example("Wheat"))
  m
}
```

See `vignette("apsimR")` for prediction, calibration, sensitivity analysis,
emulation, validation and the causal ground-truth generator end to end.

## Contributing

Bug reports and suggestions are welcome as
[GitHub issues](https://github.com/max578/apsimR/issues).

## Citation

```r
citation("apsimR")
```

## Licence

MIT + file LICENSE. See [LICENSE](LICENSE) / [LICENSE.md](LICENSE.md).
