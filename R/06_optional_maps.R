# Modulo OPCIONAL de mapa com malha geografica -------------------------------
# Este arquivo e listado em .renvignore: ggplot2/geobr sao opcionais e nao
# entram no lockfile. O pipeline funciona completamente sem eles.

plot_optional_choropleth <- function(rated, path, cfg) {
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("geobr", quietly = TRUE)) {
    log_info("Coropletico pulado (instale ggplot2 + geobr para habilita-lo).")
    return(invisible(NULL))
  }

  year <- max(cfg$years)
  d <- rated[rated$ano == year, c("sigla_uf", "taxa_100k")]
  result <- tryCatch({
    map <- geobr::read_state(year = year, showProgress = FALSE)
    map <- dplyr::left_join(map, d, by = c("abbrev_state" = "sigla_uf"))
    p <- ggplot2::ggplot(map) +
      ggplot2::geom_sf(ggplot2::aes(fill = taxa_100k), colour = "white") +
      ggplot2::scale_fill_viridis_c(option = "C", na.value = "grey90") +
      ggplot2::labs(title = sprintf("Casos por 100 mil nascidos - %d", year),
                   fill = "Taxa") +
      ggplot2::theme_minimal()
    make_dir(dirname(path))
    ggplot2::ggsave(path, plot = p, width = 10, height = 7, dpi = 120)
    path
  }, error = function(e) {
    log_info("Coropletico falhou: %s", conditionMessage(e))
    NULL
  })
  invisible(result)
}
