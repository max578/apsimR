test_that("availability and version have the right types", {
  expect_type(apsim_available(), "logical")
  v <- apsim_version()
  expect_true(is.character(v) && length(v) == 1L)
})

test_that("apsim_configure() reverts to discovery", {
  res <- apsim_configure()
  expect_true(is.list(res))
  expect_true(all(c("models", "server", "dotnet_root") %in% names(res)))
})

test_that("verbs abstain cleanly when the simulator is absent", {
  on.exit(apsim_configure(), add = TRUE)
  apsim_configure(models = file.path(tempdir(), "no-such-Models"))
  expect_false(apsim_available())

  ab <- apsim_predict(apsimx_fixture())
  expect_true(is_apsim_abstention(ab))
  expect_identical(ab$reason, "runtime_unavailable")

  ab2 <- apsim_estimate(apsimx_fixture(), x = "N", y = "Yield")
  expect_true(is_apsim_abstention(ab2))
})

test_that("apsim_example returns a path or NA", {
  ex <- apsim_example("Wheat")
  expect_true(is.character(ex) && length(ex) == 1L)
})
