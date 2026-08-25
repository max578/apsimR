# emulate.R -- a fast surrogate for an expensive APSIM output.
#
# A single APSIM run costs seconds; a calibration or sensitivity sweep needs
# thousands. An emulator breaks that wall: run the simulator at a space-filling
# design once, fit a Gaussian-process surrogate to the (parameters -> output) map,
# then predict anywhere in microseconds with a calibrated uncertainty. apsimR
# ships a real, dependency-free exact GP (squared-exponential ARD kernel whose
# per-dimension length-scales, signal variance and noise variance are fitted by
# maximising the exact log marginal likelihood, Cholesky solve, standardised
# in/out) as the default backend, and composes PESTO's GP / random-feature
# surrogates when present. Every
# emulator is returned with mandatory leave-one-out diagnostics -- an emulator
# whose own honesty is unmeasured is worse than none.

# --- exact GP backend (base R) -----------------------------------------------

#' Train an exact squared-exponential Gaussian process
#'
#' Standardises inputs and output, then fits a genuine exact GP: the
#' per-dimension (ARD) length-scales, the signal variance and the noise variance
#' are estimated by maximising the exact log marginal likelihood (the median
#' pairwise distance only seeds the optimiser), and the GP is solved via a
#' Cholesky factor. Fitting the hyperparameters -- rather than fixing one
#' isotropic length-scale -- is what lets the surrogate match a reference exact GP
#' on anisotropic targets and interpolate the training design.
#'
#' @param X Numeric `n x p` design matrix.
#' @param y Numeric length-`n` response.
#' @param nugget Numeric jitter added to the kernel diagonal for conditioning, on
#'   top of the fitted noise variance.
#' @param restarts Integer number of extra optimiser restarts (from shorter /
#'   longer length-scales) guarding against a marginal-likelihood local optimum.
#' @returns A list capturing the fitted GP (ARD length-scales `ell`, signal
#'   variance `sf2`, noise variance `sn2`, Cholesky factor and weights).
#' @noRd
#' @keywords internal
.apsim_gp_train <- function(X, y, nugget = 1e-8, restarts = 1L) {
  X <- as.matrix(X)
  y <- as.numeric(y)
  n <- nrow(X)
  p <- ncol(X)
  centre <- colMeans(X)
  spread <- apply(X, 2L, stats::sd)
  spread[spread == 0 | !is.finite(spread)] <- 1
  xs <- sweep(sweep(X, 2L, centre, `-`), 2L, spread, `/`)
  y_mu <- mean(y)
  y_sd <- stats::sd(y)
  if (!is.finite(y_sd) || y_sd == 0) {
    y_sd <- 1
  }
  ys <- (y - y_mu) / y_sd

  # per-dimension squared-distance matrices (the ARD kernel ingredients)
  sq_dist <- lapply(seq_len(p), function(j) outer(xs[, j], xs[, j], `-`)^2)

  ell0 <- vapply(seq_len(p), function(j) {
    dj <- sqrt(sq_dist[[j]][upper.tri(sq_dist[[j]])])
    m <- stats::median(dj[dj > 0])
    if (!is.finite(m) || m <= 0) 1 else m
  }, numeric(1L))

  .build_k <- function(ell, sf2, sn2) {
    quad <- matrix(0, n, n)
    for (j in seq_len(p)) {
      quad <- quad + sq_dist[[j]] / ell[j]^2
    }
    sf2 * exp(-0.5 * quad) + diag(sn2 + nugget, n)
  }

  # negative log marginal likelihood; par = (log ell_1..p, log sf2, log sn2)
  nlml <- function(par) {
    ell <- exp(par[seq_len(p)])
    sf2 <- exp(par[p + 1L])
    sn2 <- exp(par[p + 2L])
    ch <- tryCatch(chol(.build_k(ell, sf2, sn2)), error = function(e) NULL)
    if (is.null(ch)) {
      return(1e10)
    }
    a <- backsolve(ch, backsolve(ch, ys, transpose = TRUE))
    0.5 * sum(ys * a) + sum(log(diag(ch))) + 0.5 * n * log(2 * pi)
  }

  lower <- c(rep(log(1e-2), p), log(1e-4), log(1e-8))
  upper <- c(rep(log(1e2), p), log(1e4), log(1e1))
  starts <- list(c(log(ell0), 0, log(1e-3)))
  if (restarts >= 1L) {
    starts <- c(starts, list(c(log(ell0 * 0.3), 0, log(1e-4))))
  }
  if (restarts >= 2L) {
    starts <- c(starts, list(c(log(ell0 * 3), 0, log(1e-2))))
  }

  best_par <- pmin(pmax(starts[[1L]], lower), upper)
  best_val <- Inf
  for (s in starts) {
    s <- pmin(pmax(s, lower), upper)
    opt <- tryCatch(
      stats::optim(s, nlml, method = "L-BFGS-B", lower = lower, upper = upper,
                   control = list(maxit = 100L)),
      error = function(e) NULL)
    if (!is.null(opt) && is.finite(opt$value) && opt$value < best_val) {
      best_val <- opt$value
      best_par <- opt$par
    }
  }

  ell <- exp(best_par[seq_len(p)])
  sf2 <- exp(best_par[p + 1L])
  sn2 <- exp(best_par[p + 2L])
  chol_k <- chol(.build_k(ell, sf2, sn2))
  alpha <- backsolve(chol_k, backsolve(chol_k, ys, transpose = TRUE))
  list(xs = xs, centre = centre, spread = spread, y_mu = y_mu, y_sd = y_sd,
       ell = ell, sf2 = sf2, sn2 = sn2, nugget = nugget,
       chol = chol_k, alpha = alpha)
}

