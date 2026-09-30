#!/usr/bin/env Rscript
# ============================================================================
# run_piloto.R — EJECUCIÓN COMPLETA DEL ANÁLISIS PILOTO
# ============================================================================
# Este script orquesta todo el pipeline del análisis piloto:
#   1. Carga la configuración global (R/00_config.R) y la específica del piloto.
#   2. Importa y normaliza los datos del piloto.
#   3. Aplica todo el procesamiento (texto, sentimiento, diccionarios, embeddings).
#   4. Ejecuta los análisis estadísticos (modelos, pruebas, bootstrap).
#   5. Genera las figuras y tablas.
#
# El script está diseñado para ser ejecutado de forma independiente,
# sin necesidad de los datos del estudio principal.
# ============================================================================

# ── 0. Configuración inicial ────────────────────────────────────────────────
# Asegurarse de que el paquete 'here' esté disponible
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   PIPELINE DE ANÁLISIS PILOTO — EXPERIMENTO NLP\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("Directorio raíz del proyecto:", here::here(), "\n\n")

# ── 1. Comprobación de existencia de los scripts necesarios ────────────────
cat("── Verificando scripts necesarios ────────────────────────────\n")

scripts_comunes <- c(
  "code/R/00_config.R",
  "code/R/01_import_data.R",
  "code/R/02_text_processing.R",
  "code/R/03_sentiment.R",
  "code/R/04_dictionaries.R",
  "code/R/05_embeddings.R",
  "code/R/06_similarity.R",
  "code/R/07_models.R",
  "code/R/08_visualization.R",
  "code/R/09_sensitivity.R"   # opcional, pero se incluye si existe
)

scripts_piloto <- c(
  "code/R/piloto/00_piloto_config.R",
  "code/R/piloto/01_piloto_import.R",
  "code/R/piloto/02_piloto_analysis.R",
  "code/R/piloto/03_piloto_models.R",
  "code/R/piloto/04_piloto_figures.R"
)

todos_scripts <- c(scripts_comunes, scripts_piloto)

faltan <- c()
for (scr in todos_scripts) {
  if (!file.exists(here(scr))) {
    faltan <- c(faltan, scr)
  }
}

if (length(faltan) > 0) {
  cat("❌ Faltan los siguientes scripts:\n")
  for (f in faltan) cat("   -", f, "\n")
  stop("No se pueden continuar. Asegúrate de que todos los scripts existan.")
} else {
  cat("✅ Todos los scripts necesarios están presentes.\n\n")
}

# ── 2. Cargar módulos comunes ──────────────────────────────────────────────
cat("── Cargando módulos comunes ──────────────────────────────────\n")

source(here("code", "R", "00_config.R"))
cat("✓ R/00_config.R cargado\n")

source(here("code", "R", "01_import_data.R"))
cat("✓ R/01_import_data.R cargado\n")

source(here("code", "R", "02_text_processing.R"))
cat("✓ R/02_text_processing.R cargado\n")

source(here("code", "R", "03_sentiment.R"))
cat("✓ R/03_sentiment.R cargado\n")

source(here("code", "R", "04_dictionaries.R"))
cat("✓ R/04_dictionaries.R cargado\n")

source(here("code", "R", "05_embeddings.R"))
cat("✓ R/05_embeddings.R cargado\n")

source(here("code", "R", "06_similarity.R"))
cat("✓ R/06_similarity.R cargado\n")

source(here("code", "R", "07_models.R"))
cat("✓ R/07_models.R cargado\n")

source(here("code", "R", "08_visualization.R"))
cat("✓ R/08_visualization.R cargado\n")

# Cargar 09_sensitivity.R si existe (no crítico para el piloto)
if (file.exists(here("code", "R", "09_sensitivity.R"))) {
  source(here("code", "R", "09_sensitivity.R"))
  cat("✓ R/09_sensitivity.R cargado (opcional)\n")
} else {
  cat("⚠ R/09_sensitivity.R no encontrado. Se omitirá el análisis de sensibilidad.\n")
}
cat("\n")

# ── 3. Cargar configuración específica del piloto ──────────────────────────
cat("── Cargando configuración específica del piloto ──────────────\n")
source(here("code", "R", "piloto", "00_piloto_config.R"))
cat("✓ R/piloto/00_piloto_config.R cargado\n\n")

# ── 4. Importar datos del piloto ───────────────────────────────────────────
cat("── Paso 1: Importación de datos ─────────────────────────────\n")
source(here("code", "R", "piloto", "01_piloto_import.R"))
if (!exists("datos_piloto")) {
  datos_piloto <- cargar_piloto()
}
cat("✅ Datos del piloto importados.\n")
cat("   Participantes:", n_distinct(datos_piloto$ancho$id_participante), "\n")
cat("   Observaciones (largo):", nrow(datos_piloto$largo), "\n")
cat("   Columnas en ancho:", ncol(datos_piloto$ancho), "\n\n")

