# ============================================================================
# 08_visualization.R — FIGURAS CIENTÍFICAS PARA MANUSCRITO
# ============================================================================
# Este módulo contiene:
#   - Temas y paletas de colores (accesibles para daltónicos).
#   - Funciones auxiliares para guardar figuras y exportar bilingües.
#   - Funciones para generar cada una de las 15 figuras del estudio.
#   - (Opcional) Función para generar todas las figuras y paneles.
#
# Las figuras toman como argumentos los objetos necesarios (datos, modelos,
# matrices de correlación, diccionarios) y devuelven objetos ggplot o NULL
# si faltan datos. Esto permite reutilizarlas en diferentes contextos.
# ============================================================================

# ── Dependencias (ya cargadas en 00_config.R) ──────────────────────────────
# library(ggplot2)
# library(cowplot)
# library(viridis)
# library(RColorBrewer)
# library(corrplot)
# library(emmeans)
# library(dplyr)
# library(tidyr)
# library(purrr)
# library(scales)
# library(patchwork)
# library(gridExtra)

# ── Paletas de colores (accesibles para daltónicos) ────────────────────────
paleta_condicion <- c("Texto"  = "#0072B2",  # azul
                      "Audio"  = "#D55E00",  # naranja
                      "Imagen" = "#009E73")  # verde
paleta_demora    <- c("ND" = "#56B4E9",      # celeste
                      "D"  = "#E69F00")      # amarillo
paleta_emocion   <- c("Bing" = "#CC79A7", "Tristeza" = "#0072B2", "Alegría" = "#009E73")

# ── Tema para figuras de manuscrito (estilo Q1) ─────────────────────────────
tema_cientifico <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.2), hjust = 0.5, margin = margin(b = 5)),
      plot.subtitle = element_text(size = rel(0.9), hjust = 0.5, color = "gray30", margin = margin(b = 10)),
      axis.title = element_text(face = "bold", size = rel(0.9)),
      axis.text = element_text(size = rel(0.8), color = "black"),
      legend.title = element_text(face = "bold", size = rel(0.8)),
      legend.text = element_text(size = rel(0.8)),
      legend.position = "bottom",
      legend.box = "horizontal",
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray95", color = NA),
      strip.text = element_text(face = "bold", size = rel(0.9)),
      plot.margin = margin(10, 15, 10, 15)
    )
}

# ── Tema editorial Q1 (versión alternativa, más simple) ────────────────────
theme_q1 <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(size = 14, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = 11),
      axis.title = element_text(size = 11, face = "bold"),
      axis.text = element_text(size = 10),
      legend.title = element_text(size = 10, face = "bold"),
      legend.text = element_text(size = 9),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      strip.text = element_text(face = "bold")
    )
}

# ── Función para guardar figura en formato estándar ────────────────────────
guardar_figura <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  dir.create(here::here("results", "figuras"), recursive = TRUE, showWarnings = FALSE)
  ggsave(
    filename = file.path("results/figuras", filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    device = "png",
    bg = "white"
  )
  cat(sprintf("✓ Figura guardada: %s\n", filename))
}

# ── Función para exportar figuras bilingües (ES/EN) ──────────────────────
crear_figura_bilingue <- function(p_es, p_en, nombre_base,
                                  ancho = 8, alto = 6, res = 300) {
  dir_es <- "results/graficos español"
  dir_en <- "results/graficos ingles"
  dir.create(dir_es, recursive = TRUE, showWarnings = FALSE)
  dir.create(dir_en, recursive = TRUE, showWarnings = FALSE)
  
  # Español
  ggsave(filename = file.path(dir_es, paste0(nombre_base, "_es.png")),
         plot = p_es, width = ancho, height = alto, dpi = res, bg = "white")
  ggsave(filename = file.path(dir_es, paste0(nombre_base, "_es.pdf")),
         plot = p_es, width = ancho, height = alto, device = cairo_pdf, bg = "white")
  
  # Inglés
  ggsave(filename = file.path(dir_en, paste0(nombre_base, "_en.png")),
         plot = p_en, width = ancho, height = alto, dpi = res, bg = "white")
  ggsave(filename = file.path(dir_en, paste0(nombre_base, "_en.pdf")),
         plot = p_en, width = ancho, height = alto, device = cairo_pdf, bg = "white")
  
  invisible(TRUE)
}

