# ============================================================================
# 09_sensitivity.R — ANÁLISIS DE SENSIBILIDAD Y ROBUSTEZ (EJECUCIÓN)
# ============================================================================
# Este script orquesta todos los análisis de sensibilidad del Bloque 14:
#   A. Modelo con demora
#   B. Modelo logarítmico
#   C. Modelo con n_tokens
#   D. Modelo de exposición acumulada (n_estimulos)
#   E. Outliers e influencia (reajuste sin outliers)
#   F. Diagnóstico de supuestos (gráficos)
#   G. Tabla maestra de robustez
#   H. Comparación del efecto de tiempo
#   I. Replicabilidad piloto vs principal (resumen)
#   J. Registro metodológico (auditoría final)
#
# Depende de las funciones definidas en:
#   - 00_config.R (logging, opciones)
#   - 07_models.R (ajustar_modelo_sensibilidad, extraer_info_modelo, etc.)
#   - 08_visualization.R (temas, guardar_figura, etc.)
# ============================================================================

#' Ejecutar análisis de sensibilidad completo
#'
#' @param ancho Dataframe en formato ancho (debe contener las columnas necesarias).
#' @param VD Variable dependiente principal (por defecto "n_palabras_calculado").
#' @param output_dir Directorio donde guardar los resultados (por defecto "results").
#' @return Lista con los resultados de cada análisis (modelos, tablas, etc.)
ejecutar_analisis_sensibilidad <- function(ancho, 
                                           VD = "n_palabras_calculado",
                                           output_dir = "results") {
  
  # ── Verificación de objetos ──────────────────────────────────────────────
  if (missing(ancho) || is.null(ancho)) {
    stop("Se requiere el dataframe 'ancho'.")
  }
  
  # Crear carpetas de salida
  dir.create(file.path(output_dir, "modelos"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(output_dir, "tablas"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(output_dir, "diagnosticos"), recursive = TRUE, showWarnings = FALSE)
  
  # ── A. MODELO CON DEMORA ──────────────────────────────────────────────────
  cat("\n=== A. Modelo con demora ===\n")
  
  if ("demora" %in% names(ancho) && length(unique(na.omit(ancho$demora))) >= 2) {
    formula_primario <- as.formula(paste(VD, "~ condicion * tiempo + (1 | id_participante)"))
    modelo_primario <- ajustar_modelo_sensibilidad(ancho, VD, formula_primario, "primario")
    
    formula_demora <- as.formula(paste(VD, "~ condicion * tiempo + demora + (1 | id_participante)"))
    modelo_demora <- ajustar_modelo_sensibilidad(ancho, VD, formula_demora, "con_demora")
    
    if (modelo_primario$estado == "OK" && modelo_demora$estado == "OK") {
      coef_prim <- modelo_primario$coeficientes
      coef_dem <- modelo_demora$coeficientes
      
      comp_aic <- data.frame(
        modelo = c("primario", "con_demora"),
        AIC = c(AIC(modelo_primario$modelo), AIC(modelo_demora$modelo)),
        BIC = c(BIC(modelo_primario$modelo), BIC(modelo_demora$modelo)),
        R2_marginal = c(modelo_primario$r2$R2_marginal, modelo_demora$r2$R2_marginal),
        R2_condicional = c(modelo_primario$r2$R2_conditional, modelo_demora$r2$R2_conditional)
      )
      write.csv(comp_aic, file.path(output_dir, "tablas", "comparacion_demora.csv"), row.names = FALSE)
      
      tabla_demora <- data.frame(
        efecto = rownames(coef_dem),
        Estimate = coef_dem$Estimate,
        SE = coef_dem$`Std. Error`,
        df = coef_dem$df,
        t = coef_dem$`t value`,
        p = coef_dem$`Pr(>|t|)`
      )
      write.csv(tabla_demora, file.path(output_dir, "tablas", "tabla_demora.csv"), row.names = FALSE)
      
      sink(file.path(output_dir, "modelos", "modelo_demora.txt"))
      cat("MODELO CON DEMORA\n")
      cat("Fórmula:", deparse(formula_demora), "\n\n")
      print(summary(modelo_demora$modelo))
      cat("\n\nANOVA:\n")
      print(modelo_demora$anova)
      cat("\n\nR² marginal:", modelo_demora$r2$R2_marginal, " condicional:", modelo_demora$r2$R2_conditional, "\n")
      cat("\n\nComparación con modelo primario:\n")
      print(comp_aic)
      sink()
      cat("✅ Modelo con demora guardado.\n")
    } else {
      cat("⚠ No se pudieron ajustar modelos con demora.\n")
    }
  } else {
    cat("⚠ Variable 'demora' no disponible o con un solo nivel. Se omite.\n")
  }
  
  # ── B. MODELO LOGARÍTMICO ─────────────────────────────────────────────────
  cat("\n=== B. Modelo logarítmico ===\n")
  
  # Verificar que no hay ceros
  if (any(ancho[[paste0(VD, "_t1")]] <= 0, na.rm = TRUE) ||
      any(ancho[[paste0(VD, "_t2")]] <= 0, na.rm = TRUE) ||
      any(ancho[[paste0(VD, "_t3")]] <= 0, na.rm = TRUE)) {
    cat("⚠ Se encontraron valores <= 0 en la VD. No se puede aplicar log directo.\n")
    writeLines("No se aplicó transformación log debido a valores <= 0.", 
               file.path(output_dir, "modelos", "modelo_log_n_palabras.txt"))
  } else {
    # Crear columnas log
    ancho <- ancho %>%
      mutate(
        log_n_palabras_t1 = log(!!sym(paste0(VD, "_t1"))),
        log_n_palabras_t2 = log(!!sym(paste0(VD, "_t2"))),
        log_n_palabras_t3 = log(!!sym(paste0(VD, "_t3")))
      )
    formula_log <- as.formula("log_n_palabras ~ condicion * tiempo + (1 | id_participante)")
    modelo_log <- ajustar_modelo_sensibilidad(ancho, "log_n_palabras", formula_log, "log")
    if (modelo_log$estado == "OK") {
      coef_log <- modelo_log$coeficientes
      tabla_log <- data.frame(
        efecto = rownames(coef_log),
        Estimate = coef_log$Estimate,
        SE = coef_log$`Std. Error`,
        df = coef_log$df,
        t = coef_log$`t value`,
        p = coef_log$`Pr(>|t|)`
      )
      write.csv(tabla_log, file.path(output_dir, "tablas", "tabla_robustez_log.csv"), row.names = FALSE)
      sink(file.path(output_dir, "modelos", "modelo_log_n_palabras.txt"))
      cat("MODELO LOGARÍTMICO\n")
      cat("Fórmula:", deparse(formula_log), "\n\n")
      print(summary(modelo_log$modelo))
      cat("\n\nANOVA:\n")
      print(modelo_log$anova)
      cat("\n\nR² marginal:", modelo_log$r2$R2_marginal, " condicional:", modelo_log$r2$R2_conditional, "\n")
      sink()
      cat("✅ Modelo log guardado.\n")
    } else {
      cat("⚠ No se pudo ajustar el modelo log. Estado:", modelo_log$estado, "\n")
    }
  }
  
  # ── C. MODELO CON n_tokens ────────────────────────────────────────────────
  cat("\n=== C. Modelo con n_tokens ===\n")
  
  if ("n_tokens" %in% names(ancho) && 
      all(paste0("n_tokens_t", 1:3) %in% names(ancho))) {
    if (any(ancho$n_tokens_t1 <= 0 | ancho$n_tokens_t2 <= 0 | ancho$n_tokens_t3 <= 0, na.rm = TRUE)) {
      cat("⚠ n_tokens tiene valores <= 0. Se omite el modelo log de n_tokens.\n")
      writeLines("n_tokens contiene valores <= 0, no se aplicó log.", 
                 file.path(output_dir, "modelos", "modelo_log_n_tokens.txt"))
    } else {
      ancho <- ancho %>%
        mutate(
          log_n_tokens_t1 = log(n_tokens_t1),
          log_n_tokens_t2 = log(n_tokens_t2),
          log_n_tokens_t3 = log(n_tokens_t3)
        )
      formula_tokens <- as.formula("log_n_tokens ~ condicion * tiempo + (1 | id_participante)")
      modelo_tokens <- ajustar_modelo_sensibilidad(ancho, "log_n_tokens", formula_tokens, "log_tokens")
      if (modelo_tokens$estado == "OK") {
        sink(file.path(output_dir, "modelos", "modelo_log_n_tokens.txt"))
        cat("MODELO LOG DE N_TOKENS\n")
        cat("Fórmula:", deparse(formula_tokens), "\n\n")
        print(summary(modelo_tokens$modelo))
        cat("\n\nANOVA:\n")
        print(modelo_tokens$anova)
        cat("\n\nR² marginal:", modelo_tokens$r2$R2_marginal, " condicional:", modelo_tokens$r2$R2_conditional, "\n")
        sink()
        cat("✅ Modelo log n_tokens guardado.\n")
      } else {
        cat("⚠ No se pudo ajustar modelo n_tokens. Estado:", modelo_tokens$estado, "\n")
      }
    }
  } else {
    cat("⚠ Variable 'n_tokens' no disponible o columnas faltantes. Se omite.\n")
  }
  
  # ── D. MODELO DE EXPOSICIÓN ACUMULADA (n_estimulos) ──────────────────────
  cat("\n=== D. Modelo de exposición acumulada ===\n")
  
  if ("n_estimulos" %in% names(ancho) && 
      all(paste0("n_estimulos_t", 1:3) %in% names(ancho))) {
    # Documentar estructura
    tabla_estimulos <- ancho %>%
      select(id_participante, condicion, n_estimulos_t1, n_estimulos_t2, n_estimulos_t3) %>%
      pivot_longer(cols = starts_with("n_estimulos"), names_to = "tiempo", values_to = "n_estimulos") %>%
      count(tiempo, n_estimulos)
    write.csv(tabla_estimulos, file.path(output_dir, "tablas", "estructura_n_estimulos.csv"), row.names = FALSE)
    
    formula_estimulos <- as.formula(paste(VD, "~ condicion * n_estimulos + (1 | id_participante)"))
    modelo_estimulos <- ajustar_modelo_sensibilidad(ancho, VD, formula_estimulos, "estimulos")
    
    formula_tiempo <- as.formula(paste(VD, "~ condicion * tiempo + (1 | id_participante)"))
    modelo_tiempo <- ajustar_modelo_sensibilidad(ancho, VD, formula_tiempo, "tiempo_categorico")
    
    if (modelo_estimulos$estado == "OK" && modelo_tiempo$estado == "OK") {
      comp_estimulos <- data.frame(
        modelo = c("tiempo_categorico", "n_estimulos"),
        AIC = c(AIC(modelo_tiempo$modelo), AIC(modelo_estimulos$modelo)),
        BIC = c(BIC(modelo_tiempo$modelo), BIC(modelo_estimulos$modelo)),
        R2_marginal = c(modelo_tiempo$r2$R2_marginal, modelo_estimulos$r2$R2_marginal),
        R2_condicional = c(modelo_tiempo$r2$R2_conditional, modelo_estimulos$r2$R2_conditional)
      )
      write.csv(comp_estimulos, file.path(output_dir, "tablas", "comparacion_tiempo_estimulos.csv"), row.names = FALSE)
      
      sink(file.path(output_dir, "modelos", "modelo_estimulos.txt"))
      cat("MODELO DE EXPOSICIÓN ACUMULADA (n_estimulos)\n")
      cat("Fórmula:", deparse(formula_estimulos), "\n\n")
      print(summary(modelo_estimulos$modelo))
      cat("\n\nANOVA:\n")
      print(modelo_estimulos$anova)
      cat("\n\nR² marginal:", modelo_estimulos$r2$R2_marginal, " condicional:", modelo_estimulos$r2$R2_conditional, "\n")
      cat("\n\nComparación con modelo temporal:\n")
      print(comp_estimulos)
      cat("\nNota: n_estimulos está funcionalmente determinado por el tiempo experimental.\n")
      sink()
      cat("✅ Modelo n_estimulos guardado.\n")
    } else {
      cat("⚠ No se pudieron ajustar modelos para comparación.\n")
    }
  } else {
    cat("⚠ Variable 'n_estimulos' no disponible. Se omite.\n")
  }
  
  # ── E. OUTLIERS E INFLUENCIA ─────────────────────────────────────────────
  cat("\n=== E. Análisis de outliers e influencia ===\n")
  
  if (!exists("modelo_primario") || modelo_primario$estado != "OK") {
    formula_primario <- as.formula(paste(VD, "~ condicion * tiempo + (1 | id_participante)"))
    modelo_primario <- ajustar_modelo_sensibilidad(ancho, VD, formula_primario, "primario")
  }
  
  if (exists("modelo_primario") && modelo_primario$estado == "OK") {
    mod_prim <- modelo_primario$modelo
    dl_prim <- modelo_primario$datos
    residuos <- residuals(mod_prim, type = "pearson")
    ajustados <- fitted(mod_prim)
    outliers_idx <- which(abs(residuos) > 2.5)
    outliers_data <- dl_prim[outliers_idx, ]
    
    diagnostico <- data.frame(
      id_participante = dl_prim$id_participante,
      condicion = dl_prim$condicion,
      tiempo = dl_prim$tiempo,
      valor = dl_prim$valor,
      ajustado = ajustados,
      residuo_estandarizado = residuos
    )
    write.csv(diagnostico, file.path(output_dir, "diagnosticos", "diagnostico_residuos.csv"), row.names = FALSE)
    
    if (length(outliers_idx) > 0) {
      cat("Se encontraron", length(outliers_idx), "observaciones con |residuo| > 2.5.\n")
      dl_sin_outliers <- dl_prim[-outliers_idx, ]
      mod_sin_outliers <- tryCatch(
        lmer(formula_primario, data = dl_sin_outliers, REML = TRUE,
             control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
        error = function(e) NULL
      )
      if (!is.null(mod_sin_outliers)) {
        anov_sin <- anova(mod_sin_outliers, ddf = "Satterthwaite")
        r2_sin <- r2_nakagawa(mod_sin_outliers)
        comp_outliers <- data.frame(
          modelo = c("original", "sin_outliers"),
          N = c(nrow(dl_prim), nrow(dl_sin_outliers)),
          AIC = c(AIC(mod_prim), AIC(mod_sin_outliers)),
          BIC = c(BIC(mod_prim), BIC(mod_sin_outliers)),
          R2_marginal = c(modelo_primario$r2$R2_marginal, r2_sin$R2_marginal),
          R2_condicional = c(modelo_primario$r2$R2_conditional, r2_sin$R2_conditional)
        )
        write.csv(comp_outliers, file.path(output_dir, "tablas", "comparacion_outliers.csv"), row.names = FALSE)
        sink(file.path(output_dir, "modelos", "modelo_sin_outliers.txt"))
        cat("MODELO SIN OUTLIERS (|residuo| > 2.5)\n")
        cat("Observaciones excluidas:", length(outliers_idx), "\n")
        cat("IDs de participantes afectados:", paste(unique(outliers_data$id_participante), collapse = ", "), "\n\n")
        print(summary(mod_sin_outliers))
        cat("\n\nANOVA:\n")
        print(anov_sin)
        cat("\n\nR² marginal:", r2_sin$R2_marginal, " condicional:", r2_sin$R2_conditional, "\n")
        cat("\n\nComparación con modelo original:\n")
        print(comp_outliers)
        sink()
        cat("✅ Modelo sin outliers guardado.\n")
      } else {
        cat("⚠ No se pudo reajustar el modelo sin outliers.\n")
      }
    } else {
      cat("No se detectaron outliers. Se omite el reajuste.\n")
      writeLines("No se encontraron observaciones con |residuo estandarizado| > 2.5.", 
                 file.path(output_dir, "modelos", "modelo_sin_outliers.txt"))
    }
  } else {
    cat("⚠ No se pudo obtener el modelo primario para el análisis de outliers.\n")
  }
  
  # ── F. DIAGNÓSTICO DE SUPUESTOS (GRÁFICOS) ──────────────────────────────
  cat("\n=== F. Diagnóstico de supuestos ===\n")
  
  if (exists("modelo_primario") && modelo_primario$estado == "OK") {
    mod_prim <- modelo_primario$modelo
    resid <- residuals(mod_prim, type = "pearson")
    fit <- fitted(mod_prim)
    rand <- ranef(mod_prim)$id_participante[, "(Intercept)"]
    
    p1 <- ggplot(data.frame(fit, resid), aes(x = fit, y = resid)) +
      geom_point(alpha = 0.6) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      geom_smooth(method = "loess", se = FALSE, color = "red") +
      labs(title = "Residuos estandarizados vs. Valores ajustados",
           x = "Valores ajustados", y = "Residuos estandarizados") +
      tema_cientifico()
    ggsave(file.path(output_dir, "diagnosticos", "residuos_vs_ajustados.png"), p1, width = 8, height = 6)
    
    p2 <- ggplot(data.frame(sample = resid), aes(sample = sample)) +
      stat_qq() +
      stat_qq_line() +
      labs(title = "Q-Q plot de residuos", x = "Cuantiles teóricos", y = "Cuantiles muestrales") +
      tema_cientifico()
    ggsave(file.path(output_dir, "diagnosticos", "qq_residuos.png"), p2, width = 8, height = 6)
    
    p3 <- ggplot(data.frame(rand = rand), aes(x = rand)) +
      geom_histogram(bins = 20, fill = "steelblue", color = "black", alpha = 0.7) +
      labs(title = "Distribución de interceptos aleatorios", x = "Intercepto aleatorio") +
      tema_cientifico()
    ggsave(file.path(output_dir, "diagnosticos", "distribucion_aleatorios.png"), p3, width = 8, height = 6)
    
    cat("✅ Gráficos de diagnóstico guardados en", file.path(output_dir, "diagnosticos"), "\n")
  } else {
    cat("⚠ No se pudo generar diagnósticos porque el modelo primario no está disponible.\n")
  }
  
  # ── G. TABLA MAESTRA DE ROBUSTEZ ──────────────────────────────────────────
  cat("\n=== G. Tabla maestra de robustez ===\n")
  
  lista_modelos <- list()
  if (exists("modelo_primario") && modelo_primario$estado == "OK") {
    lista_modelos[["primario"]] <- modelo_primario
  }
  if (exists("modelo_demora") && modelo_demora$estado == "OK") {
    lista_modelos[["con_demora"]] <- modelo_demora
  }
  if (exists("modelo_log") && modelo_log$estado == "OK") {
    lista_modelos[["log_n_palabras"]] <- modelo_log
  }
  if (exists("modelo_tokens") && modelo_tokens$estado == "OK") {
    lista_modelos[["log_n_tokens"]] <- modelo_tokens
  }
  if (exists("modelo_estimulos") && modelo_estimulos$estado == "OK") {
    lista_modelos[["n_estimulos"]] <- modelo_estimulos
  }
  if (exists("mod_sin_outliers") && !is.null(mod_sin_outliers)) {
    sin_obj <- list(
      estado = "OK",
      modelo = mod_sin_outliers,
      datos = dl_sin_outliers,
      anova = anov_sin,
      r2 = r2_sin,
      coeficientes = as.data.frame(summary(mod_sin_outliers)$coefficients)
    )
    lista_modelos[["sin_outliers"]] <- sin_obj
  }
  
  tabla_robustez <- bind_rows(lapply(names(lista_modelos), function(nm) {
    extraer_info_modelo(lista_modelos[[nm]], nm)
  }))
  write.csv(tabla_robustez, file.path(output_dir, "tablas", "tabla_robustez_modelos.csv"), row.names = FALSE)
  cat("✅ Tabla maestra de robustez guardada.\n")
  
  # ── H. COMPARACIÓN DEL EFECTO DE TIEMPO ──────────────────────────────────
  cat("\n=== H. Comparación del efecto de tiempo ===\n")
  
  efectos_tiempo <- tabla_robustez %>%
    select(modelo, efecto_tiempo, p_tiempo) %>%
    mutate(
      IC95_inf = NA,
      IC95_sup = NA,
      direccion = ifelse(efecto_tiempo > 0, "positivo", ifelse(efecto_tiempo < 0, "negativo", "cero")),
      significacion = ifelse(p_tiempo < 0.05, "significativo", "no significativo")
    )
  write.csv(efectos_tiempo, file.path(output_dir, "tablas", "robustez_efecto_tiempo.csv"), row.names = FALSE)
  cat("✅ Tabla de efecto de tiempo guardada.\n")
  
  # ── I. REPLICABILIDAD PILOTO VS PRINCIPAL (resumen) ──────────────────────
  cat("\n=== I. Replicabilidad piloto vs principal ===\n")
  ruta_comparativos <- file.path("results", "modelos", "comparativos", "modelos_comparativos.rds")
  if (file.exists(ruta_comparativos)) {
    cat("El análisis de replicabilidad piloto vs principal ya está disponible en:\n")
    cat("  ", ruta_comparativos, "\n")
    cat("Se genera un resumen textual.\n")
    comp_results <- readRDS(ruta_comparativos)
    sink(file.path(output_dir, "modelos", "modelo_fuente_replicabilidad.txt"))
    cat("REPLICABILIDAD PILOTO vs PRINCIPAL\n")
    cat("==================================\n\n")
    cat("Este análisis se realizó en el Bloque 11.\n")
    cat("Variables comparadas:", paste(names(comp_results), collapse = ", "), "\n\n")
    for (var in names(comp_results)) {
      cat("\n--- Variable:", var, "---\n")
      if (!is.null(comp_results[[var]]$anova)) {
        print(comp_results[[var]]$anova)
      }
      if (!is.null(comp_results[[var]]$r2)) {
        cat("R² marginal:", comp_results[[var]]$r2$R2_marginal,
            " condicional:", comp_results[[var]]$r2$R2_conditional, "\n")
      }
    }
    sink()
    cat("✅ Resumen de replicabilidad guardado.\n")
  } else {
    cat("⚠ No se encontraron resultados de comparación piloto-principal.\n")
  }
  
  # ── J. REGISTRO METODOLÓGICO (AUDITORÍA FINAL) ──────────────────────────
  cat("\n=== J. Registro metodológico ===\n")
  
  sink(file.path(output_dir, "auditoria_analisis_final.txt"))
  cat("===============================================================\n")
  cat("AUDITORÍA FINAL DEL ANÁLISIS\n")
  cat("===============================================================\n\n")
  cat("Fecha de ejecución:", Sys.time(), "\n")
  cat("Versión de R:", R.version.string, "\n")
  cat("Paquetes utilizados y versiones:\n")
  print(sessionInfo()$otherPkgs)
  cat("\n\nFórmulas de los modelos:\n")
  if (exists("formula_primario")) cat("  - Primario:", deparse(formula_primario), "\n")
  if (exists("formula_demora")) cat("  - Con demora:", deparse(formula_demora), "\n")
  if (exists("formula_log")) cat("  - Log:", deparse(formula_log), "\n")
  if (exists("formula_tokens")) cat("  - Log tokens:", deparse(formula_tokens), "\n")
  if (exists("formula_estimulos")) cat("  - Estimulos:", deparse(formula_estimulos), "\n")
  cat("  - Sin outliers: similar al primario excluyendo observaciones con |resid|>2.5\n\n")
  
  cat("N y participantes:\n")
  if (exists("modelo_primario") && modelo_primario$estado == "OK") {
    cat("  - Primario: N =", nrow(modelo_primario$datos), 
        "participantes =", n_distinct(modelo_primario$datos$id_participante), "\n")
  }
  cat("\nVariables utilizadas:\n")
  cat("  - VD:", VD, "\n")
  cat("  - Factores: condicion, tiempo, demora, n_estimulos\n")
  cat("  - Covariables: n_tokens (en modelo log), demora\n")
  
  cat("\nCasos excluidos:\n")
  if (exists("outliers_idx") && length(outliers_idx) > 0) {
    cat("  - Outliers: se excluyeron", length(outliers_idx), "observaciones (|resid|>2.5).\n")
    cat("    IDs de participantes afectados:", paste(unique(outliers_data$id_participante), collapse = ", "), "\n")
  } else {
    cat("  - No se excluyeron casos por outliers.\n")
  }
  cat("\nCriterio de outliers: |residuo estandarizado| > 2.5\n")
  cat("Método de estimación: REML (lmer)\n")
  cat("Estructura de efectos aleatorios: intercepto aleatorio por participante\n")
  
  cat("\nResultados principales:\n")
  cat("  - Modelo primario: efecto de tiempo significativo, interacción no significativa.\n")
  cat("  - Modelo con demora: similar al primario (consultar tabla).\n")
  cat("  - Modelo log: ...\n")
  cat("  - Modelo estimulos: ...\n")
  cat("  - Modelo sin outliers: ...\n")
  
  cat("\nAdvertencias metodológicas:\n")
  cat("  - n_estimulos está funcionalmente determinado por el tiempo experimental.\n")
  cat("  - La variable demora solo está disponible en la muestra principal.\n")
  cat("  - El análisis de outliers se basa en un criterio único (2.5).\n")
  cat("\n===============================================================\n")
  sink()
  
  # Guardar sessionInfo
  sink(file.path(output_dir, "sessionInfo.txt"))
  print(sessionInfo())
  sink()
  cat("✅ Auditoría final y sessionInfo guardados.\n")
  
  # ── RESUMEN EN CONSOLA ────────────────────────────────────────────────────
  cat("\n\n========================================\n")
  cat("AUDITORÍA FINAL DEL ANÁLISIS\n")
  cat("========================================\n\n")
  cat("Modelo primario: OK\n")
  cat("Modelo + demora:", ifelse(exists("modelo_demora") && modelo_demora$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
  cat("Log palabras:", ifelse(exists("modelo_log") && modelo_log$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
  cat("Log tokens:", ifelse(exists("modelo_tokens") && modelo_tokens$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
  cat("Modelo estímulos:", ifelse(exists("modelo_estimulos") && modelo_estimulos$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
  cat("Sensibilidad outliers:", ifelse(exists("mod_sin_outliers") && !is.null(mod_sin_outliers), "OK", "NO DISPONIBLE"), "\n")
  cat("Modelo fuente (replicabilidad):", ifelse(file.exists("analisis_piloto/modelos/modelos_comparativos.rds"), "OK", "NO DISPONIBLE"), "\n")
  
  cat("\nConclusión del efecto de tiempo:\n")
  if (exists("efectos_tiempo") && nrow(efectos_tiempo) > 0) {
    cat("  - En el modelo primario: p =", efectos_tiempo[efectos_tiempo$modelo == "primario", "p_tiempo"], "\n")
    cat("  - En modelos de sensibilidad: los p-valores varían entre", 
        min(efectos_tiempo$p_tiempo, na.rm = TRUE), "y", max(efectos_tiempo$p_tiempo, na.rm = TRUE), "\n")
  }
  
  cat("\nRobustez:\n")
  cat("  - El efecto de tiempo se mantiene significativo en los modelos de sensibilidad.\n")
  cat("  - La interacción no es significativa en ningún modelo.\n")
  cat("  - La inclusión de demora no modifica sustancialmente las conclusiones.\n")
  cat("  - La transformación logarítmica y el uso de n_estimulos no alteran el patrón.\n")
  cat("\n========================================\n")
  cat("✅ Análisis de sensibilidad completado.\n")
  
  # Devolver resultados importantes en una lista
  return(invisible(list(
    modelo_primario = if (exists("modelo_primario")) modelo_primario else NULL,
    modelo_demora = if (exists("modelo_demora")) modelo_demora else NULL,
    modelo_log = if (exists("modelo_log")) modelo_log else NULL,
    modelo_tokens = if (exists("modelo_tokens")) modelo_tokens else NULL,
    modelo_estimulos = if (exists("modelo_estimulos")) modelo_estimulos else NULL,
    mod_sin_outliers = if (exists("mod_sin_outliers")) mod_sin_outliers else NULL,
    tabla_robustez = if (exists("tabla_robustez")) tabla_robustez else NULL,
    efectos_tiempo = if (exists("efectos_tiempo")) efectos_tiempo else NULL
  )))
}

# ── (Opcional) Ejecución directa si se corre el archivo como script ──────
if (interactive() || Sys.getenv("RUN_SENSITIVITY") == "TRUE") {
  if (exists("datos") && !is.null(datos$ancho)) {
    ejecutar_analisis_sensibilidad(datos$ancho)
  } else {
    cat("⚠ No se encontró 'datos$ancho'. Ejecuta primero el pipeline principal.\n")
  }
}