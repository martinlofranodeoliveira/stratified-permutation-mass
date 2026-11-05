library(stratapermexact)

checks <- 0L
expect <- function(ok, label) {
  checks <<- checks + 1L
  tryCatch(stopifnot(isTRUE(ok)), error = function(e) {
    stop(sprintf("Assertion %d failed: %s", checks, label), call. = FALSE)
  })
}
zsum <- function(x) sum(gmp::as.bigz(x))
stratum <- function(scores, selected) list(scores = scores, selected = selected)

# Independent oracle: materialize combinations of item indices, then the
# Cartesian product of their score sums. No selected-count/score recurrence.
enumerate <- function(strata) {
  sizes <- vapply(strata, function(s) length(s$scores), integer(1))
  expect(sum(sizes) <= 16L, "enumeration item bound")
  normalizer <- gmp::as.bigz(1L)
  sums <- lapply(strata, function(s) {
    n <- length(s$scores)
    k <- s$selected
    if (k == 0L) return(0L)
    combinations <- utils::combn(seq_len(n), k, simplify = FALSE)
    vapply(combinations, function(indices) as.integer(sum(s$scores[indices])), integer(1))
  })
  for (s in strata) normalizer <- normalizer * gmp::chooseZ(length(s$scores), s$selected)
  expect(isTRUE(normalizer <= gmp::as.bigz(65536L)), "enumeration assignment bound")
  grid <- expand.grid(lapply(sums, seq_along), KEEP.OUT.ATTRS = FALSE)
  totals <- Reduce(`+`, lapply(seq_along(sums), function(i) sums[[i]][grid[[i]]]))
  scores <- sort(unique(as.integer(totals)))
  counts <- vapply(scores, function(score) {
    as.character(gmp::as.bigz(length(which(totals == score))))
  }, character(1))
  list(masses = data.frame(score = scores, count = counts, stringsAsFactors = FALSE),
       totals = totals, normalizer = as.character(normalizer))
}

compare_fixture <- function(strata, threshold = 0L) {
  oracle <- enumerate(strata)
  result <- spm_distribution(strata, threshold)
  expect(identical(result$status, "COMPLETE"), "enumerated fixture is COMPLETE")
  expect(identical(result$masses, oracle$masses), "every support point and integer mass matches combn oracle")
  expect(identical(result$normalizer, oracle$normalizer), "normalizer equals product of exact binomials")
  expect(isTRUE(zsum(result$masses$count) == gmp::as.bigz(result$normalizer)), "exact normalization")
  le <- gmp::as.bigz(length(which(oracle$totals <= threshold)))
  ge <- gmp::as.bigz(length(which(oracle$totals >= threshold)))
  expect(identical(result$tails$less_equal$numerator, as.character(le)), "inclusive lower numerator")
  expect(identical(result$tails$greater_equal$numerator, as.character(ge)), "inclusive upper numerator")
  expect(identical(result$tails$less_equal$denominator, result$normalizer), "raw tail denominator retained")
  expect(identical(result$tails$greater_equal$rational,
                   as.character(gmp::as.bigq(ge, gmp::as.bigz(result$normalizer)))), "GMP rational tail")

  shifted <- lapply(strata, function(s) stratum(s$scores + 2L, s$selected))
  translated <- spm_distribution(shifted)
  displacement <- 2L * sum(vapply(strata, function(s) as.integer(s$selected), integer(1)))
  expect(identical(translated$status, "COMPLETE"), "translation completes")
  expect(identical(translated$masses$score, result$masses$score + displacement), "score translation support identity")
  expect(identical(translated$masses$count, result$masses$count), "score translation exact count identity")
  expect(identical(translated$normalizer, result$normalizer), "translation normalizer identity")

  complements <- lapply(strata, function(s) stratum(s$scores, length(s$scores) - s$selected))
  complement <- spm_distribution(complements)
  score_total <- as.integer(sum(vapply(strata, function(s) sum(s$scores), numeric(1))))
  expect(identical(complement$status, "COMPLETE"), "complement completes")
  expect(identical(complement$masses$score, score_total - rev(result$masses$score)), "complement support identity")
  expect(identical(complement$masses$count, rev(result$masses$count)), "complement exact count identity")
  expect(identical(complement$normalizer, result$normalizer), "complement binomial identity")
  result
}

# Fixed goldens recorded from pre-source independent Python enumeration.
a <- compare_fixture(list(stratum(1:4, 2L)), 5L)
expect(identical(a$masses$score, 3:7), "first independent golden support")
expect(identical(a$masses$count, c("1", "1", "2", "1", "1")), "first independent golden masses")
expect(identical(a$normalizer, "6"), "first independent golden denominator")
expect(identical(a$tails$less_equal$rational, "2/3"), "first golden lower rational")
expect(identical(a$tails$greater_equal$rational, "2/3"), "first golden upper rational")

b <- compare_fixture(list(stratum(c(-3L, 0L, 0L, 2L), 2L),
                          stratum(c(-1L, 4L, 5L), 1L)))
