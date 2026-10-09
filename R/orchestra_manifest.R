# orchestra_manifest.R -- the federation's shared result contract, emitted natively.
#
# apsimR is an orchestra member, so an APSIM result must be expressible in the
# contract every member emits or consumes as its primary inference-result type
# (ORCHESTRA binding #1): a versioned, hashed, provenance-complete S7 object.
# Before this file apsimR emitted only its own `apsim_manifest` plus a bridge to
# PESTO's *ensemble* contract, which no consumer outside the inversion stack
# reads -- so a prediction, a screening result or a validation verdict could not
# be handed to decideR, conductoR or optimix at all.
#
# The contract class is defined here rather than depended upon because the
# reference implementation (`ORCHESTRA_dev/integration/orchestra_manifest.R`)
# lives in the composition layer, not in an installable package. Two things make
# this a genuine implementation of the shared contract rather than a
# same-shaped-but-foreign look-alike:
#
#   * `package = NULL` on the class. S7 dispatch compares the class NAME string
#     `paste(package, name, sep = "::")`, so a namespaced
#     "apsimR::orchestra_manifest" would never match the reference class -- which
#     is sourced outside any namespace and is therefore bare. A consumer
#     dispatching on the contract would silently not see an apsimR result.
#   * The integrity-hash recipe. `.hash_payload()` reproduces the reference's
#     `.sha256()` byte for byte, so a manifest apsimR hashed verifies under any
#     member's `verify_manifest()` and vice versa.
#
# Both are grounded by `tests/testthat/test-orchestra-manifest.R` against an
# independently authored sibling implementation (optimix), not against apsimR's
# own conventions.

# --- schema constants --------------------------------------------------------

# The manifest schema version this member emits. Tracks the reference
# implementation; bump only with an additive (x.y) or breaking (x.0) change
# there. 2.0.0 was a breaking change to the integrity-hash scheme: the hash is
# computed over version-stable serialised bytes so a manifest emitted under one
# R version verifies under any other.
MANIFEST_VERSION <- "2.0.0-draft"

# The inferential-target enum, kept identical to the reference contract so a
# consumer's dispatch never sees an unknown token.
.INFERENTIAL_TARGETS <- c("parameters", "predictions",
                          "treatment_effects", "decisions",
                          "breeding_values", "marker_associations",
                          "structure")

# apsimR's own five targets, mapped onto the contract enum. `sensitivity` is a
# table of per-parameter influence measures, so it is a statement about
# parameters; `emulator` and `validation` are statements about predictions (a
# surrogate predicts; a validation grades predictions against observations). The
# original apsimR target is never lost -- it rides in `metadata$apsim_target`.
.APSIM_TO_CONTRACT_TARGET <- c(predictions = "predictions",
                               parameters = "parameters",
                               sensitivity = "parameters",
                               emulator = "predictions",
                               validation = "predictions")

# --- integrity hash ----------------------------------------------------------

#' SHA-256 over version-stable serialised bytes
#'
#' Serialisation is pinned to format 2 and its fixed 14-byte header (magic,
#' format, writer and minimum-reader R versions) is dropped before hashing:
#' those bytes are the only version-varying part of the representation, so a
#' manifest emitted under one R version verifies under any other. Byte-identical
#' to the reference contract's `.sha256()`.
#'
#' @param obj The object to hash.
#'
#' @returns A single hex string, with no prefix.
#' @noRd
#' @keywords internal
.sha256 <- function(obj) {
  raw <- serialize(obj, connection = NULL, version = 2L)
  raw <- raw[-seq_len(14L)]
  digest::digest(raw, algo = "sha256", serialize = FALSE)
}

#' Payload integrity hash matching the orchestra contract
#'
#' SHA-256 over the load-bearing data slots only: the schema version, the
#' emitter identity and the timestamp are metadata and are deliberately not
#' hashed. The `"sha256:"` prefix and the slot ordering match the reference
#' implementation, so a manifest hashed by apsimR verifies under the
#' federation's `verify_manifest()`.
#'
#' @param params,outputs,weights,obs_target,seed,summary The load-bearing slots.
#'
#' @returns A single `"sha256:"`-prefixed hex string.
#' @noRd
#' @keywords internal
.hash_payload <- function(params, outputs, weights, obs_target, seed,
                          summary = NULL) {
  obj <- list(params, outputs, weights, obs_target, seed, summary)
  paste0("sha256:", .sha256(obj))
}

# --- typed verdict -----------------------------------------------------------

