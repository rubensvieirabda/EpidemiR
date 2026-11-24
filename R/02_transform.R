# Transformacao ----------------------------------------------------------------
# Validacao, limpeza, grade completa e enriquecimento com metadados de UF.
# Separar esta etapa da extracao e o que permite testar sem BigQuery.

.normalize_counts <- function(df, value_col, cfg, label) {
  assert_columns(df, c("ano", "sigla_uf", value_col), label)

  out <- df[, c("ano", "sigla_uf", value_col)]
  names(out)[3L] <- "value"
  out$ano <- suppressWarnings(as.integer(out$ano))
  out$sigla_uf <- toupper(trimws(as.character(out$sigla_uf)))
  out$value <- suppressWarnings(as.numeric(out$value))

  bad <- is.na(out$ano) | is.na(out$sigla_uf) |
    is.na(out$value) | out$value < 0 | !nzchar(out$sigla_uf)
  if (any(bad)) {
    log_info("%s: descartando %d linhas com chave/valor invalidos.", label, sum(bad))
    out <- out[!bad, , drop = FALSE]
  }

  bad_uf <- !out$sigla_uf %in% UF_LOOKUP$sigla
  if (any(bad_uf)) {
    log_info("%s: descartando %d linhas com sigla_uf desconhecida.", label, sum(bad_uf))
    out <- out[!bad_uf, , drop = FALSE]
  }

  out <- out[out$ano %in% cfg$years, , drop = FALSE]
  abort_if(nrow(out) == 0L, sprintf("%s: nenhuma linha valida apos a limpeza.", label))

  out <- dplyr::group_by(out, ano, sigla_uf) |>
    dplyr::summarise(value = sum(value), .groups = "drop") |>
    dplyr::ungroup()
  names(out)[names(out) == "value"] <- value_col
  out
}

.complete_grid <- function(df, cfg, value_col) {
  grid <- expand.grid(ano = cfg$years,
                      sigla_uf = UF_LOOKUP$sigla,
                      stringsAsFactors = FALSE)
  out <- dplyr::left_join(grid, df, by = c("ano", "sigla_uf"))
  out$is_imputed <- is.na(out[[value_col]])
  out[[value_col]] <- ifelse(out$is_imputed, 0, out[[value_col]])
  out
}

add_uf_metadata <- function(df) {
  assert_columns(df, "sigla_uf", "df")
  meta <- UF_LOOKUP[, c("sigla", "nome", "regiao", "lon", "lat")]
  dplyr::left_join(df, meta, by = c("sigla_uf" = "sigla"))
}

#' Casos: conta validada agregada por ano/UF + grade completa + metadados.
prepare_cases <- function(df, cfg) {
  out <- .normalize_counts(df, "total", cfg, "casos")
  out <- .complete_grid(out, cfg, "total")
  out <- add_uf_metadata(out)
  log_info("Casos preparados: %d linhas, %d UFs.",
           nrow(out), length(unique(out$sigla_uf)))
  out
}

#' Denominador de nascidos vivos, no mesmo formato dos casos.
prepare_births <- function(df, cfg) {
  out <- .normalize_counts(df, "nascidos", cfg, "nascidos-vivos")
  out <- .complete_grid(out, cfg, "nascidos")
  out[, c("ano", "sigla_uf", "nascidos")]
}
