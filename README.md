# Stratified Permutation Mass

**Development version 0.1.0** — an original bounded exact-combinatorics R library by [Lofrano Tecnologia](https://lofranotecnologia.com.br).

Given integer scores and a selected count in each fixed stratum, compute the exact distribution of the sum of selected scores. Assignments are uniformly weighted over distinct item positions, including positions with identical scores. An original selected-count/score dynamic program builds each stratum distribution; exact convolution combines them. The maintained **gmp** package supplies arbitrary-precision integer and rational arithmetic. This is not a wrapper around a statistical test.

Repository: https://github.com/martinlofranodeoliveira/stratified-permutation-mass

## Bounds and results

- 1–8 strata, 1–16 items per stratum, 1–64 items overall.
- Integral scores in −20…20; each selected count is 0…stratum size.
- At most 65,536 live coefficient/scratch cells and 5,000,000 contribution updates. Callers may lower, but not raise, these ceilings.
- Ascending reachable scores only, at most 2,561 rows in −1280…1280.
- Exact counts are **decimal strings**, bounded by 2^64, never double probabilities.
- `COMPLETE`: all masses, exact normalizer and requested inclusive tails.
- `UNKNOWN_BUDGET`: reason and work counters only; no partial distribution, normalizer or tails.
- `INVALID_INPUT`: typed diagnostic code and field; no calculation.

See [the precise contract](docs/contract.md), [design](docs/design.md), and installed `?spm_distribution`. Logical work limits do not promise a hard memory or wall-clock bound. R is not an adversarial-code sandbox.

## Install and test

The source package is **nested**, at `pkg/stratapermexact`. R 4.5.0 or later and the maintained CRAN `gmp` package are required. The reproducible gate uses the qualified R 4.5.0 / GNU GMP 6.3.0 / gmp 0.7-5 closure. `renv` 1.1.2 is build tooling only.

With the qualified offline library already available:

```sh
export R_LIBS_SITE=/opt/r-qualified
mkdir -p build
R CMD build pkg/stratapermexact
R CMD check --no-manual stratapermexact_0.1.0.tar.gz
lib="$(mktemp -d)"
R CMD INSTALL --library="$lib" stratapermexact_0.1.0.tar.gz
R_LIBS_USER="$lib" Rscript --vanilla pkg/stratapermexact/tests/regression.R
R_LIBS_USER="$lib" Rscript --vanilla pkg/stratapermexact/exec/stratapermexact.R demo --assert
R_LIBS_USER="$lib" Rscript --vanilla pkg/stratapermexact/exec/stratapermexact.R demo --assert --tsv
```

The installed CLI has no source fallback. Its installed location can be obtained with `system.file("exec", "stratapermexact.R", package="stratapermexact", mustWork=TRUE)`.

A direct development check is `R CMD check --no-manual pkg/stratapermexact`. For acceptance, use the full source-package gate, which requires **exactly `Status: OK` and no WARNING, NOTE or ERROR**, not merely exit zero. Tests use only base R plus gmp, with independent `utils::combn` enumeration and counted assertions. No testthat or jsonlite is needed.

## Isolated reproducible gate

[Dependency evidence](docs/dependencies.md) defines the genuine lock and manifest inputs. Missing evidence is a gate failure; ordinary tests never generate or replace it. Docker preparation may download only official Debian/CRAN artifacts. Test containers are offline.

```sh
docker build --target test --tag spm-check .
docker run --name spm-check-evidence --network none --user 1000:1000 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 256 \
  --memory 1g --cpus 2 spm-check
mkdir -p build
docker cp spm-check-evidence:/work/build/stratapermexact_0.1.0.tar.gz build/
docker cp spm-check-evidence:/work/build/source-package.sha256 build/
sha256sum --check --strict build/source-package.sha256
docker build --target runtime --tag spm-runtime .
consumer="$(cat tools/consumer.R)"
docker run --network none --user 1000:1000 --cap-drop ALL \
  --security-opt no-new-privileges --pids-limit 256 --memory 1g --cpus 2 \
  --env SPM_EXPECT_LIBRARY=/opt/spm-library --entrypoint Rscript \
  spm-runtime --vanilla -e "$consumer"
docker run --network none --user 1000:1000 --cap-drop ALL \
  --security-opt no-new-privileges --pids-limit 256 --memory 1g --cpus 2 \
  spm-runtime demo --assert
```

The final runtime contains installed R libraries, not the package checkout or a compiler. Fresh container identities and directories are required for repeated gates. CI is read-only, has a 30-minute outer timeout, records runner/source identity and command logs, and does not publish anything. An interrupted or timed-out gate is **INCOMPLETE**, not an input rejection or verified mathematical result. Commands and tests here are procedures, not claims of execution on a particular machine.

## R usage

```r
library(stratapermexact)
x <- spm_distribution(list(list(scores = 1:4, selected = 2L)), threshold = 5L)
stopifnot(x$status == "COMPLETE")
x$masses
#   score count
# 1     3     1
# 2     4     1
# 3     5     2
# 4     6     1
# 5     7     1
x$tails$less_equal
# $numerator
# [1] "4"
# $denominator
# [1] "6"
# $rational
# [1] "2/3"
exact_counts <- gmp::as.bigz(x$masses$count)
limited <- spm_distribution(list(list(scores = 1:4, selected = 2L)),
  budgets = list(max_cells = 0L, max_updates = 0L))
stopifnot(limited$status == "UNKNOWN_BUDGET", is.null(limited$masses))
bad <- spm_distribution(list(list(scores = 0.5, selected = 0L)))
stopifnot(bad$status == "INVALID_INPUT", bad$error$code == "NONINTEGER")
```

`print(x)` is human-readable. Application code should branch on `status`, not parse printed text. Input objects and previous results are not mutated.

## Deterministic asserting demo

Expected text output:

```text
Stratified Permutation Mass 0.1.0 (development)
status: COMPLETE
score count
3 1
4 1
5 2
6 1
7 1
normalizer: 6
score <= 5: 4/6 (2/3)
score >= 5: 4/6 (2/3)
assertions: PASS
```

`--tsv` emits the documented `SPM-DEMO` frame, five `mass` records and terminal `END\t5`. Consumers must require the full frame and successful exit; stdout can be truncated by I/O failure. The CLI accepts only this fixed synthetic demo and no files, endpoints or executable names.

## Rationale and limitations

Sparse two-layer DP counts positions without enumerating all assignments. Staging is included in the cell budget, and every contribution is checked before committing. Exact strings avoid accidental double rounding, including the analytic four-stratum fixture whose count is `27435582641610000` at score 32.

There are no continuous scores, weights, automatic strata, Monte Carlo approximation, covariate adjustment, personal records, telemetry, model/API dependencies, GUI or server. Exact combinatorics does not establish that a real experiment used this mechanism. No significance, medical, causal, legal or financial recommendation is produced. No broad statistical-standard compliance, performance, deployment or production-readiness claim is made.

Original code is MIT, copyright 2026 Lofrano Tecnologia. R, GNU GMP, gmp, renv and native components retain their own licenses; MIT does not relabel that closure. See [third-party boundaries](THIRD_PARTY.md). General contact is the [official homepage](https://lofranotecnologia.com.br); security reporting uses [GitHub private vulnerability reporting](https://github.com/martinlofranodeoliveira/stratified-permutation-mass/security/advisories/new).
