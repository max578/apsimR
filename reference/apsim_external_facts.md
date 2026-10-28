# apsimR's external-authority (APSIM) fact registry

Enumerates the class-8 facts apsimR asserts about the APSIM simulator –
the DataStore SQLite schema, the `"Current"` checkpoint, report column
names, and manager node paths – with the oracle that grounds each and
the date it was last diffed against a live APSIM install. A fact is
*grounded* only when `verified_on` is a non-`NA` date; the
DataStore-schema and report-column facts are grounded by the
replayed-real-run oracle test, not by a skipped test.

## Usage

``` r
apsim_external_facts()
```

## Value

A `data.frame` with `fact_family`, `asserted_value`, `oracle_kind`,
`verified_on` (`Date`/`NA`), `evidence_path`, and a derived `grounding`
token (`"grounded"` / `"ungrounded"`).

## Examples

``` r
apsim_external_facts()
#>         fact_family                                asserted_value
#> 1   datastore_table                                  _Simulations
#> 2   datastore_table                                  _Checkpoints
#> 3   datastore_table                                        Report
#> 4  datastore_column                               _Simulations.ID
#> 5  datastore_column                             _Simulations.Name
#> 6  datastore_column                             _Checkpoints.Name
#> 7  datastore_column                           Report.SimulationID
#> 8  datastore_column                           Report.CheckpointID
#> 9   checkpoint_name                                       Current
#> 10    report_column                                         Yield
#> 11    report_column                          Wheat.AboveGround.Wt
#> 12     manager_node           [Fertilise at sowing].Script.Amount
#> 13     manager_node [Sow using a variable rule].Script.Population
#> 14    apsim_version                                 2026.5.8046.0
#>           oracle_kind verified_on                             evidence_path
#> 1        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 2        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 3        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 4        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 5        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 6        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 7        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 8        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 9        recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 10       recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 11       recorded_run  2026-06-09 tests/testthat/test-properties-recorded.R
#> 12 install_inspection  2026-06-09 tests/testthat/test-properties-recorded.R
#> 13 install_inspection  2026-06-09 tests/testthat/test-properties-recorded.R
#> 14 install_inspection  2026-06-09 tests/testthat/test-properties-recorded.R
#>    grounding
#> 1   grounded
#> 2   grounded
#> 3   grounded
#> 4   grounded
#> 5   grounded
#> 6   grounded
#> 7   grounded
#> 8   grounded
#> 9   grounded
#> 10  grounded
#> 11  grounded
#> 12  grounded
#> 13  grounded
#> 14  grounded
```
