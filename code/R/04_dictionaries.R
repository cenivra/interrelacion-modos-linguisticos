# ============================================================================
# 04_dictionaries.R — DICCIONARIOS TEMÁTICOS DE HOPPER Y ENRIQUECIMIENTO
# ============================================================================
# Este módulo contiene:
#   - Los 10 diccionarios temáticos base (estética de Hopper).
#   - Funciones para enriquecerlos empíricamente (PMI, frecuencia).
#   - Funciones para auditar cobertura y solapamientos.
#   - Función para aplicar los diccionarios a un dataset en formato largo.
# ============================================================================

# ── Diccionarios base (10 temas de Hopper) ────────────────────────────────
diccionarios_hopper_base <- list(
  soledad = c("solo", "sola", "soledad", "solitario", "solitaria",
              "aislado", "aislada", "aislamiento", "abandonado", "abandonada",
              "unico", "unica", "sin compania", "apartado", "apartada",
              "desvinculado", "desvinculada"),
  espera = c("espera", "esperar", "espero", "esperaba", "aguarda", "aguardar",
             "quietud", "quieto", "quieta", "inmovilidad", "inmovil",
             "paciencia", "paciente", "detenido", "parado", "parada"),
  incomunicacion = c("silencio", "silenciosa", "silencioso", "mudo", "muda",
                     "callado", "callada", "calla", "incomunicacion", "incomunicado",
                     "monologo", "espaldas", "sin voz"),
  objetos = c("bolsa", "maletin", "sombrero", "ropa", "vestido", "prenda",
              "cama", "habitacion", "cuarto", "hotel", "piso", "suelo",
              "equipaje", "maleta", "cartera", "bolso",
              "mueble", "silla", "ventana", "cortina", "puerta",
              "mesilla", "almohada"),
  emociones_negativas = c("tristeza", "triste", "angustia", "angustiado", "angustiada",
                          "melancolia", "melancolico", "melancolica",
                          "desolacion", "desolado", "desolada",
                          "dolor", "doloroso", "dolorosa", "duele",
                          "pena", "penoso", "penosa",
                          "desaliento", "depresion", "deprimido", "deprimida",
                          "ansiedad", "ansioso", "ansiosa",
                          "inquietud", "inquieto", "inquieta",
                          "infeliz", "tormento", "atormentado"),
  luz_sombra = c("luz", "luminoso", "luminosa", "iluminado", "iluminada",
                 "sombra", "sombras", "sombrio", "sombria",
                 "claro", "claridad", "oscuro", "oscuridad", "oscura",
                 "penumbra", "brillo", "brillante", "destello", "radiante"),
  pasividad = c("sentado", "sentada", "quieto", "quieta", "quietud",
                "inmovil", "inmovilidad", "estatico", "estatica",
                "recostado", "recostada", "acostado", "acostada",
                "tumbado", "tumbada", "reposa", "reposaba",
                "descansa", "descansaba", "yace", "yacia"),
  desconexion = c("alejado", "alejada", "distancia", "distante", "lejos",
                  "lejano", "lejana", "separado", "separada",
                  "desvinculado", "desvinculada", "ignorado", "ignorada",
                  "olvidado", "olvidada", "invisible", "espaldas"),
  duda = c("duda", "dudaba", "dudar",
           "incierto", "incierta", "incertidumbre",
           "interrogante", "pregunta", "indecision", "indeciso", "indecisa",
           "vacilacion", "vacila", "dilema", "ambiguedad", "ambiguo", "ambigua"),
  espacio = c("habitacion", "cuarto", "hotel", "piso",
              "pared", "techo", "suelo", "ventana", "puerta",
              "interior", "exterior", "frontera", "limite",
              "espacio", "lugar", "ambito")
)

# ── Preparar corpus (tokenizar textos y agrupar por observación) ──────────
preparar_corpus <- function(datos_long) {
  # datos_long debe tener columnas: id_observacion, fuente, participante,
  # condicion, iteracion, texto, n_palabras_calculado
  corpus <- datos_long %>%
    mutate(
      texto_limpio = map_chr(texto, ~ ifelse(is.na(.), "", limpiar_texto(.))),
      tokens = map(texto_limpio, tokenizar)
    ) %>%
    filter(!is.na(tokens), map_int(tokens, length) > 0) %>%
    unnest(tokens) %>%
    rename(token = tokens) %>%
    group_by(id_observacion, fuente, participante, condicion, iteracion) %>%
    summarise(tokens_list = list(token), .groups = "drop") %>%
    ungroup()
  return(corpus)
}

