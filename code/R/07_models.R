# ============================================================================
# 07_models.R — MODELOS MIXTOS, PRUEBAS INFERENCIALES Y BOOTSTRAP
# ============================================================================
# Este módulo contiene funciones para:
#   - Calcular cambios temporales y scores heurísticos.
#   - Pruebas pareadas y Friedman.
#   - Ajuste de modelos lineales mixtos (LMM) con diagnóstico.
#   - Extracción de ANOVA, R², contrastes post-hoc.
#   - Bootstrap de coeficientes.
#   - Análisis de sensibilidad y robustez.
# ============================================================================

# ── SCORES HEURÍSTICOS ──────────────────────────────────────────────────────
config_scores_default <- function() {
  list(
    influencia_T2 = c(
      soledad              = 1.0,
      espera               = 1.0,
      incomunicacion       = 1.0,
      emociones_negativas  = 1.5,
      sadness              = 2.0,
      joy                  = -1.5,
      trust                = -1.5
    ),
    influencia_T3 = c(
      objetos      = 2.0,
      duda         = 1.0,
      desconexion  = 1.0,
      sadness      = 1.5,
      fear         = 1.0
    ),
    complejidad = c(
      palabras_oracion = 1.0,
      long_palabra     = 2.0
    ),
    audio_T3 = c(
      sadness = 2.0,
      fear    = 1.5
    )
  )
}

#' Calcular cambios temporales y scores de influencia
calcular_cambios_y_scores <- function(ancho, config_scores = config_scores_default()) {
  vars_existentes <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                       "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
  vars_disponibles <- c()
  for (v in vars_existentes) {
    if (all(paste0(v, "_t", 1:3) %in% names(ancho))) {
      vars_disponibles <- c(vars_disponibles, v)
    }
  }
  cat("Variables disponibles para calcular cambios:", paste(vars_disponibles, collapse = ", "), "\n")
  
  mutate_exprs <- list()
  for (v in vars_disponibles) {
    col1 <- paste0(v, "_t1")
    col2 <- paste0(v, "_t2")
    col3 <- paste0(v, "_t3")
    mutate_exprs[[paste0("cambio_", v, "_t1t2")]] <- rlang::expr(!!sym(col2) - !!sym(col1))
    mutate_exprs[[paste0("cambio_", v, "_t2t3")]] <- rlang::expr(!!sym(col3) - !!sym(col2))
    mutate_exprs[[paste0("cambio_", v, "_total")]] <- rlang::expr(!!sym(col3) - !!sym(col1))
    if (v %in% c("n_palabras", "n_palabras_calculado")) {
      mutate_exprs[[paste0("pct_cambio_", v, "_t1t2")]] <- 
        rlang::expr(ifelse(!!sym(col1) == 0, NA_real_, 100 * (!!sym(col2) - !!sym(col1)) / !!sym(col1)))
      mutate_exprs[[paste0("pct_cambio_", v, "_t2t3")]] <- 
        rlang::expr(ifelse(!!sym(col2) == 0, NA_real_, 100 * (!!sym(col3) - !!sym(col2)) / !!sym(col2)))
    }
  }
  
  emociones_existentes <- all(c("sadness_t1", "sadness_t2", "sadness_t3", 
                                "joy_t1", "joy_t2", "joy_t3",
                                "fear_t1", "fear_t2", "fear_t3",
                                "trust_t1", "trust_t2", "trust_t3") %in% names(ancho))
  diccionarios_existentes <- all(c("soledad_t1", "soledad_t2", "soledad_t3",
                                   "espera_t1", "espera_t2", "espera_t3",
                                   "incomunicacion_t1", "incomunicacion_t2", "incomunicacion_t3",
                                   "objetos_t1", "objetos_t2", "objetos_t3",
                                   "emociones_negativas_t1", "emociones_negativas_t2", "emociones_negativas_t3",
                                   "duda_t1", "duda_t2", "duda_t3",
                                   "desconexion_t1", "desconexion_t2", "desconexion_t3") %in% names(ancho))
  
  if (emociones_existentes && diccionarios_existentes) {
    cat("Calculando scores heurísticos (requieren emociones y diccionarios)...\n")
    w_T2 <- config_scores$influencia_T2
    w_T3 <- config_scores$influencia_T3
    w_comp <- config_scores$complejidad
    w_audio <- config_scores$audio_T3
    
    expr_T2 <- rlang::expr(
      w_T2["soledad"] * (soledad_t2 - soledad_t1) +
        w_T2["espera"] * (espera_t2 - espera_t1) +
        w_T2["incomunicacion"] * (incomunicacion_t2 - incomunicacion_t1) +
        w_T2["emociones_negativas"] * (emociones_negativas_t2 - emociones_negativas_t1) +
        w_T2["sadness"] * (sadness_t2 - sadness_t1) +
        w_T2["joy"] * (joy_t2 - joy_t1) +
        w_T2["trust"] * (trust_t2 - trust_t1)
    )
    mutate_exprs$score_influencia_T2 <- expr_T2
    
    expr_T3 <- rlang::expr(
      w_T3["objetos"] * (objetos_t3 - objetos_t2) +
        w_T3["duda"] * (duda_t3 - duda_t2) +
        w_T3["desconexion"] * (desconexion_t3 - desconexion_t2) +
        w_T3["sadness"] * (sadness_t3 - sadness_t2) +
        w_T3["fear"] * (fear_t3 - fear_t2)
    )
    mutate_exprs$score_influencia_T3 <- expr_T3
    
    expr_comp <- rlang::expr(
      w_comp["palabras_oracion"] * (palabras_oracion_t2 - palabras_oracion_t1) +
        w_comp["long_palabra"] * (long_palabra_t2 - long_palabra_t1)
    )
    mutate_exprs$score_complejidad <- expr_comp
    
    expr_audio <- rlang::expr(
      w_audio["sadness"] * (sadness_t3 - sadness_t2) +
        w_audio["fear"] * (fear_t3 - fear_t2)
    )
    mutate_exprs$score_audio_T3 <- expr_audio
  } else {
    cat("No se encontraron todas las columnas necesarias para scores heurísticos. Se omiten.\n")
  }
  
  resultado <- ancho %>%
    mutate(!!!mutate_exprs) %>%
    select(fuente, participante, id_participante, condicion, demora,
           starts_with("cambio_"), starts_with("pct_"), starts_with("score_"))
  return(resultado)
}

