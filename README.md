# apsimR

apsimR is a typed R interface to APSIM Next Generation, the process-based
agricultural systems simulator. It drives the simulator for prediction over
scenario designs, parameter calibration, global sensitivity analysis,
Gaussian-process emulation and validation against observations, and it can
manufacture known-causal-structure test datasets for grading causal-inference
methods. Every verb returns a versioned, provenance-complete `apsim_manifest`
object, or a typed `apsim_abstention` when the simulator or its runtime is
absent -- apsimR installs, loads and its tests run with no simulator present.

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
