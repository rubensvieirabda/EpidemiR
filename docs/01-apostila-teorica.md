# Apostila: aprofundamento em R

Material de estudo pensado para acompanhar **este projeto**. Cada conceito aparece
primeiro na linguagem, depois conectado a um arquivo do `EpidemiR`.
Trechos de código podem ser colados no console — experimente modificar tudo.

> Convenção: `?funcao` abre a ajuda; `vignette(package = "dplyr")` lista as
> vignettes. Leia a ajuda **depois** de tentar prever o resultado.

---

## 1. O modelo mental: tudo é objeto

Em R, praticamente tudo é objeto: números, vetores, funções, data.frames e até
o próprio ambiente onde você está. Objetos têm **tipo**, **atributos** e
**classe**.

```r
x <- 42
typeof(x)      # "double"  (42 é double; 42L é integer)
class(x)       # "numeric"
attributes(x)  # NULL

y <- factor(c("PE", "SP"))
typeof(y)      # "integer"   -> factor é inteiro por baixo
class(y)       # "factor"
attributes(y)  # $levels
```

Três funções que você vai usar para sempre:

```r
typeof(x)   # tipo interno
str(x)      # estrutura compacta
dput(x)     # reproduz o objeto como código R
```

**Conexão com o projeto:** `UF_LOOKUP` (`R/00_config.R`) é um `data.frame` com
colunas de tipos distintos (`integer`, `character`, `double`). `str(UF_LOOKUP)`
mostra isso em duas linhas. Note o `stringsAsFactors = FALSE`: sem ele, versões
antigas do R transformariam texto em factor e bagunçariam joins.

---

## 2. Vetores, coerção e reciclagem

R não tem "escalares": `1` é um vetor de tamanho 1. Quase todas as operações
são **vetorizadas**.

```r
c(TRUE, 1L, 2.5, "texto")
# [1] "TRUE" "1" "2.5" "texto"   -> tudo virou character

c(TRUE, 1L, 2.5)
# [1] 1.0 1.0 2.5                 -> promovido a double
```

Hierarquia de coerção (de "fraca" para "forta"):

```
logical  <  integer  <  double  <  complex  <  character
```

`raw` fica fora dessa cadeia. A regra prática: `c()` promove todos ao tipo
"mais largo" presente.

### Reciclagem

```r
1:6 + c(10, 20)      # o vetor curto repete: 11 22 13 24 15 26
1:7 + c(10, 20)      # aviso: resultado de tamanho 7 não é múltiplo de 2
```

Reciclagem é útil (`x > 0`) e perigosa (soma de vetores de tamanhos diferentes
que deveriam bater). No pipeline, evite contar com ela em chaves: validamos
`ano` e `sigla_uf` antes de agregar.

### Indexação

```r
v <- c(a = 10, b = 20, c = 30)
v[2]        # 20       -> mantém nome
v[[2]]      # 20       -> remove atributos, só o valor
v["b"]      # 20       -> por nome
v[c(TRUE, FALSE, TRUE)]  # 10 30
v[-1]       # 20 30    -> negativo exclui
v[NULL]     # vector() -> vazio

df <- data.frame(ano = 2014:2016, total = c(1, 2, 3))
df[df$ano == 2015, ]     # linha; CUIDADO com NA no filtro
df$total                 # vetor da coluna
df[["total"]]            # idem, mais explícito
```

Para listas, `[` devolve uma **sub-lista**; `[[` devolve o **elemento**. Essa
distinção explica muito erro de "objeto de comprimento 1".

---

## 3. `NA`, `NaN`, `Inf`, `NULL`

| Valor | Significado | Tipo | `is.na()` |
|---|---|---|---|
| `NA` | dado ausente | logical (tem variantes `NA_integer_`, etc.) | TRUE |
| `NaN` | "not a number", ex.: `0/0` | double | TRUE |
| `Inf` | infinito, ex.: `1/0` | double | FALSE |
| `NULL` | objeto vazio, comprimento 0 | NULL | FALSE (é `is.null()`) |

