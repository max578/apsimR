# Real-simulator integration test: skipped wherever APSIM is absent (CRAN), run
# on a developer machine with the simulator installed.

test_that("apsim_predict runs the simulator and emits a predictions manifest", {
  skip_if_not(apsim_available(), "APSIM not installed")
  ex <- apsim_example("Wheat")
  skip_if(is.na(ex), "no Wheat example in this install")

  m <- apsim_predict(ex)
  if (is_apsim_abstention(m)) {
    skip(paste("APSIM run abstained:", m$reason))
  }

  expect_true(S7::S7_inherits(m, apsim_manifest))
  expect_identical(m@inferential_target, "predictions")
  expect_false(is.null(m@outputs))
  expect_gt(nrow(m@outputs), 0L)
  expect_identical(m@apsim_version, apsim_version())
})
