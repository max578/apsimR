# Is the APSIM simulator available?

Reports whether a runnable `Models` executable has been found (by
[`apsim_configure()`](https://max578.github.io/apsimR/reference/apsim_configure.md)
or auto-discovery). When this is `FALSE`, the simulator-dependent verbs
return an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
rather than running.

## Usage

``` r
apsim_available()
```

## Value

A single logical.

## Examples

``` r
if (apsim_available()) {
  apsim_version()
}
```