# ── Función auxiliar para obtener IC del modelo (emmeans) ──────────────────
obtener_ic_modelo <- function(modelo, nuevo_datos = NULL) {
  # Devuelve un dataframe con ajustes e IC 95% para los datos de entrada
  if (is.null(modelo)) return(NULL)
  emm <- emmeans(modelo, ~ condicion | tiempo, adjust = "tukey")
  df <- as.data.frame(emm)
  df$tiempo <- factor(df$tiempo, levels = c("T1","T2","T3"))
  return(df)
}

# ── FIGURA 1: Evolución de palabras por condición (con bootstrap IC) ──────
crear_fig1 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  # Trayectorias individuales + media con IC bootstrap
  dl <- datos_ancho %>%
    select(id_participante, condicion, n_palabras_t1, n_palabras_t2, n_palabras_t3) %>%
    pivot_longer(cols = starts_with("n_palabras"),
                 names_to = "tiempo",
                 values_to = "palabras") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("n_palabras_t1","n_palabras_t2","n_palabras_t3"),
                           labels = c("T1\n(sin estímulo)", "T2\n(1 estímulo)", "T3\n(3 estímulos)")))
  
  # Calcular medias e IC bootstrap (percentil 95%)
  medias_ic <- dl %>%
    group_by(condicion, tiempo) %>%
    summarise(
      media = mean(palabras, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(palabras, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(palabras, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(dl, aes(x = tiempo, y = palabras, color = condicion, group = id_participante)) +
    geom_line(alpha = 0.2, linewidth = 0.4, aes(group = id_participante)) +
    geom_ribbon(data = medias_ic, aes(y = media, ymin = ic_inf, ymax = ic_sup,
                                      fill = condicion, group = condicion),
                alpha = 0.2, inherit.aes = FALSE) +
    geom_line(data = medias_ic, aes(y = media, color = condicion, group = condicion),
              linewidth = 1.2, inherit.aes = FALSE) +
    geom_point(data = medias_ic, aes(y = media, color = condicion),
               size = 3, inherit.aes = FALSE) +
    scale_color_manual(values = paleta_condicion) +
    scale_fill_manual(values = paleta_condicion) +
    labs(
      title = "Evolución de la extensión textual por condición",
      subtitle = "Líneas grises = trayectorias individuales · Banda = IC 95% bootstrap · Puntos = media",
      x = "Iteración",
      y = "Número de palabras",
      color = "Condición",
      fill = "Condición"
    ) +
    tema_cientifico() +
    theme(legend.position = "bottom")
}

# ── FIGURA 2: Evolución de palabras por demora ─────────────────────────────
crear_fig2 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    filter(!is.na(demora)) %>%
    select(id_participante, condicion, demora, n_palabras_t1, n_palabras_t2, n_palabras_t3) %>%
    pivot_longer(cols = starts_with("n_palabras"),
                 names_to = "tiempo",
                 values_to = "palabras") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("n_palabras_t1","n_palabras_t2","n_palabras_t3"),
                           labels = c("T1", "T2", "T3")))
  
  n_grupo <- dl %>%
    group_by(demora) %>%
    summarise(n = n_distinct(id_participante)) %>%
    mutate(label = paste0(demora, " (n=", n, ")"))
  dl <- left_join(dl, n_grupo, by = "demora")
  
  ggplot(dl, aes(x = tiempo, y = palabras, color = label, group = label)) +
    stat_summary(fun = mean, geom = "line", linewidth = 1.2) +
    stat_summary(fun = mean, geom = "point", size = 3) +
    stat_summary(fun.data = mean_se, geom = "errorbar", width = 0.15, alpha = 0.6) +
    geom_jitter(aes(color = label), alpha = 0.3, width = 0.1, size = 1.5) +
    scale_color_manual(values = paleta_demora, name = "Demora") +
    labs(
      title = "Distribución de palabras por demora",
      subtitle = "Media ± error estándar · solo fuente principal (demora disponible)",
      x = "Iteración",
      y = "Número de palabras"
    ) +
    tema_cientifico()
}

