# EpidemiR

Projeto de estudos de R que virou um pipeline de análise de dados de saúde pública:
consulta a [Base dos Dados](https://basedosdados.org/) (SIM / SINASC) sobre
microcefalia, trata os dados, calcula taxas por 100 mil nascidos vivos ajusta
tendências e gera gráficos + relatório.

> **Comece aqui:** checklist de primeira utilização em
> [`docs/05-primeira-uso.md`](docs/05-primeira-uso.md). O guia dos dados de
> raiva está em [`docs/06-dados-raiva.md`](docs/06-dados-raiva.md). O ponto de
> retomada das sessões está em [`info.md`](info.md).

O script original da aula (`BaseMap.R`) foi removido: não compilava (blocos
Markdown dentro de `.R`) e continha um ID de billing exposto. O histórico da
revisão está em `docs/00-revisao-critica.md`.

## Começo rápido (30 segundos, sem internet)

```r
Rscript run_analysis.R --mock
Rscript tests/test_pipeline.R
```

O modo `--mock` gera dados sintéticos com semente fixa: ideal para aprender,
testar e garantir que nada depende de credenciais.

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

As consultas são salvas em `data/raw/` e reaproveitadas na próxima execução
(`--no-cache` força uma nova consulta, com custo no BigQuery; sem chave, nesse
caso, o pipeline cai para mock com aviso). O relatório registra a origem e,
quando aplicável, o motivo do modo mock.

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
tests/test_pipeline.R   30 checagens, sem dependências externas
tools/verificar_csv.R   valida um CSV baixado antes de usar
data/raw|processed|reports   saídas geradas (não versionadas)
docs/                   revisão crítica, apostila, roadmap, guia de dados
info.md                 ponto de retomada da sessão de estudos
.Renviron.example       modelo de configuracao (sem segredo)
```

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [docs/00-revisao-critica.md](docs/00-revisao-critica.md) | O que estava errado no script original e como foi corrigido |
| [docs/01-apostila-teorica.md](docs/01-apostila-teorica.md) | Apostila profunda de R (tipos, escopo, tidyverse, SQL, estatística, performance) |
| [docs/02-roadmap-estudos.md](docs/02-roadmap-estudos.md) | Plano de estudos de 12 semanas |
| [docs/03-arquitetura-e-uso.md](docs/03-arquitetura-e-uso.md) | Arquitetura, contratos dos módulos, como estender, troubleshooting |
| [docs/04-guia-de-dados.md](docs/04-guia-de-dados.md) | Dados SIM/SINASC: quais buscar, formato, onde colocar, como consumir |
| [docs/05-primeira-uso.md](docs/05-primeira-uso.md) | **Comece aqui**: checklist do clone ao primeiro relatório |
| [docs/06-dados-raiva.md](docs/06-dados-raiva.md) | Onde buscar raiva, campos exatos, animais e regiões de maior impacto |

## Segurança

- Nenhuma credencial é versionada: `.Renviron`, `.Rhistory`, chaves `*.json` de
  conta de serviço e dados gerados estão no `.gitignore`.
- O ID de billing é **opcional** e vai somente no `.Renviron` local (use o
  modelo `.Renviron.example`). O código lê com `Sys.getenv("GCP_BILLING_ID")`;
  sem ele, usa cache local ou dados mock.
- O ID exposto no script original foi removido junto com o arquivo. Se ele já
  esteve em um repositório público, **revoque/rotacione o projeto no Google
  Cloud** — apagar do git não desfaz vazamento anterior.
- Antes de cada commit: `git status` + uma busca por números de 12 dígitos e
  por `GCP_BILLING_ID=`.
