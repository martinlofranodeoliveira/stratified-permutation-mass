# Security

## Reporting

Use GitHub private vulnerability reporting:

https://github.com/martinlofranodeoliveira/stratified-permutation-mass/security/advisories/new

Do not place exploit details, secrets or personal data in a public issue. General contact is the official homepage: https://lofranotecnologia.com.br . No response-time SLA is promised.

## Scope and boundaries

Development version 0.1.0 is a pure R exact-counting library with a fixed synthetic asserting CLI. There is no runtime network access, model/API dependency, telemetry, credential handling, server, arbitrary executable input or filesystem input adapter. Inputs are ordinary cooperative R values, not serialized code or untrusted R programs. R evaluation and native dependencies are not a sandbox.

Input validation limits sizes, integer ranges and custom budgets. DP budgets bound logical coefficient cells and contribution updates, not total RSS, GMP internals or wall-clock duration. Use the documented offline container restrictions and an outer owner deadline for untrusted workloads. A process crash or native allocation failure must not be interpreted as INVALID_INPUT or UNKNOWN_BUDGET.

The library does not signal PIDs/PGIDs or spawn workers. Build/test helpers invoke fixed commands synchronously. No universal descendant cleanup, real-time deadline or kernel-uninterruptible I/O guarantee is made. Timeout or interruption is INCOMPLETE.

Build/manifest/archive operations support only owned cooperative local Linux filesystems with stable directories and no concurrent hostile mutation. They are not general-purpose hostile-file parsers. Hash verification is not an atomic filesystem snapshot. The application publishes no files; stdout can be truncated, so consumers must require complete framing and a successful exit.

Dependency vulnerabilities and redistribution obligations remain relevant even though the original source is MIT. Preserve exact official source identities, genuine lock/native manifests and notices. Never silently repair a failed offline gate by downloading or changing evidence.
