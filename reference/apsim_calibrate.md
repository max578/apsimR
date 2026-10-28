# Calibrate APSIM parameters against observations

Estimates the `parm_paths` parameters whose APSIM-simulated observations
best match `observed`, over the box `[lower, upper]`. The `ies` backend
(default when `PESTO` is installed) returns a posterior parameter
ensemble through an iterative ensemble smoother; the `optim` backend
returns a single bounded least-squares point estimate with no extra
dependency. Several targets are calibrated jointly – pass a named
`observed` vector and, optionally, per-target `obs_sd` or `weights`.

## Usage

``` r
apsim_calibrate(
  sim,
  parm_paths,
  lower,
  upper,
  observed,
  output,
  obs_sd = NULL,
  weights = NULL,
  backend = c("auto", "ies", "optim"),
  n_real = 50L,
  noptmax = 4L,
  inflation = 0.8,
  report = NULL,
  seed = NULL
)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- parm_paths:

  Character vector of APSIM node paths to estimate.

- lower, upper:

  Numeric box bounds aligned to `parm_paths` (recycled from length one).

- observed:

  Named numeric vector of observed target values; the names must match
  what `output` produces.

- output:

  Either a `function(report) -> named numeric` reducing a run's report
  to the comparable observations, or a character vector of report column
  names (see
  [`apsim_forward_model()`](https://max578.github.io/apsimR/reference/apsim_forward_model.md)).

- obs_sd:

  Numeric observation standard deviation(s): a scalar or a vector
  aligned to `observed`. Defaults to ten percent of each `|observed|`
  (floored away from zero) when `NULL`.

- weights:

  Optional misfit weights aligned to `observed` for the `optim` backend;
  defaults to `1 / obs_sd^2`. The `ies` backend always weights by
  `1 / obs_sd`.

- backend:

  Character: `"auto"` (default – `ies` if `PESTO` is installed, else
  `optim`), `"ies"`, or `"optim"`.

- n_real:

  Integer ensemble size for the `ies` backend.

- noptmax:

  Integer number of ensemble-smoother iterations (`ies`).

- inflation:

  Numeric RTPS inflation strength in `[0, 1]` for the `ies` backend (`0`
  disables it); guards against ensemble collapse.

- report:

  Character report-table name, or `NULL` for the first report.

- seed:

  Optional integer RNG seed (prior ensemble / reproducibility).

## Value

An `apsim_manifest` with `inferential_target = "parameters"` whose
`params` holds the point estimate (`optim`) or the posterior ensemble
(`ies`), or an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator (or, for `ies`, PESTO) is unavailable.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# A calibration runs the simulator many times, so the example is wrapped in
# \dontrun{}; see the package vignette for a runnable walk-through.
if (FALSE) { # \dontrun{
f <- apsim_example("Wheat")
if (!is.na(f)) {
  apsim_calibrate(
    f, parm_paths = "[Fertilise at sowing].Script.Amount",
    lower = 0, upper = 250, observed = c(Yield = 2200), output = "Yield",
    backend = "optim", seed = 1L)
}
} # }
}
```
