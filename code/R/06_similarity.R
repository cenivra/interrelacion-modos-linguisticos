# ============================================================================
# 06_similarity.R — SIMILITUDES TEXTUALES (COSENO Y JACCARD)
# ============================================================================
# Este módulo contiene funciones para calcular similitudes entre textos
# basadas en la frecuencia de tokens (bolsa de palabras):
#   - Similitud coseno (basada en frecuencias)
#   - Similitud Jaccard (intersección / unión)
#   - Distancia coseno (1 - similitud)
# La función principal aplica estas medidas a las columnas de tokens
# del dataset ancho (t1_tokens, t2_tokens, t3_tokens).
# ============================================================================

# ── Similitud coseno (basada en frecuencias de tokens) ──────────────────────
similitud_coseno <- function(t1, t2) {
  if (length(t1) == 0 || length(t2) == 0) return(NA_real_)
  # Usar bolsa de palabras con frecuencias
  vocab <- unique(c(t1, t2))
  v1 <- as.numeric(table(factor(t1, levels = vocab)))
  v2 <- as.numeric(table(factor(t2, levels = vocab)))
  den <- sqrt(sum(v1^2)) * sqrt(sum(v2^2))
  if (den == 0) return(NA_real_)
  round(sum(v1 * v2) / den, 4)
}

# ── Similitud Jaccard (intersección / unión) ────────────────────────────────
similitud_jaccard <- function(t1, t2) {
  if (length(t1) == 0 || length(t2) == 0) return(NA_real_)
  conj_union <- length(union(t1, t2))
  if (conj_union == 0) return(NA_real_)
  round(length(intersect(t1, t2)) / conj_union, 4)
}

# ── Calcular similitudes sobre el dataset ancho ─────────────────────────────
calcular_similitudes <- function(datos) {
  # datos debe tener las columnas t1_tokens, t2_tokens, t3_tokens
  # (generadas por preprocesar_textos en 02_text_processing.R)
  registrar_log("Calculando similitudes textuales...")
  datos$ancho <- datos$ancho %>%
    rowwise() %>%
    mutate(
      # Similitudes coseno
      cos_t1_t2 = similitud_coseno(t1_tokens, t2_tokens),
      cos_t2_t3 = similitud_coseno(t2_tokens, t3_tokens),
      cos_t1_t3 = similitud_coseno(t1_tokens, t3_tokens),
      # Jaccard
      jac_t1_t2 = similitud_jaccard(t1_tokens, t2_tokens),
      jac_t2_t3 = similitud_jaccard(t2_tokens, t3_tokens),
      jac_t1_t3 = similitud_jaccard(t1_tokens, t3_tokens),
      # Distancia coseno (1 - similitud)
      div_t1_t2 = 1 - cos_t1_t2,
      div_t2_t3 = 1 - cos_t2_t3,
      div_t1_t3 = 1 - cos_t1_t3
    ) %>%
    ungroup()
  registrar_log("Similitudes calculadas")
  datos
}