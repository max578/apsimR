# List the report tables in an APSIM DataStore

List the report tables in an APSIM DataStore

## Usage

``` r
apsim_reports(db)
```

## Arguments

- db:

  Character path to a `.db` DataStore.

## Value

A character vector of report-table names (metadata tables, prefixed with
`_`, are excluded).

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
# apsim_reports(run$db)
}
```
