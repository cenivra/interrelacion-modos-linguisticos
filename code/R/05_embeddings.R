# ============================================================================
# 05_embeddings.R — EMBEDDINGS, PROTOTIPOS SEMÁNTICOS Y PCA
# ============================================================================
#
# Infraestructura:
#   Python / sentence-transformers genera los embeddings.
#
# Responsabilidades conservadas en R:
#   - Normalización de textos.
#   - Caché.
#   - Normalización L2 final.
#   - Prototipos semánticos.
#   - Centroides.
#   - Similitud coseno.
#   - Proximidad a prototipos.
#   - Análisis posterior.
#
# La migración NO modifica el contenido científico de los prototipos.
# ============================================================================

suppressPackageStartupMessages({
  library(reticulate)
})

# ---------------------------------------------------------------------------
# Python / Sentence Transformers
# ---------------------------------------------------------------------------

source_python(
  here::here("code", "python", "embeddings_setup.py")
)

# ---------------------------------------------------------------------------
# Caché de embeddings
# ---------------------------------------------------------------------------

.emb_cache <- new.env(parent = emptyenv())

# ---------------------------------------------------------------------------
# Obtener embeddings
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Obtener embeddings (función base, sin guardado a disco)
# ---------------------------------------------------------------------------

obtener_embeddings <- function(
  textos,
  normalize = TRUE,
  batch_size = 32L
) {

  # ---------------------------------------------------------
  # 1. Normalización R
  #
  # IMPORTANTE:
  # reticulate convierte NA_character_ en el string Python "NA".
  #
  # Por eso la normalización debe ocurrir ANTES de cruzar
  # la frontera R -> Python.
  # ---------------------------------------------------------

  textos <- as.character(textos)

  # Contar textos vacíos ANTES de reemplazar
  n_vacios <- sum(is.na(textos) | trimws(textos) == "")
  if (n_vacios > 0) {
    registrar_log(sprintf("obtener_embeddings: %d textos vacíos/NA detectados, se reemplazarán por '[VACÍO]'", n_vacios))
  }

  textos[
    is.na(textos) |
      trimws(textos) == ""
  ] <- "[VACÍO]"

  # ---------------------------------------------------------
  # 2. Clave de caché
  # ---------------------------------------------------------

  key <- if (
    requireNamespace("digest", quietly = TRUE)
  ) {

    digest::digest(
      list(
        textos,
        normalize,
        batch_size
      ),
      algo = "md5"
    )

  } else {

    paste(
      length(textos),
      sum(nchar(textos)),
      normalize,
      batch_size,
      sep = "|"
    )
  }

  if (exists(key, envir = .emb_cache)) {

    return(
      get(
        key,
        envir = .emb_cache
      )
    )
  }

  # ---------------------------------------------------------
  # 3. Inferencia Python
  #
  # Usamos normalize = FALSE aquí para reproducir exactamente
  # el comportamiento científico del pipeline legacy:
  #
  # Python:
  #   encode(...)
  #
  # R:
  #   normalización L2
  # ---------------------------------------------------------

  embs <- encode_texts(
    textos,
    normalize = FALSE,
    batch_size = as.integer(batch_size)
  )

  embs <- as.matrix(embs)

  storage.mode(embs) <- "double"

  # ---------------------------------------------------------
  # 4. Normalización L2 en R
  # ---------------------------------------------------------

  if (normalize) {

    nrm <- sqrt(
      rowSums(
        embs^2
      )
    )

    nrm[
      nrm < 1e-12
    ] <- 1

    embs <- embs / nrm
  }

  # ---------------------------------------------------------
  # 5. Caché
  # ---------------------------------------------------------

  assign(
    key,
    embs,
    envir = .emb_cache
  )

  # Devolver también metadatos como atributos
  attr(embs, "n_vacios") <- n_vacios
  attr(embs, "n_textos") <- length(textos)
  attr(embs, "modelo") <- "paraphrase-multilingual-MiniLM-L12-v2"
  attr(embs, "dimension") <- ncol(embs)
  attr(embs, "normalizacion") <- if (normalize) "L2" else "none"
  attr(embs, "fecha") <- Sys.time()

  embs
}


# ---------------------------------------------------------------------------
# Obtener embeddings para una cohorte y guardar a disco con metadatos
# ---------------------------------------------------------------------------

