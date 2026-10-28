# Grounding status summary for apsimR's external facts

Collapses
[`apsim_external_facts()`](https://max578.github.io/apsimR/reference/apsim_external_facts.md)
to one row per fact family, so a caller can see at a glance which
classes of APSIM fact are grounded by a replayed real run and which are
still `"ungrounded"`.

## Usage

``` r
apsim_fact_status()
```

## Value

A `data.frame` with one row per `fact_family`: `n_facts`, `n_grounded`,
`n_unverified`.

## Examples

``` r
status <- apsim_fact_status()
status
#>        fact_family n_facts n_grounded n_unverified
#> 1    apsim_version       1          1            0
#> 2  checkpoint_name       1          1            0
#> 3 datastore_column       5          5            0
#> 4  datastore_table       3          3            0
#> 5     manager_node       2          2            0
#> 6    report_column       2          2            0
# families with at least one unverified fact
status[status$n_unverified > 0, ]
#> [1] fact_family  n_facts      n_grounded   n_unverified
#> <0 rows> (or 0-length row.names)
```
