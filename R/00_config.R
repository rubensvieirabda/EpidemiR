# Configuracao e dados de apoio ------------------------------------------------
# "Uma unica fonte de verdade": caminhos, parametros da consulta e a tabela
# de UFs ficam aqui. Nenhum modulo deve fixar caminhos ou valores no codigo.

#' Encontra a raiz do projeto subindo diretorios ate achar o .Rproj.
.find_project_root <- function(start = getwd()) {
  env_root <- Sys.getenv("RENV_PROJECT", unset = "")
  if (nzchar(env_root) && file.exists(file.path(env_root, "MapaGenBase.Rproj"))) {
    return(normalizePath(env_root, winslash = "/"))
  }
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "MapaGenBase.Rproj"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  stop("Nao encontrei MapaGenBase.Rproj a partir de '", start, "'.", call. = FALSE)
}

if (!exists("PROJECT_ROOT", inherits = FALSE)) {
  PROJECT_ROOT <- .find_project_root()
}

DIRS <- list(
  root      = PROJECT_ROOT,
  r         = file.path(PROJECT_ROOT, "R"),
  data      = file.path(PROJECT_ROOT, "data"),
  raw       = file.path(PROJECT_ROOT, "data", "raw"),
  processed = file.path(PROJECT_ROOT, "data", "processed"),
  reports   = file.path(PROJECT_ROOT, "data", "reports"),
  tests     = file.path(PROJECT_ROOT, "tests")
)

# Tabela de apoio com as 27 UFs. Coordenadas sao centroides aproximados:
# suficientes para um "mapa de bolhas" em base R, sem precisar de sf/geobr.
UF_LOOKUP <- data.frame(
  sigla = c("RO", "AC", "AM", "RR", "PA", "AP", "TO", "MA", "PI", "CE",
            "RN", "PB", "PE", "AL", "SE", "BA", "MG", "ES", "RJ", "SP",
            "PR", "SC", "RS", "MS", "MT", "GO", "DF"),
  codigo_ibge = c(11L, 12L, 13L, 14L, 15L, 16L, 17L, 21L, 22L, 23L,
                  24L, 25L, 26L, 27L, 28L, 29L, 31L, 32L, 33L, 35L,
                  41L, 42L, 43L, 50L, 51L, 52L, 53L),
  nome = c("Rondonia", "Acre", "Amazonas", "Roraima", "Para", "Amapa",
           "Tocantins", "Maranhao", "Piaui", "Ceara", "Rio Grande do Norte",
           "Paraiba", "Pernambuco", "Alagoas", "Sergipe", "Bahia",
           "Minas Gerais", "Espirito Santo", "Rio de Janeiro", "Sao Paulo",
           "Parana", "Santa Catarina", "Rio Grande do Sul",
           "Mato Grosso do Sul", "Mato Grosso", "Goias", "Distrito Federal"),
  regiao = c(rep("Norte", 7L), rep("Nordeste", 9L), rep("Sudeste", 4L),
             rep("Sul", 3L), rep("Centro-Oeste", 4L)),
  lon = c(-63.9, -69.6, -63.0, -60.7, -52.0, -51.0, -48.3, -44.3, -42.7, -39.0,
          -36.6, -36.7, -38.5, -36.2, -37.2, -41.5, -44.0, -40.6, -42.8, -48.5,
          -51.5, -49.3, -51.2, -54.6, -56.1, -49.2, -47.9),
  lat = c(-10.8, -9.0, -3.1, 2.8, -3.2, 1.4, -10.2, -4.1, -5.1, -5.2,
          -5.6, -7.1, -8.3, -9.6, -10.6, -12.0, -18.5, -19.6, -22.9, -23.5,
          -24.5, -27.3, -30.0, -20.1, -13.7, -16.6, -15.8),
  stringsAsFactors = FALSE
)

validate_config <- function(cfg) {
  abort_if(!cfg$source %in% c("sim", "sinasc"), "source deve ser 'sim' ou 'sinasc'.")
  abort_if(!is.numeric(cfg$years) || length(cfg$years) == 0L,
           "years precisa ser um vetor numerico nao vazio.")
  abort_if(any(!is.finite(cfg$years)) || any(cfg$years != as.integer(cfg$years)),
           "years so aceita inteiros finitos.")
  abort_if(!is.character(cfg$cid_cases) || !grepl("^[A-Z0-9%_]+$", cfg$cid_cases),
           "cid_cases so aceita letras maiusculas, digitos, % e _.")
  abort_if(!grepl("^[A-Za-z0-9_.]+$", cfg$table_cases), "table_cases invalida.")
  abort_if(!grepl("^[A-Za-z0-9_]+$", cfg$field_cases), "field_cases invalido.")
  abort_if(!is.logical(cfg$use_cache) || length(cfg$use_cache) != 1L,
           "use_cache precisa ser TRUE ou FALSE.")
  abort_if(!is.logical(cfg$mock) || length(cfg$mock) != 1L,
           "mock precisa ser TRUE ou FALSE.")
  invisible(TRUE)
}

#' Cria a lista de configuracao.
#'
#' @param source "sim" (obitos) ou "sinasc" (nascidos vivos com anomalia).
#' @param years  Anos de interesse.
#' @param ...    Sobrescreve qualquer campo da configuracao (ex.: seed = 1L).
default_config <- function(source = "sim",
                           years = 2014:2019,
                           table_cases = NULL,
                           field_cases = NULL,
                           cid_cases = NULL,
                           table_births = "basedosdados.br_ms_sinasc.microdados",
                           use_cache = TRUE,
                           mock = FALSE,
                           billing_id = Sys.getenv("GCP_BILLING_ID", unset = ""),
                           seed = 20260101L,
                           ...) {
  source <- match.arg(source, c("sim", "sinasc"))
  table_cases <- table_cases %||%
    if (source == "sim") "basedosdados.br_ms_sim.microdados" else
      "basedosdados.br_ms_sinasc.microdados"
  field_cases <- field_cases %||%
    if (source == "sim") "causa_basica" else "anomalia_congenita"
  cid_cases <- cid_cases %||% if (source == "sim") "Q02%" else "%Q02%"

  cfg <- list(
    source       = source,
    years        = as.integer(years),
    table_cases  = table_cases,
    field_cases  = field_cases,
    cid_cases    = cid_cases,
    table_births = table_births,
    use_cache    = use_cache,
    mock         = mock,
    billing_id   = billing_id,
    seed         = as.integer(seed),
    dirs         = DIRS
  )

  override <- list(...)
  if (length(override) > 0L) {
    unknown <- setdiff(names(override), names(cfg))
    abort_if(length(unknown) > 0L,
             sprintf("Parametros de configuracao desconhecidos: %s",
                     paste(unknown, collapse = ", ")))
    cfg[names(override)] <- override
  }

  validate_config(cfg)
  cfg
}

#' Atalho para trocar a fonte mantendo o resto da configuracao.
config_for_source <- function(source, cfg = default_config(), ...) {
  base <- default_config(source = source,
                         years = cfg$years,
                         use_cache = cfg$use_cache,
                         mock = cfg$mock,
                         billing_id = cfg$billing_id,
                         seed = cfg$seed,
                         ...)
  base
}
