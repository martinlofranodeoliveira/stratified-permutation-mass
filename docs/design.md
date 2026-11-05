# Design

## Original counting algorithm

For one stratum, let D[i,j,s] count assignments selecting j positions among the first i items with sum s. The initial state is D[0,0,0] = 1. Each old state contributes once to a skip state and, if selection remains possible, once to a take state with score increased by the current score. States that cannot reach the required final count with remaining items are discarded. Two layers ensure an item cannot be selected twice. Equal score values merge counts without merging item identities.

The implementation uses a list of sparse environments, one per selected count. Keys are bounded integer scores rendered as strings; values are scalar `gmp` integers. Environments are private, never returned. Keys are explicitly sorted numerically before traversal. This avoids dependence on hash iteration order. No statistical-distribution routine implements the recurrence.

After a stratum is complete, its required-count row is convolved with the accumulated distribution. For every score pair, the product of the two exact coefficients is added at their score sum. Independence here means Cartesian-product counting of supplied stratum choices, not a substantive assumption about real experiments.

All coefficient, normalizer, normalization-check and tail arithmetic uses gmp integers. Rational reduction belongs to gmp. Native integer arithmetic is used only for bounded scores, sizes, indices and work counters. Decimal output is an intentional interoperability boundary: an R data frame containing doubles would silently lose large counts.

## Resource design

The global distribution stays charged while local DP is built. Both old and staged layers stay charged until old bindings are removed. During convolution, both input distributions and the destination are charged. A new binding is reserved before insertion. Two scratch coefficient cells cover product/addition temporaries. Existing scalar references do not create additional table bindings.

Map bindings are explicitly cleared at retirement; discarded layers are not retained as histories. R/GMP allocation and garbage collection still have overhead outside the logical accounting. There is no internal timer, native allocation interceptor, asynchronous worker, subprocess, endpoint input or runtime compiler. Container limits and outer deadlines provide independent containment, not a universal memory/time promise.

Normalizers and final reductions involve only bounded input/output sizes and are excluded from the update metric. The exact scope of every counter is part of [the contract](contract.md), so a custom budget is reproducible rather than an undocumented heuristic.

## Failure/publication boundary

Validation constructs normalized private input before counting. Typed input conditions are caught only by the validator boundary. Budget conditions are caught only by the calculation boundary. Other errors propagate and cannot masquerade as a mathematical negative.

Only after full convolution and exact normalization does the calculation construct a COMPLETE value. Budget outcomes contain no masses or normalizer. Returning fresh ordinary lists/data frames avoids exposing mutable map references. Nothing writes application state to disk. The fixed CLI computes and asserts before printing; successful exit and full framing remain mandatory because stdout can fail partway through.

## Tests that do not repeat the implementation

- `utils::combn` enumerates actual item-index subsets. An explicit Cartesian product enumerates total scores for fixtures of at most 16 items and 65536 assignments. Every score and mass is compared, not just moments or a selected tail.
- Static independent Python-enumeration goldens cover simple, repeated/negative, zero/full and 16-item fixtures.
- Translation shifts support by the selected-count-weighted constant while preserving counts. Complement selection reflects scores around the total supplied score and preserves exact counts.
- Exact normalizers are products of gmp binomials. A separate analytic repeated-score fixture requires `27435582641610000`, beyond 2^53.
- Tests assert exact INVALID_INPUT codes/fields and exact UNKNOWN_BUDGET reasons. A dependency error, process exit, crash, timeout or missing oracle cannot satisfy these checks.
- Exact five-cell/two-update boundary tests exercise staging and precommit accounting. A later-stratum convolution limit tests all-or-nothing publication.
- Serialization checks detect mutation of input and previous results.

## Package and evidence boundary

The native package is nested to keep infrastructure out of the distributed R source package. The gate builds a tarball, checks it strictly, inspects its inventory, compares per-file SHA256 hashes, recognizes generated DESCRIPTION/optional MD5 content, installs into a fresh private library and invokes the installed CLI. A second runtime stage installs only the checked tarball and contains neither checkout nor compiler; an independent consumer imports that installed namespace.

The root lock/manifests are genuine qualification inputs, not generated examples. Ordinary gates verify them unchanged. Networkable preparation and offline tests are separate. CI logs are evidence only when actual commands complete successfully; a workflow definition alone is not execution evidence.

## Non-goals

No real participant records, significance recommendation, automatic conclusion, causal model, weighted assignments, random approximation, GUI, server, telemetry or model/API runtime. There is no performance or adoption claim. Original code is MIT while maintained numerical/runtime dependencies retain their own licenses.
