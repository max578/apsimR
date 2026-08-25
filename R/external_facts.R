# ---------------------------------------------------------------------------
# External-facts provenance registry (Independent Oracle Principle).
#
# apsimR asserts class-8 facts about the APSIM authority: the DataStore SQLite
# schema (table + column names, the "Current" checkpoint), report column names,
# and manager node paths. The orchestra audit (2026-06-09) flagged these as
# grounded only by file-existence / a SKIPPED live test (skip != pass), with the
# DataStore schema un-grounded because the shipped `Wheat.db` is an empty stub.
#
# This registry enumerates each fact with the oracle that grounds it. A fact is
# *grounded* (token "grounded") iff `verified_on` is a non-NA Date; otherwise
# "[unverified]" (orchestra provenance vocabulary). The DataStore-schema and
# report-column facts below were grounded on 2026-06-09 by a REAL replayed
# `Wheat.apsimx` run against APSIM NG 2026.5.8046.0 (the oracle test
# tests/testthat/test-properties-recorded.R re-grounds them on every live run).
#
# Two surfaces, one source of truth: `.external_facts` (below) is the canonical
# recipe-52 registry the `/rpkg` audit driver sources and validates via
# `.validate_external_registry()`; the exported `apsim_external_facts()` is a
# per-value reader view derived from the SAME seed, so the two cannot drift (a
# drift-guard test asserts it). Both are base R only, so the audit can source
# this file in a vanilla session.
# ---------------------------------------------------------------------------

# Canonical grounding tokens (orchestra provenance vocabulary v1.0), hardcoded
# identically because apsimR cannot source the contract layer.
.APSIMR_GROUNDED   <- "grounded"
.APSIMR_UNVERIFIED <- "[unverified]"

# Date a fact family was last diffed against the live APSIM install. A real
# Wheat run on this date confirmed the DataStore schema + report columns.
.APSIMR_VERIFIED_ON <- "2026-06-09"

# Point-of-truth: the live APSIM Next Gen install itself (the authority that
# owns the DataStore schema and node paths), diffed by a replayed real run.
.APSIMR_SOURCE <-
  "APSIM Next Gen 2026.5.8046.0 install: DataStore SQLite schema / .apsimx JSON node paths; oracle = replayed Wheat.apsimx"

.apsimr_fact_seed <- function() {
  recorded_run <- "recorded_run"          # grounded by replaying a real run
  install <- "install_inspection"          # grounded by inspecting the install
  vdate <- as.Date(.APSIMR_VERIFIED_ON)
  ev <- "tests/testthat/test-properties-recorded.R"

  rows <- list(
    # DataStore schema (datastore.R:64-78) -- grounded by the real run.
    data.frame(fact_family = "datastore_table",
               asserted_value = c("_Simulations", "_Checkpoints", "Report"),
               oracle_kind = recorded_run, verified_on = vdate,
               evidence_path = ev, stringsAsFactors = FALSE),
    data.frame(fact_family = "datastore_column",
               asserted_value = c("_Simulations.ID", "_Simulations.Name",
                                  "_Checkpoints.Name", "Report.SimulationID",
                                  "Report.CheckpointID"),
               oracle_kind = recorded_run, verified_on = vdate,
               evidence_path = ev, stringsAsFactors = FALSE),
    data.frame(fact_family = "checkpoint_name", asserted_value = "Current",
               oracle_kind = recorded_run, verified_on = vdate,
               evidence_path = ev, stringsAsFactors = FALSE),
    # Report columns the example/forward path names (forward.R) -- grounded:
    # the stock Wheat report emits BOTH (the audit's "Wheat.AboveGround.Wt is
    # absent" claim was inferred from the empty stub and is false on a real run).
    data.frame(fact_family = "report_column",
               asserted_value = c("Yield", "Wheat.AboveGround.Wt"),
               oracle_kind = recorded_run, verified_on = vdate,
               evidence_path = ev, stringsAsFactors = FALSE),
    # Manager node paths (apsim_sim / forward) -- grounded by JSON inspection.
    data.frame(fact_family = "manager_node",
               asserted_value = c("[Fertilise at sowing].Script.Amount",
                                  "[Sow using a variable rule].Script.Population"),
               oracle_kind = install, verified_on = vdate,
               evidence_path = ev, stringsAsFactors = FALSE),
    data.frame(fact_family = "apsim_version", asserted_value = "2026.5.8046.0",
               oracle_kind = install, verified_on = vdate,
               evidence_path = ev, stringsAsFactors = FALSE)
  )
  do.call(rbind, rows)
}

