# Verifica um CSV de origem antes de ele entrar no pipeline.
# Uso (terminal): Rscript tools/verificar_csv.R data/raw/cases_sim.csv
# Tambem pode ser source(): a funcao verificar_csv_fonte() fica disponivel.

UFS_BRASIL <- c(
  "RO", "AC", "AM", "RR", "PA", "AP", "TO", "MA", "PI", "CE", "RN", "PB",
  "PE", "AL", "SE", "BA", "MG", "ES", "RJ", "SP", "PR", "SC", "RS", "MS",
  "MT", "GO", "DF"
)

verificar_csv_fonte <- function(path) {
  if (!file.exists(path)) stop("Arquivo nao encontrado: ", path, call. = FALSE)
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("Instale readr: install.packages('readr')", call. = FALSE)
  }

  # O nome do arquivo define quais colunas esperamos.
  name <- basename(path)
  expected <- if (grepl("births", name, fixed = TRUE)) {
    c("ano", "sigla_uf", "nascidos")
  } else if (grepl("cases_sinasc", name, fixed = TRUE) ||
             grepl("cases_sim", name, fixed = TRUE)) {
    c("ano", "sigla_uf", "total")
  } else {
    stop("Nome nao reconhecido. Use cases_sim.csv, cases_sinasc.csv ou births.csv.",
         call. = FALSE)
  }

  d <- readr::read_csv(path, show_col_types = FALSE)
  missing <- setdiff(expected, names(d))
  value_col <- setdiff(expected, c("ano", "sigla_uf"))

  problems <- if (length(missing) > 0L) {
    sprintf("faltam colunas obrigatorias: %s (baixe o resultado da SQL agregada)",
            paste(missing, collapse = ", "))
  } else {
    c(
      if (anyNA(d$ano)) "ano com NA",
      if (anyNA(d$sigla_uf)) "sigla_uf com NA",
      if (anyNA(d[[value_col]])) paste0(value_col, " com NA"),
      if (any(d[[value_col]] < 0)) paste0(value_col, " negativo"),
      if (any(!toupper(trimws(d$sigla_uf)) %in% UFS_BRASIL)) "sigla_uf fora do padrao"
    )
  }

  list(
    path = path,
    nome = name,
    linhas = nrow(d),
    colunas = names(d),
    coluna_valor = value_col,
    problemas = problems,
    periodo = if (all(c("ano") %in% names(d)) && nrow(d) > 0L) {
      c(min = min(d$ano, na.rm = TRUE), max = max(d$ano, na.rm = TRUE))
    } else {
      c(min = NA_integer_, max = NA_integer_)
    },
    ufs = if ("sigla_uf" %in% names(d)) length(unique(trimws(d$sigla_uf))) else 0L,
    total = if (length(missing) == 0L && nrow(d) > 0L) sum(d[[value_col]], na.rm = TRUE) else NA_real_
  )
}

# Só executa a CLI quando o arquivo é chamado diretamente, não quando é source().
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1L) {
    stop("Uso: Rscript tools/verificar_csv.R <caminho/do/arquivo.csv>", call. = FALSE)
  }
  res <- verificar_csv_fonte(args[1L])
  cat("Arquivo :", res$path, "\n")
  cat("Linhas  :", res$linhas, "\n")
  cat("Colunas :", paste(res$colunas, collapse = ", "), "\n")
  if (length(res$problemas) > 0L) {
    stop("Problemas encontrados:\n- ", paste(res$problemas, collapse = "\n- "),
         "\nBaixe o RESULTADO da SQL agregada, nao os microdados brutos.",
         call. = FALSE)
  }
  cat(sprintf("OK! '%s' esta pronto para ser consumido pelo pipeline.\n", res$nome))
  cat(sprintf("Periodo: %d-%d | UFs: %d | Total: %s\n",
              res$periodo["min"], res$periodo["max"], res$ufs,
              format(res$total, big.mark = ".", decimal.mark = ",", trim = TRUE)))
}
