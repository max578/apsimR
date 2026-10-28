# Apply `[Node].Property = value` edits through APSIM's validator

Writes an APSIM `--apply` config file from `edits` and runs the
simulator's own editor, so the change is validated against the model
schema rather than poked into raw JSON. Requires the simulator; returns
an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when it is absent.

## Usage

``` r
apsim_edit(x, edits, path = tempfile(fileext = ".apsimx"))
```

## Arguments

- x:

  An `apsim_sim` object.

- edits:

  A named character vector of edits, names being APSIM node paths and
  values the new values, for example
  `c("[Clock].End" = "1991-12-31", "[Sow].Script.Population" = "120")`.

- path:

  Character output path for the edited file. Defaults to a temporary
  `.apsimx`.

## Value

A new `apsim_sim` for the edited file, or an `apsim_abstention`.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
if (nzchar(f)) {
  apsim_edit(apsim_sim(f), c("[Clock].End" = "1991-12-31"))
}
}
```
