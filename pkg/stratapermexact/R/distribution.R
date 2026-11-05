.spm_plain <- function(x, types) {
  typeof(x) %in% types && !is.object(x) && !isS4(x) &&
    all(names(attributes(x)) %in% "names")
}

.spm_invalid <- function(code, field, message) {
  stop(structure(list(message = message, call = NULL, code = code, field = field),
                 class = c("spm_invalid", "error", "condition")))
}

.spm_fields <- function(x, required, field) {
  if (!.spm_plain(x, "list")) {
    .spm_invalid("TYPE", field, "Expected an unclassed list.")
  }
  if (length(x) != length(required) || is.null(names(x)) ||
      anyNA(names(x)) || anyDuplicated(names(x)) ||
      !setequal(names(x), required)) {
    .spm_invalid("SCHEMA", field, "Named fields must match the documented schema exactly.")
  }
}

.spm_integer <- function(x, field, minimum, maximum, size = 1L) {
  if (!.spm_plain(x, c("integer", "double")) ||
      !methods::is(x, "numeric")) {
    .spm_invalid("TYPE", field, "Expected an unclassed integer or double vector.")
  }
  if (length(x) < 1L || length(x) > size) {
    .spm_invalid("SIZE", field, "Vector length is outside its permitted bounds.")
  }
  if (anyNA(x)) .spm_invalid("MISSING", field, "NA and NaN are not permitted.")
  if (any(!is.finite(x))) .spm_invalid("NONFINITE", field, "Infinite values are not permitted.")
  if (any(x != trunc(x))) .spm_invalid("NONINTEGER", field, "Every value must be integral.")
  if (any(x < minimum | x > maximum)) {
    .spm_invalid("RANGE", field, "A value is outside its permitted bounds.")
  }
  unname(as.integer(x))
}

.spm_validate <- function(strata, threshold, budgets) {
  if (is.null(strata)) .spm_invalid("MISSING", "strata", "Strata must be supplied.")
  if (!.spm_plain(strata, "list")) {
    .spm_invalid("TYPE", "strata", "Expected an unclassed list of strata.")
  }
  if (length(strata) < 1L || length(strata) > 8L) {
    .spm_invalid("SIZE", "strata", "There must be one through eight strata.")
  }
  clean <- vector("list", length(strata))
  total <- 0L
  for (i in seq_along(strata)) {
    field <- sprintf("strata[[%d]]", i)
    .spm_fields(strata[[i]], c("scores", "selected"), field)
    scores <- .spm_integer(strata[[i]]$scores, paste0(field, "$scores"), -20L, 20L, 16L)
    selected <- .spm_integer(strata[[i]]$selected, paste0(field, "$selected"),
                             0L, length(scores))
    total <- total + length(scores)
    if (total > 64L) .spm_invalid("SIZE", "strata", "Total item count must not exceed 64.")
    clean[[i]] <- list(scores = scores, selected = selected)
  }
  if (!is.null(threshold)) {
    threshold <- .spm_integer(threshold, "threshold", -2147483647, 2147483647)
  }
  .spm_fields(budgets, c("max_cells", "max_updates"), "budgets")
  cells <- .spm_integer(budgets$max_cells, "budgets$max_cells", 0L, 65536L)
  updates <- .spm_integer(budgets$max_updates, "budgets$max_updates", 0L, 5000000L)
  list(strata = clean, threshold = threshold,
       budgets = list(max_cells = cells, max_updates = updates))
}

.spm_result <- function(status, error = NULL, reason = NULL, masses = NULL,
                        normalizer = NULL, tails = NULL,
                        work = list(updates = 0L, peak_cells = 0L)) {
  structure(list(schema = "stratapermexact/1", status = status, error = error,
                 reason = reason, masses = masses, normalizer = normalizer,
                 tails = tails, work = work), class = "spm_result")
}

