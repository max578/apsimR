# Validate simulated output against observations

Pairs predicted with observed values and reports goodness-of-fit metrics
plus a typed performance verdict. `predicted` may be an
[`apsim_predict()`](https://max578.github.io/apsimR/reference/apsim_predict.md)
manifest, a `data.frame`, or a numeric vector; `observed` a `data.frame`
or numeric vector. When both are data frames and `by` is given, they are
joined on that key (matching simulated and observed rows by, say, date)
before scoring; otherwise the two columns are paired by position and
must be equal length.

## Usage

``` r
apsim_validate(
  predicted,
  observed,
  predicted_col = NULL,
  observed_col = NULL,
  by = NULL
)
```

## Arguments

- predicted:

  An `apsim_manifest`, `data.frame`, or numeric vector of simulated
  values.

- observed:

  A `data.frame` or numeric vector of observed values.

- predicted_col, observed_col:

  Column names when the corresponding input is a `data.frame`.

- by:

  Optional key column present in both data frames to join on before
  pairing.

## Value

An `apsim_manifest` with `inferential_target = "validation"`: `params`
holds the one-row metrics table, `outputs` the paired observed/predicted
values, and `metadata$verdict` the performance grade.

## Verdict caveat

The typed grade in `metadata$verdict` reads on Nash-Sutcliffe efficiency
(NSE) alone. The bands are those of Moriasi et al. (2007)
`[unverified against the source paper]`, derived for monthly watershed
and streamflow simulations, not paddock-scale crop yield; that paper's
own recommendation is a joint reading of NSE with `rsr` and `pbias`
(both already reported in `params`), not NSE on its own. Treat the grade
as a diagnostic starting point, and read all three metrics before
trusting it.

## References

Moriasi, D. N. et al. (2007) Model evaluation guidelines for systematic
quantification of accuracy in watershed simulations. *Transactions of
the ASABE* 50(3), 885-900.
[doi:10.13031/2013.23153](https://doi.org/10.13031/2013.23153)

## Examples

``` r
obs <- c(2.1, 3.4, 4.0, 5.2)
sim <- c(2.0, 3.6, 3.8, 5.0)
v <- apsim_validate(sim, obs)
v@metadata$verdict
#> [1] "very good"
```
