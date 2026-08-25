# apsimR (development version)

* Added a GitHub Actions R-CMD-check workflow (macOS/Windows/Ubuntu across
  release/devel/oldrel-1) so releases are verified on an independent runner
  rather than only on this machine; the private `PESTO` test oracle is
  dropped from `Suggests` before dependency resolution on the runner, and
  its guarded tests skip there as designed.
* Added a `README.md` with a purpose statement, install instructions and a
  minimal runnable example.
* Documented `apsim_fact_status()`'s previously-undocumented `@examples`.
* Vignette: the emulation section now exercises the real exact-GP training
  and prediction pair on a genuine leave-one-out pass, with a plotted
  diagnostic, instead of demonstrating `stats::smooth.spline` under a
  Gaussian-process label; the estimation section calls the same internal
  fitter `apsim_estimate()` uses instead of a hand-rolled `nls()` call; both
  sections now state the governing equation (the Mitscherlich dose-response,
  the ARD squared-exponential kernel) rather than leaving the mathematics
  implicit in R code; the validation section now renders the
  observed-versus-predicted plot instead of only describing it; `mu.star` is
  corrected to the emitted `mu_star`; and the closing "Composing with the
  orchestra" section no longer states that the `PESTO` manifest bridge
  already composes -- it currently abstains on every apsimR manifest and the
  vignette now says so.
* `DESCRIPTION` and the package-level documentation no longer claim the
  `PESTO` ensemble-manifest bridge already composes; they describe it as
  underway, matching `as_pesto_manifest()`'s current abstain-on-every-input
  behaviour.
* `apsim_validate()`'s documentation now states the Moriasi et al. (2007)
  performance bands were derived for watershed/streamflow simulation, flags
  the citation `[unverified]` pending a source check, and directs readers to
  the joint NSE/RSR/PBIAS reading the source recommends rather than grading
  on NSE alone.
* Corrected `apsim_sensitivity()`'s documentation to name the emitted column
  `mu_star`, not `mu.star`.

# apsimR 0.3.0

The `"exact"` emulator backend is now a genuine exact Gaussian process. It
previously fixed a single isotropic length-scale by the median-distance heuristic
with unit signal variance and never fitted its hyperparameters -- exact-inference,
but never *fitted*, so on an anisotropic target it neither interpolated the design
nor competed with a reference exact GP (an independent benchmark on the Branin
function found it ~334x less accurate out-of-sample and not interpolating). The
`"exact"` label is now true to its name.

## Behaviour change

* `apsim_emulate(backend = "exact")` (and the internal `.apsim_gp_train()`) now fit
  per-dimension **ARD length-scales**, the **signal variance** and the **noise
  variance** by maximising the exact log marginal likelihood (the median heuristic
  only seeds the optimiser, with restarts against a local optimum). Predictions
  from the default backend therefore change -- and improve: on the Branin benchmark
  the surrogate's held-out RMSE now matches a marginal-likelihood-fitted
  `DiceKriging` exact GP (ratio ~0.85x, i.e. on par) and it interpolates the
  training design to ~1e-3 of the output range. The public API is unchanged.

## Bug fixes

* The squared-exponential predictive variance now uses the fitted signal variance
  (it was implicitly fixed at one in standardised space), so the reported
  uncertainty scales correctly with the data.

# apsimR 0.2.0

A stabilisation pass on the 0.1.0 core: the simulator-backed edit round-trip is
fixed, the reference documentation is organised for a published site, and the
expensive live oracles are run end-to-end against the installed APSIM.

## Bug fixes