#' Calcular y guardar embeddings para una cohorte
#'
#' @param textos Vector de textos (uno por participante/observación)
#' @param cohorte Etiqueta de la cohorte: "principal", "piloto", o "combinado"
#' @param tiempo Etiqueta del tiempo: "t1", "t2", "t3"
#' @param output_base Directorio base de salida (default: here("data", "processed", "embeddings"))
#' @param normalize Normalizar L2 (default: TRUE)
#' @param batch_size Tamaño de lote (default: 32L)
#' @return Matriz de embeddings (invisiblemente)
obtener_embeddings_cohorte <- function(
  textos,
  cohorte = c("principal", "piloto", "combinado"),
  tiempo = c("t1", "t2", "t3"),
  output_base = here::here("data", "processed", "embeddings"),
  normalize = TRUE,
  batch_size = 32L
) {
  cohorte <- match.arg(cohorte)
  tiempo <- match.arg(tiempo)
  
  # Calcular embeddings
  embs <- obtener_embeddings(textos, normalize = normalize, batch_size = batch_size)
  
  # Extraer metadatos
  n_vacios <- attr(embs, "n_vacios")
  n_textos <- attr(embs, "n_textos")
  modelo <- attr(embs, "modelo")
  dimension <- attr(embs, "dimension")
  normalizacion <- attr(embs, "normalizacion")
  fecha <- attr(embs, "fecha")
  
  # Hash de los textos de entrada (para trazabilidad, no guardar textos)
  textos_hash <- if (requireNamespace("digest", quietly = TRUE)) {
    digest::digest(textos, algo = "md5")
  } else {
    "no-digest"
  }
  
  # Preparar directorio de salida
  dir_cohorte <- file.path(output_base, cohorte)
  dir.create(dir_cohorte, recursive = TRUE, showWarnings = FALSE)
  
  # Archivo RDS
  archivo_rds <- file.path(dir_cohorte, sprintf("embeddings_%s_%s.rds", cohorte, tiempo))
  saveRDS(embs, archivo_rds)
  
  # Archivo de metadatos TXT
  archivo_meta <- file.path(dir_cohorte, sprintf("embeddings_%s_%s_meta.txt", cohorte, tiempo))
  meta_lines <- c(
    sprintf("Modelo: %s", modelo),
    sprintf("Dimensión: %d", dimension),
    sprintf("Normalización: %s", normalizacion),
    sprintf("Cohorte: %s", cohorte),
    sprintf("Tiempo: %s", tiempo),
    sprintf("Número de filas: %d", n_textos),
    sprintf("Textos vacíos ([VACÍO]): %d", n_vacios),
    sprintf("Fecha: %s", fecha),
    sprintf("Hash textos (MD5): %s", textos_hash)
  )
  writeLines(meta_lines, archivo_meta)
  
  registrar_log(sprintf("Embeddings %s %s guardados: %d x %d (%d vacíos) → %s",
                        cohorte, tiempo, nrow(embs), ncol(embs), n_vacios, archivo_rds))
  
  invisible(embs)
}


# ---------------------------------------------------------------------------
# Calcular embeddings para las tres cohortes en una sola corrida
# ---------------------------------------------------------------------------

#' Calcular embeddings para principal, piloto y combinado
#'
#' @param datos_principal Dataframe ancho del principal (con t1_limpio, t2_limpio, t3_limpio)
#' @param datos_piloto Dataframe ancho del piloto (con t1_limpio, t2_limpio, t3_limpio)
#' @param output_base Directorio base de salida
#' @param normalize Normalizar L2
#' @param batch_size Tamaño de lote
#' @return Lista con embeddings para cada cohorte y tiempo
calcular_embeddings_todas_cohortes <- function(
  datos_principal,
  datos_piloto,
  output_base = here::here("data", "processed", "embeddings"),
  normalize = TRUE,
  batch_size = 32L
) {
  
  # Combinado: bind_rows de principal y piloto
  datos_combinado <- bind_rows(datos_principal, datos_piloto)
  
  resultado <- list()
  tiempos <- c("t1", "t2", "t3")
  col_tiempos <- c("t1_limpio", "t2_limpio", "t3_limpio")
  
  for (i in seq_along(tiempos)) {
    t <- tiempos[i]
    col <- col_tiempos[i]
    
    cat(sprintf("\n=== Embeddings para %s ===\n", t))
    
    # Principal
    textos_p <- datos_principal[[col]]
    if (!is.null(textos_p)) {
      resultado[[sprintf("principal_%s", t)]] <- obtener_embeddings_cohorte(
        textos_p, cohorte = "principal", tiempo = t,
        output_base = output_base, normalize = normalize, batch_size = batch_size
      )
    }
    
    # Piloto
    textos_pi <- datos_piloto[[col]]
    if (!is.null(textos_pi)) {
      resultado[[sprintf("piloto_%s", t)]] <- obtener_embeddings_cohorte(
        textos_pi, cohorte = "piloto", tiempo = t,
        output_base = output_base, normalize = normalize, batch_size = batch_size
      )
    }
    
    # Combinado
    textos_c <- datos_combinado[[col]]
    if (!is.null(textos_c)) {
      resultado[[sprintf("combinado_%s", t)]] <- obtener_embeddings_cohorte(
        textos_c, cohorte = "combinado", tiempo = t,
        output_base = output_base, normalize = normalize, batch_size = batch_size
      )
    }
  }
  
  cat("\n✅ Embeddings para todas las cohortes calculados y guardados.\n")
  invisible(resultado)
}

