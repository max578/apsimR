# Emit an apsimR result as an orchestra manifest

The federation's emit and adapt generic. The
[`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md)
method lifts any apsimR result into the shared contract: the apsimR
target is mapped onto the contract's target enum (a sensitivity table is
a statement about parameters, an emulator and a validation are
statements about predictions), the assimilation context of an ensemble
result is carried into the contract's `weights` and `obs_target` slots,
and a validation verdict is lifted into the typed `summary` rather than
left buried in metadata.

## Usage

``` r
as_orchestra_manifest(x, ...)
```

## Arguments

- x:

  An
  [`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md)
  object.

- ...:

  Method-specific arguments. The
  [`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md)
  method accepts `run_id`, an optional character run identifier; when
  omitted a content hash is derived, so two identical results get the
  same identifier.

## Value

An `orchestra_manifest` S7 object.

## Details

Nothing is discarded: the original apsimR target, the APSIM build that
produced the result and apsimR's own payload hash all ride in
`metadata`, so a consumer can trace a contract manifest back to the
apsimR result it came from.

## See also

[`verify_manifest()`](https://max578.github.io/apsimR/reference/verify_manifest.md),
[`as_pesto_manifest()`](https://max578.github.io/apsimR/reference/as_pesto_manifest.md)

## Examples

``` r
m <- apsim_manifest("validation", "apsim:validate",
                    params = data.frame(nse = 0.82, rmse = 0.31),
                    outputs = data.frame(observed = c(2, 3.6),
                                         predicted = c(2.1, 3.4)),
                    metadata = list(verdict = "good"))
as_orchestra_manifest(m)
#> <orchestra_manifest>
#>   schema:   2.0.0-draft
#>   emitter:  apsimR 0.3.2.9000
#>   target:   predictions
#>   method:   apsim:validate
#>   run_id:   apsimR-e8e144740c91
#>   verdict:  good
#>   outputs:  2 rows x 2 cols
#>   hash:     sha256:e8e144740c91b43cf026fd29bccf6c7cef0915fa9d31c97d1551814429efedde
```
