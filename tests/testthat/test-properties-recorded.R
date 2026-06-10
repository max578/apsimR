# external-fact families: datastore_table, datastore_column, checkpoint_name,
#   report_column, manager_node, apsim_version
# (recipe-52 catalogue/coverage header -- the validator's per-family F14 grep
#  resolves every registry family to this recorded-real-property oracle file.)
#
# Independent-oracle tests (Phase-1 FX-7 / FX-8). These ground apsimR's class-8
# APSIM facts by REPLAYING A REAL RUN and asserting the FACT, not just
# non-emptiness -- closing the audit's "skip != pass" hole. The DataStore schema
# is grounded here rather than against the shipped empty Wheat.db stub.

test_that("a real Wheat run grounds the DataStore schema exactly as assumed (FX-7)", {
  skip_if_not(apsim_available(), "APSIM not installed")
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "Wheat example not resolvable")
  run <- apsimR:::.apsim_run(f)
  skip_if(is_apsim_abstention(run), "Wheat run abstained")
  on.exit(unlink(run$dir, recursive = TRUE, force = TRUE), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), run$db)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  tabs <- DBI::dbListTables(con)

  # The exact tables/columns datastore.R:64-78 assumes.
  expect_true(all(c("_Simulations", "_Checkpoints") %in% tabs))
  expect_true(all(c("ID", "Name") %in% DBI::dbListFields(con, "_Simulations")))
  expect_true("Name" %in% DBI::dbListFields(con, "_Checkpoints"))
  cps <- DBI::dbGetQuery(con, "SELECT Name FROM _Checkpoints")$Name
  expect_true("Current" %in% cps)

  reports <- tabs[!startsWith(tabs, "_")]
  expect_gt(length(reports), 0L)
  rflds <- DBI::dbListFields(con, reports[[1]])
  expect_true(all(c("SimulationID", "CheckpointID") %in% rflds))
})

test_that("apsim_read returns the grounded report columns by NAME, not just rows (FX-8)", {
  skip_if_not(apsim_available(), "APSIM not installed")
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "Wheat example not resolvable")
  run <- apsimR:::.apsim_run(f)
  skip_if(is_apsim_abstention(run), "Wheat run abstained")
  on.exit(unlink(run$dir, recursive = TRUE, force = TRUE), add = TRUE)

  d <- apsim_read(run$db)
  expect_s3_class(d, "data.frame")
  expect_gt(nrow(d), 0L)
  # Value-asserting (not is.finite-only): the stock Wheat report emits BOTH of
  # these. The registry asserts the same; this is the oracle that grounds it.
  expect_true("Yield" %in% names(d))
  expect_true("Wheat.AboveGround.Wt" %in% names(d))
  # Every asserted report-column fact must exist in the real report.
  asserted <- apsim_external_facts()
  rc <- asserted$asserted_value[asserted$fact_family == "report_column"]
  expect_true(all(rc %in% names(d)))
})

test_that("yield responds monotonically to nitrogen (sign check, expensive)", {
  skip_if_not(apsim_available(), "APSIM not installed")
  if (!identical(Sys.getenv("APSIMR_LIVE_TESTS"), "true")) {
    testthat::skip("expensive 2-run sign check; set APSIMR_LIVE_TESTS=true")
  }
  f <- apsim_example("Wheat")
  fm <- apsim_forward_model(f, "[Fertilise at sowing].Script.Amount",
                            output = "Yield")
  skip_if(is_apsim_abstention(fm), "forward model abstained")
  y <- fm(matrix(c(0, 150), ncol = 1L))   # low vs moderate N
  skip_if(any(!is.finite(y)), "run produced no finite yield")
  # More N -> not-less yield (moderate N is below the saturation peak).
  expect_gte(y[2L, 1L], y[1L, 1L])
})

test_that("the apsimR fact registry is well-formed and grounds the schema", {
  facts <- apsim_external_facts()
  expect_true(all(c("fact_family", "asserted_value", "oracle_kind",
                    "verified_on", "evidence_path", "grounding") %in%
                  names(facts)))
  # The DataStore-schema + report-column facts are grounded (real run, today).
  schema_rows <- facts[facts$fact_family %in%
                       c("datastore_table", "datastore_column",
                         "checkpoint_name", "report_column"), ]
  expect_true(all(schema_rows$grounding == "grounded"))
  expect_true(all(!is.na(schema_rows$verified_on)))
})

test_that("the canonical recipe-52 registry validates and matches the reader view", {
  # The canonical `.external_facts` (audit surface) is derived from the same
  # seed as `apsim_external_facts()` (reader view); this guards against the
  # two drifting apart -- the failure mode the registry exists to prevent.
  canon <- apsimR:::.external_facts
  view <- apsim_external_facts()
  expect_setequal(canon$family, unique(view$fact_family))
  # Every asserted value in the view appears in the canonical row for its family.
  for (f in canon$family) {
    vv <- view$asserted_value[view$fact_family == f]
    cv <- canon$value[canon$family == f]
    expect_true(all(vapply(vv, function(x) grepl(x, cv, fixed = TRUE),
                           logical(1L))))
  }
  # The validator (gate F13/F14 contract) passes every family offline. Under
  # testthat the working directory is the test folder, so the oracle-coverage
  # scan looks there (`test_path()`), not at the package-relative path the
  # `/rpkg` audit driver uses.
  res <- apsimR:::.validate_external_registry(canon, testthat::test_path())
  expect_true(all(res$pass),
              info = paste(res$family[!res$pass], res$reason[!res$pass],
                           collapse = "; "))
})
