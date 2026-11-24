# Analise ----------------------------------------------------------------------
# Contagens, taxas por denominador, tendencias e resumo executivo.

summarize_by_uf <- function(cases) {
  assert_columns(cases, c("sigla_uf", "total"), "cases")
  out <- dplyr::group_by(cases, sigla_uf, nome, regiao) |>
    dplyr::summarise(total = sum(total), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(total))
  out
}

summarize_by_year <- function(cases) {
  assert_columns(cases, c("ano", "total"), "cases")
  dplyr::group_by(cases, ano) |>
    dplyr::summarise(total = sum(total), .groups = "drop") |>
    dplyr::arrange(ano)
}

rank_uf <- function(cases, n = 10L) {
  utils::head(summarize_by_uf(cases), n)
}

#' Junta o denominador e calcula casos por 100 mil nascidos vivos.
add_rates <- function(cases, births) {
  assert_columns(births, c("ano", "sigla_uf", "nascidos"), "births")
  den <- births[, c("ano", "sigla_uf", "nascidos")]
  out <- dplyr::left_join(cases, den, by = c("ano", "sigla_uf"))
  out$taxa_100k <- ifelse(!is.na(out$nascidos) & out$nascidos > 0,
                          out$total / out$nascidos * 1e5,
                          NA_real_)
  out
}

#' Ajusta uma reta por UF (split-apply-combine em base R + stats::lm).
fit_trends <- function(cases) {
  assert_columns(cases, c("ano", "sigla_uf", "total"), "cases")

  fit_one <- function(d) {
    out <- data.frame(sigla_uf = d$sigla_uf[1L],
                      n = nrow(d),
                      slope = NA_real_,
                      r2 = NA_real_,
                      p_value = NA_real_,
                      direction = "insuficiente",
                      stringsAsFactors = FALSE)
    if (nrow(d) < 3L || length(unique(d$ano)) < 3L) return(out)

    fit <- tryCatch(stats::lm(total ~ ano, data = d), error = function(e) NULL)
    if (is.null(fit)) return(out)

    s <- summary(fit)
    out$slope   <- unname(stats::coef(fit)[2L])
    out$r2      <- unname(s$r.squared)
    out$p_value <- unname(s$coefficients[2L, 4L])
    out$direction <- if (is.na(out$p_value)) "indefinida" else if (out$p_value < 0.05) {
      if (out$slope > 0) "crescente" else "decrescente"
    } else "estavel"
    out
  }

  out <- do.call(rbind, lapply(split(cases, cases$sigla_uf), fit_one))
  rownames(out) <- NULL
  out[order(out$slope, decreasing = TRUE), ]
}

summary_stats <- function(cases, rated) {
  by_year <- summarize_by_year(cases)
  top <- rank_uf(cases, n = 1L)
  den_total <- sum(rated$nascidos, na.rm = TRUE)

  list(
    total_cases   = sum(cases$total),
    period        = paste(range(cases$ano), collapse = "-"),
    peak_year     = by_year$ano[which.max(by_year$total)],
    peak_cases    = max(by_year$total),
    top_uf        = as.list(top[1L, c("sigla_uf", "nome", "total")]),
    n_ufs         = length(unique(cases$sigla_uf)),
    national_rate = if (den_total > 0) sum(cases$total) / den_total * 1e5 else NA_real_,
    mean_rate     = mean(rated$taxa_100k, na.rm = TRUE)
  )
}
