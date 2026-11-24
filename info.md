# Ponto de retomada — MapaGenBase

**Salvo em:** 23/11/2026 · **Próxima sessão:** retomar pelo checklist no final.

## Onde estamos

- Pipeline completo criado e testado em modo `--mock` (23 testes passando).
- `renv.lock` sincronizado (57 pacotes).
- Documentação: `docs/00` a `docs/04`. O guia canônico destes passos é
  [`docs/04-guia-de-dados.md`](docs/04-guia-de-dados.md).
- **Ainda não fizemos:** credenciais reais do Google Cloud nem consulta ao
  BigQuery. Tudo até agora foi com dados sintéticos.

---

## Passos salvos

Boa pergunta — esse é o ponto que transforma o projeto de "exercício" em "análise de verdade". Vou te guiar em 5 passos. Também salvei tudo em `docs/04-guia-de-dados.md` para você consultar enquanto executa.

### Ideia-chave primeiro

Você **não é obrigado a baixar nada na mão**. O pipeline já faz isso:

`read_sql_cached()` verifica se `data/raw/cases_sim.csv` existe → se existe, lê do disco; se não existe, consulta o BigQuery e salva o CSV lá. Então "baixar" pode ser automático. O caminho manual existe para você aprender a usar o site e para funcionar sem credenciais configuradas.

### Passo 0 — Credenciais (só para o caminho automático)

1. Crie um projeto no Google Cloud, ative a API BigQuery e copie o **ID do projeto** (ex.: `meu-projeto-424242`).
2. No site da Base dos Dados, abra cada dataset e **aceite os termos** para esse projeto. Sem isso dá `Access denied`.
3. Faça login local: `gcloud auth application-default login` (ou configure `GOOGLE_APPLICATION_CREDENTIALS` com uma chave de conta de serviço).
4. Crie `.Renviron` na raiz (já ignorado pelo Git):

   ```r
   GCP_BILLING_ID=meu-projeto-424242
   ```

Reinicie o R depois. Nosso código passa esse valor direto em `read_sql(query, billing_project_id = ...)`, então **não** precisa de `set_billing_id()`.

### Passo 1 — Quais dados buscar

Você precisa de **3 consultas em 2 tabelas**, mas usa só 2 delas:

| Consulta | Tabela | Filtro | vira arquivo |
|---|---|---|---|
| 1. Casos SIM | `br_ms_sim.microdados` | `causa_basica LIKE 'Q02%'` | `cases_sim.csv` |
| 2. Casos SINASC | `br_ms_sinasc.microdados` | `anomalia_congenita LIKE '%Q02%'` | `cases_sinasc.csv` |
| 3. Denominador | `br_ms_sinasc.microdados` | sem filtro de CID | `births.csv` |

Escolha **1 ou 2** (conforme `--source=sim` ou `--source=sinasc`) e **sempre 3**. O denominador é obrigatório porque `taxa_100k = total / nascidos * 100000`; sem ele você compara tamanho populacional, não risco.

