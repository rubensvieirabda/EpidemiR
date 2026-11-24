# Revisão crítica do `BaseMap.R` (registro histórico)

> O arquivo original foi **removido do repositório antes da publicação** porque
> não compilava e continha um ID de billing exposto. Esta revisão é mantida como
> registro didático do que foi corrigido; valores sensíveis foram substituídos
> por `<ID_DO_PROJETO>`.

Revisão do script original com.base no estado em que foi encontrado. A coluna
"Destino" mostra onde cada problema foi tratado no pipeline novo.

Resumo: **1 problema bloqueante, 4 de alta/média-alta prioridade, 7 de média/baixa**.
O script não chega a rodar — e, se chegasse, ainda teria problemas de custo,
reprodutibilidade e interpretação estatística.

---

## 1. BLOQUEANTE — o arquivo não é um script R válido

**Onde:** linhas 6 e 12 (` ```{r} ` e ` ```` `).

```r
# Fontes:
```{r}
Sistema de Informações sobre Mortalidade (SIM)
```

```

Isso é Markdown de notebook colado dentro de um `.R`. Para o parser de R,
crases delimitam **nomes não sintáticos**; três crases seguidos de `{r}` geram:

```
PARSE ERROR: tentativa de usar um nome de variável com comprimento zero
```

`source("BaseMap.R")` falha antes de executar qualquer linha. O `rlang::last_trace()`
no `.Rhistory` é provavelmente a tentativa de diagnosticar isso.

**Correção:** em arquivo `.R`, comentário é só `#`. Blocos `{r}` pertencem a
`.Rmd`/`.qmd`. No projeto novo, toda a narrativa foi para `docs/` e o código
para `R/*.R`.
**Destino:** `R/*.R` + `docs/`.

---

## 2. ALTA — credencial de billing exposta no código

**Onde:** linha 15 (`set_billing_id("<ID_DO_PROJETO>")`), `.Renviron` e `.Rhistory`.

O `.Renviron` já existe com `GCP_BILLING_ID`, mas o script **ignora** a variável
e fixa o valor direto no código. Consequências:

- quem commitar o repositório publica o projeto do Google Cloud;
- trocar de projeto exige editar código;
- o valor aparece também no histórico interativo.

**Correção aplicada:** `default_config()` lê `Sys.getenv("GCP_BILLING_ID")`;
`read_sql_cached()` falha com mensagem clara se estiver vazio e passa o valor
como argumento (`basedosdados::read_sql(query, billing_project_id = ...)`)
em vez de depender de estado global. `.Renviron` e `.Rhistory` entram no
`.gitignore`.
**Destino:** `R/00_config.R`, `R/01_extract.R`, `.gitignore`.

> Recomendação fora do código: revogue/rotacione o projeto no Cloud se o repo
> for ou tiver sido público.

---

## 3. ALTA — `renv.lock` está incompleto

**Onde:** `renv.lock` (contém apenas o pacote `renv`).

O projeto usa `basedosdados` e `dplyr`, mas o lockfile não os registra. O aviso
`- The project is out-of-sync -- use renv::status() for details.` aparece em toda
execução. Na prática, "reprodutibilidade" aqui é só promessa: outra máquina
restauraria um ambiente vazio.

**Correção:** rodar `renv::snapshot()` depois de estabilizar as dependências e
versionar o lockfile. Ver `docs/03-arquitetura-e-uso.md`.
**Destino:** `renv.lock` + guia de uso.

---

## 4. MÉDIA-ALTA — nenhum tratamento de erro, retry ou cache

**Onde:** linha 44 (`micro.uf <- read_sql(query_obitos)`).

Uma falha de rede, cota ou permissão derruba tudo sem contexto. Pior: cada
reexecução refaz a consulta e **cobra de novo** no BigQuery, mesmo quando os
dados não mudaram.

**Correção aplicada:** `tryCatch()` com mensagem que identifica a consulta,
cache em `data/raw/` e flag `--no-cache` explícita para refazer.
**Destino:** `R/01_extract.R::read_sql_cached()`.

---

## 5. MÉDIA — saída para o diretório corrente

**Onde:** linha 45 (`write.csv(micro.uf, "micro_uf.csv", row.names = FALSE)`).

O arquivo cai em qualquer pasta em que o R esteja, misturando dado gerado com
código. Além disso, `write.csv` depende de `options("OutDec")` e pode gerar
encoding inconsistente no Windows.

**Correção aplicada:** diretórios derivados da raiz do projeto (`DIRS`),
`readr::write_csv()` com caminho absoluto e saídas separadas em
`data/processed/` e `data/reports/`.
**Destino:** `R/00_config.R`, `R/05_export.R`.

---

## 6. MÉDIA — contagem bruta não é comparação válida

**Onde:** linhas 18-41 (`COUNT(*) ... GROUP BY ano, sigla_uf`).

São contagens absolutas. SP e PE têm números de nascimentos muito diferentes;
comparar "casos" diretamente troca **risco** por **tamanho populacional**.
Falta um denominador.

**Correção aplicada:** segunda consulta para total de nascidos vivos (SINASC),
join por `ano`/`sigla_uf` e `taxa_100k = total / nascidos * 1e5`. O relatório
mostra contagem **e** taxa.
**Destino:** `R/01_extract.R::build_query_births()`, `R/03_analyze.R::add_rates()`.

---

## 7. MÉDIA — dependência declarada mas não usada

**Onde:** linha 3 (`library(dplyr)`).

O script carrega `dplyr` e nunca usa uma única função dele. É um custo de
carregamento e uma pista falsa para quem lê o código.

**Correção aplicada:** `dplyr` é usado de verdade, sempre como `dplyr::verbo()`,
sem `library()` — fica explícito de onde vem cada função.
**Destino:** `R/02_transform.R`, `R/03_analyze.R`.

---

## 8. MÉDIA — zero validação de dados

**Onde:** toda a linha 44.

`ano` pode vir como string, `sigla_uf` pode ter `NA`, espaços ou "SP " com
espaço trailing, `total` pode ser negativo ou duplicado. Nada disso é checado.
Um `NA` em `sigla_uf` simplesmente desaparece silenciosamente de um gráfico.

**Correção aplicada:** `assert_columns()`, `.normalize_counts()` (conversão de
tipos, remoção de linhas inválidas, checagem contra as 27 siglas conhecidas),
agregação por chave e grade completa ano × UF com `is_imputed`.
**Destino:** `R/utils.R`, `R/02_transform.R`.

---

## 9. BAIXA — semântica do CID discutível

**Onde:** linhas 25 e 38.

- SIM: `causa_basica LIKE 'Q02%'` — correto para prefixo.
- SINASC: `anomalia_congenita LIKE '%Q02%'` — se o campo for uma lista de CIDs
  separados por delimitador, `%Q02%` pode casar `Q020`, `AQ02`, etc.

Não é necessariamente erro (depende do esquema real da tabela), mas a regra
deve ser **documentada e testada**, não deixada em comentário ("Troque por Q0%").
**Correção aplicada:** o padrão sai da config (`cid_cases`), é validado por
regex e a consulta gerada é coberta por teste para as duas fontes.
**Destino:** `R/00_config.R`, `tests/test_pipeline.R`.

---

## 10. BAIXA — SQL montada sem controle sobre valores interpolados

**Onde:** linhas 18-41.

Hoje os valores são literais, então não há risco real. Mas o padrão "colar
texto na SQL" é o primeiro passo para uma injeção quando alguém transformar
`ano` ou o CID em parâmetro de uma interface.

**Correção aplicada:** `validate_config()` e `.abstract_sql_text()` só permitem
inteiros e `[A-Z0-9%_]` no padrão do CID. Há teste que tenta injetar
`Q02'; DROP TABLE x` e espera erro.
**Destino:** `R/00_config.R`, `R/01_extract.R`, tests.

---

## 11. BAIXA — convenções de nomenclatura

**Onde:** linha 44 (`micro.uf`).

O ponto evoca S3 (`print.micro.uf`) mas aqui é só um nome. Prefira `snake_case`
(`casos_por_uf`) — consistente com tidyverse e evita confusão.
**Correção aplicada:** nomes de funções e objetos em `snake_case`, funções
internas prefixadas com `.`, constantes em maiúsculas (`UF_LOOKUP`, `DIRS`).

---

## 12. BAIXA — nenhum teste, nenhum README, tudo global

**Onde:** projeto como um todo.

Sem testes, mudar uma consulta quebra silenciosamente. Sem README, ninguém sabe
como rodar. Tudo em variáveis globais impede testar uma etapa isolada.

**Correção aplicada:** 6 módulos com contratos de entrada/saída, 23 checagens em
`tests/test_pipeline.R` (modo mock, sem rede), README e esta documentação.
**Destino:** projeto inteiro.

---

## Quadro-resumo: antes × depois

| Antes (`BaseMap.R`) | Depois |
|---|---|
| Markdown dentro de `.R` → não parseia | código puro em `R/*.R` |
| ID de billing no código | `Sys.getenv()` + `.gitignore` |
| lockfile só com `renv` | `renv::snapshot()` documentado |
| consulta sem cache/tryCatch | cache + erro contextual |
| `write.csv()` no cwd | caminhos derivados da raiz |
| contagens brutas | contagens + taxa por 100 mil |
| `dplyr` carregado sem uso | verbs namespaced e usados |
| sem validação | validação + grade completa |
| padrão CID em comentário | parâmetro validado e testado |
| escopo global | funções com contrato |
| sem testes | 23 checagens offline |