# ── FIGURA 3: Evolución emocional ─────────────────────────────────────────
crear_fig3 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    select(id_participante, condicion,
           bing_t1, bing_t2, bing_t3,
           sadness_t1, sadness_t2, sadness_t3,
           joy_t1, joy_t2, joy_t3) %>%
    pivot_longer(cols = -c(id_participante, condicion),
                 names_to = c("emocion", "tiempo"),
                 names_pattern = "(.*)_t(\\d)",
                 values_to = "valor") %>%
    mutate(
      tiempo = factor(paste0("T", tiempo), levels = c("T1","T2","T3")),
      emocion = factor(emocion,
                       levels = c("bing", "sadness", "joy"),
                       labels = c("Sentimiento global\n(Bing)", "Tristeza\n(NRC)", "Alegría\n(NRC)"))
    )
  
  ggplot(dl, aes(x = tiempo, y = valor, color = condicion, group = condicion)) +
    stat_summary(fun = mean, geom = "line", linewidth = 1.2) +
    stat_summary(fun = mean, geom = "point", size = 3) +
    stat_summary(fun.data = mean_se, geom = "errorbar", width = 0.15, alpha = 0.6) +
    facet_wrap(~ emocion, scales = "free_y", ncol = 3) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Evolución emocional por condición",
      subtitle = "Media ± error estándar · Bing = valencia global, NRC = emociones específicas",
      x = "Iteración",
      y = "Puntuación",
      color = "Condición"
    ) +
    tema_cientifico() +
    theme(strip.text = element_text(face = "bold", size = 10))
}

