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

# --- the C2 bridge, positive path (audit F1 / F6) ----------------------------
#
# Until this block existed the only bridge test skipped whenever PESTO was
# present, so the success path had no coverage at all and the bridge could
# abstain on every payload apsimR emits without a single test noticing. The
# oracle here is PESTO itself (0.10.1): its S7 validator decides whether the
# object is a legal `pesto_ensemble_manifest`, and `PESTO::verify_manifest()`
# recomputes the integrity hash with PESTO's own recipe -- neither is authored
# by apsimR, so a bridge that merely satisfies apsimR's own conventions fails
# them.

test_that("an ensemble manifest bridges to a real PESTO manifest", {
  skip_if_not_installed("PESTO")
  m <- apsim_ensemble_manifest_fixture()
  p <- as_pesto_manifest(m)
  expect_false(is_apsim_abstention(p))
  expect_true(S7::S7_inherits(p, PESTO::pesto_ensemble_manifest))
})

test_that("the bridged manifest verifies under PESTO's own hash recipe", {
  skip_if_not_installed("PESTO")
  p <- as_pesto_manifest(apsim_ensemble_manifest_fixture())
  expect_false(is_apsim_abstention(p))
  expect_true(isTRUE(PESTO::verify_manifest(p)$ok))
})

test_that("the bridge carries the ensemble across row for row", {
  skip_if_not_installed("PESTO")
  m <- apsim_ensemble_manifest_fixture()
  p <- as_pesto_manifest(m)
  expect_false(is_apsim_abstention(p))
  expect_identical(nrow(p@params), nrow(p@outputs))
  expect_identical(nrow(p@params), nrow(m@params))
  expect_equal(unname(p@obs_target), c(2200, 6500))
  expect_identical(p@apsim_version, m@apsim_version)
  expect_identical(p@seed, m@seed)
})

test_that("the bridge maps the method onto PESTO's accepted enum", {
  skip_if_not_installed("PESTO")
  p <- as_pesto_manifest(apsim_ensemble_manifest_fixture())
  expect_false(is_apsim_abstention(p))
  # PESTO 0.10.1's validator accepts exactly these five tokens; an apsimR
  # method tag ("apsim:calibrate:ies") is not one of them, so the bridge must
  # translate rather than pass its own vocabulary through.
  expect_true(p@method %in% c("ies_callback", "ies_filter", "ies_pst", "mda",
                              "surrogate"))
  expect_identical(p@method, "ies_callback")
})

test_that("a result that is not an inversion abstains, naming the enum", {
  skip_if_not_installed("PESTO")
  res <- as_pesto_manifest(apsim_manifest_by_target()$predictions)
  expect_true(is_apsim_abstention(res))
  expect_identical(res$reason, "feature_unsupported")
  expect_match(res$detail, "not an ensemble inversion")
  expect_match(res$detail, "as_orchestra_manifest")
})

test_that("an inversion with no ensemble abstains, naming the requirement", {
  skip_if_not_installed("PESTO")
  bare <- apsim_manifest("parameters", "apsim:calibrate:ies",
                         params = data.frame(amount = c(80, 120, 160)))
  res <- as_pesto_manifest(bare)
  expect_true(is_apsim_abstention(res))
  expect_identical(res$reason, "feature_unsupported")
  expect_match(res$detail, "row-aligned")
})

test_that("the ies backend's own manifest bridges end to end", {
  skip_if_not_installed("PESTO")
  # A cheap linear forward model stands in for APSIM so the ensemble smoother
  # runs in the ordinary suite: theta -> (Yield, Biomass). No simulator needed.
  fm <- function(theta) {
    theta <- as.matrix(theta)
    cbind(Yield = 1000 + 12 * theta[, 1L],
          Biomass = 3000 + 20 * theta[, 1L] + 5 * theta[, 2L])
  }
  m <- .apsim_calibrate_ies(
    fm, parm_paths = c("amount", "population"), lower = c(0, 50),
    upper = c(250, 200), observed = c(Yield = 2200, Biomass = 6500),
    obs_sd = c(Yield = 220, Biomass = 650), n_real = 20L, noptmax = 2L,
    inflation = 0.8, seed = 7L)
  skip_if(is_apsim_abstention(m), "the ies backend abstained")
  p <- as_pesto_manifest(m)
  expect_false(is_apsim_abstention(p))
  expect_true(isTRUE(PESTO::verify_manifest(p)$ok))
  expect_identical(nrow(p@params), 20L)
})
