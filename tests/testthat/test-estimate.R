# The numeric fit is separated from the simulator so it is testable offline.

test_that("the Mitscherlich fit recovers known parameters", {
  set.seed(1)
  n_rate <- runif(60, 0, 220)
  yield <- 1.1 + 4.2 * (1 - exp(-0.018 * n_rate)) + rnorm(60, 0, 0.15)
  fit <- apsimR:::.apsim_fit_response(n_rate, yield, "mitscherlich")

  expect_identical(names(fit), c("ymax", "rate", "y0"))
  expect_equal(fit$ymax, 4.2, tolerance = 0.1)
  expect_equal(fit$rate, 0.018, tolerance = 0.15)
  expect_equal(fit$y0, 1.1, tolerance = 0.2)
})

test_that("the linear fit returns intercept and slope", {
  set.seed(2)
  x <- runif(40, 0, 10)
  y <- 2 + 1.5 * x + rnorm(40, 0, 0.2)
  fit <- apsimR:::.apsim_fit_response(x, y, "linear")

  expect_identical(names(fit), c("intercept", "slope"))
  expect_equal(fit$slope, 1.5, tolerance = 0.1)
  expect_equal(fit$intercept, 2, tolerance = 0.3)
})