# ── FIGURA 4: Diversidad léxica (TTR) por condición ──────────────────────
crear_fig4 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    select(id_participante, condicion, ttr_t1, ttr_t2, ttr_t3) %>%
    pivot_longer(cols = starts_with("ttr"),
                 names_to = "tiempo",
                 values_to = "ttr") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("ttr_t1","ttr_t2","ttr_t3"),
                           labels = c("T1", "T2", "T3")))
  
  medias_ic <- dl %>%
    group_by(condicion, tiempo) %>%
    summarise(
      media = mean(ttr, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(ttr, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(ttr, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(dl, aes(x = tiempo, y = ttr, color = condicion, group = condicion)) +
    geom_jitter(alpha = 0.2, width = 0.1, size = 1.5) +
    geom_ribbon(data = medias_ic, aes(y = media, ymin = ic_inf, ymax = ic_sup,
                                      fill = condicion, group = condicion),
                alpha = 0.2, inherit.aes = FALSE) +
    geom_line(data = medias_ic, aes(y = media, color = condicion),
              linewidth = 1.2, inherit.aes = FALSE) +
    geom_point(data = medias_ic, aes(y = media, color = condicion),
               size = 3, inherit.aes = FALSE) +
    scale_color_manual(values = paleta_condicion) +
    scale_fill_manual(values = paleta_condicion) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    labs(
      title = "Diversidad léxica (TTR) por condición",
      subtitle = "Type-Token Ratio · Mayor valor = mayor variedad · Nota: TTR depende de la longitud del texto",
      x = "Iteración",
      y = "TTR medio",
      color = "Condición",
      fill = "Condición"
    ) +
    tema_cientifico()
}

# ── FIGURA 5: Medias marginales estimadas (modelo mixto) ──────────────────
crear_fig5 <- function(modelo_mixto) {
  if (is.null(modelo_mixto)) return(NULL)
  emm <- emmeans(modelo_mixto, ~ condicion | tiempo, adjust = "tukey")
  df <- as.data.frame(emm)
  df$tiempo <- factor(df$tiempo, levels = c("T1","T2","T3"))
  
  p <- ggplot(df, aes(x = tiempo, y = emmean, color = condicion, group = condicion)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.15, alpha = 0.7) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Medias marginales estimadas — modelo mixto",
      subtitle = "Número de palabras · IC 95% (Tukey)",
      x = "Iteración",
      y = "Palabras estimadas",
      color = "Condición"
    ) +
    tema_cientifico()
  p
}

# ── FIGURA 6: Scores de influencia (exploratorios) ────────────────────────
crear_fig6 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    select(id_participante, condicion,
           score_influencia_T2, score_influencia_T3, score_complejidad) %>%
    pivot_longer(cols = starts_with("score"),
                 names_to = "score",
                 values_to = "valor") %>%
    mutate(
      score = factor(score,
                     levels = c("score_influencia_T2", "score_influencia_T3", "score_complejidad"),
                     labels = c("Influencia T2\n(1 estímulo)", "Influencia T3\n(3 estímulos)",
                                "Complejidad\nlingüística"))
    )
  
  n_grupo <- dl %>%
    group_by(condicion, score) %>%
    summarise(n = n_distinct(id_participante), .groups = "drop") %>%
    mutate(label = paste0(condicion, " (n=", n, ")"))
  dl <- left_join(dl, n_grupo, by = c("condicion", "score"))
  
  ggplot(dl, aes(x = condicion, y = valor, fill = condicion, color = condicion)) +
    geom_boxplot(alpha = 0.5, outlier.shape = NA) +
    geom_jitter(alpha = 0.5, width = 0.2, size = 1.5) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    facet_wrap(~ score, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = paleta_condicion, guide = "none") +
    scale_color_manual(values = paleta_condicion, guide = "none") +
    labs(
      title = "Scores de influencia (exploratorios) por condición",
      subtitle = "Scores derivados con ponderaciones heurísticas · No validados psicométricamente",
      x = "Condición",
      y = "Score"
    ) +
    tema_cientifico() +
    theme(legend.position = "none")
}

# ── FIGURA 7: Matriz de correlaciones (Spearman) ──────────────────────────
crear_fig7 <- function(cor_mat) {
  if (is.null(cor_mat)) return(NULL)
  # Ordenar por cluster
  hc <- hclust(as.dist(1 - cor_mat), method = "ward.D2")
  orden <- hc$order
  cor_mat_ord <- cor_mat[orden, orden]
  
  # Usar corrplot (devuelve NULL, pero dibuja en el dispositivo activo)
  # Esta función debe ser llamada dentro de un dispositivo gráfico (png, pdf, etc.)
  corrplot(cor_mat_ord, method = "color", type = "upper",
           order = "original",
           tl.cex = 0.7, tl.col = "black",
           addCoef.col = "black", number.cex = 0.6,
           col = COL2("RdBu", 10),
           diag = FALSE,
           title = "Correlaciones Spearman (variables de cambio)",
           mar = c(0,0,2,0))
}

# ── FIGURA 8: Cambios T1→T2 y T2→T3 en variables principales ────────────
crear_fig8 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  vars_cambio <- c("cambio_palabras_t1t2", "cambio_palabras_t2t3",
                   "cambio_bing_t1t2", "cambio_bing_t2t3",
                   "cambio_ttr_t1t2", "cambio_ttr_t2t3")
  dl <- datos_ancho %>%
    select(id_participante, condicion, all_of(vars_cambio)) %>%
    pivot_longer(cols = all_of(vars_cambio),
                 names_to = "cambio",
                 values_to = "valor") %>%
    mutate(
      tipo = ifelse(grepl("_t1t2$", cambio), "T1→T2", "T2→T3"),
      variable = gsub("_t1t2|_t2t3", "", cambio),
      variable = factor(variable,
                        levels = c("cambio_palabras", "cambio_bing", "cambio_ttr"),
                        labels = c("Palabras", "Sentimiento (Bing)", "TTR"))
    )
  
  ic_boot <- dl %>%
    group_by(condicion, variable, tipo) %>%
    summarise(
      media = mean(valor, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(ic_boot, aes(x = condicion, y = media, color = condicion)) +
    geom_point(size = 3, position = position_dodge(0.3)) +
    geom_errorbar(aes(ymin = ic_inf, ymax = ic_sup), width = 0.2, position = position_dodge(0.3)) +
    facet_grid(variable ~ tipo, scales = "free_y") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    scale_color_manual(values = paleta_condicion, guide = "none") +
    labs(
      title = "Cambios longitudinales en variables principales",
      subtitle = "Media e IC 95% bootstrap · Línea horizontal en 0 indica ausencia de cambio",
      x = "Condición",
      y = "Cambio medio"
    ) +
    tema_cientifico() +
    theme(legend.position = "none")
}

# ── FIGURA 9: Trayectorias individuales (palabras) ────────────────────────
crear_fig9 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    select(id_participante, condicion, n_palabras_t1, n_palabras_t2, n_palabras_t3) %>%
    pivot_longer(cols = starts_with("n_palabras"),
                 names_to = "tiempo",
                 values_to = "palabras") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("n_palabras_t1","n_palabras_t2","n_palabras_t3"),
                           labels = c("T1", "T2", "T3")))
  
  ggplot(dl, aes(x = tiempo, y = palabras, color = condicion, group = id_participante)) +
    geom_line(alpha = 0.3, linewidth = 0.5) +
    stat_summary(aes(group = condicion), fun = mean, geom = "line", linewidth = 1.5) +
    stat_summary(aes(group = condicion), fun = mean, geom = "point", size = 3) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Trayectorias individuales de extensión textual",
      subtitle = "Cada línea = un participante · Líneas gruesas = media por condición",
      x = "Iteración",
      y = "Número de palabras",
      color = "Condición"
    ) +
    tema_cientifico()
}

