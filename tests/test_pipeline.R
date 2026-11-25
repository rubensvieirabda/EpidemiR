# Testes do pipeline (sem rede por padrao) -------------------------------------
# Rode: Rscript tests/test_pipeline.R
# Auditoria: cada etapa imprime contagens, NAs, chaves e faixas ([DEBUG]).
# Origem real (opcional): $env:EPIDEMIR_REAL_DATA=1; Rscript tests/test_pipeline.R

root <- getwd()
while (!file.exists(file.path(root, "EpidemiR.Rproj")) && dirname(root) != root) {
  root <- dirname(root)
}
PROJECT_ROOT <- root
for (m in c("R/utils.R", "R/00_config.R", "R/01_extract.R",
            "R/02_transform.R", "R/03_analyze.R",
            "R/04_visualize.R", "R/05_export.R", "R/06_optional_maps.R",
            "tools/verificar_csv.R")) {
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

#' Auditoria legivel de um data.frame em cada etapa do pipeline.
audit <- function(label, x, key = NULL, expected_rows = NULL) {
  cat(sprintf("\n[DEBUG][%s] linhas=%d colunas=%d\n", label, nrow(x), ncol(x)))
  nas <- vapply(x, function(col) as.integer(sum(is.na(col))), integer(1L))
  cat(sprintf("[DEBUG][%s] NAs: %s\n", label,
              paste(sprintf("%s=%d", names(nas), nas), collapse = ", ")))
  if (!is.null(key)) {
    missing_key <- setdiff(key, names(x))
    dup <- if (length(missing_key) == 0L) {
      sum(duplicated(x[, key, drop = FALSE]))
    } else {
      NA_integer_
    }
    cat(sprintf("[DEBUG][%s] chave=%s duplicadas=%s\n", label,
                paste(key, collapse = "+"),
                if (is.na(dup)) "chave ausente" else dup))
  }
  numericas <- names(x)[vapply(x, is.numeric, logical(1L))]
  if (length(numericas) > 0L) {
    faixas <- vapply(x[numericas], function(v) {
      ok <- is.finite(v)
      if (!any(ok)) return("sem valores")
      sprintf("[%s ; %s]", format(min(v[ok])), format(max(v[ok])))
    }, character(1L))
    cat(sprintf("[DEBUG][%s] faixas: %s\n", label,
                paste(sprintf("%s=%s", names(faixas), faixas), collapse = ", ")))
  }
  if (!is.null(expected_rows)) {
    cat(sprintf("[DEBUG][%s] esperado=%d obtido=%d\n",
                label, expected_rows, nrow(x)))
  }
  invisible(x)
}

cat("--- Configuracao e SQL ---\n")
cfg0 <- default_config(source = "sim", years = 2014:2016, mock = TRUE)
check(length(cfg0$years) == 3L, "anos configurados")
check(inherits(try(default_config(cid_cases = "Q02'; DROP TABLE x"), silent = TRUE), "try-error"),
      "CID malicioso e rejeitado")
check(grepl("br_ms_sim.microdados", build_query_cases(cfg0), fixed = TRUE),
      "SQL de casos aponta para SIM")
check(grepl("BETWEEN 2014 AND 2016", build_query_cases(cfg0), fixed = TRUE),
      "SQL usa o intervalo de anos")
cfg_sinasc <- config_for_source("sinasc", cfg0)
check(grepl("anomalia_congenita", build_query_cases(cfg_sinasc), fixed = TRUE),
      "troca de fonte muda o campo do CID")

cat("\n--- Chave opcional e cache local ---\n")
tmp_raw <- file.path(tempdir(), "epidemir_cache_teste")
make_dir(tmp_raw)
paths_teste <- .cache_paths(default_config(dirs = list(raw = tmp_raw)))
writeLines(c("ano,sigla_uf,total", "2014,PE,10"), paths_teste["cases"])
writeLines(c("ano,sigla_uf,nascidos", "2014,PE,1000"), paths_teste["births"])

cfg_cache <- suppressMessages(resolve_data_source(
  default_config(years = 2014:2016, billing_id = "",
                 dirs = list(raw = tmp_raw))
))
check(identical(cfg_cache$data_mode, "cache"), "cache completo dispensa GCP_BILLING_ID")
check(!cfg_cache$mock, "cache completo nao ativa mock")

cfg_vazio <- file.path(tempdir(), "epidemir_sem_cache")
cfg_sem_chave <- suppressMessages(resolve_data_source(
  default_config(years = 2014:2016, billing_id = "",
                 dirs = list(raw = cfg_vazio))
))
check(isTRUE(cfg_sem_chave$mock), "sem chave e sem cache cai para mock")
check(identical(cfg_sem_chave$data_mode, "mock"), "modo mock registrado na config")
check(grepl("GCP_BILLING_ID", cfg_sem_chave$mock_reason, fixed = TRUE),
      "motivo do mock registrado para o relatorio")

cfg_com_chave <- suppressMessages(resolve_data_source(
  default_config(years = 2014:2016, billing_id = "projeto-teste",
                 dirs = list(raw = cfg_vazio))
))
check(identical(cfg_com_chave$data_mode, "bigquery"), "com chave segue para BigQuery")

cfg_sem_cache_flag <- suppressMessages(resolve_data_source(
  default_config(years = 2014:2016, billing_id = "", use_cache = FALSE,
                 dirs = list(raw = tmp_raw))
))
check(isTRUE(cfg_sem_cache_flag$mock), "--no-cache sem chave tambem cai para mock")

cat("\n--- Origem importada (CSV -> pipeline) ---\n")
tmp_run <- file.path(tempdir(), "epidemir_auditoria")
dir_raw <- file.path(tmp_run, "raw")
dir_processed <- file.path(tmp_run, "processed")
dir_reports <- file.path(tmp_run, "reports")
make_dir(dir_raw)
make_dir(dir_processed)
make_dir(dir_reports)

# Dados sinteticos fazem o papel da origem baixada; o pipeline le os CSVs do disco.
fonte <- extract_all(cfg0)
paths_fonte <- .cache_paths(default_config(dirs = list(raw = dir_raw)))
readr::write_csv(fonte$cases, paths_fonte["cases"])
readr::write_csv(fonte$births, paths_fonte["births"])
check(all(file.exists(paths_fonte)), "CSVs de origem criados em area temporaria")

v_cases <- verificar_csv_fonte(paths_fonte["cases"])
v_births <- verificar_csv_fonte(paths_fonte["births"])
check(length(v_cases$problemas) == 0L, "CSV de casos aprovado na auditoria de origem")
check(length(v_births$problemas) == 0L, "CSV de nascidos aprovado na auditoria de origem")
cat(sprintf("[DEBUG][origem] casos: %d linhas, %d UFs, total=%s\n",
            v_cases$linhas, v_cases$ufs,
            format(v_cases$total, big.mark = ".", decimal.mark = ",", trim = TRUE)))

cfg <- suppressMessages(resolve_data_source(default_config(
  source = "sim", years = 2014:2016, mock = FALSE, billing_id = "",
  dirs = list(raw = dir_raw, processed = dir_processed, reports = dir_reports)
)))
check(identical(cfg$data_mode, "cache"), "origem importada do cache sem chave")
check(!cfg$mock, "origem importada nao e mock")

raw <- extract_all(cfg)
audit("extracao/importacao", raw$cases, key = c("ano", "sigla_uf"))
audit("extracao/importacao", raw$births, key = c("ano", "sigla_uf"))
check(sum(raw$cases$total) == v_cases$total, "total importado bate com CSV de origem")
check(sum(raw$births$nascidos) == v_births$total, "nascidos importados batem com CSV")

cat("\n--- Transformacao (auditada) ---\n")
cases  <- prepare_cases(raw$cases, cfg)
births <- prepare_births(raw$births, cfg)
audit("transformacao/casos", cases, key = c("ano", "sigla_uf"),
      expected_rows = 3L * 27L)
audit("transformacao/nascidos", births, key = c("ano", "sigla_uf"),
      expected_rows = 3L * 27L)
check(nrow(cases) == 3L * 27L, "grade completa tem 3 anos x 27 UFs")
check(all(c("sigla_uf", "nome", "regiao", "lon", "lat") %in% names(cases)),
      "metadados de UF colados")
check(all(!is.na(cases$total)), "sem total NA apos completar grade")
check(!anyDuplicated(cases[, c("ano", "sigla_uf")]), "chave ano/UF unica")
check(sum(cases$total) == sum(raw$cases$total), "agregacao nao perde nem duplica casos")
check(sum(births$nascidos) == sum(raw$births$nascidos),
      "agregacao de nascidos nao perde nem duplica")

cat("\n--- Analise (auditada) ---\n")
rated <- add_rates(cases, births)
audit("analise/taxas", rated, key = c("ano", "sigla_uf"),
      expected_rows = 3L * 27L)
check(all(is.finite(rated$taxa_100k)), "taxas finitas")
check(all(rated$taxa_100k >= 0), "taxas nao negativas")
check(sum(rated$total) == sum(cases$total), "taxas preservam total de casos")
check(sum(rated$nascidos) == sum(births$nascidos), "taxas preservam total de nascidos")
trends <- fit_trends(cases)
check(nrow(trends) == 27L, "uma tendencia por UF")
check(all(trends$direction %in% c("crescente", "decrescente", "estavel",
                                    "insuficiente", "indefinida")),
      "direcoes de tendencia validas")
st <- summary_stats(cases, rated)
check(st$total_cases == sum(cases$total), "resumo bate com a base")
check(st$n_ufs == 27L, "resumo conta 27 UFs")
check(st$national_rate > 0, "taxa nacional positiva")
by_year <- summarize_by_year(cases)
audit("analise/por-ano", by_year, expected_rows = 3L)

cat("\n--- Exportacao (auditada) ---\n")
paths <- make_all_plots(cases, rated, cfg)
check(all(file.exists(paths)), "graficos PNG gerados em area temporaria")
files <- export_tables(cases, births, rated, trends, by_year, cfg)
check(all(file.exists(unname(files))), "tabelas CSV/RDS gerados em area temporaria")
check(nrow(readr::read_csv(files["casos"], show_col_types = FALSE)) == nrow(cases),
      "CSV exportado tem a mesma quantidade de linhas")
report <- write_report_md(st, cases, trends, paths, cfg)
linhas_relatorio <- readLines(report, warn = FALSE)
check(any(grepl("Relatorio automatico", linhas_relatorio, fixed = TRUE)),
      "relatorio markdown gerado")
check(!any(grepl("MODO MOCK", linhas_relatorio, fixed = TRUE)),
      "relatorio da origem importada nao diz MODO MOCK")
check(all(grepl(tmp_run, unname(files), fixed = TRUE)),
      "exportacao nao sujou data/ do projeto")
check(grepl(tmp_run, report, fixed = TRUE),
      "relatorio nao sujou data/ do projeto")

cat("\n--- Origem real (BigQuery, opcional) ---\n")
if (identical(Sys.getenv("EPIDEMIR_REAL_DATA", unset = "0"), "1")) {
  source(file.path(PROJECT_ROOT, "tools", "buscar_dados_reais.R"),
         local = FALSE, encoding = "UTF-8")
  dir_real <- file.path(tempdir(), "epidemir_real")
  res_real <- fetch_real_sources(dir_real, source = "sim", years = 2014:2015)
  check(length(res_real$paths) == 2L, "origem real gerou os dois CSVs")
  for (p in res_real$paths) {
    v <- verificar_csv_fonte(p)
    check(length(v$problemas) == 0L,
          sprintf("origem real valida: %s", basename(p)))
  }
} else {
  cat("[DEBUG] Busca real ignorada. Use EPIDEMIR_REAL_DATA=1 (gcloud + termos prontos).\n")
}

cat(sprintf("\n%d testes passaram.\n", tc$total()))
