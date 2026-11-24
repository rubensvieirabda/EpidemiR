# Exportacao -------------------------------------------------------------------
# Resultados tabulares, objeto RDS e relatorio markdown gerado por codigo.

export_tables <- function(cases, births, rated, trends, by_year, cfg) {
  abort_if(!requireNamespace("readr", quietly = TRUE), "Pacote 'readr' necessario.")
  out <- cfg$dirs$processed
  make_dir(out)

  files <- c(
    casos   = file.path(out, "casos_por_uf_ano.csv"),
    nascidos = file.path(out, "nascidos_por_uf_ano.csv"),
    taxas   = file.path(out, "taxas_por_uf_ano.csv"),
    tendencias = file.path(out, "tendencias_por_uf.csv"),
    anos    = file.path(out, "casos_por_ano.csv")
  )
  readr::write_csv(cases, files["casos"])
  readr::write_csv(births, files["nascidos"])
  readr::write_csv(rated[, c("ano", "sigla_uf", "nome", "regiao",
                             "total", "nascidos", "taxa_100k", "is_imputed")],
                   files["taxas"])
  readr::write_csv(trends, files["tendencias"])
  readr::write_csv(by_year, files["anos"])
  saveRDS(list(cases = cases, births = births, rated = rated,
               trends = trends, config = cfg),
          file.path(out, "objetos.rds"))
  log_info("Tabelas exportadas em %s", out)
  files
}

write_report_md <- function(stats, cases, trends, paths, cfg) {
  top <- rank_uf(cases, n = 10L)
  linhas_top <- vapply(seq_len(nrow(top)), function(i) {
    sprintf("| %d | %s - %s | %s |",
            i, top$sigla_uf[i], top$nome[i], format_number(top$total[i]))
  }, character(1L))

  linhas <- c(
    "# Relatorio automatico - MapaGenBase",
    "",
    sprintf("Gerado em %s (origem: %s%s).",
            format(Sys.time(), "%d/%m/%Y %H:%M"),
            if (cfg$source == "sim") "SIM/obitos" else "SINASC/nascidos com anomalia",
            if (cfg$mock) ", MODO MOCK" else ""),
    "",
    "## Numeros gerais",
    "",
    sprintf("- Periodo: **%s**", stats$period),
    sprintf("- Total de casos: **%s**", format_number(stats$total_cases)),
    sprintf("- Ano de pico: **%d** (%s casos)",
            stats$peak_year, format_number(stats$peak_cases)),
    sprintf("- UF com mais casos: **%s - %s** (%s)",
            stats$top_uf$sigla_uf, stats$top_uf$nome,
            format_number(stats$top_uf$total)),
    sprintf("- Taxa nacional: **%.2f por 100 mil nascidos vivos**",
            stats$national_rate),
    sprintf("- Taxa media entre UFs: **%.2f por 100 mil**", stats$mean_rate),
    sprintf("- UFs na base: **%d**", stats$n_ufs),
    "",
    "## Top 10 UFs",
    "",
    "| # | UF | Casos |",
    "|---:|---|---:|",
    linhas_top,
    "",
    "## Tendencias (lm: casos ~ ano)",
    "",
    sprintf("- Crescentes: %d | Decrescentes: %d | Estaveis: %d",
            sum(trends$direction == "crescente"),
            sum(trends$direction == "decrescente"),
            sum(trends$direction == "estavel")),
    "",
    "## Arquivos gerados",
    "",
    vapply(names(paths), function(k) sprintf("- %s: `%s`", k, paths[[k]]),
           character(1L), USE.NAMES = FALSE),
    ""
  )

  path <- file.path(cfg$dirs$reports, "relatorio.md")
  write_text(linhas, path)
  log_info("Relatorio: %s", path)
  path
}