```r
is.na(NaN)     # TRUE
is.nan(NA)     # FALSE
is.finite(Inf) # FALSE
length(NULL)   # 0
c(NULL, 1)     # 1   -> NULL "desaparece" dentro de c()
```

**O grande perigo:** `NA == 2015` devolve `NA`, não `FALSE`. E filtrar com um
vetor que contém `NA` produz linhas de `NA`:

```r
x <- c(2014, NA, 2016)
x[x == 2015]        # NA NA
x[which(x == 2015)] # numeric(0)  -> `which` descarta NAs
x[!is.na(x) & x == 2015] # numeric(0) -> forma mais explícita
```

Em `dplyr::filter()`, linhas cuja condição é `NA` são removidas. É por isso que
`prepare_cases()` normaliza e remove chaves inválidas **antes** de agregar.

`ifelse(test, yes, no)` é vetorizado e preserva o comprimento de `test`:

```r
ifelse(c(TRUE, NA, FALSE), 1, 0)   # 1 NA 0
```

Para `NA` virar zero de propósito, use `ifelse(is.na(x), 0, x)` — foi exatamente
o que fizemos em `.complete_grid()`, junto da coluna `is_imputed` para não
perder a informação de que aquela célula foi preenchida.

---

## 4. Factors (fatores)

Factor é um inteiro com `levels` (rótulos). Serve para variáveis categóricas com
conjunto fixo e ordem conhecida.

```r
reg <- factor(c("Nordeste", "Sul", "Nordeste"))
levels(reg)          # "Nordeste" "Sul"   -> ordem alfabética por padrão
as.integer(reg)      # 1 2 1

reg2 <- factor(c("baixo", "medio", "alto"),
               levels = c("baixo", "medio", "alto"), ordered = TRUE)
reg2 < "alto"        # TRUE TRUE FALSE
```

Armadilhas:

- `factor(1:3)` cria níveis `"1"`, `"2"`, `"3"` — não use para números.
- `factor(c("SP", "PE"))` só conhece esses dois níveis. Se depois aparecer "RJ",
  ele vira `NA`. Defina `levels` explicitamente quando souber o universo.
- `droplevels()` remove níveis não usados após um `filter()`.
- Gráficos e `lm()` usam a **ordem dos níveis** como referência.

No projeto, as UFs são `character`, não factor, porque a tabela `UF_LOOKUP`
já define o universo das 27 siglas. Se virassem factor, um join com níveis
diferentes entre as duas tabelas geraria `NA` silencioso.

---

## 5. Lists e data.frames

```r
lst <- list(nome = "casos", anos = 2014:2019, meta = list(fonte = "SIM"))
lst$nome        # "casos"
lst[["anos"]]   # vetor
length(lst)     # 3
```

Um `data.frame` é uma **lista de vetores de mesmo comprimento** com atributo
`row.names`. Um `tibble` é um data.frame com impressão e comportamentos mais
seguros (não converte string em factor, não cria nomes de linha, recicla menos).

```r
dplyr::glimpse(UF_LOOKUP)
UF_LOOKUP[1, "sigla"]      # "RO"
UF_LOOKUP[[1]]             # coluna inteira (equivale a UF_LOOKUP$sigla)
```

**Conexão com o projeto:** `extract_all()` devolve uma `list(cases, births)`;
`summary_stats()` devolve uma `list` de escalares e um sub-lista (`top_uf`).
Essa é a forma natural de devolver "várias coisas" sem poluir o global env.

---

## 6. Funções: avaliação preguiçosa e escopo

### Argumentos são promises

R não avalia um argumento quando a função é chamada — só quando ele é usado.

```r
f <- function(x) {
  cat("antes\n")
  force(x)        # força a avaliação aqui
  cat("depois\n")
  x
}
f({ cat("avaliando!\n"); 42 })
# antes / avaliando! / depois
```

Isso permite `missing(x)` e valores padrão que dependem de outros argumentos —
é exatamente o que `default_config()` faz:

```r
table_cases <- table_cases %||% if (source == "sim") "..." else "..."
```

### Escopo léxico

Uma função procura variáveis **onde foi definida**, não onde foi chamada.

```r
fabricar <- function(fator) {
  function(x) x * fator   # closure: "lembra" de fator
}
dobro <- fabricar(2)
dobro(10)  # 20
```

