# This script imports only an installed namespace. It has no source fallback.
expected <- Sys.getenv("SPM_EXPECT_LIBRARY")
stopifnot(nzchar(expected), dir.exists(expected))
suppressPackageStartupMessages(library(stratapermexact))
location <- normalizePath(find.package("stratapermexact"), mustWork = TRUE)
stopifnot(identical(location, file.path(normalizePath(expected), "stratapermexact")))
stopifnot(identical(as.character(packageVersion("stratapermexact")), "0.1.0"))
stopifnot(!dir.exists("/work/source/pkg"))
fixture <- list(list(scores = c(-3L, 0L, 0L, 2L), selected = 2L),
                list(scores = c(-1L, 4L, 5L), selected = 1L))
x <- spm_distribution(fixture, 1L)
stopifnot(identical(x$status, "COMPLETE"),
          identical(x$masses$score, c(-4L, -2L, -1L, 1:7)),
          identical(x$masses$count, c("2", "1", "1", "4", "2", "1", "2", "1", "2", "2")),
          identical(x$normalizer, "18"),
          identical(x$tails$less_equal$numerator, "8"),
          identical(x$tails$less_equal$rational, "4/9"))
large <- spm_distribution(rep(list(list(scores = rep(1L, 16L), selected = 8L)), 4L))
stopifnot(identical(large$status, "COMPLETE"),
          identical(large$masses$count, "27435582641610000"))
bad <- spm_distribution(list(list(scores = 0.5, selected = 0L)))
stopifnot(identical(bad$status, "INVALID_INPUT"), identical(bad$error$code, "NONINTEGER"))
limited <- spm_distribution(fixture, budgets = list(max_cells = 0L, max_updates = 0L))
stopifnot(identical(limited$status, "UNKNOWN_BUDGET"),
          identical(limited$reason, "max_cells"), is.null(limited$masses),
          is.null(limited$normalizer), is.null(limited$tails))
cli <- system.file("exec", "stratapermexact.R", package = "stratapermexact", mustWork = TRUE)
stopifnot(startsWith(cli, paste0(location, "/")))
cat("PASS: installed independent consumer; exact goldens, large count and typed failures\n")
