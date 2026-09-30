# ============================================================================
# 03_sentiment.R — ANÁLISIS DE SENTIMIENTO CON LÉXICO NRC-ES
# ============================================================================
# Este módulo contiene funciones para:
#   - Descargar y procesar el léxico NRC-ES desde la fuente oficial.
#   - Validar y almacenar localmente el léxico.
#   - Analizar sentimiento de textos usando el léxico (8 emociones básicas).
#   - Aplicar el análisis a todo el dataset.
# ============================================================================

# ── Constantes ──────────────────────────────────────────────────────────────
RUTA_LEXICO_LOCAL <- here::here("data", "raw", "lexicons", "nrc_es.rds")   # léxico versionado en el repo (antes: data/lexicons, ruta inexistente)
URL_NRC_ZIP <- "https://saifmohammad.com/WebDocs/NRC-Emotion-Lexicon.zip"
NOMBRE_EXCEL <- "NRC-Emotion-Lexicon-v0.92-In105Languages-Nov2017Translations.xlsx"
NOMBRE_HOJA <- "NRC-Lex-v0.92-word-translations"

EMOCIONES_NRC <- c("joy", "sadness", "fear", "anger", "anticipation",
                   "trust", "surprise", "disgust")
EMOCIONES_EXCEL <- c("Anger", "Anticipation", "Disgust", "Fear",
                     "Joy", "Sadness", "Surprise", "Trust")
MAPEO_EMOCIONES <- setNames(tolower(EMOCIONES_EXCEL), EMOCIONES_EXCEL)

# ── Normalización específica para el léxico ──────────────────────────────
normalizar_palabra_lexico <- function(palabra) {
  if (is.na(palabra) || nchar(trimws(palabra)) == 0) return("")
  palabra <- tolower(trimws(palabra))
  palabra <- iconv(palabra, from = "UTF-8", to = "ASCII//TRANSLIT")
  palabra <- gsub("[^a-z]", "", palabra)
  return(palabra)
}

# ── Validación del léxico ──────────────────────────────────────────────────
validar_lexico_nrc_es <- function(lexico, detener = TRUE) {
  errores <- c()
  advertencias <- c()
  
  if (!is.list(lexico)) {
    errores <- c(errores, "El objeto no es una lista.")
  } else {
    if (!all(EMOCIONES_NRC %in% names(lexico))) {
      faltantes <- setdiff(EMOCIONES_NRC, names(lexico))
      errores <- c(errores, paste("Faltan emociones:", paste(faltantes, collapse = ", ")))
    }
    for (emo in EMOCIONES_NRC) {
      if (!is.character(lexico[[emo]])) {
        errores <- c(errores, paste("La emoción", emo, "no es un vector de caracteres."))
      }
    }
    vacias <- sapply(lexico, function(x) length(x) == 0)
    if (any(vacias)) {
      errores <- c(errores, paste("Categorías vacías:", paste(names(lexico)[vacias], collapse = ", ")))
    }
    if (any(sapply(lexico, function(x) any(is.na(x))))) {
      errores <- c(errores, "Se encontraron NA en los vectores de palabras.")
    }
    for (emo in EMOCIONES_NRC) {
      palabras <- lexico[[emo]]
      if (length(palabras) > 0 && any(grepl("[^a-z]", palabras))) {
        errores <- c(errores, paste("La emoción", emo, "contiene caracteres no permitidos."))
      }
    }
    for (emo in EMOCIONES_NRC) {
      if (any(duplicated(lexico[[emo]]))) {
        errores <- c(errores, paste("La emoción", emo, "contiene duplicados."))
      }
    }
    total <- sum(sapply(lexico, length))
    if (total < 1000) {
      errores <- c(errores, paste("El léxico es demasiado pequeño:", total, "palabras."))
    }
  }
  
  # Serialización
  tryCatch({
    tmp <- tempfile()
    saveRDS(lexico, file = tmp)
    readRDS(tmp)
    unlink(tmp)
  }, error = function(e) {
    errores <- c(errores, paste("No se puede serializar:", e$message))
  })
  
  if (length(errores) == 0) {
    cat("[VALIDACIÓN] Léxico NRC-ES válido.\n")
    resumen <- data.frame(
      emocion = names(lexico),
      n_palabras = sapply(lexico, length)
    )
    print(resumen)
    return(invisible(TRUE))
  } else {
    cat("[VALIDACIÓN] ERRORES encontrados:\n")
    cat(paste("  -", errores), sep = "\n")
    if (detener) {
      stop("El léxico no superó la validación. No se puede utilizar.", call. = FALSE)
    } else {
      return(FALSE)
    }
  }
}

