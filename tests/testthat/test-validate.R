# The validation metrics and verdict are pure numeric code, tested offline against
# hand-computable values and the Moriasi et al. (2007) performance bands.

test_that("a perfect fit scores NSE 1 and zero error", {
  g <- apsimR:::.apsim_gof(c(2, 4, 6, 8), c(2, 4, 6, 8))
  expect_equal(g$nse, 1)
  expect_equal(g$rmse, 0)
  expect_equal(g$r2, 1)
  expect_equal(g$d, 1)
})

test_that("metrics match closed-form values", {
  o <- c(2.1, 3.4, 4.0, 5.2)
  p <- c(2.0, 3.6, 3.8, 5.0)
  g <- apsimR:::.apsim_gof(o, p)
  expect_equal(g$n, 4L)
  expect_equal(g$me, mean(p - o))
  expect_equal(g$rmse, sqrt(mean((p - o)^2)))
  expect_equal(g$nse, 1 - sum((o - p)^2) / sum((o - mean(o))^2))
  expect_equal(g$pbias, 100 * sum(p - o) / sum(o))
})

test_that("non-finite pairs are dropped before scoring", {
  g <- apsimR:::.apsim_gof(c(1, 2, NA, 4), c(1, 2, 3, NA))
  expect_equal(g$n, 2L)
})

test_that("the verdict follows the Moriasi bands", {
  band <- function(nse) apsimR:::.apsim_verdict(data.frame(nse = nse))
  expect_identical(band(0.80), "very good")
  expect_identical(band(0.70), "good")
  expect_identical(band(0.60), "satisfactory")
  expect_identical(band(0.40), "unsatisfactory")
  expect_identical(band(NA_real_), "indeterminate")
})

test_that("apsim_validate emits a validation manifest with a verdict", {
  v <- apsim_validate(c(2, 3.6, 3.8, 5), c(2.1, 3.4, 4, 5.2))
  expect_s3_class(v, "apsimR::apsim_manifest")
  expect_identical(v@inferential_target, "validation")
  expect_identical(v@metadata$verdict, "very good")
  expect_equal(nrow(v@outputs), 4L)
})

test_that("data frames join on a key before pairing", {
  pd <- data.frame(Date = 1:3, Yield = c(10, 20, 30))
  od <- data.frame(Date = c(1, 3), Yield = c(11, 28))
  v <- apsim_validate(pd, od, predicted_col = "Yield", observed_col = "Yield",
                      by = "Date")
  expect_equal(v@params$n, 2L)
})

test_that("mismatched lengths without a join key are rejected", {
  expect_error(apsim_validate(1:3, 1:4), "length")
})

test_that("the plot abstains without ggplot2, else returns a ggplot", {
  v <- apsim_validate(c(2, 3.6, 3.8, 5), c(2.1, 3.4, 4, 5.2))
  p <- apsim_validation_plot(v)
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    expect_s3_class(p, "ggplot")
  } else {
    expect_true(is_apsim_abstention(p))
  }
})

test_that("scoring needs equal lengths and two complete pairs", {
  expect_error(apsimR:::.apsim_gof(1:3, 1:2), "equal length")
  expect_error(apsimR:::.apsim_gof(c(1, NA), c(1, 2)), "at least two")
})

test_that("data frame inputs must name an existing column", {
  sim <- data.frame(Yield = c(2, 3))
  expect_error(apsim_validate(sim, c(2, 3)), "predicted_col")
  expect_error(apsim_validate(sim, c(2, 3), predicted_col = "Biomass"),
               "no column `Biomass`")
  expect_error(apsim_validate("2, 3", c(2, 3)), "must be an apsim_manifest")
  expect_error(
    apsim_validate(data.frame(d = 1:2, y = 1:2), data.frame(day = 1:2, y = 1:2),
                   predicted_col = "y", observed_col = "y", by = "d"),
    "must be a column of both")
})

test_that("a predictions manifest is scored from its outputs", {
  m <- apsim_manifest("predictions", "apsim:predict",
                      outputs = data.frame(Yield = c(2, 3.5, 4)))
  v <- apsim_validate(m, c(2, 3.5, 4), predicted_col = "Yield")
  expect_equal(v@params$rmse, 0)
  expect_equal(v@params$nse, 1)
})

test_that("only a validation manifest can be plotted", {
  m <- apsim_manifest_by_target()$predictions
  expect_error(apsim_validation_plot(m), "apsim_validate")
})
