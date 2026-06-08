# apsim_sim.R -- a typed, round-trippable handle on an .apsimx simulation file.
#
# An `.apsimx` file is JSON: a tree of typed model nodes (Simulations > Simulation
# > Zone > Clock/Weather/Soil/Manager/Report/crop). `apsim_sim` reads that tree
# into a typed S7 object so a caller can inspect it, write it back unchanged
# (round-trip), and apply validated `[Node].Property = value` edits -- without the
# path-string depth limits of a list-of-lists representation. Reading and writing
# need no simulator; only `apsim_edit()` (which runs APSIM's own validator)
# requires the runtime.

#' A simulation file (`.apsimx`) as a typed object
#'
#' Reads an `.apsimx` (JSON) file into an S7 object holding the absolute file
#' path, the parsed model tree, and the APSIM version that produced it (or `NA`).
#' The object round-trips: [apsim_write()] writes the tree back unchanged.
#'
#' @param file Character path to an `.apsimx` file.
#'
#' @returns An `apsim_sim` S7 object.
#'
#' @examplesIf apsimR::apsim_available()
#' f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
#' if (nzchar(f)) {
#'   sim <- apsim_sim(f)
#'   apsim_simulations(sim)
#' }
#'
#' @export
apsim_sim <- S7::new_class(
  "apsim_sim",
  properties = list(
    file = S7::class_character,
    json = S7::class_list,
    apsim_version = S7::class_character
  ),
  constructor = function(file) {
    file <- as.character(file)
    if (length(file) != 1L || !file.exists(file)) {
      stop("`file` must be a path to an existing .apsimx file.", call. = FALSE)
    }
    json <- jsonlite::read_json(file, simplifyVector = FALSE)
    S7::new_object(
      S7::S7_object(),
      file = normalizePath(file),
      json = json,
      apsim_version = apsim_version())
  }
)

#' List the simulation names in an `apsim_sim`
#'
#' Walks the model tree and returns the `Name` of every `Models.Core.Simulation`
#' node. Needs no simulator (it reads the parsed JSON).
#'
#' @param x An `apsim_sim` object.
#' @returns A character vector of simulation names (possibly empty).
#' @examplesIf apsimR::apsim_available()
#' f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
#' if (nzchar(f)) apsim_simulations(apsim_sim(f))
#' @export
apsim_simulations <- function(x) {
  if (!S7::S7_inherits(x, apsim_sim)) {
    stop("`x` must be an `apsim_sim` object.", call. = FALSE)
  }
  names <- character(0)
  walk <- function(node) {
    if (!is.list(node)) {
      return(invisible())
    }
    type <- node[["$type"]]
    if (!is.null(type) && grepl("Models\\.Core\\.Simulation,", type)) {
      names <<- c(names, node[["Name"]] %||% NA_character_)
    }
    kids <- node[["Children"]]
    if (!is.null(kids)) {
      lapply(kids, walk)
    }
    invisible()
  }
  walk(x@json)
  names
}

#' Write an `apsim_sim` back to an `.apsimx` file
#'
#' Serialises the model tree to JSON. With no edits this is a faithful round-trip
#' of the file `apsim_sim()` read. Needs no simulator.
#'
#' @param x An `apsim_sim` object.
#' @param path Character output path. Defaults to a new temporary `.apsimx`.
#' @returns Invisibly, the output path.
#' @examplesIf apsimR::apsim_available()
#' f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
#' if (nzchar(f)) apsim_write(apsim_sim(f), tempfile(fileext = ".apsimx"))
#' @export
apsim_write <- function(x, path = tempfile(fileext = ".apsimx")) {
  if (!S7::S7_inherits(x, apsim_sim)) {
    stop("`x` must be an `apsim_sim` object.", call. = FALSE)
  }
  jsonlite::write_json(x@json, path, auto_unbox = TRUE, pretty = TRUE,
                       digits = NA, null = "null")
  invisible(path)
}

#' Apply `[Node].Property = value` edits through APSIM's validator
#'
#' Writes an APSIM `--apply` config file from `edits` and runs the simulator's own
#' editor, so the change is validated against the model schema rather than poked
#' into raw JSON. Requires the simulator; returns an [apsim_abstention()] when it
#' is absent.
#'
#' @param x An `apsim_sim` object.
#' @param edits A named character vector of edits, names being APSIM node paths
#'   and values the new values, for example
#'   `c("[Clock].End" = "1991-12-31", "[Sow].Script.Population" = "120")`.
#' @param path Character output path for the edited file. Defaults to a temporary
#'   `.apsimx`.
#'
#' @returns A new `apsim_sim` for the edited file, or an `apsim_abstention`.
#'
#' @examplesIf apsimR::apsim_available()
#' f <- system.file("extdata", "Wheat.apsimx", package = "apsimR")
#' if (nzchar(f)) {
#'   apsim_edit(apsim_sim(f), c("[Clock].End" = "1991-12-31"))
#' }
#'
#' @export
apsim_edit <- function(x, edits, path = tempfile(fileext = ".apsimx")) {
  if (!S7::S7_inherits(x, apsim_sim)) {
    stop("`x` must be an `apsim_sim` object.", call. = FALSE)
  }
  if (is.null(names(edits)) || any(!nzchar(names(edits)))) {
    stop("`edits` must be a named character vector of `[Node].Path = value`.",
         call. = FALSE)
  }
  rt <- .apsim_resolve()
  if (is.na(rt$models) || !file.exists(rt$models)) {
    return(apsim_abstention("runtime_unavailable",
                            "apsim_edit() needs the simulator to validate edits"))
  }
  # APSIM's `--apply` applies the config to the positional file but writes the
  # result only where an explicit `save` command directs, leaving the source
  # untouched. So the config is the edits followed by `save <path>`.
  rundir <- tempfile("apsimR_edit_")
  dir.create(rundir)
  on.exit(unlink(rundir, recursive = TRUE, force = TRUE), add = TRUE)
  cfg <- file.path(rundir, "edit.txt")
  writeLines(c(sprintf("%s = %s", names(edits), unname(edits)),
               sprintf("save %s", path)), cfg)
  args <- c(shQuote(rt$models), "--apply", shQuote(cfg), shQuote(x@file))
  out <- tryCatch(.apsim_system(rt, args, tmpdir = rundir),
                  error = function(e) NULL)
  status <- attr(out, "status")
  if ((!is.null(status) && status != 0L) || !file.exists(path)) {
    return(apsim_abstention("run_failed",
                            paste(utils::tail(out, 3L), collapse = " | ")))
  }
  apsim_sim(path)
}

S7::method(print, apsim_sim) <- function(x, ...) {
  sims <- apsim_simulations(x)
  cat("<apsim_sim>\n")
  cat(sprintf("  file:        %s\n", basename(x@file)))
  cat(sprintf("  APSIM:       %s\n", x@apsim_version))
  cat(sprintf("  simulations: %d%s\n", length(sims),
              if (length(sims)) paste0(" (", paste(utils::head(sims, 4L),
                                                   collapse = ", "),
                                       if (length(sims) > 4L) ", ..." else "",
                                       ")") else ""))
  invisible(x)
}

# Coerce a path or an apsim_sim to an apsim_sim.
.as_apsim_sim <- function(x) {
  if (S7::S7_inherits(x, apsim_sim)) x else apsim_sim(x)
}
