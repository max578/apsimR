# forward.R -- the shared forward-model core for the inference verbs.
#
# Calibration, sensitivity and emulation are all the same machine: vary a set of
# APSIM model parameters, run the simulator, reduce each run's report to a small
# numeric observation vector. This file builds that machine once, as a closure of
# the orchestra-standard shape -- `function(theta) -> obs`, where `theta` is an
# `nreal x npar` matrix and `obs` an `nreal x nobs` matrix (PESTO's
# `pesto_forward_model` contract) -- so the three verbs differ only in what they
# do with it. A single APSIM invocation per realisation applies the parameter
# edits and runs the file in one `--apply` config (edit + `run`), with the run
# confined to a scratch directory and the source file never touched.

# --- value formatting --------------------------------------------------------

#' Format a parameter value for an APSIM `--apply` config line
#'
#' Numeric values are written in fixed notation with full precision (APSIM's
#' config parser rejects R's default scientific notation for small magnitudes);
#' everything else is coerced to character verbatim.
#'
#' @param v A length-one parameter value.
#' @returns A single character string.
#' @noRd
#' @keywords internal
.apsim_fmt_value <- function(v) {
  if (is.numeric(v)) {
    format(v, scientific = FALSE, trim = TRUE, digits = 15L)
  } else {
    as.character(v)
  }
}

# --- observation reducer -----------------------------------------------------

#' Normalise an `output` specification to a report-reducing function
#'
#' The forward model needs a function mapping a run's report `data.frame` to a
#' named numeric observation vector. A caller may pass that function directly, or
#' name one or more report columns; named columns are reduced with `reduce`
#' (final value by default -- the end-of-season state most agronomic targets use).
#'
#' @param output A `function(data.frame) -> named numeric`, or a character vector
#'   of report column names.
#' @param reduce A `function(numeric) -> numeric(1)` applied to each named column
#'   (default takes the final value).
#' @returns A function of one argument (the report `data.frame`).
#' @noRd
#' @keywords internal
.apsim_observe_fn <- function(output, reduce = function(x) x[[length(x)]]) {
  if (is.function(output)) {
    return(output)
  }
  cols <- as.character(output)
  if (!length(cols) || any(!nzchar(cols))) {
    stop("`output` must be a function or a non-empty character vector of ",
         "report column names.", call. = FALSE)
  }
  function(report) {
    missing <- setdiff(cols, names(report))
    if (length(missing)) {
      stop("report has no column(s): ", paste(missing, collapse = ", "),
           "; have: ", paste(names(report), collapse = ", "), ".",
           call. = FALSE)
    }
    stats::setNames(vapply(cols, function(k) as.numeric(reduce(report[[k]])),
                           numeric(1L)),
                    cols)
  }
}

# --- single realisation ------------------------------------------------------

#' Run one parameter realisation through APSIM
#'
#' Applies the `parm_paths = values` edits and runs the file in a single
#' `Models --apply` invocation (config: the edit lines followed by `run`),
#' confined to `rundir`, then reduces the report with `observe`. Returns the named
#' observation vector, or `NULL` on any failure (so the caller can record an `NA`
#' row rather than abort the whole ensemble).
#'
#' @param rt A resolved runtime list from [.apsim_resolve()].
#' @param base_file Character path to the source `.apsimx`.
#' @param parm_paths Character vector of APSIM node paths to edit.
#' @param values Numeric (or coercible) vector of new values, aligned to
#'   `parm_paths`.
#' @param observe A report-reducing function (see [.apsim_observe_fn()]).
#' @param report Character report-table name, or `NULL` for the first.
#' @param checkpoint Character checkpoint name.
#' @returns A named numeric vector, or `NULL`.
#' @noRd
#' @keywords internal
.apsim_forward_eval <- function(rt, base_file, parm_paths, values, observe,
                                report, checkpoint) {
  rundir <- tempfile("apsimR_fwd_")
  dir.create(rundir)
  on.exit(unlink(rundir, recursive = TRUE, force = TRUE), add = TRUE)
  work <- file.path(rundir, basename(base_file))
  if (!file.copy(base_file, work, overwrite = TRUE)) {
    return(NULL)
  }
  cfg <- file.path(rundir, "apply.txt")
  writeLines(c(sprintf("%s = %s", parm_paths,
                       vapply(values, .apsim_fmt_value, character(1L))),
               "run"),
             cfg)
  args <- c(shQuote(rt$models), "--apply", shQuote(cfg), shQuote(work))
  out <- tryCatch(.apsim_system(rt, args, tmpdir = rundir),
                  error = function(e) NULL)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    return(NULL)
  }
  db <- paste0(tools::file_path_sans_ext(work), ".db")
  if (!file.exists(db)) {
    return(NULL)
  }
  report_df <- tryCatch(apsim_read(db, report = report, checkpoint = checkpoint),
                        error = function(e) NULL)
  if (is.null(report_df)) {
    return(NULL)
  }
  obs <- tryCatch(observe(report_df), error = function(e) NULL)
  if (is.null(obs) || !length(obs)) {
    return(NULL)
  }
  obs
}

