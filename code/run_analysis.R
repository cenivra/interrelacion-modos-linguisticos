# ============================================================================
# run_analysis.R — PIPELINE COMPLETO DE ANÁLISIS NLP (3 TIEMPOS)
# ============================================================================
# Este script orquesta todo el análisis del estudio:
#   - Configuración, librerías y entorno Python.
#   - Importación y normalización de datos (principal + piloto).
#   - Procesamiento de texto (limpieza, tokenización, métricas).
#   - Análisis de sentimiento (NRC-ES).
#   - Diccionarios temáticos de Hopper (enriquecimiento empírico).
#   - Embeddings, prototipos semánticos y PCA.
#   - Similitudes textuales (coseno y Jaccard).
#   - Modelos mixtos, pruebas inferenciales y bootstrap.
#   - Visualizaciones científicas (figuras en español/inglés).
#   - Análisis de sensibilidad y robustez.
# ============================================================================

# ── 0. CONFIGURACIÓN INICIAL ────────────────────────────────────────────────
# Asegurarse de que el directorio de trabajo sea la raíz del proyecto
# Si usas RStudio, esto se hace automáticamente al abrir el .Rproj.
# Si no, ejecuta: setwd("ruta/a/tu/proyecto")

# Cargar paquete 'here' para rutas relativas (se instala si no existe)
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   INICIANDO PIPELINE DE ANÁLISIS NLP (3 TIEMPOS)\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("Directorio raíz del proyecto:", here::here(), "\n\n")

# ── 1. CARGAR MÓDULOS ──────────────────────────────────────────────────────
cat("── Cargando módulos ────────────────────────────────────────────\n")

source(here("code", "R", "00_config.R"))               # Opciones, librerías, logging, Python
cat("✓ 00_config.R cargado\n")

source(here("code", "R", "01_import_data.R"))          # Importación y normalización
cat("✓ 01_import_data.R cargado\n")

source(here("code", "R", "02_text_processing.R"))      # Limpieza, tokenización, métricas
cat("✓ 02_text_processing.R cargado\n")

source(here("code", "R", "03_sentiment.R"))            # Léxico NRC-ES y sentimientos
cat("✓ 03_sentiment.R cargado\n")

source(here("code", "R", "04_dictionaries.R"))         # Diccionarios Hopper
cat("✓ 04_dictionaries.R cargado\n")

source(here("code", "R", "05_embeddings.R"))           # Embeddings, prototipos, PCA
cat("✓ 05_embeddings.R cargado\n")

source(here("code", "R", "06_similarity.R"))           # Similitudes textuales (tokens)
cat("✓ 06_similarity.R cargado\n")

source(here("code", "R", "07_models.R"))               # Modelos mixtos, pruebas, bootstrap
cat("✓ 07_models.R cargado\n")

source(here("code", "R", "08_visualization.R"))        # Figuras científicas
cat("✓ 08_visualization.R cargado\n")

source(here("code", "R", "09_sensitivity.R"))          # Análisis de sensibilidad
cat("✓ 09_sensitivity.R cargado\n\n")

# ── 2. IMPORTACIÓN Y NORMALIZACIÓN ────────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 1 — IMPORTACIÓN Y NORMALIZACIÓN DE DATOS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Rutas de los archivos (usar las definidas en 00_config.R)
# RUTA_DATOS_CRUDOS, RUTA_PRINCIPAL_EXCEL, RUTA_PILOTO_EXCEL ya están definidas en 00_config.R
# Si no existen (fallback), construirlas aquí
if (!exists("RUTA_PRINCIPAL_EXCEL")) {
  ruta_principal <- here("data", "raw", "Datos Exp Interrelacion.xlsx")
  ruta_piloto_largo <- here("data", "raw", "piloto_interrelacion_formato_largo.xlsx")
} else {
  ruta_principal <- RUTA_PRINCIPAL_EXCEL
  ruta_piloto_largo <- RUTA_PILOTO_EXCEL
}

# ── Pre-flight checks ────────────────────────────────────────────────────────
cat("── Comprobaciones previas ──────────────────────────────────────\n")

