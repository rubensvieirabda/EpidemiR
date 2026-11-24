# Verifica um CSV baixado da Base dos Dados antes de coloca-lo em data/raw/
# Uso: Rscript tools/verificar_csv.R data/raw/cases_sim.csv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop("Uso: Rscript tools/verificar_csv.R <caminho/do/arquivo.csv>", call. = FALSE)
}

path <- args[1L]
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
cat("Arquivo :", path, "\n")
cat("Linhas  :", nrow(d), "\n")
cat("Colunas :", paste(names(d), collapse = ", "), "\n")

missing <- setdiff(expected, names(d))
if (length(missing) > 0L) {
  stop("Faltam colunas obrigatorias: ", paste(missing, collapse = ", "),
       "\nBaixe o RESULTADO da SQL agregada, nao os microdados brutos.",
       call. = FALSE)
}

value_col <- setdiff(expected, c("ano", "sigla_uf"))
problems <- c(
  if (anyNA(d$ano)) "ano com NA",
  if (anyNA(d$sigla_uf)) "sigla_uf com NA",
  if (anyNA(d[[value_col]])) paste0(value_col, " com NA"),
  if (any(d[[value_col]] < 0)) paste0(value_col, " negativo"),
  if (any(!toupper(trimws(d$sigla_uf)) %in% c(
    "RO", "AC", "AM", "RR", "PA", "AP", "TO", "MA", "PI", "CE", "RN", "PB",
    "PE", "AL", "SE", "BA", "MG", "ES", "RJ", "SP", "PR", "SC", "RS", "MS",
    "MT", "GO", "DF"))) "sigla_uf fora do padrao"
)

if (length(problems) > 0L) {
  stop("Problemas encontrados:\n- ", paste(problems, collapse = "\n- "),
       call. = FALSE)
}

cat(sprintf("OK! '%s' esta pronto para ser consumido pelo pipeline.\n", name))
cat(sprintf("Periodo: %d-%d | UFs: %d\n",
            min(d$ano, na.rm = TRUE), max(d$ano, na.rm = TRUE),
            length(unique(d$sigla_uf))))
