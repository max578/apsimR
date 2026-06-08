# apsim_design() is pure (no simulator), so it is fully testable offline.

test_that("a Latin-hypercube design has the right shape and bounds", {
  d <- apsim_design(c("a", "b"), lower = c(0, 10), upper = c(1, 20),
                    n = 25L, method = "lhs", seed = 1L)
  expect_equal(dim(d), c(25L, 2L))
  expect_identical(colnames(d), c("a", "b"))
  expect_true(all(d[, "a"] >= 0 & d[, "a"] <= 1))
  expect_true(all(d[, "b"] >= 10 & d[, "b"] <= 20))
})

test_that("a seed makes the design reproducible", {
  d1 <- apsim_design("a", 0, 1, n = 10L, seed = 42L)
  d2 <- apsim_design("a", 0, 1, n = 10L, seed = 42L)
  expect_identical(d1, d2)
})

test_that("a grid design is the full factorial", {
  d <- apsim_design(c("a", "b"), 0, 1, n = 4L, method = "grid")
  expect_equal(nrow(d), 16L)
})

test_that("invalid bounds and n are rejected", {
  expect_error(apsim_design("a", 1, 0), "upper")
  expect_error(apsim_design("a", 0, 1, n = 0L), "positive")
  expect_error(apsim_design(character(0), 0, 1), "non-empty")
})
