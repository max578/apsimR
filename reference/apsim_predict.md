# Run APSIM forward over a simulation file

Runs the simulator on a copy of `sim` (the source file and its DataStore
are never touched), reads the requested report from the resulting
DataStore, and returns it as a `predictions`
[`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md).
A single `Models` invocation builds the file once and runs every
simulation it contains (including any factorial fan-out) across cores.
Returns an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the simulator is unavailable or the run fails.

## Usage

``` r
apsim_predict(sim, report = NULL, simulations = NULL, cpu = NULL)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- report:

  Character report-table name, or `NULL` for the first report.

- simulations:

  Optional regular expression selecting simulations to run
  (`--simulation-names`).

- cpu:

  Optional integer thread cap; `NULL` uses all cores.

## Value

An `apsim_manifest` with `inferential_target = "predictions"` carrying
the simulated report in `outputs`, or an `apsim_abstention`.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# Running APSIM over a real simulation file takes several seconds, so the
# call is wrapped in \donttest{}; it runs under R CMD check --run-donttest.
f <- apsim_example("Wheat")
# \donttest{
if (!is.na(f)) {
  m <- apsim_predict(f)
  m@inferential_target
}
# }
}
```