#' A typed home for a headline verdict
#'
#' A non-ensemble inference -- a validation verdict, a decision -- has no meaningful
#' values for the ensemble payload slots and should not ride in `params` as a
#' one-row pseudo-parameter table. The contract's optional `summary` slot carries
#' the headline label, whether the emitter abstained, and the key metrics. It is
#' integrity-hashed with the rest of the payload, so a tampered verdict is
#' detected. The class and field names match the reference contract's
#' `manifest_summary()` exactly, so a consumer reads an apsimR verdict with no
#' special casing.
#'
#' @param headline Character scalar: the verdict itself, for example `"good"`.
#' @param abstained Logical scalar: did the emitter decline to stand behind the
#'   result?
#' @param metrics Named list of supporting numbers.
#' @param abstain_reason Character scalar reason when `abstained` is `TRUE`.
#'
#' @returns A `manifest_summary` list.
#'
#' @examples
#' manifest_summary("good", metrics = list(nse = 0.82))
#'
#' @export
manifest_summary <- function(headline, abstained = FALSE, metrics = list(),
                             abstain_reason = NA_character_) {
  stopifnot(is.character(headline), length(headline) == 1L, nzchar(headline),
            is.logical(abstained), length(abstained) == 1L, is.list(metrics))
  structure(list(headline = headline, abstained = isTRUE(abstained),
                 abstain_reason = abstain_reason, metrics = metrics),
            class = "manifest_summary")
}

# --- the contract class ------------------------------------------------------

#' The orchestra manifest contract (apsimR-side implementation)
#'
#' A versioned, hashed, provenance-complete S7 result object, property-compatible
#' with the federation's reference `orchestra_manifest` and carrying the same
#' bare class identity, so any orchestra consumer reads an apsimR result without
#' special casing. Build one from an [apsim_manifest()] with
#' [as_orchestra_manifest()] rather than calling this constructor directly.
#'
#' @usage NULL
#'
#' @returns An S7 object of class `orchestra_manifest`.
#'
#' @seealso [as_orchestra_manifest()], [verify_manifest()]
#' @export
orchestra_manifest <- S7::new_class(
  "orchestra_manifest",
  package = NULL,
  properties = list(
    manifest_version   = S7::new_property(S7::class_character,
                                          default = MANIFEST_VERSION),
    emitter_package    = S7::class_character,
    emitter_version    = S7::class_character,
    inferential_target = S7::class_character,
    run_id             = S7::class_character,
    method             = S7::class_character,
    seed               = S7::new_property(S7::class_integer,
                                          default = NA_integer_),
    params             = S7::new_property(S7::class_data.frame,
                                          default = data.frame()),
    outputs            = S7::new_property(S7::class_any, default = NULL),
    weights            = S7::new_property(S7::class_any, default = NULL),
    obs_target         = S7::new_property(S7::class_any, default = NULL),
    obs_schema         = S7::new_property(S7::class_any, default = NULL),
    summary            = S7::new_property(S7::class_any, default = NULL),
    consumed_manifests = S7::new_property(S7::class_list, default = list()),
    metadata           = S7::new_property(S7::class_list, default = list()),
    timestamp          = S7::class_POSIXct,
    data_hash          = S7::class_character
  ),
  validator = function(self) {
    errs <- character(0)
    if (length(self@run_id) != 1L || !nzchar(self@run_id)) {
      errs <- c(errs, "`run_id` must be a single non-empty string")
    }
    if (length(self@inferential_target) != 1L ||
        !self@inferential_target %in% .INFERENTIAL_TARGETS) {
      errs <- c(errs, sprintf("`inferential_target` must be one of %s",
                              paste(.INFERENTIAL_TARGETS, collapse = ", ")))
    }
    if (length(self@data_hash) != 1L) {
      errs <- c(errs, "`data_hash` must be a single string")
    }
    if (!is.null(self@summary) &&
        !inherits(self@summary, "manifest_summary")) {
      errs <- c(errs,
                "`summary`, when set, must be a manifest_summary() object")
    }
    # Reference fork 3: a derived manifest must carry its provenance lineage.
    # apsimR emits only primary manifests -- it consumes no manifest today -- so
    # this never fires on its own output; it is kept so the class stays a
    # faithful structural match to the reference.
    if (isTRUE(self@metadata$derived) &&
        length(self@consumed_manifests) < 1L) {
      errs <- c(errs, paste0("a derived manifest must record >= 1 ",
                             "`consumed_manifests` (provenance lineage is ",
                             "required, not optional)"))
    }
    if (length(errs) == 0L) NULL else paste(errs, collapse = "; ")
  }
)

#' Verify an orchestra manifest's payload integrity
#'
#' Recomputes the payload hash from the object's own load-bearing slots and
#' compares it to the stored `data_hash`. A mismatch means the payload was
#' modified after emission. Matches the reference contract's `verify_manifest()`,
#' so the check is symmetric across members.
#'
#' @param m An `orchestra_manifest` object.
#'
#' @returns A list with a logical `ok` and a human-readable `message`.
#'
#' @seealso [as_orchestra_manifest()]
#'
#' @examples
#' m <- apsim_manifest("predictions", "apsim:predict",
#'                     outputs = data.frame(Yield = c(3.8, 4.1)))
#' verify_manifest(as_orchestra_manifest(m))
#'
#' @export
verify_manifest <- function(m) {
  if (!S7::S7_inherits(m, orchestra_manifest)) {
    return(list(ok = FALSE, message = "not an orchestra_manifest"))
  }
  recomputed <- .hash_payload(m@params, m@outputs, m@weights,
                              m@obs_target, m@seed, m@summary)
  ok <- identical(recomputed, m@data_hash)
  list(ok = ok,
       message = if (ok) "data_hash verified"
                 else "data_hash MISMATCH -- manifest payload was modified")
}

