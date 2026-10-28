# An APSIM result as a contract-emitting manifest

The typed result every verb returns. `inferential_target` follows the
orchestra contract enum (`"predictions"`, `"parameters"`); `params`
carries a fitted-parameter table (empty for a pure prediction);
`outputs` carries the simulated report; provenance pins the APSIM
version, an integrity hash, and the seed.

## Usage

``` r
apsim_manifest(
  inferential_target,
  method,
  params = data.frame(),
  outputs = NULL,
  metadata = list(),
  seed = NA_integer_
)
```

## Arguments

- inferential_target:

  Character: `"predictions"`, `"parameters"`, `"sensitivity"`,
  `"emulator"` or `"validation"`.

- method:

  Character method tag, for example `"apsim:predict"`.

- params:

  A `data.frame` of fitted parameters (default empty).

- outputs:

  The simulated report (`data.frame`) or `NULL`.

- metadata:

  A named list of auxiliary provenance.

- seed:

  Integer RNG seed (`NA` when none).

## Value

An `apsim_manifest` S7 object.

## Examples

``` r
m <- apsim_manifest("parameters", "apsim:estimate:mitscherlich",
                    params = data.frame(ymax = 4.2, rate = 0.018, y0 = 1.1))
m@inferential_target
#> [1] "parameters"
```
