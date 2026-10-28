# Global sensitivity analysis of an APSIM output

Quantifies how the `parm_paths` parameters drive a single scalar APSIM
output over the box `[lower, upper]`. Morris screening (default) ranks
the factors by mean absolute elementary effect (`mu_star`) and flags
interaction / non-linearity (`sigma`) cheaply; the Sobol-Jansen method
decomposes the output variance into first-order (`S`) and total (`T`)
indices at a higher run cost. The two stages use the `sensitivity`
package over the same forward model as the other verbs.

## Usage

``` r
apsim_sensitivity(
  sim,
  parm_paths,
  lower,
  upper,
  output,
  target = NULL,
  method = c("morris", "sobol", "both"),
  morris_r = 10L,
  morris_levels = 6L,
  sobol_n = 100L,
  nboot = 100L,
  report = NULL,
  seed = NULL
)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- parm_paths:

  Character vector of APSIM node paths (the factors).

- lower, upper:

  Numeric box bounds aligned to `parm_paths` (recycled from length one).

- output:

  A `function(report) -> named numeric` or report column name(s)
  identifying the output (see
  [`apsim_forward_model()`](https://max578.github.io/apsimR/reference/apsim_forward_model.md)).

- target:

  Character naming the single output column to analyse when `output`
  yields several; defaults to the first.

- method:

  Character: `"morris"` (default), `"sobol"`, or `"both"`.

- morris_r:

  Integer number of Morris elementary-effect repetitions.

- morris_levels:

  Integer Morris grid levels.

- sobol_n:

  Integer base sample size for Sobol (total runs `n * (p + 2)`).

- nboot:

  Integer bootstrap replicates for Sobol confidence intervals.

- report:

  Character report-table name, or `NULL` for the first report.

- seed:

  Optional integer RNG seed.

## Value

An `apsim_manifest` with `inferential_target = "sensitivity"` whose
`params` holds one row per factor with the requested indices, or an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator is unavailable.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# Sensitivity analysis runs the simulator r(p + 1) times, so the example is
# wrapped in \dontrun{}; see the package vignette for a runnable walk-through.
if (FALSE) { # \dontrun{
f <- apsim_example("Wheat")
if (!is.na(f)) {
  apsim_sensitivity(
    f, parm_paths = "[Fertilise at sowing].Script.Amount",
    lower = 0, upper = 250, output = "Yield", method = "morris",
    morris_r = 4L, seed = 1L)
}
} # }
}
```