# 1. Archivos de datos
if (!file.exists(ruta_principal)) {
  stop("❌ Archivo principal no encontrado en: ", ruta_principal,
       "\n   Configure RUTA_DATOS_CRUDOS en R/00_config.R o coloque el archivo en data/raw/")
}
if (!file.exists(ruta_piloto_largo)) {
  stop("❌ Archivo piloto no encontrado en: ", ruta_piloto_largo,
       "\n   Configure RUTA_DATOS_CRUDOS en R/00_config.R o coloque el archivo en data/raw/")
}
cat("✓ Archivos de datos encontrados:\n")
cat("   Principal:", ruta_principal, "\n")
cat("   Piloto:   ", ruta_piloto_largo, "\n")

# 2. Intérprete Python (debe estar configurado desde 00_config.R)
if (!exists("python_exe") || !file.exists(python_exe)) {
  stop("❌ Intérprete Python no configurado. ",
       "Ejecute source('code/R/00_config.R') primero o defina NLP_PYTHON.")
}
# Verificar que sentence_transformers está disponible
test_py <- system(sprintf('"%s" -c "import sentence_transformers"', python_exe), ignore.stderr = TRUE)
if (test_py != 0) {
  stop("❌ Python en ", python_exe, " no puede importar sentence_transformers.")
}
cat("✓ Python verificado:", python_exe, "\n\n")

# Importar y normalizar principal
cat("→ Importando dataset principal...\n")
raw_principal <- importar_principal(ruta_principal, hoja = "Datos_Largo")
principal_norm <- normalizar_principal(raw_principal)

# Importar y normalizar piloto
cat("→ Importando dataset piloto...\n")
raw_piloto <- importar_piloto(ruta_piloto_largo, hoja = "Datos_Largo")
piloto_norm <- normalizar_piloto(raw_piloto)

# Integrar fuentes (maestro combinado)
cat("→ Integrando fuentes (maestro combinado)...\n")
datos_maestros_long <- integrar_fuentes(list(principal_norm, piloto_norm))

# Validar maestro
validar_dataset_maestro(datos_maestros_long)

# Generar formato ancho para cada cohorte por separado Y para el combinado
cat("→ Generando formato ancho por cohorte...\n")
ancho_principal <- generar_ancho(principal_norm)
ancho_piloto <- generar_ancho(piloto_norm)
ancho_combinado <- generar_ancho(datos_maestros_long)

# Guardar formatos ancho por cohorte
dir.create(here("data", "processed", "principal"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "processed", "piloto"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "processed", "combinado"), recursive = TRUE, showWarnings = FALSE)

saveRDS(ancho_principal, here("data", "processed", "principal", "ancho_principal_base.rds"))
saveRDS(ancho_piloto, here("data", "processed", "piloto", "ancho_piloto_base.rds"))
saveRDS(ancho_combinado, here("data", "processed", "combinado", "ancho_combinado_procesado.rds"))

# Crear objeto `datos` para compatibilidad (usa el combinado como maestro)
datos <- list(
  largo = datos_maestros_long,
  ancho = ancho_combinado
)

cat("✅ Datos importados y normalizados.\n")
cat("   Observaciones (largo):", nrow(datos$largo), "\n")
cat("   Principal - Participantes:", nrow(ancho_principal), "filas\n")
cat("   Piloto - Participantes:", nrow(ancho_piloto), "filas\n")
cat("   Combinado - Participantes:", nrow(ancho_combinado), "filas\n\n")

# ── 3. PROCESAMIENTO DE TEXTO ──────────────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 2 — PROCESAMIENTO DE TEXTO Y MÉTRICAS LINGÜÍSTICAS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

datos <- preprocesar_textos(datos)
datos <- agregar_metricas(datos)
validar_datos(datos)

cat("✅ Procesamiento de texto completado.\n")
cat("   Columnas en datos$ancho:", ncol(datos$ancho), "\n\n")

# ── 4. ANÁLISIS DE SENTIMIENTO ─────────────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 3 — ANÁLISIS DE SENTIMIENTO (NRC-ES)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Inicializar léxico (descarga si es necesario)
inicializar_lexico()
cat("✓ Léxico NRC-ES cargado.\n")

