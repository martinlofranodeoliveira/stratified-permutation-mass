# Contributing

This is development version 0.1.0. Keep changes small, original and reviewable. Use only synthetic fixtures and do not contribute private client code or personal records.

## Local work

The native package is `pkg/stratapermexact`. With R and gmp installed:

```sh
R CMD build pkg/stratapermexact
R CMD check --no-manual stratapermexact_0.1.0.tar.gz
lib="$(mktemp -d)"
R CMD INSTALL --library="$lib" stratapermexact_0.1.0.tar.gz
R_LIBS_USER="$lib" Rscript --vanilla pkg/stratapermexact/tests/regression.R
R_LIBS_USER="$lib" Rscript --vanilla pkg/stratapermexact/exec/stratapermexact.R demo --assert
```

Use the full isolated gate from the README for acceptance. Require `Status: OK` with no WARNING, NOTE or ERROR, archive inventory/hash equality, a fresh private installation, and the independent runtime consumer and installed demo. Source-tree execution alone is insufficient. A missing oracle, dependency failure, timeout or crash is not a successful negative test.

## Review expectations

- Preserve the documented mathematical model, validation order, typed codes and all-or-nothing result schema.
- Check update capacity before arithmetic/commit; include all retained/staging maps in cell accounting.
- Keep count arithmetic exact and delegated to maintained gmp APIs.
- Add full cellwise independent enumeration tests when changing the recurrence or convolution.
- Test translation/complement identities, zero/full counts, repeated/negative scores and exact large counts.
- Update both READMEs, help, contract and changelog for observable API changes.
- Do not add runtime network access, telemetry, arbitrary execution/path adapters, a server, significance recommendations or personal-data fixtures.
- Dependency changes require separate official-artifact/native API/offline restore qualification. Ordinary gates verify genuine locks/manifests unchanged; they do not regenerate them.

CI uses only the pinned checkout action and standard hosted Linux. Do not add publication, deployment, privileged-container or unqualified workflow actions. Do not interpret a workflow definition as evidence of a successful run.

Original contributions are provided under this project's MIT license. Maintained dependencies keep their own licenses. General contact is the [official homepage](https://lofranotecnologia.com.br); report vulnerabilities privately as described in SECURITY.md.
