# The emulator's GP, leave-one-out diagnostics and prediction are tested offline
# on a known smooth function; only the design-running step needs the simulator.

smooth_truth <- function(X) {
  X <- as.matrix(X)
  sin(X[, 1L]) + 0.1 * X[, 1L]
}

test_that("the exact GP interpolates the training data and predicts the truth", {
  X <- matrix(seq(0, 10, length.out = 15L), ncol = 1L)
  y <- smooth_truth(X)
  gp <- apsimR:::.apsim_gp_train(X, y)
  at_train <- apsimR:::.apsim_gp_predict(gp, X)
  expect_equal(at_train$mean, y, tolerance = 1e-3)        # interpolation
  q <- matrix(c(2.5, 7.3), ncol = 1L)
  pred <- apsimR:::.apsim_gp_predict(gp, q)
  expect_equal(pred$mean, smooth_truth(q), tolerance = 1e-2)
  expect_true(all(pred$sd >= 0))
})

test_that("leave-one-out diagnostics are honest on a smooth function", {
  X <- matrix(seq(0, 10, length.out = 20L), ncol = 1L)
  y <- smooth_truth(X)
  loo <- apsimR:::.apsim_emulator_loo(
    apsimR:::.apsim_emulator_backend("exact"), X, y)
  expect_lt(loo$rmse, 0.05)
  expect_gt(loo$r2, 0.99)
  expect_length(loo$predicted, 20L)
})

test_that("predict() dispatches on the S7 emulator object", {
  X <- matrix(seq(0, 10, length.out = 12L), ncol = 1L)
  y <- smooth_truth(X)
  impl <- apsimR:::.apsim_emulator_backend("exact")
  em <- apsimR:::apsim_emulator(
    backend = "exact", parm_paths = "x", target = "y", X = X,
    y = as.numeric(y), gp = impl$train(X, y),
    loo = apsimR:::.apsim_emulator_loo(impl, X, y))
  out <- predict(em, matrix(c(2.5, 7.3), ncol = 1L))
  expect_s3_class(out, "data.frame")
  expect_identical(names(out), c("mean", "sd"))
  expect_equal(out$mean, smooth_truth(matrix(c(2.5, 7.3), ncol = 1L)),
               tolerance = 1e-2)
})

test_that("the pesto backend abstains when PESTO is absent", {
  skip_if(requireNamespace("PESTO", quietly = TRUE), "PESTO is installed")
  a <- apsim_emulate(apsimx_fixture(), "[X].p", 0, 1, output = "Yield",
                     backend = "pesto")
  expect_true(is_apsim_abstention(a))
  expect_identical(a$reason, "feature_unsupported")
})

# Live emulation: skipped without APSIM. A fertiliser->yield emulator should fit.
test_that("an APSIM yield emulator fits with honest LOO", {
  skip_if_no_live_apsim()
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "no Wheat example")
  em <- apsim_emulate(f, "[Fertilise at sowing].Script.Amount",
                      lower = 0, upper = 250, output = "Yield", n = 10L,
                      seed = 1L)
  skip_if(is_apsim_abstention(em), "emulation unavailable")
  expect_s3_class(em, "apsimR::apsim_emulator", exact = FALSE)
  expect_true(is.finite(em@loo$rmse))
})
