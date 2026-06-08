test_that("apsim_sim reads a tree and round-trips it", {
  f <- apsimx_fixture()
  sim <- apsim_sim(f)

  expect_true(S7::S7_inherits(sim, apsim_sim))
  expect_identical(apsim_simulations(sim), "Sim1")

  out <- apsim_write(sim, tempfile(fileext = ".apsimx"))
  expect_true(file.exists(out))
  # The written file re-reads to the same simulation set.
  expect_identical(apsim_simulations(apsim_sim(out)), "Sim1")
})

test_that("apsim_sim rejects a missing file", {
  expect_error(apsim_sim(tempfile(fileext = ".apsimx")), "existing")
})

test_that("apsim_edit abstains without the simulator", {
  on.exit(apsim_configure(), add = TRUE)
  apsim_configure(models = file.path(tempdir(), "no-such-Models"))
  res <- apsim_edit(apsim_sim(apsimx_fixture()), c("[Clock].End" = "1991-12-31"))
  expect_true(is_apsim_abstention(res))
})

test_that("on a real install, apsim_sim reads an example", {
  skip_if_not(apsim_available(), "APSIM not installed")
  ex <- apsim_example("Wheat")
  skip_if(is.na(ex), "no Wheat example in this install")
  sim <- apsim_sim(ex)
  expect_gt(length(apsim_simulations(sim)), 0L)
})

test_that("on a real install, apsim_edit persists an edit", {
  skip_if_not(apsim_available(), "APSIM not installed")
  ex <- apsim_example("Wheat")
  skip_if(is.na(ex), "no Wheat example in this install")
  out <- apsim_edit(apsim_sim(ex), c("[Clock].End" = "1990-06-30"))
  if (is_apsim_abstention(out)) {
    skip(paste("edit abstained:", out$reason))
  }
  expect_true(S7::S7_inherits(out, apsim_sim))
  # The edit is present in the written file, and the source is untouched.
  expect_true(any(grepl("1990-06-30", unlist(out@json))))
  expect_false(any(grepl("1990-06-30", unlist(apsim_sim(ex)@json))))
})
