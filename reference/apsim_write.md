# Write an `apsim_sim` back to an `.apsimx` file

Serialises the model tree to JSON. With no edits this is a faithful
round-trip of the file
[`apsim_sim()`](https://max578.github.io/apsimR/reference/apsim_sim.md)
read. Needs no simulator.

## Usage

``` r
apsim_write(x, path = tempfile(fileext = ".apsimx"))
```

## Arguments

- x:

  An `apsim_sim` object.

- path:

  Character output path. Defaults to a new temporary `.apsimx`.

## Value

Invisibly, the output path.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
if (nzchar(f)) apsim_write(apsim_sim(f), tempfile(fileext = ".apsimx"))
}
```