# ── PRUEBAS PAREADAS Y FRIEDMAN ──────────────────────────────────────────

realizar_pruebas_pareadas <- function(ancho, variables = NULL, metodo_ajuste = "holm") {
  if (is.null(variables)) {
    posibles <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                  "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
    variables <- c()
    for (v in posibles) {
      if (all(paste0(v, "_t", 1:3) %in% names(ancho))) {
        temp <- ancho[, paste0(v, "_t", 1:3)]
        if (sum(complete.cases(temp)) >= 3) {
          variables <- c(variables, v)
        }
      }
    }
  }
  
  if (length(variables) == 0) {
    warning("No hay variables disponibles para pruebas pareadas.")
    return(data.frame(
      variable = character(),
      comparacion = character(),
      n = integer(),
      estadistico = numeric(),
      p_raw = numeric(),
      p_adj = numeric(),
      tamano_efecto = numeric(),
      IC95_inf = numeric(),
      IC95_sup = numeric()
    ))
  }
  
  resultados <- list()
  for (var in variables) {
    col1 <- paste0(var, "_t1")
    col2 <- paste0(var, "_t2")
    col3 <- paste0(var, "_t3")
    x1 <- ancho[[col1]]
    x2 <- ancho[[col2]]
    x3 <- ancho[[col3]]
    comps <- list(T1_T2 = list(a = x1, b = x2),
                  T2_T3 = list(a = x2, b = x3),
                  T1_T3 = list(a = x1, b = x3))
    for (comp in names(comps)) {
      a <- comps[[comp]]$a
      b <- comps[[comp]]$b
      d <- b - a
      n_valid <- sum(!is.na(d))
      if (n_valid < 3) {
        resultados[[paste(var, comp, sep = "_")]] <- data.frame(
          variable = var, comparacion = comp, n = n_valid,
          estadistico = NA, p_raw = NA, p_adj = NA,
          tamano_efecto = NA, IC95_inf = NA, IC95_sup = NA
        )
        next
      }
      sw_p <- if (n_valid >= 3 && n_valid <= 5000) shapiro.test(d)$p.value else NA
      if (!is.na(sw_p) && sw_p > 0.05) {
        test <- t.test(b, a, paired = TRUE)
        stat <- test$statistic
        p_raw <- test$p.value
        d_eff <- effsize::cohen.d(b[!is.na(b)], a[!is.na(a)], paired = TRUE, na.rm = TRUE)
        efecto <- d_eff$estimate
      } else {
        test <- wilcox.test(b, a, paired = TRUE, exact = FALSE)
        stat <- test$statistic
        p_raw <- test$p.value
        Z <- qnorm(p_raw/2) * sign(stat - n_valid*(n_valid+1)/4)
        efecto <- abs(Z) / sqrt(n_valid)
      }
      resultados[[paste(var, comp, sep = "_")]] <- data.frame(
        variable = var,
        comparacion = comp,
        n = n_valid,
        estadistico = as.numeric(stat),
        p_raw = p_raw,
        p_adj = NA,
        tamano_efecto = efecto,
        IC95_inf = NA,
        IC95_sup = NA,
        stringsAsFactors = FALSE
      )
    }
  }
  
  if (length(resultados) == 0) {
    return(data.frame(
      variable = character(),
      comparacion = character(),
      n = integer(),
      estadistico = numeric(),
      p_raw = numeric(),
      p_adj = numeric(),
      tamano_efecto = numeric(),
      IC95_inf = numeric(),
      IC95_sup = numeric()
    ))
  }
  
  df_res <- do.call(rbind, resultados)
  rownames(df_res) <- NULL
  df_res$p_adj <- p.adjust(df_res$p_raw, method = metodo_ajuste)
  df_res <- df_res[order(df_res$variable, df_res$comparacion), ]
  return(df_res)
}

