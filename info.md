# Ponto de retomada — EpidemiR

**Atualizado em:** 25/11/2026 · **Branch padrão:** `develop` ·
**Repo:** https://github.com/rubensvieirabda/EpidemiR

> Este arquivo registra apenas o **estado atual**. O histórico de problemas
> já corrigidos foi removido: ele não faz mais parte do fluxo e pode ser
> recuperado no histórico do Git se necessário.

---

## Pronto

- Pipeline SIM/SINASC completo: extração → transformação → análise →
  gráficos e relatório.
- **41 testes** passam offline, com auditoria `[DEBUG]` por etapa
  (linhas/colunas, NAs, chaves `ano+sigla_uf` duplicadas, faixas e totais).
  Com `$env:EPIDEMIR_REAL_DATA=1`, são **44** (3 consultas reais extras).
- Testes gravam tudo em `tempdir()` e verificam que `data/` não foi sujo.
- `GCP_BILLING_ID` é opcional: cache local primeiro; sem chave e sem cache,
  o pipeline avisa, usa mock e grava o motivo no relatório.
- Google Cloud SDK `594.0.1` instalado; `gcloud auth application-default login`
  feito. ADC em `%APPDATA%\gcloud\application_default_credentials.json`.
- `.Renviron` local com `GCP_BILLING_ID=apidevbase` (ID do projeto, nunca o
  número de 12 dígitos). Arquivo ignorado pelo Git.
- Busca real validada em 25/11: `cases_sim.csv` (148 linhas, 27 UFs, 1.168
  casos) e `births.csv` (162 linhas, 27 UFs, 17.572.340 nascidos).
- Pipeline já rodou em cache real (`dados=cache`, `mock=FALSE`): período
  2014–2019, pico 2016 (250 casos), top UF SP (175), taxa nacional 6,65/100 mil.
- `renv.lock` com 57 pacotes; `ggplot2`/`geobr` opcionais.
- Documentação enxuta: manual operacional + guia de dados + primeira uso.

---

## Estado de `data/`

Limpo: apenas os três `.gitkeep` versionados. Nenhum CSV, gráfico ou relatório
fica no repositório.

```powershell
pwsh -File script/limpar_e_comecar_do_zero.ps1        # apaga artefatos
pwsh -File script/limpar_e_comecar_do_zero.ps1 -WhatIf # simula
```

---

## Retomar em 4 comandos

```powershell
pwsh -File script/limpar_e_comecar_do_zero.ps1   # ponto de partida
Rscript tools/buscar_dados_reais.R               # importa e valida a origem
Rscript run_analysis.R                           # processa e gera o relatório
Rscript tests/test_pipeline.R                    # auditoria das etapas
```

Na primeira vez, veja [`docs/05-primeira-uso.md`](docs/05-primeira-uso.md).
Para comandos, credenciais, limpeza e erros, use
[`docs/README.md`](docs/README.md). Para SQL e formato dos CSVs,
[`docs/04-guia-de-dados.md`](docs/04-guia-de-dados.md).

---

## Em aberto

1. **Rotacionar o client secret** que esteve em `Cliente OAuth criado.md`.
   O arquivo está no `.gitignore` e o segredo não foi usado no fluxo do
   `gcloud`, mas apareceu em texto: deve ser revogado no Console do Google.
2. **Raiva/SINAN**: não há código no pipeline. O guia antigo foi removido na
   limpeza da documentação; se o tema voltar, a pesquisa precisa ser refeita.

---

## Antes de commitar

```powershell
git status
git check-ignore -v .Renviron
git ls-files | Select-String -Pattern 'OAuth|Renviron|client_secret|\.csv$'
```

Nunca versionar `.Renviron`, `.Rhistory`, `*.csv` ou JSONs de credencial.
