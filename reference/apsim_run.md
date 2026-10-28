# Run the server's in-memory simulation, optionally with modified parameters

Runs the `.apsimx` the server holds, optionally overriding model
parameters for this run. The file is not reloaded, so an adaptive sweep
pays the load cost once. Read the results with
[`apsim_output()`](https://max578.github.io/apsimR/reference/apsim_output.md).

## Usage

``` r
apsim_run(server, changes = NULL)
```

## Arguments

- server:

  An open `apsim_server` handle.

- changes:

  A named list of parameter overrides: names are APSIM model paths (for
  example `"[Wheat].Phenology.MinimumLeafNumber"`), values are R scalars
  (numeric, integer, logical, `Date`, character) or a numeric vector
  (passed as a double array). `NULL` (default) runs the file unchanged.

## Value

Invisibly `TRUE` on success; errors carry the simulator's message.

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
