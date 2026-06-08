# datastore.R -- read APSIM's SQLite output DataStore.
#
# A run writes one SQLite `.db` next to the `.apsimx`. Underscore-prefixed tables
# are metadata (`_Simulations` maps integer IDs to names, `_Checkpoints` versions
# outputs); each `Report` node becomes a table keyed by `SimulationID` +
# `CheckpointID`. We read by a server-side JOIN that pulls only the requested
# report and checkpoint -- never whole tables into R then subset -- so large
# factorial DataStores stay cheap.

#' List the report tables in an APSIM DataStore
#'
#' @param db Character path to a `.db` DataStore.
#' @returns A character vector of report-table names (metadata tables, prefixed
#'   with `_`, are excluded).
#' @examplesIf apsimR::apsim_available()
#' # apsim_reports(run$db)
#' @export
apsim_reports <- function(db) {
  if (!file.exists(db)) {
    stop("DataStore not found: ", db, call. = FALSE)
  }
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  tables <- DBI::dbListTables(con)
  tables[!startsWith(tables, "_")]
}

#' Read a report from an APSIM DataStore
#'
#' Returns one report table joined to its simulation names and filtered to a
#' checkpoint. Reading is a single pushed-down SQL JOIN, so only the requested
#' columns and rows leave SQLite.
#'
#' @param db Character path to a `.db` DataStore.
#' @param report Character report-table name, or `NULL` (default) for the first
#'   report in the file.
#' @param checkpoint Character checkpoint name (default `"Current"`).
#'
#' @returns A `data.frame`: the report columns, prefixed with a `SimulationName`
#'   column when the report is simulation-keyed.
#'
#' @examplesIf apsimR::apsim_available()
#' # d <- apsim_read(run$db, report = "Report")
#'
#' @export
apsim_read <- function(db, report = NULL, checkpoint = "Current") {
  if (!file.exists(db)) {
    stop("DataStore not found: ", db, call. = FALSE)
  }
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  tables <- DBI::dbListTables(con)
  reports <- tables[!startsWith(tables, "_")]
  if (!length(reports)) {
    stop("the DataStore has no report tables.", call. = FALSE)
  }
  report <- report %||% reports[[1]]
  if (!report %in% reports) {
    stop("report `", report, "` is not in the DataStore (have: ",
         paste(reports, collapse = ", "), ").", call. = FALSE)
  }

  cols <- DBI::dbListFields(con, report)
  rep_id <- DBI::dbQuoteIdentifier(con, report)
  select <- if ("SimulationID" %in% cols) {
    paste0("s.\"Name\" AS \"SimulationName\", r.*")
  } else {
    "r.*"
  }
  query <- sprintf("SELECT %s FROM %s r", select, rep_id)
  if ("SimulationID" %in% cols) {
    query <- paste(query, "JOIN \"_Simulations\" s ON s.\"ID\" = r.\"SimulationID\"")
  }
  if ("CheckpointID" %in% cols && "_Checkpoints" %in% tables) {
    query <- paste0(query,
                    " JOIN \"_Checkpoints\" c ON c.\"ID\" = r.\"CheckpointID\"",
                    " WHERE c.\"Name\" = ", DBI::dbQuoteString(con, checkpoint))
  }
  DBI::dbGetQuery(con, query)
}