realizar_friedman <- function(ancho, variables = NULL, metodo_ajuste = "bonferroni") {
  if (is.null(variables)) {
    posibles <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                  "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
    variables <- c()
    for (v in posibles) {
      if (all(paste0(v, "_t", 1:3) %in% names(ancho))) {
        temp <- ancho[, paste0(v, "_t", 1:3)]
        if (sum(complete.cases(temp)) >= 3) {
          variables <- c(variables, v)
        }
      }
    }
  }
  
  if (length(variables) == 0) {
    warning("No hay variables disponibles para Friedman.")
    return(list())
  }
  
  resultados <- list()
  for (var in variables) {
    col1 <- paste0(var, "_t1")
    col2 <- paste0(var, "_t2")
    col3 <- paste0(var, "_t3")
    m <- cbind(ancho[[col1]], ancho[[col2]], ancho[[col3]])
    m <- m[complete.cases(m), ]
    if (nrow(m) < 3) {
      resultados[[var]] <- list(friedman = NULL, posthoc = NULL)
      next
    }
    ft <- friedman.test(m)
    p_friedman <- ft$p.value
    stat_friedman <- ft$statistic
    
    posthoc <- NULL
    if (p_friedman < 0.05) {
      dl <- data.frame(
        valor = c(m[,1], m[,2], m[,3]),
        tiempo = factor(rep(c("T1","T2","T3"), each = nrow(m)))
      )
      pw <- pairwise.wilcox.test(dl$valor, dl$tiempo, paired = TRUE, p.adjust.method = metodo_ajuste)
      posthoc <- as.data.frame(pw$p.value)
      posthoc$comparacion <- rownames(posthoc)
    }
    resultados[[var]] <- list(
      friedman = data.frame(variable = var, estadistico = stat_friedman, 
                            gl = 2, p_valor = p_friedman),
      posthoc = posthoc
    )
  }
  return(resultados)
}

