# Testes do pipeline (sem dependencias externas) -------------------------------
# Rode: Rscript tests/test_pipeline.R
# Usa apenas dados mock: nao consulta BigQuery e nao precisa de GCP_BILLING_ID.

root <- getwd()
while (!file.exists(file.path(root, "MapaGenBase.Rproj")) && dirname(root) != root) {
  root <- dirname(root)
}
PROJECT_ROOT <- root
for (m in c("R/utils.R", "R/00_config.R", "R/01_extract.R",
            "R/02_transform.R", "R/03_analyze.R",
            "R/04_visualize.R", "R/05_export.R", "R/06_optional_maps.R")) {
  source(file.path(PROJECT_ROOT, m), local = FALSE, encoding = "UTF-8")
}

# Contador encapsulado em environment: um pequeno exemplo de closure com estado.
make_checker <- function() {
  state <- new.env(parent = emptyenv())
  state$n <- 0L
  list(
    check = function(cond, label) {
      state$n <- state$n + 1L
      if (!isTRUE(cond)) stop("FALHOU: ", label, call. = FALSE)
      cat("ok -", label, "\n")
      invisible(state$n)
    },
    total = function() state$n
  )
}
tc <- make_checker()
check <- tc$check

cat("--- Configuracao e SQL ---\n")
cfg <- default_config(source = "sim", years = 2014:2016, mock = TRUE)
check(length(cfg$years) == 3L, "anos configurados")
check(inherits(try(default_config(cid_cases = "Q02'; DROP TABLE x"), silent = TRUE), "try-error"),
      "CID malicioso e rejeitado")
check(grepl("br_ms_sim.microdados", build_query_cases(cfg), fixed = TRUE),
      "SQL de casos aponta para SIM")
check(grepl("BETWEEN 2014 AND 2016", build_query_cases(cfg), fixed = TRUE),
      "SQL usa o intervalo de anos")
cfg_sinasc <- config_for_source("sinasc", cfg)
check(grepl("anomalia_congenita", build_query_cases(cfg_sinasc), fixed = TRUE),
      "troca de fonte muda o campo do CID")

cat("\n--- Extracao mock ---\n")
raw <- extract_all(cfg)
check(nrow(raw$cases) == 3L * nrow(UF_LOOKUP), "mock de casos cobre todos os anos/UFs")
check(nrow(raw$births) == 3L * nrow(UF_LOOKUP), "mock de nascidos cobre todos os anos/UFs")
check(all(!is.na(raw$cases$total)), "mock sem NAs")

cat("\n--- Transformacao ---\n")
cases  <- prepare_cases(raw$cases, cfg)
births <- prepare_births(raw$births, cfg)
check(nrow(cases) == 3L * 27L, "grade completa tem 3 anos x 27 UFs")
check(all(c("sigla_uf", "nome", "regiao", "lon", "lat") %in% names(cases)),
      "metadados de UF colados")
check(all(!is.na(cases$total)), "sem total NA apos completar grade")
check(!anyDuplicated(cases[, c("ano", "sigla_uf")]), "chave ano/UF unica")
check(sum(cases$total) == sum(raw$cases$total), "agregacao nao perde nem duplica casos")

cat("\n--- Analise ---\n")
rated <- add_rates(cases, births)
check(all(is.finite(rated$taxa_100k)), "taxas finitas")
check(all(rated$taxa_100k >= 0), "taxas nao negativas")
trends <- fit_trends(cases)
check(nrow(trends) == 27L, "uma tendencia por UF")
check(all(trends$direction %in% c("crescente", "decrescente", "estavel",
                                   "insuficiente", "indefinida")),
      "direcoes de tendencia validas")
st <- summary_stats(cases, rated)
check(st$total_cases == sum(cases$total), "resumo bate com a base")
check(st$n_ufs == 27L, "resumo conta 27 UFs")
check(st$national_rate > 0, "taxa nacional positiva")

cat("\n--- Exportacao ---\n")
paths <- make_all_plots(cases, rated, cfg)
check(all(file.exists(paths)), "graficos PNG gerados")
by_year <- summarize_by_year(cases)
files <- export_tables(cases, births, rated, trends, by_year, cfg)
check(all(file.exists(unname(files))), "tabelas CSV/RDS gerados")
report <- write_report_md(st, cases, trends, paths, cfg)
check(file.exists(report) && any(grepl("Relatorio automatico", readLines(report))),
      "relatorio markdown gerado")

cat(sprintf("\n%d testes passaram.\n", tc$total()))
