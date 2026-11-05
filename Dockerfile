FROM debian:trixie-slim@sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392 AS prepared
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget make g++ dpkg-dev \
    r-base-core=4.5.0-3 r-base-dev=4.5.0-3 \
    libgmp-dev=2:6.3.0+dfsg-3 libgmp10=2:6.3.0+dfsg-3
RUN test "$(gcc -dumpfullversion)" = 14.2.0 && \
    mkdir -p /opt/qualified-r-repo/src/contrib /opt/r-qualified /opt/notices && \
    wget -O /opt/qualified-r-repo/src/contrib/gmp_0.7-5.tar.gz \
      https://cran.r-project.org/src/contrib/Archive/gmp/gmp_0.7-5.tar.gz && \
    wget -O /opt/qualified-r-repo/src/contrib/renv_1.1.2.tar.gz \
      https://cran.r-project.org/src/contrib/Archive/renv/renv_1.1.2.tar.gz && \
    printf '%s\n' \
      'f5cdaf9afb4cd921924f16682a6d6097ff372c95b697f363704c367f9b13ce78  /opt/qualified-r-repo/src/contrib/gmp_0.7-5.tar.gz' \
      '33c9d94c653602225ed345569d1e0fefb9741235e7f4b4096c65f66d37b1bb85  /opt/qualified-r-repo/src/contrib/renv_1.1.2.tar.gz' \
      > /opt/qualified-r-repo/archive.sha256 && \
    sha256sum --check --strict /opt/qualified-r-repo/archive.sha256
RUN --network=none R CMD INSTALL --library=/opt/r-qualified /opt/qualified-r-repo/src/contrib/gmp_0.7-5.tar.gz
RUN --network=none R CMD INSTALL --library=/opt/r-qualified /opt/qualified-r-repo/src/contrib/renv_1.1.2.tar.gz
RUN --network=none Rscript --vanilla -e 'stopifnot(as.character(getRversion()) == "4.5.0"); tools::write_PACKAGES("/opt/qualified-r-repo/src/contrib", type="source")'
RUN cp /usr/share/doc/r-base-core/copyright /opt/notices/R-copyright && \
    cp /usr/share/doc/libgmp10/copyright /opt/notices/GMP-copyright && \
    cp /opt/r-qualified/gmp/DESCRIPTION /opt/notices/gmp-DESCRIPTION && \
    cp /opt/r-qualified/renv/DESCRIPTION /opt/notices/renv-DESCRIPTION && \
    cp -R /usr/share/common-licenses /opt/notices/common-licenses && \
    mkdir -p /work/source /work/build /work/home /work/library /work/installed /work/artifacts && \
    chown -R 1000:1000 /work
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 HOME=/work/home R_LIBS_SITE=/opt/r-qualified R_LIBS_USER=/work/library
WORKDIR /work
USER 1000:1000

FROM prepared AS test
COPY --chown=1000:1000 . /work/source
CMD ["sh", "/work/source/tools/gate.sh"]

FROM prepared AS installed
COPY --chown=1000:1000 build/stratapermexact_0.1.0.tar.gz /work/artifacts/stratapermexact_0.1.0.tar.gz
RUN --network=none R CMD INSTALL --library=/work/installed /work/artifacts/stratapermexact_0.1.0.tar.gz

FROM debian:trixie-slim@sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392 AS runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base-core=4.5.0-3 libgmp10=2:6.3.0+dfsg-3 && \
    mkdir -p /work/home /work/library && chown -R 1000:1000 /work && \
    test ! -x /usr/bin/cc && test ! -x /usr/bin/gcc && test ! -x /usr/bin/g++
COPY --from=prepared /opt/r-qualified/gmp /opt/r-qualified/gmp
COPY --from=prepared /opt/notices /opt/notices
COPY --from=installed /work/installed /opt/spm-library
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 HOME=/work/home R_LIBS_SITE=/opt/spm-library:/opt/r-qualified R_LIBS_USER=/work/library
WORKDIR /work
USER 1000:1000
ENTRYPOINT ["Rscript", "--vanilla", "/opt/spm-library/stratapermexact/exec/stratapermexact.R"]
CMD ["demo", "--assert"]