`make_checker()` em `tests/test_pipeline.R` é um closure com estado: ele guarda
um `environment()` privado com o contador de testes. É o uso legítimo de `<<-`:

```r
state$n <- state$n + 1L   # modifica o environment guardado, não cria global
```

Fora de um closure, `<<-` procura no ambiente pai e, se não achar, cria no
global — é uma das formas mais comuns de bug "misterioso". Evite.

### `...`, `match.arg` e `on.exit`

```r
meu_plot <- function(tipo = c("linha", "ponto"), ...) {
  tipo <- match.arg(tipo)
  # '...' repassado para outra função
  invisible(list(tipo = tipo, args = list(...)))
}

com_device <- function(path, code) {
  grDevices::png(path)
  on.exit(grDevices::dev.off(), add = TRUE)   # sempre executa, mesmo com erro
  force(code)
}
```

`safe_png()` no projeto usa esse padrão. Sem `on.exit()`, um erro no meio do
gráfico deixa o dispositivo aberto e o próximo plot vai parar dentro do PNG
anterior.

### Condições

```r
tryCatch(
  expressao_que_pode_falhar(),
  error = function(e) { message("erro: ", conditionMessage(e)); NULL },
  warning = function(w) { invokeRestart("muffleWarning") },
  finally = { message("limpeza") }
)
```

`stop(msg, call. = FALSE)` evita poluir a mensagem com "Error in f(...)".
É o que `abort_if()` faz. `try()` é a versão curta: devolve um objeto da classe
`try-error` em vez de parar — útil em testes.

---

## 7. Depurando sem adivinhar

| Ferramenta | Quando usar |
|---|---|
| `traceback()` | depois de um erro: mostra a pilha de chamadas |
| `rlang::last_trace()` | versão mais legível (rlang vem com dplyr) |
| `options(error = recover)` | abre menu para inspecionar cada frame |
| `debugonce(f)` | entra no debugger na próxima chamada de `f` |
| `browser()` | coloque dentro da função; `n` próxima linha, `c` continua, `Q` sai |
| `conditionMessage(e)` | pega só o texto do erro dentro de `tryCatch` |

O `.Rhistory` do projeto termina com `rlang::last_trace()` — sinal de que foi
usado para investigar justamente o erro de parse do `BaseMap.R`.

---

## 8. tidyverse: verbs que você já usa no projeto

### O pipe

```r
x |> f() |> g(y = 3)     # nativo, R >= 4.1
x %>% f() %>% g(y = 3)   # magrittr, precisa do pacote
```

O pipe nativo insere o valor como **primeiro argumento**. Para outro lugar, use
o placeholder `_` (R >= 4.2): `x |> plot(y = _)`.

### Os verbs

```r
cases |>
  dplyr::filter(ano >= 2015) |>
  dplyr::group_by(sigla_uf) |>
  dplyr::summarise(total = sum(total), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(total))
```

- `mutate()` cria/colunas; `transmute()` só mantém as criadas.
- `summarise()` colapsa grupos; **sempre** passe `.groups = "drop"` se o próximo
  passo não deve continuar agrupado.
- `n()` conta linhas do grupo; `dplyr::n_distinct(x)` conta valores únicos.
- `left_join(x, y, by = ...)` mantém todas as linhas de `x` — foi a escolha em
  `add_rates()`, porque uma UF sem denominador deve virar taxa `NA`, não
  desaparecer.
- `anti_join()` acha o que **não** casou: ótimo para auditoria de chaves.

### Programação com tidy eval

Quando o nome da coluna é dinâmico, o dplyr exige cuidado:

```r
resumo <- function(d, col) {
  d |> dplyr::summarise(total = sum(.data[[col]]))
}
resumo(cases, "total")
```

Para repassar uma coluna escrita pelo usuário:

```r
media_de <- function(d, col) {
  d |> dplyr::summarise(m = mean({{ col }}, na.rm = TRUE))
}
media_de(cases, total)
```

