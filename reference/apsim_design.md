# Build an experimental design over an APSIM parameter space

Generates parameter points filling the box `[lower, upper]` for the
named parameters. A Latin-hypercube design (the default) spreads `n`
points evenly through the space – the standard choice for training an
emulator; a grid gives an exhaustive factorial (`n` becomes
points-per-dimension); random gives an independent uniform sample. The
design is reproducible through `seed`.

## Usage

``` r
apsim_design(
  parm_paths,
  lower,
  upper,
  n = 20L,
  method = c("lhs", "grid", "random"),
  seed = NULL
)
```

## Arguments

- parm_paths:

  Character vector of APSIM node paths (the design columns).

- lower, upper:

  Numeric vectors of box bounds, each aligned to `parm_paths` (recycled
  from length one).

- n:

  Integer. For `method = "lhs"` / `"random"`, the number of points; for
  `method = "grid"`, the number of points per dimension (so the design
  has `n ^ length(parm_paths)` rows).

- method:

  Character: `"lhs"` (default), `"grid"` or `"random"`.

- seed:

  Optional integer RNG seed for the stochastic methods.

## Value

A numeric matrix with `length(parm_paths)` named columns, one row per
design point.

## Examples

``` r
d <- apsim_design(c("[Sow].Script.Population", "[Fertilise].Amount"),
                  lower = c(50, 0), upper = c(200, 200), n = 8, seed = 1L)
dim(d)
#> [1] 8 2
```
