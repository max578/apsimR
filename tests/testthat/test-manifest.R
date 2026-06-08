test_that("apsim_manifest constructs a contract-shaped object", {
  m <- apsim_manifest(
    "parameters", "apsim:estimate:mitscherlich",
    params = data.frame(ymax = 4.2, rate = 0.018, y0 = 1.1))
  expect_true(S7::S7_inherits(m, apsim_manifest))
  expect_identical(m@inferential_target, "parameters")
  expect_identical(names(m@params), c("ymax", "rate", "y0"))
  expect_match(m@data_hash, "^sha256:")
  expect_identical(m@emitter_version, as.character(utils::packageVersion("apsimR")))
})

test_that("an unknown inferential target is rejected", {
  expect_error(apsim_manifest("nonsense", "m"), "inferential_target")
})

test_that("a predictions manifest carries outputs", {
  out <- data.frame(SimulationName = "S1", Yield = 3.8)
  m <- apsim_manifest("predictions", "apsim:predict", outputs = out)
  expect_identical(m@inferential_target, "predictions")
  expect_equal(nrow(m@outputs), 1L)
})

test_that("print returns invisibly", {
  m <- apsim_manifest("predictions", "apsim:predict",
                      outputs = data.frame(y = 1))
  expect_invisible(print(m))
})

test_that("as_pesto_manifest abstains cleanly without PESTO", {
  skip_if(requireNamespace("PESTO", quietly = TRUE),
          "PESTO is installed; the no-PESTO path is not exercised here")
  m <- apsim_manifest("parameters", "apsim:estimate",
                      params = data.frame(a = 1))
  res <- as_pesto_manifest(m)
  expect_true(is_apsim_abstention(res))
})
