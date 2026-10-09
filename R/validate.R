# validate.R -- score simulated output against observations.
#
# A model that has not been confronted with data is a hypothesis, not a tool.
# `apsim_validate()` pairs simulated values with observed ones and reports the
# standard agronomic goodness-of-fit metrics -- error magnitude (RMSE, MAE),
# direction (mean error, percent bias), and skill relative to the observed mean
# (Nash-Sutcliffe efficiency, Willmott's index of agreement, RSR) -- then renders
# a typed verdict against the widely-used performance bands of Moriasi et al.
# (2007). The metrics are exact base-R formulae (no dependency); an optional
# observed-versus-predicted plot uses 'ggplot2' when it is installed.

# --- metrics -----------------------------------------------------------------

#' Goodness-of-fit metrics for paired observed / predicted values
#'
#' Computes the standard validation metrics on complete (non-`NA`) pairs. All are
#' exact base-R formulae: `me` (mean error / bias), `mae`, `rmse`, `nse`
#' (Nash-Sutcliffe efficiency), `r2` (squared Pearson correlation), `d` (Willmott's
#' index of agreement), `rsr` (RMSE over the observed standard deviation) and
#' `pbias` (percent bias).
#'
#' @param observed,predicted Numeric vectors of equal length.
#' @returns A one-row `data.frame` of metrics (with `n`, the pair count).
#' @noRd
#' @keywords internal
.apsim_gof <- function(observed, predicted) {
  observed <- as.numeric(observed)
  predicted <- as.numeric(predicted)
  if (length(observed) != length(predicted)) {
    stop("`observed` and `predicted` must have equal length.", call. = FALSE)
  }
  ok <- is.finite(observed) & is.finite(predicted)
  o <- observed[ok]
  p <- predicted[ok]
  n <- length(o)
  if (n < 2L) {
    stop("need at least two complete observed/predicted pairs.", call. = FALSE)
  }
  err <- p - o
  o_mu <- mean(o)
  ss_obs <- sum((o - o_mu)^2)
  rmse <- sqrt(mean(err^2))
  data.frame(
    n = n,
    me = mean(err),
    mae = mean(abs(err)),
    rmse = rmse,
    nse = if (ss_obs > 0) 1 - sum(err^2) / ss_obs else NA_real_,
    r2 = if (stats::sd(o) > 0 && stats::sd(p) > 0) stats::cor(o, p)^2 else NA_real_,
    d = {
      denom <- sum((abs(p - o_mu) + abs(o - o_mu))^2)
      if (denom > 0) 1 - sum(err^2) / denom else NA_real_
    },
    rsr = {
      sd_o <- stats::sd(o)
      if (sd_o > 0) rmse / sd_o else NA_real_
    },
    pbias = if (sum(o) != 0) 100 * sum(err) / sum(o) else NA_real_,
    row.names = NULL)
}

#' A typed performance verdict from the metrics
#'
#' Bands follow Moriasi et al. (2007): Nash-Sutcliffe efficiency governs the
#' grade (`> 0.75` very good, `0.65`-`0.75` good, `0.50`-`0.65` satisfactory,
#' otherwise unsatisfactory), with percent bias reported alongside.
#'
#' @param gof A one-row metrics `data.frame` from [.apsim_gof()].
#' @returns A character grade.
#' @noRd
#' @keywords internal
.apsim_verdict <- function(gof) {
  nse <- gof$nse
  if (is.na(nse)) {
    return("indeterminate")
  }
  if (nse > 0.75) {
    "very good"
  } else if (nse > 0.65) {
    "good"
  } else if (nse > 0.50) {
    "satisfactory"
  } else {
    "unsatisfactory"
  }
}

# --- pairing -----------------------------------------------------------------

#' Extract a numeric vector from a manifest, data.frame or numeric input
#' @noRd
#' @keywords internal
.apsim_pull <- function(x, col, what) {
  if (S7::S7_inherits(x, apsim_manifest)) {
    x <- x@outputs
  }
  if (is.numeric(x)) {
    return(as.numeric(x))
  }
  if (is.data.frame(x)) {
    if (is.null(col)) {
      stop("`", what, "` is a data.frame; name its column with `",
           what, "_col`.", call. = FALSE)
    }
    if (!col %in% names(x)) {
      stop("`", what, "` has no column `", col, "` (have: ",
           paste(names(x), collapse = ", "), ").", call. = FALSE)
    }
    return(as.numeric(x[[col]]))
  }
  stop("`", what, "` must be an apsim_manifest, data.frame or numeric vector.",
       call. = FALSE)
}