expect(identical(b$masses$score, c(-4L, -2L, -1L, 1:7)), "negative repeated-score golden support")
expect(identical(b$masses$count, c("2", "1", "1", "4", "2", "1", "2", "1", "2", "2")), "negative repeated-score golden masses")
expect(identical(b$normalizer, "18"), "multiple-stratum golden normalizer")

c0 <- compare_fixture(list(stratum(rep(7L, 3L), 0L), stratum(c(-2L, 1L, 4L), 3L)), 3L)
expect(identical(c0$masses$score, 3L) && identical(c0$masses$count, "1"), "zero/full degenerate golden")
expect(identical(c0$tails$less_equal$numerator, "1") &&
         identical(c0$tails$greater_equal$numerator, "1"), "equality belongs to both inclusive tails")

d <- compare_fixture(list(stratum(-8:7, 8L)), -4L)
golden <- strsplit(paste(
  "1 1 2 3 5 7 11 15 22 28 38 48 63 77 97 116 141 164 194 221 255 284",
  "319 348 383 409 440 461 486 499 515 519 526 519 515 499 486 461 440 409",
  "383 348 319 284 255 221 194 164 141 116 97 77 63 48 38 28 22 15 11 7 5 3 2 1 1"), " ", fixed = TRUE)[[1L]]
expect(identical(d$masses$score, -36:28), "16-item golden support")
expect(identical(d$masses$count, golden), "all 65 pre-source golden masses")
expect(identical(d$normalizer, "12870"), "16-item golden denominator")

# Exhaustive small alphabet; repeated values and all count boundaries included.
patterns <- expand.grid(rep(list(-1:1), 3L), KEEP.OUT.ATTRS = FALSE)
for (i in seq_len(nrow(patterns))) {
  scores <- as.integer(unlist(patterns[i, ], use.names = FALSE))
  for (k in 0:3) invisible(compare_fixture(list(stratum(scores, k)), k - 2L))
}
for (k in 0:4) {
  invisible(compare_fixture(list(stratum(c(-5L, -5L, 1L, 3L), k),
                                  stratum(c(-2L, 0L, 4L), k %% 4L)), 1L))
}

large <- spm_distribution(rep(list(stratum(rep(1L, 16L), 8L)), 4L), 32L)
expect(identical(large$status, "COMPLETE"), "large count completes")
expect(identical(large$masses$score, 32L), "large single-mass score")
expect(identical(large$masses$count, "27435582641610000"), "large analytic mass exceeds double integer precision")
expect(identical(large$normalizer, "27435582641610000"), "large analytic normalizer")
expect(isTRUE(gmp::as.bigz(large$normalizer) > gmp::as.bigz(2L)^53L), "large count is genuinely above 2^53")
expect(identical(large$tails$less_equal$rational, "1"), "large exact rational")
for (sign in c(-1L, 1L)) {
  boundary <- spm_distribution(rep(list(stratum(rep(sign * 20L, 16L), 16L)), 4L))
  expect(identical(boundary$status, "COMPLETE"), "64-item boundary completes")
  expect(identical(boundary$masses$score, sign * 1280L), "statistic endpoint")
  expect(identical(boundary$normalizer, "1"), "full selection denominator")
}
eight <- spm_distribution(rep(list(stratum(0L, 0L)), 8L))
expect(identical(eight$status, "COMPLETE"), "eight strata allowed")

