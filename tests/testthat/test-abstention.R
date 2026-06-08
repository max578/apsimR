test_that("apsim_abstention carries a machine-readable reason", {
  a <- apsim_abstention("runtime_unavailable", "no Models", scope = "apsim_predict")
  expect_true(is_apsim_abstention(a))
  expect_identical(a$reason, "runtime_unavailable")
  expect_identical(a$scope, "apsim_predict")
  expect_true(a$abstained)
})

test_that("is_apsim_abstention is FALSE for other objects", {
  expect_false(is_apsim_abstention(42))
  expect_false(is_apsim_abstention(list(reason = "x")))
})

test_that("a missing reason is rejected", {
  expect_error(apsim_abstention(character(0)))
})

test_that("print returns invisibly", {
  expect_invisible(print(apsim_abstention("run_failed")))
})
