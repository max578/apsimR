# Read a report from an APSIM DataStore

Returns one report table joined to its simulation names and filtered to
a checkpoint. Reading is a single pushed-down SQL JOIN, so only the
requested columns and rows leave SQLite.

## Usage

``` r
apsim_read(db, report = NULL, checkpoint = "Current")
```

## Arguments

- db:

  Character path to a `.db` DataStore.

- report:

  Character report-table name, or `NULL` (default) for the first report
  in the file.

- checkpoint:

  Character checkpoint name (default `"Current"`).

## Value

A `data.frame`: the report columns, prefixed with a `SimulationName`
column when the report is simulation-keyed.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# d <- apsim_read(run$db, report = "Report")
}
```
