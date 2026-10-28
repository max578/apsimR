# Generate a known-causal-structure dataset from APSIM (an OSSE)

Runs each unit under a control and a treatment value of `treatment` – so
both potential outcomes are known – then assigns each unit to treatment
or control and reveals the corresponding outcome, producing a dataset
whose true effects are recorded. Each unit is one row of `units`, whose
columns are further APSIM node paths defining that unit's context (the
heterogeneity, and the source of confounding). The result is the
test-bench for a causal member: hand it the observed
`(covariates, W, Y)` and compare its estimate to the recorded average
treatment effect.

## Usage

``` r
apsim_ground_truth(
  sim,
  treatment,
  control,
  treated,
  units,
  output,
  target = NULL,
  assignment = c("random", "confounded"),
  prob = 0.5,
  confounder = NULL,
  confound_strength = 1,
  report = NULL,
  seed = NULL
)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- treatment:

  Character APSIM node path of the intervened parameter.

- control, treated:

  Numeric values of `treatment` under control (`W = 0`) and treatment
  (`W = 1`).

- units:

  A `data.frame` whose columns are APSIM node paths and whose rows are
  the units' contexts (covariates). At least one column.

- output:

  A `function(report) -> named numeric` or report column name(s)
  identifying the outcome (see
  [`apsim_forward_model()`](https://max578.github.io/apsimR/reference/apsim_forward_model.md)).

- target:

  Character naming the outcome column when `output` yields several;
  defaults to the first.

- assignment:

  Character: `"random"` (treatment independent of covariates – no
  confounding) or `"confounded"` (treatment probability driven by a
  covariate that also affects the outcome).

- prob:

  Numeric treatment probability for `assignment = "random"`.

- confounder:

  Character naming the `units` column that drives assignment when
  `assignment = "confounded"`.

- confound_strength:

  Numeric logistic coefficient on the standardised confounder (larger
  means stronger confounding).

- report:

  Character report-table name, or `NULL` for the first report.

- seed:

  Optional integer RNG seed (assignment reproducibility).

## Value

An `apsim_ground_truth_result`, or an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator is unavailable.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# An OSSE varying sowing population (the unit covariate) under two N rates,
# with treatment confounded by population. Runs the simulator twice per unit.
if (FALSE) { # \dontrun{
f <- apsim_example("Wheat")
units <- data.frame(`[Sow using a variable rule].Script.Population` = c(80, 120,
  160, 200), check.names = FALSE)
apsim_ground_truth(
  f, treatment = "[Fertilise at sowing].Script.Amount",
  control = 0, treated = 150, units = units, output = "Yield",
  assignment = "confounded",
  confounder = "[Sow using a variable rule].Script.Population", seed = 1L)
} # }
}
```
