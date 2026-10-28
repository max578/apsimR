# List the simulation names in an `apsim_sim`

Walks the model tree and returns the `Name` of every
`Models.Core.Simulation` node. Needs no simulator (it reads the parsed
JSON).

## Usage

``` r
apsim_simulations(x)
```

## Arguments

- x:

  An `apsim_sim` object.

## Value

A character vector of simulation names (possibly empty).

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
if (nzchar(f)) apsim_simulations(apsim_sim(f))
}
```
