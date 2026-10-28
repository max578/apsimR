# Verify an orchestra manifest's payload integrity

Recomputes the payload hash from the object's own load-bearing slots and
compares it to the stored `data_hash`. A mismatch means the payload was
modified after emission. Matches the reference contract's
`verify_manifest()`, so the check is symmetric across members.

## Usage

``` r
verify_manifest(m)
```

## Arguments

- m:

  An `orchestra_manifest` object.

## Value

A list with a logical `ok` and a human-readable `message`.

## See also

[`as_orchestra_manifest()`](https://max578.github.io/apsimR/reference/as_orchestra_manifest.md)

## Examples

``` r
m <- apsim_manifest("predictions", "apsim:predict",
                    outputs = data.frame(Yield = c(3.8, 4.1)))
verify_manifest(as_orchestra_manifest(m))
#> $ok
#> [1] TRUE
#> 
#> $message
#> [1] "data_hash verified"
#> 
```
