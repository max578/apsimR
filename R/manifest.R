# manifest.R -- the contract-emitting result object.
#
# Every apsimR verb returns an `apsim_manifest`: a typed, provenance-complete
# result shaped like the orchestra's ensemble-manifest contract (params + outputs
# + an integrity hash + the APSIM version that produced it). It is deliberately
# `pesto_ensemble_manifest`-compatible so simulator output composes with the
# downstream calibration / UQ / causal stack; `as_pesto_manifest()` bridges to
# PESTO's S7 contract when that package is installed.

#' An APSIM result as a contract-emitting manifest
#'
#' The typed result every verb returns. `inferential_target` follows the
#' orchestra contract enum (`"predictions"`, `"parameters"`); `params` carries a
#' fitted-parameter table (empty for a pure prediction); `outputs` carries the
#' simulated report; provenance pins the APSIM version, an integrity hash, and the
#' seed.
#'
#' @param inferential_target Character: `"predictions"`, `"parameters"`,
#'   `"sensitivity"`, `"emulator"` or `"validation"`.
#' @param method Character method tag, for example `"apsim:predict"`.
#' @param params A `data.frame` of fitted parameters (default empty).
#' @param outputs The simulated report (`data.frame`) or `NULL`.
#' @param metadata A named list of auxiliary provenance.
#' @param seed Integer RNG seed (`NA` when none).
#'
#' @returns An `apsim_manifest` S7 object.
#'
#' @examples
#' m <- apsim_manifest("parameters", "apsim:estimate:mitscherlich",
#'                     params = data.frame(ymax = 4.2, rate = 0.018, y0 = 1.1))
#' m@inferential_target
#'
#' @export
apsim_manifest <- S7::new_class(
  "apsim_manifest",
  properties = list(
    inferential_target = S7::class_character,
    method = S7::class_character,
    params = S7::new_property(S7::class_data.frame, default = data.frame()),
    outputs = S7::new_property(S7::class_any, default = NULL),
    metadata = S7::new_property(S7::class_list, default = list()),
    apsim_version = S7::new_property(S7::class_character, default = NA_character_),
    emitter_version = S7::new_property(S7::class_character, default = NA_character_),
    seed = S7::new_property(S7::class_integer, default = NA_integer_),
    timestamp = S7::new_property(S7::class_POSIXct,
                                 default = quote(Sys.time())),
    data_hash = S7::new_property(S7::class_character, default = NA_character_)
  ),
  constructor = function(inferential_target, method, params = data.frame(),
                         outputs = NULL, metadata = list(), seed = NA_integer_) {
    valid <- c("predictions", "parameters", "sensitivity", "emulator",
               "validation")
    if (length(inferential_target) != 1L || !inferential_target %in% valid) {
      stop("`inferential_target` must be one of ",
           paste(valid, collapse = ", "), ".", call. = FALSE)
    }
    params <- as.data.frame(params)
    hash <- paste0("sha256:",
                   digest::digest(list(params, outputs, as.integer(seed)),
                                  algo = "sha256"))
    S7::new_object(
      S7::S7_object(),
      inferential_target = inferential_target, method = method,
      params = params, outputs = outputs, metadata = metadata,
      apsim_version = apsim_version(),
      emitter_version = as.character(utils::packageVersion("apsimR")),
      seed = as.integer(seed), timestamp = Sys.time(), data_hash = hash)
  }
)

#' Bridge an `apsim_manifest` to a PESTO ensemble manifest
#'
#' Converts to PESTO's `pesto_ensemble_manifest` S7 object (the orchestra's C2
#' contract) so an APSIM result can be consumed by the PESTO/kernR/flexyBayes
#' stack. Requires the optional `PESTO` package; returns an [apsim_abstention()]
#' when it is absent, and a `feature_unsupported` abstention if the payload cannot
#' be expressed in the ensemble contract.
#'
#' @param x An `apsim_manifest` object.
#' @returns A `PESTO::pesto_ensemble_manifest`, or an `apsim_abstention`.
#'
#' @examplesIf requireNamespace("PESTO", quietly = TRUE)
#' m <- apsim_manifest("parameters", "apsim:estimate",
#'                     params = data.frame(ymax = 4.2, rate = 0.018, y0 = 1.1))
#' as_pesto_manifest(m)
#'
#' @export
as_pesto_manifest <- function(x) {
  if (!S7::S7_inherits(x, apsim_manifest)) {
    stop("`x` must be an `apsim_manifest` object.", call. = FALSE)
  }
  if (!requireNamespace("PESTO", quietly = TRUE)) {
    return(apsim_abstention("runtime_unavailable",
                            "PESTO is not installed", scope = "as_pesto_manifest"))
  }
  params <- if (nrow(x@params)) x@params else data.frame(.apsim = NA_real_)
  out <- tryCatch(
    PESTO::pesto_ensemble_manifest(
      run_id = paste0("apsim-", substr(sub("^sha256:", "", x@data_hash), 1L, 12L)),
      params = params,
      outputs = if (is.null(x@outputs)) data.frame() else as.data.frame(x@outputs),
      weights = numeric(0), obs_target = numeric(0),
      seed = x@seed, data_hash = x@data_hash,
      apsim_version = x@apsim_version,
      pesto_version = as.character(utils::packageVersion("PESTO")),
      timestamp = x@timestamp, method = x@method,
      noptmax = 0L, lambda_schedule = numeric(0), failure_rate = 0),
    error = function(e) e)
  if (inherits(out, "error")) {
    return(apsim_abstention("feature_unsupported", conditionMessage(out),
                            scope = "as_pesto_manifest"))
  }
  out
}

S7::method(print, apsim_manifest) <- function(x, ...) {
  cat("<apsim_manifest>\n")
  cat(sprintf("  target:  %s\n", x@inferential_target))
  cat(sprintf("  method:  %s\n", x@method))
  cat(sprintf("  APSIM:   %s\n", x@apsim_version))
  if (nrow(x@params)) {
    cat(sprintf("  params:  %s\n", paste(names(x@params), collapse = ", ")))
  }
  if (!is.null(x@outputs)) {
    cat(sprintf("  outputs: %d rows x %d cols\n",
                nrow(x@outputs), ncol(x@outputs)))
  }
  cat(sprintf("  hash:    %s\n", x@data_hash))
  invisible(x)
}
