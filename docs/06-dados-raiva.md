# Dados de raiva — onde buscar e como mapear cada categoria

Pesquisa feita em **23/11/2026** em fontes oficiais. Todo campo, arquivo e
número abaixo foi verificado no dicionário do Ministério da Saúde, no FTP do
DATASUS e na página do Ministério da Saúde.

> Este é um documento de **pesquisa**, ainda não implementado no pipeline.
> Para executar o que já existe (SIM/SINASC), veja o
> [manual operacional](README.md).

---

## 0. Resposta curta

| O que você quer | Onde buscar (endereço exato) | Campo / categoria |
|---|---|---|
| Casos registrados (notificações) | SINAN-Raiva (`RAIVBR*.dbc`) | todas as linhas |
| "Falso positivo" | **o termo oficial é `Descartado`** | `classi_fin = 2` |
| Óbitos | `dt_obito` preenchido / `criterio = 2` | `dt_obito`, `criterio` |
| Recuperados **com** sequela | ⚠️ **não existe na ficha de raiva** | ver §2 |
| Recuperados **sem** sequela | ⚠️ **não existe na ficha de raiva** | ver §2 |
| Animais (espécie do agressor) | `especie_n`, `esp_out` | §5 |
| Regiões de maior impacto | `sg_uf`, `id_mn_resi` | §5 |

**Fontes oficiais (URLs exatas):**

- Dicionário de dados SINAN — Raiva Humana (v5.0, revisado em abril/2012):
  <https://app.wiki.saude.es.gov.br/vigilancia/microdados/dic_dados_raiva_v5.pdf>
- Página do Ministério da Saúde — Raiva Humana (dados até jun/2026):
  <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/raiva-humana>
- Página do Ministério da Saúde — Raiva Animal:
  <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/raiva-animal>
- Dataset SINAN na Base dos Dados:
  <https://basedosdados.org/dataset/f51134c2-5ab9-4bbc-882f-f1034603147a>
- Espelho indexado dos arquivos DBC (útil para conferir nomes/períodos):
  <https://quantilica.com/alpaca/dados/sinan-raiv>

---

## 1. A correção conceitual mais importante

Os termos que você ouviu — **falso positivo, recuperados com sequela,
recuperados sem sequela** — são da **ficha genérica do SINAN** (usada em
dengue, chikungunya, zika etc.), no campo "Evolução do caso".

**A ficha de Raiva Humana não tem esse campo.** Motivo clínico: raiva sintomática
é quase sempre letal. O próprio Ministério da Saúde afirma na página oficial:

> "Na história dos casos de raiva humana no Brasil, apenas **dois pacientes
> sobreviveram**; todos os outros evoluíram para óbito."

Consequência prática:

|termo que você pediu | o que usar em raiva | por quê |
|---|---|---|
| falsos positivos | **`Descartado`** (`classi_fin = 2`) | é o Sinônimo oficial de notificação que não confirmou |
| recuperados com sequela | **`criterio = 3` (Evolução clínica)** **com `dt_obito` vazio** | é o mais próximo que existe; "sequela" não é registrado |
| recuperados sem sequela | **não há campo**; reportar como `sobrevivente` derivado de `is.na(dt_obito) & classi_fin == 1` | só 2 casos em toda a história |
| óbitos | `dt_obito` não nulo ou `criterio = 2` | `criterio = 2` = "Óbito com clínica compatível + vínculo epidemiológico" |

> **Termo mais adequado para "recuperado": `sobrevivente`.** É o termo usado
> pelo Ministério e pelo Protocolo de Milwaukee. Se precisar diferenciar
> "com/sem sequela" no seu trabalho, você terá que buscar em **prontuários/
> estudos de caso** (os 2 sobreviventes brasileiros), não no SINAN.

Se a sua lista de categorias veio de uma frase de exercício sobre **dengue,
chikungunya ou zika**, me avise: nesses agravos o campo `evolucao` existe com
os valores "Curou sem sequela / Curou com sequela / Óbito / ...". Para raiva,
use o mapeamento acima e registre a ressalva no relatório.

---

## 2. Campos exatos do dicionário (Raiva Humana)

Verificados no PDF oficial:

