# Is an object an apsimR abstention?

Is an object an apsimR abstention?

## Usage

``` r
is_apsim_abstention(x)
```

## Arguments

- x:

  Any object.

## Value

A single logical: `TRUE` when `x` is an `apsim_abstention`.

## Examples

``` r
is_apsim_abstention(apsim_abstention("run_failed"))
#> [1] TRUE
is_apsim_abstention(42)
#> [1] FALSE
```