realizar_pruebas_inferenciales <- function(ancho, config = NULL) {
  if (is.null(config)) {
    posibles <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                  "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
    vars_disp <- c()
    for (v in posibles) {
      if (all(paste0(v, "_t", 1:3) %in% names(ancho))) {
        temp <- ancho[, paste0(v, "_t", 1:3)]
        if (sum(complete.cases(temp)) >= 3) {
          vars_disp <- c(vars_disp, v)
        }
      }
    }
    config <- list(
      variables_pareadas = vars_disp,
      variables_friedman = vars_disp,
      metodo_ajuste = "holm"
    )
  }
  cat("\n\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║         PRUEBAS ESTADÍSTICAS — CAMBIOS ENTRE ITERACIONES      ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")
  cat("Variables a evaluar:", paste(config$variables_pareadas, collapse = ", "), "\n\n")
  cat("── Pruebas pareadas (T1 vs T2, T2 vs T3, T1 vs T3) ──────────────────────\n")
  res_pareadas <- realizar_pruebas_pareadas(ancho, 
                                            variables = config$variables_pareadas,
                                            metodo_ajuste = config$metodo_ajuste)
  if (!is.null(res_pareadas) && nrow(res_pareadas) > 0) {
    print(res_pareadas)
  } else {
    cat("   (No se generaron resultados para pruebas pareadas)\n")
  }
  cat("\n── Prueba de Friedman (T1, T2, T3 simultáneamente) ─────────────────────\n")
  res_friedman <- realizar_friedman(ancho,
                                    variables = config$variables_friedman,
                                    metodo_ajuste = "bonferroni")
  if (length(res_friedman) > 0) {
    for (var in names(res_friedman)) {
      if (!is.null(res_friedman[[var]]$friedman)) {
        print(res_friedman[[var]]$friedman)
        if (!is.null(res_friedman[[var]]$posthoc)) {
          cat("  Post-hoc (Wilcoxon con ajuste Bonferroni):\n")
          print(res_friedman[[var]]$posthoc)
        }
      }
    }
  } else {
    cat("   (No se generaron resultados para Friedman)\n")
  }
  return(list(pareadas = res_pareadas, friedman = res_friedman))
}

# ── FUNCIONES PARA MODELOS MIXTOS ─────────────────────────────────────────

#' Construir formato largo para una variable (sin fuente)
construir_largo <- function(ancho, variable_base, incluir_demora = TRUE) {
  cols <- grep(paste0("^", variable_base, "_t[123]$"), names(ancho), value = TRUE)
  if (length(cols) == 0) stop("No se encontraron columnas para ", variable_base)
  id_cols <- c("id_participante", "condicion")
  if (incluir_demora && "demora" %in% names(ancho)) id_cols <- c(id_cols, "demora")
  ancho %>%
    select(all_of(id_cols), all_of(cols)) %>%
    pivot_longer(cols = all_of(cols),
                 names_to = "tiempo_col",
                 values_to = "valor") %>%
    mutate(
      tiempo = factor(str_extract(tiempo_col, "\\d+$"),
                      levels = c("1","2","3"),
                      labels = c("T1","T2","T3")),
      condicion = factor(condicion, levels = c("Texto","Audio","Imagen"))
    ) %>%
    filter(!is.na(valor)) %>%
    select(-tiempo_col)
}

#' Ajustar modelo mixto con manejo de errores y convergencia
ajustar_modelo <- function(ancho, variable_base, incluir_demora = TRUE) {
  if (incluir_demora && length(unique(ancho$demora[!is.na(ancho$demora)])) < 2) {
    incluir_demora <- FALSE
    cat("  → Demora tiene un solo nivel o todos NA. Se omite.\n")
  }
  dl <- construir_largo(ancho, variable_base, incluir_demora = incluir_demora)
  if (n_distinct(dl$id_participante) < 3) {
    warning("Menos de 3 participantes. No se ajusta modelo.")
    return(NULL)
  }
  if (incluir_demora) {
    formula <- as.formula("valor ~ condicion * tiempo + demora + (1 | id_participante)")
  } else {
    formula <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
  }
  cat("  Fórmula:", deparse(formula), "\n")
  mod <- tryCatch(
    lmer(formula, data = dl, REML = FALSE,
         control = lmerControl(optimizer = "bobyqa",
                               optCtrl = list(maxfun = 2e5))),
    error = function(e) {
      warning("Error al ajustar: ", e$message)
      return(NULL)
    }
  )
  if (is.null(mod)) return(NULL)
  list(
    modelo = mod,
    datos = dl,
    convergencia = tryCatch(check_convergence(mod), error = function(e) NA),
    singular = tryCatch(isSingular(mod), error = function(e) NA),
    formula = formula,
    variable = variable_base
  )
}