S7::method(print, orchestra_manifest) <- function(x, ...) {
  cat("<orchestra_manifest>\n")
  cat(sprintf("  schema:   %s\n", x@manifest_version))
  cat(sprintf("  emitter:  %s %s\n", x@emitter_package, x@emitter_version))
  cat(sprintf("  target:   %s\n", x@inferential_target))
  cat(sprintf("  method:   %s\n", x@method))
  cat(sprintf("  run_id:   %s\n", x@run_id))
  if (!is.null(x@summary)) {
    cat(sprintf("  verdict:  %s\n", x@summary$headline))
  }
  if (!is.null(x@outputs)) {
    cat(sprintf("  outputs:  %d rows x %d cols\n",
                nrow(x@outputs), ncol(x@outputs)))
  }
  cat(sprintf("  hash:     %s\n", x@data_hash))
  invisible(x)
}

# --- the emit generic --------------------------------------------------------

#' Emit an apsimR result as an orchestra manifest
#'
#' The federation's emit and adapt generic. The [apsim_manifest()] method lifts
#' any apsimR result into the shared contract: the apsimR target is mapped onto
#' the contract's target enum (a sensitivity table is a statement about
#' parameters, an emulator and a validation are statements about predictions),
#' the assimilation context of an ensemble result is carried into the contract's
#' `weights` and `obs_target` slots, and a validation verdict is lifted into the
#' typed `summary` rather than left buried in metadata.
#'
#' Nothing is discarded: the original apsimR target, the APSIM build that
#' produced the result and apsimR's own payload hash all ride in `metadata`, so
#' a consumer can trace a contract manifest back to the apsimR result it came
#' from.
#'
#' @param x An [apsim_manifest()] object.
#' @param ... Method-specific arguments. The [apsim_manifest()] method accepts
#'   `run_id`, an optional character run identifier; when omitted a content hash
#'   is derived, so two identical results get the same identifier.
#'
#' @returns An `orchestra_manifest` S7 object.
#'
#' @seealso [verify_manifest()], [as_pesto_manifest()]
#'
#' @examples
#' m <- apsim_manifest("validation", "apsim:validate",
#'                     params = data.frame(nse = 0.82, rmse = 0.31),
#'                     outputs = data.frame(observed = c(2, 3.6),
#'                                          predicted = c(2.1, 3.4)),
#'                     metadata = list(verdict = "good"))
#' as_orchestra_manifest(m)
#'
#' @export
as_orchestra_manifest <- S7::new_generic("as_orchestra_manifest", "x")

S7::method(as_orchestra_manifest, S7::class_any) <- function(x, ...) {
  stop("`x` must be an `apsim_manifest` object.", call. = FALSE)
}

S7::method(as_orchestra_manifest, apsim_manifest) <-
  function(x, ..., run_id = NULL) {
    target <- unname(.APSIM_TO_CONTRACT_TARGET[[x@inferential_target]])
    ens <- .apsim_assimilation_context(x)

    smry <- NULL
    if (identical(x@inferential_target, "validation") &&
        !is.null(x@metadata$verdict)) {
      smry <- manifest_summary(
        headline = as.character(x@metadata$verdict),
        metrics = if (nrow(x@params)) as.list(x@params[1L, , drop = FALSE])
                  else list())
    }

    meta <- c(x@metadata,
              list(derived = FALSE,
                   apsim_target = x@inferential_target,
                   apsim_version = x@apsim_version,
                   apsim_data_hash = x@data_hash))

    dh <- .hash_payload(x@params, x@outputs, ens$weights, ens$obs_target,
                        x@seed, smry)
    rid <- run_id %||% paste0("apsimR-",
                              substr(sub("^sha256:", "", dh), 1L, 12L))

    orchestra_manifest(
      manifest_version   = MANIFEST_VERSION,
      emitter_package    = "apsimR",
      emitter_version    = x@emitter_version,
      inferential_target = target,
      run_id             = rid,
      method             = x@method,
      seed               = x@seed,
      params             = x@params,
      outputs            = x@outputs,
      weights            = ens$weights,
      obs_target         = ens$obs_target,
      summary            = smry,
      consumed_manifests = list(),
      metadata           = meta,
      timestamp          = x@timestamp,
      data_hash          = dh)
  }

# --- internal ----------------------------------------------------------------

#' The assimilation context of a calibration manifest
#'
#' A calibration against observations carries two quantities the contract has
#' typed slots for -- the observation targets and their weights. Both are
#' recorded in an apsimR calibration manifest's metadata; every other verb has
#' neither, and gets `NULL` rather than an invented value.
#'
#' @param x An `apsim_manifest`.
#'
#' @returns A list with `weights` and `obs_target`, each numeric or `NULL`.
#' @noRd
#' @keywords internal
.apsim_assimilation_context <- function(x) {
  num <- function(v) {
    if (is.null(v) || !length(v)) NULL
    else stats::setNames(as.numeric(v), names(v))
  }
  list(weights = num(x@metadata$obs_weights),
       obs_target = num(x@metadata$obs_target))
}
