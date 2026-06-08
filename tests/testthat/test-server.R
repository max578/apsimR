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
