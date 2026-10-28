# Emulate an expensive APSIM output with a Gaussian-process surrogate

Runs APSIM at a space-filling design over `[lower, upper]`, fits a GP
surrogate mapping the `parm_paths` parameters to a single scalar output,
and returns it with leave-one-out diagnostics. The default `exact`
backend needs no extra package; `pesto` uses PESTO's surrogate when
installed. Predict at new parameters with
[`predict()`](https://rdrr.io/r/stats/predict.html).

## Usage

``` r
apsim_emulate(
  sim,
  parm_paths,
  lower,
  upper,
  output,
  target = NULL,
  n = 30L,
  design = c("lhs", "grid", "random"),
  backend = c("exact", "pesto"),
  report = NULL,
  seed = NULL
)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- parm_paths:

  Character vector of APSIM node paths (the emulator inputs).

- lower, upper:

  Numeric box bounds aligned to `parm_paths` (recycled from length one).

- output:

  A `function(report) -> named numeric` or report column name(s)
  identifying the output (see
  [`apsim_forward_model()`](https://max578.github.io/apsimR/reference/apsim_forward_model.md)).

- target:

  Character naming the output column to emulate when `output` yields
  several; defaults to the first.

- n:

  Integer number of design (training) points.

- design:

  Character design method passed to
  [`apsim_design()`](https://max578.github.io/apsimR/reference/apsim_design.md):
  `"lhs"` (default), `"grid"` or `"random"`.

- backend:

  Character: `"exact"` (default, dependency-free; a
  marginal-likelihood-fitted ARD exact GP) or `"pesto"`.

- report:

  Character report-table name, or `NULL` for the first report.

- seed:

  Optional integer RNG seed (design reproducibility).

## Value

An `apsim_emulator`, or an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator (or, for `backend = "pesto"`, PESTO) is unavailable.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# Fitting an emulator runs the simulator at every design point, so the example
# is wrapped in \dontrun{}; see the package vignette for a runnable walk-through.
if (FALSE) { # \dontrun{
f <- apsim_example("Wheat")
if (!is.na(f)) {
  em <- apsim_emulate(
    f, parm_paths = "[Fertilise at sowing].Script.Amount",
    lower = 0, upper = 250, output = "Yield", n = 12L, seed = 1L)
  if (!is_apsim_abstention(em)) predict(em, matrix(c(50, 150), ncol = 1L))
}
} # }
}
```