# ── Extraer candidatos por tema (PMI y frecuencia) ────────────────────────
extraer_candidatos <- function(corpus, diccionarios, min_freq = 5, min_doc = 3, min_part = 2) {
  # 1. Frecuencias globales
  tokens_all <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%
    count(token, name = "freq_total")
  
  # 2. Document frequency (número de observaciones)
  doc_freq <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%
    distinct(id_observacion, token) %>%
    count(token, name = "doc_freq")
  
  # 3. Participant frequency
  part_freq <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%
    distinct(participante, token) %>%
    count(token, name = "part_freq")
  
  # 4. Unir métricas y filtrar
  term_stats <- tokens_all %>%
    left_join(doc_freq, by = "token") %>%
    left_join(part_freq, by = "token") %>%
    filter(freq_total >= min_freq, doc_freq >= min_doc, part_freq >= min_part)
  
  # 5. Crear DTM binaria
  dtm <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%
    distinct(id_observacion, token) %>%
    mutate(presence = 1) %>%
    pivot_wider(id_cols = id_observacion, names_from = token, values_from = presence, values_fill = 0)
  
  tokens_cols <- setdiff(colnames(dtm), "id_observacion")
  
  # Función para calcular PMI entre un candidato y un conjunto de semillas
  calcular_pmi <- function(candidato, semillas) {
    f_cand <- sum(dtm[[candidato]])
    f_sem <- sapply(semillas, function(s) if (s %in% tokens_cols) sum(dtm[[s]]) else 0)
    co_occ <- sapply(semillas, function(s) {
      if (s %in% tokens_cols) sum(dtm[[candidato]] & dtm[[s]]) else 0
    })
    pmi_vec <- log2((co_occ + 1) / (f_cand * f_sem + 1))
    mean(pmi_vec, na.rm = TRUE)
  }
  
  temas <- names(diccionarios)
  candidatos_list <- list()
  
  for (tema in temas) {
    semillas <- diccionarios[[tema]]
    semillas_existentes <- intersect(semillas, tokens_cols)
    if (length(semillas_existentes) == 0) next
    
    pmi_scores <- sapply(term_stats$token, function(tok) {
      calcular_pmi(tok, semillas_existentes)
    })
    names(pmi_scores) <- term_stats$token
    
    candidatos <- term_stats %>%
      mutate(pmi = pmi_scores[token]) %>%
      filter(pmi > 0) %>%
      arrange(desc(pmi)) %>%
      select(token, freq_total, doc_freq, part_freq, pmi)
    
    candidatos_list[[tema]] <- candidatos
  }
  
  return(candidatos_list)
}

# ── Enriquecer diccionarios (añadir candidatos aceptados manualmente) ──────
enriquecer_diccionarios <- function(base_dict, candidatos_aceptados) {
  # candidatos_aceptados: lista por tema con los términos a añadir
  enriquecido <- base_dict
  for (tema in names(candidatos_aceptados)) {
    enriquecido[[tema]] <- unique(c(enriquecido[[tema]], candidatos_aceptados[[tema]]))
  }
  return(enriquecido)
}

# ── Calcular cobertura de un diccionario sobre el corpus ───────────────────
calcular_cobertura <- function(corpus, diccionario, nombre) {
  # corpus: tibble con tokens_list por observación
  # diccionario: vector de términos
  cobertura_obs <- corpus %>%
    mutate(has_tema = map_lgl(tokens_list, ~ any(.x %in% diccionario))) %>%
    summarise(prop = mean(has_tema)) %>% pull(prop)
  
  cobertura_part <- corpus %>%
    group_by(participante) %>%
    summarise(has_tema = any(map_lgl(tokens_list, ~ any(.x %in% diccionario)))) %>%
    summarise(prop = mean(has_tema)) %>% pull(prop)
  
  total_tokens <- corpus %>% unnest(tokens_list) %>% nrow()
  tokens_tema <- corpus %>%
    unnest(tokens_list) %>%
    filter(tokens_list %in% diccionario) %>% nrow()
  cobertura_tokens <- tokens_tema / total_tokens
  
  return(tibble(
    diccionario = nombre,
    cobertura_obs = cobertura_obs,
    cobertura_part = cobertura_part,
    cobertura_tokens = cobertura_tokens
  ))
}

# ── Detectar solapamientos entre temas ──────────────────────────────────────
detectar_solapamientos <- function(diccionarios) {
  todos <- bind_rows(lapply(names(diccionarios), function(tema) {
    tibble(tema = tema, termino = diccionarios[[tema]])
  }))
  solapados <- todos %>%
    group_by(termino) %>%
    filter(n() > 1) %>%
    summarise(temas = paste(tema, collapse = ", ")) %>%
    ungroup()
  return(solapados)
}

# ── Aplicar diccionarios a formato largo (conteos y tasas) ────────────────
aplicar_diccionarios_long <- function(datos_long, diccionarios) {
  # datos_long: dataframe con columnas id_observacion, texto
  # diccionarios: lista de vectores de términos
  # Devuelve: dataframe con id_observacion, metadatos, scores (conteos y tasas)
  
  # Si no existe columna 'tokens', la creamos
  if (!"tokens" %in% names(datos_long)) {
    datos_long <- datos_long %>%
      mutate(texto_limpio = map_chr(texto, ~ ifelse(is.na(.), "", limpiar_texto(.))),
             tokens = map(texto_limpio, tokenizar))
  }
  
  tokens_por_obs <- datos_long %>%
    select(id_observacion, tokens) %>%
    distinct()
  
  scores <- tokens_por_obs %>%
    select(id_observacion)
  
  for (tema in names(diccionarios)) {
    col_score <- paste0("score_", tema)
    scores <- scores %>%
      left_join(
        tokens_por_obs %>%
          rowwise() %>%
          mutate(!!col_score := sum(tokens %in% diccionarios[[tema]])) %>%
          ungroup() %>%
          select(id_observacion, !!col_score),
        by = "id_observacion"
      )
  }
  
  result <- datos_long %>%
    select(id_observacion, fuente, participante, id_participante, condicion, demora, iteracion, n_palabras_calculado) %>%
    distinct() %>%
    left_join(scores, by = "id_observacion")
  
  # Añadir tasas normalizadas (por 1000 palabras)
  for (tema in names(diccionarios)) {
    col_score <- paste0("score_", tema)
    col_rate <- paste0("rate_", tema)
    result <- result %>%
      mutate(!!col_rate := (!!sym(col_score) / n_palabras_calculado) * 1000)
  }
  
  return(result)
}