Nosso pipeline evita isso no caminho crítico: `.normalize_counts()` renomeia a
coluna de valor para `value` usando base R **antes** de entrar no dplyr. Menos
mágica, mais previsibilidade — e um bom exemplo de que "tidyverse" e "base R"
se misturam naturalmente.

---

## 9. SQL dentro do R

A consulta do projeto roda no BigQuery pela Base dos Dados:

```sql
SELECT ano, sigla_uf, COUNT(*) AS total
FROM `basedosdados.br_ms_sim.microdados`
WHERE ano BETWEEN 2014 AND 2019
  AND causa_basica LIKE 'Q02%'
GROUP BY ano, sigla_uf
ORDER BY sigla_uf, ano
```

Leia de baixo para cima mentalmente:

1. `FROM`: tabela completamente qualificada entre backticks.
2. `WHERE`: filtra **linhas** antes de agrupar. Filtrar `ano` primeiro é
   importante porque a tabela é particionada por ano — menos dados lidos,
   menos custo.
3. `GROUP BY`: define as chaves. Toda coluna do `SELECT` que não é agregada
   precisa estar aqui.
4. `COUNT(*)` conta linhas; `COUNT(coluna)` ignora `NULL`s.
5. `HAVING` filtra grupos (depois do `GROUP BY`); `ORDER BY` ordena a saída.
6. `LIKE 'Q02%'` = prefixo; `LIKE '%Q02%'` = contém. A escolha muda a semântica
   do CID.

No R:

```r
basedosdados::read_sql(query, billing_project_id = Sys.getenv("GCP_BILLING_ID"))
```

Alternativa quando você tem conexão ODBC/BigQuery própria: `DBI` + `dbplyr`,
onde você escreve dplyr e o pacote traduz para SQL. Ainda assim, **saiba ler
SQL**: é a língua franca de qualquer base grande.

Regra de ouro: nunca interpole texto do usuário direto na SQL. Valide com
regex (`^[A-Z0-9%_]+$`) como faz `.abstract_sql_text()`.

---

## 10. Estatística: contagem, taxa e cautela

O pipeline calcula:

```r
taxa_100k <- total / nascidos * 1e5
```

Por que não comparar `total` direto? Porque o total mistura **risco** com
**tamanho da população**. Um estado com o dobro de nascimentos tende ao dobro
de casos mesmo com o mesmo risco.

Três níveis de resumo:

| Medida | Pergunta que responde |
|---|---|
| Contagem | Quantos casos? |
| Taxa estadual | Qual o risco relativo naquele estado? |
| Taxa nacional ponderada (`sum(total)/sum(nascidos)`) | Qual o risco no país? |

A média simples das taxas estaduais (`mean(rated$taxa_100k)`) **não** é a taxa
nacional: ela dá o mesmo peso para PE e para RO. Compare os dois números no
`relatorio.md` gerado — a diferença é didática.

`fit_trends()` ajusta `lm(total ~ ano)`:

- `slope`: variação média de casos por ano (na escala de contagem, não de taxa).
- `r.squared`: fração da variação explicada pelo ano.
- `p_value`: probabilidade de ver uma inclinação tão extrema se o risco fosse
  nulo. Com 27 UFs, espere alguns falsos positivos só por acaso.
- Cuidado: tendência em contagem pode refletir mudança de natalidade, não de
  risco. Para uma análise mais correta, ajuste `taxa_100k ~ ano`.

> **Erro ecológico:** taxas estaduais não dizem nada sobre o risco de uma
> pessoa específica. Este projeto é descritivo, não causal.

---

## 11. Visualização

### Base graphics

```r
grDevices::png("fig.png", width = 1000, height = 700, res = 120)
on.exit(grDevices::dev.off(), add = TRUE)
graphics::barplot(d$total, names.arg = d$ano, col = "steelblue")
graphics::text(x, y, labels = format_number(d$total), pos = 3)
```

`plot()` / `barplot()` / `symbols()` são rápidos e sempre disponíveis. O
`fig_mapa_bolhas.png` do projeto usa `symbols()` sobre centroides aproximados:
é um "mapa" honesto o suficiente para mostrar padrão geográfico sem precisar
de malha shapefile.

### ggplot2 (opcional no projeto)

