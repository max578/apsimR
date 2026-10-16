test_that("apsim_server abstains without a server executable", {
  on.exit(apsim_configure(), add = TRUE)
  apsim_configure(server = file.path(tempdir(), "no-such-apsim-server"))
  srv <- apsim_server(apsimx_fixture())
  expect_true(is_apsim_abstention(srv))
  expect_identical(srv$reason, "runtime_unavailable")
})

test_that("string-column decoding unpacks length-prefixed elements", {
  enc <- function(s) {
    b <- charToRaw(s)
    c(writeBin(length(b), raw(), size = 4L, endian = "little"), b)
  }
  blob <- c(enc("alpha"), enc(""), enc("gamma"))
  expect_identical(apsimR:::.srv_unpack_strings(blob), c("alpha", "", "gamma"))
})

test_that("a free port is a plausible integer", {
  p <- apsimR:::.srv_free_port()
  expect_true(is.numeric(p) && length(p) == 1L && p > 1024L)
})

# Live server path: skipped where no working server is available. On a stock
# APSIM build whose V1 server cannot run files, apsim_run() abstains and this
# test skips; against a fixed/patched server it runs the round-trip.
test_that("a working server round-trips RUN + READ", {
  skip_if_not(apsim_available(), "APSIM not installed")
  ex <- apsim_example("Wheat")
  skip_if(is.na(ex), "no Wheat example in this install")
  srv <- apsim_server(ex, timeout = 30)
  skip_if(is_apsim_abstention(srv), "no apsim-server available")
  on.exit(close(srv), add = TRUE)

  r <- apsim_run(srv)
  skip_if(is_apsim_abstention(r),
          paste("server cannot run this file:", r$detail))

  d <- apsim_output(srv, "Report", "Yield")
  skip_if(is_apsim_abstention(d), "server READ unavailable")
  expect_s3_class(d, "data.frame")
  expect_gt(nrow(d), 0L)
})

# The V1 wire protocol, spoken to a loopback socket that stands in for
# apsim-server. The expected bytes are built by hand from the framing in the
# protocol: a string is [int32 little-endian byte length][UTF-8 bytes], a
# scalar is its raw little-endian bytes.
enc_str <- function(s) {
  b <- charToRaw(enc2utf8(s))
  c(writeBin(length(b), raw(), size = 4L, endian = "little"), b)
}
enc_int <- function(i) writeBin(as.integer(i), raw(), size = 4L, endian = "little")
enc_dbl <- function(x) writeBin(as.double(x), raw(), size = 8L, endian = "little")

# A connected pair: `server` is the handle apsimR writes to, `peer` plays
# apsim-server. The peer's replies are written before the client call, so the
# test runs in one process. Close both with close_pair().
server_pair <- function() {
  port <- apsimR:::.srv_free_port()
  listener <- serverSocket(port)
  client <- socketConnection("127.0.0.1", port, open = "w+b", blocking = TRUE)
  peer <- socketAccept(listener, open = "w+b", blocking = TRUE)
  close(listener)
  handle <- structure(new.env(parent = emptyenv()), class = "apsim_server")
  handle$con <- client
  handle$port <- port
  handle$file <- "Wheat.apsimx"
  handle$process <- list(is_alive = function() FALSE,
                         kill = function() invisible(TRUE))
  handle$scratch <- tempfile("apsimR_server_")
  dir.create(handle$scratch)
  handle$open <- TRUE
  list(server = handle, peer = peer)
}

close_pair <- function(p) {
  try(close(p$peer), silent = TRUE)
  close(p$server)
}

peer_send <- function(peer, bytes) {
  writeBin(bytes, peer)
  flush(peer)
}

test_that("apsim_run sends each override with the type tag for its class", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  ack <- enc_str("ACK")
  changes <- list(rate = 1.5, n = 7L, cultivar = "Hartog",
                  sow = as.Date("2020-05-02"), irrigate = TRUE,
                  depths = c(150, 300))
  # one ACK for RUN, three per override, one for FIN, then the result FIN
  peer_send(p$peer, c(ack, rep(ack, 3L * length(changes)), ack,
                      enc_str("FIN")))
  expect_true(apsim_run(p$server, changes))
  expected <- c(
    enc_str("RUN"),
    enc_str("rate"), enc_int(1L), enc_dbl(1.5),
    enc_str("n"), enc_int(0L), enc_int(7L),
    enc_str("cultivar"), enc_int(4L), enc_str("Hartog"),
    enc_str("sow"), enc_int(3L), enc_int(20200502L),
    enc_str("irrigate"), enc_int(2L), as.raw(1L),
    enc_str("depths"), enc_int(6L), enc_int(16L), enc_dbl(c(150, 300)),
    enc_str("FIN"))
  expect_identical(readBin(p$peer, "raw", length(expected)), expected)
})

