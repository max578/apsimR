# manifest.R -- the contract-emitting result object.
#
# Every apsimR verb returns an `apsim_manifest`: a typed, provenance-complete
# result shaped like the orchestra's ensemble-manifest contract (params + outputs
# + an integrity hash + the APSIM version that produced it). Two adapters carry
# it into the federation: `as_orchestra_manifest()` emits the orchestra's general
# contract natively (see R/orchestra_manifest.R), and `as_pesto_manifest()`
# bridges an ensemble inversion into PESTO's narrower C2 ensemble contract.

# --- manifest object ---------------------------------------------------------

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

# --- PESTO bridge + print ----------------------------------------------------

#' Bridge an `apsim_manifest` to a PESTO ensemble manifest
#'
#' Converts to PESTO's `pesto_ensemble_manifest` S7 object (the orchestra's C2
#' contract) so an APSIM inversion result can be consumed by the
#' PESTO / kernR / flexyBayes stack.
#'
#' PESTO's contract is an *ensemble* contract, and the bridge respects that
#' rather than forcing every payload through it. It requires two things, both
#' read from the installed PESTO (0.10.1 at the time of writing) rather than
#' assumed: a method tag drawn from PESTO's own enum, and a parameter ensemble
#' whose rows align one-for-one with a simulated-observation ensemble. Exactly
#' one apsimR result satisfies that -- the posterior ensemble from
#' [apsim_calibrate()]'s `ies` backend, which PESTO's own ensemble smoother
#' produced. Every other apsimR result (a prediction, a screening table, an
#' emulator, a validation verdict) is not an ensemble inversion, so the bridge
#' returns a `feature_unsupported` [apsim_abstention()] naming the reason
#' instead of a manifest whose slots would have to be invented. Those results
#' compose through [as_orchestra_manifest()], the federation's general contract.
#'
#' The bridged manifest is re-hashed with PESTO's own payload recipe, so
#' `PESTO::verify_manifest()` verifies it; apsimR's own hash is kept in the
#' bridge's provenance chain through the source manifest.
#'
#' @param x An `apsim_manifest` object.
#'
#' @returns A `PESTO::pesto_ensemble_manifest`, or an `apsim_abstention` with
#'   reason `"runtime_unavailable"` (PESTO absent) or `"feature_unsupported"`
#'   (the payload is not an ensemble inversion).
#'
#' @seealso [as_orchestra_manifest()] for the general orchestra contract.
#'
#' @examplesIf requireNamespace("PESTO", quietly = TRUE)
#' # A prediction is not an ensemble inversion, so the bridge declines.
#' as_pesto_manifest(apsim_manifest("predictions", "apsim:predict",
#'                                  outputs = data.frame(Yield = 3.8)))
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
  method <- .apsim_pesto_method(x@method)
  if (is.na(method)) {
    return(apsim_abstention(
      "feature_unsupported",
      sprintf(paste0("method '%s' is not an ensemble inversion, so it has no ",
                     "counterpart in PESTO's method enum (%s); use ",
                     "as_orchestra_manifest() for the general contract"),
              x@method, paste(.PESTO_METHODS, collapse = ", ")),
      scope = "as_pesto_manifest"))
  }
  ens <- .apsim_pesto_ensemble(x)
  if (is.null(ens)) {
    return(apsim_abstention(
      "feature_unsupported",
      paste0("PESTO's ensemble contract needs a row-aligned parameter / ",
             "simulated-observation ensemble; this manifest carries none ",
             "(use as_orchestra_manifest() for the general contract)"),
      scope = "as_pesto_manifest"))
  }
  out <- tryCatch(
    PESTO::pesto_ensemble_manifest(
      run_id = paste0("apsim-", substr(sub("^sha256:", "", x@data_hash),
                                       1L, 12L)),
      params = ens$params,
      outputs = ens$outputs,
      weights = ens$weights, obs_target = ens$obs_target,
      seed = x@seed,
      data_hash = .apsim_pesto_data_hash(ens, x@seed),
      apsim_version = x@apsim_version,
      pesto_version = as.character(utils::packageVersion("PESTO")),
      timestamp = x@timestamp, method = method,
      noptmax = as.integer(x@metadata$noptmax %||% 0L),
      lambda_schedule = as.numeric(x@metadata$lambda_schedule %||% numeric(0)),
      failure_rate = as.numeric(x@metadata$failure_rate %||% 0)),
    error = function(e) e)
  if (inherits(out, "error")) {
    return(apsim_abstention("feature_unsupported", conditionMessage(out),
                            scope = "as_pesto_manifest"))
  }
  out
}