# ── 5. Procesamiento analítico ─────────────────────────────────────────────
cat("── Paso 2: Procesamiento analítico ──────────────────────────\n")
source(here("code", "R", "piloto", "02_piloto_analysis.R"))
if (!exists("datos_piloto") || is.null(datos_piloto$ancho$t1_limpio)) {
  datos_piloto <- procesar_piloto(datos_piloto,
                                  enriquecer_diccionarios = FALSE,
                                  calcular_embeddings = TRUE,
                                  calcular_pca = TRUE)
}
cat("✅ Procesamiento analítico completado.\n")
cat("   Columnas en ancho después del procesamiento:", ncol(datos_piloto$ancho), "\n\n")

# ── 6. Modelado estadístico ─────────────────────────────────────────────────
cat("── Paso 3: Modelado estadístico ─────────────────────────────\n")
source(here("code", "R", "piloto", "03_piloto_models.R"))
if (!exists("resultados_piloto")) {
  resultados_piloto <- modelar_piloto(datos_piloto, realizar_sensibilidad = TRUE)
}
cat("✅ Modelado estadístico completado.\n")
cat("   Modelos ajustados:", length(resultados_piloto$modelos), "\n")
cat("   Tablas de efectos y contrastes generadas.\n\n")

# ── 7. Generación de figuras ───────────────────────────────────────────────
cat("── Paso 4: Generación de figuras ────────────────────────────\n")
source(here("code", "R", "piloto", "04_piloto_figures.R"))
figuras_piloto <- figuras_piloto(datos_piloto, resultados_piloto)
cat("✅ Figuras generadas.\n")
cat("   Directorio de figuras:", file.path(OUTPUT_DIR_PILOTO, "figuras"), "\n")
cat("   Directorio de gráficos español:", file.path(OUTPUT_DIR_PILOTO, "graficos_es"), "\n")
cat("   Directorio de gráficos inglés:", file.path(OUTPUT_DIR_PILOTO, "graficos_en"), "\n\n")

# ── 8. Resumen de resultados y guardado ────────────────────────────────────
cat("── Generando resumen de resultados ──────────────────────────\n")

resumen_file <- file.path(OUTPUT_DIR_PILOTO, "piloto_results.txt")
sink(resumen_file)

cat("===============================================================\n")
cat("RESUMEN DE RESULTADOS DEL ANÁLISIS PILOTO\n")
cat("===============================================================\n\n")
cat("Fecha de ejecución:", Sys.time(), "\n")
cat("Número de participantes:", n_distinct(datos_piloto$ancho$id_participante), "\n")
cat("Número de observaciones (largo):", nrow(datos_piloto$largo), "\n")
cat("Número de variables en ancho:", ncol(datos_piloto$ancho), "\n\n")

cat("--- Modelos ajustados ---\n")
cat("Variables modeladas:", paste(names(resultados_piloto$modelos), collapse = ", "), "\n\n")

cat("--- Tabla de efectos (p < 0.05) ---\n")
if (!is.null(resultados_piloto$tabla_efectos) && nrow(resultados_piloto$tabla_efectos) > 0) {
  print(resultados_piloto$tabla_efectos %>% filter(p_FDR < 0.05 | p < 0.05))
} else {
  cat("No se encontraron efectos significativos.\n")
}

cat("\n--- Correlaciones de cambios (Spearman) ---\n")
if (!is.null(resultados_piloto$correlaciones)) {
  print(round(resultados_piloto$correlaciones, 3))
} else {
  cat("No se calcularon correlaciones.\n")
}

cat("\n--- Figuras generadas ---\n")
figs <- list.files(file.path(OUTPUT_DIR_PILOTO, "figuras"), pattern = "\\.png$")
if (length(figs) > 0) {
  for (f in figs) cat("  -", f, "\n")
} else {
  cat("No se generaron figuras.\n")
}

cat("\n===============================================================\n")
sink()

cat("✅ Resumen guardado en:", resumen_file, "\n\n")

# ── 9. Mensaje final ──────────────────────────────────────────────────────
cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                 ANÁLISIS PILOTO COMPLETADO                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
cat("📁 Resultados disponibles en:\n")
cat("   -", OUTPUT_DIR_PILOTO, "\n")
cat("   - Resumen:", resumen_file, "\n\n")
cat("✅ El análisis piloto está listo para ser utilizado en el artículo científico.\n")