#' Validate simulated output against observations
#'
#' Pairs predicted with observed values and reports goodness-of-fit metrics plus a
#' typed performance verdict. `predicted` may be an [apsim_predict()] manifest, a
#' `data.frame`, or a numeric vector; `observed` a `data.frame` or numeric vector.
#' When both are data frames and `by` is given, they are joined on that key
#' (matching simulated and observed rows by, say, date) before scoring; otherwise
#' the two columns are paired by position and must be equal length.
#'
#' @param predicted An `apsim_manifest`, `data.frame`, or numeric vector of
#'   simulated values.
#' @param observed A `data.frame` or numeric vector of observed values.
#' @param predicted_col,observed_col Column names when the corresponding input is a
#'   `data.frame`.
#' @param by Optional key column present in both data frames to join on before
#'   pairing.
#'
#' @returns An `apsim_manifest` with `inferential_target = "validation"`: `params`
#'   holds the one-row metrics table, `outputs` the paired observed/predicted
#'   values, and `metadata$verdict` the performance grade.
#'
#' @section Verdict caveat: The typed grade in `metadata$verdict` reads on
#'   Nash-Sutcliffe efficiency (NSE) alone. The bands are those of Moriasi et
#'   al. (2007) `[unverified against the source paper]`, derived for monthly
#'   watershed and streamflow simulations, not paddock-scale crop yield; that
#'   paper's own recommendation is a joint reading of NSE with `rsr` and
#'   `pbias` (both already reported in `params`), not NSE on its own. Treat the
#'   grade as a diagnostic starting point, and read all three metrics before
#'   trusting it.
#'
#' @references Moriasi, D. N. et al. (2007) Model evaluation guidelines for
#'   systematic quantification of accuracy in watershed simulations.
#'   *Transactions of the ASABE* 50(3), 885-900.
#'   \doi{10.13031/2013.23153}
#'
#' @examples
#' obs <- c(2.1, 3.4, 4.0, 5.2)
#' sim <- c(2.0, 3.6, 3.8, 5.0)
#' v <- apsim_validate(sim, obs)
#' v@metadata$verdict
#'
#' @export
apsim_validate <- function(predicted, observed, predicted_col = NULL,
                           observed_col = NULL, by = NULL) {
  if (!is.null(by) && is.data.frame(predicted) && is.data.frame(observed)) {
    if (!all(by %in% names(predicted)) || !all(by %in% names(observed))) {
      stop("`by` (", paste(by, collapse = ", "),
           ") must be a column of both `predicted` and `observed`.",
           call. = FALSE)
    }
    merged <- merge(predicted, observed, by = by, suffixes = c(".pred", ".obs"))
    p <- .apsim_pull(merged, paste0(predicted_col, ".pred"), "predicted")
    o <- .apsim_pull(merged, paste0(observed_col, ".obs"), "observed")
  } else {
    p <- .apsim_pull(predicted, predicted_col, "predicted")
    o <- .apsim_pull(observed, observed_col, "observed")
    if (length(p) != length(o)) {
      stop("`predicted` (", length(p), ") and `observed` (", length(o),
           ") differ in length; supply `by` to join, or align them.",
           call. = FALSE)
    }
  }

  gof <- .apsim_gof(o, p)
  verdict <- .apsim_verdict(gof)
  apsim_manifest(
    "validation", "apsim:validate", params = gof,
    outputs = data.frame(observed = o, predicted = p, row.names = NULL),
    metadata = list(verdict = verdict, governing_metric = "nse",
                    reference = "Moriasi et al. (2007)"))
}

#' Plot observed against predicted for a validation manifest
#'
#' Builds an observed-versus-predicted scatter with the 1:1 line, titled with the
#' verdict and key metrics. Requires the optional `ggplot2` package; returns an
#' [apsim_abstention()] when it is absent.
#'
#' @param validation An `apsim_manifest` of `inferential_target = "validation"`
#'   (the result of [apsim_validate()]).
#' @returns A `ggplot` object, or an `apsim_abstention`.
#'
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' v <- apsim_validate(c(2, 3.6, 3.8, 5), c(2.1, 3.4, 4, 5.2))
#' apsim_validation_plot(v)
#'
#' @export
apsim_validation_plot <- function(validation) {
  if (!S7::S7_inherits(validation, apsim_manifest) ||
      validation@inferential_target != "validation") {
    stop("`validation` must be an apsim_validate() result.", call. = FALSE)
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(apsim_abstention("feature_unsupported",
                            "apsim_validation_plot() needs the ggplot2 package",
                            scope = "apsim_validation_plot"))
  }
  d <- validation@outputs
  gof <- validation@params
  subtitle <- sprintf("%s | NSE %.2f | RMSE %.3g | PBIAS %.1f%%",
                      validation@metadata$verdict, gof$nse, gof$rmse, gof$pbias)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$observed, y = .data$predicted)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2,
                         colour = "grey50") +
    ggplot2::geom_point(alpha = 0.8) +
    ggplot2::labs(title = "APSIM validation: observed vs predicted",
                  subtitle = subtitle, x = "Observed", y = "Predicted") +
    ggplot2::coord_equal() +
    ggplot2::theme_minimal()
}
