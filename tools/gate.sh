#!/bin/sh
set -eu
umask 077
cd /work/source
export HOME=/work/home
export R_LIBS_SITE=/opt/r-qualified
export R_LIBS_USER=/work/private-library
export R_ENVIRON_USER=/work/empty-environ
export R_PROFILE_USER=/work/offline-profile.R
export _R_CHECK_CRAN_INCOMING_REMOTE_=false
export _R_CHECK_FORCE_SUGGESTS_=false
mkdir -p /work/home /work/private-library /work/build /work/independent
: > /work/empty-environ
printf '%s\n' 'options(repos=c(CRAN="file:///opt/qualified-r-repo"))' > /work/offline-profile.R
test -s qualification/renv.lock
test -s qualification/dependencies.sha256
test -s qualification/native-packages.tsv
# These are verification inputs, never synthesized by this gate.
grep -Fq '  /work/source/qualification/renv.lock' qualification/dependencies.sha256
grep -Fq '  /opt/qualified-r-repo/src/contrib/gmp_0.7-5.tar.gz' qualification/dependencies.sha256
grep -Fq '  /opt/qualified-r-repo/src/contrib/renv_1.1.2.tar.gz' qualification/dependencies.sha256
sha256sum --check --strict qualification/dependencies.sha256
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' > /work/build/native-current.tsv
cmp qualification/native-packages.tsv /work/build/native-current.tsv
Rscript --vanilla tools/verify-dependencies.R

test ! -e /work/build/stratapermexact_0.1.0.tar.gz
cp -R pkg/stratapermexact /work/build/stratapermexact
cd /work/build
R CMD build stratapermexact
R CMD check --no-manual stratapermexact_0.1.0.tar.gz
Rscript --vanilla -e 'x <- readLines("stratapermexact.Rcheck/00check.log", warn=FALSE); stopifnot(sum(x == "Status: OK") == 1L, !any(grepl("WARNING|NOTE|ERROR", x))); cat("PASS: strict R CMD check log\n")'

# Inspect the archive before extraction. Only owned, cooperative filesystems
# are supported; this is not an extractor for arbitrary third-party archives.
Rscript --vanilla - <<'RS'
archive <- "stratapermexact_0.1.0.tar.gz"
entries <- utils::untar(archive, list = TRUE)
stopifnot(length(entries) < 128L, !anyDuplicated(entries),
          all(startsWith(entries, "stratapermexact/")),
          !any(grepl("(^|/)\\.\\.(/|$)", entries)),
          !any(grepl("\\\\", entries)))
dir.create("inspection")
utils::untar(archive, exdir = "inspection")
original <- "/work/source/pkg/stratapermexact"
packaged <- "/work/build/inspection/stratapermexact"
files <- list.files(original, recursive = TRUE, all.files = TRUE, no.. = TRUE)
actual <- list.files(packaged, recursive = TRUE, all.files = TRUE, no.. = TRUE)
stopifnot(setequal(files, setdiff(actual, "MD5")))
hash <- function(path) {
  text <- system2("sha256sum", shQuote(path), stdout = TRUE)
  stopifnot(is.null(attr(text, "status")), length(text) == 1L)
  substr(text, 1L, 64L)
}
for (file in setdiff(files, "DESCRIPTION")) {
  a <- hash(file.path(original, file))
  b <- hash(file.path(packaged, file))
  stopifnot(identical(a, b))
  cat(a, "  ", file, "\n", sep = "")
}
a <- read.dcf(file.path(original, "DESCRIPTION"))
b <- read.dcf(file.path(packaged, "DESCRIPTION"))
generated <- c("Packaged", "Author", "Maintainer")
stopifnot(setequal(colnames(a), setdiff(colnames(b), generated)))
for (name in colnames(a)) stopifnot(identical(a[1L, name], b[1L, name]))
if ("MD5" %in% actual) stopifnot(isTRUE(tools::checkMD5sums(dir = packaged)))
cat("Generated content: DESCRIPTION build fields; optional MD5 inventory\n")
cat("Packaged DESCRIPTION SHA256: ", hash(file.path(packaged, "DESCRIPTION")), "\n", sep = "")
cat("PASS: archive inventory and original per-file SHA256 equality\n")
RS
sha256sum stratapermexact_0.1.0.tar.gz > source-package.sha256
R CMD INSTALL --library=/work/private-library stratapermexact_0.1.0.tar.gz
# Rerun installed tests from outside the package checkout. R CMD check already
# ran the same tests against its own installed copy.
cd /work/independent
Rscript --vanilla /work/source/pkg/stratapermexact/tests/regression.R
Rscript --vanilla /work/private-library/stratapermexact/exec/stratapermexact.R demo --assert
Rscript --vanilla /work/private-library/stratapermexact/exec/stratapermexact.R demo --assert --tsv
printf '%s\n' 'COMPLETE: build, strict check, archive verification, fresh installation and installed tests/demo'