# --- bridge internals --------------------------------------------------------

# PESTO 0.10.1's `pesto_ensemble_manifest` validator accepts exactly these five
# method tags (read from the installed validator, not from memory). apsimR's own
# method vocabulary is namespaced ("apsim:calibrate:ies"), so the bridge must
# translate; a tag with no honest counterpart maps to NA and the bridge declines
# rather than mislabelling the algorithm that produced the ensemble.
.PESTO_METHODS <- c("ies_callback", "ies_filter", "ies_pst", "mda", "surrogate")

# The one grounded mapping: apsimR's `ies` calibration backend calls
# `PESTO::pesto_ies_callback()` directly (R/calibrate.R), so its result IS a
# PESTO ies_callback ensemble.
.APSIM_TO_PESTO_METHOD <- c("apsim:calibrate:ies" = "ies_callback")

#' Translate an apsimR method tag into PESTO's method enum
#'
#' @param method An apsimR method tag.
#'
#' @returns A single PESTO method token, or `NA_character_` when the tag has no
#'   honest counterpart.
#' @noRd
#' @keywords internal
.apsim_pesto_method <- function(method) {
  unname(.APSIM_TO_PESTO_METHOD[as.character(method)[[1L]]])
}

#' The row-aligned ensemble a PESTO manifest needs, or NULL
#'
#' PESTO's validator requires `nrow(params) == nrow(outputs)`. An `ies`
#' calibration manifest carries the posterior parameter ensemble in `params` and
#' the matching simulated-observation ensemble in `metadata$obs_ensemble`; its
#' `outputs` slot holds an observed-versus-predicted summary of a different
#' shape, so the ensemble is assembled here rather than read off `outputs`.
#'
#' @param x An `apsim_manifest`.
#'
#' @returns A list with `params`, `outputs`, `weights` and `obs_target`, or
#'   `NULL` when the manifest carries no ensemble.
#' @noRd
#' @keywords internal
.apsim_pesto_ensemble <- function(x) {
  params <- as.data.frame(x@params)
  obs_ens <- x@metadata$obs_ensemble
  outputs <- if (!is.null(obs_ens)) as.data.frame(obs_ens) else NULL
  if (is.null(outputs) || !nrow(params) || nrow(params) != nrow(outputs)) {
    return(NULL)
  }
  num <- function(v) {
    if (is.null(v) || !length(v)) numeric(0)
    else stats::setNames(as.numeric(v), names(v))
  }
  list(params = params, outputs = outputs,
       weights = num(x@metadata$obs_weights),
       obs_target = num(x@metadata$obs_target))
}

#' The payload hash PESTO's own verifier recomputes
#'
#' PESTO hashes the ensemble payload with its own recipe -- a `digest::digest()`
#' over the numeric matrices of `params` and `outputs` (dropping the optional
#' `real_name` label column), the weights, the targets and the seed. apsimR's
#' `apsim_manifest` hash is a different recipe over different slots, so passing
#' it through would produce a manifest that PESTO reports as tampered. The recipe
#' is reproduced here and grounded in `tests/testthat/test-manifest.R` against
#' `PESTO::verify_manifest()`: if PESTO ever changes it, that test fails loudly
#' rather than the bridge drifting silently.
#'
#' @param ens The ensemble list from `.apsim_pesto_ensemble()`.
#' @param seed The manifest seed.
#'
#' @returns A single `"sha256:"`-prefixed hex string.
#' @noRd
#' @keywords internal
.apsim_pesto_data_hash <- function(ens, seed) {
  drop_label <- function(d) {
    d <- as.data.frame(d)
    as.matrix(d[, setdiff(names(d), "real_name"), drop = FALSE])
  }
  paste0("sha256:",
         digest::digest(list(params = drop_label(ens$params),
                             outputs = drop_label(ens$outputs),
                             weights = as.numeric(ens$weights),
                             obs_target = as.numeric(ens$obs_target),
                             seed = as.integer(seed)),
                        algo = "sha256", serialize = TRUE))
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