# ---------------------------------------------------------------------------
# Prototipos semánticos
# ---------------------------------------------------------------------------
prototipos_hopper <- list(
  soledad = c(
    "me siento solo y aislado de los demás",
    "no tengo compañía y me encuentro apartado",
    "siento que estoy desconectado de las personas",
    "me encuentro solo aunque haya otras personas",
    "la soledad me envuelve y no encuentro consuelo"
  ),
  espera = c(
    "estoy esperando que algo suceda",
    "siento que estoy detenido mientras espero",
    "permanezco en una situación de espera",
    "no sé cuánto tiempo tendré que esperar",
    "el tiempo se detiene y solo espero"
  ),
  incomunicacion = c(
    "no logro comunicarme con los demás",
    "siento que no me escuchan ni me entienden",
    "estoy aislado sin poder expresar lo que siento",
    "la comunicación se ha roto y no hay diálogo",
    "me siento incomunicado y fuera de lugar"
  ),
  objetos = c(
    "los objetos que me rodean me acompañan",
    "muebles y pertenencias llenan el espacio",
    "cada objeto tiene una historia y un significado",
    "el entorno físico está lleno de cosas cotidianas",
    "los objetos reflejan mi estado interior"
  ),
  emociones_negativas = c(
    "siento una profunda tristeza y desesperanza",
    "la angustia me invade y no puedo calmarme",
    "estoy abrumado por emociones negativas",
    "el miedo y la desolación me dominan",
    "la tristeza y el dolor me acompañan constantemente"
  ),
  luz_sombra = c(
    "la luz y la sombra crean un ambiente particular",
    "los contrastes de luz reflejan mis estados",
    "la penumbra me envuelve y oculta mi rostro",
    "la claridad y la oscuridad se alternan",
    "las sombras alargan mis pensamientos"
  ),
  pasividad = c(
    "estoy quieto, sin movimiento ni acción",
    "la inactividad me define en este momento",
    "permanezco pasivo, sin reacción",
    "no tengo energía para moverme ni cambiar",
    "la pasividad es mi estado habitual"
  ),
  desconexion = c(
    "siento que estoy desconectado de la realidad",
    "no logro conectar con lo que me rodea",
    "estoy alejado de las personas y del mundo",
    "la desconexión me aísla y me confunde",
    "mi mente y mi entorno están separados"
  ),
  duda = c(
    "no estoy seguro de lo que he decidido",
    "la incertidumbre me impide avanzar",
    "me pregunto si he tomado la decisión correcta",
    "la duda me paraliza y me hace reflexionar",
    "estoy lleno de interrogantes sin respuesta"
  ),
  espacio = c(
    "el espacio físico que me rodea es importante",
    "las dimensiones de la habitación me contienen",
    "el entorno espacial influye en mi estado",
    "me siento atrapado en este espacio reducido",
    "el lugar donde estoy define mi perspectiva"
  )
)

