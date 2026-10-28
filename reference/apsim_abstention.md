# Construct a typed abstention

Returns a small classed object signalling that a simulator-dependent
operation could not be performed, with a machine-readable reason. Used
in place of an error so that callers (and the orchestration layer) can
branch on a refusal rather than catch an exception.

## Usage

``` r
apsim_abstention(reason, detail = NA_character_, scope = "call")
```

## Arguments

- reason:

  Character scalar reason code. One of `"runtime_unavailable"` (no
  `Models` executable or .NET runtime found), `"run_failed"` (the
  simulator was invoked but did not complete), or `"no_output"` (the run
  produced no readable DataStore).

- detail:

  Character scalar human-readable detail, or `NA`.

- scope:

  Character scalar naming what was refused (default `"call"`).

## Value

An object of class `"apsim_abstention"`: a list with `reason`, `detail`,
`scope` and `abstained = TRUE`.

## Examples

``` r
a <- apsim_abstention("runtime_unavailable", "no Models executable found")
is_apsim_abstention(a)
#> [1] TRUE
```
