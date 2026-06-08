# server.R -- persistent-server client (the high-throughput execution path).
#
# The command-line path (engine.R) re-pays APSIM's ~2.8s file-load on every run.
# For an adaptive inner loop -- calibration, sensitivity, UQ -- that cost
# dominates. APSIM Next Generation ships a persistent server (`apsim-server`) that
# holds an `.apsimx` in memory and re-runs it on demand with modified parameters
# over a socket. This file starts that server and speaks its V1 native protocol
# from R over a loopback TCP connection, so a parameter sweep pays the load once.
#
# The protocol (APSIMInitiative/ApsimX APSIM.Server/V1 + APSIM.Client C reference)
# is length-prefixed little-endian framing: a string is [int32 byte-length][UTF-8],
# a bare scalar is its raw little-endian bytes. RUN sends "RUN", a list of
# (path, type-tag, value) replacements, then "FIN"; READ sends "READ", a table and
# column names, then reads back one (type-name, packed-array) pair per column.
# Every step is individually acknowledged with the string "ACK".
#
# An `apsim_server` is a stateful handle on an OS process plus a live socket, so it
# is a classed environment (like an R connection), not an immutable S7 value.

# --- wire primitives ---------------------------------------------------------

# Read exactly n bytes from a blocking connection, looping over short reads.
.srv_read_n <- function(con, n) {
  if (n == 0L) {
    return(raw(0))
  }
  buf <- raw(0)
  while (length(buf) < n) {
    chunk <- readBin(con, "raw", n - length(buf))
    if (!length(chunk)) {
      stop("apsim-server: connection closed mid-message.", call. = FALSE)
    }
    buf <- c(buf, chunk)
  }
  buf
}

.srv_send_str <- function(con, s) {
  b <- charToRaw(enc2utf8(s))
  writeBin(length(b), con, size = 4L, endian = "little")
  if (length(b)) {
    writeBin(b, con)
  }
  flush(con)
}

.srv_recv_str <- function(con) {
  len <- readBin(.srv_read_n(con, 4L), "integer", n = 1L, size = 4L,
                 endian = "little")
  if (len == 0L) {
    return(NULL)
  }
  rawToChar(.srv_read_n(con, len))
}

.srv_send_int <- function(con, i) {
  writeBin(as.integer(i), con, size = 4L, endian = "little")
  flush(con)
}

.srv_recv_int <- function(con) {
  readBin(.srv_read_n(con, 4L), "integer", n = 1L, size = 4L, endian = "little")
}

.srv_expect_ack <- function(con) {
  ack <- .srv_recv_str(con)
  if (!identical(ack, "ACK")) {
    stop("apsim-server: expected ACK, got ", .srv_quote(ack), ".",
         call. = FALSE)
  }
  invisible(TRUE)
}

.srv_quote <- function(x) {
  if (is.null(x)) "<closed>" else paste0("\"", x, "\"")
}

# Send one (path, value) replacement with the type tag the server expects, and
# absorb the three interleaved ACKs.
.srv_send_replacement <- function(con, path, value) {
  .srv_send_str(con, path)
  .srv_expect_ack(con)
  if (is.character(value)) {
    tag <- 4L
  } else if (inherits(value, "Date")) {
    tag <- 3L
  } else if (is.logical(value)) {
    tag <- 2L
  } else if (is.integer(value)) {
    tag <- 0L
  } else if (length(value) > 1L) {
    tag <- 6L                                     # double array
  } else {
    tag <- 1L                                     # double scalar
  }
  .srv_send_int(con, tag)
  .srv_expect_ack(con)
  switch(
    as.character(tag),
    "4" = .srv_send_str(con, value),
    "3" = .srv_send_int(con,
                        as.integer(format(value, "%Y%m%d"))),
    "2" = {
      writeBin(as.raw(if (isTRUE(value)) 1L else 0L), con)
      flush(con)
    },
    "0" = .srv_send_int(con, value),
    "6" = {
      writeBin(length(value) * 8L, con, size = 4L, endian = "little")
      writeBin(as.double(value), con, size = 8L, endian = "little")
      flush(con)
    },
    .srv_send_double(con, value))
  .srv_expect_ack(con)
  invisible(TRUE)
}

.srv_send_double <- function(con, x) {
  writeBin(as.double(x), con, size = 8L, endian = "little")
  flush(con)
}

# Decode one returned column: a .NET type-name string then a packed array.
.srv_recv_column <- function(con) {
  type <- .srv_recv_str(con)
  len <- readBin(.srv_read_n(con, 4L), "integer", n = 1L, size = 4L,
                 endian = "little")
  blob <- .srv_read_n(con, len)
  out <- switch(
    type,
    "System.Double"  = readBin(blob, "double", n = len %/% 8L, size = 8L,
                               endian = "little"),
    "System.Single"  = readBin(blob, "double", n = len %/% 4L, size = 4L,
                               endian = "little"),
    "System.Int32"   = readBin(blob, "integer", n = len %/% 4L, size = 4L,
                               endian = "little"),
    "System.Boolean" = as.logical(readBin(blob, "integer", n = len, size = 1L,
                                           signed = FALSE)),
    "System.DateTime" = as.Date(
      sprintf("%08d", readBin(blob, "integer", n = len %/% 4L, size = 4L,
                              endian = "little")), "%Y%m%d"),
    "System.String"  = .srv_unpack_strings(blob),
    stop("apsim-server: unsupported column type ", .srv_quote(type), ".",
         call. = FALSE))
  out
}

