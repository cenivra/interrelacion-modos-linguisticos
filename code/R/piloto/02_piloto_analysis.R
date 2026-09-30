# ============================================================================
# 02_piloto_analysis.R — PROCESAMIENTO COMPLETO DEL PILOTO
# ============================================================================
# Este script aplica todas las etapas de análisis al dataset piloto:
#   - Procesamiento de texto (limpieza, tokenización, métricas lingüísticas)
#   - Análisis de sentimiento (NRC‑ES)
#   - Diccionarios temáticos de Hopper (con enriquecimiento opcional)
#   - Embeddings semánticos, prototipos y PCA
#   - Similitudes textuales (coseno y Jaccard)
#
# El resultado es un objeto `datos_piloto` enriquecido con todas las columnas
# generadas (lingüísticas, emociones, scores, prototipos, similitudes).
# ============================================================================

# ── Dependencias ─────────────────────────────────────────────────────────────
# Este script asume que los siguientes módulos ya han sido sourceados:
#   R/00_config.R
#   R/01_import_data.R        (para funciones de normalización, si se usan)
#   R/02_text_processing.R
#   R/03_sentiment.R
#   R/04_dictionaries.R
#   R/05_embeddings.R
#   R/06_similarity.R
# y que 00_piloto_config.R y 01_piloto_import.R ya se han ejecutado,
# por lo que el objeto `datos_piloto` existe (o puede ser cargado mediante
# la función `cargar_piloto()`).

# ── Función principal de procesamiento ──────────────────────────────────────

