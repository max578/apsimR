# The orchestra manifest contract (apsimR-side implementation)

A versioned, hashed, provenance-complete S7 result object,
property-compatible with the federation's reference `orchestra_manifest`
and carrying the same bare class identity, so any orchestra consumer
reads an apsimR result without special casing. Build one from an
[`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md)
with
[`as_orchestra_manifest()`](https://max578.github.io/apsimR/reference/as_orchestra_manifest.md)
rather than calling this constructor directly.

## Value

An S7 object of class `orchestra_manifest`.

## See also

[`as_orchestra_manifest()`](https://max578.github.io/apsimR/reference/as_orchestra_manifest.md),
[`verify_manifest()`](https://max578.github.io/apsimR/reference/verify_manifest.md)