# Every map binding is a coefficient cell. Two additional cells are reserved
# throughout the calculation for the product and addition temporaries.
.spm_calculate <- function(input) {
  state <- new.env(parent = emptyenv())
  state$live <- 0L
  state$peak <- 0L
  state$updates <- 0L
  budget <- input$budgets
  exhausted <- function(reason) {
    stop(structure(list(message = reason, call = NULL, reason = reason),
                   class = c("spm_budget", "error", "condition")))
  }
  reserve <- function(n) {
    if (n > budget$max_cells - state$live) exhausted("max_cells")
    state$live <- state$live + n
    state$peak <- max(state$peak, state$live)
    invisible(NULL)
  }
  newmap <- function() new.env(hash = TRUE, parent = emptyenv(), size = 29L)
  keys <- function(map) sort(as.integer(ls(map, all.names = TRUE)))
  discard <- function(map) {
    labels <- ls(map, all.names = TRUE)
    rm(list = labels, envir = map)
    state$live <- state$live - length(labels)
    invisible(NULL)
  }
  seed <- function(map) {
    reserve(1L)
    assign("0", gmp::as.bigz(1L), envir = map)
  }
  add <- function(map, score, value) {
    # Check work BEFORE arithmetic or insertion. A failed reservation commits
    # neither an update nor a new coefficient binding.
    if (state$updates >= budget$max_updates) exhausted("max_updates")
    label <- as.character(score)
    present <- exists(label, envir = map, inherits = FALSE)
    if (!present) reserve(1L)
    if (present) value <- get(label, envir = map, inherits = FALSE) + value
    assign(label, value, envir = map)
    state$updates <- state$updates + 1L
    invisible(NULL)
  }
  work <- function() list(updates = state$updates, peak_cells = state$peak)

  tryCatch({
    reserve(2L)
    combined <- newmap()
    seed(combined)
    normalizer <- gmp::as.bigz(1L)

    for (stratum in input$strata) {
      scores <- stratum$scores
      n <- length(scores)
      k <- stratum$selected
      normalizer <- normalizer * gmp::chooseZ(n, k)
      rows <- lapply(seq_len(k + 1L), function(unused) newmap())
      seed(rows[[1L]])

      for (i in seq_len(n)) {
        staged <- lapply(seq_len(k + 1L), function(unused) newmap())
        remaining <- n - i
        for (j in seq.int(0L, k)) {
          for (score in keys(rows[[j + 1L]])) {
            coefficient <- get(as.character(score), envir = rows[[j + 1L]], inherits = FALSE)
            if (j + remaining >= k) {
              add(staged[[j + 1L]], score, coefficient)
            }
            if (j < k && j + 1L + remaining >= k) {
              add(staged[[j + 2L]], score + scores[[i]], coefficient)
            }
          }
        }
        for (row in rows) discard(row)
        rows <- staged
      }
      # Feasibility pruning leaves only the selected-count row populated.
      local_mass <- rows[[k + 1L]]
      rows <- NULL
      staged <- NULL
      convolved <- newmap()
      local_scores <- keys(local_mass)
      for (a in keys(combined)) {
        for (b in local_scores) {
          # R promises defer the product until add has checked both budgets.
          add(convolved, a + b,
              get(as.character(a), envir = combined, inherits = FALSE) *
                get(as.character(b), envir = local_mass, inherits = FALSE))
        }
      }
      discard(combined)
      discard(local_mass)
      combined <- convolved
    }

    support <- keys(combined)
    counts <- character(length(support))
    total <- gmp::as.bigz(0L)
    lower <- gmp::as.bigz(0L)
    upper <- gmp::as.bigz(0L)
    for (i in seq_along(support)) {
      value <- get(as.character(support[[i]]), envir = combined, inherits = FALSE)
      counts[[i]] <- as.character(value)
      total <- total + value
      if (!is.null(input$threshold)) {
        if (support[[i]] <= input$threshold) lower <- lower + value
        if (support[[i]] >= input$threshold) upper <- upper + value
      }
    }
    if (!isTRUE(total == normalizer) || length(support) > 2561L ||
        any(support < -1280L | support > 1280L) ||
        !isTRUE(normalizer <= gmp::as.bigz(2L)^64L)) {
      stop("Internal distribution invariant failed; no result is available.", call. = FALSE)
    }
    fraction <- function(numerator) {
      list(numerator = as.character(numerator), denominator = as.character(normalizer),
           rational = as.character(gmp::as.bigq(numerator, normalizer)))
    }
    tails <- if (is.null(input$threshold)) NULL else
      list(threshold = input$threshold, less_equal = fraction(lower),
           greater_equal = fraction(upper))
    answer <- .spm_result("COMPLETE",
                          masses = data.frame(score = support, count = counts,
                                              stringsAsFactors = FALSE),
                          normalizer = as.character(normalizer), tails = tails,
                          work = work())
    discard(combined)
    answer
  }, spm_budget = function(e) {
    .spm_result("UNKNOWN_BUDGET", reason = e$reason, work = work())
  })
}

#' Exact bounded stratified assignment masses
#'
#' See the installed help page and docs/contract.md for the complete schema.
#' Counts are returned as decimal strings, never floating-point probabilities.
spm_distribution <- function(strata = NULL, threshold = NULL,
                             budgets = list(max_cells = 65536L,
                                            max_updates = 5000000L)) {
  input <- tryCatch(.spm_validate(strata, threshold, budgets),
                    spm_invalid = function(e) e)
  if (inherits(input, "spm_invalid")) {
    return(.spm_result("INVALID_INPUT",
                       error = list(code = input$code, field = input$field,
                                    message = input$message)))
  }
  .spm_calculate(input)
}

print.spm_result <- function(x, ...) {
  cat("Stratified Permutation Mass: ", x$status, "\n", sep = "")
  if (identical(x$status, "COMPLETE")) {
    print(x$masses, row.names = FALSE)
    cat("normalizer: ", x$normalizer, "\n", sep = "")
    if (!is.null(x$tails)) {
      for (name in c("less_equal", "greater_equal")) {
        tail <- x$tails[[name]]
        cat(name, " at ", x$tails$threshold, ": ", tail$numerator, "/",
            tail$denominator, " (", tail$rational, ")\n", sep = "")
      }
    }
  } else if (identical(x$status, "INVALID_INPUT")) {
    cat(x$error$code, " at ", x$error$field, ": ", x$error$message, "\n", sep = "")
  } else {
    cat("limit: ", x$reason, "; no distribution returned\n", sep = "")
  }
  invisible(x)
}
