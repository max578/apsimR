# sensitivity.R -- global sensitivity analysis of an APSIM output.
#
# Which inputs matter, and how much? Sensitivity analysis answers that by varying
# the parameters across their ranges and decomposing the variation they induce in
# a chosen output. apsimR runs the two standard global methods over the shared
# forward model, using the `sensitivity` package's design/`tell` split so the
# expensive APSIM runs are decoupled from index estimation: Morris elementary
# effects for cheap screening (`r * (p + 1)` runs -- rank the factors, find the
# negligible ones), and Sobol-Jansen variance decomposition for a quantitative
# first-order / total-effect split (`n * (p + 2)` runs -- the precise but costly
# follow-up). Failed simulator runs are mean-imputed and counted, never silently
# dropped.

# --- public entry point ------------------------------------------------------

#' Global sensitivity analysis of an APSIM output
#'
#' Quantifies how the `parm_paths` parameters drive a single scalar APSIM output
#' over the box `[lower, upper]`. Morris screening (default) ranks the factors by
#' mean absolute elementary effect (`mu_star`) and flags interaction / non-linearity
#' (`sigma`) cheaply; the Sobol-Jansen method decomposes the output variance into
#' first-order (`S`) and total (`T`) indices at a higher run cost. The two stages
#' use the `sensitivity` package over the same forward model as the other verbs.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param parm_paths Character vector of APSIM node paths (the factors).
#' @param lower,upper Numeric box bounds aligned to `parm_paths` (recycled from
#'   length one).
#' @param output A `function(report) -> named numeric` or report column name(s)
#'   identifying the output (see [apsim_forward_model()]).
#' @param target Character naming the single output column to analyse when
#'   `output` yields several; defaults to the first.
#' @param method Character: `"morris"` (default), `"sobol"`, or `"both"`.
#' @param morris_r Integer number of Morris elementary-effect repetitions.
#' @param morris_levels Integer Morris grid levels.
#' @param sobol_n Integer base sample size for Sobol (total runs `n * (p + 2)`).
#' @param nboot Integer bootstrap replicates for Sobol confidence intervals.
#' @param report Character report-table name, or `NULL` for the first report.
#' @param seed Optional integer RNG seed.
#'
#' @returns An `apsim_manifest` with `inferential_target = "sensitivity"` whose
#'   `params` holds one row per factor with the requested indices, or an
#'   [apsim_abstention()] when the simulator is unavailable.
#'
#' @examplesIf apsimR::apsim_available()
#' # Sensitivity analysis runs the simulator r(p + 1) times, so the example is
#' # wrapped in \dontrun{}; see the package vignette for a runnable walk-through.
#' \dontrun{
#' f <- apsim_example("Wheat")
#' if (!is.na(f)) {
#'   apsim_sensitivity(
#'     f, parm_paths = "[Fertilise at sowing].Script.Amount",
#'     lower = 0, upper = 250, output = "Yield", method = "morris",
#'     morris_r = 4L, seed = 1L)
#' }
#' }
#'
#' @export
apsim_sensitivity <- function(sim, parm_paths, lower, upper, output,
                              target = NULL,
                              method = c("morris", "sobol", "both"),
                              morris_r = 10L, morris_levels = 6L,
                              sobol_n = 100L, nboot = 100L,
                              report = NULL, seed = NULL) {
  method <- match.arg(method)
  parm_paths <- as.character(parm_paths)
  npar <- length(parm_paths)
  lower <- rep_len(as.numeric(lower), npar)
  upper <- rep_len(as.numeric(upper), npar)
  if (any(upper <= lower)) {
    stop("`upper` must exceed `lower` elementwise.", call. = FALSE)
  }
  if (!is.null(seed)) {
    set.seed(as.integer(seed))
  }

  fm <- apsim_forward_model(sim, parm_paths, output = output, report = report)
  if (is_apsim_abstention(fm)) {
    return(fm)
  }
  failures <- new.env(parent = emptyenv())
  failures$n <- 0L
  scalar_model <- function(x) {
    obs <- fm(x)
    col <- target %||% colnames(obs)[[1L]]
    y <- obs[, col]
    bad <- !is.finite(y)
    failures$n <- failures$n + sum(bad)
    if (any(bad)) {
      y[bad] <- mean(y[!bad], na.rm = TRUE)
    }
    as.numeric(y)
  }

  indices <- vector("list", 0L)
  total_runs <- 0L
  if (method %in% c("morris", "both")) {
    mo <- .apsim_sa_morris(scalar_model, parm_paths, lower, upper, morris_r,
                           morris_levels)
    indices$morris <- mo$indices
    total_runs <- total_runs + mo$runs
  }
  if (method %in% c("sobol", "both")) {
    so <- .apsim_sa_sobol(scalar_model, parm_paths, lower, upper, sobol_n, nboot)
    indices$sobol <- so$indices
    total_runs <- total_runs + so$runs
  }
  params <- Reduce(function(a, b) merge(a, b, by = "parameter", sort = FALSE),
                   indices)

  apsim_manifest(
    "sensitivity", paste0("apsim:sensitivity:", method), params = params,
    metadata = list(method = method, target = target, n_runs = total_runs,
                    n_failures = failures$n, parm_paths = parm_paths),
    seed = if (is.null(seed)) NA_integer_ else as.integer(seed))
}

# --- Morris ------------------------------------------------------------------

#' Morris elementary-effect screening over the forward model
#' @noRd
#' @keywords internal
.apsim_sa_morris <- function(model, parm_paths, lower, upper, r, levels) {
  grid_jump <- max(1L, as.integer(levels) %/% 2L)
  mo <- sensitivity::morris(
    model = NULL, factors = parm_paths, r = as.integer(r),
    design = list(type = "oat", levels = as.integer(levels),
                  grid.jump = grid_jump),
    binf = lower, bsup = upper)
  y <- model(mo$X)
  mo <- sensitivity::tell(mo, y)
  ee <- mo$ee
  indices <- data.frame(
    parameter = parm_paths,
    mu = apply(ee, 2L, mean),
    mu_star = apply(ee, 2L, function(e) mean(abs(e))),
    sigma = apply(ee, 2L, stats::sd),
    row.names = NULL, check.names = FALSE)
  list(indices = indices, runs = nrow(mo$X))
}

# --- Sobol -------------------------------------------------------------------

#' Sobol-Jansen variance decomposition over the forward model
#' @noRd
#' @keywords internal
.apsim_sa_sobol <- function(model, parm_paths, lower, upper, n, nboot) {
  npar <- length(parm_paths)
  draw <- function() {
    u <- matrix(stats::runif(n * npar), nrow = n, ncol = npar)
    d <- sweep(sweep(u, 2L, upper - lower, `*`), 2L, lower, `+`)
    colnames(d) <- parm_paths
    as.data.frame(d)
  }
  so <- sensitivity::soboljansen(model = NULL, X1 = draw(), X2 = draw(),
                                 nboot = as.integer(nboot))
  y <- model(so$X)
  so <- sensitivity::tell(so, y)
  indices <- data.frame(
    parameter = parm_paths,
    S = so$S[["original"]],
    T = so$T[["original"]],
    row.names = NULL, check.names = FALSE)
  list(indices = indices, runs = nrow(so$X))
}