# ── Preparar léxico (descarga, procesamiento, guardado) ──────────────────
preparar_lexico_nrc_es <- function() {
  cat("[INFO] Preparando léxico NRC-ES desde fuente oficial...\n")
  dir.create(dirname(RUTA_LEXICO_LOCAL), recursive = TRUE, showWarnings = FALSE)
  
  cat("  → Descargando archivo ZIP desde:\n     ", URL_NRC_ZIP, "\n")
  zip_temp <- tempfile(fileext = ".zip")
  tryCatch({
    curl_download(URL_NRC_ZIP, zip_temp, quiet = FALSE)
  }, error = function(e) {
    stop("No se pudo descargar el ZIP. Verifica conexión a internet.\n",
         "  Error original: ", e$message, call. = FALSE)
  })
  
  archivos_zip <- unzip(zip_temp, list = TRUE)
  excel_path <- archivos_zip$Name[grepl(NOMBRE_EXCEL, archivos_zip$Name, fixed = TRUE)]
  if (length(excel_path) == 0) {
    stop("No se encontró el archivo Excel esperado dentro del ZIP.")
  }
  cat("  → Archivo encontrado:", excel_path[1], "\n")
  
  xlsx_temp <- tempfile(fileext = ".xlsx")
  unzip(zip_temp, files = excel_path[1], exdir = dirname(xlsx_temp))
  archivo_extraido <- file.path(dirname(xlsx_temp), excel_path[1])
  if (!file.exists(archivo_extraido)) {
    stop("Error al extraer el archivo Excel.")
  }
  file.rename(archivo_extraido, xlsx_temp)
  
  cat("  → Leyendo archivo Excel (hoja:", NOMBRE_HOJA, ")...\n")
  datos_xlsx <- tryCatch({
    read_excel(xlsx_temp, sheet = NOMBRE_HOJA, .name_repair = "minimal")
  }, error = function(e) {
    stop("Error al leer el Excel: ", e$message, call. = FALSE)
  })
  
  cat("[INFO] Columnas detectadas en Excel:\n")
  print(names(datos_xlsx))
  
  # Detección robusta de columnas
  idx_en <- which(grepl("^English \\(en\\)", names(datos_xlsx)))
  if (length(idx_en) < 1) {
    stop("No se encontró ninguna columna English (en).", call. = FALSE)
  }
  col_en <- names(datos_xlsx)[idx_en[1]]
  cat("[INFO] Columna inglesa seleccionada:", col_en, "\n")
  
  idx_es <- which(grepl("^Spanish \\(es\\)$", names(datos_xlsx)))
  if (length(idx_es) != 1) {
    stop("No se encontró exactamente una columna Spanish (es).", call. = FALSE)
  }
  col_es <- names(datos_xlsx)[idx_es]
  cat("[INFO] Columna española seleccionada:", col_es, "\n")
  
  faltan_emociones <- setdiff(EMOCIONES_EXCEL, names(datos_xlsx))
  if (length(faltan_emociones) > 0) {
    stop("Faltan columnas de emociones: ", paste(faltan_emociones, collapse = ", "), call. = FALSE)
  }
  
  cat("  → Dimensiones del Excel:", nrow(datos_xlsx), "filas x", ncol(datos_xlsx), "columnas\n")
  
  df <- datos_xlsx %>%
    select(all_of(c(col_es, EMOCIONES_EXCEL))) %>%
    rename(spanish_raw = !!col_es) %>%
    filter(!is.na(spanish_raw) & nchar(trimws(spanish_raw)) > 0)
  cat("  → Traducciones españolas no vacías:", nrow(df), "\n")
  
  df$spanish_norm <- sapply(df$spanish_raw, normalizar_palabra_lexico)
  df <- df %>% filter(nchar(spanish_norm) > 0)
  cat("  → Traducciones válidas tras normalización:", nrow(df), "\n")
  
  # Construir léxico
  lista_lexico <- list()
  for (emo_excel in EMOCIONES_EXCEL) {
    emo_interno <- MAPEO_EMOCIONES[[emo_excel]]
    palabras <- df$spanish_norm[df[[emo_excel]] == 1]
    palabras <- sort(unique(palabras))
    lista_lexico[[emo_interno]] <- palabras
  }
  
  if (any(sapply(lista_lexico, length) == 0)) {
    vacias <- names(lista_lexico)[sapply(lista_lexico, length) == 0]
    stop("ERROR CRÍTICO: las siguientes emociones quedaron vacías: ",
         paste(vacias, collapse = ", "), call. = FALSE)
  }
  if (sum(sapply(lista_lexico, length)) == 0) {
    stop("ERROR CRÍTICO: el léxico construido quedó completamente vacío.",
         call. = FALSE)
  }
  
  cat("\n--- MÉTRICAS DE COBERTURA ---\n")
  resumen <- data.frame(
    emocion = names(lista_lexico),
    n_palabras = sapply(lista_lexico, length)
  )
  print(resumen, row.names = FALSE)
  
  # Comprobación con palabras conocidas
  palabras_prueba <- c("amor", "miedo", "muerte", "enfado", "esperanza", "contento")
  cat("\n--- COMPROBACIÓN DE PALABRAS CONOCIDAS ---\n")
  for (pal in palabras_prueba) {
    pal_norm <- normalizar_palabra_lexico(pal)
    emociones_pal <- names(lista_lexico)[sapply(lista_lexico, function(x) pal_norm %in% x)]
    if (length(emociones_pal) > 0) {
      cat(pal, " → ", paste(emociones_pal, collapse = ", "), "\n")
    } else {
      cat(pal, " → no encontrada en el léxico\n")
    }
  }
  cat("-------------------------------------------\n")
  
  cat("  → Validando léxico...\n")
  validar_lexico_nrc_es(lista_lexico, detener = TRUE)
  
  saveRDS(lista_lexico, file = RUTA_LEXICO_LOCAL)
  cat("[OK] Léxico NRC-ES guardado en:\n     ", RUTA_LEXICO_LOCAL, "\n")
  
  unlink(zip_temp)
  unlink(xlsx_temp)
  
  return(lista_lexico)
}

