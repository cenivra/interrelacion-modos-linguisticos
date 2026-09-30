# ============================================================================
# 01_import_data.R — CARGA, NORMALIZACIÓN, INTEGRACIÓN Y VALIDACIÓN DE DATOS
# ============================================================================
# Este módulo contiene funciones para:
#   - Importar los datasets principal y piloto desde Excel.
#   - Normalizarlos a un esquema canónico (formato largo).
#   - Validar la estructura y consistencia.
#   - Integrar múltiples fuentes y generar formato ancho.
# ============================================================================

# ── Función para derivar n_estimulos según iteración ──────────────────────
derivar_n_estimulos <- function(iteracion) {
  case_when(
    iteracion == 1 ~ 0L,
    iteracion == 2 ~ 1L,
    iteracion == 3 ~ 3L,
    TRUE ~ NA_integer_
  )
}

# ── Importación del dataset principal ──────────────────────────────────────
importar_principal <- function(ruta, hoja = "Datos_Largo") {
  registrar_log(sprintf("Importando principal desde %s, hoja %s", ruta, hoja))
  if (!file.exists(ruta)) stop("Archivo no encontrado: ", ruta)
  
  raw <- read_excel(ruta, sheet = hoja)
  raw <- raw %>% filter(!is.na(participante), !is.na(texto))
  
  registrar_log(sprintf("Principal importado: %d filas, %d columnas",
                        nrow(raw), ncol(raw)))
  raw
}

# ── Importación del dataset piloto ──────────────────────────────────────────
#' Importar el dataset piloto desde Excel
#'
#' @param ruta Ruta al archivo Excel del piloto
#' @param hoja Hoja a leer. Por defecto "Datos_Largo" (formato largo correcto).
#'   Se puede usar "Hoja1" como respaldo (layout visual con celdas combinadas),
#'   pero emite advertencia.
#' @return Dataframe en formato largo con columnas canónicas
importar_piloto <- function(ruta, hoja = "Datos_Largo") {
  registrar_log(sprintf("Importando piloto desde %s, hoja %s", ruta, hoja))
  if (!file.exists(ruta)) stop("Archivo no encontrado: ", ruta)
  
  if (hoja == "Hoja1") {
    warning("⚠ Leyendo hoja 'Hoja1' (layout visual). Esta ruta es un respaldo; ",
            "los datos de condición se deducen del número de participante y ",
            "pueden ser INCORRECTOS. Use 'Datos_Largo' (formato largo) para resultados válidos.")
    
    raw <- read_excel(ruta, sheet = hoja, col_names = FALSE, .name_repair = "minimal")
    
    participantes <- trimws(as.character(raw[[1]]))
    idx_validos <- which(!is.na(participantes) & participantes != "")
    
    extraer_texto_bloque <- function(fila, cols) {
      for (c in cols) {
        val <- fila[[c]]
        if (!is.na(val) && trimws(val) != "") {
          return(as.character(val))
        }
      }
      return(NA_character_)
    }
    
    bloques <- list(t1 = 5:9, t2 = 11:15, t3 = 17:21)
    resultado <- list()
    
    for (i in idx_validos) {
      p <- participantes[i]
      fila <- raw[i, ]
      for (bloque in names(bloques)) {
        texto <- extraer_texto_bloque(fila, bloques[[bloque]])
        iteracion <- as.integer(gsub("t", "", bloque))
        resultado <- append(resultado, list(data.frame(
          participante = p,
          iteracion = iteracion,
          texto = texto,
          stringsAsFactors = FALSE
        )))
      }
    }
    
    df_piloto <- do.call(rbind, resultado)
    df_piloto <- df_piloto %>%
      mutate(
        condicion = case_when(
          participante %in% paste0("P", 1:5)  ~ "Texto",
          participante %in% paste0("P", 6:11) ~ "Audio",
          participante %in% paste0("P", 12:17) ~ "Imagen",
          TRUE ~ NA_character_
        )
      ) %>%
      filter(!is.na(condicion), !is.na(texto))
    
    registrar_log(sprintf("Piloto importado (Hoja1, respaldo): %d observaciones", nrow(df_piloto)))
    return(df_piloto)
  }
  
  # --- Ruta por defecto: Datos_Largo (formato largo correcto) ---
  raw <- read_excel(ruta, sheet = hoja)
  
  # Esperamos columnas: fuente, participante, condicion, demora, iteracion,
  # texto, n_palabras_excel, n_estimulos, n_palabras_calculado
  # n_palabras_excel puede venir vacía (NA) → dejar n_palabras = NA
  
  # Normalizar nombres de columnas esperadas
  nombres_esperados <- c("fuente", "participante", "condicion", "demora",
                         "iteracion", "texto", "n_palabras_excel", "n_estimulos",
                         "n_palabras_calculado")
  faltantes <- setdiff(nombres_esperados, names(raw))
  if (length(faltantes) > 0) {
    warning("Columnas esperadas no encontradas en Datos_Largo: ",
            paste(faltantes, collapse = ", "), 
            ". Intentando leer de todas formas.")
  }
  
  # Renombrar n_palabras_excel → n_palabras si existe
  if ("n_palabras_excel" %in% names(raw)) {
    raw <- raw %>% rename(n_palabras = n_palabras_excel)
  }
  
  # Asegurar que n_palabras existe (si no venía en el Excel)
  if (!"n_palabras" %in% names(raw)) {
    raw$n_palabras <- NA_integer_
  }
  
  # Filtrar filas válidas
  raw <- raw %>% filter(!is.na(participante), !is.na(texto))
  
  registrar_log(sprintf("Piloto importado (Datos_Largo): %d filas, %d columnas",
                        nrow(raw), ncol(raw)))
  raw
}

