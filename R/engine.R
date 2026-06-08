# engine.R -- discover, configure and drive APSIM Next Generation.
#
# APSIM is an external .NET process, not an R library. This file owns the
# boundary: locating the installed `Models` (and `apsim-server`) executable and
# the .NET runtime across platforms, reporting availability and version, and
# running a simulation file from the command line. Every simulator-dependent
# entry point routes through `.apsim_run()` and abstains -- never errors opaquely
# -- when the runtime is absent.

# Package-internal mutable configuration (explicit paths win over discovery).
.apsim_env <- new.env(parent = emptyenv())

# --- discovery ---------------------------------------------------------------

#' Candidate `Models` executable paths for the running platform
#'
#' @returns A character vector of plausible absolute paths, newest install last,
#'   with any `PATH`-resolved `Models` appended.
#' @noRd
#' @keywords internal
.apsim_candidates <- function() {
  home <- path.expand("~")
  pattern <- switch(
    tolower(Sys.info()[["sysname"]]),
    darwin = file.path(home, "Applications", "APSIM*.app", "Contents",
                       "Resources", "bin", "Models"),
    windows = "C:/Program Files/APSIM*/bin/Models.exe",
    file.path("/usr/local/lib/apsim", "*", "bin", "Models"))
  globbed <- sort(Sys.glob(pattern))
  on_path <- unname(Sys.which("Models"))
  c(globbed, on_path[nzchar(on_path)])
}

#' Resolve the APSIM runtime (Models + apsim-server + .NET root)
#'
#' Prefers an explicit [apsim_configure()] setting; otherwise discovers the
#' newest installed `Models`. The companion `apsim-server` is taken from the same
#' `bin/` directory; an x64 .NET root at `~/.dotnet-x64` (the Apple-Silicon build)
#' is recorded when present so child processes inherit `DOTNET_ROOT`.
#'
#' @returns A list with `models`, `server` and `dotnet_root` (each a path or
#'   `NA_character_`).
#' @noRd
#' @keywords internal
.apsim_resolve <- function() {
  models <- .apsim_env$models %||% {
    cands <- .apsim_candidates()
    cands <- cands[file.exists(cands)]
    if (length(cands)) cands[[length(cands)]] else NA_character_
  }
  server <- .apsim_env$server %||% if (!is.na(models)) {
    cand <- file.path(dirname(models),
                      if (.is_windows()) "apsim-server.exe" else "apsim-server")
    if (file.exists(cand)) cand else NA_character_
  } else {
    NA_character_
  }
  dotnet <- .apsim_env$dotnet_root %||% {
    cand <- path.expand("~/.dotnet-x64")
    if (dir.exists(cand)) cand else NA_character_
  }
  list(models = models, server = server, dotnet_root = dotnet)
}

