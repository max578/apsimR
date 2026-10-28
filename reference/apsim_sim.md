# A simulation file (`.apsimx`) as a typed object

Reads an `.apsimx` (JSON) file into an S7 object holding the absolute
file path, the parsed model tree, and the APSIM version that produced it
(or `NA`). The object round-trips:
[`apsim_write()`](https://max578.github.io/apsimR/reference/apsim_write.md)
writes the tree back unchanged.

## Usage

``` r
apsim_sim(file)
```

## Arguments

- file:

  Character path to an `.apsimx` file.

## Value

An `apsim_sim` S7 object.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
if (nzchar(f)) {
  sim <- apsim_sim(f)
  apsim_simulations(sim)
}
}
```