#' Extraer resultados (ANOVA, R², post-hoc)
extraer_resultados <- function(modelo_obj) {
  if (is.null(modelo_obj$modelo)) return(NULL)
  mod <- modelo_obj$modelo
  anov <- tryCatch(anova(mod, ddf = "Satterthwaite"), error = function(e) NULL)
  if (is.null(anov)) anov <- tryCatch(anova(mod), error = function(e) NULL)
  r2 <- tryCatch(r2_nakagawa(mod), error = function(e) NULL)
  posthoc <- list()
  if (!is.null(anov) && nrow(anov) > 0) {
    p_terms <- anov[["Pr(>F)"]]
    names(p_terms) <- rownames(anov)
    if ("condicion:tiempo" %in% names(p_terms) && p_terms["condicion:tiempo"] < 0.05) {
      cat("  → Interacción significativa. Calculando post-hoc...\n")
      emm1 <- emmeans(mod, ~ condicion | tiempo)
      posthoc$cond_tiempo <- pairs(emm1, adjust = "tukey")
      emm2 <- emmeans(mod, ~ tiempo | condicion)
      posthoc$tiempo_cond <- pairs(emm2, adjust = "tukey")
    } else {
      if ("tiempo" %in% names(p_terms) && p_terms["tiempo"] < 0.05) {
        emm_t <- emmeans(mod, ~ tiempo)
        posthoc$tiempo <- pairs(emm_t, adjust = "tukey")
      }
      if ("condicion" %in% names(p_terms) && p_terms["condicion"] < 0.05) {
        emm_c <- emmeans(mod, ~ condicion)
        posthoc$condicion <- pairs(emm_c, adjust = "tukey")
      }
      if ("demora" %in% names(p_terms) && p_terms["demora"] < 0.05) {
        emm_d <- emmeans(mod, ~ demora)
        posthoc$demora <- pairs(emm_d, adjust = "none")
      }
    }
  }
  list(
    anova = anov,
    r2 = r2,
    posthoc = posthoc,
    p_terms = if (!is.null(anov)) p_terms else NULL
  )
}

calcular_correlaciones_cambios <- function(ancho) {
  vars_cambio <- names(ancho)[grepl("^cambio_.*_t1t2$|^cambio_.*_t2t3$", names(ancho))]
  if (length(vars_cambio) == 0) {
    warning("No se encontraron variables de cambio parcial.")
    return(NULL)
  }
  datos_cor <- ancho %>% select(all_of(vars_cambio)) %>% na.omit()
  if (nrow(datos_cor) < 5) return(NULL)
  mat_cor <- cor(datos_cor, method = "spearman", use = "pairwise.complete.obs")
  return(mat_cor)
}

diagnostico_outliers <- function(modelo_obj, umbral_resid = 2.5) {
  if (is.null(modelo_obj$modelo)) return(NULL)
  mod <- modelo_obj$modelo
  resid <- residuals(mod, type = "pearson")
  outliers <- which(abs(resid) > umbral_resid)
  if (length(outliers) == 0) {
    cat("No se detectaron observaciones influyentes (|resid| >", umbral_resid, ").\n")
    return(NULL)
  }
  cat("Observaciones potencialmente influyentes (|resid| >", umbral_resid, "):", paste(outliers, collapse = ", "), "\n")
  return(list(outliers = outliers))
}

bootstrappear <- function(modelo_obj, nsim = 500, seed = 123) {
  if (is.null(modelo_obj$modelo)) return(NULL)
  mod <- modelo_obj$modelo
  if (isSingular(mod)) {
    warning("Modelo singular. Bootstrap omitido.")
    return(NULL)
  }
  if (!is.null(modelo_obj$convergencia) && is.na(modelo_obj$convergencia)) {
    warning("Convergencia no confirmada. Bootstrap omitido.")
    return(NULL)
  }
  coef_names <- names(fixef(mod))
  extraer <- function(mod) fixef(mod)
  set.seed(seed)
  boot_par <- tryCatch(
    bootMer(mod, FUN = extraer, nsim = nsim,
            .progress = "txt", parallel = "no"),
    error = function(e) {
      warning("Bootstrapping falló: ", e$message)
      return(NULL)
    }
  )
  if (is.null(boot_par)) return(NULL)
  boot_ci <- apply(boot_par$t, 2, function(x) quantile(x, probs = c(0.025, 0.975), na.rm = TRUE))
  colnames(boot_ci) <- coef_names
  list(bootstrap = boot_par, IC_percentil = boot_ci, nsim = nsim, seed = seed)
}

diagnosticar <- function(modelo_obj, nombre = "") {
  if (is.null(modelo_obj$modelo)) return(NULL)
  mod <- modelo_obj$modelo
  cat("\n--- Diagnóstico para:", nombre, "---\n")
  tryCatch({
    print(check_model(mod))
  }, error = function(e) {
    cat("  check_model() no disponible. Usando diagnóstico básico.\n")
    resid <- residuals(mod, type = "pearson")
    sw <- shapiro.test(resid)
    cat("Shapiro-Wilk: W =", round(sw$statistic, 4), "p =", round(sw$p.value, 4), "\n")
    cat("N observaciones:", length(resid), "\n")
    cat("Singular:", isSingular(mod), "\n")
    conv <- tryCatch(check_convergence(mod), error = function(e) NA)
    cat("Convergencia:", conv, "\n")
  })
}

