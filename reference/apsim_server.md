# Start a persistent APSIM server holding a simulation in memory

Launches `apsim-server` over loopback TCP, holding `sim` in memory, and
opens a connection to it. The returned handle runs the file repeatedly –
optionally with modified parameters – without re-paying APSIM's per-run
load cost, which is the throughput path for calibration and uncertainty
loops. Returns an
[`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
when the server executable is unavailable.

## Usage

``` r
apsim_server(sim, port = NULL, timeout = 30)
```

## Arguments

- sim:

  An `apsim_sim` object or a path to an `.apsimx` file.

- port:

  Integer loopback port, or `NULL` (default) to pick a free one.

- timeout:

  Numeric seconds to wait for the server to accept a connection (default
  30).

## Value

An `apsim_server` handle (a classed environment), or an
`apsim_abstention`.

## Details

Always close the handle with
[`close()`](https://rdrr.io/r/base/connections.html) to stop the server
process.

## Examples

``` r
# \donttest{
f <- apsim_example("Wheat")
if (!is.na(f) && apsim_available()) {
  srv <- apsim_server(f)
  if (!is_apsim_abstention(srv)) {
    apsim_run(srv)
    close(srv)
  }
}
# }
```
