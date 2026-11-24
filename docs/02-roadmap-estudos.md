# Roadmap de estudos — 12 semanas de R

Plano para sair da introdução e chegar a **análise de dados reproduzível com R**,
usando este repositório como laboratório. Carga sugerida: 6-8 h/semana.

Regra de ouro: **não pule a execução**. Cada semana termina com código rodando e
uma resposta escrita com suas próprias palavras.

## Diagnóstico inicial (30 min, antes da semana 1)

- [ ] Sei o que `typeof()`, `length()` e `str()` mostram?
- [ ] Consigo explicar a diferença entre `NA`, `NULL` e `NaN`?
- [ ] Entendo por que `df[df$ano == 2015, ]` some com linhas com `NA`?
- [ ] Sei o que `group_by() |> summarise()` faz?
- [ ] Consigo ler uma consulta `SELECT ... GROUP BY`?

Se errou 3 ou mais, comece pela Fase I sem pressa. Se acertou quase tudo,
avance e use as semanas 1-3 como revisão ativa.

---

## Fase I — Fundamentos da linguagem (semanas 1-3)

### Semana 1 — Objetos, vetores e tipos

**Objetivos:** pensar em R como vetores; entender coerção e `NA`.

- Tipos atômicos: logical, integer, double, character, complex, raw.
- `typeof()` × `class()` × `mode()`; `is.*` e `as.*`.
- Hierarquia de coerção: logical → integer → double → character.
- Reciclagem de vetores e por que `1:3 + 1` é perigoso.
- `NA`, `NaN`, `Inf`, `NULL`, `NA_integer_`.
- Indexação `[`, `[[`, `$`; negativos; lógicos; nomes.

**Exercício no repo:** abra `R/00_config.R` e responda: por que `UF_LOOKUP`
usa `stringsAsFactors = FALSE`? O que muda em `UF_LOOKUP$regiao` se isso virar
`TRUE`?

**Checkpoint:** sem olhar a apostila, escreva 5 linhas que provem a reciclagem
e a coerção. Explique o resultado de `c(1, 2, NA) > 1`.

### Semana 2 — Funções, escopo e condições

**Objetivos:** entender que função é objeto e que escopo é léxico.

- Argumentos com valores padrão; `missing()`; `...`; `match.arg()`.
- Avaliação preguiçosa (promises) e `force()` — veja `safe_png()`.
- Ambientes: `globalenv()`, `parent.env()`, busca de variáveis.
- Closures e estado: leia `make_checker()` em `tests/test_pipeline.R`.
- `<<-`: quando é legítimo e por que é perigoso fora de closure.
- `tryCatch()`, `try()`, `on.exit()`; `stop()` com `call. = FALSE`.

**Exercício no repo:** reescreva `abort_if()` aceitando uma condição que pode
ser `NA`. O que acontece hoje? (`isTRUE(NA)` é `FALSE`.)

**Checkpoint:** explique por que `read_sql_cached()` usa `tryCatch()` em vez de
`if (falhou) stop()`.

### Semana 3 — Estruturas de dados e debugging

**Objetivos:** dominar lists/data.frames e saber depurar.

- `list()` vs `vector()`; `unlist()`; nomear elementos.
- `data.frame` × `tibble`; `str()`, `dplyr::glimpse()`.
- Factors: `levels`, `ordered`, `droplevels`, armadilhas com `factor(1:3)`.
- `traceback()`, `rlang::last_trace()`, `debugonce()`, `browser()`.
- `options(error = recover)`.

**Exercício no repo:** rode `Rscript tests/test_pipeline.R`, quebre
deliberadamente uma linha de `R/02_transform.R`, rode de novo e use o traceback
para encontrar o ponto. Restaure.

**Checkpoint:** descreva o fluxo de uma mensagem de erro desde `stop()` até o
console.

---

## Fase II — Manipulação e SQL (semanas 4-6)

### Semana 4 — dplyr

**Objetivos:** o vocabulário verbs.