# Calcular sentimientos
datos <- calcular_sentimientos(datos)

cat("✅ Análisis de sentimiento completado.\n")
cat("   Emociones calculadas:", paste(EMOCIONES_NRC, collapse = ", "), "\n\n")

# ── 5. DICCIONARIOS TEMÁTICOS DE HOPPER ──────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 4 — DICCIONARIOS TEMÁTICOS DE HOPPER\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Preparar corpus para enriquecimiento
cat("→ Preparando corpus...\n")
corpus <- preparar_corpus(datos_maestros_long)

# Extraer candidatos (puede tomar tiempo)
cat("→ Extrayendo candidatos por PMI...\n")
candidatos <- extraer_candidatos(corpus, diccionarios_hopper_base, 
                                  min_freq = 5, min_doc = 3, min_part = 2)

# NOTA: En el script original, los candidatos_aceptados se definen MANUALMENTE.
# Aquí los mantenemos como en el original (basado en inspección previa).
# En un proyecto real, podrías leerlos desde un archivo de configuración.
candidatos_aceptados <- list(
  soledad = c("acompañado", "vacío", "aislado", "desamparo"),
  espera = c("esperanza", "detenerse", "pausa"),
  incomunicacion = c("callado", "mudez"),
  objetos = c("maleta", "sombrero", "cartera", "pertenencias"),
  emociones_negativas = c("angustia", "desolación", "tormento", "desesperación"),
  luz_sombra = c("claro-oscuro"),
  pasividad = c("recostado", "yacer"),
  desconexion = c("distante", "separado"),
  duda = c("indecisión", "interrogante", "vacilación"),
  espacio = c("rincón", "ámbito", "entorno")
)

# Crear diccionario enriquecido
cat("→ Creando diccionario enriquecido...\n")
diccionarios_hopper_enriquecido <- enriquecer_diccionarios(
  diccionarios_hopper_base, 
  candidatos_aceptados
)

# Auditoría de diccionarios
auditoria_diccionarios <- bind_rows(lapply(names(candidatos_aceptados), function(tema) {
  tibble(
    tema = tema,
    termino = candidatos_aceptados[[tema]],
    tipo = "empírico",
    justificacion = "Extraído por PMI y frecuencia en el corpus"
  )
}))
cat("✓ Auditoría de diccionarios generada.\n")

# Solapamientos
solapamientos <- detectar_solapamientos(diccionarios_hopper_enriquecido)
cat("✓ Solapamientos detectados.\n")

# Cobertura
cobertura_base <- bind_rows(lapply(names(diccionarios_hopper_base), function(tema) {
  calcular_cobertura(corpus, diccionarios_hopper_base[[tema]], paste0(tema, "_base"))
}))
cobertura_enriquecida <- bind_rows(lapply(names(diccionarios_hopper_enriquecido), function(tema) {
  calcular_cobertura(corpus, diccionarios_hopper_enriquecido[[tema]], paste0(tema, "_enriquecido"))
}))
cobertura_total <- bind_rows(cobertura_base, cobertura_enriquecida)

# Mostrar resultados
cat("\n--- Cobertura comparada ---\n")
print(cobertura_total)

# Guardar diccionarios
save(diccionarios_hopper_base, diccionarios_hopper_enriquecido,
     auditoria_diccionarios, solapamientos, cobertura_total,
     file = here("data", "processed", "diccionarios_enriquecidos.RData"))

# Aplicar diccionarios enriquecidos
cat("\n→ Aplicando diccionarios al dataset...\n")
scores_long <- aplicar_diccionarios_long(datos_maestros_long, diccionarios_hopper_enriquecido)

# Transformar a formato ancho
scores_wide <- scores_long %>%
  pivot_wider(
    id_cols = c(fuente, participante, id_participante, condicion, demora),
    names_from = iteracion,
    values_from = c(starts_with("score_"), starts_with("rate_")),
    names_glue = "{.value}_t{iteracion}"
  )