# ── Normalización del principal al esquema canónico ──────────────────────
normalizar_principal <- function(raw) {
  registrar_log("Normalizando dataset principal")
  
  df <- raw %>%
    mutate(
      fuente = "principal",
      participante = as.character(trimws(participante)),
      condicion = as.character(trimws(condicion)),
      demora = as.character(trimws(demora)),
      iteracion = as.integer(iteracion),
      texto = as.character(texto),
      n_palabras = as.integer(n_palabras),
      n_palabras_calculado = str_count(texto, "\\S+"),
      n_estimulos = derivar_n_estimulos(iteracion),
      id_participante = paste(fuente, participante, sep = "_"),
      id_observacion = paste(id_participante, iteracion, sep = "_")
    ) %>%
    select(fuente, participante, id_participante, id_observacion,
           condicion, demora, iteracion, texto,
           n_palabras, n_palabras_calculado, n_estimulos)
  
  registrar_log(sprintf("Principal normalizado: %d observaciones", nrow(df)))
  df
}

# ── Normalización del piloto al esquema canónico ──────────────────────────
normalizar_piloto <- function(raw) {
  registrar_log("Normalizando dataset piloto")
  
  df <- raw %>%
    mutate(
      fuente = "piloto",
      participante = as.character(trimws(participante)),
      condicion = as.character(trimws(condicion)),
      iteracion = as.integer(iteracion),
      texto = as.character(texto),
      demora = NA_character_,
      n_palabras = NA_integer_,
      n_palabras_calculado = str_count(texto, "\\S+"),
      n_estimulos = derivar_n_estimulos(iteracion),
      id_participante = paste(fuente, participante, sep = "_"),
      id_observacion = paste(id_participante, iteracion, sep = "_")
    ) %>%
    select(fuente, participante, id_participante, id_observacion,
           condicion, demora, iteracion, texto,
           n_palabras, n_palabras_calculado, n_estimulos)
  
  registrar_log(sprintf("Piloto normalizado: %d observaciones", nrow(df)))
  df
}

