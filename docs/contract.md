# Contract — development 0.1.0

## Mathematical model

Items are distinct positions. In stratum j, every subset of exactly k[j] positions has equal weight. The admissible sample space is the Cartesian product of these subset choices. The statistic is the sum of scores at selected positions. Repeated scores preserve positional multiplicity. The normalizer is the exact product of `choose(n[j], k[j])`. There is always at least one assignment for valid input; zero/full selections are valid, not infeasible inputs.

Only this finite, unweighted, fixed-stratum mechanism is modeled. No inference about real people or an experimental mechanism follows from these counts.

## Typed R input

`spm_distribution(strata = NULL, threshold = NULL, budgets = list(max_cells=65536L, max_updates=5000000L))`

Supported objects are unclassed ordinary lists and unclassed integer/double vectors. An optional `names` attribute is allowed; every other attribute is rejected. S3/S4 objects, factors, logicals, arrays, matrices, environments, functions and text numbers are unsupported. No implicit numeric coercion is performed. R callers must be cooperative: evaluating a promise or an arbitrary object's code is outside the library's security boundary.

- `strata`: list length 1–8; optional outer names ignored. `NULL` means missing required input.
- Each stratum: list with exactly the unique names `scores`, `selected`, in either order. Missing/extra/duplicate field names are schema errors.
- `scores`: numeric vector length 1–16; every value integral in −20…20. Names ignored. At most 64 items across all strata.
- `selected`: one numeric integral value in 0…length(scores).
- `threshold`: `NULL`, or one numeric integral value in −2147483647…2147483647. Outside the statistic's support is allowed. Both tails include equality. `NULL` omits the query.
- `budgets`: list with exactly the unique names `max_cells`, `max_updates`. Each is one numeric integral value. Cells: 0…65536; updates: 0…5000000. Defaults are the ceilings. Zero is valid; it does not request unlimited work.

Validation order is outer strata type/size, then each stratum's schema, scores, selected and running total size, then threshold, then budget schema/cells/updates. Numeric validation order is type/attributes, length, missing, finite, integral, range. The first failure wins. Missing required `strata` has code `MISSING`; missing named stratum fields have code `SCHEMA`. `NA` logical has code `TYPE`; `NA_integer_`, `NA_real_` and numeric NaN have code `MISSING`. This distinction avoids silently accepting logical input.

## Deterministic result schema

Every returned value is a fresh S3 `spm_result` list, in this field order:

| Field | Type and meaning |
| --- | --- |
| `schema` | Scalar character `stratapermexact/1` |
| `status` | `COMPLETE`, `UNKNOWN_BUDGET`, or `INVALID_INPUT` |
| `error` | NULL, or list `code`, `field`, `message` |
| `reason` | NULL, `max_cells`, or `max_updates` |
| `masses` | NULL, or data frame `score` integer, `count` character |
| `normalizer` | NULL, or positive exact decimal string |
| `tails` | NULL, or the tail-query list below |
| `work` | List of integer `updates`, `peak_cells` |

`COMPLETE` has every positive mass, in strictly ascending reachable score order, with default data-frame row names. Zero masses are omitted. Scores lie in −1280…1280, hence at most 2561 rows. Counts and their exact sum are at most 2^64. Decimal strings have no leading sign or zeros except the string `0` for a zero tail. Error and reason are NULL.

If requested, `tails` is a list `threshold` (integer), `less_equal`, `greater_equal`. Each tail is a list:

- `numerator`: exact decimal assignment count;
- `denominator`: the original normalizer string, not reduced;
- `rational`: canonical `as.character(gmp::as.bigq(numerator, denominator))`, reduced, with integer form such as `0` or `1` when appropriate.

Thus the two numerators overlap on mass exactly at the threshold. They need not sum to the normalizer. Use `gmp::as.bigz` for decimal counts, or `gmp::as.bigq(gmp::as.bigz(numerator), gmp::as.bigz(denominator))` for a rational. Never convert counts to double to obtain an exact probability.

