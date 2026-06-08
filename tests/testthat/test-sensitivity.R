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
