# Guia prático: buscar, baixar e consumir os dados

Este guia responde a quatro perguntas: **quais dados**, **qual formato**,
**onde colocar** e **como o projeto consome**.

---

## 0. Primeiro: entenda que "baixar" aqui pode ser automático

O pipeline já faz o download por você. Em `R/01_extract.R`, a função
`read_sql_cached()` funciona assim:

```
Existe data/raw/cases_sim.csv?
├── SIM  -> lê o CSV do disco (não consulta o BigQuery, não gasta cota)
└── NÃO  -> executa a SQL no BigQuery -> salva CSV em data/raw/ -> continua
```

Então você tem **dois caminhos**:

| Caminho | Quando usar | O que você faz |
|---|---|---|
| **A. Automático (recomendado)** | tem Google Cloud e quer o pipeline completo | só roda `Rscript run_analysis.R` |
| **B. Manual pelo site** | quer aprender a consultar na interface, ou está sem credenciais configuradas | roda a SQL no site, baixa o CSV, coloca em `data/raw/` |

Os dois terminam com **os mesmos arquivos** na mesma pasta. O passo 5 é comum aos dois.

---

## 1. Credenciais e termos (necessário para o caminho A)

1. **Google Cloud**: crie um projeto (o free tier dá 1 TB/mês de consultas —
   muito mais do que o suficiente aqui). Ative a API **BigQuery**. Copie o
   **ID do projeto** (ex.: `meu-projeto-424242`), não o número de projeto.
2. **Base dos Dados**: abra cada dataset abaixo e clique em aceitar os termos /
   autorizar o uso via BigQuery com esse projeto. Sem isso você recebe
   `Access denied` mesmo com as credenciais corretas.
3. **Autenticação local** (uma das opções):
   - `gcloud auth application-default login` (Google Cloud CLI instalada), ou
   - conta de serviço: `GOOGLE_APPLICATION_CREDENTIALS=C:\caminho\chave.json`
4. **`.Renviron` na raiz do projeto** (já ignorado pelo Git):

   ```r
   GCP_BILLING_ID=meu-projeto-424242
   ```

   Reinicie o R/RStudio depois de editar. Nosso código lê essa variável e
   passa direto para `basedosdados::read_sql(query, billing_project_id = ...)`.
   Não é preciso chamar `set_billing_id()`.

> O script legado `BaseMap.R` e o `.Rhistory` foram removidos antes da
> publicação por conterem um ID de projeto exposto. Se esse projeto já foi
> usado em algum repositório público, **revoque/rotacione no Google Cloud**.
> Use sempre o ID do seu próprio projeto no `.Renviron`.

---

## 2. Quais dados buscar

Você precisa de **três consultas**, duas tabelas:

| # | O que representa | Tabela | Coluna de CID | Onde fica no pipeline |
|---|---|---|---|---|
| 1 | Óbitos por microcefalia (SIM) | `basedosdados.br_ms_sim.microdados` | `causa_basica LIKE 'Q02%'` | `cases_sim.csv` |
| 2 | Nascidos vivos com anomalia (SINASC) | `basedosdados.br_ms_sinasc.microdados` | `anomalia_congenita LIKE '%Q02%'` | `cases_sinasc.csv` |
| 3 | **Denominador**: total de nascidos vivos | `basedosdados.br_ms_sinasc.microdados` | sem filtro de CID | `births.csv` |

Você **não precisa das três**. Escolha uma fonte de casos (1 **ou** 2) e
**sempre** busque o denominador (3):

- `--source=sim` → consultas 1 + 3
- `--source=sinasc` → consultas 2 + 3

### Por que o denominador é obrigatório?

Comparar `COUNT(*)` de SP com o de RO mede tamanho populacional, não risco.
O projeto calcula `taxa_100k = total / nascidos * 100000`. Sem `births.csv`
a taxa fica `NA`.

### Links dos datasets

- SIM: https://basedosdados.org/dataset/5beeec93-cbf3-43f6-9eea-9bee6a0d1683
- SINASC: https://basedosdados.org/dataset/bdaa4883-1c44-4cac-8fe4-b5daa768640e

Dentro da página, use a aba **Tabelas** → `microdados` para ver o dicionário
de colunas (confirmar `ano`, `sigla_uf`, `causa_basica`, `anomalia_congenita`).

### SQL pronta para copiar no editor da Base dos Dados

**Casos — SIM**

```sql
SELECT
    ano,
    sigla_uf,
    COUNT(*) AS total
FROM `basedosdados.br_ms_sim.microdados`
WHERE ano BETWEEN 2014 AND 2019
  AND causa_basica LIKE 'Q02%'
GROUP BY ano, sigla_uf
ORDER BY sigla_uf, ano
```

**Casos — SINASC**

```sql
SELECT
    ano,
    sigla_uf,
    COUNT(*) AS total
FROM `basedosdados.br_ms_sinasc.microdados`
WHERE ano BETWEEN 2014 AND 2019
  AND anomalia_congenita LIKE '%Q02%'
GROUP BY ano, sigla_uf
ORDER BY sigla_uf, ano
```

**Denominador (sempre)**

```sql
SELECT
    ano,
    sigla_uf,
    COUNT(*) AS nascidos
FROM `basedosdados.br_ms_sinasc.microdados`
WHERE ano BETWEEN 2014 AND 2019
GROUP BY ano, sigla_uf
ORDER BY sigla_uf, ano
```

> Para incluir todas as malformações do encéfalo (Q00-Q04), troque o filtro
> do SIM por `causa_basica LIKE 'Q0%'`. No R:
> `default_config(cid_cases = "Q0%")`.