| Campo no DBC | Nome no dicionário | Valores |
|---|---|---|
| `classi_fin` | Classificação final | `1` = Confirmado; `2` = Descartado |
| `criterio` | Critério de confirmação/descarte | `1` = Laboratório; `2` = Óbito com clínica compatível + vínculo epidemiológico; `3` = Evolução clínica |
| `dt_obito` | Data do óbito | data |
| `dt_encerra` | Data de encerramento | data |
| `especie_n` | Espécie do animal agressor | código (ver §5) |
| `esp_out` | Outra espécie | texto livre |
| `sg_uf` / `sg_uf_not` | UF de residência / notificação | sigla |
| `id_mn_resi` | Município de residência | código IBGE |
| `nu_ano` / `dt_notific` | ano / data da notificação | — |
| `varia_vir` | Variante viral | AgV1, AgV2, AgV3, sagui... |
| `vacinad` | Animal agressor vacinado? | 1 = sim, 2 = não, 9 = ignorado |

Outros campos clínicos presentes: `aerofobia`, `hidrofobi`, `disfagia`,
`parestesi`, `agressivi`, `paralisia`, `agitacao`, `febre` (todos 1 = sim,
2 = não, 9 = ignorado) — úteis para descrever o quadro.

**Atenção:** a ficha tem 94 colunas e os códigos mudaram ao longo dos anos. O
próprio Base dos Dados avisa: "recomendamos acessar o dicionário e os
diretórios para entender como traduzir os códigos".

---

## 3. Rota A — DataSUS direto (recomendada; sem Google Cloud)

### 3.1 Arquivos exatos no FTP

```
/dissemin/publicos/SINAN/DADOS/FINAIS/RAIVBR07.dbc   ...  RAIVBR24.dbc  (2007–2024, definitivos)
/dissemin/publicos/SINAN/DADOS/PRELIM/RAIVBR25.dbc                    (2025, preliminar)
/dissemin/publicos/SINAN/DADOS/PRELIM/RAIVBR26.dbc                    (2026, preliminar)
```

Servidor: `ftp.datasus.gov.br`. Os arquivos são pequenos (~4–15 KB por ano),
porém **não há raiva em quase todos os anos** — o total de casos de 2007 a
2026 é pequeno (ver §5). Isso é normal, não é download falhado.

### 3.2 Código R (pacote `microdatasus` ≥ 3.0)

```r
install.packages("microdatasus")

library(microdatasus)

# 1. descobrir o nome exato do sistema no servidor (faça isso primeiro)
subset(datasus_information_systems(), system == "SINAN")
# procure a linha de raiva: "SINAN-RAIVA" (ou o alias antigo "SINAN-RAIV")

# 2. baixar
raiva_raw <- fetch_datasus(
  year_start = 2010,
  year_end   = 2024,
  information_system = "SINAN-RAIVA",
  track_source = TRUE
)

# 3. processar (traduz códigos para rótulos)
raiva <- process_sinan(raiva_raw, information_system = "SINAN-RAIVA")

# 4. salvar para o projeto (formato que o pipeline já entende)
readr::write_csv(raiva, "data/raw/raiva_casos.csv")
```

> Se `SINAN-RAIVA` não existir na sua versão do pacote, use o alias
> `SINAN-RAIV` (presente desde as versões antigas) ou rode o `subset()` acima
> para copiar o nome exato.

### 3.3 Alternativa sem pacote nenhum

Baixe os `.dbc` com um cliente FTP e abra no **TabWin** (programa oficial do
DATASUS) ou converta com `read.dbc::read.dbc()`.

---

## 4. Rota B — Base dos Dados / BigQuery