# A string column is a buffer of [int32 len][utf8] elements.
.srv_unpack_strings <- function(blob) {
  out <- character(0)
  i <- 1L
  n <- length(blob)
  while (i <= n) {
    len <- readBin(blob[i:(i + 3L)], "integer", n = 1L, size = 4L,
                   endian = "little")
    i <- i + 4L
    out <- c(out, if (len > 0L) rawToChar(blob[i:(i + len - 1L)]) else "")
    i <- i + len
  }
  out
}

# --- process lifecycle -------------------------------------------------------

# Find a free loopback TCP port by briefly holding a listening socket.
.srv_free_port <- function() {
  for (p in as.integer(20000 + (seq_len(200) * 53L) %% 40000)) {
    s <- tryCatch(serverSocket(p), error = function(e) NULL)
    if (!is.null(s)) {
      close(s)
      return(p)
    }
  }
  27746L
}

#' Start a persistent APSIM server holding a simulation in memory
#'
#' Launches `apsim-server` over loopback TCP, holding `sim` in memory, and opens a
#' connection to it. The returned handle runs the file repeatedly -- optionally
#' with modified parameters -- without re-paying APSIM's per-run load cost, which
#' is the throughput path for calibration and uncertainty loops. Returns an
#' [apsim_abstention()] when the server executable is unavailable.
#'
#' Always close the handle with `close()` to stop the server process.
#'
#' @param sim An `apsim_sim` object or a path to an `.apsimx` file.
#' @param port Integer loopback port, or `NULL` (default) to pick a free one.
#' @param timeout Numeric seconds to wait for the server to accept a connection
#'   (default 30).
#'
#' @returns An `apsim_server` handle (a classed environment), or an
#'   `apsim_abstention`.
#'
#' @examples
#' \donttest{
#' f <- apsim_example("Wheat")
#' if (!is.na(f) && apsim_available()) {
#'   srv <- apsim_server(f)
#'   if (!is_apsim_abstention(srv)) {
#'     apsim_run(srv)
#'     close(srv)
#'   }
#' }
#' }
#'
#' @export
apsim_server <- function(sim, port = NULL, timeout = 30) {
  rt <- .apsim_resolve()
  if (is.na(rt$server) || !file.exists(rt$server)) {
    return(apsim_abstention(
      "runtime_unavailable",
      "no apsim-server executable found; see apsim_configure()",
      scope = "apsim_server"))
  }
  s <- .as_apsim_sim(sim)
  port <- as.integer(port %||% .srv_free_port())
  # Confine the server's .NET scratch (`APSIM*.cs`, `tmp*.tmp`) to a private dir
  # cleaned at close(), and disable the diagnostic IPC sockets, so a long-lived
  # server leaves the session temp directory clean -- mirroring `.apsim_system()`.
  scratch <- tempfile("apsimR_server_")
  dir.create(scratch)
  env <- c(Sys.getenv())
  env[["DOTNET_EnableDiagnostics"]] <- "0"
  env[c("TMPDIR", "TMP", "TEMP")] <- scratch
  if (!is.na(rt$dotnet_root)) {
    env[["DOTNET_ROOT"]] <- rt$dotnet_root
  }
  proc <- processx::process$new(
    rt$server,
    c("listen", "--file", s@file, "--native", "--remote",
      "--address", "127.0.0.1", "--port", as.character(port), "--keep-alive"),
    env = env, stdout = "|", stderr = "|")

  con <- .srv_await_connection(proc, port, timeout)
  if (is_apsim_abstention(con)) {
    proc$kill()
    unlink(scratch, recursive = TRUE, force = TRUE)
    return(con)
  }
  handle <- structure(
    new.env(parent = emptyenv()), class = "apsim_server")
  handle$process <- proc
  handle$con <- con
  handle$port <- port
  handle$file <- s@file
  handle$scratch <- scratch
  handle$open <- TRUE
  handle
}

# Poll until the server accepts a TCP connection, or time out / die.
.srv_await_connection <- function(proc, port, timeout) {
  deadline <- Sys.time() + timeout
  repeat {
    if (!proc$is_alive()) {
      return(apsim_abstention(
        "run_failed",
        paste("apsim-server exited on start:",
              paste(utils::tail(proc$read_error_lines(), 3L), collapse = " | ")),
        scope = "apsim_server"))
    }
    con <- tryCatch(
      socketConnection("127.0.0.1", port, open = "w+b", blocking = TRUE,
                       timeout = 86400L),
      warning = function(w) NULL, error = function(e) NULL)
    if (!is.null(con)) {
      return(con)
    }
    if (Sys.time() > deadline) {
      return(apsim_abstention("run_failed",
                              "timed out waiting for apsim-server",
                              scope = "apsim_server"))
    }
    Sys.sleep(0.2)
  }
}