#' Predict from an exact GP at new inputs
#'
#' @param gp A fitted GP from [.apsim_gp_train()].
#' @param x_new Numeric `m x p` matrix of query points.
#' @returns A list with `mean` and `sd`, each length `m`.
#' @noRd
#' @keywords internal
.apsim_gp_predict <- function(gp, x_new) {
  xn <- sweep(sweep(as.matrix(x_new), 2L, gp$centre, `-`), 2L, gp$spread, `/`)
  p <- ncol(gp$xs)
  quad <- matrix(0, nrow(xn), nrow(gp$xs))
  for (j in seq_len(p)) {
    quad <- quad + outer(xn[, j], gp$xs[, j], `-`)^2 / gp$ell[j]^2
  }
  k_star <- gp$sf2 * exp(-0.5 * quad)
  mean_s <- as.numeric(k_star %*% gp$alpha)
  v <- backsolve(gp$chol, t(k_star), transpose = TRUE)
  var_s <- pmax(gp$sf2 - colSums(v^2), 0) + gp$sn2
  list(mean = mean_s * gp$y_sd + gp$y_mu, sd = sqrt(var_s) * gp$y_sd)
}

# --- backend dispatch --------------------------------------------------------

#' Resolve a backend name to a (train, predict) function pair
#' @noRd
#' @keywords internal
.apsim_emulator_backend <- function(backend) {
  switch(
    backend,
    exact = list(
      train = function(X, y) .apsim_gp_train(X, y),
      predict = function(gp, x) .apsim_gp_predict(gp, x)),
    pesto = list(
      train = function(X, y) PESTO::train_gp_surrogate(as.matrix(X),
                                                       as.numeric(y)),
      predict = function(gp, x) {
        p <- PESTO::predict_gp_surrogate(gp, as.matrix(x))
        list(mean = as.numeric(p$mean),
             sd = sqrt(pmax(as.numeric(p$variance), 0)))
      }),
    stop(sprintf(
      'unknown emulator backend "%s"; use "exact" (base R) or "pesto" (needs the PESTO package).',
      backend), call. = FALSE))
}

# --- leave-one-out -----------------------------------------------------------

#' Leave-one-out diagnostics by refit
#'
#' Refits the backend on each `n - 1` subset and predicts the held-out point, so
#' the diagnostics measure genuine out-of-sample behaviour for any backend. Reports
#' the LOO root-mean-square error, predictive R-squared, and the 95% interval
#' coverage (the fraction of held-out points within `+/- 1.96 sd` -- honest if near
#' `0.95`).
#'
#' @param backend A `(train, predict)` pair from [.apsim_emulator_backend()].
#' @param X,y The full design and response.
#' @returns A list of diagnostics.
#' @noRd
#' @keywords internal
.apsim_emulator_loo <- function(backend, X, y) {
  X <- as.matrix(X)
  y <- as.numeric(y)
  n <- length(y)
  pred <- numeric(n)
  psd <- numeric(n)
  for (i in seq_len(n)) {
    gp <- backend$train(X[-i, , drop = FALSE], y[-i])
    p <- backend$predict(gp, X[i, , drop = FALSE])
    pred[i] <- p$mean[[1L]]
    psd[i] <- p$sd[[1L]]
  }
  resid <- y - pred
  sse <- sum(resid^2)
  sst <- sum((y - mean(y))^2)
  list(rmse = sqrt(mean(resid^2)),
       r2 = if (sst > 0) 1 - sse / sst else NA_real_,
       coverage95 = mean(abs(resid) <= 1.96 * psd),
       predicted = pred, predicted_sd = psd, observed = y)
}

# --- emulator object ---------------------------------------------------------

#' A fitted APSIM emulator
#'
#' The typed surrogate [apsim_emulate()] returns: the fitted GP, its training
#' design and response, the backend, and the leave-one-out diagnostics. Call
#' [predict()] on it to emulate the APSIM output at new parameters.
#'
#' @returns An `apsim_emulator` S7 object.
#' @noRd
apsim_emulator <- S7::new_class(
  "apsim_emulator",
  properties = list(
    backend = S7::class_character,
    parm_paths = S7::class_character,
    target = S7::class_character,
    X = S7::class_any,
    y = S7::class_numeric,
    gp = S7::class_any,
    loo = S7::class_list,
    apsim_version = S7::new_property(S7::class_character, default = NA_character_),
    emitter_version = S7::new_property(S7::class_character, default = NA_character_)
  )
)