# Guardar scores
save(scores_long, scores_wide, file = here("data", "processed", "scores_diccionarios.RData"))
write_csv(scores_long, here("data", "processed", "scores_diccionarios_long.csv"))
write_csv(scores_wide, here("data", "processed", "scores_diccionarios_wide.csv"))

# Integrar scores al objeto `datos` (añadir al ancho)
datos$ancho <- datos$ancho %>%
  left_join(
    scores_wide %>% 
      select(-fuente, -participante, -condicion, -demora),
    by = "id_participante"
  )

cat("✅ Diccionarios aplicados y guardados.\n")
cat("   Scores añadidos a datos$ancho.\n\n")

# ── 6. EMBEDDINGS Y TRANSFORMACIÓN SEMÁNTICA ─────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 5 — EMBEDDINGS, PROTOTIPOS Y PCA\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Verificar que ancho_principal y ancho_piloto tienen columnas de texto limpio
if (!all(c("t1_limpio", "t2_limpio", "t3_limpio") %in% names(ancho_principal))) {
  stop("Faltan columnas t1_limpio, t2_limpio, t3_limpio en ancho_principal.")
}
if (!all(c("t1_limpio", "t2_limpio", "t3_limpio") %in% names(ancho_piloto))) {
  stop("Faltan columnas t1_limpio, t2_limpio, t3_limpio en ancho_piloto.")
}

# Calcular embeddings para todas las cohortes (principal, piloto, combinado)
cat("→ Calculando embeddings para principal, piloto y combinado (T1, T2, T3)...\n")
embeddings_todas <- calcular_embeddings_todas_cohortes(
  datos_principal = ancho_principal,
  datos_piloto = ancho_piloto,
  output_base = here("data", "processed", "embeddings"),
  normalize = TRUE,
  batch_size = 32L
)

# Para compatibilidad con el resto del pipeline, usar embeddings del combinado
emb_t1 <- embeddings_todas[["combinado_t1"]]
emb_t2 <- embeddings_todas[["combinado_t2"]]
emb_t3 <- embeddings_todas[["combinado_t3"]]

# Construir prototipos semánticos (Hopper + Clínicos)
cat("→ Construyendo prototipos semánticos...\n")
prototipos_centroides <- list()
for (nombre in names(prototipos)) {
  frases <- prototipos[[nombre]]
  centroide <- tryCatch({
    construir_centroide(frases)
  }, error = function(e) {
    warning("Error construyendo prototipo para ", nombre, ": ", e$message)
    rep(NA_real_, 384)
  })
  prototipos_centroides[[nombre]] <- centroide
}
cat("✓ Prototipos construidos.\n")

# Guardar prototipos
dir.create(here("data", "processed", "prototypes"), showWarnings = FALSE, recursive = TRUE)
saveRDS(prototipos_centroides, here("data", "processed", "prototypes", "prototipos_semanticos.rds"))
cambio_semantico_total <- div_sem_t1_t3

# Calcular proximidad a prototipos
cat("→ Calculando proximidad a prototipos...\n")
emb_list <- list(t1 = emb_t1, t2 = emb_t2, t3 = emb_t3)
nombres_proto <- names(prototipos_centroides)
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
    centroide <- prototipos_centroides[[proto]]
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

# PCA
cat("→ Calculando PCA para visualización...\n")
completos <- complete.cases(emb_t1, emb_t2, emb_t3)
if (sum(completos) >= 3) {
  emb_all <- rbind(emb_t1[completos, ], emb_t2[completos, ], emb_t3[completos, ])
  pca <- prcomp(emb_all, center = TRUE, scale. = TRUE)
  var_exp <- round(100 * summary(pca)$importance[2, 1:2], 2)
  cat("   Varianza explicada PC1:", var_exp[1], "%, PC2:", var_exp[2], "%\n")
  
  pc_scores <- pca$x[, 1:2]
  idx_completos <- which(completos)
  for (k in 1:3) {
    idx_tiempo <- idx_completos + (k-1) * sum(completos)
    ancho[[paste0("PC1_t", k)]][idx_completos] <- pc_scores[idx_tiempo, 1]
    ancho[[paste0("PC2_t", k)]][idx_completos] <- pc_scores[idx_tiempo, 2]
  }
  pca_obj <- list(pca = pca, var_exp = var_exp, casos_completos = sum(completos))
  saveRDS(pca_obj, here("results", "pca_embeddings.rds"))
} else {
  warning("No hay suficientes casos completos para PCA.")
  ancho$PC1_t1 <- ancho$PC1_t2 <- ancho$PC1_t3 <- NA_real_
  ancho$PC2_t1 <- ancho$PC2_t2 <- ancho$PC2_t3 <- NA_real_
}

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