# ── FIGURA 10: Interacción condición × tiempo (emmeans) ───────────────────
crear_fig10 <- function(modelo_mixto) {
  if (is.null(modelo_mixto)) return(NULL)
  emm <- emmeans(modelo_mixto, ~ condicion | tiempo, adjust = "tukey")
  df <- as.data.frame(emm)
  df$tiempo <- factor(df$tiempo, levels = c("T1","T2","T3"))
  
  ggplot(df, aes(x = tiempo, y = emmean, color = condicion, group = condicion)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.15, alpha = 0.7) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Interacción Condición × Tiempo",
      subtitle = "Medias marginales estimadas del modelo mixto · IC 95% (Tukey)",
      x = "Iteración",
      y = "Valor estimado",
      color = "Condición"
    ) +
    tema_cientifico()
}

# ── FIGURA 11: Efecto de demora sobre cambios en palabras ─────────────────
crear_fig11 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    filter(!is.na(demora)) %>%
    select(id_participante, condicion, demora,
           cambio_palabras_t1t2, cambio_palabras_t2t3, cambio_palabras_total) %>%
    pivot_longer(cols = starts_with("cambio_palabras"),
                 names_to = "cambio",
                 values_to = "valor") %>%
    mutate(
      cambio = factor(cambio,
                      levels = c("cambio_palabras_t1t2", "cambio_palabras_t2t3", "cambio_palabras_total"),
                      labels = c("T1→T2", "T2→T3", "T1→T3"))
    )
  
  ic_boot <- dl %>%
    group_by(demora, cambio) %>%
    summarise(
      media = mean(valor, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(ic_boot, aes(x = demora, y = media, fill = demora)) +
    geom_col(position = position_dodge(0.9), alpha = 0.7) +
    geom_errorbar(aes(ymin = ic_inf, ymax = ic_sup), width = 0.2) +
    facet_wrap(~ cambio, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = paleta_demora, guide = "none") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(
      title = "Efecto de la demora sobre cambios en palabras",
      subtitle = "Media e IC 95% bootstrap · Solo fuente principal",
      x = "Demora",
      y = "Cambio en palabras"
    ) +
    tema_cientifico()
}

# ── FIGURA 12: Cambio emocional multivariado (heatmap) ────────────────────
crear_fig12 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  emociones <- c("sadness", "joy", "fear", "trust", "anger", "anticipation", "surprise", "disgust")
  cambios <- c()
  for (e in emociones) {
    cambios <- c(cambios, paste0("cambio_", e, "_t1t2"), paste0("cambio_", e, "_t2t3"))
  }
  
  dl <- datos_ancho %>%
    select(condicion, all_of(cambios)) %>%
    group_by(condicion) %>%
    summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    pivot_longer(cols = -condicion,
                 names_to = "cambio",
                 values_to = "media") %>%
    mutate(
      emocion = gsub("cambio_|_t1t2|_t2t3", "", cambio),
      tipo = ifelse(grepl("_t1t2$", cambio), "T1→T2", "T2→T3"),
      emocion = factor(emocion, levels = emociones)
    )
  
  ggplot(dl, aes(x = tipo, y = emocion, fill = media)) +
    geom_tile(color = "white") +
    facet_wrap(~ condicion, ncol = 3) +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                         midpoint = 0, name = "Cambio medio") +
    labs(
      title = "Cambio emocional multivariado por condición",
      subtitle = "Cambio medio en emociones NRC · Azul = disminución, Rojo = aumento",
      x = "",
      y = "Emoción"
    ) +
    tema_cientifico() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# ── FIGURA 13: Diccionarios temáticos (normalizados) ──────────────────────