# ── Validación del esquema canónico ──────────────────────────────────────
validar_esquema <- function(df, nombre = "dataset") {
  cat(sprintf("\n=== VALIDACIÓN DE ESQUEMA: %s ===\n", nombre))
  
  columnas_requeridas <- c("fuente", "participante", "id_participante",
                           "id_observacion", "condicion", "demora",
                           "iteracion", "texto", "n_palabras",
                           "n_palabras_calculado", "n_estimulos")
  faltantes <- setdiff(columnas_requeridas, names(df))
  if (length(faltantes) > 0) {
    stop("Faltan columnas: ", paste(faltantes, collapse = ", "))
  }
  
  # Validaciones adicionales (tipos, valores, consistencia)
  # 1. Tipos básicos
  if (!is.character(df$fuente)) stop("'fuente' debe ser character")
  if (!is.character(df$participante)) stop("'participante' debe ser character")
  if (!is.character(df$id_participante)) stop("'id_participante' debe ser character")
  if (!is.character(df$id_observacion)) stop("'id_observacion' debe ser character")
  if (!is.character(df$condicion)) stop("'condicion' debe ser character")
  if (!is.character(df$demora)) stop("'demora' debe ser character")
  if (!is.integer(df$iteracion)) stop("'iteracion' debe ser integer")
  if (!is.character(df$texto)) stop("'texto' debe ser character")
  if (!is.integer(df$n_palabras)) stop("'n_palabras' debe ser integer")
  if (!is.integer(df$n_palabras_calculado)) stop("'n_palabras_calculado' debe ser integer")
  if (!is.integer(df$n_estimulos)) stop("'n_estimulos' debe ser integer")
  
  # 2. n_palabras_calculado no negativo
  if (any(df$n_palabras_calculado < 0, na.rm = TRUE)) {
    stop("'n_palabras_calculado' tiene valores negativos")
  }
  
  # 3. Ausencia de duplicados en id_observacion
  dup_obs <- df$id_observacion[duplicated(df$id_observacion)]
  if (length(dup_obs) > 0) {
    stop("Duplicados en 'id_observacion': ", paste(unique(dup_obs), collapse = ", "))
  }
  
  # 4. Unicidad de id_participante dentro de cada cohorte (fuente)
  ids_por_fuente <- df %>% group_by(fuente) %>% summarise(n = n_distinct(id_participante), .groups = "drop")
  cat(sprintf("Participantes únicos por fuente:\n"))
  print(ids_por_fuente)
  
  # Verificar que dentro de cada fuente no hay duplicados de id_participante
  for (f in unique(df$fuente)) {
    ids_f <- df %>% filter(fuente == f) %>% pull(id_participante)
    dup_ids <- ids_f[duplicated(ids_f)]
    if (length(dup_ids) > 0) {
      stop(sprintf("Duplicados de 'id_participante' en fuente '%s': %s",
                   f, paste(unique(dup_ids), collapse = ", ")))
    }
  }
  
  # 5. Prefijos distintos entre cohortes (aserción explícita)
  prefijos <- df %>% group_by(fuente) %>% summarise(
    prefijo = unique(sub("_.*", "", id_participante)),
    .groups = "drop"
  )
  if (length(unique(prefijos$prefijo)) != nrow(prefijos)) {
    stop("Prefijos de id_participante NO son únicos entre cohortes: ",
         paste(prefijos$prefijo, collapse = ", "))
  }
  cat("✓ Prefijos de cohortes son distintos: ", paste(prefijos$prefijo, collapse = ", "), "\n")
  
  cat("✓ Esquema válido.\n")
  invisible(list(ok = TRUE))
}

