# Manual do EpidemiR

> **Documento de referência operacional.** Atualizado em 25/11/2026.
> A documentação foi enxugada: o que era histórico ou já foi refeito saiu.
> Aqui está o manual; os outros dois arquivos são o passo a passo inicial e
> o guia dos dados.

---

## Índice da documentação

| Documento | Para que serve | Quando ler |
|---|---|---|
| [`README.md`](../README.md) (raiz) | Visão geral do projeto e avisos de segurança | Antes de tudo |
| **Este arquivo** | **Manual operacional: instalar, rodar, auditar, limpar** | **Sempre** |
| [`05-primeira-uso.md`](05-primeira-uso.md) | Checklist do clone vazio ao primeiro relatório | Na primeira vez |
| [`04-guia-de-dados.md`](04-guia-de-dados.md) | Quais dados, SQL pronta, formato dos CSVs, onde colocar | Antes de buscar dados |
| [`info.md`](../info.md) (raiz) | Estado atual do projeto | Ao voltar ao projeto |

Regra prática: **manual = este arquivo**; os outros dois cobrem a primeira vez
e a origem dos dados. Em caso de divergência, prevalecem o código e este manual.
O material histórico (revisão do script antigo, apostila, roadmap e pesquisa de
raiva) foi removido porque já foi refeito ou não faz parte do pipeline. Se
precisar dele, está no histórico do Git.

---

## 1. Começo rápido (30 segundos, sem internet)

Na raiz do repositório:

```powershell
Rscript run_analysis.R --mock       # dados sintéticos com semente fixa
Rscript tests/test_pipeline.R       # 41 checagens + auditoria [DEBUG]
```

Espere um `=== RESUMO ===` no console e `41 testes passaram`. Se isso falhar,
o problema é local (R/pacotes), não credencial — pare aqui.

> No RStudio, abra `EpidemiR.Rproj` e use **Ctrl+Shift+F10** para rodar o script
> inteiro. Nunca execute linha a linha após um erro: variáveis ficam pela metade
> e aparecem erros falsos como `objeto 'cases' não encontrado`.

---

## 2. Pré-requisitos

| Item | Necessário para | Observação |
|---|---|---|
| R ≥ 4.2 e RStudio | tudo | Use o arquivo `EpidemiR.Rproj` |
| `renv.lock` | reproduzir o ambiente | 57 pacotes; `renv::restore()` |
| `basedosdados`, `dplyr`, `readr` | pipeline | já no lockfile |
| `gcloud` + ADC | dados reais | `gcloud auth application-default login` |
| Termos aceitos no site da Base dos Dados | dados reais | sem isso: `Access denied` |
| `.Renviron` (opcional) | consultar BigQuery | ver §3 |

Se `renv::status()` acusar pacotes fora de sincronia, rode `renv::snapshot()`.
`ggplot2` e `geobr` são opcionais: sem eles o mapa é de bolhas; com eles há
também o coropletico (`R/06_optional_maps.R` está no `.renvignore`).

---

## 3. Como a origem é escolhida

`resolve_data_source()` em `R/01_extract.R` decide nesta ordem:

```
--mock                     -> dados sintéticos (sempre offline)
cache completo em data/raw -> lê os CSVs (sem rede, sem custo)
GCP_BILLING_ID definido    -> consulta BigQuery e salva o cache
sem chave e sem cache      -> avisa, usa mock e grava o motivo no relatório
```

A chave fica em `.Renviron` na raiz (ignorado pelo Git):

```r
GCP_BILLING_ID=id-do-seu-projeto-google-cloud
```

Use o **ID do projeto**, nunca o número de 12 dígitos. Nesta máquina o valor
local é `apidevbase`. Depois de editar, **reinicie o R/RStudio**.

