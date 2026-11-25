# EpidemiR

Projeto de estudos de R que virou um pipeline de análise de dados de saúde pública:
consulta a [Base dos Dados](https://basedosdados.org/) (SIM / SINASC) sobre
microcefalia, trata os dados, calcula taxas por 100 mil nascidos vivos, ajusta
tendências e gera gráficos + relatório.

> **Comece aqui:** o manual operacional (comandos + auditoria + limpeza +
> erros) está em [`docs/README.md`](docs/README.md). O checklist da primeira
> vez está em [`docs/05-primeira-uso.md`](docs/05-primeira-uso.md), a origem
> dos dados em [`docs/04-guia-de-dados.md`](docs/04-guia-de-dados.md) e o
> estado atual em [`info.md`](info.md).

O projeto foi refeito do zero: o script original da aula não compilava e
continha um ID de billing exposto. Documentação histórica e material de estudo
que não fazem mais parte do fluxo foram removidos (recuperáveis no Git).

## Começo rápido (30 segundos, sem internet)

```r
Rscript run_analysis.R --mock
Rscript tests/test_pipeline.R
```

O modo `--mock` gera dados sintéticos com semente fixa: ideal para aprender,
testar e garantir que nada depende de credenciais.

## Estado do ambiente

- `data/raw`, `data/processed` e `data/reports` estão **limpos** (só os
  `.gitkeep`). Nenhum dado bruto ou artefato é versionado.
- Credenciais são locais: `.Renviron` com `GCP_BILLING_ID=apidevbase` e login
  do Google feito via `gcloud auth application-default login` (ADC).
- Testes: **41 checagens** por padrão (sem rede) e **44** com busca real ligada
  (`$env:EPIDEMIR_REAL_DATA=1`), sempre com saídas em `tempdir()`.

Fluxo recomendado:

```powershell
pwsh -File script/limpar_e_comecar_do_zero.ps1   # garante o ponto de partida
Rscript tools/buscar_dados_reais.R               # importa a origem do BigQuery
Rscript run_analysis.R                           # processa e gera o relatório
Rscript tests/test_pipeline.R                    # auditoria das etapas
```

## Com dados reais (chave opcional)

Se `data/raw/cases_sim.csv` e `data/raw/births.csv` já existirem, o pipeline lê
o cache e **não pede chave alguma**. Sem chave e sem cache, ele avisa e roda em
modo mock, gerando o relatório normalmente. Para consultar o BigQuery, configure
o ID de billing:

1. Copie `.Renviron.example` para `.Renviron` na raiz e preencha com o **ID do
   seu projeto** (este arquivo **nunca** deve ser versionado):

   ```powershell
   Copy-Item .Renviron.example .Renviron
   ```

   ```r
   GCP_BILLING_ID=seu-projeto-do-google-cloud
   ```

2. Rode:

   ```r
   Rscript run_analysis.R                         # SIM: óbitos com CID Q02
   Rscript run_analysis.R --source=sinasc         # SINASC: nascidos com anomalia
   Rscript run_analysis.R --years=2014-2019 --no-cache
   ```

Para buscar a origem **antes** de rodar o pipeline (e validar cada CSV):

```powershell
Rscript tools/buscar_dados_reais.R            # grava cases_*.csv + births.csv em data/raw/
Rscript tools/verificar_csv.R data/raw/cases_sim.csv
```

Para apagar tudo e recomeçar do zero (preserva os `.gitkeep`):

```powershell
pwsh -File script/limpar_e_comecar_do_zero.ps1
pwsh -File script/limpar_e_comecar_do_zero.ps1 -WhatIf   # só simula
```

As consultas são reaproveitadas na próxima execução (`--no-cache` força uma
nova consulta, com custo no BigQuery; sem chave, nesse caso, o pipeline cai para
mock com aviso). O relatório registra a origem e, quando aplicável, o motivo do
modo mock.

## Estrutura

```
run_analysis.R          entry point + CLI
R/utils.R               logging, validação, safe_png, helpers
R/00_config.R           caminhos, parâmetros, tabela das 27 UFs
R/01_extract.R          SQL parametrizado + cache + dados mock
R/02_transform.R        limpeza, grade completa, metadados
R/03_analyze.R          contagens, taxas, tendências, resumo
R/04_visualize.R        gráficos base R
R/05_export.R           CSV/RDS + relatório markdown
R/06_optional_maps.R    coroplético opcional (fora do renv)
tests/test_pipeline.R   41 checagens + auditoria [DEBUG], sem rede por padrão
tools/verificar_csv.R   valida um CSV baixado antes de usar
tools/buscar_dados_reais.R  busca a origem no BigQuery com o .Renviron
script/limpar_e_comecar_do_zero.ps1  limpa data/ e preserva os .gitkeep
data/raw|processed|reports   saídas geradas (não versionadas)
docs/                   manual operacional, guia de dados, primeira utilização
info.md                 estado atual do projeto
.Renviron.example       modelo de configuracao (sem segredo)
```

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [docs/README.md](docs/README.md) | **Manual operacional**: comandos, origem dos dados, auditoria, limpeza, erros |
| [docs/05-primeira-uso.md](docs/05-primeira-uso.md) | Checklist do clone ao primeiro relatório |
| [docs/04-guia-de-dados.md](docs/04-guia-de-dados.md) | Dados SIM/SINASC: quais buscar, formato, onde colocar, como consumir |

O que era histórico ou já foi refeito saiu da documentação. Se precisar de
algum arquivo antigo, ele continua no histórico do Git.

## Segurança

- Nenhuma credencial é versionada: `.Renviron`, `.Rhistory`, chaves `*.json` de
  conta de serviço, notas de OAuth e dados gerados estão no `.gitignore`.
- Use sempre o **ID do projeto** (`apidevbase`), nunca o número de 12 dígitos.
  O login do `gcloud` grava a credencial ADC fora do repositório.
- O ID de billing é **opcional** e vai somente no `.Renviron` local (use o
  modelo `.Renviron.example`). O código lê com `Sys.getenv("GCP_BILLING_ID")`;
  sem ele, usa cache local ou dados mock.
- O ID exposto no script original foi removido junto com o arquivo. Se ele já
  esteve em um repositório público, **revoque/rotacione o projeto no Google
  Cloud** — apagar do git não desfaz vazamento anterior.
- ⚠️ Um client secret do Google esteve em `Cliente OAuth criado.md`. O arquivo
  está ignorado, mas a credencial deve ser **revogada/rotacionada** no Console;
  ela não é necessária para o fluxo de `gcloud auth application-default login`.
- Antes de cada commit: `git status` + uma busca por números de 12 dígitos e
  por `GCP_BILLING_ID=`.
