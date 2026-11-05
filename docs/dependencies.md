# Qualified dependencies and evidence inputs

## Fixed preparation identities

The public Dockerfile independently prepares Debian trixie-slim amd64 digest `7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392`, signed official Debian `r-base-core`/`r-base-dev` 4.5.0-3, `libgmp10`/`libgmp-dev` 2:6.3.0+dfsg-3, and GCC 14.2.0. Exact package requests fail rather than silently selecting newer versions. Apt dependency closure identities are additionally checked against the qualified native manifest. Availability changes in official repositories may make preparation fail; ordinary gates must not relax pins to repair that failure.

Original upstream CRAN archives:

| Package | Archive | Bytes | SHA256 |
| --- | --- | ---: | --- |
| gmp 0.7-5 | https://cran.r-project.org/src/contrib/Archive/gmp/gmp_0.7-5.tar.gz | 166664 | `f5cdaf9afb4cd921924f16682a6d6097ff372c95b697f363704c367f9b13ce78` |
| renv 1.1.2 | https://cran.r-project.org/src/contrib/Archive/renv/renv_1.1.2.tar.gz | 1263920 | `33c9d94c653602225ed345569d1e0fefb9741235e7f4b4096c65f66d37b1bb85` |

Sources live at `/opt/qualified-r-repo/src/contrib`; the actual index is made with `tools::write_PACKAGES`. Libraries live at `/opt/r-qualified/{gmp,renv}`. Archive hashes are verified before any source installation. Installation uses fixed local archives with networking disabled. No application operation restores or downloads packages. `renv` is optional for users and required only to inspect the qualified build lock in the full gate.

## Mandatory external evidence files

A qualified source checkout includes these actual evidence files under `qualification/`:

1. `renv.lock`: the genuine resolved R 4.5.0 / gmp 0.7-5 / renv 1.1.2 lock, retained from qualification. It is not a hand-written sample.
2. `native-packages.tsv`: exact bytes of `dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n'` from the prepared build image, covering the complete installed native package closure.
3. `dependencies.sha256`: GNU sha256sum format, using absolute paths in the prepared image. It covers the lock at `/work/source/qualification/renv.lock`, both original source archives, the local source repository index, installed gmp/renv content, the R runtime/native headers/libraries, GMP libraries/headers, compiler/build tools and associated license/provenance evidence.

These files are qualification artifacts, not invented distribution files. The native closure and per-file manifest must correspond to this actual prepared image and source lock. Review manifest coverage before accepting evidence. Do not copy a manifest from an unrelated machine or treat version strings alone as artifact identity.

`tools/gate.sh` requires all three inputs, verifies SHA256 checks without rewriting them, compares the actual native closure byte-for-byte, and checks the lock and installed package identities through actual APIs. It never snapshots a new lock, rebuilds a manifest, repairs dependencies or uses an online repository. A mismatch or missing file is an infrastructure failure, not INVALID_INPUT or UNKNOWN_BUDGET.

An intentional dependency update requires a separate qualification: obtain official artifacts, preserve provenance/licenses, verify archive hashes, inspect the real lock and native closure, exercise exact indexed gmp operations/binomial/rational APIs, restore into a fresh library from the fixed local repository, and repeat offline build/check/install/consumer gates. Do not silently regenerate evidence during ordinary testing.

## Isolation and output evidence

The workflow uses standard GitHub-hosted Linux, read-only repository permissions, immutable checkout action identity and a 30-minute job timeout. Offline containers use UID/GID 1000, no network, no capabilities, no-new-privileges, 256 PIDs, 1 GiB and two CPUs. They mount no home directory, keys, sockets or host environment. `/work` and writable subdirectories are actually created and owned by that UID. There are no cross-job caches or extra workflow actions.

Source package hashes, strict R check logs, per-file package inventory hashes, installed consumer/demo output and command exits are separate evidence from dependency qualification. The runtime consumer receives only a fixed test expression, not a checkout or a development search path. Container/job interruption is INCOMPLETE; it cannot establish a passing gate. No cleanup deadline or escaped-process guarantee is claimed.

Primary upstreams: https://www.r-project.org/ ; https://cran.r-project.org/package=gmp ; https://gmplib.org/ ; https://rstudio.github.io/renv/ .
