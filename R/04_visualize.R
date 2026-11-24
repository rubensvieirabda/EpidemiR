# Visualizacao -----------------------------------------------------------------
# Graficos em base R (sem dependencias) + mapa coropletico OPCIONAL com
# ggplot2/geobr. O pipeline never depende de pacotes nao instalados.

plot_by_year <- function(cases, path) {
  d <- summarize_by_year(cases)
  safe_png(path, {
    graphics::barplot(d$total ~ d$ano,
                      col = grDevices::hcl.colors(nrow(d), "Blues", rev = TRUE),
                      border = NA,
                      main = "Casos por ano",
                      xlab = "Ano", ylab = "Casos",
                      ylim = c(0, max(d$total) * 1.15))
    graphics::text(x = graphics::par("usr")[1L] + 0.4,
                   y = d$total, labels = format_number(d$total),
                   pos = 3L, cex = 0.75)
  })
  path
}

plot_top_uf <- function(cases, path, n = 12L) {
  d <- utils::head(rank_uf(cases, n), n)
  d <- d[order(d$total), ] # barplot horizontal desenha de baixo para cima
  safe_png(path, {
    graphics::barplot(d$total, names.arg = d$sigla_uf, horiz = TRUE,
                      las = 1L, border = NA,
                      col = grDevices::hcl.colors(nrow(d), "YlOrRd", rev = TRUE),
                      xlim = c(0, max(d$total) * 1.18),
                      main = sprintf("Top %d UFs por casos", n),
                      xlab = "Casos", ylab = "")
    graphics::text(x = d$total, y = seq_len(nrow(d)) * 1.2 - 0.6,
                   labels = format_number(d$total), pos = 4L, cex = 0.75)
  })
  path
}

#' Mapa de bolhas com centroides aproximados. Funciona com base graphics.
plot_bubble_map <- function(rated, path, year = NULL) {
  d <- rated[rated$ano == (year %||% max(rated$ano)), ]
  d <- d[!is.na(d$lon) & !is.na(d$lat) & !is.na(d$total), ]

  q <- stats::quantile(d$taxa_100k, probs = c(0, 0.5, 1), na.rm = TRUE)
  cols <- if (anyDuplicated(q) > 0L || anyNA(q)) {
    rep("steelblue", nrow(d))
  } else {
    grp <- cut(d$taxa_100k, breaks = q, include.lowest = TRUE, labels = FALSE)
    grp[is.na(grp)] <- 1L
    grDevices::hcl.colors(3L, "YlOrRd")[grp]
  }

  safe_png(path, {
    graphics::symbols(x = d$lon, y = d$lat, circles = sqrt(d$total + 1),
                      inches = 0.4, bg = cols, fg = "grey25",
                      xlim = c(-75, -33), ylim = c(-35, 5), asp = 1,
                      main = sprintf("Casos por 100 mil nascidos (ano %d)",
                                     year %||% max(rated$ano)),
                      xlab = "Longitude", ylab = "Latitude")
    graphics::text(d$lon, d$lat, labels = d$sigla_uf, cex = 0.6)
  })
  path
}

make_all_plots <- function(cases, rated, cfg) {
  paths <- c(
    anos = plot_by_year(cases, file.path(cfg$dirs$reports, "fig_anos.png")),
    ufs  = plot_top_uf(cases, file.path(cfg$dirs$reports, "fig_top_ufs.png")),
    mapa = plot_bubble_map(rated, file.path(cfg$dirs$reports, "fig_mapa_bolhas.png"))
  )
  extra <- plot_optional_choropleth(
    rated, file.path(cfg$dirs$reports, "fig_coropletico.png"), cfg
  )
  if (!is.null(extra)) paths <- c(paths, coropletico = extra)
  paths
}
