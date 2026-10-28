# Estimate a mechanism by running APSIM across an input

Runs the simulator on a copy of `sim`, reads the report, and fits a
reduced-form response of the outcome `y` on the input `x` (the report
must already vary `x`, for example through a factorial over an N-rate).
Returns the fitted parameters as a `parameters`
[`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md),
or an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator is unavailable.

## Usage

``` r
apsim_estimate(
  sim,
  x,
  y,
  response = c("mitscherlich", "linear"),
  report = NULL
)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- x:

  Character name of the input column in the report.

- y:

  Character name of the outcome column in the report.

- response:

  Character mechanism form: `"mitscherlich"` (default, a saturating
  dose-response) or `"linear"`.

- report:

  Character report-table name, or `NULL` for the first report.

## Value

An `apsim_manifest` with `inferential_target = "parameters"`, or an
`apsim_abstention`.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
f <- apsim_example("Wheat")
if (!is.na(f)) {
  # apsim_estimate(f, x = "Nitrogen", y = "Yield")
  apsim_available()
}
}
```
