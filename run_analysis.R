# EpidemiR - ponto de entrada do pipeline -------------------------------------
# Uso:
#   Rscript run_analysis.R --mock
#   Rscript run_analysis.R --source=sinasc --years=2014-2019
#   Rscript run_analysis.R --no-cache

usage <- function() {
  paste(
    "EpidemiR - pipeline de extracao -> transformacao -> analise -> exportacao",
    "",
    "Opcoes:",
    "  --mock            usa dados sinteticos, sem internet/BigQuery",
    "  --source=sim      obitos por CID (padrao)",
    "  --source=sinasc   nascidos vivos com anomalia",
    "  --years=2014-2019 intervalo de anos",
    "  --no-cache        ignora CSVs em data/raw e refaz a consulta",
    "  -h, --help        mostra esta ajuda",
    sep = "\n"
  )
}

parse_cli <- function(args) {
  out <- list(source = "sim", years = 2014:2019,
              use_cache = TRUE, mock = FALSE)
  for (a in args) {
    if (a %in% c("-h", "--help")) {
      cat(usage(), "\n")
      quit(save = "no", status = 0L)
    } else if (identical(a, "--mock")) {
      out$mock <- TRUE
    } else if (identical(a, "--no-cache")) {
      out$use_cache <- FALSE
    } else if (startsWith(a, "--source=")) {
      out$source <- sub("^--source=", "", a)
    } else if (startsWith(a, "--years=")) {
      pieces <- strsplit(sub("^--years=", "", a), "-", fixed = TRUE)[[1L]]
      abort_if(length(pieces) != 2L, "--years deve ser AAAA-AAAA (ex.: 2014-2019).")
      bounds <- suppressWarnings(as.integer(pieces))
      abort_if(anyNA(bounds) || bounds[1L] > bounds[2L], "--years invalido.")
      out$years <- seq(bounds[1L], bounds[2L])
    } else {
      stop("Argumento desconhecido: '", a, "'. Rode com --help.", call. = FALSE)
    }
  }
  out
}

# Descobre a raiz a partir do proprio arquivo de script (funciona mesmo se
# Rscript for chamado de outro diretorio).
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
PROJECT_ROOT <- if (length(file_arg) > 0L) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1L]), winslash = "/"))
} else {
  normalizePath(getwd(), winslash = "/")
}

modules <- c("R/utils.R", "R/00_config.R", "R/01_extract.R",
             "R/02_transform.R", "R/03_analyze.R",
             "R/04_visualize.R", "R/05_export.R", "R/06_optional_maps.R")
for (m in modules) {
  source(file.path(PROJECT_ROOT, m), local = FALSE, encoding = "UTF-8")
}

cli <- parse_cli(commandArgs(trailingOnly = TRUE))
cfg <- default_config(source = cli$source,
                      years = cli$years,
                      use_cache = cli$use_cache,
                      mock = cli$mock)

log_info("Iniciando pipeline | source=%s | anos=%s | mock=%s",
         cfg$source, paste(range(cfg$years), collapse = "-"), cfg$mock)
t0 <- Sys.time()

raw     <- extract_all(cfg)
cases   <- prepare_cases(raw$cases, cfg)
births  <- prepare_births(raw$births, cfg)
rated   <- add_rates(cases, births)
trends  <- fit_trends(cases)
by_year <- summarize_by_year(cases)
stats   <- summary_stats(cases, rated)

paths   <- make_all_plots(cases, rated, cfg)
tables  <- export_tables(cases, births, rated, trends, by_year, cfg)
report  <- write_report_md(stats, cases, trends, paths, cfg)

log_info("Concluido em %.2fs.", as.numeric(difftime(Sys.time(), t0, units = "secs")))
cat("\n=== RESUMO ===\n")
cat(sprintf("Periodo      : %s\n", stats$period))
cat(sprintf("Total casos  : %s\n", format_number(stats$total_cases)))
cat(sprintf("Ano de pico  : %d (%s casos)\n",
            stats$peak_year, format_number(stats$peak_cases)))
cat(sprintf("Top UF       : %s - %s (%s)\n",
            stats$top_uf$sigla_uf, stats$top_uf$nome,
            format_number(stats$top_uf$total)))
cat(sprintf("Taxa nacional: %.2f / 100 mil nascidos\n", stats$national_rate))
cat(sprintf("Relatorio    : %s\n", report))

