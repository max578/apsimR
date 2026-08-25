# ground_truth.R -- APSIM as a known-causal-structure data factory (OSSE).
#
# This is the differentiator. A real experiment can never observe both potential
# outcomes of the same unit, so the true causal effect is unknowable and a causal
# method can only be trusted, never scored. A process simulator escapes that: run
# the same unit under control and under treatment and both potential outcomes are
# known exactly. `apsim_ground_truth()` does this across a set of heterogeneous
# units to manufacture an observing-system simulation experiment (OSSE) -- a
# dataset of observed (covariates, treatment, outcome) triples whose true
# individual and average treatment effects are recorded alongside. Treatment can be
# assigned at random (no confounding) or driven by a covariate that also moves the
# outcome (confounding), so a causal method (TACI, kernR) can be handed the
# observed data and graded against the truth it cannot see.

# --- result object -----------------------------------------------------------

#' A known-causal-structure dataset generated from APSIM
#'
#' Holds the observed `(covariates, treatment, outcome)` data a causal method
#' consumes, and the hidden `truth` -- both potential outcomes, the individual and
#' average treatment effects, and the assignment propensities -- it is graded
#' against.
#'
#' @returns An `apsim_ground_truth` S7 object.
#' @noRd
apsim_ground_truth_result <- S7::new_class(
  "apsim_ground_truth_result",
  properties = list(
    treatment = S7::class_character,
    observed = S7::class_data.frame,
    truth = S7::class_list,
    assignment = S7::class_character,
    apsim_version = S7::new_property(S7::class_character, default = NA_character_),
    emitter_version = S7::new_property(S7::class_character, default = NA_character_),
    seed = S7::new_property(S7::class_integer, default = NA_integer_)
  )
)

# --- OSSE generator ----------------------------------------------------------

#' Generate a known-causal-structure dataset from APSIM (an OSSE)
#'
#' Runs each unit under a control and a treatment value of `treatment` -- so both
#' potential outcomes are known -- then assigns each unit to treatment or control
#' and reveals the corresponding outcome, producing a dataset whose true effects
#' are recorded. Each unit is one row of `units`, whose columns are further APSIM
#' node paths defining that unit's context (the heterogeneity, and the source of
#' confounding). The result is the test-bench for a causal member: hand it the
#' observed `(covariates, W, Y)` and compare its estimate to the recorded average
#' treatment effect.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param treatment Character APSIM node path of the intervened parameter.
#' @param control,treated Numeric values of `treatment` under control (`W = 0`) and
#'   treatment (`W = 1`).
#' @param units A `data.frame` whose columns are APSIM node paths and whose rows
#'   are the units' contexts (covariates). At least one column.
#' @param output A `function(report) -> named numeric` or report column name(s)
#'   identifying the outcome (see [apsim_forward_model()]).
#' @param target Character naming the outcome column when `output` yields several;
#'   defaults to the first.
#' @param assignment Character: `"random"` (treatment independent of covariates --
#'   no confounding) or `"confounded"` (treatment probability driven by a
#'   covariate that also affects the outcome).
#' @param prob Numeric treatment probability for `assignment = "random"`.
#' @param confounder Character naming the `units` column that drives assignment
#'   when `assignment = "confounded"`.
#' @param confound_strength Numeric logistic coefficient on the standardised
#'   confounder (larger means stronger confounding).
#' @param report Character report-table name, or `NULL` for the first report.
#' @param seed Optional integer RNG seed (assignment reproducibility).
#'
#' @returns An `apsim_ground_truth_result`, or an [apsim_abstention()] when the
#'   simulator is unavailable.
#'
#' @examplesIf apsimR::apsim_available()
#' # An OSSE varying sowing population (the unit covariate) under two N rates,
#' # with treatment confounded by population. Runs the simulator twice per unit.
#' \dontrun{
#' f <- apsim_example("Wheat")
#' units <- data.frame(`[Sow using a variable rule].Script.Population` = c(80, 120,
#'   160, 200), check.names = FALSE)
#' apsim_ground_truth(
#'   f, treatment = "[Fertilise at sowing].Script.Amount",
#'   control = 0, treated = 150, units = units, output = "Yield",
#'   assignment = "confounded",
#'   confounder = "[Sow using a variable rule].Script.Population", seed = 1L)
#' }
#'
#' @export
apsim_ground_truth <- function(sim, treatment, control, treated, units, output,
                               target = NULL,
                               assignment = c("random", "confounded"),
                               prob = 0.5, confounder = NULL,
                               confound_strength = 1, report = NULL,
                               seed = NULL) {
  assignment <- match.arg(assignment)
  treatment <- as.character(treatment)
  if (!is.data.frame(units) || !ncol(units) || !nrow(units)) {
    stop("`units` must be a data.frame with at least one column and one row.",
         call. = FALSE)
  }
  if (assignment == "confounded" &&
      (is.null(confounder) || !confounder %in% names(units))) {
    stop("`assignment = \"confounded\"` needs `confounder` to name a `units` ",
         "column.", call. = FALSE)
  }
  if (!is.null(seed)) {
    set.seed(as.integer(seed))
  }

  fm <- apsim_forward_model(sim, c(treatment, names(units)), output = output,
                            report = report)
  if (is_apsim_abstention(fm)) {
    return(fm)
  }
  .apsim_osse(fm, treatment, control, treated, units, target, assignment, prob,
              confounder, confound_strength, seed)
}

