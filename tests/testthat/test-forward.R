# The forward-model helpers (value formatting, observation reduction, theta and
# observation assembly) carry the simulator-independent logic, tested offline.

test_that("numeric values format in fixed notation APSIM accepts", {
  expect_identical(apsimR:::.apsim_fmt_value(0.000123), "0.000123")
  expect_false(grepl("e", apsimR:::.apsim_fmt_value(1e-7)))
  expect_identical(apsimR:::.apsim_fmt_value("1991-12-31"), "1991-12-31")
})

test_that("an observe spec coerces from columns and from a function", {
  rep <- data.frame(Yield = c(1, 2, 3), N = c(10, 20, 30))
  by_col <- apsimR:::.apsim_observe_fn("Yield")
  expect_identical(by_col(rep), c(Yield = 3))            # final value
  by_mean <- apsimR:::.apsim_observe_fn("N", reduce = mean)
  expect_identical(by_mean(rep), c(N = 20))
  by_fn <- apsimR:::.apsim_observe_fn(function(d) c(s = sum(d$Yield)))
  expect_identical(by_fn(rep), c(s = 6))
})

test_that("a missing observed column is reported, not silently dropped", {
  rep <- data.frame(Yield = 1)
  f <- apsimR:::.apsim_observe_fn("Nope")
  expect_error(f(rep), "no column")
})

test_that("theta coercion enforces the parameter count", {
  m <- apsimR:::.apsim_as_theta(c(1, 2), c("a", "b"))
  expect_equal(dim(m), c(1L, 2L))
  expect_identical(colnames(m), c("a", "b"))
  expect_error(apsimR:::.apsim_as_theta(c(1, 2, 3), c("a", "b")), "aligned")
})

test_that("failed realisations become NA rows, not dropped rows", {
  rows <- list(c(y = 1), NULL, c(y = 3))
  m <- apsimR:::.apsim_bind_obs(rows)
  expect_equal(dim(m), c(3L, 1L))
  expect_true(is.na(m[2L, 1L]))
  expect_equal(m[, 1L], c(1, NA, 3), ignore_attr = TRUE)
})

test_that("apsim_forward_model abstains without a simulator", {
  on.exit(apsim_configure(), add = TRUE)
  apsim_configure(models = file.path(tempdir(), "no-such-Models"))
  fm <- apsim_forward_model(apsimx_fixture(), "[X].p", output = "Yield")
  expect_true(is_apsim_abstention(fm))
  expect_identical(fm$reason, "runtime_unavailable")
})

# Live forward model: skipped without APSIM. The N-rate response is monotone.
test_that("the forward model runs APSIM and gives a monotone N response", {
  skip_if_not(apsim_available(), "APSIM not installed")
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "no Wheat example")
  fm <- apsim_forward_model(f, "[Fertilise at sowing].Script.Amount",
                            output = "Yield")
  skip_if(is_apsim_abstention(fm), "forward model unavailable")
  obs <- fm(matrix(c(0, 200), nrow = 2L, ncol = 1L))
  expect_equal(dim(obs), c(2L, 1L))
  expect_gt(obs[2L, 1L], obs[1L, 1L])
})

# The forward model with the simulator replaced by an R stand-in: each run
# reads the `--apply` config and writes Yield = 10 * value to the DataStore.
# A negative value fails the run.
fake_apply_yield <- function(cfg, work) {
  lines <- readLines(cfg)
  value <- as.numeric(sub("^.* = ", "", lines[[1L]]))
  if (value < 0) {
    return(failed_run("Error: negative rate"))
  }
  write_datastore(db_path(work), list(
    Report = data.frame(SimulationID = 1L, CheckpointID = 1L,
                        Yield = c(0, 10 * value))))
  "Finished"
}

test_that("each row of theta is one run, reduced to the report's final value", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(apply = fake_apply_yield)
  fm <- apsim_forward_model(apsimx_fixture(), "[Fertilise at sowing].Script.Amount",
                            output = "Yield")
  obs <- fm(matrix(c(1, 2.5), ncol = 1L))
  expect_identical(colnames(obs), "Yield")
  expect_equal(obs[, "Yield"], c(10, 25))
})

test_that("the config line carries the parameter path and the value", {
  on.exit(apsim_configure(), add = TRUE)
  seen <- new.env()
  local_fake_simulator(apply = function(cfg, work) {
    seen$cfg <- readLines(cfg)
    fake_apply_yield(cfg, work)
  })
  fm <- apsim_forward_model(apsimx_fixture(), "[Sow].Script.Population",
                            output = "Yield")
  fm(120)
  expect_identical(seen$cfg, c("[Sow].Script.Population = 120", "run"))
})

test_that("a failed run is an NA row and an all-failed batch is an error", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(apply = fake_apply_yield)
  fm <- apsim_forward_model(apsimx_fixture(), "[X].p", output = "Yield")
  obs <- fm(matrix(c(2, -1), ncol = 1L))
  expect_equal(obs[, "Yield"], c(20, NA))
  expect_error(fm(matrix(-1, ncol = 1L)), "every APSIM realisation failed")
})

test_that("a run whose output function fails is an NA row", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(apply = fake_apply_yield)
  fm <- apsim_forward_model(apsimx_fixture(), "[X].p",
                            output = function(report) {
                              if (report$Yield[2L] > 50) stop("too high")
                              c(Yield = report$Yield[2L])
                            })
  obs <- fm(matrix(c(1, 9), ncol = 1L))
  expect_equal(obs[, "Yield"], c(10, NA))
})

test_that("parameter paths must be given", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(apply = fake_apply_yield)
  expect_error(apsim_forward_model(apsimx_fixture(), character(0),
                                   output = "Yield"),
               "non-empty character vector")
  expect_error(apsimR:::.apsim_observe_fn(character(0)), "non-empty")
})
