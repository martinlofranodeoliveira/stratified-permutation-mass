# Dependency licensing boundaries

Original project code and documentation are MIT, copyright 2026 Lofrano Tecnologia. That statement does not label the R/GMP dependency closure MIT. This repository does not vendor upstream source into its original implementation.

| Component | Role | Upstream licensing boundary |
| --- | --- | --- |
| R 4.5.0 | Runtime, package build/check, base/recommended facilities | GPL-2 for the Debian package's principal license, with LGPL, Artistic and other component notices; retain actual R copyright/license files |
| GNU GMP 6.3.0 | Native arbitrary-precision engine used by gmp | Principal library dual GPL-2-or-later / LGPL-3-or-later; some source/demo components have distinct GPL terms |
| CRAN gmp 0.7-5 | Maintained exact integer/rational R APIs | Principal package GPL-2-or-later; factorization source has GPL-3-or-later notice; inspect the original archive and actual notices |
| renv 1.1.2 | Optional build/restore tooling, not application runtime | MIT; Posit Software, PBC notices remain applicable |
| Debian native closure | Runtime/build support | Component-specific licenses, not a single blanket license |

The prepared image retains the signed Debian R/GMP copyright files, installed upstream package DESCRIPTION files, and Debian common license texts under `/opt/notices`. The exact original CRAN archives and verified hashes remain in `/opt/qualified-r-repo`. The runtime stage retains notices but does not contain those original source archives or build tools. It is a local test artifact, not a claim that distribution obligations have been discharged.

Before redistributing a runtime image or dependency binaries, retain the exact applicable notices and corresponding source/license materials or another legally valid means of satisfying the chosen licenses. Keep dependency source artifacts separate from the compiler-free runtime if needed; do not present a binary-only image as an MIT-only distribution. Review actual-component notices rather than relying solely on the summary table. No legal advice is provided here.

Official provenance and source hashes are documented in [dependencies](docs/dependencies.md). Upstream notices, not this project's MIT license, govern their components.