# ── Inicializar léxico (cargar o preparar) ──────────────────────────────
inicializar_lexico <- function() {
  .lexico_nrc_es <<- NULL
  
  if (file.exists(RUTA_LEXICO_LOCAL)) {
    cat("[INFO] Intentando cargar léxico desde almacenamiento local...\n")
    lex_local <- tryCatch({
      readRDS(RUTA_LEXICO_LOCAL)
    }, error = function(e) {
      warning("El archivo local parece corrupto: ", e$message)
      return(NULL)
    })
    
    if (!is.null(lex_local) && is.list(lex_local) && all(EMOCIONES_NRC %in% names(lex_local))) {
      if (validar_lexico_nrc_es(lex_local, detener = FALSE)) {
        .lexico_nrc_es <<- lex_local
        cat("[OK] NRC-ES cargado desde almacenamiento local.\n")
        return(invisible(.lexico_nrc_es))
      } else {
        warning("El archivo local no pasó la validación. Se eliminará y se intentará descargar nuevamente.")
        file.remove(RUTA_LEXICO_LOCAL)
      }
    } else {
      warning("El archivo local no tiene la estructura esperada. Se eliminará.")
      file.remove(RUTA_LEXICO_LOCAL)
    }
  }
  
  cat("[INFO] No se encontró léxico local válido. Procediendo a descarga...\n")
  tryCatch({
    lex_nuevo <- preparar_lexico_nrc_es()
    .lexico_nrc_es <<- lex_nuevo
    cat("[OK] NRC-ES descargado y almacenado localmente.\n")
    return(invisible(.lexico_nrc_es))
  }, error = function(e) {
    stop("[ERROR] No fue posible obtener el léxico NRC-ES.\n",
         "  Motivo: ", e$message, "\n",
         "  Asegúrate de tener conexión a internet para la primera descarga,\n",
         "  o coloca manualmente el archivo 'nrc_es.rds' en:\n",
         "     ", RUTA_LEXICO_LOCAL, "\n",
         "  Para descargar manualmente, ejecuta: preparar_lexico_nrc_es()",
         call. = FALSE)
  })
}