# ---- Canonical recipe-52 registry (the audit's F13/F14 contract surface) ----
# Derived from `.apsimr_fact_seed()` so there is ONE source of truth. One row
# per fact family; `value` lists the asserted members. `kind`/`oracle_types`
# encode the recipe-52 taxonomy honestly: schema/enum/constant are *silent*
# kinds (a wrong value returns wrong output with no error) and therefore carry a
# D/E/F oracle -- here E (differential: the replayed real run vs the asserted
# value) and B (schema/structure diff vs the authority's own DataStore). The
# version is A (live resolution of the install) + D (property: parseable
# version string). Manager node paths are `locator` (a wrong path errors loudly)
# so a B structure-diff oracle suffices.
.APSIMR_KIND <- c(datastore_table = "schema", datastore_column = "schema",
                  checkpoint_name = "enum", report_column = "enum",
                  manager_node = "locator", apsim_version = "constant")
.APSIMR_ORACLE <- c(datastore_table = "B,E", datastore_column = "B,E",
                    checkpoint_name = "B,E", report_column = "B,E",
                    manager_node = "B", apsim_version = "A,D")

.external_facts <- local({
  seed <- .apsimr_fact_seed()
  fams <- unique(seed$fact_family)
  rows <- lapply(fams, function(f) {
    sub <- seed[seed$fact_family == f, , drop = FALSE]
    data.frame(
      family = f,
      fact_id = paste0("apsim.", f),
      kind = unname(.APSIMR_KIND[[f]]),
      value = paste(sub$asserted_value, collapse = ", "),
      source = .APSIMR_SOURCE,
      verified_on = format(max(sub$verified_on), "%Y-%m-%d"),
      reverify_by = "stable",
      oracle_types = unname(.APSIMR_ORACLE[[f]]),
      signoff = NA_character_,
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
})

# Silent-failure kinds: a wrong value returns wrong output with NO error, so a
# live call "succeeding" is not enough -- they need a property / differential /
# human oracle (D/E/F). (recipe 52 section 2)
.silent_fact_kinds <- c("enum", "crs", "units", "constant", "schema", "rule")

# NA-safe ISO date parse (never errors on bad input).
.parse_iso <- function(x) as.Date(as.character(x), format = "%Y-%m-%d")

#' Validate the external-fact registry (gate F13/F14 contract)
#'
#' Pure-R, no network. Run by apsimR's own tests and invoked by the `/rpkg`
#' audit driver. Returns one row per family with `pass` and, on failure, a
#' `reason`. Mirrors the recipe-52 canonical validator.
#'
#' @param registry The registry `data.frame` (default `.external_facts`).
#' @param test_dir Path to `tests/testthat` for the oracle-coverage check.
#' @returns A `data.frame`: `family`, `pass` (logical), `reason`.
#' @noRd
#' @keywords internal
.validate_external_registry <- function(registry = .external_facts,
                                        test_dir = "tests/testthat") {
  reasons <- character()
  fail <- function(msg) reasons[[length(reasons) + 1L]] <<- msg

  if (any(!nzchar(registry$source) | is.na(registry$source)))
    fail("row(s) with empty `source`")
  if (any(is.na(.parse_iso(registry$verified_on))))
    fail("row(s) with unparseable `verified_on`")

  window <- c(volatile = 90L, stable = 365L, literature = .Machine$integer.max)
  due <- vapply(seq_len(nrow(registry)), function(i) {
    pol <- registry$reverify_by[[i]]
    days <- if (pol %in% names(window)) window[[pol]] else NA_integer_
    if (is.na(days)) {
      due_by <- .parse_iso(pol)
      !is.na(due_by) && Sys.Date() > due_by
    } else {
      vd <- .parse_iso(registry$verified_on[[i]])
      !is.na(vd) && as.integer(Sys.Date() - vd) > days
    }
  }, logical(1L))
  if (any(due, na.rm = TRUE)) fail("row(s) past their re-grounding window")

  silent <- registry$kind %in% .silent_fact_kinds
  has_def <- grepl("[DEF]", registry$oracle_types)
  if (any(silent & !has_def))
    fail("silent-failure kind without a D/E/F oracle (recipe 52 section 2)")

  is_rule <- registry$kind == "rule"
  bad_signoff <- is_rule & (is.na(registry$signoff) | !nzchar(registry$signoff))
  if (any(bad_signoff)) fail("`kind == 'rule'` row without a `signoff`")

  oracle_files <- list.files(
    test_dir,
    pattern = "test-(contract-live|catalogue-diff|properties-recorded)\\.R$",
    full.names = TRUE)
  oracle_blob <- if (length(oracle_files)) paste(
    vapply(oracle_files, function(f) paste(readLines(f, warn = FALSE),
                                           collapse = "\n"), character(1L)),
    collapse = "\n") else ""
  fams <- unique(registry$family)
  uncovered <- fams[!vapply(fams, function(f) {
    grepl(f, oracle_blob, fixed = TRUE) ||
      any(grepl(registry$fact_id[registry$family == f], oracle_blob,
                fixed = TRUE))
  }, logical(1L))]

  data.frame(
    family = fams,
    pass = !fams %in% uncovered & length(reasons) == 0L,
    reason = ifelse(
      fams %in% uncovered,
      "no independent-oracle test references this family (F14)",
      if (length(reasons)) paste(reasons, collapse = "; ") else NA_character_),
    stringsAsFactors = FALSE)
}

#' apsimR's external-authority (APSIM) fact registry
#'
#' Enumerates the class-8 facts apsimR asserts about the APSIM simulator -- the
#' DataStore SQLite schema, the `"Current"` checkpoint, report column names, and
#' manager node paths -- with the oracle that grounds each and the date it was
#' last diffed against a live APSIM install. A fact is *grounded* only when
#' `verified_on` is a non-`NA` date; the DataStore-schema and report-column facts
#' are grounded by the replayed-real-run oracle test, not by a skipped test.
#'
#' @return A `data.frame` with `fact_family`, `asserted_value`, `oracle_kind`,
#'   `verified_on` (`Date`/`NA`), `evidence_path`, and a derived `grounding`
#'   token (`"grounded"` / `"[unverified]"`).
#' @seealso The orchestra provenance vocabulary
#'   (`ORCHESTRA_dev/integration/provenance_vocabulary.md`).
#' @export
#' @examples
#' apsim_external_facts()
apsim_external_facts <- function() {
  dt <- .apsimr_fact_seed()
  dt$grounding <- ifelse(is.na(dt$verified_on),
                         .APSIMR_UNVERIFIED, .APSIMR_GROUNDED)
  dt
}

#' Grounding status summary for apsimR's external facts
#'
#' Collapses [apsim_external_facts()] to one row per fact family, so a caller
#' (or the `/rpkg` audit driver) can see at a glance which classes of APSIM
#' fact are grounded by a replayed real run and which are still
#' `"[unverified]"`.
#'
#' @return A `data.frame` with one row per `fact_family`: `n_facts`,
#'   `n_grounded`, `n_unverified`.
#'
#' @examples
#' status <- apsim_fact_status()
#' status
#' # families with at least one unverified fact
#' status[status$n_unverified > 0, ]
#'
#' @export
apsim_fact_status <- function() {
  dt <- apsim_external_facts()
  agg <- stats::aggregate(
    grounding ~ fact_family, data = dt,
    FUN = function(g) c(n_facts = length(g),
                        n_grounded = sum(g == .APSIMR_GROUNDED),
                        n_unverified = sum(g == .APSIMR_UNVERIFIED)))
  out <- data.frame(fact_family = agg$fact_family, agg$grounding)
  names(out) <- c("fact_family", "n_facts", "n_grounded", "n_unverified")
  out
}
