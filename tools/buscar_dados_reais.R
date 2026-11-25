# Busca os CSVs de origem no BigQuery (Base dos Dados) com o projeto do .Renviron.
# Uso:
#   Rscript tools/buscar_dados_reais.R                 # grava em data/raw/
#   Rscript tools/buscar_dados_reais.R <pasta/raw>     # destino alternativo
#
# Requisitos: basedosdados instalado, gcloud autenticado e termos SIM/SINASC
# aceitos no site da Base dos Dados com o MESMO ID de projeto.

root <- getwd()
while (!file.exists(file.path(root, "EpidemiR.Rproj")) && dirname(root) != root) {
  root <- dirname(root)
}
for (m in c("R/utils.R", "R/00_config.R", "R/01_extract.R",
            "tools/verificar_csv.R")) {
  source(file.path(root, m), local = FALSE, encoding = "UTF-8")
}

#' Checa pre-requisitos sem fazer rede.
credentials_ready <- function() {
  id <- Sys.getenv("GCP_BILLING_ID", unset = "")
  if (!nzchar(id)) {
    return(list(ok = FALSE, msg = paste0(
      "GCP_BILLING_ID vazio. Crie .Renviron na raiz com ",
      "GCP_BILLING_ID=id-do-projeto e reinicie o R.")))
  }
  if (!requireNamespace("basedosdados", quietly = TRUE)) {
    return(list(ok = FALSE, msg = "Instale o pacote basedosdados."))
  }
  adc <- Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS", unset = "")
  if (!nzchar(adc)) {
    adc <- file.path(path.expand("~"), ".config", "gcloud",
                     "application_default_credentials.json")
  }
  if (!file.exists(adc)) {
    return(list(ok = FALSE, msg = paste0(
      "Credenciais padrao do Google nao encontradas em '", adc, "'. ",
      "Instale o Google Cloud CLI e rode: gcloud auth application-default login")))
  }
  list(ok = TRUE, id = id)
}

#' Consulta o BigQuery e grava cases_<source>.csv + births.csv em raw_dir.
#' Nunca usa cache: o objetivo e buscar a origem.
fetch_real_sources <- function(raw_dir,
                               source = "sim",
                               years = 2014:2019) {
  chk <- credentials_ready()
  abort_if(!chk$ok, chk$msg)

  make_dir(raw_dir)
  cfg <- default_config(source = source,
                        years = years,
                        billing_id = chk$id,
                        mock = FALSE,
                        use_cache = FALSE,
                        dirs = list(raw = raw_dir))
  log_info("Buscando origem real | projeto=%s | fonte=%s | anos=%d-%d",
           chk$id, source, min(years), max(years))

  raw <- extract_all(cfg)
  paths <- .cache_paths(cfg)
  for (p in paths) {
    res <- verificar_csv_fonte(p)
    abort_if(length(res$problemas) > 0L,
             sprintf("CSV gerado invalido (%s): %s", basename(p),
                     paste(res$problemas, collapse = "; ")))
    log_info("Validado: %s | %d linhas | %d UFs | total=%s",
             basename(p), res$linhas, res$ufs,
             format(res$total, big.mark = ".", decimal.mark = ",", trim = TRUE))
  }
  list(config = cfg, raw = raw, paths = paths)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  dest <- if (length(args) > 0L) args[1L] else file.path(root, "data", "raw")
  res <- fetch_real_sources(dest)
  cat("\n=== ORIGEM REAL PRONTA ===\n")
  for (p in res$paths) cat("-", p, "\n")
  cat("Agora rode: Rscript run_analysis.R\n")
}