# ── Analizar sentimiento de un texto ──────────────────────────────────────
analizar_sentimiento_es <- function(texto) {
  if (is.null(.lexico_nrc_es)) {
    stop("El léxico NRC-ES no está cargado. Ejecuta 'inicializar_lexico()' primero.")
  }
  
  if (is.na(texto) || nchar(trimws(texto)) == 0) {
    scores <- setNames(rep(NA_real_, length(EMOCIONES_NRC)), EMOCIONES_NRC)
    return(c(scores, list(estado = "vacio")))
  }
  
  texto_limpio <- limpiar_texto(texto)
  if (nchar(texto_limpio) == 0) {
    scores <- setNames(rep(NA_real_, length(EMOCIONES_NRC)), EMOCIONES_NRC)
    return(c(scores, list(estado = "vacio")))
  }
  tokens <- tokenizar(texto_limpio)
  if (length(tokens) == 0) {
    scores <- setNames(rep(NA_real_, length(EMOCIONES_NRC)), EMOCIONES_NRC)
    return(c(scores, list(estado = "vacio")))
  }
  
  tryCatch({
    freq <- table(tokens)
    palabras <- names(freq)
    scores <- setNames(rep(0, length(EMOCIONES_NRC)), EMOCIONES_NRC)
    for (emo in EMOCIONES_NRC) {
      palabras_emo <- .lexico_nrc_es[[emo]]
      if (!is.null(palabras_emo) && length(palabras_emo) > 0) {
        comunes <- intersect(palabras, palabras_emo)
        if (length(comunes) > 0) {
          scores[[emo]] <- sum(freq[comunes], na.rm = TRUE)
        }
      }
    }
    return(c(scores, list(estado = "ok")))
  }, error = function(e) {
    warning("Error al analizar sentimiento: ", e$message)
    scores <- setNames(rep(NA_real_, length(EMOCIONES_NRC)), EMOCIONES_NRC)
    return(c(scores, list(estado = "error")))
  })
}

# ── Calcular sentimientos sobre el dataset ancho ──────────────────────────
calcular_sentimientos <- function(datos) {
  if (is.null(.lexico_nrc_es)) {
    inicializar_lexico()
  }
  if (is.null(.lexico_nrc_es)) {
    stop("[ERROR] No se dispone del léxico NRC-ES. No se pueden calcular sentimientos.")
  }
  
  registrar_log("Analizando sentimientos con NRC-ES...")
  
  datos$ancho <- datos$ancho %>%
    rowwise() %>%
    mutate(
      s1 = list(analizar_sentimiento_es(t1_limpio)),
      s2 = list(analizar_sentimiento_es(t2_limpio)),
      s3 = list(analizar_sentimiento_es(t3_limpio)),
      
      joy_t1 = s1$joy, sadness_t1 = s1$sadness, fear_t1 = s1$fear,
      anger_t1 = s1$anger, anticipation_t1 = s1$anticipation,
      trust_t1 = s1$trust, surprise_t1 = s1$surprise, disgust_t1 = s1$disgust,
      sent_estado_t1 = s1$estado,
      
      joy_t2 = s2$joy, sadness_t2 = s2$sadness, fear_t2 = s2$fear,
      anger_t2 = s2$anger, anticipation_t2 = s2$anticipation,
      trust_t2 = s2$trust, surprise_t2 = s2$surprise, disgust_t2 = s2$disgust,
      sent_estado_t2 = s2$estado,
      
      joy_t3 = s3$joy, sadness_t3 = s3$sadness, fear_t3 = s3$fear,
      anger_t3 = s3$anger, anticipation_t3 = s3$anticipation,
      trust_t3 = s3$trust, surprise_t3 = s3$surprise, disgust_t3 = s3$disgust,
      sent_estado_t3 = s3$estado
    ) %>%
    select(-s1, -s2, -s3) %>%
    ungroup()
  
  registrar_log("Sentimientos calculados correctamente")
  cat("[OK] Análisis de sentimientos completado. Léxico local utilizado.\n")
  return(datos)
}