- `select`, `filter`, `mutate`, `arrange`, `rename`, `relocate`.
- `group_by` → `summarise` → `.groups = "drop"`.
- `n()`, `across()`, `if_any()/if_all()`.
- `left_join`, `inner_join`, `anti_join` e o problema de colunas duplicadas.
- Pipe `|>` (nativo) × `%>%` (magrittr).

**Exercício no repo:** em `R/03_analyze.R`, acrescente uma coluna `participacao`
com a fatia de cada UF no total nacional e exporte.

**Checkpoint:** por que `add_rates()` usa `left_join` e não `inner_join`? (Dica:
o que aconteceria com UFs sem denominador?)

### Semana 5 — tidyr e dados arrumados

**Objetivos:** tidy data e reformatação.

- `pivot_longer()` / `pivot_wider()`; `names_to`, `values_to`.
- `separate_wider_delim()` / `unite()`.
- `drop_na()`, `fill()`, `replace_na()`.
- `expand()` / `expand.grid()` — o mesmo truque usado em `.complete_grid()`.
- Tidy eval: `.data$col`, `{{ col }}`, `sym()` (leitura de `vignette("programming")`).

**Exercício no repo:** transforme a tabela larga `casos_por_uf_ano.csv` em
formato longo com `ano` como coluna e uma linha por UF. Depois volte ao formato
original e compare com `all.equal()`.

**Checkpoint:** quando `NA` significa "não existe" e quando significa "não foi
medido"? Como o pipeline distingue isso (`is_imputed`)?

### Semana 6 — SQL para análise de dados

**Objetivos:** ler, escrever e custear consultas.

