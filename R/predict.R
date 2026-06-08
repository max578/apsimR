# predict.R -- run APSIM forward and return the simulated reports.

#' Run APSIM forward over a simulation file
#'
#' Runs the simulator on a copy of `sim` (the source file and its DataStore are
#' never touched), reads the requested report from the resulting DataStore, and
#' returns it as a `predictions` [apsim_manifest()]. A single `Models` invocation
#' builds the file once and runs every simulation it contains (including any
#' factorial fan-out) across cores. Returns an [apsim_abstention()] when the
#' simulator is unavailable or the run fails.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param report Character report-table name, or `NULL` for the first report.
#' @param simulations Optional regular expression selecting simulations to run
#'   (`--simulation-names`).
#' @param cpu Optional integer thread cap; `NULL` uses all cores.
#'
#' @returns An `apsim_manifest` with `inferential_target = "predictions"` carrying
#'   the simulated report in `outputs`, or an `apsim_abstention`.
#'
#' @examplesIf apsimR::apsim_available()
#' # Running APSIM over a real simulation file takes several seconds, so the
#' # call is wrapped in \donttest{}; it runs under R CMD check --run-donttest.
#' f <- apsim_example("Wheat")
#' \donttest{
#' if (!is.na(f)) {
#'   m <- apsim_predict(f)
#'   m@inferential_target
#' }
#' }
#'
#' @export
apsim_predict <- function(sim, report = NULL, simulations = NULL, cpu = NULL) {
  s <- .as_apsim_sim(sim)
  run <- .apsim_run(s@file, sim_names = simulations, cpu = cpu)
  if (is_apsim_abstention(run)) {
    return(run)
  }
  on.exit(unlink(run$dir, recursive = TRUE, force = TRUE), add = TRUE)
  out <- apsim_read(run$db, report = report)
  apsim_manifest(
    "predictions", "apsim:predict", outputs = out,
    metadata = list(file = basename(s@file), report = report,
                    n_simulations = length(apsim_simulations(s))))
}
