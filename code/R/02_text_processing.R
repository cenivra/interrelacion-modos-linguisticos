# ============================================================================
# 02_text_processing.R — LIMPIEZA, TOKENIZACIÓN Y MÉTRICAS LINGÜÍSTICAS
# ============================================================================
# Este módulo contiene funciones para:
#   - Limpiar textos (minusculas, transliteración, eliminar ruido).
#   - Tokenizar eliminando stopwords y palabras cortas.
#   - Preprocesar el dataset ancho (generar columnas * _limpio y * _tokens).
#   - Calcular métricas lingüísticas (n_tokens, TTR, oraciones, etc.).
# ============================================================================

# ── Limpieza de texto ──────────────────────────────────────────────────────
limpiar_texto <- function(texto) {
  if (is.na(texto) || nchar(trimws(texto)) == 0) return("")
  texto <- tolower(texto)
  texto <- iconv(texto, from = "UTF-8", to = "ASCII//TRANSLIT")
  texto <- str_replace_all(texto, "\\d+", "")
  texto <- str_replace_all(texto, "[^a-z\\s\\-]", " ")
  str_squish(texto)
}

# ── Tokenización (elimina stopwords y palabras cortas) ────────────────────
tokenizar <- function(texto, min_chars = 3) {
  if (nchar(texto) == 0) return(character(0))
  sw     <- stopwords::stopwords("es")
  tokens <- str_split(texto, "\\s+")[[1]]
  tokens <- tokens[nchar(tokens) >= min_chars]
  tokens[!tokens %in% sw]
}

# ── Preprocesar textos (aplica limpieza y tokenización a T1, T2, T3) ──────
preprocesar_textos <- function(datos) {
  registrar_log("Preprocesando textos...")
  datos$ancho <- datos$ancho %>%
    mutate(
      t1_limpio = map_chr(texto_t1, limpiar_texto),
      t2_limpio = map_chr(texto_t2, limpiar_texto),
      t3_limpio = map_chr(texto_t3, limpiar_texto),
      t1_tokens = map(t1_limpio, tokenizar),
      t2_tokens = map(t2_limpio, tokenizar),
      t3_tokens = map(t3_limpio, tokenizar)
    )
  registrar_log("Preprocesamiento completado")
  datos
}

# ── Calcular métricas lingüísticas para un texto y sus tokens ──────────────
calcular_metricas_linguisticas <- function(texto_orig, tokens) {
  vacío <- list(
    n_tokens = 0L, n_oraciones = 0L,
    diversidad_ttr = NA_real_,
    long_media_palabra = NA_real_,
    palabras_por_oracion = NA_real_
  )
  if (is.na(texto_orig) || nchar(trimws(texto_orig)) == 0 ||
      length(tokens) == 0) return(vacío)
  
  n_tok  <- length(tokens)
  n_char <- nchar(tokens)
  n_or <- max(1L, stri_count_boundaries(texto_orig, type = "sentence"))
  
  list(
    n_tokens             = n_tok,
    n_oraciones          = n_or,
    diversidad_ttr       = round(length(unique(tokens)) / n_tok, 4),
    long_media_palabra   = round(mean(n_char), 2),
    palabras_por_oracion = round(n_tok / n_or, 2)
  )
}

# ── Agregar métricas lingüísticas al dataset ancho (T1, T2, T3) ────────────
agregar_metricas <- function(datos) {
  registrar_log("Calculando métricas lingüísticas...")
  
  datos$ancho <- datos$ancho %>%
    rowwise() %>%
    mutate(
      met1 = list(calcular_metricas_linguisticas(texto_t1, t1_tokens)),
      met2 = list(calcular_metricas_linguisticas(texto_t2, t2_tokens)),
      met3 = list(calcular_metricas_linguisticas(texto_t3, t3_tokens)),
      
      n_tokens_t1             = met1$n_tokens,
      n_oraciones_t1          = met1$n_oraciones,
      ttr_t1                  = met1$diversidad_ttr,
      long_palabra_t1         = met1$long_media_palabra,
      palabras_oracion_t1     = met1$palabras_por_oracion,
      
      n_tokens_t2             = met2$n_tokens,
      n_oraciones_t2          = met2$n_oraciones,
      ttr_t2                  = met2$diversidad_ttr,
      long_palabra_t2         = met2$long_media_palabra,
      palabras_oracion_t2     = met2$palabras_por_oracion,
      
      n_tokens_t3             = met3$n_tokens,
      n_oraciones_t3          = met3$n_oraciones,
      ttr_t3                  = met3$diversidad_ttr,
      long_palabra_t3         = met3$long_media_palabra,
      palabras_oracion_t3     = met3$palabras_por_oracion
    ) %>%
    select(-met1, -met2, -met3) %>%
    ungroup()
  
  registrar_log("Métricas calculadas")
  datos
}