1. Abra <https://basedosdados.org/dataset/f51134c2-5ab9-4bbc-882f-f1034603147a>
   (slug curto: <https://basedosdados.org/dataset/br-ms-sinan>).
2. Na aba **Tabelas**, escolha a tabela de microdados geral (a mesma usada
   pelo pipeline em `R/01_extract.R` para SIM/SINASC).
3. Filtre o agravo de raiva (`id_agravo`) antes de agregar.
4. Aceite os termos do dataset para o seu projeto Google Cloud e use o ID desse
   projeto em `GCP_BILLING_ID` no `.Renviron` (nunca o número de 12 dígitos).

SQL esqueleto (confirme o nome da tabela e o código do agravo no seletor do
site antes de rodar):

```sql
SELECT
    nu_ano AS ano,
    sg_uf,
    CASE classi_fin WHEN '1' THEN 'Confirmado'
                    WHEN '2' THEN 'Descartado' END AS classificacao,
    CASE criterio   WHEN '1' THEN 'Laboratorio'
                    WHEN '2' THEN 'Obito_clinica_compativel'
                    WHEN '3' THEN 'Evolucao_clinica' END AS criterio,
    CASE WHEN dt_obito IS NOT NULL OR dt_obito <> '' THEN 1 ELSE 0 END AS obito,
    especie_n,
    COUNT(*) AS total
FROM `basedosdados.br_ms_sinan.microdados`
WHERE id_agravo = 'RAIV'
  AND nu_ano BETWEEN 2010 AND 2024
GROUP BY ano, sg_uf, classificacao, criterio, obito, especie_n
ORDER BY ano, sg_uf
```

> ⚠️ A busca por "raiva" no site da Base dos Dados retorna **0 datasets
> dedicados**. A fonte canônica e mais confiável é o DBC do DATASUS (Rota A).
> Use a Rota B se você quiser integrar tudo no mesmo `read_sql()` do pipeline.

---

## 5. Animais e regiões de maior impacto (números oficiais)

Fonte: Ministério da Saúde, página Raiva Humana, atualizada em **11/06/2026**.

**Período 2010–2026: 54 casos humanos no Brasil**, distribuição por espécie
agressora (Tabela 2 oficial):

| Espécie agressora | Casos | % |
|---|---:|---:|
| **Morcegos (quirópteros)** | **23** | 42,6% |
| **Primatas não humanos (sagui etc.)** | **12** | 22,2% |
| **Cães** | 10 | 18,5% |
| **Felinos (gatos)** | 5 | 9,3% |
| **Raposas** | 2 | 3,7% |
| Bovino | 1 | 1,9% |
| Cervídeo | 1 | 1,9% |

**Leitura:** hoje a principal fonte de infecção no país é o **morcego**. O
Brasil está há 10 anos sem raiva humana transmitida por cães — os últimos
casos foram em **2013 (Maranhão)** e **2015 (Mato Grosso do Sul)**, variantes
AgV1/AgV2. O último caso com variante 2 foi em 2013. A variante 3 (morcegos)
domina o cenário atual, com crescente participação de **saguis**.

**Regiões/estados com maior impacto histórico recente:**

| Região | Onde concentrar a busca |
|---|---|
| **Nordeste** | Maranhão, Ceará, Piauí, Pernambuco, Paraíba — ciclo canino antigo e, hoje, primatas (sagui) |
| **Norte** | Pará (surto de 10 casos em **Melgaço, 2018**, por morcegos), Amapá, Tocantins |
| **Sudeste** | Minas Gerais (variante 3, incluindo aldeia indígena em 2022) e Rio de Janeiro |
| **Sul** | Santa Catarina (2019), Paraná (2018) |
| **Centro-Oeste** | Mato Grosso e Mato Grosso do Sul (últimos casos caninos) |

Tabelas oficiais para aprofundar (links diretos da página do MS):

- Tabela 1 — casos por ano: <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/arquivos/tabela-1.pdf>
- Tabela 2 — casos por espécie animal agressora: <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/arquivos/tabela-2.pdf>
- Tabela 3 — evolução clínica/óbitos: <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/arquivos/tabela-3.pdf>
- Tabela 4 — sobreviventes: <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/arquivos/tabela-4.pdf>
- Tabela 5 — espécie × variante genética (2010–2025): <https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/arquivos/tabela-5-casos-de-raiva-humana-por-especie-animal-agressora-e-variante-genetica-brasil-2010-a-2025.pdf>

---

## 6. Como ligar isso ao pipeline atual

O pipeline hoje lê `cases_sim.csv` / `cases_sinasc.csv` + `births.csv`. Para
raiva você **não tem denominador de nascidos** — a taxa por 100 mil não se
aplica. Use contagens e, no máximo, taxa por milhão de habitantes (precisaria
de população do IBGE).

Sugestão de novo módulo (quando decidirmos implementar):

```
R/07_raiva.R   -> lê data/raw/raiva_casos.csv (Rota A)
                  -> classifica confirmado/descartado/obito/sobrevivente
                  -> agrega por ano, UF e especie_n
                  -> gera data/reports/raiva_relatorio.md
```

Até lá, o jeito mais rápido é rodar o código da Rota A, salvar o CSV e
fazer `dplyr::count(raiva, nu_ano, sg_uf, especie_n, classi_fin, criterio)`.

---

## 7. Armadilhas

| Risco | Como evitar |
|---|---|
| chamar `Descartado` de "falso positivo" no relatório | use o termo oficial e explique o sinônimo |
| procurar "curado com sequela" no SINAN-Raiva | não existe; use `sobrevivente` e cite os 2 casos históricos |
| achar que arquivo pequeno está corrompido | raiva é doença rara; poucos registros é esperado |
| misturar anos preliminares (2025/2026) com definitivos | filtre `PRELIM` se quiser série fechada |
| confundir UF de notificação com a de residência | use `sg_uf` (residência) para impacto, `sg_uf_not` para atendimento |
| usar taxa por 100 mil nascidos | sem sentido aqui; raiva não é desfecho neonatal |