.is_windows <- function() {
  identical(tolower(Sys.info()[["sysname"]]), "windows")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# --- public configuration / health ------------------------------------------

#' Configure the APSIM runtime explicitly
#'
#' Pins the paths apsimR uses, overriding auto-discovery. Call this once per
#' session when APSIM is installed in a non-standard location or when more than
#' one version is present and a specific one is wanted. With all arguments `NULL`
#' it clears any pinned paths and reverts to discovery.
#'
#' @param models Character path to the `Models` executable, or `NULL` to discover.
#' @param server Character path to the `apsim-server` executable, or `NULL`.
#' @param dotnet_root Character path to the .NET runtime root (sets `DOTNET_ROOT`
#'   for child processes), or `NULL` to discover `~/.dotnet-x64`.
#'
#' @returns Invisibly, the resolved runtime list (see [apsim_available()]).
#'
#' @examples
#' # Revert to auto-discovery.
#' apsim_configure()
#'
#' @export
apsim_configure <- function(models = NULL, server = NULL, dotnet_root = NULL) {
  .apsim_env$models <- models
  .apsim_env$server <- server
  .apsim_env$dotnet_root <- dotnet_root
  .apsim_env$version <- NULL
  invisible(.apsim_resolve())
}

#' Is the APSIM simulator available?
#'
#' Reports whether a runnable `Models` executable has been found (by
#' [apsim_configure()] or auto-discovery). When this is `FALSE`, the
#' simulator-dependent verbs return an [apsim_abstention()] rather than running.
#'
#' @returns A single logical.
#'
#' @examples
#' if (apsim_available()) {
#'   apsim_version()
#' }
#'
#' @export
apsim_available <- function() {
  m <- .apsim_resolve()$models
  !is.na(m) && file.exists(m)
}

#' Path to an installed APSIM example simulation
#'
#' Returns the path to one of the `.apsimx` examples shipped with the installed
#' APSIM, so examples and tests can run against a real simulation without the
#' package bundling APSIM's own (separately-licensed) files. Returns
#' `NA_character_` when the simulator or the named example is not present.
#'
#' @param name Character example name without extension (default `"Wheat"`).
#' @returns A single character path, or `NA_character_`.
#'
#' @examplesIf apsimR::apsim_available()
#' apsim_example("Wheat")
#'
#' @export
apsim_example <- function(name = "Wheat") {
  rt <- .apsim_resolve()
  if (is.na(rt$models)) {
    return(NA_character_)
  }
  candidate <- file.path(dirname(dirname(rt$models)), "Examples",
                         paste0(name, ".apsimx"))
  if (file.exists(candidate)) candidate else NA_character_
}

#' Installed APSIM version string
#'
#' Runs `Models --version` and returns the reported version (for example
#' `"2026.5.8046.0"`), cached for the session. Returns `NA_character_` when the
#' simulator is not available.
#'
#' @returns A single character string, or `NA_character_`.
#'
#' @examples
#' apsim_version()
#'
#' @export
apsim_version <- function() {
  if (!is.null(.apsim_env$version)) {
    return(.apsim_env$version)
  }
  rt <- .apsim_resolve()
  if (is.na(rt$models)) {
    return(NA_character_)
  }
  out <- tryCatch(
    .apsim_system(rt, c(shQuote(rt$models), "--version")),
    error = function(e) NULL)
  ver <- if (is.null(out) || !length(out)) {
    NA_character_
  } else {
    # The version line looks like "APSIM 2026.5.8046.0"; keep the numeric token.
    m <- regmatches(out[[1]], regexpr("[0-9]+(\\.[0-9]+)+", out[[1]]))
    if (length(m)) m else trimws(out[[1]])
  }
  .apsim_env$version <- ver
  ver
}

# --- running -----------------------------------------------------------------

#' Run a shell command with the APSIM .NET environment set
#'
#' @param rt A resolved runtime list from [.apsim_resolve()].
#' @param args A character vector: command then arguments (already quoted).
#' @returns The captured stdout/stderr lines.
#' @noRd
#' @keywords internal
.apsim_system <- function(rt, args, tmpdir = NA_character_) {
  # The child is a .NET process that writes three families of scratch into its
  # temp directory -- APSIM manager-script sources (`APSIM*.cs`), .NET tempfiles
  # (`tmp*.tmp` from `Path.GetTempFileName()`), and diagnostic IPC sockets
  # (`clr-debug-pipe-*`, `dotnet-diagnostic-*`). We confine the first two by
  # redirecting the child's temp directory and kill the third outright with
  # `DOTNET_EnableDiagnostics=0`, so a run leaves the session temp directory
  # clean. When the caller gives no `tmpdir` (for example `apsim_version()`), an
  # internal scratch dir is created and removed here; otherwise the caller owns
  # cleanup of its run directory. Every variable touched is restored on exit.
  own_tmp <- is.na(tmpdir)
  if (own_tmp) {
    tmpdir <- tempfile("apsimR_scratch_")
    dir.create(tmpdir)
    on.exit(unlink(tmpdir, recursive = TRUE, force = TRUE), add = TRUE)
  }
  vars <- c(DOTNET_EnableDiagnostics = "0")
  if (!is.na(rt$dotnet_root)) {
    vars["DOTNET_ROOT"] <- rt$dotnet_root
  }
  vars[c("TMPDIR", "TMP", "TEMP")] <- tmpdir
  old <- Sys.getenv(names(vars), unset = NA, names = TRUE)
  do.call(Sys.setenv, as.list(vars))
  on.exit({
    for (k in names(vars)) {
      if (is.na(old[[k]])) {
        Sys.unsetenv(k)
      } else {
        do.call(Sys.setenv, stats::setNames(list(old[[k]]), k))
      }
    }
  }, add = TRUE)
  system(paste(args, collapse = " "), intern = TRUE, ignore.stderr = FALSE)
}

#' Run an `.apsimx` file through the `Models` command line
#'
#' Drives the simulator over a single file, exploiting APSIM's own multi-threaded
#' factorial fan-out (one process builds the file once and runs every simulation
#' it contains across cores). Returns the path to the SQLite DataStore the run
#' wrote, or an [apsim_abstention()] when the runtime is absent or the run fails.
#'
#' @param file Character path to an `.apsimx` file.
#' @param sim_names Optional regular expression; only simulations whose names
#'   match are run (`--simulation-names`).
#' @param cpu Optional integer thread cap (`--cpu-count`); `NULL` uses all cores.
#' @returns A list `list(db = <path>)`, or an `apsim_abstention`.
#' @noRd
#' @keywords internal
#' @returns A list `list(db = <path>, dir = <run dir>)` -- the caller reads `db`
#'   then removes `dir` -- or an `apsim_abstention`. The simulator runs on a copy
#'   inside `dir`, with its temp output redirected there, so nothing leaks into
#'   the session temp directory and the source file is never touched.
#' @noRd
.apsim_run <- function(file, sim_names = NULL, cpu = NULL) {
  rt <- .apsim_resolve()
  if (is.na(rt$models) || !file.exists(rt$models)) {
    return(apsim_abstention("runtime_unavailable",
                            "no Models executable found; see apsim_configure()"))
  }
  if (!file.exists(file)) {
    stop("`file` does not exist: ", file, call. = FALSE)
  }
  rundir <- tempfile("apsimR_run_")
  dir.create(rundir)
  work <- file.path(rundir, basename(file))
  file.copy(file, work, overwrite = TRUE)

  args <- c(shQuote(rt$models), shQuote(work))
  if (!is.null(sim_names)) {
    args <- c(args, "--simulation-names", shQuote(sim_names))
  }
  if (!is.null(cpu)) {
    args <- c(args, "--cpu-count", as.integer(cpu))
  }
  out <- tryCatch(.apsim_system(rt, args, tmpdir = rundir),
                  error = function(e) NULL)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    unlink(rundir, recursive = TRUE, force = TRUE)
    return(apsim_abstention("run_failed",
                            paste(utils::tail(out, 3L), collapse = " | ")))
  }
  db <- paste0(tools::file_path_sans_ext(work), ".db")
  if (!file.exists(db)) {
    unlink(rundir, recursive = TRUE, force = TRUE)
    return(apsim_abstention("no_output", "the run produced no .db DataStore"))
  }
  list(db = db, dir = rundir)
}
