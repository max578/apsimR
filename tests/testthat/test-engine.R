test_that("availability and version have the right types", {
  expect_type(apsim_available(), "logical")
  v <- apsim_version()
  expect_true(is.character(v) && length(v) == 1L)
})

test_that("apsim_configure() reverts to discovery", {
  res <- apsim_configure()
  expect_true(is.list(res))
  expect_true(all(c("models", "server", "dotnet_root") %in% names(res)))
})

test_that("verbs abstain cleanly when the simulator is absent", {
  on.exit(apsim_configure(), add = TRUE)
  apsim_configure(models = file.path(tempdir(), "no-such-Models"))
  expect_false(apsim_available())

  ab <- apsim_predict(apsimx_fixture())
  expect_true(is_apsim_abstention(ab))
  expect_identical(ab$reason, "runtime_unavailable")

  ab2 <- apsim_estimate(apsimx_fixture(), x = "N", y = "Yield")
  expect_true(is_apsim_abstention(ab2))
})

test_that("apsim_example returns a path or NA", {
  ex <- apsim_example("Wheat")
  expect_true(is.character(ex) && length(ex) == 1L)
})

# The command-line paths, with the simulator replaced by an R stand-in that
# writes the DataStore a real run would.

test_that("apsim_version keeps the numeric token and asks the simulator once", {
  on.exit(apsim_configure(), add = TRUE)
  calls <- 0L
  local_fake_simulator(version_line = "APSIM 2026.5.8046.0")
  testthat::local_mocked_bindings(
    .apsim_system = function(rt, args, tmpdir = NA_character_) {
      calls <<- calls + 1L
      "APSIM 2026.5.8046.0"
    })
  expect_identical(apsim_version(), "2026.5.8046.0")
  expect_identical(apsim_version(), "2026.5.8046.0")
  expect_identical(calls, 1L)
})

test_that("apsim_version returns the whole line when it holds no version", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(version_line = "  development build  ")
  expect_identical(apsim_version(), "development build")
})

test_that("apsim_predict reads the run's report and cleans up after itself", {
  on.exit(apsim_configure(), add = TRUE)
  seen <- new.env()
  local_fake_simulator(run = function(work, extra) {
    seen$work <- work
    write_datastore(db_path(work), list(
      Report = data.frame(SimulationID = 1L, CheckpointID = 1L,
                          Yield = c(3.2, 4.4))))
    "Finished"
  })
  src <- apsimx_fixture()
  before <- readLines(src)
  m <- apsim_predict(src)
  expect_true(S7::S7_inherits(m, apsim_manifest))
  expect_identical(m@inferential_target, "predictions")
  expect_identical(m@outputs$Yield, c(3.2, 4.4))
  expect_identical(m@outputs$SimulationName, c("Sim1", "Sim1"))
  expect_identical(m@metadata$n_simulations, 1L)
  # the simulator ran on a copy, which is removed with its run directory
  expect_false(identical(dirname(seen$work), dirname(src)))
  expect_false(dir.exists(dirname(seen$work)))
  expect_identical(readLines(src), before)
})

test_that("simulation names and a thread cap reach the command line", {
  on.exit(apsim_configure(), add = TRUE)
  seen <- new.env()
  local_fake_simulator(run = function(work, extra) {
    seen$extra <- extra
    write_datastore(db_path(work), list(Report = data.frame(Yield = 1)))
    "Finished"
  })
  apsim_predict(apsimx_fixture(), simulations = "Sim1", cpu = 2L)
  expect_identical(seen$extra,
                   c("--simulation-names", "Sim1", "--cpu-count", "2"))
})

test_that("a failed run and a run without output abstain with the reason", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(run = function(work, extra) {
    failed_run("Loading", "Error: no weather file", "Exit")
  })
  ab <- apsim_predict(apsimx_fixture())
  expect_true(is_apsim_abstention(ab))
  expect_identical(ab$reason, "run_failed")
  expect_match(ab$detail, "no weather file")

  local_fake_simulator(run = function(work, extra) "Finished")
  ab <- apsim_predict(apsimx_fixture())
  expect_true(is_apsim_abstention(ab))
  expect_identical(ab$reason, "no_output")
})

test_that("running a file that does not exist is an error", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(run = function(work, extra) "Finished")
  expect_error(apsimR:::.apsim_run(tempfile(fileext = ".apsimx")),
               "does not exist")
})

test_that("apsim_estimate fits the response across the simulated input", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(run = function(work, extra) {
    n <- c(0, 50, 100, 150)
    write_datastore(db_path(work), list(
      Report = data.frame(SimulationID = 1L, CheckpointID = 1L, N = n,
                          Yield = 2 + 0.01 * n)))
    "Finished"
  })
  m <- apsim_estimate(apsimx_fixture(), x = "N", y = "Yield",
                      response = "linear")
  expect_identical(m@inferential_target, "parameters")
  expect_identical(m@method, "apsim:estimate:linear")
  expect_equal(m@params$intercept, 2)
  expect_equal(m@params$slope, 0.01)
  expect_identical(m@metadata$n, 4L)
  expect_error(apsim_estimate(apsimx_fixture(), x = "Rain", y = "Yield"),
               "must both be columns")
})
