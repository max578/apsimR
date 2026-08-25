# calibrate.R -- estimate APSIM parameters from observations (the inverse problem).
#
# Calibration is the forward model run backwards: find the parameters whose
# simulated observations best match real data. apsimR ships two real backends over
# the shared `apsim_forward_model()` closure -- a zero-dependency bounded optimiser
# (`stats::optim`, L-BFGS-B) for a point estimate, and PESTO's iterative ensemble
# smoother (`pesto_ies_callback()`, with RTPS inflation against ensemble collapse)
# for a full posterior parameter ensemble. Both minimise the same weighted
# observation misfit, so multiple targets are handled by one weight vector. The
# result is a `parameters` manifest carrying the estimate (or ensemble), ready for
# the downstream UQ / decision stack.

#' Calibrate APSIM parameters against observations
#'
#' Estimates the `parm_paths` parameters whose APSIM-simulated observations best
#' match `observed`, over the box `[lower, upper]`. The `ies` backend (default
#' when `PESTO` is installed) returns a posterior parameter ensemble through an
#' iterative ensemble smoother; the `optim` backend returns a single bounded
#' least-squares point estimate with no extra dependency. Several targets are
#' calibrated jointly -- pass a named `observed` vector and, optionally, per-target
#' `obs_sd` or `weights`.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param parm_paths Character vector of APSIM node paths to estimate.
#' @param lower,upper Numeric box bounds aligned to `parm_paths` (recycled from
#'   length one).
#' @param observed Named numeric vector of observed target values; the names must
#'   match what `output` produces.
#' @param output Either a `function(report) -> named numeric` reducing a run's
#'   report to the comparable observations, or a character vector of report column
#'   names (see [apsim_forward_model()]).
#' @param obs_sd Numeric observation standard deviation(s): a scalar or a vector
#'   aligned to `observed`. Defaults to ten percent of each `|observed|` (floored
#'   away from zero) when `NULL`.
#' @param weights Optional misfit weights aligned to `observed` for the `optim`
#'   backend; defaults to `1 / obs_sd^2`. The `ies` backend always weights by
#'   `1 / obs_sd`.
#' @param backend Character: `"auto"` (default -- `ies` if `PESTO` is installed,
#'   else `optim`), `"ies"`, or `"optim"`.
#' @param n_real Integer ensemble size for the `ies` backend.
#' @param noptmax Integer number of ensemble-smoother iterations (`ies`).
#' @param inflation Numeric RTPS inflation strength in `[0, 1]` for the `ies`
#'   backend (`0` disables it); guards against ensemble collapse.
#' @param report Character report-table name, or `NULL` for the first report.
#' @param seed Optional integer RNG seed (prior ensemble / reproducibility).
#'
#' @returns An `apsim_manifest` with `inferential_target = "parameters"` whose
#'   `params` holds the point estimate (`optim`) or the posterior ensemble
#'   (`ies`), or an [apsim_abstention()] when the simulator (or, for `ies`, PESTO)
#'   is unavailable.
#'
#' @examplesIf apsimR::apsim_available()
#' # A calibration runs the simulator many times, so the example is wrapped in
#' # \dontrun{}; see the package vignette for a runnable walk-through.
#' \dontrun{
#' f <- apsim_example("Wheat")
#' if (!is.na(f)) {
#'   apsim_calibrate(
#'     f, parm_paths = "[Fertilise at sowing].Script.Amount",
#'     lower = 0, upper = 250, observed = c(Yield = 2200), output = "Yield",
#'     backend = "optim", seed = 1L)
#' }
#' }
#'
#' @export
apsim_calibrate <- function(sim, parm_paths, lower, upper, observed, output,
                            obs_sd = NULL, weights = NULL,
                            backend = c("auto", "ies", "optim"),
                            n_real = 50L, noptmax = 4L, inflation = 0.8,
                            report = NULL, seed = NULL) {
  backend <- match.arg(backend)
  parm_paths <- as.character(parm_paths)
  npar <- length(parm_paths)
  lower <- rep_len(as.numeric(lower), npar)
  upper <- rep_len(as.numeric(upper), npar)
  if (any(upper <= lower)) {
    stop("`upper` must exceed `lower` elementwise.", call. = FALSE)
  }
  observed <- .apsim_named_obs(observed)
  obs_sd <- .apsim_obs_sd(obs_sd, observed)

  if (backend == "auto") {
    backend <- if (requireNamespace("PESTO", quietly = TRUE)) "ies" else "optim"
  }
  if (backend == "ies" && !requireNamespace("PESTO", quietly = TRUE)) {
    return(apsim_abstention(
      "feature_unsupported",
      "the `ies` backend needs the PESTO package; install it or use backend = 'optim'",
      scope = "apsim_calibrate"))
  }

  fm <- apsim_forward_model(sim, parm_paths, output = output, report = report)
  if (is_apsim_abstention(fm)) {
    return(fm)
  }

  if (backend == "optim") {
    .apsim_calibrate_optim(fm, parm_paths, lower, upper, observed, obs_sd,
                           weights, seed)
  } else {
    .apsim_calibrate_ies(fm, parm_paths, lower, upper, observed, obs_sd,
                         n_real, noptmax, inflation, seed)
  }
}

# --- shared input handling ---------------------------------------------------

#' Validate a named observation vector
#' @noRd
#' @keywords internal
.apsim_named_obs <- function(observed) {
  observed <- observed[!is.na(observed)]
  if (!length(observed) || is.null(names(observed)) ||
      any(!nzchar(names(observed)))) {
    stop("`observed` must be a non-empty named numeric vector.", call. = FALSE)
  }
  as.numeric(observed) -> v
  stats::setNames(v, names(observed))
}