#' Procesar el dataset piloto a través de todo el pipeline analítico
#'
#' @param datos_piloto Lista con elementos `largo` y `ancho` (datos del piloto).
#' @param enriquecer_diccionarios Lógico, si se desea enriquecer los diccionarios
#'        Hopper con candidatos del piloto (requiere tiempo de cómputo).
#' @param calcular_embeddings Lógico, si se desea calcular embeddings (requiere Python).
#' @param calcular_pca Lógico, si se desea calcular PCA sobre embeddings.
#' @return Lista `datos_piloto` enriquecida.
procesar_piloto <- function(datos_piloto,
                            enriquecer_diccionarios = FALSE,
                            calcular_embeddings = TRUE,
                            calcular_pca = TRUE) {
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("   PROCESAMIENTO PILOTO — ANÁLISIS COMPLETO\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # ── 1. Procesamiento de texto y métricas lingüísticas ──────────────────
  cat("→ Aplicando procesamiento de texto...\n")
  datos_piloto <- preprocesar_textos(datos_piloto)
  datos_piloto <- agregar_metricas(datos_piloto)
  cat("✓ Métricas lingüísticas calculadas.\n")
  
  # ── 2. Análisis de sentimiento (NRC‑ES) ────────────────────────────────
  cat("→ Inicializando léxico NRC‑ES...\n")
  inicializar_lexico()
  cat("→ Calculando sentimientos...\n")
  datos_piloto <- calcular_sentimientos(datos_piloto)
  cat("✓ Sentimientos calculados.\n")
  
  # ── 3. Diccionarios temáticos de Hopper ────────────────────────────────
  cat("→ Preparando corpus para diccionarios...\n")
  corpus_piloto <- preparar_corpus(datos_piloto$largo)
  
  # 3.1. Enriquecimiento opcional de los diccionarios (basado solo en piloto)
  if (enriquecer_diccionarios) {
    cat("→ Extrayendo candidatos para enriquecer diccionarios (PMI)...\n")
    candidatos <- extraer_candidatos(corpus_piloto, diccionarios_hopper_base,
                                     min_freq = 3, min_doc = 2, min_part = 2)
    
    # En el análisis principal, los candidatos aceptados se definen manualmente.
    # Aquí se puede optar por no aceptar ninguno, o usar los mismos que en el
    # análisis principal, o elegir algunos basados en el piloto.
    # Por defecto, no enriquecemos para mantener la coherencia con el principal.
    cat("   (No se aplicará enriquecimiento a menos que se modifique el código)\n")
    # Si se desea enriquecer, se puede definir candidatos_aceptados y llamar a
    # enriquecer_diccionarios. Ejemplo (comentado):
    # candidatos_aceptados <- list(...)  # selección manual
    # diccionarios_hopper_piloto <- enriquecer_diccionarios(diccionarios_hopper_base, candidatos_aceptados)
    
    # En este script usamos los diccionarios base sin enriquecer.
    # Si se quiere enriquecer, se debe definir aquí.
    diccionarios_hopper_piloto <- diccionarios_hopper_base
  } else {
    diccionarios_hopper_piloto <- diccionarios_hopper_base
  }
  
  # 3.2. Aplicar diccionarios al dataset largo
  cat("→ Aplicando diccionarios al piloto...\n")
  scores_long_piloto <- aplicar_diccionarios_long(datos_piloto$largo,
                                                  diccionarios_hopper_piloto)
  
  # 3.3. Transformar scores a formato ancho e integrar en datos_piloto$ancho
  scores_wide_piloto <- scores_long_piloto %>%
    pivot_wider(
      id_cols = c(fuente, participante, id_participante, condicion, demora),
      names_from = iteracion,
      values_from = c(starts_with("score_"), starts_with("rate_")),
      names_glue = "{.value}_t{iteracion}"
    )
  
  # Unir con el ancho existente (solo las columnas de scores, sin duplicar id_participante)
  datos_piloto$ancho <- datos_piloto$ancho %>%
    left_join(
      scores_wide_piloto %>%
        select(-fuente, -participante, -condicion, -demora),
      by = "id_participante"
    )
  
  cat("✓ Diccionarios aplicados al piloto.\n")
  
  # ── 4. Embeddings y transformación semántica ────────────────────────────
  if (calcular_embeddings) {
    cat("→ Generando embeddings para el piloto...\n")
    
    ancho <- datos_piloto$ancho
    textos_t1 <- ancho$t1_limpio
    textos_t2 <- ancho$t2_limpio
    textos_t3 <- ancho$t3_limpio
    
    # Reemplazar textos vacíos
    textos_t1[is.na(textos_t1) | trimws(textos_t1) == ""] <- "[VACÍO]"
    textos_t2[is.na(textos_t2) | trimws(textos_t2) == ""] <- "[VACÍO]"
    textos_t3[is.na(textos_t3) | trimws(textos_t3) == ""] <- "[VACÍO]"
    
    # Obtener embeddings
    emb_piloto_t1 <- obtener_embeddings(textos_t1, normalize = TRUE, batch_size = 32L)
    emb_piloto_t2 <- obtener_embeddings(textos_t2, normalize = TRUE, batch_size = 32L)
    emb_piloto_t3 <- obtener_embeddings(textos_t3, normalize = TRUE, batch_size = 32L)
    
    # Construir prototipos semánticos (usando las listas globales definidas en 05_embeddings)
    cat("→ Construyendo prototipos semánticos...\n")
    prototipos_centroides_piloto <- list()
    for (nombre in names(prototipos)) {
      frases <- prototipos[[nombre]]
      centroide <- tryCatch({
        construir_centroide(frases)
      }, error = function(e) {
        warning("Error construyendo prototipo para ", nombre, ": ", e$message)
        rep(NA_real_, 384)
      })
      prototipos_centroides_piloto[[nombre]] <- centroide
    }
    
    # Calcular proximidad a prototipos
    cat("→ Calculando proximidad a prototipos...\n")
    emb_list <- list(t1 = emb_piloto_t1, t2 = emb_piloto_t2, t3 = emb_piloto_t3)
    nombres_proto <- names(prototipos_centroides_piloto)
    proto_cols <- list()
    
    for (tiempo in c("t1", "t2", "t3")) {
      emb_actual <- emb_list[[tiempo]]
      if (is.null(emb_actual) || any(is.na(emb_actual))) {
        for (proto in nombres_proto) {
          col_name <- paste0("proto_", proto, "_", tiempo)
          proto_cols[[col_name]] <- rep(NA_real_, nrow(ancho))
        }
        next
      }
      for (proto in nombres_proto) {
        centroide <- prototipos_centroides_piloto[[proto]]
        if (any(is.na(centroide))) {
          sim <- rep(NA_real_, nrow(emb_actual))
        } else {
          sim <- as.numeric(emb_actual %*% centroide)
          sim <- pmax(-1, pmin(1, sim))
        }
        col_name <- paste0("proto_", proto, "_", tiempo)
        proto_cols[[col_name]] <- sim
      }
    }
    proto_df <- as.data.frame(proto_cols)
    ancho <- cbind(ancho, proto_df)
    
    # Calcular deltas de prototipos
    cat("→ Calculando cambios de proximidad a prototipos...\n")
    for (proto in nombres_proto) {
      col_t1 <- paste0("proto_", proto, "_t1")
      col_t2 <- paste0("proto_", proto, "_t2")
      col_t3 <- paste0("proto_", proto, "_t3")
      if (all(c(col_t1, col_t2, col_t3) %in% names(ancho))) {
        ancho[[paste0("delta_proto_", proto, "_t1t2")]] <- ancho[[col_t2]] - ancho[[col_t1]]
        ancho[[paste0("delta_proto_", proto, "_t2t3")]] <- ancho[[col_t3]] - ancho[[col_t2]]
        ancho[[paste0("delta_proto_", proto, "_t1t3")]] <- ancho[[col_t3]] - ancho[[col_t1]]
      }
    }
    
    # PCA (opcional)
    if (calcular_pca) {
      cat("→ Calculando PCA sobre embeddings...\n")
      completos <- complete.cases(emb_piloto_t1, emb_piloto_t2, emb_piloto_t3)
      if (sum(completos) >= 3) {
        emb_all <- rbind(emb_piloto_t1[completos, ],
                         emb_piloto_t2[completos, ],
                         emb_piloto_t3[completos, ])
        pca_piloto <- prcomp(emb_all, center = TRUE, scale. = TRUE)
        var_exp <- round(100 * summary(pca_piloto)$importance[2, 1:2], 2)
        cat("   Varianza explicada PC1:", var_exp[1], "%, PC2:", var_exp[2], "%\n")
        
        pc_scores <- pca_piloto$x[, 1:2]
        idx_completos <- which(completos)
        for (k in 1:3) {
          idx_tiempo <- idx_completos + (k - 1) * sum(completos)
          ancho[[paste0("PC1_t", k)]][idx_completos] <- pc_scores[idx_tiempo, 1]
          ancho[[paste0("PC2_t", k)]][idx_completos] <- pc_scores[idx_tiempo, 2]
        }
        # Guardar objeto PCA
        pca_obj_piloto <- list(pca = pca_piloto, var_exp = var_exp,
                               casos_completos = sum(completos))
      } else {
        warning("No hay suficientes casos completos para PCA en el piloto.")
        ancho$PC1_t1 <- ancho$PC1_t2 <- ancho$PC1_t3 <- NA_real_
        ancho$PC2_t1 <- ancho$PC2_t2 <- ancho$PC2_t3 <- NA_real_
        pca_obj_piloto <- NULL
      }
    } else {
      ancho$PC1_t1 <- ancho$PC1_t2 <- ancho$PC1_t3 <- NA_real_
      ancho$PC2_t1 <- ancho$PC2_t2 <- ancho$PC2_t3 <- NA_real_
      pca_obj_piloto <- NULL
    }
    
    # Calcular similitudes semánticas
    sim_sem_t1_t2 <- calcular_similitud_coseno(emb_piloto_t1, emb_piloto_t2)
    sim_sem_t2_t3 <- calcular_similitud_coseno(emb_piloto_t2, emb_piloto_t3)
    sim_sem_t1_t3 <- calcular_similitud_coseno(emb_piloto_t1, emb_piloto_t3)
    
    div_sem_t1_t2 <- 1 - sim_sem_t1_t2
    div_sem_t2_t3 <- 1 - sim_sem_t2_t3
    div_sem_t1_t3 <- 1 - sim_sem_t1_t3
    
    cambio_semantico_t1t2 <- div_sem_t1_t2
    cambio_semantico_t2t3 <- div_sem_t2_t3
    cambio_semantico_total <- div_sem_t1_t3
    
    # Agregar métricas semánticas a ancho
    ancho$sim_sem_t1_t2 <- sim_sem_t1_t2
    ancho$sim_sem_t2_t3 <- sim_sem_t2_t3
    ancho$sim_sem_t1_t3 <- sim_sem_t1_t3
    ancho$div_sem_t1_t2 <- div_sem_t1_t2
    ancho$div_sem_t2_t3 <- div_sem_t2_t3
    ancho$div_sem_t1_t3 <- div_sem_t1_t3
    ancho$cambio_semantico_t1t2 <- cambio_semantico_t1t2
    ancho$cambio_semantico_t2t3 <- cambio_semantico_t2t3
    ancho$cambio_semantico_total <- cambio_semantico_total
    
    # Actualizar datos_piloto$ancho
    datos_piloto$ancho <- ancho
    
    # Guardar embeddings y prototipos del piloto (opcional)
    dir.create(file.path(OUTPUT_DIR_PILOTO, "datos"), recursive = TRUE, showWarnings = FALSE)
    saveRDS(emb_piloto_t1, file.path(OUTPUT_DIR_PILOTO, "datos", "embeddings_piloto_t1.rds"))
    saveRDS(emb_piloto_t2, file.path(OUTPUT_DIR_PILOTO, "datos", "embeddings_piloto_t2.rds"))
    saveRDS(emb_piloto_t3, file.path(OUTPUT_DIR_PILOTO, "datos", "embeddings_piloto_t3.rds"))
    saveRDS(prototipos_centroides_piloto, file.path(OUTPUT_DIR_PILOTO, "datos", "prototipos_piloto.rds"))
    if (exists("pca_obj_piloto")) {
      saveRDS(pca_obj_piloto, file.path(OUTPUT_DIR_PILOTO, "datos", "pca_piloto.rds"))
    }
    
    cat("✓ Embeddings, prototipos y PCA calculados.\n")
  } else {
    cat("⚠ Cálculo de embeddings omitido (calcular_embeddings = FALSE).\n")
  }
  
  # ── 5. Similitudes textuales (tokens) ────────────────────────────────────
  cat("→ Calculando similitudes textuales (coseno y Jaccard)...\n")
  datos_piloto <- calcular_similitudes(datos_piloto)
  cat("✓ Similitudes textuales calculadas.\n")
  
  # ── 6. Guardar el objeto datos_piloto procesado (opcional) ──────────────
  # Se puede guardar para reutilizar en análisis posteriores sin repetir el procesamiento.
  saveRDS(datos_piloto, file.path(OUTPUT_DIR_PILOTO, "datos", "datos_piloto_procesado.rds"))
  cat("✅ Objeto datos_piloto guardado en:", file.path(OUTPUT_DIR_PILOTO, "datos", "datos_piloto_procesado.rds"), "\n")
  
  cat("\n✅ Procesamiento del piloto completado.\n")
  cat("   Columnas en datos_piloto$ancho:", ncol(datos_piloto$ancho), "\n\n")
  
  return(datos_piloto)
}

# ── Ejecución directa (si se sourcea este script) ──────────────────────────
# Si este script se ejecuta directamente (no desde run_piloto.R), se cargará
# el piloto (si no existe) y se ejecutará el procesamiento completo.

if (interactive() || Sys.getenv("RUN_PILOTO") == "TRUE") {
  # Verificar si datos_piloto ya está cargado, si no, cargarlo
  if (!exists("datos_piloto") || is.null(datos_piloto)) {
    cat("ℹ️ Cargando datos del piloto...\n")
    source(here::here("code", "R", "piloto", "01_piloto_import.R"))
    datos_piloto <- cargar_piloto()
  }
  # Procesar
  datos_piloto <- procesar_piloto(datos_piloto,
                                  enriquecer_diccionarios = FALSE,
                                  calcular_embeddings = TRUE,
                                  calcular_pca = TRUE)
} else {
  cat("ℹ️ Función 'procesar_piloto()' definida. Ejecutar para procesar los datos.\n")
}