# --- design core + print -----------------------------------------------------

#' Assemble an OSSE from a forward model and a unit table
#'
#' The simulator-independent core of [apsim_ground_truth()]: evaluates both
#' potential outcomes (a control block and a treated block, one forward call),
#' assigns treatment, reveals the observed outcome, and records the truth. Split
#' out so the causal-design logic is testable with an analytic forward model.
#'
#' @inheritParams apsim_ground_truth
#' @param fm A forward model from [apsim_forward_model()] over `c(treatment,
#'   names(units))`.
#' @returns An `apsim_ground_truth_result`, or an [apsim_abstention()].
#' @noRd
#' @keywords internal
.apsim_osse <- function(fm, treatment, control, treated, units, target,
                        assignment, prob, confounder, confound_strength, seed) {
  # Both potential outcomes for every unit: a control block and a treated block,
  # evaluated in one forward call (one APSIM run per row).
  covar <- as.matrix(units)
  nu <- nrow(covar)
  theta <- rbind(cbind(control, covar), cbind(treated, covar))
  colnames(theta) <- c(treatment, names(units))
  obs <- fm(theta)
  col <- target %||% colnames(obs)[[1L]]
  y <- obs[, col]
  y0 <- y[seq_len(nu)]
  y1 <- y[nu + seq_len(nu)]

  complete <- is.finite(y0) & is.finite(y1)
  if (sum(complete) < 2L) {
    return(apsim_abstention(
      "run_failed",
      sprintf("only %d of %d units produced both potential outcomes",
              sum(complete), nu),
      scope = "apsim_ground_truth"))
  }
  units <- units[complete, , drop = FALSE]
  y0 <- y0[complete]
  y1 <- y1[complete]
  nu <- nrow(units)

  propensity <- if (assignment == "confounded") {
    z <- as.numeric(scale(units[[confounder]]))
    z[!is.finite(z)] <- 0
    stats::plogis(confound_strength * z)
  } else {
    rep(prob, nu)
  }
  w <- stats::rbinom(nu, 1L, propensity)
  y_obs <- ifelse(w == 1L, y1, y0)

  ite <- y1 - y0
  ate <- mean(ite)
  naive_diff <- if (any(w == 1L) && any(w == 0L)) {
    mean(y_obs[w == 1L]) - mean(y_obs[w == 0L])
  } else {
    NA_real_
  }

  observed <- cbind(units, W = w, Y = y_obs)
  rownames(observed) <- NULL

  apsim_ground_truth_result(
    treatment = treatment, observed = observed,
    truth = list(Y0 = y0, Y1 = y1, ite = ite, ate = ate,
                 propensity = propensity, naive_diff = naive_diff,
                 confounding_bias = naive_diff - ate),
    assignment = assignment,
    apsim_version = apsim_version(),
    emitter_version = as.character(utils::packageVersion("apsimR")),
    seed = if (is.null(seed)) NA_integer_ else as.integer(seed))
}

S7::method(print, apsim_ground_truth_result) <- function(x, ...) {
  tr <- x@truth
  cat("<apsim_ground_truth>\n")
  cat(sprintf("  treatment:  %s\n", x@treatment))
  cat(sprintf("  assignment: %s\n", x@assignment))
  cat(sprintf("  units:      %d\n", nrow(x@observed)))
  cat(sprintf("  true ATE:   %.4g\n", tr$ate))
  if (!is.na(tr$naive_diff)) {
    cat(sprintf("  naive diff: %.4g (confounding bias %.4g)\n",
                tr$naive_diff, tr$confounding_bias))
  }
  cat("  observed:   (", paste(names(x@observed), collapse = ", "), ")\n",
      sep = "")
  invisible(x)
}
