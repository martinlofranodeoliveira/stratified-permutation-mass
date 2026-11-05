args <- commandArgs(trailingOnly = TRUE)
valid <- identical(args, c("demo", "--assert")) ||
  identical(args, c("demo", "--assert", "--tsv"))
if (!valid) {
  cat("Usage: Rscript stratapermexact.R demo --assert [--tsv]\n", file = stderr())
  quit(save = "no", status = 2L)
}
suppressPackageStartupMessages(library(stratapermexact))
result <- spm_distribution(list(list(scores = 1:4, selected = 2L)), threshold = 5L)
stopifnot(identical(result$status, "COMPLETE"),
          identical(result$masses$score, 3:7),
          identical(result$masses$count, c("1", "1", "2", "1", "1")),
          identical(result$normalizer, "6"),
          identical(result$tails$less_equal$numerator, "4"),
          identical(result$tails$greater_equal$numerator, "4"),
          identical(result$tails$less_equal$rational, "2/3"),
          identical(result$tails$greater_equal$rational, "2/3"))
if ("--tsv" %in% args) {
  lines <- c("SPM-DEMO\t1", "status\tCOMPLETE",
             paste("mass", result$masses$score, result$masses$count, sep = "\t"),
             "normalizer\t6", "tail_le\t5\t4\t6\t2/3",
             "tail_ge\t5\t4\t6\t2/3", "assertions\tPASS", "END\t5")
} else {
  lines <- c("Stratified Permutation Mass 0.1.0 (development)",
             "status: COMPLETE", "score count",
             paste(result$masses$score, result$masses$count),
             "normalizer: 6", "score <= 5: 4/6 (2/3)",
             "score >= 5: 4/6 (2/3)", "assertions: PASS")
}
cat(paste0(paste(lines, collapse = "\n"), "\n"))
