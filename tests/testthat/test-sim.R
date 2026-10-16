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
  wd_before <- normalizePath(getwd())
  out <- apsim_edit(apsim_sim(ex), c("[Clock].End" = "1990-06-30"))
  # The edit round-trip must succeed on a real install: the relative-save
  # invocation sidesteps APSIM 2026.5's absolute-save temp-path quirk under a
  # sandboxed R session (see apsim_edit() and external_facts.R). An abstention
  # here is a failure, not a tolerated skip.
  expect_false(is_apsim_abstention(out))
  expect_true(S7::S7_inherits(out, apsim_sim))
  # The edit is present in the written file, and the source is untouched.
  expect_true(any(grepl("1990-06-30", unlist(out@json))))
  expect_false(any(grepl("1990-06-30", unlist(apsim_sim(ex)@json))))
  # The working directory is restored after the edit (the fix sets it to the
  # scratch directory for the relative-save invocation, then restores it).
  expect_identical(normalizePath(getwd()), wd_before)
})

test_that("apsim_edit sends the edits and a save command, and reads the result", {
  on.exit(apsim_configure(), add = TRUE)
  seen <- new.env()
  local_fake_simulator(apply = function(cfg, work) {
    seen$cfg <- readLines(cfg)
    seen$wd <- getwd()
    file.copy(work, file.path(dirname(work), "apsimR_edited.apsimx"))
    "Saved"
  })
  src <- apsimx_fixture()
  out_path <- tempfile(fileext = ".apsimx")
  wd_before <- getwd()
  out <- apsim_edit(apsim_sim(src), c("[Clock].End" = "1991-12-31"),
                    path = out_path)
  expect_true(S7::S7_inherits(out, apsim_sim))
  expect_identical(out@file, normalizePath(out_path))
  expect_identical(seen$cfg, c("[Clock].End = 1991-12-31",
                               "save apsimR_edited.apsimx"))
  # APSIM runs in the scratch directory; the caller's directory comes back
  expect_false(identical(seen$wd, wd_before))
  expect_identical(getwd(), wd_before)
})

test_that("a rejected edit abstains with the simulator's message", {
  on.exit(apsim_configure(), add = TRUE)
  local_fake_simulator(apply = function(cfg, work) {
    failed_run("Error: cannot find [Clock].Ends")
  })
  out <- apsim_edit(apsim_sim(apsimx_fixture()), c("[Clock].Ends" = "1991"))
  expect_true(is_apsim_abstention(out))
  expect_identical(out$reason, "run_failed")
  expect_match(out$detail, "cannot find")
})

test_that("edits must be named, and the verbs need an apsim_sim", {
  sim <- apsim_sim(apsimx_fixture())
  expect_error(apsim_edit(sim, "1991-12-31"), "named character vector")
  expect_error(apsim_edit(apsimx_fixture(), c(a = "1")), "apsim_sim")
  expect_error(apsim_simulations(apsimx_fixture()), "apsim_sim")
  expect_error(apsim_write(apsimx_fixture()), "apsim_sim")
})

test_that("print lists at most four simulation names", {
  sims <- paste0(
    '{"$type":"Models.Core.Simulation, Models","Name":"S', 1:5,
    '","Children":[]}', collapse = ",")
  f <- tempfile(fileext = ".apsimx")
  writeLines(paste0('{"$type":"Models.Core.Simulations, Models",',
                    '"Name":"Simulations","Children":[', sims, ']}'), f)
  sim <- apsim_sim(f)
  expect_identical(apsim_simulations(sim), paste0("S", 1:5))
  expect_output(print(sim), "simulations: 5 \\(S1, S2, S3, S4, \\.\\.\\.\\)")
})