invalid <- function(value, code, field) {
  expect(identical(value$status, "INVALID_INPUT"), paste("typed invalid status", field))
  expect(identical(value$error$code, code), paste("exact input error code", field, code))
  expect(identical(value$error$field, field), paste("exact input field", field))
  expect(is.null(value$masses) && is.null(value$normalizer) && is.null(value$tails), "invalid has no mathematical result")
  expect(identical(value$work, list(updates = 0L, peak_cells = 0L)), "invalid input performs no DP work")
}
invalid(spm_distribution(), "MISSING", "strata")
invalid(spm_distribution(list()), "SIZE", "strata")
invalid(spm_distribution(TRUE), "TYPE", "strata")
invalid(spm_distribution(rep(list(stratum(0L, 0L)), 9L)), "SIZE", "strata")
invalid(spm_distribution(rep(list(stratum(rep(0L, 16L), 0L)), 5L)), "SIZE", "strata")
invalid(spm_distribution(list(stratum(integer(), 0L))), "SIZE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(rep(0L, 17L), 0L))), "SIZE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(c(1L, NA_integer_), 1L))), "MISSING", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(NaN, 0L))), "MISSING", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(Inf, 0L))), "NONFINITE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(0.5, 0L))), "NONINTEGER", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(TRUE, 0L))), "TYPE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(factor("1"), 0L))), "TYPE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(matrix(1L), 0L))), "TYPE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(21L, 0L))), "RANGE", "strata[[1]]$scores")
invalid(spm_distribution(list(stratum(1L, -1L))), "RANGE", "strata[[1]]$selected")
invalid(spm_distribution(list(stratum(1L, 2L))), "RANGE", "strata[[1]]$selected")
invalid(spm_distribution(list(stratum(1L, 0.1))), "NONINTEGER", "strata[[1]]$selected")
invalid(spm_distribution(list(stratum(1L, NA))), "TYPE", "strata[[1]]$selected")
invalid(spm_distribution(list(stratum(1L, NA_integer_))), "MISSING", "strata[[1]]$selected")
invalid(spm_distribution(list(list(scores = 1L))), "SCHEMA", "strata[[1]]")
invalid(spm_distribution(list(list(scores = 1L, scores = 0L))), "SCHEMA", "strata[[1]]")
invalid(spm_distribution(list(list(scores = 1L, selected = 0L, extra = 1L))), "SCHEMA", "strata[[1]]")
fixture <- list(stratum(1L, 1L))
invalid(spm_distribution(fixture, threshold = 0.2), "NONINTEGER", "threshold")
invalid(spm_distribution(fixture, threshold = NA_real_), "MISSING", "threshold")
invalid(spm_distribution(fixture, threshold = TRUE), "TYPE", "threshold")
invalid(spm_distribution(fixture, threshold = 2147483648), "RANGE", "threshold")
invalid(spm_distribution(fixture, budgets = list(max_cells = 65537L, max_updates = 1L)), "RANGE", "budgets$max_cells")
invalid(spm_distribution(fixture, budgets = list(max_cells = 10L, max_updates = 5000001L)), "RANGE", "budgets$max_updates")
invalid(spm_distribution(fixture, budgets = list(max_cells = 10L, max_updates = FALSE)), "TYPE", "budgets$max_updates")
invalid(spm_distribution(fixture, budgets = list(max_cells = 1.5, max_updates = 2L)), "NONINTEGER", "budgets$max_cells")
invalid(spm_distribution(fixture, budgets = list(max_cells = 1L)), "SCHEMA", "budgets")
invalid(spm_distribution(list(stratum(NA_integer_, 0L)),
                         budgets = list(max_cells = 0L, max_updates = 0L)),
        "MISSING", "strata[[1]]$scores")

unknown <- function(result, reason) {
  expect(identical(result$status, "UNKNOWN_BUDGET"), "typed budget outcome, not an arbitrary failure")
  expect(identical(result$reason, reason), "exact budget failure type")
  expect(is.null(result$error), "budget is not invalid input")
  expect(is.null(result$masses) && is.null(result$normalizer) && is.null(result$tails), "no partial normalized result")
}
unknown(spm_distribution(fixture, budgets = list(max_cells = 0L, max_updates = 0L)), "max_cells")
unknown(spm_distribution(fixture, budgets = list(max_cells = 5L, max_updates = 0L)), "max_updates")
cell_limited <- spm_distribution(fixture, budgets = list(max_cells = 4L, max_updates = 2L))
unknown(cell_limited, "max_cells")
expect(identical(cell_limited$work$updates, 0L), "failed insertion does not commit update")
expect(identical(cell_limited$work$peak_cells, 4L), "old, global and scratch cells counted before staging")
unknown(spm_distribution(fixture, budgets = list(max_cells = 5L, max_updates = 1L)), "max_updates")
exact_budget <- spm_distribution(fixture, budgets = list(max_cells = 5L, max_updates = 2L))
expect(identical(exact_budget$status, "COMPLETE"), "exact resource boundary succeeds")
expect(identical(exact_budget$work, list(updates = 2L, peak_cells = 5L)), "specified resource accounting")
unknown(spm_distribution(rep(fixture, 2L), budgets = list(max_cells = 20L, max_updates = 3L)), "max_updates")

below <- spm_distribution(list(stratum(1:4, 2L)), -2147483647)
above <- spm_distribution(list(stratum(1:4, 2L)), 2147483647)
expect(identical(below$tails$less_equal$numerator, "0"), "far lower threshold")
expect(identical(above$tails$greater_equal$numerator, "0"), "far upper threshold")
expect(identical(above$tails$less_equal$rational, "1"), "far upper lower-tail rational")
expect(is.null(spm_distribution(fixture)$tails), "NULL threshold omits tails")
expect(identical(spm_distribution(list(stratum(c(a = 1, b = 2), 1)))$status, "COMPLETE"), "plain named numeric vectors accepted")

owned <- list(stratum(c(-2L, 1L, 1L), 1L))
input_bytes <- serialize(owned, NULL)
previous <- spm_distribution(owned)
previous_bytes <- serialize(previous, NULL)
invisible(spm_distribution(owned, budgets = list(max_cells = 0L, max_updates = 0L)))
invisible(spm_distribution(owned, 1L))
expect(identical(serialize(owned, NULL), input_bytes), "caller input is not mutated")
expect(identical(serialize(previous, NULL), previous_bytes), "previous result is not mutated")
owned[[1L]]$scores[[1L]] <- 20L
expect(identical(serialize(previous, NULL), previous_bytes), "result does not alias caller input")
expect(any(grepl("COMPLETE", capture.output(print(previous)), fixed = TRUE)), "human-readable complete output")
cat(sprintf("PASS: %d exact, oracle, identity, boundary and adversarial assertions\n", checks))
