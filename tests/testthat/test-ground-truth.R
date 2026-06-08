# The OSSE design logic is tested offline with an analytic forward model whose
# true effect is known in closed form. The outcome Y = tv + 2 x + 0.1 tv x makes
# the individual effect of control -> treated equal (treated - control) (1 + 0.1 x),
# so the average treatment effect is exact and the confounder x both drives
# assignment and moves the outcome.

osse_fm <- function(theta) {
  theta <- as.matrix(theta)
  cbind(Y = theta[, 1L] + 2 * theta[, 2L] + 0.1 * theta[, 1L] * theta[, 2L])
}

osse_units <- function(n = 400L, seed = 7L) {
  set.seed(seed)
  data.frame(x = stats::runif(n, 0, 5))
}

test_that("the recorded ATE equals the closed-form truth", {
  units <- osse_units()
  ate_true <- mean(10 + units$x)  # (treated - control)=10 -> ITE = 10 + x
  gr <- apsimR:::.apsim_osse(osse_fm, "T", control = 0, treated = 10,
                            units = units, target = NULL, assignment = "random",
                            prob = 0.5, confounder = NULL, confound_strength = 1,
                            seed = 1L)
  expect_s3_class(gr, "apsimR::apsim_ground_truth_result", exact = FALSE)
  expect_equal(gr@truth$ate, ate_true, tolerance = 1e-8)
  expect_identical(names(gr@observed), c("x", "W", "Y"))
  expect_equal(nrow(gr@observed), nrow(units))
})

test_that("random assignment leaves the naive estimator ~unbiased", {
  units <- osse_units()
  gr <- apsimR:::.apsim_osse(osse_fm, "T", control = 0, treated = 10,
                            units = units, target = NULL, assignment = "random",
                            prob = 0.5, confounder = NULL, confound_strength = 1,
                            seed = 1L)
  expect_lt(abs(gr@truth$confounding_bias), 1)        # small sampling noise only
})

test_that("confounded assignment biases the naive estimator but not the truth", {
  units <- osse_units()
  ate_true <- mean(10 + units$x)
  gc <- apsimR:::.apsim_osse(osse_fm, "T", control = 0, treated = 10,
                            units = units, target = NULL,
                            assignment = "confounded", prob = 0.5,
                            confounder = "x", confound_strength = 2, seed = 1L)
  expect_equal(gc@truth$ate, ate_true, tolerance = 1e-8)  # truth unchanged
  expect_gt(gc@truth$confounding_bias, 1)                 # naive is biased high
})

test_that("units that fail to produce both outcomes are dropped", {
  units <- data.frame(x = c(1, 2, 3, 4))
  # A forward model that returns NA for the treated run of the first unit.
  flaky <- function(theta) {
    y <- osse_fm(theta)
    y[5L] <- NA_real_   # treated block, first unit (rows 5..8 are treated)
    y
  }
  gr <- apsimR:::.apsim_osse(flaky, "T", control = 0, treated = 10,
                            units = units, target = NULL, assignment = "random",
                            prob = 0.5, confounder = NULL, confound_strength = 1,
                            seed = 1L)
  expect_equal(nrow(gr@observed), 3L)
})

test_that("input validation catches bad units and missing confounder", {
  expect_error(
    apsim_ground_truth(apsimx_fixture(), "T", 0, 10,
                       units = data.frame(), output = "Y"),
    "at least one column")
  expect_error(
    apsim_ground_truth(apsimx_fixture(), "T", 0, 10,
                       units = data.frame(x = 1:3), output = "Y",
                       assignment = "confounded"),
    "confounder")
})

# Live OSSE: skipped without APSIM and outside the opt-in. Two runs per unit.
test_that("an APSIM OSSE produces a dataset with a finite ATE", {
  skip_if_no_live_apsim()
  f <- apsim_example("Wheat")
  skip_if(is.na(f), "no Wheat example")
  units <- data.frame(
    `[Sow using a variable rule].Script.Population` = c(80, 120, 160, 200),
    check.names = FALSE)
  gr <- apsim_ground_truth(
    f, treatment = "[Fertilise at sowing].Script.Amount",
    control = 0, treated = 150, units = units, output = "Yield", seed = 1L)
  skip_if(is_apsim_abstention(gr), "OSSE unavailable")
  expect_true(is.finite(gr@truth$ate))
  expect_identical(names(gr@observed)[2:3], c("W", "Y"))
})
