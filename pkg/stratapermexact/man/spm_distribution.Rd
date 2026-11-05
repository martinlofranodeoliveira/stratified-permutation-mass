\name{spm_distribution}
\alias{spm_distribution}
\alias{print.spm_result}
\title{Exact Bounded Stratified Assignment Masses}
\description{
Development version 0.1.0. Counts uniformly weighted assignments of selected
labels to distinct item positions while preserving each stratum count.
No experimental conclusion or significance recommendation is produced.
}
\usage{
spm_distribution(strata = NULL, threshold = NULL,
  budgets = list(max_cells = 65536L, max_updates = 5000000L))

\method{print}{spm_result}(x, ...)
}
\arguments{
  \item{strata}{An unclassed list of one through eight strata, containing one
  through 64 total items. Each stratum is an unclassed list with exactly the
  named fields \code{scores} and \code{selected}. Scores are an unclassed
  integer or double vector of length one through 16, integral and in
  [-20, 20]. Selected is one integral numeric value in [0, length(scores)].}
  \item{threshold}{NULL, or one integral numeric value in
  [-2147483647, 2147483647]. Both returned tails include equality.}
  \item{budgets}{An unclassed list with exactly \code{max_cells} and
  \code{max_updates}, integral numeric scalars in [0, 65536] and
  [0, 5000000], respectively. Zero is valid and generally exhausts work.}
  \item{x}{A result returned by \code{spm_distribution}.}
  \item{...}{Reserved print arguments; ignored.}
}
\details{
Names on otherwise plain input vectors and outer lists are allowed and
ignored. Other attributes, classes, logical vectors, factors, arrays and
S4 objects are not accepted. Inputs are not coerced from text or logicals.
Validation precedes all dynamic programming. NA and NaN are missing;
infinity is nonfinite; fractional finite values are noninteger.

Original sparse selected-count/score dynamic programming uses two layers
per item and exact convolution across strata. Every populated coefficient
binding in all retained input and staging tables counts as one live cell.
Two additional arithmetic scratch cells are reserved throughout calculation.
Each retained skip/take contribution and each convolution pair contributes
one update. Seeds, validation, binomial normalizers and output reductions
are not updates. Checks precede arithmetic updates and cell insertion.
These are logical work bounds, not hard byte or elapsed-time limits.

Counts are decimal strings, not doubles. Use \code{gmp::as.bigz} for exact
integer conversion. Tails contain raw numerator and normalizer denominator
strings plus \code{rational}, the canonical exact \code{gmp::as.bigq} string.
No floating-point probabilities are calculated.
}
\value{
An S3 \code{spm_result} list with fields \code{schema}, \code{status},
\code{error}, \code{reason}, \code{masses}, \code{normalizer}, \code{tails}
and \code{work}. Schema is \code{stratapermexact/1}.

\code{COMPLETE} has a data frame of ascending reachable integer
\code{score} and positive decimal \code{count}, an exact decimal
\code{normalizer}, and optional tails. A tail query has \code{threshold},
\code{less_equal} and \code{greater_equal}; each tail has \code{numerator},
\code{denominator} and \code{rational}. Error and reason are NULL.

\code{INVALID_INPUT} has an error list with \code{code}, \code{field}, and
\code{message}; work is zero. Codes are TYPE, SIZE, SCHEMA, MISSING,
NONFINITE, NONINTEGER and RANGE. Diagnostic fields identify the first
failure in validation order. Mathematical fields and reason are NULL.

\code{UNKNOWN_BUDGET} has reason \code{max_cells} or \code{max_updates};
error and all mathematical fields are NULL. No partial distribution or
normalizer is exposed. Work always contains integer \code{updates} and
\code{peak_cells}. Unexpected dependency, allocation or internal errors
raise ordinary R errors and are not reclassified as input or budget results.
}
\examples{
strata <- list(list(scores = 1:4, selected = 2L))
x <- spm_distribution(strata, threshold = 5L)
print(x)
stopifnot(x$status == "COMPLETE", x$normalizer == "6")
gmp::as.bigz(x$masses$count)
spm_distribution(strata, budgets = list(max_cells = 0L, max_updates = 0L))
spm_distribution(list(list(scores = 0.5, selected = 0L)))
}
\seealso{\code{gmp::as.bigz}, \code{gmp::as.bigq}}
\keyword{distribution}