# Clínicos (10 constructos psicológicos)
prototipos_clinicos <- list(
  tristeza = c(
    "siento una gran tristeza que no se va",
    "estoy profundamente apenado y sin esperanza",
    "la tristeza me embarga y no puedo salir",
    "me invade una melancolía constante",
    "el dolor emocional es permanente"
  ),
  miedo = c(
    "siento miedo y temor por lo que pasará",
    "el miedo me paraliza y no me deja avanzar",
    "estoy aterrorizado sin razón aparente",
    "temo lo desconocido y el futuro",
    "la ansiedad y el miedo me dominan"
  ),
  ansiedad_malestar = c(
    "siento ansiedad y malestar constante",
    "la inquietud me tiene sin calma",
    "mi mente no descansa, todo me preocupa",
    "vivo en un estado de tensión permanente",
    "el malestar emocional me consume"
  ),
  esperanza = c(
    "tengo esperanza de que las cosas mejoren",
    "confío en que el futuro será mejor",
    "la esperanza me da fuerzas para seguir",
    "creo que mis deseos se cumplirán",
    "mantengo la ilusión de un cambio positivo"
  ),
  confianza = c(
    "confío en mí mismo y en los demás",
    "siento seguridad en mis capacidades",
    "tengo fe en que todo saldrá bien",
    "la confianza me permite actuar con decisión",
    "creo en la solidez de mis relaciones"
  ),
  agencia = c(
    "puedo tomar decisiones y actuar",
    "tengo control sobre mi vida",
    "soy capaz de generar cambios",
    "mi voluntad es fuerte y determinada",
    "me siento con poder para elegir"
  ),
  control = c(
    "tengo el control de lo que me sucede",
    "puedo manejar mis emociones y acciones",
    "siento que todo está bajo mi dominio",
    "soy dueño de mis decisiones y su rumbo",
    "la autorregulación me da estabilidad"
  ),
  incertidumbre = c(
    "no sé lo que va a pasar mañana",
    "el futuro es incierto y me preocupa",
    "vivo con la incertidumbre a cuestas",
    "la falta de certeza me desestabiliza",
    "no hay nada fijo ni seguro en mi vida"
  ),
  evitacion = c(
    "evito enfrentar lo que me molesta",
    "prefiero no pensar en los problemas",
    "huyo de situaciones difíciles",
    "la evitación es mi estrategia de defensa",
    "no quiero afrontar la realidad"
  ),
  afrontamiento = c(
    "busco maneras de enfrentar las dificultades",
    "afronto los problemas con determinación",
    "tengo recursos para manejar el estrés",
    "me adapto y supero los desafíos",
    "respondo activamente a las adversidades"
  )
)
# ─── Función para construir centroide de un prototipo ────────────────────────
construir_centroide <- function(frases, model = embedding_model, normalize = TRUE) {
  if (length(frases) == 0) return(NULL)
  # Obtener embeddings de las frases
  embs_frases <- obtener_embeddings(frases, normalize = normalize, batch_size = 8L)
  # Centroide = media
  centroide <- colMeans(embs_frases, na.rm = TRUE)
  if (normalize) {
    nrm <- sqrt(sum(centroide^2))
    if (nrm > 1e-12) centroide <- centroide / nrm
  }
  return(centroide)
}

# ─── Función para calcular similitud coseno (vectorizada) ────────────────────
calcular_similitud_coseno <- function(emb1, emb2) {
  # emb1 y emb2 son matrices con filas = observaciones, columnas = dimensiones
  # Asumimos que están normalizadas (norma = 1)
  if (is.null(emb1) || is.null(emb2)) return(rep(NA_real_, nrow(emb1)))
  if (nrow(emb1) == 0 || nrow(emb2) == 0) return(rep(NA_real_, nrow(emb1)))
  # Producto punto fila a fila
  sim <- rowSums(emb1 * emb2, na.rm = TRUE)
  # Por seguridad, truncar a [-1,1] por errores numéricos
  sim <- pmax(-1, pmin(1, sim))
  return(sim)
}

# ─── (Opcional) Función para calcular proximidad a todos los prototipos ──────
calcular_proximidad_prototipos <- function(emb_mat, centroides) {
  # emb_mat: matriz de embeddings (n x d)
  # centroides: lista de vectores (d) nombrados por prototipo
  # Devuelve: data.frame con una columna por prototipo (similitud coseno)
  res <- as.data.frame(matrix(NA, nrow = nrow(emb_mat), ncol = length(centroides)))
  names(res) <- names(centroides)
  for (proto in names(centroides)) {
    centroide <- centroides[[proto]]
    if (any(is.na(centroide))) {
      res[[proto]] <- NA_real_
    } else {
      sim <- as.numeric(emb_mat %*% centroide)
      res[[proto]] <- pmax(-1, pmin(1, sim))
    }
  }
  return(res)
}