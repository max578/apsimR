# Contract tests for the native `orchestra_manifest` emission (audit F1).
#
# The oracle throughout is **optimix** -- a sibling orchestra member that
# implements the same reference contract
# (ORCHESTRA_dev/integration/orchestra_manifest.R) and was authored
# independently of apsimR. `optimix::verify_manifest()` recomputes the payload
# hash with optimix's own implementation of the contract recipe and dispatches
# on optimix's own class object, so it grounds two things apsimR cannot ground
# for itself: that the emitted object carries the shared, bare class identity
# (a namespaced `apsimR::orchestra_manifest` would be invisible to every
# consumer), and that the integrity hash is byte-identical to the federation's.

test_that("class identity is the shared bare contract class, not a look-alike", {
  skip_if_not_installed("optimix")
  m <- as_orchestra_manifest(apsim_manifest_by_target()$parameters)
  # A member-namespaced S7 class would fail this: S7 dispatch compares the
  # `package::name` string, so only a bare "orchestra_manifest" matches.
  expect_true(S7::S7_inherits(m, optimix::orchestra_manifest))
  expect_identical(class(m)[[1L]], "orchestra_manifest")
})

test_that("the payload hash verifies under a sibling's implementation", {
  skip_if_not_installed("optimix")
  for (nm in names(apsim_manifest_by_target())) {
    m <- as_orchestra_manifest(apsim_manifest_by_target()[[nm]])
    expect_true(isTRUE(optimix::verify_manifest(m)$ok),
                info = paste("target:", nm))
  }
})

test_that("a tampered payload is caught by the sibling verifier", {
  skip_if_not_installed("optimix")
  m <- as_orchestra_manifest(apsim_manifest_by_target()$validation)
  m@outputs$predicted[1L] <- m@outputs$predicted[1L] + 0.5
  expect_false(isTRUE(optimix::verify_manifest(m)$ok))
})

test_that("every apsimR target maps onto the contract's target enum", {
  contract_enum <- c("parameters", "predictions", "treatment_effects",
                     "decisions", "breeding_values", "marker_associations",
                     "structure")
  mapped <- vapply(apsim_manifest_by_target(),
                   function(x) as_orchestra_manifest(x)@inferential_target,
                   character(1L))
  expect_true(all(mapped %in% contract_enum))
  expect_identical(
    unname(mapped[c("predictions", "parameters", "sensitivity", "emulator",
                    "validation")]),
    c("predictions", "parameters", "parameters", "predictions", "predictions"))
})

test_that("the emitter self-identifies and keeps the apsimR target", {
  m <- as_orchestra_manifest(apsim_manifest_by_target()$sensitivity)
  expect_identical(m@emitter_package, "apsimR")
  expect_identical(m@emitter_version,
                   as.character(utils::packageVersion("apsimR")))
  expect_identical(m@manifest_version, "2.0.0-draft")
  expect_identical(m@metadata$apsim_target, "sensitivity")
  expect_match(m@run_id, "^apsimR-")
})

test_that("a validation manifest carries its verdict in the typed summary", {
  m <- as_orchestra_manifest(apsim_manifest_by_target()$validation)
  expect_s3_class(m@summary, "manifest_summary")
  expect_identical(m@summary$headline, "good")
  expect_equal(m@summary$metrics$nse, 0.82)
})

test_that("an ensemble manifest carries weights and obs_target across", {
  m <- as_orchestra_manifest(apsim_ensemble_manifest_fixture())
  expect_equal(unname(m@obs_target), c(2200, 6500))
  expect_equal(unname(m@weights), c(1 / 220, 1 / 650))
})

test_that("as_orchestra_manifest rejects a non-manifest", {
  expect_error(as_orchestra_manifest(42), "apsim_manifest")
})
