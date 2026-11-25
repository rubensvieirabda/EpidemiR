# Primeira utilização — checklist completo

Este guia leva você de um clone vazio até o primeiro relatório. Atualizado em
**25/11/2026**, válido para a branch `develop` (padrão do repositório).

> **Manual completo:** [`README.md`](README.md) nesta pasta reúne comandos,
> auditoria, limpeza e solução de problemas. Este arquivo é o checklist curto.

---

## Checklist rápido (imprima / marque)

```
[ ] 1. git clone https://github.com/rubensvieirabda/EpidemiR.git
[ ] 2. Abrir EpidemiR.Rproj no RStudio
[ ] 3. renv::restore()                       (instala 57 pacotes travados)
[ ] 4. Rscript run_analysis.R --mock         (valida a máquina, sem internet)
[ ] 5. Rscript tests/test_pipeline.R         (41 testes, sem rede)
[ ] 6. Copiar .Renviron.example -> .Renviron e preencher GCP_BILLING_ID
[ ] 7. Reiniciar o R/RStudio
[ ] 8. gcloud auth application-default login
[ ] 9. Aceitar os termos do dataset no site da Base dos Dados
[ ] 10. Rscript tools/buscar_dados_reais.R   (importa e valida a origem)
[ ] 11. Rscript run_analysis.R               (lê o cache real)
[ ] 12. Conferir data/reports/relatorio.md   (NÃO pode dizer MODO MOCK)
```

---

## Passo 1 — Clonar

```powershell
git clone https://github.com/rubensvieirabda/EpidemiR.git
cd EpidemiR
git checkout develop        # já é o padrão, mas garante
```

## Passo 2 — Abrir o projeto

Duplo clique em `EpidemiR.Rproj`. O `.Rprofile` ativa o `renv`
automaticamente. Confirme no console:

```r
renv::status()
# Se acusar pacotes fora de sincronia: renv::snapshot()
```

## Passo 3 — Restaurar o ambiente

```r
renv::restore()
```

Isso instala exatamente as versões do `renv.lock` (57 pacotes). Pode levar
alguns minutos na primeira vez. Se falhar só com `geobr`/`ggplot2`, ignore:
são opcionais e estão no `.renvignore`.

## Passo 4 — Validar sem internet (30 segundos)

```powershell
Rscript run_analysis.R --mock
Rscript tests/test_pipeline.R
```

Esperado: `41 testes passaram` e um `=== RESUMO ===` no console. Se isso
falhar, **pare aqui** — o problema é local, não credencial.

Sem `.Renviron` e sem CSVs em `data/raw/`, `Rscript run_analysis.R` ainda
termina: avisa, usa dados mock e grava o motivo no relatório. A chave só é
necessária para consultar o BigQuery.

Os testes imprimem linhas `[DEBUG]` por etapa (linhas, NAs, chaves duplicadas e
faixas de valores) e **não sujam `data/`**: CSVs, gráficos e relatório vão para
`tempdir()`. A busca real dentro dos testes é opcional:

```powershell
$env:EPIDEMIR_REAL_DATA = "1"   # exige gcloud autenticado + termos aceitos
Rscript tests/test_pipeline.R   # 44 testes (3 consultas reais a mais)
Remove-Item Env:EPIDEMIR_REAL_DATA
```

## Passo 5 — Credenciais (opcional, só para consultar o BigQuery)

```powershell
Copy-Item .Renviron.example .Renviron
notepad .Renviron
```

Conteúdo:

```r
GCP_BILLING_ID=id-do-seu-projeto-google-cloud
```

> Use o **ID do projeto** (ex.: `meu-projeto-424242`), não o número de 12
> dígitos. `.Renviron` está no `.gitignore`: nunca vai para o GitHub.

Depois:

1. **Reinicie o R/RStudio** (variáveis de ambiente só são lidas na largada).
2. Instale o Google Cloud CLI e rode `gcloud auth application-default login`.
3. Abra [SIM](https://basedosdados.org/dataset/5beeec93-cbf3-43f6-9eea-9bee6a0d1683)
   e [SINASC](https://basedosdados.org/dataset/bdaa4883-1c44-4cac-8fe4-b5daa768640e)
   e **aceite os termos** com o mesmo projeto. Sem isso: `Access denied`.

## Passo 6 — Rodar com dados reais

```powershell
Rscript tools/buscar_dados_reais.R     # busca + valida os CSVs de origem
Rscript run_analysis.R                 # SIM + nascidos
Rscript run_analysis.R --source=sinasc # SINASC + nascidos
```

Na primeira execução o pipeline consulta o BigQuery e salva o CSV em
`data/raw/`. Nas seguintes, lê o cache (mais rápido, sem custo).

Confira no console:

```
[hora] Cache encontrado (casos/sim): .../data/raw/cases_sim.csv
```

Se você baixou os CSVs manualmente, **não use `--no-cache`** — a flag refaz a
consulta e sobrescreve seus arquivos.

## Passo 7 — Verificar o resultado

Abra `data/reports/relatorio.md`. Itens de checagem:

- [ ] não contém `MODO MOCK`
- [ ] o console mostrou `dados=cache` (ou `bigquery`) e `mock=FALSE`
- [ ] `Total casos` confere com a origem (o mock gera 35.228 — nunca compare com ele)
- [ ] `Taxa nacional` não é `NA` (se for, falta `births.csv`)
- [ ] gráficos `fig_anos.png`, `fig_top_ufs.png`, `fig_mapa_bolhas.png` existem

---

## Erros rápidos

| Erro | Ação |
|---|---|
| `Can't get Google credentials` | `gcloud auth application-default login` |
| `Credenciais padrao do Google nao encontradas` | ver ADC em `%APPDATA%\gcloud\` (ver [manual](README.md)) |
| `Access denied` | aceitar termos do dataset no site |
| `Arquivo nao encontrado: .../cases_sim.csv` | rode `tools/buscar_dados_reais.R` |
| `Faltam colunas: total` | baixou microdados brutos; rode a SQL agregada |
| `Continuando em MODO MOCK` | chave/cache ausentes (a chave é opcional se houver cache) |
| `gcloud` não reconhecido | sessão antiga: atualize `$env:Path` ou faça logoff/logon |
| dado esquisito | rodar `script/limpar_e_comecar_do_zero.ps1` e importar de novo |

> A tabela completa está no [manual](README.md#8-solução-de-problemas).

## Recomeçar do zero

Apaga CSVs brutos, tabelas, gráficos e relatório, preservando os `.gitkeep`:

```powershell
pwsh -File script/limpar_e_comecar_do_zero.ps1        # executa
pwsh -File script/limpar_e_comecar_do_zero.ps1 -WhatIf # só simula
```

Depois, volte ao passo 1 (ou rode `tools/buscar_dados_reais.R`).

## Próximo assunto

Depois que o pipeline SIM/SINASC estiver rodando, veja
[`06-dados-raiva.md`](06-dados-raiva.md) — onde buscar os dados de raiva e
como mapear cada categoria pedida para os campos reais do SINAN.

## Como subir mudanças

```powershell
git status
git add -A
git commit -m "descreva o que mudou"
git push
```

Antes do `git add`, confirme que `.Renviron`, `.Rhistory`, `*.csv` e JSONs de
credencial **não** aparecem no `git status`.
