# ============================================================================
# 04_piloto_figures.R — FIGURAS ESPECÍFICAS PARA EL PILOTO
# ============================================================================
# Este script genera figuras científicas para el manuscrito basado en el piloto.
# Utiliza las funciones de visualización del módulo R/08_visualization.R,
# pero aplicadas a los datos, modelos y correlaciones del piloto.
# Las figuras se guardan en la carpeta 'results/piloto/figuras/' y
# 'results/piloto/graficos_es/' y 'graficos_en/' para versiones bilingües.
# ============================================================================

# ── Dependencias ─────────────────────────────────────────────────────────────
# Este script asume que los siguientes módulos ya han sido sourceados:
#   R/00_config.R
#   R/08_visualization.R
# y que 00_piloto_config.R, 01_piloto_import.R, 02_piloto_analysis.R y
# 03_piloto_models.R ya se han ejecutado, por lo que los objetos `datos_piloto`
# y `resultados_piloto` existen.

# ── Función principal de generación de figuras ─────────────────────────────

#' Generar figuras para el piloto
#'
#' @param datos_piloto Lista con elementos `largo` y `ancho`.
#' @param resultados_piloto Lista con resultados del modelado (modelos, correlaciones, etc.).
#' @param diccionarios_hopper_piloto Lista de diccionarios temáticos (opcional,
#'        por defecto usa diccionarios_hopper_base).
#' @param output_dir Directorio base de salida (por defecto OUTPUT_DIR_PILOTO).
#' @return Lista con los objetos ggplot generados.
figuras_piloto <- function(datos_piloto,
                           resultados_piloto,
                           diccionarios_hopper_piloto = NULL,
                           output_dir = OUTPUT_DIR_PILOTO) {
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("   FIGURAS PILOTO — GENERACIÓN DE VISUALIZACIONES\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # Extraer objetos necesarios
  ancho <- datos_piloto$ancho
  modelos <- resultados_piloto$modelos
  mat_cor <- resultados_piloto$correlaciones
  if (is.null(diccionarios_hopper_piloto)) {
    diccionarios_hopper_piloto <- diccionarios_hopper_base
  }
  
  # Crear carpetas de salida
  fig_dir <- file.path(output_dir, "figuras")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  
  es_dir <- file.path(output_dir, "graficos_es")
  en_dir <- file.path(output_dir, "graficos_en")
  dir.create(es_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(en_dir, recursive = TRUE, showWarnings = FALSE)
  
  # ── 1. Generar figuras individuales ──────────────────────────────────────
  cat("→ Generando figuras...\n")
  figuras <- list()
  
  # Figura 1: Evolución de palabras por condición (piloto)
  tryCatch({
    figuras$fig1 <- crear_fig1(ancho)
    guardar_figura(figuras$fig1, "fig1_palabras_condicion_piloto.png",
                   width = 9, height = 6, dpi = 300, dir = fig_dir)
    cat("   ✓ fig1_palabras_condicion_piloto.png\n")
  }, error = function(e) warning("fig1 falló: ", e$message))
  
  # Figura 3: Evolución emocional (piloto)
  tryCatch({
    figuras$fig3 <- crear_fig3(ancho)
    guardar_figura(figuras$fig3, "fig3_emociones_piloto.png",
                   width = 12, height = 5, dpi = 300, dir = fig_dir)
    cat("   ✓ fig3_emociones_piloto.png\n")
  }, error = function(e) warning("fig3 falló: ", e$message))
  
  # Figura 4: TTR por condición (piloto)
  tryCatch({
    figuras$fig4 <- crear_fig4(ancho)
    guardar_figura(figuras$fig4, "fig4_ttr_piloto.png",
                   width = 9, height = 6, dpi = 300, dir = fig_dir)
    cat("   ✓ fig4_ttr_piloto.png\n")
  }, error = function(e) warning("fig4 falló: ", e$message))
  
  # Figura 8: Cambios T1→T2 y T2→T3 (piloto)
  tryCatch({
    figuras$fig8 <- crear_fig8(ancho)
    guardar_figura(figuras$fig8, "fig8_cambios_piloto.png",
                   width = 10, height = 7, dpi = 300, dir = fig_dir)
    cat("   ✓ fig8_cambios_piloto.png\n")
  }, error = function(e) warning("fig8 falló: ", e$message))
  
  # Figura 9: Trayectorias individuales (piloto)
  tryCatch({
    figuras$fig9 <- crear_fig9(ancho)
    guardar_figura(figuras$fig9, "fig9_trayectorias_individuales_piloto.png",
                   width = 9, height = 6, dpi = 300, dir = fig_dir)
    cat("   ✓ fig9_trayectorias_individuales_piloto.png\n")
  }, error = function(e) warning("fig9 falló: ", e$message))
  
  # Figura 12: Cambio emocional multivariado (piloto)
  tryCatch({
    figuras$fig12 <- crear_fig12(ancho)
    guardar_figura(figuras$fig12, "fig12_cambio_emocional_piloto.png",
                   width = 10, height = 6, dpi = 300, dir = fig_dir)
    cat("   ✓ fig12_cambio_emocional_piloto.png\n")
  }, error = function(e) warning("fig12 falló: ", e$message))
  
  # Figura 13: Diccionarios temáticos (piloto)
  tryCatch({
    figuras$fig13 <- crear_fig13(ancho, diccionarios_hopper_piloto)
    guardar_figura(figuras$fig13, "fig13_diccionarios_piloto.png",
                   width = 14, height = 8, dpi = 300, dir = fig_dir)
    cat("   ✓ fig13_diccionarios_piloto.png\n")
  }, error = function(e) warning("fig13 falló: ", e$message))
  
  # Figura 14: Similitud textual (piloto)
  tryCatch({
    figuras$fig14 <- crear_fig14(ancho)
    guardar_figura(figuras$fig14, "fig14_similitud_textual_piloto.png",
                   width = 10, height = 6, dpi = 300, dir = fig_dir)
    cat("   ✓ fig14_similitud_textual_piloto.png\n")
  }, error = function(e) warning("fig14 falló: ", e$message))
  
  # Figura 15: Mapa integrado de cambio (piloto)
  tryCatch({
    figuras$fig15 <- crear_fig15(ancho)
    guardar_figura(figuras$fig15, "fig15_mapa_cambio_piloto.png",
                   width = 10, height = 7, dpi = 300, dir = fig_dir)
    cat("   ✓ fig15_mapa_cambio_piloto.png\n")
  }, error = function(e) warning("fig15 falló: ", e$message))
  
  # Figura 5: Medias marginales estimadas (si existe modelo de palabras)
  if (!is.null(modelos$n_palabras$modelo)) {
    tryCatch({
      figuras$fig5 <- crear_fig5(modelos$n_palabras$modelo, ancho)
      if (!is.null(figuras$fig5)) {
        guardar_figura(figuras$fig5, "fig5_modelo_estimado_piloto.png",
                       width = 9, height = 6, dpi = 300, dir = fig_dir)
        cat("   ✓ fig5_modelo_estimado_piloto.png\n")
      }
    }, error = function(e) warning("fig5 falló: ", e$message))
  }
  
  # Figura 10: Interacción condición×tiempo (si existe modelo de palabras)
  if (!is.null(modelos$n_palabras$modelo)) {
    tryCatch({
      figuras$fig10 <- crear_fig10(modelos$n_palabras$modelo)
      if (!is.null(figuras$fig10)) {
        guardar_figura(figuras$fig10, "fig10_interaccion_piloto.png",
                       width = 9, height = 6, dpi = 300, dir = fig_dir)
        cat("   ✓ fig10_interaccion_piloto.png\n")
      }
    }, error = function(e) warning("fig10 falló: ", e$message))
  }
  
  # Figura 7: Matriz de correlaciones (si existe)
  if (!is.null(mat_cor)) {
    tryCatch({
      png(file.path(fig_dir, "fig7_correlaciones_piloto.png"),
          width = 1400, height = 1400, res = 140)
      crear_fig7(mat_cor)
      dev.off()
      cat("   ✓ fig7_correlaciones_piloto.png\n")
    }, error = function(e) warning("fig7 falló: ", e$message))
  }
  
  # ── 2. Generar versiones bilingües (español/inglés) ──────────────────────
  # Para las figuras que tienen traducción, podemos usar la función crear_figura_bilingue
  # pero necesitamos las versiones en inglés. Como las funciones crear_fig* ya
  # generan títulos en español, podemos crear versiones en inglés modificando los títulos.
  # Para simplificar, en este script solo generamos las figuras en español.
  # Si se desea bilingüe, se pueden adaptar las funciones crear_fig* para que acepten un
  # argumento `idioma` y luego llamar a crear_figura_bilingue.
  # Aquí se deja como mejora futura.
  
  # ── 3. Paneles combinados ─────────────────────────────────────────────────
  cat("→ Generando paneles combinados...\n")
  
  if (!is.null(figuras$fig1) && !is.null(figuras$fig4) && !is.null(figuras$fig9)) {
    panel_main <- plot_grid(figuras$fig1, figuras$fig4, figuras$fig9,
                            ncol = 1, labels = c("A", "B", "C"), label_size = 12)
    guardar_figura(panel_main, "panel_principal_piloto.png",
                   width = 9, height = 15, dpi = 300, dir = fig_dir)
    cat("   ✓ panel_principal_piloto.png\n")
  }
  
  if (!is.null(figuras$fig3) && !is.null(figuras$fig12)) {
    panel_emocion <- plot_grid(figuras$fig3, figuras$fig12,
                               ncol = 1, labels = c("A", "B"), label_size = 12)
    guardar_figura(panel_emocion, "panel_emocional_piloto.png",
                   width = 10, height = 12, dpi = 300, dir = fig_dir)
    cat("   ✓ panel_emocional_piloto.png\n")
  }
  
  if (!is.null(figuras$fig8) && !is.null(figuras$fig11)) {
    # Nota: fig11 requiere demora, el piloto no tiene, así que se omite.
    # En su lugar, podemos usar fig8 solo.
    panel_cambios <- plot_grid(figuras$fig8, ncol = 1, labels = "A", label_size = 12)
    guardar_figura(panel_cambios, "panel_cambios_piloto.png",
                   width = 10, height = 7, dpi = 300, dir = fig_dir)
    cat("   ✓ panel_cambios_piloto.png\n")
  }
  
  cat("✅ Figuras generadas y guardadas en:", output_dir, "\n\n")
  
  return(invisible(figuras))
}

# ── Función auxiliar para guardar figuras con directorio personalizado ────
# Sobrescribe la función guardar_figura del módulo 08 para usar un directorio específico.
guardar_figura <- function(plot, filename, width = 8, height = 6, dpi = 300, dir = NULL) {
  if (is.null(dir)) {
    dir <- "results/figuras"
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ggsave(
    filename = file.path(dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    device = "png",
    bg = "white"
  )
}

# ── Ejecución directa (si se sourcea este script) ──────────────────────────
if (interactive() || Sys.getenv("RUN_PILOTO") == "TRUE") {
  # Verificar que los objetos necesarios existen
  if (!exists("datos_piloto") || is.null(datos_piloto)) {
    stop("❌ datos_piloto no está disponible. Ejecuta primero 01_piloto_import.R y 02_piloto_analysis.R.")
  }
  if (!exists("resultados_piloto") || is.null(resultados_piloto)) {
    stop("❌ resultados_piloto no está disponible. Ejecuta primero 03_piloto_models.R.")
  }
  # Generar figuras
  figuras_piloto <- figuras_piloto(datos_piloto, resultados_piloto)
} else {
  cat("ℹ️ Función 'figuras_piloto()' definida. Ejecutar para generar las figuras.\n")
}