crear_fig13 <- function(datos_ancho, diccionarios) {
  if (is.null(datos_ancho) || is.null(diccionarios)) return(NULL)
  temas <- names(diccionarios)
  dl <- datos_ancho %>%
    select(id_participante, condicion, n_palabras_t1, n_palabras_t2, n_palabras_t3)
  
  for (tema in temas) {
    for (t in 1:3) {
      col_name <- paste0(tema, "_t", t)
      if (col_name %in% names(datos_ancho)) {
        dl[[paste0("rate_", tema, "_t", t)]] <- dl[[col_name]] / dl[[paste0("n_palabras_t", t)]] * 1000
      }
    }
  }
  
  dl_long <- dl %>%
    select(id_participante, condicion, starts_with("rate_")) %>%
    pivot_longer(cols = starts_with("rate_"),
                 names_to = c("tema", "tiempo"),
                 names_pattern = "rate_(.*)_t(\\d)",
                 values_to = "rate") %>%
    mutate(
      tiempo = factor(paste0("T", tiempo), levels = c("T1","T2","T3")),
      tema = factor(tema, levels = temas)
    )
  
  medias <- dl_long %>%
    group_by(condicion, tema, tiempo) %>%
    summarise(media = mean(rate, na.rm = TRUE), .groups = "drop")
  
  ggplot(medias, aes(x = tiempo, y = media, color = condicion, group = condicion)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    facet_wrap(~ tema, scales = "free_y", ncol = 5) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Evolución de diccionarios temáticos (tasa por 1000 palabras)",
      subtitle = "Temas basados en la estética de Hopper · Normalizado por longitud del texto",
      x = "Iteración",
      y = "Frecuencia por 1000 palabras",
      color = "Condición"
    ) +
    tema_cientifico() +
    theme(strip.text = element_text(face = "bold", size = 7))
}

