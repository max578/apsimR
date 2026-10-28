# Read a report from the server after a run

Fetches columns of a report table produced by the most recent
[`apsim_run()`](https://max578.github.io/apsimR/reference/apsim_run.md),
decoding the server's typed column stream into a `data.frame`. The named
report must contain rows (the server signals an empty report as an
error, not an empty frame).

## Usage

``` r
apsim_output(server, table, columns)
```

## Arguments

- server:

  An open `apsim_server` handle.

- table:

  Character report-table name.

- columns:

  Character vector of column names to fetch.

## Value

A `data.frame` with one column per requested name.

## Examples

``` r
# \donttest{
f <- apsim_example("Wheat")
if (!is.na(f) && apsim_available()) {
  srv <- apsim_server(f)
  if (!is_apsim_abstention(srv) && !is_apsim_abstention(apsim_run(srv))) {
    d <- apsim_output(srv, "Report", "Yield")
  }
  close(srv)
}
# }
```