test_that("a run the server reports as failed abstains with its message", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  peer_send(p$peer, c(enc_str("ACK"), enc_str("ACK"),
                      enc_str("Simulation Wheat failed")))
  out <- apsim_run(p$server)
  expect_true(is_apsim_abstention(out))
  expect_identical(out$detail, "Simulation Wheat failed")
})

test_that("a reply other than ACK is an error that quotes it", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  peer_send(p$peer, enc_str("BUSY"))
  expect_error(apsim_run(p$server), "expected ACK, got \"BUSY\"")
})

test_that("an empty reply reads as a closed connection", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  peer_send(p$peer, enc_int(0L))
  expect_error(apsim_run(p$server), "got <closed>")
})

test_that("a message cut short is an error, not a short read", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  peer_send(p$peer, as.raw(c(3L, 0L)))
  close(p$peer)
  expect_error(apsim_run(p$server), "closed mid-message")
})

test_that("apsim_output decodes each .NET column type", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  ack <- enc_str("ACK")
  column <- function(type, blob) c(enc_str(type), enc_int(length(blob)), blob)
  peer_send(p$peer, c(
    ack, ack, rep(ack, 6L), enc_str("FIN"),
    column("System.Double", enc_dbl(c(3.8, 4.1))),
    column("System.Single", writeBin(c(0.5, 0.25), raw(), size = 4L,
                                     endian = "little")),
    column("System.Int32", enc_int(c(1L, 2L))),
    column("System.Boolean", as.raw(c(1L, 0L))),
    column("System.DateTime", enc_int(c(20200101L, 20201231L))),
    column("System.String", c(enc_str("Sim1"), enc_str("")))))
  cols <- c("Yield", "Frac", "Day", "Sown", "Date", "Name")
  d <- apsim_output(p$server, "Report", cols)
  expect_identical(names(d), cols)
  expect_identical(d$Yield, c(3.8, 4.1))
  expect_identical(d$Frac, c(0.5, 0.25))
  expect_identical(d$Day, c(1L, 2L))
  expect_identical(d$Sown, c(TRUE, FALSE))
  expect_identical(d$Date, as.Date(c("2020-01-01", "2020-12-31")))
  expect_identical(d$Name, c("Sim1", ""))
  # READ, the table and each column, the list end, then one ACK per result
  expected <- c(enc_str("READ"), enc_str("Report"),
                unlist(lapply(cols, enc_str)), enc_str("FIN"),
                rep(ack, 1L + length(cols)))
  expect_identical(readBin(p$peer, "raw", length(expected)), expected)
})

test_that("apsim_output abstains on a server error and rejects odd types", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  ack <- enc_str("ACK")
  peer_send(p$peer, c(ack, ack, ack, enc_str("Report has no rows")))
  out <- apsim_output(p$server, "Report", "Yield")
  expect_true(is_apsim_abstention(out))
  expect_identical(out$detail, "Report has no rows")

  q <- server_pair()
  on.exit(close_pair(q), add = TRUE)
  peer_send(q$peer, c(ack, ack, ack, enc_str("FIN"),
                      enc_str("System.Decimal"), enc_int(0L)))
  expect_error(apsim_output(q$server, "Report", "Yield"),
               "unsupported column type \"System.Decimal\"")
})

test_that("a closed handle is refused, and columns must be named", {
  p <- server_pair()
  on.exit(close_pair(p), add = TRUE)
  expect_error(apsim_output(p$server, "Report", character(0)), "non-empty")
  scratch <- p$server$scratch
  close(p$server)
  expect_false(dir.exists(scratch))
  expect_false(p$server$open)
  expect_error(apsim_run(p$server), "not an open apsim_server")
  expect_error(apsim_run(list()), "not an open apsim_server")
})

test_that("waiting for a server that died or never listens abstains", {
  dead <- list(is_alive = function() FALSE,
               read_error_lines = function() c("starting", "port in use"))
  ab <- apsimR:::.srv_await_connection(dead, 1L, timeout = 1)
  expect_true(is_apsim_abstention(ab))
  expect_match(ab$detail, "port in use")

  alive <- list(is_alive = function() TRUE)
  port <- apsimR:::.srv_free_port()
  ab <- apsimR:::.srv_await_connection(alive, port, timeout = 0)
  expect_true(is_apsim_abstention(ab))
  expect_match(ab$detail, "timed out")
})

test_that("waiting for a listening server returns its connection", {
  port <- apsimR:::.srv_free_port()
  listener <- serverSocket(port)
  on.exit(close(listener), add = TRUE)
  con <- apsimR:::.srv_await_connection(list(is_alive = function() TRUE),
                                        port, timeout = 5)
  on.exit(close(con), add = TRUE)
  expect_s3_class(con, "sockconn")
})
