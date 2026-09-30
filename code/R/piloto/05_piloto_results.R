# ============================================================================
# 05_piloto_results.R — EXPORTACIÓN DE RESULTADOS DEL PILOTO
# ============================================================================
# Este script recopila todos los resultados del análisis piloto y los exporta
# en formatos listos para el artículo científico (tablas CSV, objetos RDS,
# resúmenes ejecutivos, etc.).
#
# Genera:
#   - Tablas de descriptivos por condición y tiempo.
#   - Tabla de efectos de modelos mixtos (con p-valores crudos y FDR).
#   - Tabla de contrastes post-hoc.
#   - Matriz de correlaciones (Spearman).
#   - Resultados de bootstrap (si existen).
#   - Resumen ejecutivo en texto plano.
#   - Versión en Excel (opcional, si writexl está disponible).
# ============================================================================

# ── Dependencias ─────────────────────────────────────────────────────────────
# Este script asume que los módulos 00 a 04 ya han sido ejecutados y que
# los objetos `datos_piloto` y `resultados_piloto` existen en el entorno.

# ── Función principal de exportación ──────────────────────────────────────

#' Exportar todos los resultados del análisis piloto
#'
#' @param datos_piloto Lista con elementos `largo` y `ancho`.
#' @param resultados_piloto Lista con resultados del modelado.
#' @param output_dir Directorio base de salida (por defecto OUTPUT_DIR_PILOTO).
#' @param export_excel Lógico, si se desea exportar a Excel (requiere writexl).
#' @return Lista con rutas de los archivos generados.
exportar_resultados_piloto <- function(datos_piloto,
                                       resultados_piloto,
                                       output_dir = OUTPUT_DIR_PILOTO,
                                       export_excel = TRUE) {
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("   EXPORTACIÓN DE RESULTADOS DEL PILOTO\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # Crear carpeta de tablas
  tablas_dir <- file.path(output_dir, "tablas")
  dir.create(tablas_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Crear carpeta para objetos RDS
  modelos_dir <- file.path(output_dir, "modelos")
  dir.create(modelos_dir, recursive = TRUE, showWarnings = FALSE)
  
  # ── 1. Descriptivos de métricas lingüísticas ────────────────────────────
  cat("→ Generando descriptivos lingüísticos...\n")
  
  # Identificar columnas numéricas con patrón _t1, _t2, _t3
  cols_num <- names(datos_piloto$ancho)[
    grepl("_t[123]$", names(datos_piloto$ancho)) &
      sapply(datos_piloto$ancho, is.numeric)
  ]
  
  if (length(cols_num) > 0) {
    desc_largo <- datos_piloto$ancho %>%
      select(id_participante, condicion, all_of(cols_num)) %>%
      pivot_longer(
        cols = all_of(cols_num),
        names_to = "variable_tiempo",
        values_to = "valor"
      ) %>%
      separate(variable_tiempo, into = c("variable", "tiempo"), sep = "_t") %>%
      mutate(tiempo = paste0("T", tiempo)) %>%
      group_by(variable, condicion, tiempo) %>%
      summarise(
        n = sum(!is.na(valor)),
        Media = mean(valor, na.rm = TRUE),
        SD = sd(valor, na.rm = TRUE),
        Mediana = median(valor, na.rm = TRUE),
        Min = min(valor, na.rm = TRUE),
        Max = max(valor, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(across(where(is.numeric), ~ round(.x, 3)))
    
    write.csv(desc_largo, file.path(tablas_dir, "descriptivos_piloto.csv"), row.names = FALSE)
    cat("   ✓ descriptivos_piloto.csv\n")
  } else {
    cat("   ⚠ No se encontraron variables numéricas para descriptivos.\n")
  }
  
  # ── 2. Tabla de efectos de modelos mixtos ──────────────────────────────
  cat("→ Exportando tabla de efectos...\n")
  if (!is.null(resultados_piloto$tabla_efectos) && nrow(resultados_piloto$tabla_efectos) > 0) {
    write.csv(resultados_piloto$tabla_efectos,
              file.path(tablas_dir, "efectos_modelos_piloto.csv"),
              row.names = FALSE)
    cat("   ✓ efectos_modelos_piloto.csv\n")
  } else {
    cat("   ⚠ No hay tabla de efectos para exportar.\n")
  }
  
  # ── 3. Tabla de contrastes post-hoc ─────────────────────────────────────
  cat("→ Exportando contrastes post-hoc...\n")
  if (!is.null(resultados_piloto$tabla_contrastes) && nrow(resultados_piloto$tabla_contrastes) > 0) {
    write.csv(resultados_piloto$tabla_contrastes,
              file.path(tablas_dir, "contrastes_piloto.csv"),
              row.names = FALSE)
    cat("   ✓ contrastes_piloto.csv\n")
  } else {
    cat("   ⚠ No hay contrastes post-hoc para exportar.\n")
  }
  
  # ── 4. Matriz de correlaciones (Spearman) ──────────────────────────────
  cat("→ Exportando matriz de correlaciones...\n")
  if (!is.null(resultados_piloto$correlaciones)) {
    cor_df <- as.data.frame(resultados_piloto$correlaciones)
    cor_df$variable <- rownames(cor_df)
    write.csv(cor_df, file.path(tablas_dir, "correlaciones_piloto.csv"), row.names = FALSE)
    cat("   ✓ correlaciones_piloto.csv\n")
  } else {
    cat("   ⚠ No hay matriz de correlaciones para exportar.\n")
  }
  
  # ── 5. Resultados de bootstrap ─────────────────────────────────────────
  cat("→ Exportando resultados de bootstrap...\n")
  if (!is.null(resultados_piloto$bootstrap)) {
    if (!is.null(resultados_piloto$bootstrap$IC_percentil)) {
      boot_df <- as.data.frame(resultados_piloto$bootstrap$IC_percentil)
      boot_df$coeficiente <- rownames(boot_df)
      write.csv(boot_df, file.path(tablas_dir, "bootstrap_piloto.csv"), row.names = FALSE)
      cat("   ✓ bootstrap_piloto.csv\n")
    }
    # Guardar objeto completo de bootstrap
    saveRDS(resultados_piloto$bootstrap,
            file.path(modelos_dir, "bootstrap_piloto.rds"))
    cat("   ✓ bootstrap_piloto.rds\n")
  } else {
    cat("   ⚠ No hay resultados de bootstrap.\n")
  }
  
  # ── 6. Objetos completos (modelos, datos procesados) ──────────────────
  cat("→ Guardando objetos completos (RDS)...\n")
  saveRDS(datos_piloto, file.path(modelos_dir, "datos_piloto_procesado.rds"))
  cat("   ✓ datos_piloto_procesado.rds\n")
  
  saveRDS(resultados_piloto, file.path(modelos_dir, "resultados_piloto.rds"))
  cat("   ✓ resultados_piloto.rds\n")
  
  # ── 7. Resumen ejecutivo en texto plano ──────────────────────────────
  cat("→ Generando resumen ejecutivo...\n")
  resumen_file <- file.path(output_dir, "piloto_results.txt")
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
    sig <- resultados_piloto$tabla_efectos %>%
      filter(p_FDR < 0.05 | p < 0.05)
    if (nrow(sig) > 0) {
      print(sig)
    } else {
      cat("No se encontraron efectos significativos.\n")
    }
  } else {
    cat("No hay tabla de efectos disponible.\n")
  }
  
  cat("\n--- Correlaciones de cambios (Spearman) ---\n")
  if (!is.null(resultados_piloto$correlaciones)) {
    print(round(resultados_piloto$correlaciones, 3))
  } else {
    cat("No se calcularon correlaciones.\n")
  }
  
  cat("\n--- Figuras generadas ---\n")
  figs_dir <- file.path(output_dir, "figuras")
  if (dir.exists(figs_dir)) {
    figs <- list.files(figs_dir, pattern = "\\.png$")
    if (length(figs) > 0) {
      for (f in figs) cat("  -", f, "\n")
    } else {
      cat("No se generaron figuras.\n")
    }
  } else {
    cat("Carpeta de figuras no encontrada.\n")
  }
  
  cat("\n===============================================================\n")
  sink()
  cat("   ✓ Resumen guardado en:", resumen_file, "\n")
  
  # ── 8. Exportación a Excel (opcional) ──────────────────────────────────
  if (export_excel && requireNamespace("writexl", quietly = TRUE)) {
    cat("→ Exportando a Excel...\n")
    library(writexl)
    
    # Crear lista de dataframes para Excel
    excel_list <- list()
    
    if (exists("desc_largo") && nrow(desc_largo) > 0) {
      excel_list[["Descriptivos"]] <- desc_largo
    }
    if (!is.null(resultados_piloto$tabla_efectos) && nrow(resultados_piloto$tabla_efectos) > 0) {
      excel_list[["Efectos"]] <- resultados_piloto$tabla_efectos
    }
    if (!is.null(resultados_piloto$tabla_contrastes) && nrow(resultados_piloto$tabla_contrastes) > 0) {
      excel_list[["Contrastes"]] <- resultados_piloto$tabla_contrastes
    }
    if (!is.null(resultados_piloto$correlaciones)) {
      cor_df <- as.data.frame(resultados_piloto$correlaciones)
      cor_df$variable <- rownames(cor_df)
      excel_list[["Correlaciones"]] <- cor_df
    }
    if (!is.null(resultados_piloto$bootstrap$IC_percentil)) {
      boot_df <- as.data.frame(resultados_piloto$bootstrap$IC_percentil)
      boot_df$coeficiente <- rownames(boot_df)
      excel_list[["Bootstrap"]] <- boot_df
    }
    
    if (length(excel_list) > 0) {
      write_xlsx(excel_list, file.path(tablas_dir, "resultados_piloto.xlsx"))
      cat("   ✓ resultados_piloto.xlsx\n")
    } else {
      cat("   ⚠ No hay datos para exportar a Excel.\n")
    }
  } else if (export_excel) {
    cat("⚠ El paquete 'writexl' no está instalado. Instálalo con install.packages('writexl') para exportar a Excel.\n")
  }
  
  # ── 9. Resumen de archivos generados ──────────────────────────────────
  cat("\n✅ Exportación de resultados completada.\n")
  cat("   Archivos generados en:", tablas_dir, "\n")
  cat("   Objetos RDS en:", modelos_dir, "\n")
  cat("   Resumen ejecutivo:", resumen_file, "\n\n")
  
  # Devolver lista con rutas de archivos generados
  archivos <- list(
    descriptivos = file.path(tablas_dir, "descriptivos_piloto.csv"),
    efectos = file.path(tablas_dir, "efectos_modelos_piloto.csv"),
    contrastes = file.path(tablas_dir, "contrastes_piloto.csv"),
    correlaciones = file.path(tablas_dir, "correlaciones_piloto.csv"),
    bootstrap = file.path(tablas_dir, "bootstrap_piloto.csv"),
    datos_rds = file.path(modelos_dir, "datos_piloto_procesado.rds"),
    resultados_rds = file.path(modelos_dir, "resultados_piloto.rds"),
    resumen = resumen_file,
    excel = if (export_excel && file.exists(file.path(tablas_dir, "resultados_piloto.xlsx"))) {
      file.path(tablas_dir, "resultados_piloto.xlsx")
    } else {
      NULL
    }
  )
  
  return(invisible(archivos))
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
  # Exportar resultados
  exportar_resultados_piloto(datos_piloto, resultados_piloto, export_excel = TRUE)
} else {
  cat("ℹ️ Función 'exportar_resultados_piloto()' definida. Ejecutar para exportar los resultados.\n")
}