# Actualizar datos$ancho
datos$ancho <- ancho

cat("✅ Embeddings, prototipos y PCA completados.\n")
cat("   Nuevas columnas añadidas a datos$ancho.\n\n")

# ── 7. SIMILITUDES TEXTUALES (tokens) ─────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 6 — SIMILITUDES TEXTUALES (COSENO Y JACCARD)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

datos <- calcular_similitudes(datos)

cat("✅ Similitudes textuales calculadas.\n")
cat("   Columnas añadidas: cos_*, jac_*, div_*\n\n")

# ── 8. MODELOS MIXTOS Y PRUEBAS INFERENCIALES ────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 7 — MODELOS MIXTOS Y PRUEBAS INFERENCIALES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# 8.1. Calcular cambios y scores heurísticos
cat("→ Calculando cambios y scores...\n")
cambios_scores <- calcular_cambios_y_scores(datos$ancho)
cat("✓ Cambios y scores calculados.\n")

# 8.2. Pruebas inferenciales (pareadas y Friedman)
cat("→ Realizando pruebas inferenciales...\n")
resultados_inferenciales <- realizar_pruebas_inferenciales(datos$ancho)
cat("✓ Pruebas inferenciales completadas.\n")

# 8.3. Ajustar modelos mixtos para variables disponibles
cat("→ Ajustando modelos mixtos...\n")
vars_candidatas <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                     "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
vars_presentes <- c()
for (v in vars_candidatas) {
  if (all(paste0(v, "_t", 1:3) %in% names(datos$ancho))) {
    vars_presentes <- c(vars_presentes, v)
  }
}
cat("   Variables a modelar:", paste(vars_presentes, collapse = ", "), "\n")

# Eliminar redundancia (n_palabras vs n_palabras_calculado)
if ("n_palabras" %in% vars_presentes && "n_palabras_calculado" %in% vars_presentes) {
  cor_np <- cor(datos$ancho$n_palabras_t1, datos$ancho$n_palabras_calculado_t1, use = "pairwise.complete.obs")
  if (is.finite(cor_np) && abs(cor_np) >= 0.999) {
    vars_presentes <- setdiff(vars_presentes, "n_palabras_calculado")
    cat("   → n_palabras_calculado excluido (redundante).\n")
  }
}

# Ajustar modelos
tiene_demora <- length(unique(na.omit(datos$ancho$demora))) >= 2
resultados_modelos <- list()
todos_p_vals <- c()
nombres_p_vals <- c()

for (var in vars_presentes) {
  cat("\n   → Modelo para:", var, "\n")
  mod_obj <- ajustar_modelo(datos$ancho, var, incluir_demora = tiene_demora)
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
    if (!is.null(res$p_terms)) {
      todos_p_vals <- c(todos_p_vals, res$p_terms)
      nombres_p_vals <- c(nombres_p_vals, paste(var, names(res$p_terms), sep = "_"))
    }
    # Mostrar resumen
    if (!is.null(res$anova)) {
      print(res$anova)
      cat("      R² marginal:", round(res$r2$R2_marginal, 3), 
          " | condicional:", round(res$r2$R2_conditional, 3), "\n")
    }
  }
}

# Corrección FDR global
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
  cat("\n✓ FDR global aplicado.\n")
}

# Tabla resumen de efectos
tabla_efectos <- tabla_resumen(resultados_modelos)
cat("\n--- Tabla de efectos (modelos mixtos) ---\n")
print(tabla_efectos)