tabla_resumen <- function(resultados) {
  df <- data.frame()
  for (var in names(resultados)) {
    if (!is.null(resultados[[var]]$anova)) {
      anov <- resultados[[var]]$anova
      if ("Pr(>F)" %in% colnames(anov)) {
        ef <- rownames(anov)
        F_val <- anov[["F value"]]
        df1 <- anov[["NumDF"]]
        df2 <- anov[["DenDF"]]
        p <- anov[["Pr(>F)"]]
        p_FDR <- if ("p_FDR" %in% colnames(anov)) anov[["p_FDR"]] else NA
        r2_marg <- if (!is.null(resultados[[var]]$r2)) resultados[[var]]$r2$R2_marginal else NA
        r2_cond <- if (!is.null(resultados[[var]]$r2)) resultados[[var]]$r2$R2_conditional else NA
        temp <- data.frame(
          variable = var,
          efecto = ef,
          F = round(F_val, 3),
          df1 = df1,
          df2 = df2,
          p = round(p, 4),
          p_FDR = round(p_FDR, 4),
          R2_marginal = round(r2_marg, 3),
          R2_condicional = round(r2_cond, 3),
          significativo_p_crudo = ifelse(p < 0.05, "Sí", "No"),
          significativo_FDR = ifelse(p_FDR < 0.05, "Sí", "No")
        )
        df <- rbind(df, temp)
      }
    }
  }
  return(df)
}

tabla_contrastes <- function(resultados) {
  df <- data.frame()
  for (var in names(resultados)) {
    if (!is.null(resultados[[var]]$posthoc) && length(resultados[[var]]$posthoc) > 0) {
      for (ph in names(resultados[[var]]$posthoc)) {
        cont <- as.data.frame(resultados[[var]]$posthoc[[ph]])
        cont$variable <- var
        cont$contraste_tipo <- ph
        if ("contrast" %in% names(cont)) {
          cont$contraste <- cont$contrast
        } else {
          cont$contraste <- rownames(cont)
        }
        df <- rbind(df, cont[, c("variable", "contraste_tipo", "contraste", "estimate", "SE", "df", "t.ratio", "p.value")])
      }
    }
  }
  if (nrow(df) > 0) {
    names(df)[names(df) == "t.ratio"] <- "t"
    names(df)[names(df) == "p.value"] <- "p"
    df$p_ajustada <- p.adjust(df$p, method = "fdr")
    return(df)
  } else {
    return(data.frame())
  }
}

# ── FUNCIONES PARA ANÁLISIS DE SENSIBILIDAD (BLOQUE 14) ─────────────────

#' Construir formato largo para una variable (incluyendo fuente)
construir_largo_para_modelo <- function(ancho, variable) {
  cols <- paste0(variable, "_t", 1:3)
  if (!all(cols %in% names(ancho))) {
    warning("No se encontraron todas las columnas para ", variable)
    return(NULL)
  }
  id_cols <- c("id_participante", "condicion")
  if ("demora" %in% names(ancho)) id_cols <- c(id_cols, "demora")
  if ("fuente" %in% names(ancho)) id_cols <- c(id_cols, "fuente")
  dl <- ancho %>%
    select(all_of(id_cols), all_of(cols)) %>%
    pivot_longer(
      cols = all_of(cols),
      names_to = "tiempo_col",
      values_to = "valor"
    ) %>%
    mutate(
      tiempo = factor(str_extract(tiempo_col, "\\d+$"),
                      levels = c("1","2","3"),
                      labels = c("T1","T2","T3")),
      condicion = factor(condicion, levels = c("Texto","Audio","Imagen"))
    ) %>%
    filter(!is.na(valor)) %>%
    select(-tiempo_col)
  return(dl)
}

