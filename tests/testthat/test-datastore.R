# The DataStore reader, on a small SQLite file laid out the way APSIM writes it:
# a report keyed by simulation and checkpoint, plus a report with no keys.

datastore_fixture <- function() {
  db <- tempfile(fileext = ".db")
  write_datastore(
    db,
    reports = list(
      Report = data.frame(SimulationID = c(1L, 2L, 1L),
                          CheckpointID = c(1L, 1L, 2L),
                          Yield = c(3.8, 4.1, 9.9)),
      HarvestReport = data.frame(Year = 2020L, Yield = 4.0)),
    simulations = data.frame(ID = 1:2, Name = c("Sim1", "Sim2")),
    checkpoints = data.frame(ID = 1:2, Name = c("Current", "Calibrated")))
}

test_that("apsim_reports lists the reports and hides the metadata tables", {
  expect_setequal(apsim_reports(datastore_fixture()),
                  c("Report", "HarvestReport"))
})

test_that("apsim_read names the simulations and keeps the Current checkpoint", {
  d <- apsim_read(datastore_fixture(), report = "Report")
  d <- d[order(d$SimulationName), ]
  expect_identical(names(d)[1L], "SimulationName")
  expect_identical(d$SimulationName, c("Sim1", "Sim2"))
  expect_identical(d$Yield, c(3.8, 4.1))
})

test_that("apsim_read reads another checkpoint by name", {
  d <- apsim_read(datastore_fixture(), report = "Report",
                  checkpoint = "Calibrated")
  expect_identical(d$SimulationName, "Sim1")
  expect_identical(d$Yield, 9.9)
})

test_that("a report without simulation keys is returned as stored", {
  d <- apsim_read(datastore_fixture(), report = "HarvestReport")
  expect_false("SimulationName" %in% names(d))
  expect_identical(d$Year, 2020L)
})

test_that("with no report named, the only report is read", {
  db <- tempfile(fileext = ".db")
  write_datastore(db, list(Report = data.frame(SimulationID = 1L,
                                               CheckpointID = 1L,
                                               Yield = 5.5)))
  expect_identical(apsim_read(db)$Yield, 5.5)
})

test_that("missing files, reports and report tables are errors", {
  missing <- tempfile(fileext = ".db")
  expect_error(apsim_reports(missing), "not found")
  expect_error(apsim_read(missing), "not found")
  expect_error(apsim_read(datastore_fixture(), report = "Daily"),
               "not in the DataStore")
  empty <- tempfile(fileext = ".db")
  write_datastore(empty, list())
  expect_error(apsim_read(empty), "no report tables")
})
