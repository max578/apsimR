# Plot observed against predicted for a validation manifest

Builds an observed-versus-predicted scatter with the 1:1 line, titled
with the verdict and key metrics. Requires the optional `ggplot2`
package; returns an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when it is absent.

## Usage

``` r
apsim_validation_plot(validation)
```

## Arguments

- validation:

  An `apsim_manifest` of `inferential_target = "validation"` (the result
  of
  [`apsim_validate()`](https://max578.github.io/apsimR/reference/apsim_validate.md)).

## Value

A `ggplot` object, or an `apsim_abstention`.

## Examples

``` r
v <- apsim_validate(c(2, 3.6, 3.8, 5), c(2.1, 3.4, 4, 5.2))
apsim_validation_plot(v)
```
