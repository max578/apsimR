# design.R -- experimental designs over an APSIM parameter space.
#
# The emulator, and any user-driven sweep, needs a set of parameter points at
# which to run the simulator. `apsim_design()` builds one over a box-constrained
# space: a space-filling Latin hypercube by default (the right default for a GP
# training set), or a full factorial grid, or a uniform random sample. The result
# is an `nreal x npar` matrix in exactly the shape an `apsim_forward_model()`
# closure consumes, so a design feeds straight into a run.

#' Build an experimental design over an APSIM parameter space
#'
#' Generates parameter points filling the box `[lower, upper]` for the named
#' parameters. A Latin-hypercube design (the default) spreads `n` points evenly
#' through the space -- the standard choice for training an emulator; a grid gives
#' an exhaustive factorial (`n` becomes points-per-dimension); random gives an
#' independent uniform sample. The design is reproducible through `seed`.
#'
#' @param parm_paths Character vector of APSIM node paths (the design columns).
#' @param lower,upper Numeric vectors of box bounds, each aligned to `parm_paths`
#'   (recycled from length one).
#' @param n Integer. For `method = "lhs"` / `"random"`, the number of points; for
#'   `method = "grid"`, the number of points per dimension (so the design has
#'   `n ^ length(parm_paths)` rows).
#' @param method Character: `"lhs"` (default), `"grid"` or `"random"`.
#' @param seed Optional integer RNG seed for the stochastic methods.
#'
#' @returns A numeric matrix with `length(parm_paths)` named columns, one row per
#'   design point.
#'
#' @examples
#' d <- apsim_design(c("[Sow].Script.Population", "[Fertilise].Amount"),
#'                   lower = c(50, 0), upper = c(200, 200), n = 8, seed = 1L)
#' dim(d)
#'
#' @export
apsim_design <- function(parm_paths, lower, upper, n = 20L,
                         method = c("lhs", "grid", "random"), seed = NULL) {
  method <- match.arg(method)
  parm_paths <- as.character(parm_paths)
  npar <- length(parm_paths)
  if (!npar || any(!nzchar(parm_paths))) {
    stop("`parm_paths` must be a non-empty character vector.", call. = FALSE)
  }
  lower <- rep_len(as.numeric(lower), npar)
  upper <- rep_len(as.numeric(upper), npar)
  if (any(!is.finite(lower)) || any(!is.finite(upper)) || any(upper <= lower)) {
    stop("`lower` and `upper` must be finite with `upper > lower` elementwise.",
         call. = FALSE)
  }
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 1L) {
    stop("`n` must be a positive integer scalar.", call. = FALSE)
  }
  if (!is.null(seed)) {
    set.seed(as.integer(seed))
  }

  unit <- switch(
    method,
    lhs = lhs::randomLHS(n, npar),
    random = matrix(stats::runif(n * npar), nrow = n, ncol = npar),
    grid = {
      axis <- lapply(seq_len(npar), function(j) seq(0, 1, length.out = n))
      as.matrix(expand.grid(axis, KEEP.OUT.ATTRS = FALSE))
    })

  design <- sweep(sweep(unit, 2L, upper - lower, `*`), 2L, lower, `+`)
  colnames(design) <- parm_paths
  design
}