# --- the forward model -------------------------------------------------------

#' Build an APSIM forward model
#'
#' Returns a closure of the orchestra-standard forward-model shape:
#' `function(theta) -> obs`, where `theta` is an `nreal x npar` numeric matrix
#' (one row per parameter realisation, columns aligned to `parm_paths`) and `obs`
#' is an `nreal x nobs` numeric matrix. Each row is one APSIM run with the
#' corresponding parameters substituted; failed runs become `NA` rows. The closure
#' is what [apsim_calibrate()], [apsim_sensitivity()] and [apsim_emulate()] all
#' evaluate, and it is directly accepted by `PESTO::pesto_ies_callback()` and by
#' the `sensitivity` package's `model` argument.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param parm_paths Character vector of APSIM node paths to vary, for example
#'   `c("[Sow].Script.Population", "[Wheat].Phenology.MinimumLeafNumber")`.
#' @param output Either a `function(report) -> named numeric` reducing a run's
#'   report to its observation vector, or a character vector of report column
#'   names (reduced by `reduce`).
#' @param report Character report-table name, or `NULL` for the first report.
#' @param checkpoint Character checkpoint name (default `"Current"`).
#' @param reduce When `output` names columns, the `function(numeric) ->
#'   numeric(1)` reducing each column (default takes the final value).
#'
#' @returns A function of one argument `theta` (an `nreal x npar` matrix or a
#'   length-`npar` vector) returning an `nreal x nobs` numeric matrix, or an
#'   [apsim_abstention()] when the simulator is unavailable.
#'
#' @examplesIf apsimR::apsim_available()
#' f <- apsim_example("Wheat")
#' \donttest{
#' if (!is.na(f)) {
#'   fm <- apsim_forward_model(f, "[Clock].End", output = "Wheat.AboveGround.Wt")
#'   if (!is_apsim_abstention(fm)) fm(matrix("1991-04-30", 1L, 1L))
#' }
#' }
#'
#' @export
apsim_forward_model <- function(sim, parm_paths, output, report = NULL,
                                checkpoint = "Current",
                                reduce = function(x) x[[length(x)]]) {
  s <- .as_apsim_sim(sim)
  rt <- .apsim_resolve()
  if (is.na(rt$models) || !file.exists(rt$models)) {
    return(apsim_abstention(
      "runtime_unavailable",
      "apsim_forward_model() needs the simulator to run realisations",
      scope = "apsim_forward_model"))
  }
  parm_paths <- as.character(parm_paths)
  if (!length(parm_paths) || any(!nzchar(parm_paths))) {
    stop("`parm_paths` must be a non-empty character vector of node paths.",
         call. = FALSE)
  }
  observe <- .apsim_observe_fn(output, reduce = reduce)
  base_file <- s@file

  function(theta) {
    theta <- .apsim_as_theta(theta, parm_paths)
    nreal <- nrow(theta)
    rows <- lapply(seq_len(nreal), function(i) {
      .apsim_forward_eval(rt, base_file, parm_paths, theta[i, ], observe,
                          report, checkpoint)
    })
    .apsim_bind_obs(rows)
  }
}

#' Coerce `theta` to an `nreal x npar` matrix with parameter columns
#'
#' @param theta A matrix, `data.frame` or vector.
#' @param parm_paths The expected parameter columns.
#' @returns A numeric/character matrix with `length(parm_paths)` columns.
#' @noRd
#' @keywords internal
.apsim_as_theta <- function(theta, parm_paths) {
  npar <- length(parm_paths)
  if (is.null(dim(theta))) {
    theta <- matrix(theta, nrow = 1L)
  }
  theta <- as.matrix(theta)
  if (ncol(theta) != npar) {
    stop("`theta` must have ", npar, " column(s) aligned to `parm_paths`; ",
         "got ", ncol(theta), ".", call. = FALSE)
  }
  colnames(theta) <- parm_paths
  theta
}

#' Bind a list of per-realisation observation vectors into a matrix
#'
#' Failed realisations (`NULL`) become rows of `NA`. The observation column names
#' are taken from the first successful realisation.
#'
#' @param rows A list of named numeric vectors and/or `NULL`.
#' @returns An `nreal x nobs` numeric matrix.
#' @noRd
#' @keywords internal
.apsim_bind_obs <- function(rows) {
  ok <- Filter(Negate(is.null), rows)
  if (!length(ok)) {
    stop("every APSIM realisation failed; check the parameter paths and file.",
         call. = FALSE)
  }
  obs_names <- names(ok[[1L]])
  nobs <- length(obs_names)
  mat <- matrix(NA_real_, nrow = length(rows), ncol = nobs,
                dimnames = list(NULL, obs_names))
  for (i in seq_along(rows)) {
    if (!is.null(rows[[i]])) {
      mat[i, ] <- as.numeric(rows[[i]])[seq_len(nobs)]
    }
  }
  mat
}