#' Ajustar modelo de sensibilidad con fórmula dada
ajustar_modelo_sensibilidad <- function(ancho, variable, formula, nombre_modelo) {
  dl <- construir_largo_para_modelo(ancho, variable)
  if (is.null(dl) || n_distinct(dl$id_participante) < 3) {
    return(list(estado = "FALLIDO", motivo = "Datos insuficientes"))
  }
  if (sd(dl$valor, na.rm = TRUE) == 0) {
    return(list(estado = "VARIANZA_CERO", motivo = "Varianza cero en los datos"))
  }
  if (!grepl("\\|", deparse(formula))) {
    formula <- update(formula, . ~ . + (1 | id_participante))
  }
  mod <- tryCatch(
    lmer(formula, data = dl, REML = TRUE,
         control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
    error = function(e) NULL
  )
  if (is.null(mod)) {
    return(list(estado = "FALLIDO", motivo = "Error en lmer"))
  }
  if (isSingular(mod)) {
    return(list(estado = "SINGULAR", motivo = "Modelo singular"))
  }
  anov <- tryCatch(anova(mod, ddf = "Satterthwaite"), error = function(e) NULL)
  r2 <- tryCatch(r2_nakagawa(mod), error = function(e) NULL)
  coefs <- as.data.frame(summary(mod)$coefficients)
  emm <- tryCatch(emmeans(mod, ~ condicion * tiempo), error = function(e) NULL)
  list(
    estado = "OK",
    modelo = mod,
    datos = dl,
    anova = anov,
    r2 = r2,
    coeficientes = coefs,
    emmeans = emm
  )
}

#' Extraer información para tabla maestra de robustez
extraer_info_modelo <- function(modelo_obj, nombre) {
  if (is.null(modelo_obj) || modelo_obj$estado != "OK") {
    return(data.frame(
      modelo = nombre,
      N = NA,
      participantes = NA,
      AIC = NA,
      BIC = NA,
      R2_marginal = NA,
      R2_condicional = NA,
      efecto_tiempo = NA,
      p_tiempo = NA,
      efecto_condicion = NA,
      p_condicion = NA,
      interaccion = NA,
      p_interaccion = NA,
      conclusion = NA
    ))
  }
  mod <- modelo_obj$modelo
  dl <- modelo_obj$datos
  anov <- modelo_obj$anova
  coef <- modelo_obj$coeficientes
  N <- nrow(dl)
  participantes <- n_distinct(dl$id_participante)
  aic <- AIC(mod)
  bic <- BIC(mod)
  r2m <- modelo_obj$r2$R2_marginal
  r2c <- modelo_obj$r2$R2_conditional
  
  tiempo_rows <- coef[grepl("^tiempo", rownames(coef)), ]
  if (nrow(tiempo_rows) > 0) {
    ef_tiempo <- tiempo_rows[1, "Estimate"]
    p_tiempo <- tiempo_rows[1, "Pr(>|t|)"]
  } else {
    ef_tiempo <- NA
    p_tiempo <- NA
  }
  
  cond_rows <- coef[grepl("^condicion", rownames(coef)) & !grepl(":", rownames(coef)), ]
  if (nrow(cond_rows) > 0) {
    ef_cond <- cond_rows[1, "Estimate"]
    p_cond <- cond_rows[1, "Pr(>|t|)"]
  } else {
    ef_cond <- NA
    p_cond <- NA
  }
  
  int_rows <- coef[grepl("condicion.*tiempo|tiempo.*condicion", rownames(coef)), ]
  if (nrow(int_rows) > 0) {
    ef_int <- int_rows[1, "Estimate"]
    p_int <- int_rows[1, "Pr(>|t|)"]
  } else {
    ef_int <- NA
    p_int <- NA
  }
  
  conclusion <- "sin efecto"
  if (!is.na(p_tiempo) && p_tiempo < 0.05) conclusion <- "efecto tiempo significativo"
  if (!is.na(p_int) && p_int < 0.05) conclusion <- "interacción significativa"
  if (!is.na(p_cond) && p_cond < 0.05 && !grepl("interacción", conclusion)) {
    conclusion <- paste(conclusion, "+ efecto condición")
  }
  
  data.frame(
    modelo = nombre,
    N = N,
    participantes = participantes,
    AIC = aic,
    BIC = bic,
    R2_marginal = r2m,
    R2_condicional = r2c,
    efecto_tiempo = ef_tiempo,
    p_tiempo = p_tiempo,
    efecto_condicion = ef_cond,
    p_condicion = p_cond,
    interaccion = ef_int,
    p_interaccion = p_int,
    conclusion = conclusion,
    stringsAsFactors = FALSE
  )
}