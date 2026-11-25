# Ponto de retomada — EpidemiR

**Última atualização:** 25/11/2026 (auditoria + origem real) ·
**Próxima sessão:** comece por este bloco ↓

---

## 🟢 ESTADO ATUAL — retomar aqui

**Repo público:** https://github.com/rubensvieirabda/EpidemiR
**Branch padrão:** `develop` · **Working tree:** limpo · **Sincronizada com:** `origin/develop`
**Último commit:** confirme com `git log -1` (renomeação, chave opcional, auditoria)

### Já pronto

- Pipeline SIM/SINASC completo, 41 testes passando sem dependências externas.
- Testes com auditoria `[DEBUG]` por etapa e saídas em `tempdir()`: `data/`
  permanece limpo (só `.gitkeep`).
- `GCP_BILLING_ID` opcional: cache local primeiro; sem chave e sem cache,
  o pipeline avisa e cai para mock (motivo registrado no relatório).
- `.Renviron` local criado com `GCP_BILLING_ID=apidevbase` (ID, não o número
  `233842803077`); arquivo ignorado pelo Git.
- `renv.lock` sincronizado (57 pacotes), `renv::status()` limpo.
- `develop` é a default; `main` é só referência do commit inicial.
- Documentação `docs/00` a `docs/06`:
  - [`04-guia-de-dados.md`](docs/04-guia-de-dados.md) — SIM/SINASC
  - [`05-primeira-uso.md`](docs/05-primeira-uso.md) — **checklist do clone ao relatório**
  - [`06-dados-raiva.md`](docs/06-dados-raiva.md) — **raiva: campos, animais, regiões**
- Nenhum segredo versionado; `.Renviron` apagado e substituído por
  `.Renviron.example`.

### Ainda pendente

1. **Credenciais reais** (opcional, só para consultar o BigQuery) — `.Renviron`
   precisa ser recriado (`Copy-Item .Renviron.example .Renviron`) +
   instalar o `gcloud` (hoje não está no PATH) + `gcloud auth application-default login`
   + aceitar termos no site da Base dos Dados.
2. **Consulta real ao BigQuery** — nada foi consultado ainda; tudo foi mock.
3. **Decisão sobre raiva** — implementar ou não `R/07_raiva.R` no pipeline.
   Hoje o guia `docs/06` já responde "onde buscar", mas não há código.
4. **Rotacionar o ID antigo** vazado no Google Cloud.

### Checklist de retomada (copie e marque)

```
[ ] Abrir info.md (este arquivo) e README.md
[ ] Seguir docs/05-primeira-uso.md do passo 1 ao 7
[ ] Rscript run_analysis.R --mock  (confere que nada quebrou)
[ ] Copiar .Renviron.example -> .Renviron e preencher ID do projeto
[ ] gcloud auth application-default login
[ ] Aceitar termos SIM + SINASC no site da Base dos Dados
[ ] Rscript run_analysis.R  (conferir: relatório NÃO pode dizer MODO MOCK)
[ ] Decidir: implementar R/07_raiva.R?
[ ] Se a lista de categorias era de dengue/zika e não raiva → me avisar
```

> Se aparecer erro novo, cole a **mensagem exata** aqui e no chat.

---

## Histórico abaixo (referência)

As seções seguintes mantêm o passo a passo original, notas de publicação e
a pesquisa de raiva em detalhe. O conteúdo canônico está nos `docs/`.

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