- `SELECT`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT`.
- `LIKE` e curingas; `BETWEEN`; `COUNT(*) × COUNT(coluna)`.
- Particionamento (`ano`) e por que filtrar cedo reduz custo no BigQuery.
- `read_sql()` do `basedosdados`; `billing_project_id`.
- Alternativa: `DBI` + `dbplyr` (traduz dplyr para SQL).

**Exercício no repo:** compare `build_query_cases(cfg)` com a consulta original
em `BaseMap.R`. Liste 3 diferenças. Depois rode com `--no-cache` **apenas uma
vez** e meça `system.time()`.

**Checkpoint:** por que a validação por regex em `.abstract_sql_text()` existe
mesmo com valores fixos?

---

## Fase III — Estatística e comunicação (semanas 7-9)

### Semana 7 — Estatística descritiva e taxas

**Objetivos:** não confundir contagem com risco.

- Medidas de posição/dispersão; `summary()`, `quantile()`.
- Contagens brutas × taxas × razões; denominador correto.
- "Por 100 mil" como escolha de escala.
- Intervalos de confiança (ideia, não fórmula decorada).
- Erro ecológico: o que a taxa estadual **não** diz sobre o indivíduo.

**Exercício no repo:** compare o `rank_uf()` por contagem com o ranking por
`taxa_100k`. Escreva 5 linhas explicando a divergência.

**Checkpoint:** por que a taxa nacional (ponderada) difere da média das taxas
estaduais (`mean(rated$taxa_100k)`)?

### Semana 8 — Modelos simples e tendências

**Objetivos:** ajustar e interpretar com cautela.

- `stats::lm()`; `coef()`, `summary()`, `r.squared`, `p.value`.
- Leitura do slope; significância ≠ relevância.
- Suposições: linearidade, independência, homocedasticidade.
- Múltiplos testes e falsos positivos (27 UFs → 27 regressões!).

**Exercício no repo:** em `fit_trends()`, troque `lm` por
`stats::cor.test(ano, total)` e compare as direções. Justifique qual você
usaria num relatório.

**Checkpoint:** um `p = 0,04` em 27 testes é convincente? Por quê?

### Semana 9 — Visualização e relatórios

**Objetivos:** comunicar sem enganar.

- Base graphics: `plot()`, `barplot()`, `symbols()`, `par()`, dispositivos.
- ggplot2: gramática (data + aes + geom + scale + theme).
- Mapas: centroide vs malha; projeção; coropletico e escala de cor.
- `sprintf()`, `writeLines()` para relatório programático.
- RMarkdown/Quarto: chunks, cache, parâmetros.

**Exercício no repo:** instale `ggplot2` + `geobr`, rode o pipeline e compare
`fig_mapa_bolhas.png` com `fig_coropletico.png`. Escreva quando cada um engana
menos.

**Checkpoint:** por que o `safe_png()` usa `on.exit(dev.off())`?

---

## Fase IV — Engenharia e aplicação (semanas 10-12)

### Semana 10 — Testes e debug sistemático

- Testes unitários vs de integração; `testthat` (`expect_equal`, `expect_error`).
- Fixtures determinísticas (nosso `mock_*` com `set.seed`).
- Cobertura; testes que falham de propósito.
- `traceback`, `recover`, `browser`, `debugonce`.

**Exercício no repo:** adicione 3 testes novos: (1) `cid_cases` inválido,
(2) `anos` fora do intervalo, (3) denominador zero gerando `NA` na taxa.

### Semana 11 — Reprodutibilidade

- `renv`: `init`, `snapshot`, `restore`, lockfile. Diferença entre `install` e
  `load` no `.Rprofile`.
- Segredos: `.Renviron`, `.gitignore`, variáveis de ambiente; nunca fixar valores no código.
- Estrutura de projeto; convenções de nomes; README que permite rodar.
- Git: commits pequenos, `.Rhistory` fora do repo, diff de CSVs.

**Exercício no repo:** rode `renv::status()` e `renv::snapshot()`. Depois simulate
outra máquina: renomeie a biblioteca do renv e rode `renv::restore()`.

### Semana 12 — Projeto final e defesa

Entregue algo que outra pessoa consiga rodar:

1. Uma pergunta clara (ex.: "PE se destacou só por tamanho ou por risco?").
2. Pipeline com `run_analysis.R` e `--mock` funcionando.
3. Um gráfico e uma tabela que respondam à pergunta.
4. Um parágrafo de limitações (dados, denominador, causalidade).
5. Testes passando.

**Checkpoint final:** peça para alguém rodar só com o README. Se der erro,
o README ainda não está pronto.

---

## Rotina de estudo recomendada

| Bloco | Duração | O que fazer |
|---|---|---|
| Revisão espaçada | 10 min | reelabore 3 cartões do que viu na semana passada |
| Teoria | 45 min | leia a apostila + documentação oficial de 1 função |
| Prática | 60 min | código no repo, rode, quebre, conserte |
| Escrita | 15 min | responda o checkpoint com palavras suas |
| Fechamento | 10 min | commit com mensagem descrevendo o que aprendeu |

Técnicas: **recall ativo** (feche o arquivo e tente reescrever), **Feynman**
(explique em voz alta para um leigo), **interleaving** (alterne teoria e código
na mesma sessão).

## Recursos

- **R for Data Science (2ª ed.)** — Wickham, Çetinkaya-Rundel & Grolemund: base
  do Fase II e III. https://r4ds.hadley.nz/
- **Advanced R (2ª ed.)** — Wickham: Fase I (escopo, funções, condições).
  https://adv-r.hadley.nz/
- **ggplot2: Elegant Graphics for Data Analysis** — Wickham: visualização.
- **Documentação do `dplyr` / `tidyr` / `readr`** — `vignette(package = "dplyr")`.
- **Base dos Dados** — dicionário dos dados; leia sempre o esquema da tabela
  antes de consultar. https://basedosdados.org/
- **geobr** — malhas e shapefiles do IBGE em R. https://ipeagit.github.io/geobr/

## Matriz de competências (marque quando conseguir sem consultar)

| Competência | Semana |
|---|---|
| Explicar coerção e reciclagem | 1 |
| Escrever uma closure com estado | 2 |
| Depurar com traceback/browser | 3 |
| Usar group_by/summarise/join | 4 |
| Reformatear com pivot_longer | 5 |
| Otimizar uma consulta BigQuery | 6 |
| Diferenciar contagem de taxa | 7 |
| Interpretar lm com cautela | 8 |
| Escolher mapa adequado | 9 |
| Escrever teste com expect_error | 10 |
| Restaurar ambiente com renv | 11 |
| Entregar análise defendível | 12 |