# Tabla de contrastes post-hoc
tabla_contrastes <- tabla_contrastes(resultados_modelos)
if (nrow(tabla_contrastes) > 0) {
  cat("\n--- Contrastes post-hoc (Tukey) ---\n")
  print(head(tabla_contrastes, 10))
}

# Correlaciones de cambios
cat("\n→ Calculando correlaciones de cambios...\n")
mat_cor <- calcular_correlaciones_cambios(datos$ancho)
if (!is.null(mat_cor)) {
  cat("   Matriz de correlaciones (Spearman) calculada.\n")
}

# Bootstrap para el modelo de palabras (si existe)
if ("n_palabras" %in% names(resultados_modelos)) {
  cat("\n→ Realizando bootstrap para n_palabras...\n")
  boot_res <- bootstrappear(resultados_modelos$n_palabras, nsim = 500, seed = 123)
  if (!is.null(boot_res)) {
    cat("   IC bootstrap (95% percentil):\n")
    print(round(boot_res$IC_percentil, 4))
  }
}

# Guardar modelos y resultados
saveRDS(resultados_modelos, here("results", "modelos_mixtos.rds"))
write.csv(tabla_efectos, here("results", "tablas", "efectos_modelos_mixtos.csv"), row.names = FALSE)
if (nrow(tabla_contrastes) > 0) {
  write.csv(tabla_contrastes, here("results", "tablas", "contrastes_posthoc.csv"), row.names = FALSE)
}
if (!is.null(mat_cor)) {
  write.csv(as.data.frame(mat_cor), here("results", "tablas", "correlaciones_cambios.csv"), row.names = TRUE)
}

cat("✅ Modelos mixtos y pruebas inferenciales completados.\n\n")

# ── 9. VISUALIZACIONES CIENTÍFICAS ────────────────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 8 — VISUALIZACIONES CIENTÍFICAS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Usamos la función generadora del módulo 08
figuras <- generar_todas_figuras(
  datos = datos,
  modelos = resultados_modelos,
  cor_mat = mat_cor,
  diccionarios_hopper = diccionarios_hopper_enriquecido
)

cat("✅ Visualizaciones generadas.\n")
cat("   Figuras guardadas en 'resultados/figuras/'\n")
cat("   Figuras bilingües en 'resultados/graficos español/' y 'resultados/graficos ingles/'\n\n")

# ── 10. ANÁLISIS DE SENSIBILIDAD Y ROBUSTEZ ──────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 9 — ANÁLISIS DE SENSIBILIDAD Y ROBUSTEZ\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

resultados_sensibilidad <- ejecutar_analisis_sensibilidad(
  ancho = datos$ancho,
  VD = "n_palabras",
  output_dir = "results"
)

cat("✅ Análisis de sensibilidad completado.\n")
cat("   Resultados en carpeta 'results/'\n\n")

# ── 11. EXPORTACIÓN DE RESULTADOS ADICIONALES ─────────────────────────────
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   BLOQUE 10 — EXPORTACIÓN DE RESULTADOS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

dir.create(here("results", "tablas"), recursive = TRUE, showWarnings = FALSE)

# Datos completos ancho (sin columnas de tokens/listas)
datos_export <- datos$ancho %>%
  select(-ends_with("_tokens"), -ends_with("_limpio"), -matches("_t[123]_tokens"))
write.csv(datos_export, here("results", "tablas", "datos_completos_ancho.csv"),
          fileEncoding = "UTF-8", row.names = FALSE)
cat("✓ datos_completos_ancho.csv\n")

# Datos formato largo
write.csv(datos$largo, here("results", "tablas", "datos_formato_largo.csv"),
          fileEncoding = "UTF-8", row.names = FALSE)
cat("✓ datos_formato_largo.csv\n")

# Sentimientos
sent_export <- datos$ancho %>%
  select(id_participante, fuente, condicion, demora,
         matches("^(bing|joy|sadness|fear|anger|anticipation|trust|surprise|disgust)_t"))
write.csv(sent_export, here("results", "tablas", "sentimientos.csv"),
          fileEncoding = "UTF-8", row.names = FALSE)
cat("✓ sentimientos.csv\n")