# ── FIGURA 14: Similitud textual (Coseno y Jaccard) ──────────────────────
crear_fig14 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  dl <- datos_ancho %>%
    select(id_participante, condicion,
           cos_t1_t2, cos_t2_t3, cos_t1_t3,
           jac_t1_t2, jac_t2_t3, jac_t1_t3) %>%
    pivot_longer(cols = -c(id_participante, condicion),
                 names_to = "medida",
                 values_to = "valor") %>%
    mutate(
      tipo = ifelse(grepl("cos", medida), "Coseno", "Jaccard"),
      comparacion = factor(
        gsub("cos_|jac_", "", medida),
        levels = c("t1_t2", "t2_t3", "t1_t3"),
        labels = c("T1 vs T2", "T2 vs T3", "T1 vs T3")
      )
    )
  
  ggplot(dl, aes(x = condicion, y = valor, fill = condicion)) +
    geom_boxplot(alpha = 0.6, outlier.shape = NA) +
    geom_jitter(alpha = 0.3, width = 0.1, size = 1) +
    facet_grid(tipo ~ comparacion, scales = "free_y") +
    scale_fill_manual(values = paleta_condicion, guide = "none") +
    labs(
      title = "Similitud textual entre iteraciones",
      subtitle = "Coseno y Jaccard basados en frecuencia de tokens",
      x = "Condición",
      y = "Similitud"
    ) +
    tema_cientifico()
}

# ── FIGURA 15: Mapa integrado de cambio (exploratorio) ────────────────────
crear_fig15 <- function(datos_ancho) {
  if (is.null(datos_ancho)) return(NULL)
  vars_cambio <- c("cambio_palabras_t1t2", "cambio_palabras_t2t3",
                   "cambio_ttr_t1t2", "cambio_ttr_t2t3",
                   "cambio_bing_t1t2", "cambio_bing_t2t3",
                   "cambio_sadness_t1t2", "cambio_sadness_t2t3",
                   "cambio_joy_t1t2", "cambio_joy_t2t3")
  
  dl <- datos_ancho %>%
    select(condicion, all_of(vars_cambio)) %>%
    group_by(condicion) %>%
    summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    pivot_longer(cols = -condicion,
                 names_to = "cambio",
                 values_to = "media") %>%
    mutate(
      variable = gsub("cambio_|_t1t2|_t2t3", "", cambio),
      tipo = ifelse(grepl("_t1t2$", cambio), "T1→T2", "T2→T3"),
      variable = factor(variable, levels = unique(variable))
    ) %>%
    group_by(variable, tipo) %>%
    mutate(z = scale(media)[,1]) %>%
    ungroup()
  
  ggplot(dl, aes(x = tipo, y = variable, fill = z)) +
    geom_tile(color = "white") +
    facet_wrap(~ condicion, ncol = 3) +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                         midpoint = 0, name = "Z-score") +
    labs(
      title = "Mapa integrado de cambio (exploratorio)",
      subtitle = "Cambios estandarizados por condición · Rojo = aumento, Azul = disminución",
      x = "",
      y = "Variable"
    ) +
    tema_cientifico() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# ──────────────────────────────────────────────────────────────────────────
