# ============================================================================
# 03_piloto_models.R — ANÁLISIS ESTADÍSTICO DEL PILOTO
# ============================================================================
# Este script aplica el análisis estadístico al dataset piloto:
#   - Cálculo de cambios y scores heurísticos.
#   - Pruebas pareadas y Friedman.
#   - Modelos lineales mixtos (LMM) con estructura condicion * tiempo.
#   - Bootstrap de coeficientes (opcional).
#   - Análisis de sensibilidad y robustez (opcional).
#   - Generación de tablas de efectos y contrastes.
# ============================================================================

# ── Dependencias ─────────────────────────────────────────────────────────────
# Este script asume que los siguientes módulos ya han sido sourceados:
#   R/00_config.R
#   R/07_models.R          (funciones de modelos y pruebas)
#   R/09_sensitivity.R     (opcional, para análisis de sensibilidad)
# y que 02_piloto_analysis.R ya se ha ejecutado, por lo que el objeto
# `datos_piloto` existe con todas las columnas necesarias.

# ── Función principal de modelado ──────────────────────────────────────────

#' Modelar los datos del piloto (análisis estadístico completo)
#'
#' @param datos_piloto Lista con elementos `largo` y `ancho` (datos del piloto).
#' @param incluir_sensibilidad Lógico, si se debe ejecutar análisis de sensibilidad.
#' @param hacer_bootstrap Lógico, si se debe ejecutar bootstrap para el modelo de n_palabras.
#' @param output_dir Directorio donde guardar los resultados.
#' @return Lista con resultados (cambios, inferenciales, modelos, etc.).
modelar_piloto <- function(datos_piloto,
                           incluir_sensibilidad = TRUE,
                           hacer_bootstrap = TRUE,
                           output_dir = OUTPUT_DIR_PILOTO) {
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("   ANÁLISIS ESTADÍSTICO DEL PILOTO — MODELOS Y PRUEBAS\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # ── 1. Verificar que datos_piloto tiene la estructura esperada ──────────
  if (!exists("datos_piloto") || !"ancho" %in% names(datos_piloto)) {
    stop("❌ 'datos_piloto' no existe o no tiene el elemento 'ancho'.")
  }
  
  ancho_piloto <- datos_piloto$ancho
  cat("   Participantes en piloto:", n_distinct(ancho_piloto$id_participante), "\n")
  cat("   Observaciones (filas en ancho):", nrow(ancho_piloto), "\n")
  cat("   Columnas disponibles:", ncol(ancho_piloto), "\n\n")
  
  # ── 2. Cálculo de cambios y scores heurísticos ──────────────────────────
  cat("→ Calculando cambios temporales y scores heurísticos...\n")
  cambios_scores <- calcular_cambios_y_scores(ancho_piloto)
  
  # Guardar cambios y scores
  write.csv(cambios_scores,
            file.path(output_dir, "tablas", "piloto_cambios_y_scores.csv"),
            row.names = FALSE)
  cat("✓ Cambios y scores guardados.\n")
  
  # ── 3. Pruebas inferenciales (pareadas y Friedman) ──────────────────────
  cat("→ Realizando pruebas inferenciales (pareadas y Friedman)...\n")
  
  # Seleccionar variables disponibles para pruebas
  vars_candidatas <- c("n_palabras", "n_palabras_calculado", "n_tokens",
                       "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
  vars_presentes <- c()
  for (v in vars_candidatas) {
    if (all(paste0(v, "_t", 1:3) %in% names(ancho_piloto))) {
      vars_presentes <- c(vars_presentes, v)
    }
  }
  cat("   Variables disponibles para pruebas:", paste(vars_presentes, collapse = ", "), "\n")
  
  resultados_inferenciales <- realizar_pruebas_inferenciales(
    ancho_piloto,
    config = list(
      variables_pareadas = vars_presentes,
      variables_friedman = vars_presentes,
      metodo_ajuste = "holm"
    )
  )
  
  # Extraer tablas de resultados
  if (!is.null(resultados_inferenciales$pareadas) && nrow(resultados_inferenciales$pareadas) > 0) {
    write.csv(resultados_inferenciales$pareadas,
              file.path(output_dir, "tablas", "piloto_pruebas_pareadas.csv"),
              row.names = FALSE)
    cat("✓ Pruebas pareadas guardadas.\n")
  }
  # Friedman (puede ser una lista)
  if (length(resultados_inferenciales$friedman) > 0) {
    # Guardar resumen de Friedman en un CSV
    friedman_df <- do.call(rbind, lapply(names(resultados_inferenciales$friedman), function(var) {
      if (!is.null(resultados_inferenciales$friedman[[var]]$friedman)) {
        resultados_inferenciales$friedman[[var]]$friedman
      } else {
        data.frame(variable = var, estadistico = NA, gl = NA, p_valor = NA)
      }
    }))
    write.csv(friedman_df,
              file.path(output_dir, "tablas", "piloto_friedman.csv"),
              row.names = FALSE)
    cat("✓ Pruebas de Friedman guardadas.\n")
  }
  
  # ── 4. Modelos mixtos ────────────────────────────────────────────────────
  cat("→ Ajustando modelos mixtos...\n")
  
  # Identificar variables con datos completos en T1, T2, T3
  # Excluir n_palabras (vacía en piloto) y cualquier variable con < 3 valores no faltantes
  vars_a_excluir <- c()
  
  # n_palabras está vacía al 100% en el piloto → excluir
  if ("n_palabras" %in% vars_presentes) {
    n_nas <- sum(is.na(ancho_piloto[[paste0("n_palabras_t1")]])) +
             sum(is.na(ancho_piloto[[paste0("n_palabras_t2")]])) +
             sum(is.na(ancho_piloto[[paste0("n_palabras_t3")]]))
    n_total <- nrow(ancho_piloto) * 3
    if (n_nas >= n_total * 0.99) {  # esencialmente vacía
      vars_a_excluir <- c(vars_a_excluir, "n_palabras")
      cat("   → n_palabras excluida (columna vacía en piloto).\n")
    }
  }
  
  # Excluir cualquier variable con < 3 valores no faltantes en total (T1+T2+T3)
  for (v in vars_presentes) {
    if (v %in% vars_a_excluir) next
    cols_t <- paste0(v, "_t", 1:3)
    n_nas <- sum(sapply(cols_t, function(c) sum(is.na(ancho_piloto[[c]]))))
    n_total <- nrow(ancho_piloto) * 3
    n_no_faltantes <- n_total - n_nas
    if (n_no_faltantes < 3) {
      vars_a_excluir <- c(vars_a_excluir, v)
      cat(sprintf("   → %s excluida (solo %d valores no faltantes de %d).\n",
                  v, n_no_faltantes, n_total))
    }
  }
  
  vars_presentes <- setdiff(vars_presentes, vars_a_excluir)
  cat("   Variables finales para modelado:", paste(vars_presentes, collapse = ", "), "\n\n")
  
  # El piloto no tiene demora, así que forzamos incluir_demora = FALSE
  resultados_modelos <- list()
  todos_p_vals <- c()
  nombres_p_vals <- c()
  
  for (var in vars_presentes) {
    cat("\n   → Modelo para:", var, "\n")
    mod_obj <- ajustar_modelo(ancho_piloto, var, incluir_demora = FALSE)
    if (!is.null(mod_obj)) {
      res <- extraer_resultados(mod_obj)
      resultados_modelos[[var]] <- list(
        modelo = mod_obj$modelo,
        datos = mod_obj$datos,
        convergencia = mod_obj$convergencia,
        singular = mod_obj$singular,
        formula = mod_obj$formula,
        anova = res$anova,
        r2 = res$r2,
        posthoc = res$posthoc,
        p_terms = res$p_terms
      )
      # Recopilar p-valores para FDR global
      if (!is.null(res$p_terms)) {
        p_efectos <- res$p_terms
        todos_p_vals <- c(todos_p_vals, p_efectos)
        nombres_p_vals <- c(nombres_p_vals, paste(var, names(p_efectos), sep = "_"))
      }
      # Mostrar resumen
      if (!is.null(res$anova)) {
        cat("      ANOVA:\n")
        print(res$anova)
        if (!is.null(res$r2)) {
          cat("      R² marginal:", round(res$r2$R2_marginal, 3),
              " | condicional:", round(res$r2$R2_conditional, 3), "\n")
        }
      }
      if (length(res$posthoc) > 0) {
        cat("      Post-hoc (Tukey):\n")
        for (ph in names(res$posthoc)) {
          cat("        ", ph, ":\n")
          print(res$posthoc[[ph]])
        }
      }
    } else {
      cat("   ⚠ No se pudo ajustar modelo para ", var, "\n")
    }
  }
  
  # ── 5. Corrección FDR global ────────────────────────────────────────────
  if (length(todos_p_vals) > 0) {
    p_adj <- p.adjust(todos_p_vals, method = "fdr")
    for (var in names(resultados_modelos)) {
      if (!is.null(resultados_modelos[[var]]$anova) && "Pr(>F)" %in% colnames(resultados_modelos[[var]]$anova)) {
        anov <- resultados_modelos[[var]]$anova
        p_efectos <- anov[["Pr(>F)"]]
        idx <- which(nombres_p_vals %in% paste(var, names(p_efectos), sep = "_"))
        if (length(idx) > 0) {
          anov$p_FDR <- NA
          anov$p_FDR[match(names(p_efectos), rownames(anov))] <- p_adj[idx]
          resultados_modelos[[var]]$anova <- anov
        }
      }
    }
    cat("\n✓ FDR global aplicado a los modelos del piloto.\n")
  }
  
  # ── 6. Tablas de resumen y contrastes ──────────────────────────────────
  cat("\n→ Generando tablas de resumen y contrastes...\n")
  
  tabla_efectos <- tabla_resumen(resultados_modelos)
  if (!is.null(tabla_efectos) && nrow(tabla_efectos) > 0) {
    write.csv(tabla_efectos,
              file.path(output_dir, "tablas", "piloto_efectos_modelos_mixtos.csv"),
              row.names = FALSE)
    cat("✓ Tabla de efectos guardada.\n")
    print(tabla_efectos)
  }
  
  tabla_contrastes <- tabla_contrastes(resultados_modelos)
  if (!is.null(tabla_contrastes) && nrow(tabla_contrastes) > 0) {
    write.csv(tabla_contrastes,
              file.path(output_dir, "tablas", "piloto_contrastes_posthoc.csv"),
              row.names = FALSE)
    cat("✓ Tabla de contrastes guardada.\n")
  }
  
  # ── 7. Correlaciones de cambios ────────────────────────────────────────
  cat("\n→ Calculando correlaciones de cambios (Spearman)...\n")
  mat_cor <- calcular_correlaciones_cambios(ancho_piloto)
  if (!is.null(mat_cor)) {
    write.csv(as.data.frame(mat_cor),
              file.path(output_dir, "tablas", "piloto_correlaciones_cambios.csv"),
              row.names = TRUE)
    cat("✓ Correlaciones de cambios guardadas.\n")
  }
  
  # ── 8. Bootstrap (opcional) ─────────────────────────────────────────────
  boot_res <- NULL
  if (hacer_bootstrap && "n_palabras_calculado" %in% names(resultados_modelos)) {
    cat("\n→ Realizando bootstrap para modelo de n_palabras_calculado...\n")
    boot_res <- bootstrappear(resultados_modelos$n_palabras_calculado, nsim = 500, seed = 123)
    if (!is.null(boot_res)) {
      cat("   IC bootstrap (95% percentil):\n")
      print(round(boot_res$IC_percentil, 4))
      saveRDS(boot_res,
              file.path(output_dir, "modelos", "piloto_bootstrap_n_palabras_calculado.rds"))
      cat("✓ Bootstrap guardado.\n")
    }
  }
  # ── 9. Guardar modelos completos ────────────────────────────────────────
  saveRDS(resultados_modelos,
          file.path(output_dir, "modelos", "piloto_modelos_mixtos.rds"))
  cat("✓ Modelos completos guardados en:", file.path(output_dir, "modelos", "piloto_modelos_mixtos.rds"), "\n")
  
  # ── 10. Análisis de sensibilidad (opcional) ─────────────────────────────
  if (incluir_sensibilidad) {
    cat("\n→ Ejecutando análisis de sensibilidad para el piloto...\n")
    # Ajustar directorio de salida para sensibilidad
    output_sens <- file.path(output_dir, "sensibilidad")
    dir.create(output_sens, recursive = TRUE, showWarnings = FALSE)
    
    # Usar la función de sensibilidad con los datos del piloto
    # Nota: el piloto no tiene demora, así que el modelo con demora se omitirá automáticamente.
    # Usar n_palabras_calculado como VD (n_palabras está vacía en piloto)
    resultados_sensibilidad <- ejecutar_analisis_sensibilidad(
      ancho = ancho_piloto,
      VD = "n_palabras_calculado",   # variable dependiente principal (con datos en piloto)
      output_dir = output_sens
    )
    cat("✓ Análisis de sensibilidad completado.\n")
  } else {
    cat("\n⚠ Análisis de sensibilidad omitido (incluir_sensibilidad = FALSE).\n")
  }
  
  # ── 11. Resumen final ──────────────────────────────────────────────────
  cat("\n✅ Modelado del piloto completado.\n")
  cat("   Modelos ajustados:", length(resultados_modelos), "\n")
  cat("   Tablas guardadas en:", file.path(output_dir, "tablas"), "\n")
  cat("   Modelos guardados en:", file.path(output_dir, "modelos"), "\n")
  if (incluir_sensibilidad) {
    cat("   Análisis de sensibilidad en:", output_sens, "\n")
  }
  
  # Devolver resultados en una lista
  return(list(
    cambios_scores = cambios_scores,
    inferencial = resultados_inferenciales,
    modelos = resultados_modelos,
    tabla_efectos = tabla_efectos,
    tabla_contrastes = tabla_contrastes,
    correlaciones = mat_cor,
    bootstrap = boot_res
  ))
}

# ── Ejecución directa (si se sourcea este script) ──────────────────────────
# Si este script se ejecuta directamente (no desde run_piloto.R),
# se cargará el piloto (si no existe) y se ejecutará el modelado.

if (interactive() || Sys.getenv("RUN_PILOTO") == "TRUE") {
  # Verificar si datos_piloto ya está cargado y procesado
  if (!exists("datos_piloto") || is.null(datos_piloto)) {
    cat("ℹ️ Cargando datos del piloto...\n")
    source(here::here("code", "R", "piloto", "01_piloto_import.R"))
    datos_piloto <- cargar_piloto()
    cat("ℹ️ Procesando datos del piloto...\n")
    source(here::here("code", "R", "piloto", "02_piloto_analysis.R"))
    datos_piloto <- procesar_piloto(datos_piloto,
                                    enriquecer_diccionarios = FALSE,
                                    calcular_embeddings = TRUE,
                                    calcular_pca = TRUE)
  }
  # Ejecutar modelado
  resultados_piloto <- modelar_piloto(datos_piloto,
                                      incluir_sensibilidad = TRUE,
                                      hacer_bootstrap = TRUE,
                                      output_dir = OUTPUT_DIR_PILOTO)
} else {
  cat("ℹ️ Función 'modelar_piloto()' definida. Ejecutar para modelar los datos.\n")
}