#' Emulate an expensive APSIM output with a Gaussian-process surrogate
#'
#' Runs APSIM at a space-filling design over `[lower, upper]`, fits a GP surrogate
#' mapping the `parm_paths` parameters to a single scalar output, and returns it
#' with leave-one-out diagnostics. The default `exact` backend needs no extra
#' package; `pesto` uses PESTO's surrogate when installed. Predict at new
#' parameters with [predict()].
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param parm_paths Character vector of APSIM node paths (the emulator inputs).
#' @param lower,upper Numeric box bounds aligned to `parm_paths` (recycled from
#'   length one).
#' @param output A `function(report) -> named numeric` or report column name(s)
#'   identifying the output (see [apsim_forward_model()]).
#' @param target Character naming the output column to emulate when `output`
#'   yields several; defaults to the first.
#' @param n Integer number of design (training) points.
#' @param design Character design method passed to [apsim_design()]: `"lhs"`
#'   (default), `"grid"` or `"random"`.
#' @param backend Character: `"exact"` (default, dependency-free; a
#'   marginal-likelihood-fitted ARD exact GP) or `"pesto"`.
#' @param report Character report-table name, or `NULL` for the first report.
#' @param seed Optional integer RNG seed (design reproducibility).
#'
#' @returns An `apsim_emulator`, or an [apsim_abstention()] when the simulator
#'   (or, for `backend = "pesto"`, PESTO) is unavailable.
#'
#' @examplesIf apsimR::apsim_available()
#' # Fitting an emulator runs the simulator at every design point, so the example
#' # is wrapped in \dontrun{}; see the package vignette for a runnable walk-through.
#' \dontrun{
#' f <- apsim_example("Wheat")
#' if (!is.na(f)) {
#'   em <- apsim_emulate(
#'     f, parm_paths = "[Fertilise at sowing].Script.Amount",
#'     lower = 0, upper = 250, output = "Yield", n = 12L, seed = 1L)
#'   if (!is_apsim_abstention(em)) predict(em, matrix(c(50, 150), ncol = 1L))
#' }
#' }
#'
#' @export
apsim_emulate <- function(sim, parm_paths, lower, upper, output, target = NULL,
                          n = 30L, design = c("lhs", "grid", "random"),
                          backend = c("exact", "pesto"), report = NULL,
                          seed = NULL) {
  design <- match.arg(design)
  backend <- match.arg(backend)
  parm_paths <- as.character(parm_paths)
  if (backend == "pesto" && !requireNamespace("PESTO", quietly = TRUE)) {
    return(apsim_abstention(
      "feature_unsupported",
      "the `pesto` backend needs the PESTO package; install it or use backend = 'exact'",
      scope = "apsim_emulate"))
  }

  fm <- apsim_forward_model(sim, parm_paths, output = output, report = report)
  if (is_apsim_abstention(fm)) {
    return(fm)
  }
  x <- apsim_design(parm_paths, lower, upper, n = n, method = design,
                    seed = seed)
  obs <- fm(x)
  col <- target %||% colnames(obs)[[1L]]
  y <- obs[, col]
  keep <- is.finite(y)
  if (sum(keep) < 3L) {
    return(apsim_abstention(
      "run_failed",
      sprintf("only %d of %d design runs produced a finite output; cannot fit",
              sum(keep), length(y)),
      scope = "apsim_emulate"))
  }
  x <- x[keep, , drop = FALSE]
  y <- y[keep]

  impl <- .apsim_emulator_backend(backend)
  gp <- impl$train(x, y)
  loo <- .apsim_emulator_loo(impl, x, y)

  apsim_emulator(
    backend = backend, parm_paths = parm_paths,
    target = col, X = x, y = as.numeric(y), gp = gp, loo = loo,
    apsim_version = apsim_version(),
    emitter_version = as.character(utils::packageVersion("apsimR")))
}

# Predict from an APSIM emulator. Registered on the `stats::predict` generic for
# the S7 class (S7 uses a namespaced S3 class, so the method is registered through
# `S7::method()` -- as for `print` -- and wired at load by `S7::methods_register()`
# in `.onLoad`). `newdata` is a matrix / data.frame of query parameters with
# columns aligned to the emulator's `parm_paths`; the result is a `data.frame` with
# `mean` and `sd`, one row per query point.
#' @importFrom stats predict
S7::method(predict, apsim_emulator) <- function(object, newdata, ...) {
  impl <- .apsim_emulator_backend(object@backend)
  x <- .apsim_as_theta(newdata, object@parm_paths)
  p <- impl$predict(object@gp, x)
  data.frame(mean = p$mean, sd = p$sd)
}

S7::method(print, apsim_emulator) <- function(x, ...) {
  cat("<apsim_emulator>\n")
  cat(sprintf("  backend: %s\n", x@backend))
  cat(sprintf("  inputs:  %s\n", paste(x@parm_paths, collapse = ", ")))
  cat(sprintf("  target:  %s\n", x@target))
  cat(sprintf("  design:  %d points\n", length(x@y)))
  cat(sprintf("  LOO:     rmse %.4g | R2 %.3f | cover95 %.2f\n",
              x@loo$rmse, x@loo$r2, x@loo$coverage95))
  invisible(x)
}