Autenticação do Google: instale o Google Cloud CLI, rode
`gcloud auth application-default login` e aceite os termos de
[SIM](https://basedosdados.org/dataset/5beeec93-cbf3-43f6-9eea-9bee6a0d1683)
e [SINASC](https://basedosdados.org/dataset/bdaa4883-1c44-4cac-8fe4-b5daa768640e).
No Windows a credencial ADC fica em
`%APPDATA%\gcloud\application_default_credentials.json`.

Se abrir um PowerShell antigo e `gcloud` não for reconhecido:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"
```

---

## 4. Fluxo de trabalho padrão

```powershell
# 0. garante o ponto de partida (preserva os .gitkeep)
pwsh -File script/limpar_e_comecar_do_zero.ps1

# 1. importa a origem do BigQuery e valida cada CSV
Rscript tools/buscar_dados_reais.R

# 2. processa e gera tabelas, gráficos e relatório
Rscript run_analysis.R

# 3. audita todas as etapas
Rscript tests/test_pipeline.R

# 4. (opcional) 3 consultas reais extras dentro dos testes
$env:EPIDEMIR_REAL_DATA = "1"
Rscript tests/test_pipeline.R
Remove-Item Env:EPIDEMIR_REAL_DATA
```

Se você já baixou os CSVs manualmente (ver
[guia de dados](04-guia-de-dados.md)), **não use `--no-cache`**: a flag refaz a
consulta e sobrescreve seus arquivos.

---

## 5. Comandos de referência

| Comando | Efeito |
|---|---|
| `Rscript run_analysis.R --mock` | pipeline sintético, sem rede |
| `Rscript run_analysis.R` | cache local → BigQuery → mock (com aviso) |
| `Rscript run_analysis.R --source=sinasc` | usa `cases_sinasc.csv` + `births.csv` |
| `Rscript run_analysis.R --years=2015-2019` | recorte de anos |
| `Rscript run_analysis.R --no-cache` | ignora o cache e consulta de novo (custo) |
| `Rscript run_analysis.R --help` | ajuda da CLI |
| `Rscript tools/buscar_dados_reais.R` | busca e valida a origem em `data/raw/` |
| `Rscript tools/buscar_dados_reais.R <pasta>` | destino alternativo |
| `Rscript tools/verificar_csv.R <arquivo.csv>` | valida um CSV baixado à mão |
| `Rscript tests/test_pipeline.R` | 41 checagens offline + `[DEBUG]` |
| `EPIDEMIR_REAL_DATA=1` nos testes | 44 checagens (3 consultas reais) |
| `pwsh -File script/limpar_e_comecar_do_zero.ps1` | apaga artefatos, mantém `.gitkeep` |
| `... -WhatIf` | simula a limpeza sem apagar nada |

---

## 6. Auditoria dos testes

A suíte `tests/test_pipeline.R` grava CSVs de origem em `tempdir()`, valida com
`verificar_csv_fonte()` e os reimporta pelo mesmo caminho de cache usado pelo
pipeline. Para cada etapa imprime linhas `[DEBUG]` com:

- **linhas e colunas**;
- **NAs por coluna**;
- **chaves `ano + sigla_uf` duplicadas**;
- **faixas de valores numéricos**;
- **linhas esperadas × obtidas**.

Depois confere a consistência origem → transformação → análise → exportação
(os totais de casos e nascidos não mudam) e garante que `data/` do projeto não
foi sujo. Resultado: **41 testes** por padrão, **44** com `EPIDEMIR_REAL_DATA=1`.

Saídas geradas:

```
data/
├── raw/          cases_sim.csv (ou cases_sinasc.csv) + births.csv  [origem]
├── processed/    casos_por_uf_ano.csv, taxas_por_uf_ano.csv, *.rds [gerado]
└── reports/      relatorio.md + fig_*.png                          [gerado]
```

Tudo isso está no `.gitignore`; apenas os `.gitkeep` são versionados.

---

## 7. Limpeza e segurança

Para voltar ao estado "começar do zero":

```powershell
pwsh -File script/limpar_e_comecar_do_zero.ps1        # executa
pwsh -File script/limpar_e_comecar_do_zero.ps1 -WhatIf # só simula
```

Nunca versionar: `.Renviron`, `.Rhistory`, `*.csv`, JSONs de credencial,
notas de OAuth. Antes do commit:

```powershell
git status
git check-ignore -v .Renviron
git ls-files | Select-String -Pattern 'OAuth|Renviron|client_secret|\.csv$'
```

⚠️ Um client secret do Google esteve em `Cliente OAuth criado.md`. O arquivo
está ignorado, mas a credencial deve ser **revogada/rotacionada** no Console;
ela não é necessária para o fluxo de `gcloud auth application-default login`.

---

## 8. Solução de problemas

| Sintoma | Causa | Ação |
|---|---|---|
| `Can't get Google credentials` | sem login do Google | `gcloud auth application-default login` |
| `Credenciais padrao do Google nao encontradas` | ADC fora do lugar | ver caminho do Windows na §3 |
| `Access denied` | termos do dataset não aceitos | aceite no site com o mesmo projeto |
| `Arquivo nao encontrado: .../cases_sim.csv` | origem não foi baixada | `Rscript tools/buscar_dados_reais.R` |
| `Nome nao reconhecido` no `verificar_csv.R` | arquivo com nome diferente | renomeie para `cases_sim.csv`, `cases_sinasc.csv` ou `births.csv` |
| `faltam colunas obrigatorias: total` | baixou microdados brutos | rode a SQL agregada da [guia](04-guia-de-dados.md) |
| `Continuando em MODO MOCK` | sem chave e sem cache | configure `.Renviron` ou importe os CSVs |
| `Motivo do modo mock` no relatório | fallback sem chave/cache | veja a linha do motivo e corrija a origem |
| `gcloud: termo não reconhecido` | PATH da sessão antigo | atualize `$env:Path` (§3) ou faça logoff/logon |
| `objeto 'cases' não encontrado` | linhas executadas fora de ordem | rode o script inteiro (Ctrl+Shift+F10) |
| Cache com dados estranhos | CSV velho/mock | rode o script de limpeza e reimporte |
| `The project is out-of-sync` | lockfile incompleto | `renv::snapshot()` |

---

## 9. Próximos passos

- Primeira vez? Siga o [`05-primeira-uso.md`](05-primeira-uso.md).
- Vai buscar/baixar dados? Use o [`04-guia-de-dados.md`](04-guia-de-dados.md).
- Vai mudar consulta, métrica ou gráfico? O código é a referência:
  `R/01_extract.R`, `R/03_analyze.R`, `R/04_visualize.R`.
- Estado geral do projeto: [`info.md`](../info.md) na raiz.
