# Build an APSIM forward model

Returns a closure of the orchestra-standard forward-model shape:
`function(theta) -> obs`, where `theta` is an `nreal x npar` numeric
matrix (one row per parameter realisation, columns aligned to
`parm_paths`) and `obs` is an `nreal x nobs` numeric matrix. Each row is
one APSIM run with the corresponding parameters substituted; failed runs
become `NA` rows. The closure is what
[`apsim_calibrate()`](https://max578.github.io/apsimR/reference/apsim_calibrate.md),
[`apsim_sensitivity()`](https://max578.github.io/apsimR/reference/apsim_sensitivity.md)
and
[`apsim_emulate()`](https://max578.github.io/apsimR/reference/apsim_emulate.md)
all evaluate, and it is directly accepted by
[`PESTO::pesto_ies_callback()`](https://max578.github.io/PESTO/reference/pesto_ies_callback.html)
and by the `sensitivity` package's `model` argument.

## Usage

``` r
apsim_forward_model(
  sim,
  parm_paths,
  output,
  report = NULL,
  checkpoint = "Current",
  reduce = function(x) x[[length(x)]],
  cores = 1L
)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- parm_paths:

  Character vector of APSIM node paths to vary, for example
  `c("[Sow].Script.Population", "[Wheat].Phenology.MinimumLeafNumber")`.

- output:

  Either a `function(report) -> named numeric` reducing a run's report
  to its observation vector, or a character vector of report column
  names (reduced by `reduce`).

- report:

  Character report-table name, or `NULL` for the first report.

- checkpoint:

  Character checkpoint name (default `"Current"`).

- reduce:

  When `output` names columns, the `function(numeric) -> numeric(1)`
  reducing each column (default takes the final value).

- cores:

  Number of APSIM runs in flight at once (default `1L`, serial). With
  `cores > 1` each realisation runs in a forked R process
  ([`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html)),
  each driving its own `Models` process in its own scratch directory;
  rows of the result keep the order of `theta`. Forking is unavailable
  on Windows, where runs stay serial.

## Value

A function of one argument `theta` (an `nreal x npar` matrix or a
length-`npar` vector) returning an `nreal x nobs` numeric matrix, or an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator is unavailable.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
f <- apsim_example("Wheat")
# \donttest{
if (!is.na(f)) {
  fm <- apsim_forward_model(f, "[Clock].End", output = "Wheat.AboveGround.Wt")
  if (!is_apsim_abstention(fm)) fm(matrix("1991-04-30", 1L, 1L))
}
# }
}
```
