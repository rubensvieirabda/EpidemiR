# Extracao ---------------------------------------------------------------------
# Monta SQL parametrizado, busca no BigQuery via basedosdados e mantem cache
# local. Em modo --mock gera dados sinteticos deterministicos (sem rede).

.abstract_sql_text <- function(x, name, pattern = "^[A-Z0-9%_]+$") {
  abort_if(!is.character(x) || length(x) != 1L || !grepl(pattern, x),
           sprintf("%s contem caracteres nao permitidos na SQL: '%s'", name, x))
  x
}

#' Monta a consulta de casos (obitos ou nascidos com anomalia).
build_query_cases <- function(cfg) {
  pattern <- .abstract_sql_text(cfg$cid_cases, "cid_cases")
  field   <- .abstract_sql_text(cfg$field_cases, "field_cases", "^[A-Za-z0-9_]+$")
  y0 <- min(cfg$years)
  y1 <- max(cfg$years)

  sprintf(
    "SELECT
    ano,
    sigla_uf,
    COUNT(*) AS total
FROM `%s`
WHERE ano BETWEEN %d AND %d
  AND %s LIKE '%s'
GROUP BY ano, sigla_uf
ORDER BY sigla_uf, ano",
    cfg$table_cases, y0, y1, field, pattern
  )
}

#' Denominador: total de nascidos vivos por UF/ano (sem filtro de CID).
build_query_births <- function(cfg) {
  y0 <- min(cfg$years)
  y1 <- max(cfg$years)
  sprintf(
    "SELECT
    ano,
    sigla_uf,
    COUNT(*) AS nascidos
FROM `%s`
WHERE ano BETWEEN %d AND %d
GROUP BY ano, sigla_uf
ORDER BY sigla_uf, ano",
    cfg$table_births, y0, y1
  )
}

#' Executa uma consulta com cache em disco e mensagens de erro contexto.
#'
#' @param query     SQL ja validada.
#' @param cache_path Caminho do CSV de cache.
#' @param label     Nome legivel da consulta (para logs).
read_sql_cached <- function(query, cache_path, label, cfg) {
  abort_if(!requireNamespace("readr", quietly = TRUE),
           "Pacote 'readr' e necessario para o cache.")
  make_dir(dirname(cache_path))

  if (isTRUE(cfg$use_cache) && file.exists(cache_path)) {
    log_info("Cache encontrado (%s): %s", label, cache_path)
    return(readr::read_csv(cache_path, show_col_types = FALSE))
  }

  abort_if(!requireNamespace("basedosdados", quietly = TRUE),
           "Pacote 'basedosdados' nao instalado. Rode install.packages('basedosdados').")
  abort_if(!nzchar(cfg$billing_id),
           "GCP_BILLING_ID vazio. Defina no .Renviron: GCP_BILLING_ID=SEU_PROJETO")

  log_info("Consultando BigQuery (%s)...", label)
  df <- tryCatch(
    basedosdados::read_sql(query, billing_project_id = cfg$billing_id),
    error = function(e) {
      stop(sprintf("Falha na consulta '%s': %s", label, conditionMessage(e)),
           call. = FALSE)
    }
  )
  readr::write_csv(df, cache_path)
  log_info("Cache salvo: %s", cache_path)
  df
}

#' Dados sinteticos reproduciveis para testar o pipeline sem internet/BigQuery.
mock_cases <- function(cfg) {
  set.seed(cfg$seed)
  grid <- expand.grid(ano = cfg$years,
                      sigla_uf = UF_LOOKUP$sigla,
                      stringsAsFactors = FALSE)
  w <- setNames(round(60 + 6 * seq_len(nrow(UF_LOOKUP))), UF_LOOKUP$sigla)
  w[c("PE", "SP", "RJ", "MG", "BA")] <- c(280, 400, 220, 260, 210)

  spike <- ifelse(grid$ano %in% c(2015L, 2016L), 1.8, 1.0)
  extra <- ifelse(grid$sigla_uf == "PE" & grid$ano %in% c(2015L, 2016L), 2.5, 1.0)
  grid$total <- as.integer(round(w[grid$sigla_uf] * spike * extra *
                                   stats::runif(nrow(grid), 0.95, 1.05)))
  grid[order(grid$sigla_uf, grid$ano), c("ano", "sigla_uf", "total")]
}

mock_births <- function(cfg) {
  set.seed(cfg$seed + 1L)
  grid <- expand.grid(ano = cfg$years,
                      sigla_uf = UF_LOOKUP$sigla,
                      stringsAsFactors = FALSE)
  w <- setNames(round(60 + 6 * seq_len(nrow(UF_LOOKUP))), UF_LOOKUP$sigla)
  w[c("PE", "SP", "RJ", "MG", "BA")] <- c(280, 400, 220, 260, 210)
  grid$nascidos <- as.integer(round(180000 * (w[grid$sigla_uf] / mean(w)) *
                                      stats::runif(nrow(grid), 0.90, 1.10)))
  grid[order(grid$sigla_uf, grid$ano), c("ano", "sigla_uf", "nascidos")]
}

#' Extrai casos e denominador, retornando uma lista com os dois data.frames.
extract_all <- function(cfg) {
  if (isTRUE(cfg$mock)) {
    log_info("Modo MOCK: gerando dados sinteticos (seed=%d).", cfg$seed)
    return(list(cases = mock_cases(cfg), births = mock_births(cfg)))
  }

  list(
    cases = read_sql_cached(
      build_query_cases(cfg),
      file.path(cfg$dirs$raw, sprintf("cases_%s.csv", cfg$source)),
      sprintf("casos/%s", cfg$source),
      cfg
    ),
    births = read_sql_cached(
      build_query_births(cfg),
      file.path(cfg$dirs$raw, "births.csv"),
      "nascidos-vivos",
      cfg
    )
  )
}