#' Default / validate observation standard deviations
#' @noRd
#' @keywords internal
.apsim_obs_sd <- function(obs_sd, observed) {
  nobs <- length(observed)
  if (is.null(obs_sd)) {
    return(pmax(0.1 * abs(observed), .Machine$double.eps))
  }
  obs_sd <- as.numeric(obs_sd)
  if (length(obs_sd) == 1L) {
    obs_sd <- rep(obs_sd, nobs)
  }
  if (length(obs_sd) != nobs || any(obs_sd <= 0)) {
    stop("`obs_sd` must be a positive scalar or a vector aligned to `observed`.",
         call. = FALSE)
  }
  obs_sd
}

#' Align a forward-model prediction to the observed targets by name
#' @noRd
#' @keywords internal
.apsim_align_pred <- function(pred, observed) {
  nm <- names(observed)
  if (!is.null(names(pred)) && all(nm %in% names(pred))) {
    pred[nm]
  } else if (length(pred) == length(observed)) {
    stats::setNames(pred, nm)
  } else {
    stop(sprintf(
      "the forward model returned %d observation(s); expected %d aligned to `observed`.",
      length(pred), length(observed)), call. = FALSE)
  }
}

# --- optim backend -----------------------------------------------------------

#' Bounded least-squares point estimate via `stats::optim`
#' @noRd
#' @keywords internal
.apsim_calibrate_optim <- function(fm, parm_paths, lower, upper, observed,
                                   obs_sd, weights, seed) {
  if (!is.null(seed)) {
    set.seed(as.integer(seed))
  }
  w <- if (!is.null(weights)) {
    rep_len(as.numeric(weights), length(observed))
  } else {
    1 / obs_sd^2
  }
  objective <- function(theta) {
    pred <- fm(matrix(theta, nrow = 1L))[1L, ]
    pred <- .apsim_align_pred(pred, observed)
    if (any(!is.finite(pred))) {
      return(.Machine$double.xmax)
    }
    sum(w * (pred - observed)^2)
  }
  start <- (lower + upper) / 2
  op <- stats::optim(start, objective, method = "L-BFGS-B",
                     lower = lower, upper = upper)
  est <- stats::setNames(op$par, parm_paths)
  pred_at <- .apsim_align_pred(fm(matrix(op$par, nrow = 1L))[1L, ], observed)

  params <- as.data.frame(as.list(est), check.names = FALSE)
  apsim_manifest(
    "parameters", "apsim:calibrate:optim", params = params,
    outputs = data.frame(target = names(observed), observed = observed,
                         predicted = unname(pred_at), row.names = NULL),
    metadata = list(backend = "optim", objective = op$value,
                    convergence = op$convergence, message = op$message,
                    obs_sd = obs_sd, weights = w,
                    obs_target = observed, obs_weights = w),
    seed = if (is.null(seed)) NA_integer_ else as.integer(seed))
}

# --- ies backend -------------------------------------------------------------

#' Posterior parameter ensemble via PESTO's iterative ensemble smoother
#' @noRd
#' @keywords internal
.apsim_calibrate_ies <- function(fm, parm_paths, lower, upper, observed, obs_sd,
                                 n_real, noptmax, inflation, seed) {
  prior <- apsim_design(parm_paths, lower, upper, n = n_real, method = "lhs",
                        seed = seed)
  infl <- if (inflation > 0) {
    PESTO::pesto_inflation("rtps", alpha = inflation)
  } else {
    NULL
  }
  res <- tryCatch(
    PESTO::pesto_ies_callback(
      forward_model = fm, prior_ensemble = prior,
      obs = observed, obs_sd = obs_sd, noptmax = as.integer(noptmax),
      inflation = infl, on_failure = "na", verbose = FALSE),
    error = function(e) e)
  if (inherits(res, "error")) {
    return(apsim_abstention("run_failed", conditionMessage(res),
                            scope = "apsim_calibrate"))
  }

  post <- as.data.frame(res$par_ensemble)
  post[["real_name"]] <- NULL
  names(post) <- parm_paths
  phi <- as.data.frame(res$phi)
  phi_final <- if ("phi" %in% names(phi) && nrow(phi)) {
    mean(phi$phi[phi$iteration == max(phi$iteration)], na.rm = TRUE)
  } else {
    NA_real_
  }
  post_mean <- vapply(post, mean, numeric(1L), na.rm = TRUE)

  obs_ens <- as.data.frame(res$obs_ensemble)
  obs_ens <- obs_ens[, vapply(obs_ens, is.numeric, logical(1L)), drop = FALSE]
  obs_mean <- colMeans(as.matrix(obs_ens), na.rm = TRUE)
  pred_mean <- if (all(names(observed) %in% names(obs_mean))) {
    obs_mean[names(observed)]
  } else {
    stats::setNames(obs_mean[seq_along(observed)], names(observed))
  }

  apsim_manifest(
    "parameters", "apsim:calibrate:ies", params = post,
    outputs = data.frame(target = names(observed), observed = observed,
                         predicted = unname(pred_mean),
                         row.names = NULL),
    # The simulated-observation ensemble and the assimilation context are kept
    # alongside the posterior, not summarised away: they are the payload PESTO's
    # ensemble contract needs, so discarding them here is what left
    # `as_pesto_manifest()` with nothing to bridge (audit F1).
    metadata = list(backend = "ies", n_real = nrow(post), noptmax = noptmax,
                    inflation = inflation, phi_final = phi_final,
                    n_forward_evals = res$n_forward_evals,
                    failure_rate = res$failure_rate,
                    posterior_mean = post_mean, obs_sd = obs_sd,
                    obs_ensemble = obs_ens, obs_target = res$obs_target,
                    obs_weights = res$weights),
    seed = if (is.null(seed)) NA_integer_ else as.integer(seed))
}