# Temas Hopper (scores)
temas <- names(diccionarios_hopper_enriquecido)
cols_temas <- paste0(rep(temas, each = 3), "_t", 1:3)
cols_temas <- cols_temas[cols_temas %in% names(datos$ancho)]
temas_export <- datos$ancho %>%
  select(id_participante, fuente, condicion, demora, all_of(cols_temas))
write.csv(temas_export, here("results", "tablas", "temas_hopper.csv"),
          fileEncoding = "UTF-8", row.names = FALSE)
cat("✓ temas_hopper.csv\n")

# Cambios y scores
cambios_export <- datos$ancho %>%
  select(id_participante, fuente, condicion, demora,
         starts_with("cambio_"), starts_with("pct_"), starts_with("score_"))
write.csv(cambios_export, here("results", "tablas", "cambios_y_scores.csv"),
          fileEncoding = "UTF-8", row.names = FALSE)
cat("✓ cambios_y_scores.csv\n")

# Metadatos de figuras (si existe el objeto)
if (exists("figuras") && !is.null(figuras)) {
  metadatos_figuras <- data.frame(
    figura = names(figuras),
    generada = sapply(figuras, function(x) !is.null(x))
  )
  write.csv(metadatos_figuras, here("results", "tablas", "metadatos_figuras.csv"),
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ metadatos_figuras.csv\n")
}

cat("\n✅ Exportación de resultados completada.\n")

# ── 12. RESUMEN FINAL ──────────────────────────────────────────────────────
cat("\n\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                 PIPELINE COMPLETADO EXITOSAMENTE              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
cat("Resumen de resultados:\n")
cat("  - Participantes totales:", n_distinct(datos$ancho$id_participante), "\n")
cat("  - Observaciones (largo):", nrow(datos$largo), "\n")
cat("  - Variables en ancho:", ncol(datos$ancho), "\n")
cat("  - Modelos mixtos ajustados:", length(resultados_modelos), "\n")
cat("  - Figuras generadas:", length(figuras), "\n")
cat("\n📁 Archivos de salida en:\n")
cat("   - 'resultados/' (figuras, tablas, modelos)\n")
cat("   - 'results/' (análisis de sensibilidad)\n")
cat("   - 'data/processed/' (scores, diccionarios)\n")
# Guardar el objeto `datos` completo (opcional)
saveRDS(datos, here("data", "processed", "datos_completos.rds"))
cat("\n✅ Objeto 'datos' guardado en 'data/processed/datos_completos.rds'\n")

# Guardar también anchos por cohorte ya procesados
saveRDS(ancho_principal, here("data", "processed", "principal", "ancho_principal_procesado.rds"))
saveRDS(ancho_piloto, here("data", "processed", "piloto", "ancho_piloto_procesado.rds"))
cat("✅ Anchos por cohorte guardados en data/processed/principal/ y data/processed/piloto/\n")

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   RESUMEN FINAL DE SALIDAS\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat(sprintf("  Principal:  %d participantes, embeddings en data/processed/embeddings/principal/\n", nrow(ancho_principal)))
cat(sprintf("  Piloto:     %d participantes, embeddings en data/processed/embeddings/piloto/\n", nrow(ancho_piloto)))
cat(sprintf("  Combinado:  %d participantes, embeddings en data/processed/embeddings/combinado/\n", nrow(ancho_combinado)))
cat("\n  Formato ancho base:\n")
cat("    data/processed/principal/ancho_principal_base.rds\n")
cat("    data/processed/piloto/ancho_piloto_base.rds\n")
cat("    data/processed/combinado/ancho_combinado_procesado.rds\n")
cat("  Formato ancho procesado:\n")
cat("    data/processed/principal/ancho_principal_procesado.rds\n")
cat("    data/processed/piloto/ancho_piloto_procesado.rds\n")
cat("  Embeddings + metadatos: data/processed/embeddings/{principal,piloto,combinado}/\n")
cat("  Prototipos: data/processed/embeddings/rds/semantic_prototypes/prototipos_semanticos.rds\n")
cat("  Resultados principales: resultados/\n")
cat("  Sensibilidad: outputs/\n\n")