`INVALID_INPUT` has error code `TYPE`, `SIZE`, `SCHEMA`, `MISSING`, `NONFINITE`, `NONINTEGER` or `RANGE`. `field` identifies `strata`, `strata[[i]]`, its `$scores`/`$selected`, `threshold`, `budgets` or a budget field. Code and field are contractual; message wording is explanatory. Work counters are zero. Reason, masses, normalizer and tails are NULL.

`UNKNOWN_BUDGET` has an exact limit reason and the committed update count/observed logical peak. Error, masses, normalizer and tails are NULL. Internal partially built maps never escape. The result is not a normalized approximation.

Unexpected dependency failures, native allocation failures and violated internal invariants raise R errors. They are not `INVALID_INPUT`, `UNKNOWN_BUDGET`, infeasibility or success. Process interruption/timeouts/missing dependencies are externally **INCOMPLETE**; INCOMPLETE is not an R mathematical result object. The library never mutates input or a previously returned result and never publishes to files.

## Work accounting

Traversal order is input stratum order, input item order, ascending selected count, then ascending score; skip precedes take. Convolution visits ascending left and right scores.

One active cell is one coefficient binding in any retained sparse map. This includes the accumulated cross-stratum mass, old and staged DP layers, the retained final local mass, and staged convolution output. Two additional arithmetic scratch cells are reserved for the entire calculation, including initialization. Empty maps cost no cells. Existing input cells remain charged until their bindings are explicitly removed. No dense coefficient-vector staging is hidden outside this accounting.

Each feasible skip/take contribution and each convolution pair is one update, including contributions to previously existing cells. Seed assignment, pruning/indexing, binomial normalizer arithmetic, final normalization/tail reductions and string conversion are excluded. All table coefficients are positive, so there are no stored zero cells. These overhead operations are bounded separately by the fixed input/output ceilings.

For an update: first check remaining update capacity, then reserve a cell if necessary, then compute/commit and increment. Therefore an update-limit failure wins if both checks would fail at that update. A failed cell reservation does not change live/peak counters or commit an update. Initialization may fail a cell check before any update. A single one-item, select-one stratum requires five peak cells and two updates under this accounting.

These counters bound logical DP storage/work, not allocator overhead, garbage-collector retention, GMP internals, caller memory, RSS or wall-clock time. Output scalars/strings and fixed-size normalizer/reduction registers are not DP cells. Outer offline containers enforce independent resource limits. No numeric PID/PGID signaling or process-control capability exists in the library.

## Fixed demo protocol

CLI arguments must be exactly `demo --assert` or `demo --assert --tsv`. Other arguments produce usage on stderr and exit 2. Mathematical/assertion/runtime errors exit unsuccessfully; they are not valid demo output. The CLI imports the installed namespace, never source files.

Text is for humans. Machine format is UTF-8, LF-terminated, tab-separated, no quoting:

```text
SPM-DEMO	1
status	COMPLETE
mass	3	1
mass	4	1
mass	5	2
mass	6	1
mass	7	1
normalizer	6
tail_le	5	4	6	2/3
tail_ge	5	4	6	2/3
assertions	PASS
END	5
```

The actual records use tab characters. The final integer is the number of mass records. Require the exact frame, terminal line and successful exit. Computation and assertions finish before output begins, but stdout is not an atomic publication channel and may be truncated by I/O failure.

## Filesystem and unsupported behavior

The application accepts no input paths, stdin records, endpoints or executable names. Package/build gates operate only on owned cooperative local Linux filesystems, with controlled directories and no concurrent hostile mutation. Archive/hash evidence relies on that stable lease, not an atomic hostile-filesystem snapshot. The build harness is not a general archive reader. No durability, universal cleanup, hard deadline or hostile filesystem guarantee is made.

No weights, continuous scores, automatic strata, covariate adjustment, Monte Carlo, causal inference or significance recommendation is supported. This is a documented bounded subset, not broad standards compliance.
