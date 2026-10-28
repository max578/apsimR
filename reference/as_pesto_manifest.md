# Bridge an `apsim_manifest` to a PESTO ensemble manifest

Converts to PESTO's `pesto_ensemble_manifest` S7 object (the orchestra's
C2 contract) so an APSIM inversion result can be consumed by the PESTO /
kernR / flexyBayes stack.

## Usage

``` r
as_pesto_manifest(x)
```

## Arguments

- x:

  An `apsim_manifest` object.

## Value

A
[`PESTO::pesto_ensemble_manifest`](https://max578.github.io/PESTO/reference/pesto_ensemble_manifest.html),
or an `apsim_abstention` with reason `"runtime_unavailable"` (PESTO
absent) or `"feature_unsupported"` (the payload is not an ensemble
inversion).

## Details

PESTO's contract is an *ensemble* contract, and the bridge respects that
rather than forcing every payload through it. It requires two things,
both read from the installed PESTO (0.10.1 at the time of writing)
rather than assumed: a method tag drawn from PESTO's own enum, and a
parameter ensemble whose rows align one-for-one with a
simulated-observation ensemble. Exactly one apsimR result satisfies that
– the posterior ensemble from
[`apsim_calibrate()`](https://max578.github.io/apsimR/reference/apsim_calibrate.md)'s
`ies` backend, which PESTO's own ensemble smoother produced. Every other
apsimR result (a prediction, a screening table, an emulator, a
validation verdict) is not an ensemble inversion, so the bridge returns
a `feature_unsupported`
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
naming the reason instead of a manifest whose slots would have to be
invented. Those results compose through
[`as_orchestra_manifest()`](https://max578.github.io/apsimR/reference/as_orchestra_manifest.md),
the federation's general contract.

The bridged manifest is re-hashed with PESTO's own payload recipe, so
[`PESTO::verify_manifest()`](https://max578.github.io/PESTO/reference/verify_manifest.html)
verifies it; apsimR's own hash is kept in the bridge's provenance chain
through the source manifest.

## See also

[`as_orchestra_manifest()`](https://max578.github.io/apsimR/reference/as_orchestra_manifest.md)
for the general orchestra contract.

## Examples

``` r
# A prediction is not an ensemble inversion, so the bridge declines.
as_pesto_manifest(apsim_manifest("predictions", "apsim:predict",
                                 outputs = data.frame(Yield = 3.8)))
#> <apsim_abstention>
#>   scope:  as_pesto_manifest
#>   reason: feature_unsupported
#>   detail: method 'apsim:predict' is not an ensemble inversion, so it has no counterpart in PESTO's method enum (ies_callback, ies_filter, ies_pst, mda, surrogate); use as_orchestra_manifest() for the general contract
```
