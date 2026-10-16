# The calibration backends are tested offline with a cheap analytic forward model
# (no simulator), so the optimiser / ensemble-smoother wiring and the manifest
# assembly are exercised without APSIM. A linear map obs = 2a + b has a known
# minimum-misfit ridge through (a, b); both backends should reach obs = target.

analytic_fm <- function(theta) {
  theta <- as.matrix(theta)
  cbind(y = 2 * theta[, 1L] + theta[, 2L])
}

test_that("obs_sd defaults to a fraction of the observation", {
  sd <- apsimR:::.apsim_obs_sd(NULL, c(y = 100))
  expect_equal(unname(sd), 10)
  expect_error(apsimR:::.apsim_obs_sd(c(-1), c(y = 1)), "positive")
})

test_that("the optim backend reaches the target and emits a parameters manifest", {
  m <- apsimR:::.apsim_calibrate_optim(
    analytic_fm, c("a", "b"), c(0, 0), c(5, 5),
    observed = c(y = 5), obs_sd = c(y = 0.2), weights = NULL, seed = 1L)
  expect_s3_class(m, "apsimR::apsim_manifest")
  expect_identical(m@inferential_target, "parameters")
  expect_lt(m@metadata$objective, 1e-4)
  fitted <- 2 * m@params[[1L]] + m@params[[2L]]
  expect_equal(fitted, 5, tolerance = 1e-2)
})

test_that("the ies backend returns a posterior ensemble matching the target", {
  skip_if_not_installed("PESTO")
  m <- apsimR:::.apsim_calibrate_ies(
    analytic_fm, c("a", "b"), c(0, 0), c(5, 5),
    observed = c(y = 5), obs_sd = c(y = 0.2), n_real = 20L, noptmax = 3L,
    inflation = 0.8, seed = 1L)
  expect_s3_class(m, "apsimR::apsim_manifest")
  expect_equal(nrow(m@params), 20L)
  expect_equal(m@metadata$failure_rate, 0)
  expect_equal(m@outputs$predicted, 5, tolerance = 0.2)
})

test_that("the ies backend abstains cleanly when PESTO is absent", {
  skip_if(requireNamespace("PESTO", quietly = TRUE), "PESTO is installed")
  a <- apsim_calibrate(apsimx_fixture(), "[X].p", 0, 1,
                       observed = c(y = 1), output = "Yield", backend = "ies")
  expect_true(is_apsim_abstention(a))
  expect_identical(a$reason, "feature_unsupported")
})

# Live calibration: skipped without APSIM. Recovers a fertiliser rate from a
# target yield on a twin experiment (the simulator is its own ground truth).
test_that("optim recovers a fertiliser rate from a target yield", {
  skip_if_no_live_apsim()
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "no Wheat example")
  truth <- apsim_forward_model(f, "[Fertilise at sowing].Script.Amount",
                               output = "Yield")
  skip_if(is_apsim_abstention(truth), "forward model unavailable")
  target <- truth(matrix(120, 1L, 1L))[1L, 1L]
  m <- apsim_calibrate(f, "[Fertilise at sowing].Script.Amount",
                       lower = 0, upper = 250, observed = c(Yield = target),
                       output = "Yield", backend = "optim", seed = 1L)
  skip_if(is_apsim_abstention(m), "calibration unavailable")
  expect_equal(m@params[[1L]], 120, tolerance = 25)
})

# apsim_calibrate() itself, with the APSIM forward model replaced by the
# analytic map above.
local_analytic_forward_model <- function(fm = analytic_fm, env = parent.frame()) {
  testthat::local_mocked_bindings(
    apsim_forward_model = function(sim, parm_paths, output, report = NULL,
                                   ...) fm,
    .env = env)
}

test_that("apsim_calibrate with optim fits the target and names the parameters", {
  local_analytic_forward_model()
  m <- apsim_calibrate(apsimx_fixture(), c("a", "b"), lower = 0, upper = 5,
                       observed = c(y = 5), output = "y", obs_sd = 0.2,
                       backend = "optim", seed = 1L)
  expect_identical(m@method, "apsim:calibrate:optim")
  expect_identical(names(m@params), c("a", "b"))
  expect_equal(2 * m@params$a + m@params$b, 5, tolerance = 1e-2)
  expect_equal(m@outputs$predicted, 5, tolerance = 1e-2)
  expect_identical(m@metadata$weights, 1 / 0.2^2)
})

test_that("explicit weights replace the default inverse variance", {
  local_analytic_forward_model()
  m <- apsim_calibrate(apsimx_fixture(), c("a", "b"), lower = 0, upper = 5,
                       observed = c(y = 5), output = "y", weights = 3,
                       backend = "optim")
  expect_identical(m@metadata$weights, 3)
})

test_that("calibration inputs are validated before any run", {
  expect_error(apsim_calibrate(apsimx_fixture(), "a", 1, 0, c(y = 1), "y"),
               "must exceed")
  expect_error(apsim_calibrate(apsimx_fixture(), "a", 0, 1, 1, "y"),
               "named numeric")
  expect_error(apsimR:::.apsim_obs_sd(c(1, 2, 3), c(y = 1, z = 2)),
               "aligned")
  expect_equal(apsimR:::.apsim_obs_sd(0.5, c(y = 1, z = 2)), c(0.5, 0.5))
})

test_that("a forward model with the wrong number of outputs is an error", {
  local_analytic_forward_model(function(theta) {
    cbind(p = 1, q = 2)
  })
  expect_error(
    apsim_calibrate(apsimx_fixture(), c("a", "b"), 0, 5,
                    observed = c(y = 5), output = "y", backend = "optim"),
    "returned 2 observation")
})

test_that("predictions without names are aligned by position", {
  pred <- apsimR:::.apsim_align_pred(c(1, 2), c(y = 1, z = 2))
  expect_identical(pred, c(y = 1, z = 2))
})