# (Opcional) Función para generar todas las figuras y paneles combinados
# ──────────────────────────────────────────────────────────────────────────
generar_todas_figuras <- function(datos, modelos, cor_mat, diccionarios_hopper) {
  # datos: lista con elementos `ancho` y `largo`
  # modelos: lista con modelos mixtos (debe contener `palabras$modelo`)
  # cor_mat: matriz de correlaciones
  # diccionarios_hopper: lista de diccionarios temáticos
  
  figuras <- list()
  
  # Verificar disponibilidad de objetos
  if (is.null(datos$ancho)) {
    warning("datos$ancho no disponible. No se generarán figuras.")
    return(NULL)
  }
  ancho <- datos$ancho
  
  # Generar figuras individuales
  figuras$fig1 <- tryCatch(crear_fig1(ancho), error = function(e) { warning("fig1 falló: ", e$message); NULL })
  figuras$fig2 <- tryCatch(crear_fig2(ancho), error = function(e) { warning("fig2 falló: ", e$message); NULL })
  figuras$fig3 <- tryCatch(crear_fig3(ancho), error = function(e) { warning("fig3 falló: ", e$message); NULL })
  figuras$fig4 <- tryCatch(crear_fig4(ancho), error = function(e) { warning("fig4 falló: ", e$message); NULL })
  figuras$fig6 <- tryCatch(crear_fig6(ancho), error = function(e) { warning("fig6 falló: ", e$message); NULL })
  figuras$fig8 <- tryCatch(crear_fig8(ancho), error = function(e) { warning("fig8 falló: ", e$message); NULL })
  figuras$fig9 <- tryCatch(crear_fig9(ancho), error = function(e) { warning("fig9 falló: ", e$message); NULL })
  figuras$fig11 <- tryCatch(crear_fig11(ancho), error = function(e) { warning("fig11 falló: ", e$message); NULL })
  figuras$fig12 <- tryCatch(crear_fig12(ancho), error = function(e) { warning("fig12 falló: ", e$message); NULL })
  figuras$fig13 <- tryCatch(crear_fig13(ancho, diccionarios_hopper), error = function(e) { warning("fig13 falló: ", e$message); NULL })
  figuras$fig14 <- tryCatch(crear_fig14(ancho), error = function(e) { warning("fig14 falló: ", e$message); NULL })
  figuras$fig15 <- tryCatch(crear_fig15(ancho), error = function(e) { warning("fig15 falló: ", e$message); NULL })
  
  # Figuras que requieren modelo mixto
  if (!is.null(modelos$palabras$modelo)) {
    figuras$fig5 <- tryCatch(crear_fig5(modelos$palabras$modelo), error = function(e) { warning("fig5 falló: ", e$message); NULL })
    figuras$fig10 <- tryCatch(crear_fig10(modelos$palabras$modelo), error = function(e) { warning("fig10 falló: ", e$message); NULL })
  } else {
    warning("Modelo de palabras no disponible, figuras 5 y 10 omitidas.")
  }
  
  # Figura 7 (correlaciones) se guarda como PNG aparte porque usa corrplot
  if (!is.null(cor_mat)) {
    tryCatch({
      png("results/figuras/fig7_correlaciones.png", width = 1400, height = 1400, res = 140)
      crear_fig7(cor_mat)
      dev.off()
      cat("✓ Figura guardada: fig7_correlaciones.png\n")
    }, error = function(e) warning("fig7 falló: ", e$message))
  } else {
    warning("cor_mat no disponible, figura 7 omitida.")
  }
  
  # Guardar figuras (las que son ggplot)
  for (nm in names(figuras)) {
    if (nm != "fig7" && !is.null(figuras[[nm]])) {
      archivo <- paste0(nm, ".png")
      guardar_figura(figuras[[nm]], archivo)
    }
  }
  
  # ── Paneles combinados ──────────────────────────────────────────────────
  if (!is.null(figuras$fig1) && !is.null(figuras$fig4) && !is.null(figuras$fig9)) {
    panel_main <- plot_grid(figuras$fig1, figuras$fig4, figuras$fig9,
                            ncol = 1, labels = c("A", "B", "C"), label_size = 12)
    guardar_figura(panel_main, "panel_principal.png", width = 9, height = 15)
  }
  if (!is.null(figuras$fig3) && !is.null(figuras$fig12)) {
    panel_emocion <- plot_grid(figuras$fig3, figuras$fig12,
                               ncol = 1, labels = c("A", "B"), label_size = 12)
    guardar_figura(panel_emocion, "panel_emocional.png", width = 10, height = 12)
  }
  if (!is.null(figuras$fig8) && !is.null(figuras$fig11)) {
    panel_cambios <- plot_grid(figuras$fig8, figuras$fig11,
                               ncol = 1, labels = c("A", "B"), label_size = 12)
    guardar_figura(panel_cambios, "panel_cambios.png", width = 10, height = 12)
  }
  
  cat("✓ Generación de figuras completada.\n")
  return(invisible(figuras))
}