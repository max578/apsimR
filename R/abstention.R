# abstention.R -- the typed "I cannot answer" result.
#
# apsimR is standalone-functional: it loads and every verb exists with no APSIM
# installed. When an entry point needs the simulator and it is absent (or a run
# fails), the verb returns an `apsim_abstention` rather than erroring. This is the
# orchestra's calibrated-abstention pattern -- a member that refuses cleanly when
# its precondition fails, carrying a machine-readable reason a caller can branch
# on, instead of a stack trace.

#' Construct a typed abstention
#'
#' Returns a small classed object signalling that a simulator-dependent operation
#' could not be performed, with a machine-readable reason. Used in place of an
#' error so that callers (and the orchestration layer) can branch on a refusal
#' rather than catch an exception.
#'
#' @param reason Character scalar reason code. One of `"runtime_unavailable"`
#'   (no `Models` executable or .NET runtime found), `"run_failed"` (the
#'   simulator was invoked but did not complete), or `"no_output"` (the run
#'   produced no readable DataStore).
#' @param detail Character scalar human-readable detail, or `NA`.
#' @param scope Character scalar naming what was refused (default `"call"`).
#'
#' @returns An object of class `"apsim_abstention"`: a list with `reason`,
#'   `detail`, `scope` and `abstained = TRUE`.
#'
#' @examples
#' a <- apsim_abstention("runtime_unavailable", "no Models executable found")
#' is_apsim_abstention(a)
#'
#' @export
apsim_abstention <- function(reason, detail = NA_character_, scope = "call") {
  stopifnot(is.character(reason), length(reason) == 1L, nzchar(reason))
  structure(
    list(reason = reason, detail = as.character(detail),
         scope = as.character(scope), abstained = TRUE),
    class = "apsim_abstention")
}

#' Is an object an apsimR abstention?
#'
#' @param x Any object.
#' @returns A single logical: `TRUE` when `x` is an `apsim_abstention`.
#' @examples
#' is_apsim_abstention(apsim_abstention("run_failed"))
#' is_apsim_abstention(42)
#' @export
is_apsim_abstention <- function(x) {
  inherits(x, "apsim_abstention")
}

#' @export
print.apsim_abstention <- function(x, ...) {
  cat("<apsim_abstention>\n")
  cat(sprintf("  scope:  %s\n", x$scope))
  cat(sprintf("  reason: %s\n", x$reason))
  if (!is.na(x$detail) && nzchar(x$detail)) {
    cat(sprintf("  detail: %s\n", x$detail))
  }
  invisible(x)
}
