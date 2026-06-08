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