# ── Validación del dataset maestro integrado ──────────────────────────────
validar_dataset_maestro <- function(df) {
  cat("\n========== VALIDACIÓN DEL DATASET MAESTRO ==========\n")
  
  # Validar esquema base
  validar_esquema(df, nombre = "maestro_integrado")
  
  # 1. Fuentes presentes
  fuentes <- unique(df$fuente)
  cat("Fuentes en el dataset maestro:", paste(fuentes, collapse = ", "), "\n")
  if (!all(c("principal", "piloto") %in% fuentes)) {
    warning("No están presentes ambas cohortes (principal y piloto)")
  }
  
  # 2. Distribución por fuente
  tabla <- df %>% group_by(fuente) %>% summarise(
    n_obs = n(),
    n_participantes = n_distinct(id_participante),
    .groups = "drop"
  )
  cat("\nDistribución por fuente:\n")
  print(tabla)
  
  # 3. Missing summary
  missing_summary <- df %>% summarise(across(everything(), ~ sum(is.na(.)))) %>%
    pivot_longer(everything(), names_to = "columna", values_to = "n_missing") %>%
    filter(n_missing > 0)
  if (nrow(missing_summary) > 0) {
    cat("\nValores faltantes:\n")
    print(missing_summary)
  } else {
    cat("\nSin valores faltantes.\n")
  }
  
  # 4. Unicidad de id_observacion en todo el maestro
  dup_maestro <- df$id_observacion[duplicated(df$id_observacion)]
  if (length(dup_maestro) > 0) {
    stop("Duplicados en 'id_observacion' en dataset maestro: ",
         paste(unique(dup_maestro), collapse = ", "))
  }
  
  # 5. Aserción de prefijos distintos (redundante pero explícita)
  prefijos <- df %>% group_by(fuente) %>% summarise(
    prefijo = unique(sub("_.*", "", id_participante)),
    .groups = "drop"
  )
  if (length(unique(prefijos$prefijo)) != nrow(prefijos)) {
    stop("Prefijos NO son únicos entre cohortes en dataset maestro")
  }
  cat("✓ Dataset maestro válido: prefijos distintos confirmados\n")
  
  cat("====================================================\n\n")
  invisible(list(fuentes = fuentes, tabla = tabla, missing = missing_summary))
}

# ── Validación del dataset maestro integrado ──────────────────────────────
validar_dataset_maestro <- function(df) {
  cat("\n========== VALIDACIÓN DEL DATASET MAESTRO ==========\n")
  # ... (código completo del original)
  cat("====================================================\n\n")
  invisible(list(fuentes = fuentes, tabla = tabla, missing = missing_summary))
}

# ── Integración de múltiples fuentes ──────────────────────────────────────
integrar_fuentes <- function(lista_dfs) {
  registrar_log("Integrando fuentes...")
  for (i in seq_along(lista_dfs)) {
    validar_esquema(lista_dfs[[i]], nombre = paste0("fuente_", i))
  }
  df <- bind_rows(lista_dfs)
  registrar_log(sprintf("Integración completada: %d observaciones totales", nrow(df)))
  df
}

# ── Generación de formato ancho a partir del largo ────────────────────────
generar_ancho <- function(df_long) {
  registrar_log("Generando formato ancho...")
  id_vars <- c("fuente", "participante", "id_participante", "condicion", "demora")
  id_vars <- intersect(id_vars, names(df_long))
  
  ancho <- df_long %>%
    pivot_wider(
      id_cols = all_of(id_vars),
      names_from = iteracion,
      values_from = c(texto, n_palabras, n_palabras_calculado, n_estimulos),
      names_glue = "{.value}_t{iteracion}"
    )
  registrar_log(sprintf("Ancho generado: %d filas, %d columnas", nrow(ancho), ncol(ancho)))
  ancho
}

# ── Función de validación del objeto 'datos' (largo/ancho) ────────────────
validar_datos <- function(datos) {
  d  <- datos$largo
  da <- datos$ancho
  
  cat("\n========== VALIDACIÓN DE DATOS ==========\n")
  cat(sprintf("Participantes únicos : %d\n", n_distinct(d$participante)))
  cat(sprintf("Observaciones totales: %d\n\n", nrow(d)))
  cat("Textos por iteración:\n")
  print(table(d$iteracion))
  cat("\nDistribución por condición:\n")
  print(table(d$condicion))
  cat("\nDistribución por demora:\n")
  print(table(d$demora))
  cat("\nTamaño de grupos (condicion × demora) — solo iteración 1:\n")
  grupo_n <- d %>%
    filter(iteracion == 1) %>%
    count(condicion, demora) %>%
    arrange(condicion, demora)
  print(grupo_n)
  
  grupos_chicos <- grupo_n %>% filter(n < 4)
  if (nrow(grupos_chicos) > 0) {
    cat("\n⚠ ADVERTENCIA: grupos con n < 4 (baja potencia estadística):\n")
    print(grupos_chicos)
  }
  cat("=========================================\n\n")
}