.srv_check_open <- function(server) {
  if (!inherits(server, "apsim_server") || !isTRUE(server$open)) {
    stop("`server` is not an open apsim_server handle.", call. = FALSE)
  }
}

# --- run / output ------------------------------------------------------------

#' Run the server's in-memory simulation, optionally with modified parameters
#'
#' Runs the `.apsimx` the server holds, optionally overriding model parameters for
#' this run. The file is not reloaded, so an adaptive sweep pays the load cost
#' once. Read the results with [apsim_output()].
#'
#' @param server An open `apsim_server` handle.
#' @param changes A named list of parameter overrides: names are APSIM model
#'   paths (for example `"[Wheat].Phenology.MinimumLeafNumber"`), values are R
#'   scalars (numeric, integer, logical, `Date`, character) or a numeric vector
#'   (passed as a double array). `NULL` (default) runs the file unchanged.
#'
#' @returns Invisibly `TRUE` on success; errors carry the simulator's message.
#'
#' @examples
#' \donttest{
#' f <- apsim_example("Wheat")
#' if (!is.na(f) && apsim_available()) {
#'   srv <- apsim_server(f)
#'   if (!is_apsim_abstention(srv)) {
#'     apsim_run(srv)
#'     close(srv)
#'   }
#' }
#' }
#'
#' @export
apsim_run <- function(server, changes = NULL) {
  .srv_check_open(server)
  con <- server$con
  .srv_send_str(con, "RUN")
  .srv_expect_ack(con)
  for (path in names(changes)) {
    .srv_send_replacement(con, path, changes[[path]])
  }
  .srv_send_str(con, "FIN")
  .srv_expect_ack(con)
  res <- .srv_recv_str(con)
  if (!identical(res, "FIN")) {
    return(apsim_abstention(
      "run_failed",
      if (is.null(res)) "server closed the connection" else res,
      scope = "apsim_run"))
  }
  invisible(TRUE)
}

#' Read a report from the server after a run
#'
#' Fetches columns of a report table produced by the most recent [apsim_run()],
#' decoding the server's typed column stream into a `data.frame`. The named report
#' must contain rows (the server signals an empty report as an error, not an empty
#' frame).
#'
#' @param server An open `apsim_server` handle.
#' @param table Character report-table name.
#' @param columns Character vector of column names to fetch.
#'
#' @returns A `data.frame` with one column per requested name.
#'
#' @examples
#' \donttest{
#' f <- apsim_example("Wheat")
#' if (!is.na(f) && apsim_available()) {
#'   srv <- apsim_server(f)
#'   if (!is_apsim_abstention(srv) && !is_apsim_abstention(apsim_run(srv))) {
#'     d <- apsim_output(srv, "Report", "Yield")
#'   }
#'   close(srv)
#' }
#' }
#'
#' @export
apsim_output <- function(server, table, columns) {
  .srv_check_open(server)
  if (!is.character(columns) || !length(columns)) {
    stop("`columns` must be a non-empty character vector.", call. = FALSE)
  }
  con <- server$con
  .srv_send_str(con, "READ")
  .srv_expect_ack(con)
  .srv_send_str(con, table)
  .srv_expect_ack(con)
  for (col in columns) {
    .srv_send_str(con, col)
    .srv_expect_ack(con)
  }
  .srv_send_str(con, "FIN")               # no ACK for the list terminator
  res <- .srv_recv_str(con)
  if (!identical(res, "FIN")) {
    return(apsim_abstention(
      "run_failed",
      if (is.null(res)) "server closed the connection" else res,
      scope = "apsim_output"))
  }
  .srv_send_str(con, "ACK")               # acknowledge the server's result FIN
  out <- vector("list", length(columns))
  for (i in seq_along(columns)) {
    out[[i]] <- .srv_recv_column(con)
    .srv_send_str(con, "ACK")
  }
  names(out) <- columns
  as.data.frame(out, check.names = FALSE, stringsAsFactors = FALSE)
}

#' @export
close.apsim_server <- function(con, ...) {
  server <- con
  if (isTRUE(server$open)) {
    try(close(server$con), silent = TRUE)
    try(server$process$kill(), silent = TRUE)
    if (!is.null(server$scratch)) {
      unlink(server$scratch, recursive = TRUE, force = TRUE)
    }
    server$open <- FALSE
  }
  invisible(NULL)
}

#' @export
print.apsim_server <- function(x, ...) {
  cat("<apsim_server>\n")
  cat(sprintf("  file: %s\n", basename(x$file)))
  cat(sprintf("  port: %d\n", x$port))
  cat(sprintf("  open: %s\n", isTRUE(x$open) && x$process$is_alive()))
  invisible(x)
}
