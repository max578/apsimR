# The sensitivity machinery is tested offline with an analytic forward model whose
# true index ordering is known: y = 2a + b + 0.5 a*b makes `a` dominant and adds a
# genuine interaction (so Morris sigma > 0 and Sobol total > first-order).

analytic_model <- function(x) {
  x <- as.matrix(x)
  2 * x[, 1L] + x[, 2L] + 0.5 * x[, 1L] * x[, 2L]
}

test_that("Morris screening ranks the dominant factor and flags interaction", {
  set.seed(1)
  mo <- apsimR:::.apsim_sa_morris(analytic_model, c("a", "b"), c(0, 0),
                                  c(5, 5), r = 8L, levels = 6L)
  expect_identical(mo$indices$parameter, c("a", "b"))
  expect_gt(mo$indices$mu_star[1L], mo$indices$mu_star[2L])
  expect_true(all(mo$indices$sigma > 0))
  expect_equal(mo$runs, 8L * 3L)
})

test_that("Sobol-Jansen decomposes variance into first-order and total", {
  set.seed(2)
  so <- apsimR:::.apsim_sa_sobol(analytic_model, c("a", "b"), c(0, 0),
                                 c(5, 5), n = 200L, nboot = 0L)
  expect_identical(so$indices$parameter, c("a", "b"))
  expect_gt(so$indices$S[1L], so$indices$S[2L])
  expect_true(all(so$indices$T >= so$indices$S - 0.05))
})

test_that("failed runs are mean-imputed and counted, not silently dropped", {
  # A model that returns NA on its first call exercises the imputation path.
  calls <- 0L
  flaky <- function(x) {
    calls <<- calls + 1L
    y <- analytic_model(x)
    y[1L] <- NA_real_
    y
  }
  set.seed(3)
  expect_no_error(
    apsimR:::.apsim_sa_morris(flaky, c("a", "b"), c(0, 0), c(5, 5),
                              r = 4L, levels = 6L))
})

# Live sensitivity: skipped without APSIM.
test_that("Morris runs on APSIM and returns finite indices", {
  skip_if_no_live_apsim()
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "no Wheat example")
  m <- apsim_sensitivity(f, "[Fertilise at sowing].Script.Amount",
                         lower = 0, upper = 250, output = "Yield",
                         method = "morris", morris_r = 4L, seed = 1L)
  skip_if(is_apsim_abstention(m), "sensitivity unavailable")
  expect_identical(m@inferential_target, "sensitivity")
  expect_true(is.finite(m@params$mu_star[1L]))
})

# apsim_sensitivity() itself, with the APSIM forward model replaced by the
# linear map y = 2a + b over a, b in [0, 5]. sensitivity::morris rescales each
# factor to [0, 1] before differencing, so every elementary effect is the
# coefficient times the range: 10 for a, 5 for b, with no spread.
linear_fm <- function(theta) {
  theta <- as.matrix(theta)
  cbind(Yield = 2 * theta[, 1L] + theta[, 2L])
}

local_linear_forward_model <- function(fm = linear_fm, env = parent.frame()) {
  testthat::local_mocked_bindings(
    apsim_forward_model = function(sim, parm_paths, output, report = NULL,
                                   ...) fm,
    .env = env)
}

test_that("Morris effects of a linear output are coefficient times range", {
  local_linear_forward_model()
  m <- apsim_sensitivity(apsimx_fixture(), c("a", "b"), lower = 0, upper = 5,
                         output = "Yield", method = "morris", morris_r = 4L,
                         seed = 1L)
  expect_identical(m@inferential_target, "sensitivity")
  expect_identical(m@method, "apsim:sensitivity:morris")
  expect_equal(m@params$mu_star, c(10, 5))
  expect_equal(m@params$sigma, c(0, 0))
  expect_identical(m@metadata$n_runs, 4L * 3L)
  expect_identical(m@metadata$n_failures, 0L)
})

test_that("Sobol indices of an additive output follow the variance shares", {
  # Var(2a) = 4 Var(b) for a, b ~ U(0, 5), so S_a = 0.8 and S_b = 0.2.
  local_linear_forward_model()
  m <- apsim_sensitivity(apsimx_fixture(), c("a", "b"), lower = 0, upper = 5,
                         output = "Yield", method = "sobol", sobol_n = 2000L,
                         nboot = 0L, seed = 2L)
  expect_equal(m@params$S, c(0.8, 0.2), tolerance = 0.1)
  expect_identical(m@metadata$n_runs, 2000L * 4L)
})

test_that("both methods merge into one row per factor, failures counted", {
  flaky <- function(theta) {
    out <- linear_fm(theta)
    out[1L, 1L] <- NA_real_
    out
  }
  local_linear_forward_model(flaky)
  m <- apsim_sensitivity(apsimx_fixture(), c("a", "b"), lower = 0, upper = 5,
                         output = "Yield", method = "both", morris_r = 4L,
                         sobol_n = 50L, nboot = 0L, seed = 3L)
  expect_identical(m@params$parameter, c("a", "b"))
  expect_true(all(c("mu_star", "sigma", "S", "T") %in% names(m@params)))
  # one failed run in the Morris batch and one in the Sobol batch
  expect_identical(m@metadata$n_failures, 2L)
})

test_that("sensitivity needs upper above lower and passes on an abstention", {
  expect_error(apsim_sensitivity(apsimx_fixture(), "a", lower = 1, upper = 1,
                                 output = "Yield"),
               "must exceed")
  on.exit(apsim_configure(), add = TRUE)
  apsim_configure(models = file.path(tempdir(), "no-such-Models"))
  ab <- apsim_sensitivity(apsimx_fixture(), "a", lower = 0, upper = 1,
                          output = "Yield")
  expect_true(is_apsim_abstention(ab))
})