Links: [SIM](https://basedosdados.org/dataset/5beeec93-cbf3-43f6-9eea-9bee6a0d1683) · [SINASC](https://basedosdados.org/dataset/bdaa4883-1c44-4cac-8fe4-b5daa768640e)

SQL pronta (também gerada por `build_query_cases()` / `build_query_births()`):

```sql
-- 1: casos SIM  (troque por Q0% para incluir Q00-Q04)
SELECT ano, sigla_uf, COUNT(*) AS total
FROM `basedosdados.br_ms_sim.microdados`
WHERE ano BETWEEN 2014 AND 2019 AND causa_basica LIKE 'Q02%'
GROUP BY ano, sigla_uf ORDER BY sigla_uf, ano;

-- 2: casos SINASC
SELECT ano, sigla_uf, COUNT(*) AS total
FROM `basedosdados.br_ms_sinasc.microdados`
WHERE ano BETWEEN 2014 AND 2019 AND anomalia_congenita LIKE '%Q02%'
GROUP BY ano, sigla_uf ORDER BY sigla_uf, ano;

-- 3: denominador (sempre)
SELECT ano, sigla_uf, COUNT(*) AS nascidos
FROM `basedosdados.br_ms_sinasc.microdados`
WHERE ano BETWEEN 2014 AND 2019
GROUP BY ano, sigla_uf ORDER BY sigla_uf, ano;
```

### Passo 2 — Qual formato baixar

**CSV separado por vírgula, UTF-8, com o resultado já agregado** (3 colunas, ~162 linhas). É exatamente o que `readr::read_csv()` consome no cache.

- ✅ CSV / ZIP contendo CSV (descompacte)
- ❌ microdados brutos (milhões de linhas, GBs) — rode a SQL antes
- ❌ `.xlsx` (tipos ambíguos); se baixar, converta
- ⚠️ Parquet só se instalar `arrow`

No editor da Base dos Dados: executar a SQL → **Baixar resultado → CSV**.

### Passo 3 — Onde colocar

Na raiz `D:\source\R Lang\MapaGenBase\`:

```
data/raw/
├── cases_sim.csv       ← consulta 1
├── cases_sinasc.csv    ← consulta 2
└── births.csv          ← consulta 3
```

Os nomes são **exatos** — `extract_all()` monta os caminhos com `sprintf("cases_%s.csv", cfg$source)` e `"births.csv"`. `data/raw/*` já está no `.gitignore`.

Conteúdo esperado (cabeçalho minúsculo, sem coluna `X` de índice):

```csv
ano,sigla_uf,total
2014,AC,12
2014,AL,45
```

### Passo 4 — Como consumir

```powershell
Rscript tools/verificar_csv.R data/raw/cases_sim.csv   # confere antes
Rscript tools/verificar_csv.R data/raw/births.csv

Rscript run_analysis.R                 # lê o cache, não consulta o BigQuery
Rscript run_analysis.R --source=sinasc # usa cases_sinasc.csv
```

Se o cache for encontrado você verá:

```
[22:40:10] Cache encontrado (casos/sim): D:/.../data/raw/cases_sim.csv
```

**Não use `--no-cache` se você baixou na mão** — ele refaz a consulta e sobrescreve seu arquivo.

Depois disso: `prepare_cases()` limpa e completa a grade 27 UFs × anos; `add_rates()` junta com `births.csv`; saídas em `data/processed/` e `data/reports/relatorio.md`.

### Erros que você vai encontrar (e a causa)

| Mensagem | Solução |
|---|---|
| `GCP_BILLING_ID vazio` | `.Renviron` na raiz + reiniciar R |
| `Access denied` | aceitar termos do dataset no site |
| `Could not load default credentials` | `gcloud auth application-default login` |
| `Faltam colunas obrigatorias: total` | você baixou microdados; rode a SQL agregada |
| `Modo MOCK` no relatório | tira a flag `--mock` |
| dados estranhos | apague o CSV em `data/raw/` e rode de novo |

Criei também `tools/verificar_csv.R` (testado aqui com os CSVs gerados) para você validar cada download antes de rodar o pipeline.

---

## Checklist para amanhã

- [ ] Ver `gcloud auth list` / fazer `gcloud auth application-default login`
- [ ] Pegar o **ID do projeto** no Google Cloud e ativar a API BigQuery
- [ ] Aceitar os termos do dataset no site da Base dos Dados
- [ ] Escrever `GCP_BILLING_ID=...` no `.Renviron` e reiniciar o R
- [ ] Rodar `Rscript run_analysis.R` (primeiro com SIM)
- [ ] Conferir `data/reports/relatorio.md` — **não** pode dizer `MODO MOCK`
- [ ] Depois testar `--source=sinasc` e comparar os dois relatórios
- [ ] Dúvida/erro novo: voltar aqui e colar a mensagem exata

> Referência completa e sempre atualizada: [`docs/04-guia-de-dados.md`](docs/04-guia-de-dados.md).
