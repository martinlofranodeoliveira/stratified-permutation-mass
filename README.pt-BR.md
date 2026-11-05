# Stratified Permutation Mass

**Versão de desenvolvimento 0.1.0** — biblioteca R original de combinatória exata e limitada da [Lofrano Tecnologia](https://lofranotecnologia.com.br).

Calcula a distribuição exata da soma dos escores selecionados, preservando uma quantidade de selecionados em cada estrato fixo. As atribuições têm pesos uniformes sobre posições distintas; escores repetidos não tornam as posições indistinguíveis. Uma programação dinâmica original por quantidade selecionada e escore calcula cada estrato, seguida de convolução exata. O pacote mantido **gmp** fornece a aritmética inteira e racional de precisão arbitrária. Não é um invólucro de um teste estatístico.

Repositório: https://github.com/martinlofranodeoliveira/stratified-permutation-mass

## Limites e estados

- 1–8 estratos, 1–16 itens por estrato e 1–64 itens no total.
- Escores integrais de −20 a 20; selecionados de zero ao tamanho do estrato.
- Até 65.536 células vivas de coeficientes/temporários e 5.000.000 de atualizações por contribuição. Orçamentos personalizados só podem reduzir esses tetos.
- Somente escores alcançáveis, em ordem crescente: até 2.561 linhas entre −1280 e 1280.
- Contagens exatas como **strings decimais**, limitadas por 2^64, nunca probabilidades em double.
- `COMPLETE`: todas as massas, normalizador exato e caudas inclusivas solicitadas.
- `UNKNOWN_BUDGET`: motivo e contadores, sem distribuição, normalizador ou caudas parciais.
- `INVALID_INPUT`: código e campo do erro de entrada, sem cálculo.

Consulte o [contrato preciso](docs/contract.md), o [projeto](docs/design.md) e `?spm_distribution`. Limites lógicos de trabalho não são limites rígidos de bytes ou de tempo. R não é uma sandbox para código hostil.

## Instalação e testes

O pacote-fonte fica em **`pkg/stratapermexact`**, não na raiz. Requer R 4.5.0 ou posterior e o pacote CRAN mantido `gmp`. O procedimento reprodutível usa R 4.5.0, GNU GMP 6.3.0 e gmp 0.7-5 qualificados; renv 1.1.2 é apenas ferramenta de construção.

Com a biblioteca qualificada offline disponível:

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

O CLI importa o pacote instalado, sem alternativa via `source()`. Seu caminho instalado é retornado por `system.file("exec", "stratapermexact.R", package="stratapermexact", mustWork=TRUE)`.

Para desenvolvimento, `R CMD check --no-manual pkg/stratapermexact` verifica o diretório nativo. A aceitação usa o pacote-fonte construído e exige **exatamente `Status: OK`, sem WARNING, NOTE ou ERROR**, além da saída zero. Os testes usam R base, gmp, enumeração independente com `utils::combn` e asserções contadas. Não dependem de testthat ou jsonlite.

## Verificação isolada

Os [insumos de evidência](docs/dependencies.md) incluem lock e manifestos genuínos. Sua ausência é falha da verificação; testes comuns nunca os geram nem substituem. A preparação Docker pode baixar somente artefatos oficiais Debian/CRAN. Os contêineres de teste ficam sem rede.

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

O estágio final contém bibliotecas instaladas, sem checkout do pacote ou compilador. Novas execuções exigem identidades de contêiner e diretórios novos. A CI usa permissões somente de leitura, prazo externo de 30 minutos, registros de identidade do runner/fonte e logs, sem publicar. Interrupção ou timeout significa **INCOMPLETE**, não entrada inválida nem resultado matemático verificado. Os comandos documentam procedimentos, não afirmam execução em uma máquina específica.

## Uso da API R

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
contagens_exatas <- gmp::as.bigz(x$masses$count)
limitado <- spm_distribution(list(list(scores = 1:4, selected = 2L)),
  budgets = list(max_cells = 0L, max_updates = 0L))
stopifnot(limitado$status == "UNKNOWN_BUDGET", is.null(limitado$masses))
invalido <- spm_distribution(list(list(scores = 0.5, selected = 0L)))
stopifnot(invalido$status == "INVALID_INPUT", invalido$error$code == "NONINTEGER")
```

`print(x)` é legível para pessoas. Programas devem examinar `status`, não interpretar a impressão. Entradas e resultados anteriores não são alterados.

## Demonstração determinística com asserções

Saída textual esperada:

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

`--tsv` emite o enquadramento `SPM-DEMO`, cinco registros `mass` e o terminador `END\t5`. Exija enquadramento completo e saída zero: uma falha de E/S pode truncar stdout. O CLI aceita apenas essa demonstração sintética fixa, sem caminhos, endpoints ou nomes de executáveis.

## Decisões e limitações

A programação dinâmica esparsa de duas camadas conta posições sem enumerar todas as atribuições. Camadas em construção entram no orçamento de células, e contribuições são verificadas antes de serem confirmadas. Strings exatas evitam arredondamento em double, inclusive na massa analítica `27435582641610000` no escore 32 para quatro estratos.

Não há escores contínuos, pesos, criação automática de estratos, Monte Carlo, ajuste por covariáveis, dados pessoais, telemetria, dependência de modelo/API, GUI ou servidor. A combinatória não comprova o mecanismo de um experimento real. Não há recomendação de significância, médica, causal, jurídica ou financeira. Não se afirma conformidade estatística ampla, desempenho, implantação ou prontidão para produção.

Código original sob MIT, copyright 2026 Lofrano Tecnologia. R, GNU GMP, gmp, renv e componentes nativos mantêm licenças próprias; MIT não altera essas licenças. Veja [os limites de licenciamento](THIRD_PARTY.md). Contato geral: [site oficial](https://lofranotecnologia.com.br). Segurança: [relato privado de vulnerabilidade no GitHub](https://github.com/martinlofranodeoliveira/stratified-permutation-mass/security/advisories/new).