```r
ggplot2::ggplot(cases, ggplot2::aes(x = ano, y = total, group = sigla_uf)) +
  ggplot2::geom_line(alpha = 0.3) +
  ggplot2::scale_y_continuous(labels = scales::label_comma()) +
  ggplot2::theme_minimal() +
  ggplot2::labs(title = "Casos por ano e UF", y = "Casos")
```

A gramática: **dados + mapeamento (aes) + geometria + escalas + tema**. Cada
camada entra com `+`. Vantagem: consistência e facetas (`facet_wrap`).

### Mapas de verdade

`geobr::read_state(year = 2019)` traz a malha oficial do IBGE; `sf` faz a
junção e `geom_sf()` desenha. Atenção a:

- **projeção**: usar latitude/longitude direto distorce área em altas latitudes;
- **escala de cor**: `scale_fill_viridis_c()` é perceptually uniforme;
- **classe de intervalo**: `cut()` / `classIntervals` mudam a leitura do mapa.

---

## 12. Reprodutibilidade

- **Projeto R** (`.Rproj`): define raiz, encoding, opções. O `.Rprofile` aqui
  carrega `renv/activate.R`.
- **renv**: `renv::init()` → `renv::snapshot()` → `renv::lock` versionado →
  `renv::restore()` em outra máquina. Sem snapshot, o lockfile não protege nada.
- **Segredos**: `.Renviron` + `.gitignore`. Nunca `set_billing_id("123")`
  dentro de código versionado.
- **Testes**: `tests/test_pipeline.R` roda offline com dados mock. Teste bom é
  determinístico (semente fixa) e verifica contrato, não implementação.
- **Relatório**: `write_report_md()` gera markdown com `sprintf()`. Para algo
  mais rico, RMarkdown/Quarto com chunks e `params`.

---

## 13. Performance sem mágica

1. **Prealoque** vetores: `x <- numeric(n)` e preencha `x[i]`, em vez de
   `x <- c(x, valor)` dentro de laço (cópia quadrática).
2. **Vetorize**: `x * 2` em vez de `for (i in seq_along(x)) x[i] <- x[i]*2`.
3. **`vapply()` > `sapply()`**: você declara o tipo de retorno e falha cedo.
4. **`seq_along(x)`** em vez de `1:length(x)` (que devolve `c(1, 0)` se `x`
   estiver vazio).
5. **Não faça `rbind` dentro de laço**: junte uma lista com `do.call(rbind, L)`.
6. **Meça**: `system.time()`, `bench::mark()`, `profvis::profvis()`.
7. **Quando R base não dá conta**: `data.table` ou `duckdb`, mantendo a mesma
   separação extrair/transformar/analisar.

---

## 14. Armadilhas clássicas (cola na parede)

| Código | Problema | Correção |
|---|---|---|
| `1:0` | devolve `c(1, 0)`, não vazio | `seq_len(0)` → `integer(0)` |
| `sample(5, 1)` | amostra de `1:5`, não o número 5 | `sample.int(5, 1)` com cuidado |
| `x[x > 2]` com `NA` | linhas `NA` aparecem | `x[!is.na(x) & x > 2]` |
| `if (x > 2)` com vetor | só usa o primeiro elemento | `ifelse()` ou `all()`/`any()` |
| `ifelse()` com datas | perde classe | reconstrua com `as.Date()` |
| `stringsAsFactors` | factor indesejado (pré-4.0) | `stringsAsFactors = FALSE` |
| `merge()` | nomes e ordens surpreendentes | `dplyr::*_join()` |
| `write.csv(x, "f.csv")` | coluna `X` com índices | `row.names = FALSE` ou `readr::write_csv()` |
| `factor(c("9","10"))` | ordem alfabética: "10" < "9" | defina `levels` |
| `==` com float | `0.1 + 0.2 == 0.3` é FALSE | `abs(a-b) < 1e-8` |
| `library()` no módulo | dependência escondida | `pacote::funcao()` |
| `NA` em `sum()` | resultado `NA` | `sum(x, na.rm = TRUE)` |

---

## 15. Exercícios (com solução)

### Exercício 1 — coerção