Na raiz `D:\source\R Lang\EpidemiR\`:

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

---

## Publicação no GitHub (feito em 23/11/2026)

- Repo público: **https://github.com/rubensvieirabda/EpidemiR** (renomeado de MapaGenBase)
- Branch `main`, commit inicial `9144c87`, 30 arquivos.
- Removidos antes de publicar: `BaseMap.R` (não compilava + ID exposto),
  `.Rhistory`, `.Renviron`, CSVs/PNGs/RDS gerados.
- **`.Renviron` foi apagado**: recrie na próxima sessão com
  `Copy-Item .Renviron.example .Renviron` e preencha seu ID de projeto.
- **Importante**: o ID antigo vazou. Revogue/rotacione o projeto no Google Cloud.

### Como subir mudanças da próxima vez

```powershell
git status
git add -A
git commit -m "descreva o que mudou"
git push
```

### Regra de ouro antes de cada push

```powershell
git status
# conferir que .Renviron / .Rhistory / *.csv / *.json de credencial NAO aparecem
```

---

## Atualização de 23/11/2026 (segunda parte)

- Criada a branch **`develop`**, enviada ao GitHub e tornada **default**.
  O `main` continua existindo como referência do commit inicial.
- Novos documentos:
  - [`docs/05-primeira-uso.md`](docs/05-primeira-uso.md) — checklist do clone
    ao primeiro relatório (renv, mock, credenciais, termos, execução).
  - [`docs/06-dados-raiva.md`](docs/06-dados-raiva.md) — onde buscar raiva,
    campos exatos do SINAN, espécies e regiões de maior impacto.
- **Achado importante sobre raiva:** a ficha de Raiva Humana do SINAN **não
  tem** campos "curado com/sem sequela". O termo oficial para "falso positivo"
  é **Descartado** (`classi_fin = 2`); para "recuperado", o termo adequado é
  **sobrevivente** — só 2 casos em toda a história do Brasil. Ver §2 do doc.
- Números oficiais (MS, jun/2026): 54 casos em 2010–2026; morcegos lideram
  (23), depois primatas (12), cães (10), felinos (5), raposas (2). Nordeste e
  Norte concentram os impactos; último caso canino em 2015 (MS).

### Próximos passos (atualizados)

- [ ] Seguir o checklist de [`docs/05-primeira-uso.md`](docs/05-primeira-uso.md)
- [ ] Depois, decidir se implementamos `R/07_raiva.R` no pipeline
- [ ] Se a lista de categorias veio de outro agravo (dengue/zika), me avisar

---

## Atualização de 24/11/2026 — renomeação para EpidemiR

- Projeto renomeado de **MapaGenBase** para **EpidemiR** (pasta local, repo
  GitHub e `MapaGenBase.Rproj` → `EpidemiR.Rproj`).
- Atualizados `R/00_config.R` (detecção da raiz pelo `.Rproj`), `run_analysis.R`,
  `R/05_export.R`, `tests/test_pipeline.R`, `README.md` e `docs/01`, `03` a `05`.
- Instruções de início conferidas em
  [`docs/05-primeira-uso.md`](docs/05-primeira-uso.md) — checklist completo do
  clone ao relatório, com link no topo do `README.md`.
- Validação: `Rscript tests/test_pipeline.R` → **41 testes passaram**, sem
  gerar arquivos versionados novos.
- Commit `ffdbff6` (`Docs: renomear projeto de MapaGenBase para EpidemiR`)
  enviado com `git push origin develop`, seguido do commit que atualizou este
  ponto de retomada. `develop` == `origin/develop`, tree limpa.
- Única menção ao nome antigo mantida de propósito: nota histórica na seção
  "Publicação no GitHub" ("renomeado de MapaGenBase").

---

## Atualização de 24/11/2026 — chave GCP opcional

- `GCP_BILLING_ID` deixou de ser obrigatório. A decisão agora está em
  `resolve_data_source()` (`R/01_extract.R`), executada por `run_analysis.R`:
  1. `--mock` → dados sintéticos;
  2. cache completo em `data/raw/` (`cases_sim.csv` + `births.csv`) → lê do
     disco, sem precisar de chave;
  3. sem chave e sem cache (ou com `--no-cache`) → dois avisos `ATENCAO`,
     `cfg$mock = TRUE` e pipeline termina normalmente;
  4. com chave → consulta BigQuery como antes.
- O relatório passa a incluir "Motivo do modo mock" quando o fallback acontece,
  e o log mostra `dados=mock|cache|bigquery`.
- `log_warn()` criado em `R/utils.R`; `read_sql_cached()` agora diz
  "Sem GCP_BILLING_ID e sem cache..." em vez de só "vazio".
- Teste real feito aqui: `Rscript run_analysis.R` sem `.Renviron` e sem CSVs
  terminou em ~2s com `=== RESUMO ===` (35.228 casos mock).
- Testes automatizados: **41 checagens**, todas passando. README e `docs/00`,
  `03`, `04`, `05` atualizados.
- A máquina local **não tem `gcloud` no PATH**: para dados reais ainda é preciso
  instalá-lo, autenticar e aceitar os termos dos datasets.

---

## Atualização de 25/11/2026 — auditoria, origem importada e projeto GCP

- Novo projeto Google Cloud: nome **ApiDevBase**, ID **`apidevbase`**, número
  `233842803077` (número **nunca** é usado como billing ID).
- `.Renviron` local criado com `GCP_BILLING_ID=apidevbase` (fora do Git).
- `data/raw/`, `data/processed/` e `data/reports/` limpos: só `.gitkeep`.
- `tests/test_pipeline.R` reescrito:
  - origem sintética gravada como CSV em `tempdir()` e importada de volta pelo
    mesmo caminho de cache do pipeline;
  - `verificar_csv_fonte()` (em `tools/verificar_csv.R`) valida colunas, NAs,
    negativos e UFs antes do processamento;
  - auditoria `[DEBUG]` em cada etapa: linhas/colunas, NAs por coluna,
    chaves `ano+sigla_uf` duplicadas, faixas numéricas e contagens esperadas;
  - consistência verificada entre origem → transformação → análise → exportação
    (totais de casos e nascidos preservados);
  - saídas em `tempdir()`, com checagem explícita de que `data/` não foi sujo;
  - busca real opt-in: `$env:EPIDEMIR_REAL_DATA=1; Rscript tests/test_pipeline.R`.
- Novo `tools/buscar_dados_reais.R`: checa pré-requisitos sem rede, consulta o
  BigQuery com `apidevbase`, grava os CSVs e valida cada um. Corrigido para
  encontrar a credencial ADC no Windows (`%APPDATA%\gcloud\...`).
- `tools/verificar_csv.R` agora expõe `verificar_csv_fonte()` e continua
  funcionando como CLI.
- ⚠️ Existe o arquivo não versionado `Cliente OAuth criado.md` com um
  **client secret do Google**. Foi adicionado ao `.gitignore`, mas a credencial
  deve ser **revogada/rotacionada** no Console (e o arquivo idealmente movido
  para fora do projeto). Nunca commitar nem compartilhar esse JSON.

---

## Atualização de 25/11/2026 — dados reais funcionando

- Google Cloud SDK `594.0.1` instalado via `winget` (`Google.CloudSDK`). O PATH
  do usuário já contém `%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin`;
  sessões antigas precisam de `$env:Path += "..."` ou logoff/logon.
- `gcloud auth application-default login` concluído. ADC salva em
  `C:\Users\rlyra\AppData\Roaming\gcloud\application_default_credentials.json`,
  com `apidevbase` como projeto de cota.
- `Rscript tools/buscar_dados_reais.R` executado com sucesso:
  - `data/raw/cases_sim.csv`: 148 linhas, 27 UFs, total 1.168;
  - `data/raw/births.csv`: 162 linhas, 27 UFs, total 17.572.340.
- `Rscript run_analysis.R` rodou em **cache real** (`dados=cache`, `mock=FALSE`):
  período 2014–2019, pico 2016 (250 casos), top UF SP (175), taxa nacional 6,65
  / 100 mil. Relatório sem `MODO MOCK` (confirmado no cabeçalho).
- `EPIDEMIR_REAL_DATA=1 Rscript tests/test_pipeline.R` → **44 testes passaram**
  (3 consultas reais extras, recorte 2014–2015, gravadas só em `tempdir()`).
- Estado atual de `data/`: limpo (só `.gitkeep`) após validar o novo script.
- Criado `script/limpar_e_comecar_do_zero.ps1`: apaga o conteúdo de `data/raw`,
  `data/processed` e `data/reports`, preserva os `.gitkeep`, funciona de qualquer
  diretório e aceita `-WhatIf` para simular. Testado nos dois modos.
