# estimate.R -- run APSIM across an input and fit a reduced-form mechanism.
#
# A process model is too rich to hand downstream as-is; `apsim_estimate()` runs
# the simulator over a file whose report varies an input (for example N rate) and
# fits an interpretable dose-response to the (input, outcome) pairs -- by default
# a saturating Mitscherlich curve, the canonical N-response form. The fitted
# parameters become a `parameters` manifest a causal / decision member can read.

#' Fit a reduced-form response to (x, y)
#'
#' Pure numeric fit, separated so it is testable without the simulator.
#'
#' @param x,y Numeric vectors of equal length.
#' @param response Character: `"mitscherlich"` or `"linear"`.
#' @returns A one-row `data.frame` of fitted parameters.
#' @noRd
#' @keywords internal
.apsim_fit_response <- function(x, y, response) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  if (response == "linear") {
    co <- stats::coef(stats::lm(y ~ x))
    return(data.frame(intercept = unname(co[[1]]), slope = unname(co[[2]])))
  }
  # Mitscherlich saturating response: y = y0 + ymax * (1 - exp(-rate * x)).
  start <- list(y0 = min(y), ymax = max(y) - min(y), rate = 0.02)
  fit <- stats::nls(y ~ y0 + ymax * (1 - exp(-rate * x)), start = start,
                    control = stats::nls.control(maxiter = 100))
  co <- as.list(stats::coef(fit))
  data.frame(ymax = co$ymax, rate = co$rate, y0 = co$y0)
}

#' Estimate a mechanism by running APSIM across an input
#'
#' Runs the simulator on a copy of `sim`, reads the report, and fits a
#' reduced-form response of the outcome `y` on the input `x` (the report must
#' already vary `x`, for example through a factorial over an N-rate). Returns the
#' fitted parameters as a `parameters` [apsim_manifest()], or an
#' [apsim_abstention()] when the simulator is unavailable.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param x Character name of the input column in the report.
#' @param y Character name of the outcome column in the report.
#' @param response Character mechanism form: `"mitscherlich"` (default, a
#'   saturating dose-response) or `"linear"`.
#' @param report Character report-table name, or `NULL` for the first report.
#'
#' @returns An `apsim_manifest` with `inferential_target = "parameters"`, or an
#'   `apsim_abstention`.
#'
#' @examplesIf apsimR::apsim_available()
#' f <- apsim_example("Wheat")
#' if (!is.na(f)) {
#'   # apsim_estimate(f, x = "Nitrogen", y = "Yield")
#'   apsim_available()
#' }
#'
#' @export
apsim_estimate <- function(sim, x, y, response = c("mitscherlich", "linear"),
                           report = NULL) {
  response <- match.arg(response)
  s <- .as_apsim_sim(sim)
  run <- .apsim_run(s@file)
  if (is_apsim_abstention(run)) {
    return(run)
  }
  on.exit(unlink(run$dir, recursive = TRUE, force = TRUE), add = TRUE)
  d <- apsim_read(run$db, report = report)
  if (!all(c(x, y) %in% names(d))) {
    stop("`x` (", x, ") and `y` (", y, ") must both be columns of the report; ",
         "have: ", paste(names(d), collapse = ", "), ".", call. = FALSE)
  }
  params <- .apsim_fit_response(d[[x]], d[[y]], response)
  apsim_manifest(
    "parameters", paste0("apsim:estimate:", response), params = params,
    metadata = list(response = response, x = x, y = y, n = nrow(d)))
}