---

## 3. Qual formato baixar

| Formato | Usar? | Por quê |
|---|---|---|
| **CSV (UTF-8, vírgula)** | **Sim — o padrão deste projeto** | é exatamente o que `readr::read_csv()` lê no cache |
| `.zip` contendo CSV | Sim, descompacte antes | o site costuma zipar downloads grandes |
| `.xlsx` / `.xls` | Não, a menos que converta | planilhas têm tipos ambíguos e acentos problemáticos |
| Parquet / `.parquet` | Só se você instalar `arrow` | mais eficiente, mas nosso leitor de cache é `read_csv` |
| RDS | Não para download | é formato interno do R, gerado pelo próprio pipeline |

**Baixe o resultado da consulta já agregado** (3 colunas, ~162 linhas), não a
tabela de microdados bruta — essa tem milhões de linhas e vários GB.

No editor da Base dos Dados (ou no console do BigQuery): executar →
**Baixar resultado** → **CSV**. Se baixar pelo botão "Baixar" do dataset,
você receberá os microdados completos; nesse caso, rode antes a SQL acima.

---

## 4. Onde colocar os arquivos

Na raiz do projeto (`D:\source\R Lang\MapaGenBase\`):

```
data/
├── raw/                       <- AQUI entram os downloads
│   ├── cases_sim.csv          <- consulta 1
│   ├── cases_sinasc.csv       <- consulta 2
│   └── births.csv             <- consulta 3 (denominador)
├── processed/                 <- gerado pelo pipeline (não toque)
└── reports/                   <- gráficos e relatório (gerado)
```

Os nomes são **exatos**, porque `extract_all()` monta os caminhos assim:

```r
file.path(cfg$dirs$raw, sprintf("cases_%s.csv", cfg$source))  # cases_sim / cases_sinasc
file.path(cfg$dirs$raw, "births.csv")
```

`data/raw/*` está no `.gitignore`: seus CSVs baixados não vão para o Git.
Isso é bom — dado baixado é artefato, não código.

### Colunas obrigatórias

`cases_sim.csv` e `cases_sinasc.csv`:

```
ano,sigla_uf,total
2014,AC,12
2014,AL,45
...
```

`births.csv`:

```
ano,sigla_uf,nascidos
2014,AC,15000
2014,AL,60000
...
```

Cabeçalho em minúsculas, sem espaços, separado por vírgula. O `total` e o
`nascidos` devem ser contagens inteiras. Não inclua colunas `X` de índice —
se usar `write.csv()` no R, passe `row.names = FALSE`.

---

## 5. Como o projeto consome (e como conferir)

### Conferindo na mão antes de rodar

```r
d <- readr::read_csv("data/raw/cases_sim.csv", show_col_types = FALSE)
names(d)     # "ano" "sigla_uf" "total"
str(d)
stopifnot(all(c("ano", "sigla_uf", "total") %in% names(d)),
          !anyNA(d$ano), !anyNA(d$sigla_uf), all(d$total >= 0))
```

Ou, do terminal:

```powershell
Rscript tools/verificar_csv.R data/raw/cases_sim.csv
Rscript tools/verificar_csv.R data/raw/births.csv
```

### Rodando o pipeline

```powershell
# Caminho A: com credenciais; se cache existir, só lê o CSV
Rscript run_analysis.R

# Caminho A forçando consulta nova (sobrescreve o cache)
Rscript run_analysis.R --no-cache

# Trocar a fonte de casos (usa cases_sinasc.csv)
Rscript run_analysis.R --source=sinasc

# Se você baixou manualmente, NÃO use --no-cache: ele refaria a consulta
```

Quando o cache é encontrado, você verá no console:

```
[22:40:10] Cache encontrado (casos/sim): D:/.../data/raw/cases_sim.csv
```

Depois disso, `prepare_cases()` converte tipos, remove UFs inválidas, agrega
por `ano`/`sigla_uf`, completa a grade 27 UFs × 6 anos e cola nome/região.
`add_rates()` junta com `births.csv`. Os resultados aparecem em:

- `data/processed/casos_por_uf_ano.csv`
- `data/processed/taxas_por_uf_ano.csv`
- `data/reports/relatorio.md` e `.png`

---

## 6. Erros comuns

| Mensagem | Causa | Solução |
|---|---|---|
| `GCP_BILLING_ID vazio` | `.Renviron` ausente ou R não reiniciado | crie o arquivo na raiz e reinicie a sessão |
| `Access denied` / `permission denied` | termos do dataset não aceitos | aceite no site da Base dos Dados para o seu projeto |
| `Could not load default credentials` | Google sem login | `gcloud auth application-default login` |
| `Cache encontrado` mas dados estranhos | CSV velho/mock | apague o arquivo em `data/raw/` e rode de novo |
| `colunas obrigatorias: total` | baixou microdados em vez do resultado da SQL | rode a SQL agregada e salve como `cases_sim.csv` |
| `Falha na consulta ...` com `LIKE` | filtro de CID diferente do esquema | confira `causa_basica` / `anomalia_congenita` no dicionário |
| `Modo MOCK` no relatório | esqueceu `--mock` | rode sem essa flag |

---

## Resumo em uma frase

**Baixe o resultado agregado das consultas acima em CSV, coloque em
`data/raw/cases_sim.csv` (ou `cases_sinasc.csv`) e `data/raw/births.csv`,
e rode `Rscript run_analysis.R` sem `--mock` — o pipeline encontra os arquivos
pelo nome e pula a consulta ao BigQuery.**
