# Gate for expensive live integration tests: each drives the real simulator over
# many sequential runs (a calibration loop, a Morris design, an emulator design),
# which would bloat every `R CMD check`. They run only when explicitly opted in
# with `APSIMR_LIVE_TESTS=true` (and APSIM is present). The cheaper live tests
# (a single forward run, predict) stay gated only on `apsim_available()`.
skip_if_no_live_apsim <- function() {
  testthat::skip_if_not(apsim_available(), "APSIM not installed")
  if (!identical(Sys.getenv("APSIMR_LIVE_TESTS"), "true")) {
    testthat::skip("expensive live APSIM test; set APSIMR_LIVE_TESTS=true to run")
  }
}

# A minimal, valid .apsimx tree (one named simulation) for offline tests that
# exercise the reader / round-trip / abstention paths without the simulator.
apsimx_fixture <- function() {
  f <- tempfile(fileext = ".apsimx")
  writeLines(paste0(
    '{"$type":"Models.Core.Simulations, Models","Name":"Simulations",',
    '"Children":[{"$type":"Models.Core.Simulation, Models","Name":"Sim1",',
    '"Children":[]}]}'), f)
  f
}

# --- manifest fixtures -------------------------------------------------------

# A `parameters` manifest in the shape an ensemble smoother produces: a
# posterior parameter ensemble in `params`, the row-aligned simulated
# observation ensemble in `metadata$obs_ensemble`, and the assimilation context
# (observation targets and their `1 / obs_sd` weights) alongside it. This is the
# only apsimR payload the PESTO ensemble contract can express, so it is the
# fixture the C2 bridge is tested on.
apsim_ensemble_manifest_fixture <- function(n_real = 12L, seed = 42L) {
  set.seed(seed)
  params <- data.frame(
    `[Fertilise at sowing].Script.Amount` = stats::runif(n_real, 40, 200),
    `[Sow].Script.Population` = stats::runif(n_real, 80, 160),
    check.names = FALSE)
  obs_ensemble <- data.frame(
    Yield = 1000 + 12 * params[[1L]] + stats::rnorm(n_real, 0, 50),
    Biomass = 3000 + 20 * params[[1L]] + stats::rnorm(n_real, 0, 90))
  observed <- c(Yield = 2200, Biomass = 6500)
  obs_sd <- c(Yield = 220, Biomass = 650)
  apsim_manifest(
    "parameters", "apsim:calibrate:ies", params = params,
    outputs = data.frame(target = names(observed), observed = observed,
                         predicted = colMeans(obs_ensemble),
                         row.names = NULL),
    metadata = list(backend = "ies", n_real = n_real, noptmax = 4L,
                    obs_ensemble = obs_ensemble, obs_target = observed,
                    obs_weights = 1 / obs_sd, failure_rate = 0,
                    lambda_schedule = c(20, 10, 5, 2.5)),
    seed = seed)
}

# One manifest of each `inferential_target` apsimR can emit, so a contract test
# can assert the whole enum maps onto the orchestra contract rather than only
# the target that happens to be convenient.
apsim_manifest_by_target <- function() {
  gof <- data.frame(n = 4L, rmse = 0.31, nse = 0.82, pbias = -2.1, rsr = 0.42)
  list(
    predictions = apsim_manifest(
      "predictions", "apsim:predict",
      outputs = data.frame(SimulationName = c("S1", "S2"),
                           Yield = c(3.8, 4.1))),
    parameters = apsim_manifest(
      "parameters", "apsim:estimate:mitscherlich",
      params = data.frame(ymax = 4.2, rate = 0.018, y0 = 1.1)),
    sensitivity = apsim_manifest(
      "sensitivity", "apsim:sensitivity:morris",
      params = data.frame(parameter = c("a", "b"), mu_star = c(1.2, 0.4),
                          sigma = c(0.5, 0.2)),
      metadata = list(method = "morris", n_runs = 60L, n_failures = 0L)),
    emulator = apsim_manifest(
      "emulator", "apsim:emulate:exact",
      params = data.frame(lengthscale = c(1.4, 2.9), sigma_f = 0.8),
      metadata = list(loo_rmse = 0.11, coverage95 = 0.93)),
    validation = apsim_manifest(
      "validation", "apsim:validate", params = gof,
      outputs = data.frame(observed = c(2, 3.6, 3.8, 5),
                           predicted = c(2.1, 3.4, 4, 5.2)),
      metadata = list(verdict = "good", governing_metric = "nse",
                      reference = "Moriasi et al. (2007)")))
}