Preveja o resultado antes de rodar:

```r
c(TRUE, 2L, "3")
c(NA, 1)
as.numeric(factor(c("10", "2")))
```

<details>
<summary>Solução</summary>

```r
c(TRUE, 2L, "3")          # "TRUE" "2" "3"  -> character domina
c(NA, 1)                  # NA 1 -> NA promovido a integer
as.numeric(factor(c("10", "2")))  # 2 1 -> níveis por ordem alfabética!
```

O último é o clássico erro de factor: sempre converta para `character` antes
de `numeric` quando os rótulos são números.

</details>

### Exercício 2 — `NA` no filtro

```r
d <- data.frame(ano = c(2015, NA, 2017), total = c(10, 20, 30))
nrow(d[d$ano == 2015, ])
```

<details>
<summary>Solução</summary>

Devolve 2 linhas: a de 2015 e a de `NA` (com `total = NA`). Correção:

```r
nrow(d[!is.na(d$ano) & d$ano == 2015, ])  # 1
# ou
nrow(dplyr::filter(d, ano == 2015))       # 1 (filter descarta NA)
```

</details>

### Exercício 3 — closure com estado

Escreva uma função `contador()` que devolva outra função; cada chamada deve
incrementar e devolver o número.

<details>
<summary>Solução</summary>

```r
contador <- function() {
  e <- new.env(parent = emptyenv())
  e$n <- 0L
  function() { e$n <- e$n + 1L; e$n }
}
c1 <- contador(); c1(); c1()   # 1, 2
c2 <- contador(); c2()         # 1  -> estado independente
```

É o mesmo mecanismo de `make_checker()` nos testes.

</details>

### Exercício 4 — verbalização do dplyr

O que faz `dplyr::summarise(d, n = dplyr::n(), total = sum(total, na.rm = TRUE))`
sem `group_by()`? E com `group_by(ano)`?

<details>
<summary>Solução</summary>

Sem grupo: uma única linha com o total do data.frame inteiro. Com
`group_by(ano)`: uma linha por ano. Sempre finalize com `.groups = "drop"` se
você vai usar o resultado em outro `mutate()` que não deve herdar o agrupamento.

</details>

### Exercício 5 — taxa ponderada

Dados: UF A (100 casos / 10.000 nascidos), UF B (100 casos / 100.000 nascidos).
Calcule a média simples das taxas e a taxa nacional.

<details>
<summary>Solução</summary>

- Taxa A = 100/10.000 × 100.000 = **1000/100 mil**
- Taxa B = 100/100.000 × 100.000 = **100/100 mil**
- Média simples = 550/100 mil (enganoso: dá o mesmo peso às duas UFs)
- Taxa nacional = 200/110.000 × 100.000 ≈ **181,8/100 mil**

É por isso que `summary_stats()` calcula `sum(total)/sum(nascidos)`, e por isso
o relatório mostra as duas medidas separadas.

</details>

### Exercício 6 — SQL

Escreva uma consulta que retorne, por ano, a UF com o maior total de casos.
Dica: use CTE (`WITH`) e `ROW_NUMBER() OVER (PARTITION BY ano ORDER BY ...)`.

<details>
<summary>Solução (esqueleto)</summary>

```sql
WITH agr AS (
  SELECT ano, sigla_uf, COUNT(*) AS total
  FROM `basedosdados.br_ms_sim.microdados`
  WHERE ano BETWEEN 2014 AND 2019
    AND causa_basica LIKE 'Q02%'
  GROUP BY ano, sigla_uf
), ranqueado AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY ano ORDER BY total DESC) AS rk
  FROM agr
)
SELECT ano, sigla_uf, total
FROM ranqueado
WHERE rk = 1
ORDER BY ano
```

Em R, a versão equivalente usa `rank_uf()` + `group_by(ano)` com
`dplyr::slice_max(total, n = 1)`.

</details>

---

## Próximo passo

Abra o [roadmap de 12 semanas](02-roadmap-estudos.md) e comece pela semana 1.
A melhor forma de fixar este material é **modificar o pipeline**: troque um CID,
adicione uma métrica, escreva um teste que falhe e conserte.
