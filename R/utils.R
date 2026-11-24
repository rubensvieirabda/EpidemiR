# Utilitarios -----------------------------------------------------------------
# Funcoes pequenas, sem dependencias externas, usadas por todos os modulos.
# Carregadas primeiro por run_analysis.R.

#' Registra uma mensagem com horario no console.
#' @param fmt String com placeholders %s/%d (style sprintf).
#' @param ... Valores para os placeholders.
log_info <- function(fmt, ...) {
  message("[", format(Sys.time(), "%H:%M:%S"), "] ", sprintf(fmt, ...))
}

#' Lanca um erro legivel somente quando a condicao for TRUE.
#' @details Criar um "abort_if" proprio evita repetir `if (...) stop(...)` e
#'   deixa as validacoes com a mesma voz em todo o projeto.
abort_if <- function(condition, message) {
  if (isTRUE(condition)) stop(message, call. = FALSE)
  invisible(FALSE)
}

assert_dataframe <- function(x, name = "x") {
  abort_if(!is.data.frame(x),
           sprintf("'%s' precisa ser um data.frame ou tibble (recebi %s).",
                   name, paste(class(x), collapse = "/")))
  invisible(TRUE)
}

assert_columns <- function(x, required, name = "x") {
  assert_dataframe(x, name)
  missing <- setdiff(required, names(x))
  abort_if(length(missing) > 0L,
           sprintf("'%s' nao tem as colunas obrigatorias: %s",
                   name, paste(missing, collapse = ", ")))
  invisible(TRUE)
}

#' Operador de valor padrao: devolve `y` quando `x` e NULL.
`%||%` <- function(x, y) if (is.null(x)) y else x

make_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

write_text <- function(lines, path) {
  make_dir(dirname(path))
  writeLines(as.character(lines), con = path, useBytes = TRUE)
  invisible(path)
}

format_number <- function(x, digits = 0L) {
  formatC(x, format = "f", digits = digits,
          big.mark = ".", decimal.mark = ",")
}

#' Abre um dispositivo PNG, executa `code` e sempre fecha o dispositivo.
#' @details `on.exit()` garante o fechamento mesmo se o codigo do grafico
#'   lancar erro -- sem isso o dispositivo fica "vazado" e o proximo plot
#'   pode ir parar dentro do PNG errado.
safe_png <- function(path, code, width = 1100, height = 700) {
  make_dir(dirname(path))
  grDevices::png(filename = path, width = width, height = height, res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(code)
  invisible(path)
}