* `apsim_edit()` now completes the edit round-trip on a real install instead of
  abstaining. APSIM 2026.5's `--apply` `SaveCommand` resolves an *absolute* save
  target through the process temporary path (`Path.GetTempPath()`); under a
  sandboxed R session that path is the per-process confined temporary root, which
  R cannot write to, so the save failed with an `UnauthorizedAccessException`
  (the identical command from a bare shell succeeds -- the failure is specific to
  the R process's temporary-directory confinement, not a config-format change).
  The edit is now run with a *relative* save filename resolved against a writable
  scratch directory, then moved to the requested `path`; the source file is still
  never touched. Grounded against APSIM Next Generation 2026.5.8046.0. The live
  edit test asserts success (no tolerated abstention) and that the working
  directory is restored.

## Documentation

* Adds a `pkgdown` configuration (`_pkgdown.yml`, Bootstrap 5) with the reference
  index grouped by verb family -- simulation files, run/predict, calibrate/
  estimate, sensitivity/emulate, validate, causal ground truth (OSSE), the
  contract manifest, runtime/abstention, and external-fact grounding.
  `pkgdown::check_pkgdown()` reports no problems and `pkgdown::build_site()` runs
  clean.

## Verification

* The expensive live oracles (forward-model evaluation, Morris sensitivity,
  Gaussian-process emulation with leave-one-out diagnostics, the OSSE
  ground-truth dataset, and the yield-versus-nitrogen monotonicity sign check)
  were run end-to-end against the installed APSIM Next Generation 2026.5.8046.0
  via `APSIMR_LIVE_TESTS=true` and pass. These tests remain skip-gated so the
  suite stays green without the simulator present.

# apsimR 0.1.0

First formal release. `apsimR` enrols APSIM Next Generation into the orchestra as a
typed, contract-emitting analysis member: every entry point returns a versioned,
provenance-complete `apsim_manifest` compatible with the `PESTO` ensemble-manifest
contract, and abstains with a typed reason when the simulator or its runtime is
absent. The release consolidates the Phase-1 through Phase-4 walking skeleton, the
inference verbs, the OSSE causal test-bench, and the Independent-Oracle grounding of
the APSIM facts the package asserts.

## New features

* **Independent Oracle Principle (Phase-1 grounding).** `apsim_external_facts()`
  / `apsim_fact_status()`: a registry of the class-8 APSIM facts apsimR asserts
  (DataStore SQLite schema, the `"Current"` checkpoint, report columns, manager
  node paths) with the oracle that grounds each. The DataStore schema and report
  columns are grounded by a **replayed real run** (`test-datastore-grounding.R`)
  that asserts the *fact* by name, not just non-emptiness -- closing the
  "skip != pass" hole, and grounding the schema against a live run rather than
  the shipped empty `Wheat.db` stub. The audit's inference that
  `Wheat.AboveGround.Wt` is absent from the stock report was corrected by the
  live oracle: the report emits both `Yield` and `Wheat.AboveGround.Wt`. Adds a
  yield-vs-nitrogen monotonicity sign check (opt-in via `APSIMR_LIVE_TESTS`).

* Validation and causal ground truth (Phase 4). `apsim_validate()` scores simulated
  output against observations with the standard goodness-of-fit metrics (RMSE, MAE,
  mean error, Nash-Sutcliffe efficiency, Willmott's d, RSR, percent bias) and a
  typed verdict against the Moriasi et al. (2007) performance bands; it accepts an
  `apsim_predict()` manifest, data frames joined on a key, or vectors, and emits a
  `"validation"` manifest. `apsim_validation_plot()` draws observed-versus-predicted
  when `ggplot2` is present. `apsim_ground_truth()` turns the simulator into a
  known-causal-structure data factory: it runs each unit under control and
  treatment so both potential outcomes are known, assigns treatment at random or
  with covariate confounding, and returns an observing-system simulation experiment
  (OSSE) -- the observed `(covariates, W, Y)` a causal method consumes, plus the
  recorded individual and average treatment effects it is graded against.

* Inference verbs (Phase 3), all over one shared forward model. `apsim_calibrate()`
  solves the inverse problem -- a bounded `stats::optim` point estimate by default,
  or a posterior parameter ensemble through `PESTO`'s iterative ensemble smoother
  (with RTPS inflation) when that package is present; several targets calibrate
  jointly. `apsim_sensitivity()` runs global sensitivity analysis -- Morris
  elementary-effect screening and Sobol-Jansen variance decomposition (the
  `sensitivity` package). `apsim_emulate()` fits a Gaussian-process surrogate of an
  expensive output, returned with mandatory leave-one-out diagnostics (RMSE, R^2,
  95% coverage) and a `predict()` method; the default exact-GP backend needs no
  extra package, and `PESTO`'s GP / random-feature surrogates compose when present.

* `apsim_forward_model()` exposes the shared core: a closure mapping an
  `nreal x npar` parameter matrix to an `nreal x nobs` observation matrix (the
  `PESTO` forward-model contract), one APSIM `--apply` edit-and-run invocation per
  realisation, failed runs recorded as `NA` rows. `apsim_design()` builds the
  parameter points a sweep evaluates (Latin hypercube, grid or random).

* The `apsim_manifest` contract enum gains `"sensitivity"` and `"emulator"`
  inferential targets alongside `"predictions"` and `"parameters"`.


* First walking skeleton (Phase 1). `apsim_predict()` runs APSIM Next Generation
  over a simulation file and returns the simulated reports as a contract-emitting
  ensemble object; `apsim_estimate()` runs the simulator across an input grid and
  fits a mechanism (a saturating dose-response by default), returning the fitted
  parameters. Both emit an `apsim_manifest` compatible with the `PESTO`
  ensemble-manifest contract via `as_pesto_manifest()`.

* Execution layer. `apsim_available()`, `apsim_version()` and `apsim_configure()`
  discover and pin the installed `Models` executable and its .NET runtime; the
  command-line factorial path runs a simulation file once and reads its outputs
  from the SQLite DataStore via `apsim_read()`. Entry points that need the
  simulator return a typed `apsim_abstention` when it is absent, so the package
  is standalone-functional.

* `apsim_sim()` reads an `.apsimx` (JSON) file into a typed, round-trippable
  object; `apsim_write()` writes it back; `apsim_edit()` applies
  `[Node].Property = value` edits through APSIM's own `--apply` config mechanism.

* Experimental server client (Phase 2). `apsim_server()` starts APSIM's
  persistent `apsim-server` and speaks its native socket protocol from R;
  `apsim_run()` (optionally with parameter overrides) and `apsim_output()` re-run
  a file held in memory without re-paying the per-run load. This is the
  throughput path for adaptive inner loops. It is marked experimental: APSIM's
  bundled V1 server has known issues on current builds (it can fail to run stock
  files, and its re-runs degrade), so `apsim_run()` / `apsim_output()` abstain
  cleanly when the server cannot run; the command-line path remains the reliable
  default engine.
