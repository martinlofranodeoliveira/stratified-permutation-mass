stopifnot(identical(as.character(getRversion()), "4.5.0"))
stopifnot(identical(normalizePath(find.package("gmp")), "/opt/r-qualified/gmp"))
stopifnot(identical(normalizePath(find.package("renv")), "/opt/r-qualified/renv"))
stopifnot(identical(packageDescription("gmp")$Version, "0.7-5"))
stopifnot(identical(packageDescription("renv")$Version, "1.1.2"))
lock_path <- "/work/source/qualification/renv.lock"
before <- readBin(lock_path, "raw", n = file.info(lock_path)$size)
lock <- renv::lockfile_read(lock_path)
stopifnot(identical(lock$R$Version, "4.5.0"),
          identical(lock$Packages$gmp$Version, "0.7-5"),
          identical(lock$Packages$renv$Version, "1.1.2"))
# Native API checks are separate from mathematical negative tests.
z <- gmp::as.bigz(c("9007199254740993", "2"))
z[2L] <- z[1L] + z[2L]
stopifnot(identical(as.character(z[2L]), "9007199254740995"),
          identical(as.character(z[1L] * gmp::as.bigz(3L)), "27021597764222979"),
          identical(as.character(gmp::as.bigq(gmp::as.bigz(4L), gmp::as.bigz(6L))), "2/3"),
          identical(as.character(gmp::chooseZ(64L, 32L)), "1832624140942590534"))
stopifnot(identical(before, readBin(lock_path, "raw", n = file.info(lock_path)$size)))
cat("PASS: unchanged qualified lock, installed identities and native exact APIs\n")
