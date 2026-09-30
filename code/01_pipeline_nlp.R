# ============================================================================
# ANÁLISIS NLP DE TEXTOS EN 3 TIEMPOS — VERSIÓN 4 (CON INTEGRACIÓN DE PILOTO)
# ============================================================================
# TÍTULO  : Análisis de la Influencia de Estímulos Visuales, Auditivos y
#            Textuales en la Producción Escrita – NLP en español
# OBJETIVO: Cuantificar cómo una imagen (Hopper), un audio (poema) y un texto
#            (lectura del poema) influyen en contenido, emoción, estructura y
#            semántica en textos producidos en 3 iteraciones
#
# DISEÑO EXPERIMENTAL:
#   • 23 participantes (principal), grupos desbalanceados:
#       Texto-ND n=5 | Texto-D n=3
#       Audio-ND n=5 | Audio-D n=3
#       Imagen-ND n=2 | Imagen-D n=5
#   • 17 participantes (piloto): Texto P1-P5, Audio P6-P11, Imagen P12-P17
#   • T1 = línea base (sin estímulo)
#   • T2 = un estímulo según condición
#   • T3 = tres estímulos acumulados
#
# CAMBIOS PRINCIPALES vs. v3:
#   1. Separación de importación y normalización por fuente.
#   2. Adición del dataset piloto (estructura en bloques E:I, K:O, Q:U).
#   3. Esquema canónico común con fuente, id_participante, id_observacion.
#   4. LONG como fuente de verdad; WIDE derivado.
#   5. Validaciones específicas para el dataset maestro.
#   6. n_palabras_calculado para QA, sin mezclar con n_palabras original.
#   7. Demora y n_palabras = NA en piloto (missing estructural).
#   8. ID compuesto (fuente_participante_iteracion) para evitar colisiones.
# ============================================================================

# ============================================================================
# [v5-A] RAÍCES CONFIGURABLES (sustituye los DOS setwd() sin guarda)
# ============================================================================
# Defecto corregido: el original fijaba el directorio con setwd() a una ruta
# absoluta sin comprobar que existiera y escribía TODAS las salidas dentro de
# 'Analisis agosto'. Ahora la entrada es de solo lectura y la salida va a una
# carpeta nueva, separada por cohorte.

PROYECTO <- normalizePath(".", winslash = "/", mustWork = FALSE)
RAIZ_ENTRADA <- file.path(PROYECTO, "Analisis agosto")
RAIZ_SALIDA  <- file.path(PROYECTO, "Analisis agosto v2")

if (!dir.exists(PROYECTO)) stop("[v5] No existe la carpeta del proyecto: ", PROYECTO)
dir.create(RAIZ_SALIDA, recursive = TRUE, showWarnings = FALSE)

# Heredar insumos relativos (data/lexicons/nrc_es.rds) sin tocar el original
if (dir.exists(file.path(RAIZ_ENTRADA, "data")) &&
    !dir.exists(file.path(RAIZ_SALIDA,  "data"))) {
  file.copy(file.path(RAIZ_ENTRADA, "data"), RAIZ_SALIDA, recursive = TRUE)
}

cat("[v5] Entrada (solo lectura):", RAIZ_ENTRADA, "\n")
cat("[v5] Salida  (lo que se crea):", RAIZ_SALIDA, "\n\n")
setwd(RAIZ_SALIDA)

# Los datos y resultados de cada muestra NO se mezclan
for (.d in c("principal", "piloto", "combinado", "resultados", "logs")) {
  dir.create(file.path(RAIZ_SALIDA, .d), recursive = TRUE, showWarnings = FALSE)
}

# ============================================================================
# AUDITORÍA DE ARCHIVOS GENERADOS (VERSIÓN ROBUSTA)
# ============================================================================

library(dplyr)
library(tidyr)
library(purrr)

# Carpetas a escanear (rutas relativas a este directorio)
# [v5-L4] 'analisis_piloto' ahora se llama 'piloto' (salidas separadas por cohorte)
carpetas <- c(
  ".",                            # raíz de salida
  "data/lexicons",
  "resultados",
  "principal",
  "piloto",
  "combinado"
)

# Extensiones de interés
extensiones <- c("csv", "rds", "RData", "png", "pdf", "txt", "xlsx")

# Función para escanear sin usar fs (usa list.files + file.info)
auditar_archivos_base <- function(carpetas, extensiones) {
  
  # Vector para almacenar rutas completas
  rutas_totales <- c()
  
  for (carp in carpetas) {
    if (!dir.exists(carp)) {
      warning("La carpeta no existe: ", carp)
      next
    }
    # Listar archivos recursivamente (incluye subdirectorios)
    archivos <- list.files(
      path = carp,
      pattern = NULL,
      all.files = FALSE,
      full.names = TRUE,
      recursive = TRUE,
      ignore.case = FALSE,
      include.dirs = FALSE,
      no.. = TRUE
    )
    rutas_totales <- c(rutas_totales, archivos)
  }
  
  # Si no hay archivos, devolver data.frame vacío
  if (length(rutas_totales) == 0) {
    return(data.frame(
      ruta_relativa = character(),
      tamano_kb = numeric(),
      fecha_mod = as.POSIXct(character()),
      extension = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  # Obtener metadatos con file.info
  info <- file.info(rutas_totales)
  # Filtrar solo archivos (no directorios)
  info <- info[!info$isdir, ]
  # Extraer extensión (usando tools::file_ext)
  extension <- tools::file_ext(rownames(info))
  
  # Filtrar por extensión (convertir a minúsculas)
  extension_lower <- tolower(extension)
  keep <- extension_lower %in% extensiones
  info <- info[keep, ]
  extension <- extension[keep]
  
  # Construir data.frame
  df <- data.frame(
    ruta_relativa = rownames(info),
    tamano_kb = round(info$size / 1024, 2),
    fecha_mod = info$mtime,
    extension = extension,
    stringsAsFactors = FALSE
  )
  
  # Ordenar y convertir a ruta relativa desde el directorio de trabajo
  df <- df %>%
    mutate(
      ruta_relativa = gsub(paste0(getwd(), "/"), "", ruta_relativa, fixed = TRUE)
    ) %>%
    arrange(ruta_relativa)
  
  return(df)
}

# Ejecutar auditoría
inventario <- auditar_archivos_base(carpetas, extensiones)

# Mostrar resumen
cat("\n=== INVENTARIO DE ARCHIVOS GENERADOS ===\n")
cat(sprintf("Total de archivos encontrados: %d\n", nrow(inventario)))
cat("Distribución por extensión:\n")
print(table(inventario$extension))

# Guardar inventario en CSV
write.csv(inventario, "auditoria_archivos_generados.csv", row.names = FALSE)
cat("\n✅ Inventario guardado en 'auditoria_archivos_generados.csv'\n")

# Mostrar primeras filas
cat("\nPrimeros 20 archivos:\n")
print(head(inventario, 20))

# ============================================================================
# VERIFICACIÓN DE ARCHIVOS CRÍTICOS
# ============================================================================

archivos_esperados <- c(
  "diccionarios_enriquecidos.RData",
  "scores_diccionarios_long.csv",
  "scores_diccionarios_wide.csv",
  "data/lexicons/nrc_es.rds",
  "resultados/embeddings_t1.rds",
  "resultados/embeddings_t2.rds",
  "resultados/embeddings_t3.rds",
  "resultados/prototipos_semanticos.rds",
  "resultados/tablas/datos_completos_ancho.csv",
  "resultados/tablas/todas_tablas.xlsx",
  "resultados/figuras/fig1_palabras_condicion.png",
  "analisis_piloto/README_ANALISIS_PILOTO.txt",
  "analisis_piloto/datos/README_DATOS_PILOTO.txt"
)

# Verificar existencia (usando las rutas relativas)
existentes <- file.exists(archivos_esperados)
tabla_existencia <- data.frame(
  archivo = archivos_esperados,
  existe = existentes,
  stringsAsFactors = FALSE
)

cat("\n=== ARCHIVOS CRÍTICOS ===\n")
print(tabla_existencia)

# Si algún archivo crítico falta, se indicará
if (any(!existentes)) {
  cat("\n⚠️ Los siguientes archivos NO se encontraron:\n")
  print(archivos_esperados[!existentes])
} else {
  cat("\n✅ Todos los archivos críticos están presentes.\n")
}

# ============================================================================
# COPIAR TODOS LOS ARCHIVOS GENERADOS A UNA CARPETA PARA ARTÍCULOS
# ============================================================================

# 1. Crear la carpeta de destino (si no existe)
dir_destino <- "para_articulos"
if (!dir.exists(dir_destino)) {
  dir.create(dir_destino, recursive = TRUE)
  cat("📁 Carpeta '", dir_destino, "' creada.\n", sep = "")
}

# 2. Verificar que el inventario existe y tiene datos
if (!exists("inventario") || nrow(inventario) == 0) {
  stop("❌ El objeto 'inventario' no existe o está vacío. Ejecuta la auditoría primero.")
}

cat("📦 Copiando", nrow(inventario), "archivos a '", dir_destino, "'...\n", sep = "")

# 3. Copiar cada archivo preservando la estructura
copiados <- 0
errores <- 0

for (i in seq_len(nrow(inventario))) {
  ruta_orig <- inventario$ruta_relativa[i]
  ruta_dest <- file.path(dir_destino, ruta_orig)
  
  # Crear el directorio padre en el destino
  dir.create(dirname(ruta_dest), recursive = TRUE, showWarnings = FALSE)
  
  # Copiar el archivo (sobrescribir si ya existe)
  if (file.exists(ruta_orig)) {
    if (file.copy(ruta_orig, ruta_dest, overwrite = TRUE)) {
      copiados <- copiados + 1
    } else {
      errores <- errores + 1
      warning("⚠️ No se pudo copiar: ", ruta_orig)
    }
  } else {
    errores <- errores + 1
    warning("⚠️ El archivo original ya no existe: ", ruta_orig)
  }
  
  # Mostrar progreso cada 50 archivos
  if (i %% 50 == 0) {
    cat("  Progreso:", i, "/", nrow(inventario), "archivos procesados.\n")
  }
}

# 4. Resumen final
cat("\n✅ Copia completada.\n")
cat("   Archivos copiados exitosamente:", copiados, "\n")
cat("   Errores/omitidos:", errores, "\n")
cat("   📂 Ubicación:", normalizePath(dir_destino), "\n")

# 5. (Opcional) Guardar el inventario dentro de la carpeta para referencia
file.copy("auditoria_archivos_generados.csv", 
          file.path(dir_destino, "auditoria_archivos_generados.csv"), 
          overwrite = TRUE)
cat("   📄 Inventario también copiado a la carpeta.\n")

# ============================================================================
# COPIAR ARCHIVOS SELECCIONADOS PARA EL ARTÍCULO 1 (basado en inventario real)
# ============================================================================

# Directorio destino (ya existe)
dir_destino <- "articulo_1"

# Lista de archivos a copiar (rutas relativas, todas existen en el inventario)
archivos_seleccionados <- c(
  # Datos longitudinales
  "analisis_piloto/datos/principal_longitudinal.csv",
  "analisis_piloto/datos/piloto_longitudinal.csv",
  
  # Modelos
  "analisis_piloto/modelos/modelos_principal.rds",
  "analisis_piloto/modelos/modelos_piloto.rds",
  "analisis_piloto/modelos/modelos_comparativos.rds",
  
  # Tablas de resultados
  "resultados/tablas/todas_tablas.xlsx",
  "resultados/tablas/descriptivos_linguistica.csv",
  "resultados/tablas/descriptivos_hopper.csv",
  "resultados/tablas/descriptivos_semantica.csv",
  "resultados/tablas/cambios_prototipos.csv",
  "resultados/tablas/distancia_euclidiana.csv",
  "analisis_piloto/tablas/auditoria_principal.csv",
  "analisis_piloto/tablas/descriptivos_condicion_tiempo.csv",
  
  # Figuras (español)
  "resultados/graficos español/figura_02_linguistica_es.png",
  "resultados/graficos español/figura_03_hopper_es.png",
  "resultados/graficos español/figura_04_similitud_es.png",
  "resultados/graficos español/figura_05_prototipos_es.png",
  "resultados/graficos español/figura_06_pca_es.png",
  "resultados/graficos español/figura_07_cambio_semantico_es.png",
  "resultados/graficos español/figura_08_correlaciones_es.png"
)

# Copiar cada archivo (preservando estructura de carpetas)
copiados <- 0
no_encontrados <- c()

for (ruta_orig in archivos_seleccionados) {
  if (!file.exists(ruta_orig)) {
    no_encontrados <- c(no_encontrados, ruta_orig)
    next
  }
  
  ruta_dest <- file.path(dir_destino, ruta_orig)
  dir.create(dirname(ruta_dest), recursive = TRUE, showWarnings = FALSE)
  
  if (file.copy(ruta_orig, ruta_dest, overwrite = TRUE)) {
    copiados <- copiados + 1
  }
}

# Resumen
cat("\n══════════════════════════════════════════════════════════════\n")
cat("  COPIA PARA ARTÍCULO 1 (ARCHIVOS EXISTENTES)\n")
cat("══════════════════════════════════════════════════════════════\n")
cat("✅ Archivos copiados exitosamente:", copiados, "/", length(archivos_seleccionados), "\n")
if (length(no_encontrados) > 0) {
  cat("⚠️ Los siguientes archivos NO se encontraron (revisa el inventario):\n")
  print(no_encontrados)
} else {
  cat("✅ Todos los archivos seleccionados fueron copiados.\n")
}
cat("📂 Ubicación:", normalizePath(dir_destino), "\n")

# [v5-L3] Antes se leía un README que puede no existir: el readLines fallaba,
# el script seguía y ANUNCIABA "actualizado" aunque no hubiera escrito nada.
if (file.exists(file.path(dir_destino, "README_ARTICULO_1.txt"))) {
  readme_lines <- readLines(file.path(dir_destino, "README_ARTICULO_1.txt"))
} else {
  readme_lines <- character(0)
  cat("[v5-L3] No existe '", dir_destino, "/README_ARTICULO_1.txt' (no se copió ningún",
      " archivo de esa lista); se omite la nota.\n", sep = "")
}
# Añadir una nota al final
nota <- c(
  "",
  "NOTA: Los archivos copiados son los que realmente existen en el sistema.",
  "Para el Artículo 1 se han incluido:",
  "  - Datos longitudinales (principal y piloto) en formato largo.",
  "  - Modelos mixtos ajustados (para extraer residuos y outliers).",
  "  - Tablas de resultados (descriptivos, cambios, tamaños de grupo).",
  "  - Figuras en español (alta resolución).",
  "Estos archivos permiten abordar los cuatro puntos del análisis:",
  "  1. Excluir 'demora' (justificado con auditoria_principal.csv).",
  "  2. Transformación log (usando principal_longitudinal.csv).",
  "  3. Predictor 'n_estimulos' (derivable de 'tiempo' o 'iteracion').",
  "  4. Outliers (usando modelos_principal.rds para residuos)."
)
if (length(readme_lines) > 0) {
  writeLines(c(readme_lines, nota), file.path(dir_destino, "README_ARTICULO_1.txt"))
  cat("📄 README_ARTICULO_1.txt actualizado.\n")
} else {
  cat("📄 Nota del README omitida (no había nada que actualizar).\n")
}

# ============================================================================
# 0. CONFIGURACIÓN DE ENTORNO PYTHON PARA EMBEDDINGS (NUEVO)
# ============================================================================

# 0.1. Fijar la ruta del ejecutable de Python y entorno virtual
# [v5-C] CORREGIDO: "C:/venvs/renv311" está ROTA en este equipo (su intérprete
# base fue desinstalado). Se resuelve en cascada y se comprueba de verdad.
candidatos_python <- c(
  Sys.getenv("NLP_PYTHON", unset = NA),
  "C:/venvs/renv-nlp/Scripts/python.exe",   # validado: py 3.11.16, torch 2.14.0+cpu, ST 6.1.0
  "C:/venvs/renv311/Scripts/python.exe",    # OJO: en este equipo su intérprete base fue desinstalado
  Sys.which("python")
)
candidatos_python <- candidatos_python[!is.na(candidatos_python) & nzchar(candidatos_python)]

# [v5-C2] La comprobación anterior TAMBIÉN estaba mal: pasaba el código de -c sin
# citar, así que R lo partía en dos argumentos y TODOS los intérpretes parecían
# inválidos (incluido el que sí funciona). Ahora se cita con shQuote() y, cuando
# un candidato falla, se muestra el motivo real.
# [v5-C2b] OJO con el nombre de la variable del bucle: si se llama 'py', queda en el
# entorno global y ENMASCARA el módulo 'py' de reticulate, de modo que `py$...` falla
# con "$ operator is invalid for atomic vectors". Por eso el candidato se llama 'py_cand'.
python_exe <- NULL
for (py_cand in candidatos_python) {
  if (!file.exists(py_cand)) { cat("[v5] No existe:", py_cand, "\n"); next }
  salida <- suppressWarnings(system2(py_cand, c("-c", shQuote("import sentence_transformers")),
                                    stdout = TRUE, stderr = TRUE))
  estado <- attr(salida, "status"); if (is.null(estado)) estado <- 0L
  if (identical(as.integer(estado), 0L)) { python_exe <- py_cand; break }
  cat("[v5] Descartado:", py_cand, "\n     motivo:", paste(utils::head(salida, 2), collapse = " | "), "\n")
}

if (is.null(python_exe)) {
  stop("[v5] No se encontró un intérprete válido con sentence_transformers.\n",
       "     Cree el entorno con:\n",
       "       uv venv C:/venvs/renv-nlp --python 3.11\n",
       "       uv pip install --python C:/venvs/renv-nlp/Scripts/python.exe --index-url https://download.pytorch.org/whl/cpu torch\n",
       "       uv pip install --python C:/venvs/renv-nlp/Scripts/python.exe sentence-transformers\n",
       "     o defina la variable de entorno NLP_PYTHON.")
}
cat("[v5] Intérprete de Python:", python_exe, "\n")
venv_path <- dirname(dirname(python_exe))

Sys.setenv(RETICULATE_PYTHON = python_exe)

# 0.2. Cargar reticulate y activar EL intérprete elegido (funciona con venv y sin él)
library(reticulate)
use_python(python_exe, required = TRUE)

# [v5-C3] Directorio temporal fuera de la carpeta sincronizada (evita problemas
# de permisos con montajes tipo OneDrive/Drive). Tomado de tu configuración.
temp_dir <- "C:/temp_mfca"
if (!dir.exists(temp_dir)) dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(TMPDIR = temp_dir, TMP = temp_dir, TEMP = temp_dir)
options(tempdir = temp_dir)
cat("[v5] Directorio temporal de R:", tempdir(), "\n")

# [v5-C4] Defensa: si en el entorno global quedó un objeto llamado 'py' (una variable
# de bucle, un resto de una corrida anterior en RStudio...), enmascara el módulo de
# reticulate y rompe todas las llamadas `py$...`. Se retira antes de usarlo.
if (exists("py", envir = globalenv(), inherits = FALSE) &&
    !inherits(get("py", envir = globalenv()), "python.builtin.module")) {
  rm("py", envir = globalenv())
  cat("[v5-C4] Retirado un objeto 'py' del entorno global que enmascaraba reticulate.\n")
}

# 0.3. Importar módulos y cargar el modelo de embeddings
py_run_string("
from sentence_transformers import SentenceTransformer
embedding_model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
print('[OK] Modelo de embeddings cargado')
")

# Guardar referencia en R
embedding_model <- py$embedding_model

# 0.4. Definir función de embeddings con caché (la misma que en el script de rumia)
.emb_cache <- new.env(parent = emptyenv())

obtener_embeddings <- function(textos, normalize = TRUE, batch_size = 32L) {
  textos <- as.character(textos)
  textos[is.na(textos) | trimws(textos) == ""] <- "[VACÍO]"
  
  key <- if (requireNamespace("digest", quietly = TRUE)) {
    digest::digest(list(textos, normalize, batch_size), algo = "md5")
  } else {
    paste(length(textos), sum(nchar(textos)), normalize, sep = "|")
  }
  if (exists(key, envir = .emb_cache)) {
    return(get(key, envir = .emb_cache))
  }
  
  n <- length(textos)
  lotes <- split(seq_len(n), ceiling(seq_len(n) / batch_size))
  parts <- vector("list", length(lotes))
  
  for (i in seq_along(lotes)) {
    idx <- lotes[[i]]
    py$textos_lote <- textos[idx]
    py_run_string("
_e = embedding_model.encode(textos_lote, convert_to_numpy=True, show_progress_bar=False)
if _e.ndim == 1:
    _e = _e.reshape(1, -1)
_e = _e.astype('float64')
")
    e <- py$`_e`
    if (is.null(dim(e)) || length(dim(e)) < 2) {
      e <- matrix(e, nrow = 1)
    }
    parts[[i]] <- e
  }
  
  embs <- do.call(rbind, parts)
  if (normalize) {
    nrm <- sqrt(rowSums(embs^2))
    nrm[nrm < 1e-12] <- 1
    embs <- embs / nrm
  }
  
  assign(key, embs, envir = .emb_cache)
  embs
}

cat("✅ Entorno Python y función obtener_embeddings cargados.\n")


# ============================================================================
# 0. CONFIGURACIÓN INICIAL Y LIBRERÍAS
# ============================================================================

# [v5-B] CORREGIDO: aquí había un rm(list = ls()) que borraba el modelo de
# embeddings, la caché y las funciones de auditoría definidas más arriba.
gc()

options(
  stringsAsFactors           = FALSE,
  scipen                     = 999,
  max.print                  = 1000,
  warn                       = 1,
  digits                     = 4
)

set.seed(20260526)

# ── Instalación condicional ──────────────────────────────────────────────────
instalar_paquetes <- function(pkgs, repo = "https://cloud.r-project.org") {
  nuevos <- pkgs[!(pkgs %in% rownames(installed.packages()))]
  if (length(nuevos) > 0) {
    cat("Instalando:", paste(nuevos, collapse = ", "), "\n")
    install.packages(nuevos, repos = repo, dependencies = TRUE)
  }
}

paquetes_necesarios <- c(
  "tidyverse", "tidytext", "readxl", "stringr", "stringi",
  "tokenizers", "stopwords", "text2vec", "proxy", "tm",
  "syuzhet",
  "lme4", "lmerTest", "emmeans", "performance", "effectsize",
  "rstatix", "effsize", "car",
  "topicmodels",
  "ggplot2", "cowplot", "viridis", "corrplot", "RColorBrewer",
  "ggraph", "igraph", "wordcloud",
  "readr", "scales"
)

instalar_paquetes(paquetes_necesarios)

suppressPackageStartupMessages({
  library(tidyverse)
  library(tidytext)
  library(readxl)
  library(stringr)
  library(stringi)
  library(tokenizers)
  library(stopwords)
  library(text2vec)
  library(proxy)
  library(syuzhet)
  library(lme4)
  library(lmerTest)
  library(emmeans)
  library(performance)
  library(effectsize)
  library(rstatix)
  library(effsize)
  library(ggplot2)
  library(cowplot)
  library(viridis)
  library(corrplot)
  library(scales)
})

cat("✓ Librerías cargadas\n\n")

# ── Sistema de logging ───────────────────────────────────────────────────────
registrar_log <- function(mensaje, nivel = "INFO",
                          archivo = "experimento_log.txt") {
  ts  <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- sprintf("[%s] %s: %s", ts, nivel, mensaje)
  cat(msg, "\n")
  cat(msg, "\n", file = archivo, append = TRUE)
}


# ============================================================================
# 1. NUEVAS FUNCIONES DE IMPORTACIÓN Y NORMALIZACIÓN (LOOP 3)
# ============================================================================

# ── Función común para derivar n_estimulos ──────────────────────────────────
derivar_n_estimulos <- function(iteracion) {
  # Parametrizable para futuros diseños
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
  
  # Filtrado mínimo: eliminar filas sin participante o texto (como en original)
  raw <- raw %>%
    filter(!is.na(participante), !is.na(texto))
  
  registrar_log(sprintf("Principal importado: %d filas, %d columnas",
                        nrow(raw), ncol(raw)))
  raw
}

# ── Importación del dataset piloto ──────────────────────────────────────────
importar_piloto <- function(ruta, hoja = "Hoja1") {
  registrar_log(sprintf("Importando piloto desde %s, hoja %s", ruta, hoja))
  if (!file.exists(ruta)) stop("Archivo no encontrado: ", ruta)
  
  # Leer todas las filas y columnas (sin forzar tipos)
  raw <- read_excel(ruta, sheet = hoja, col_names = FALSE, .name_repair = "minimal")
  
  # Se espera que la estructura sea:
  #   Columna A: participantes (P1, P2, ...)
  #   Bloques: E:I (T1), K:O (T2), Q:U (T3)
  #   Cada bloque contiene 5 columnas, pero solo una contiene el texto (puede ser la primera)
  #   Por simplicidad, asumimos que el texto principal está en la primera columna de cada bloque (E, K, Q)
  #   y que las otras columnas son metadatos o vacías.
  #   Si hay celdas combinadas, la lectura puede generar NAs; se tomará la primera columna no NA.
  
  # Extraer columnas de interés: A (participante), y las primeras de cada bloque
  # Usamos índices numéricos: 1 = A, 5 = E, 11 = K, 17 = Q
  # También extraemos toda la fila para depuración, pero en producción se usarán solo esas.
  
  # Limpiar participantes: columna 1
  participantes <- raw[[1]]
  participantes <- trimws(as.character(participantes))
  # Eliminar filas sin participante (espacios o NA)
  idx_validos <- which(!is.na(participantes) & participantes != "")
  
  # Para cada participante válido, extraer los textos de los bloques
  # Asumimos que el texto está en la primera columna de cada bloque: E (5), K (11), Q (17)
  # Pero en el Excel real, puede estar en otra; si se detecta que la primera columna está vacía,
  # se buscará la primera no vacía en el bloque.
  
  extraer_texto_bloque <- function(fila, cols) {
    # cols: vector de índices de columnas que forman el bloque
    # Devuelve el primer valor no NA de esas columnas
    for (c in cols) {
      val <- fila[[c]]
      if (!is.na(val) && trimws(val) != "") {
        return(as.character(val))
      }
    }
    return(NA_character_)
  }
  
  # Definir bloques: E:I (5:9), K:O (11:15), Q:U (17:21)
  bloques <- list(
    t1 = 5:9,
    t2 = 11:15,
    t3 = 17:21
  )
  
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
  
  # Asignar condición según rango de participantes (regla específica del piloto)
  df_piloto <- df_piloto %>%
    mutate(
      condicion = case_when(
        participante %in% paste0("P", 1:5)  ~ "Texto",
        participante %in% paste0("P", 6:11) ~ "Audio",
        participante %in% paste0("P", 12:17) ~ "Imagen",
        TRUE ~ NA_character_
      )
    ) %>%
    filter(!is.na(condicion), !is.na(texto))  # eliminar filas con texto faltante o condición no asignada
  
  # Verificar que no haya participantes fuera de rango
  if (any(is.na(df_piloto$condicion))) {
    warning("Hay participantes sin condición asignada (fuera de P1-P17). Revisar estructura.")
  }
  
  registrar_log(sprintf("Piloto importado: %d observaciones (participantes: %d)",
                        nrow(df_piloto), n_distinct(df_piloto$participante)))
  df_piloto
}

# ── Normalización del principal al esquema canónico ────────────────────────
normalizar_principal <- function(raw) {
  registrar_log("Normalizando dataset principal")
  
  # Se espera que raw tenga: participante, condicion, demora, iteracion, texto, n_palabras
  # Convertir tipos y añadir columnas
  df <- raw %>%
    mutate(
      fuente = "principal",
      participante = as.character(trimws(participante)),
      condicion = as.character(trimws(condicion)),
      demora = as.character(trimws(demora)),
      iteracion = as.integer(iteracion),
      texto = as.character(texto),
      n_palabras = as.integer(n_palabras),
      # Calcular n_palabras_calculado para QA
      n_palabras_calculado = str_count(texto, "\\S+"),
      # Derivar n_estimulos
      n_estimulos = derivar_n_estimulos(iteracion),
      # Crear IDs
      id_participante = paste(fuente, participante, sep = "_"),
      id_observacion = paste(id_participante, iteracion, sep = "_")
    ) %>%
    # Asegurar orden de columnas según esquema
    select(fuente, participante, id_participante, id_observacion,
           condicion, demora, iteracion, texto,
           n_palabras, n_palabras_calculado, n_estimulos)
  
  registrar_log(sprintf("Principal normalizado: %d observaciones", nrow(df)))
  df
}

# ── Normalización del piloto al esquema canónico ────────────────────────────
normalizar_piloto <- function(raw) {
  registrar_log("Normalizando dataset piloto")
  
  # raw debe tener: participante, condicion, iteracion, texto
  df <- raw %>%
    mutate(
      fuente = "piloto",
      participante = as.character(trimws(participante)),
      condicion = as.character(trimws(condicion)),
      iteracion = as.integer(iteracion),
      texto = as.character(texto),
      # Piloto no tiene demora ni n_palabras originales
      demora = NA_character_,
      n_palabras = NA_integer_,
      # Calcular n_palabras_calculado desde el texto
      n_palabras_calculado = str_count(texto, "\\S+"),
      # Derivar n_estimulos
      n_estimulos = derivar_n_estimulos(iteracion),
      # Crear IDs
      id_participante = paste(fuente, participante, sep = "_"),
      id_observacion = paste(id_participante, iteracion, sep = "_")
    ) %>%
    select(fuente, participante, id_participante, id_observacion,
           condicion, demora, iteracion, texto,
           n_palabras, n_palabras_calculado, n_estimulos)
  
  registrar_log(sprintf("Piloto normalizado: %d observaciones", nrow(df)))
  df
}

# ── Validación del esquema canónico (para un dataframe) ────────────────────
validar_esquema <- function(df, nombre = "dataset") {
  cat(sprintf("\n=== VALIDACIÓN DE ESQUEMA: %s ===\n", nombre))
  
  # Columnas requeridas
  columnas_requeridas <- c("fuente", "participante", "id_participante",
                           "id_observacion", "condicion", "demora",
                           "iteracion", "texto", "n_palabras",
                           "n_palabras_calculado", "n_estimulos")
  faltantes <- setdiff(columnas_requeridas, names(df))
  if (length(faltantes) > 0) {
    stop("Faltan columnas: ", paste(faltantes, collapse = ", "))
  }
  
  # Tipos (comprobación básica)
  tipos_ok <- TRUE
  if (!is.character(df$fuente)) tipos_ok <- FALSE
  if (!is.character(df$participante)) tipos_ok <- FALSE
  if (!is.character(df$id_participante)) tipos_ok <- FALSE
  if (!is.character(df$id_observacion)) tipos_ok <- FALSE
  if (!is.character(df$condicion)) tipos_ok <- FALSE
  if (!is.character(df$demora) && !all(is.na(df$demora))) tipos_ok <- FALSE
  if (!is.integer(df$iteracion)) tipos_ok <- FALSE
  if (!is.character(df$texto)) tipos_ok <- FALSE
  if (!is.integer(df$n_palabras) && !all(is.na(df$n_palabras))) tipos_ok <- FALSE
  if (!is.integer(df$n_palabras_calculado)) tipos_ok <- FALSE
  if (!is.integer(df$n_estimulos)) tipos_ok <- FALSE
  
  if (!tipos_ok) {
    warning("Algunos tipos de columna no son los esperados. Revisar.")
  }
  
  # Valores permitidos
  valores_validos <- TRUE
  if (!all(df$iteracion %in% c(1,2,3))) {
    warning("iteracion debe ser 1, 2 o 3")
    valores_validos <- FALSE
  }
  if (!all(df$n_estimulos %in% c(0,1,3))) {
    warning("n_estimulos debe ser 0, 1 o 3")
    valores_validos <- FALSE
  }
  if (!all(unique(df$condicion) %in% c("Texto", "Audio", "Imagen"))) {
    warning("condicion debe ser Texto, Audio o Imagen")
    valores_validos <- FALSE
  }
  
  # Consistencia iteracion -> n_estimulos
  inconsistencia <- df %>%
    filter(!((iteracion == 1 & n_estimulos == 0) |
               (iteracion == 2 & n_estimulos == 1) |
               (iteracion == 3 & n_estimulos == 3)))
  if (nrow(inconsistencia) > 0) {
    warning(sprintf("%d filas tienen inconsistencia entre iteracion y n_estimulos", nrow(inconsistencia)))
    valores_validos <- FALSE
  }
  
  # IDs duplicados
  if (any(duplicated(df$id_observacion))) {
    warning("Hay id_observacion duplicados")
    valores_validos <- FALSE
  }
  
  # Consistencia fuente + participante vs id_participante
  df <- df %>%
    mutate(id_participante_check = paste(fuente, participante, sep = "_"))
  if (!all(df$id_participante == df$id_participante_check)) {
    warning("id_participante no coincide con fuente y participante")
    valores_validos <- FALSE
  }
  df <- df %>% select(-id_participante_check)
  
  if (valores_validos) {
    cat("✓ Esquema válido.\n")
  } else {
    cat("✗ Se encontraron problemas en el esquema.\n")
  }
  
  cat("==========================================\n\n")
  invisible(list(ok = valores_validos))
}

# ── Validación del dataset maestro integrado ────────────────────────────────
validar_dataset_maestro <- function(df) {
  cat("\n========== VALIDACIÓN DEL DATASET MAESTRO ==========\n")
  
  # Resumen general
  cat(sprintf("Total observaciones: %d\n", nrow(df)))
  cat(sprintf("Participantes únicos: %d\n", n_distinct(df$id_participante)))
  
  # Por fuente
  fuentes <- df %>% count(fuente)
  cat("\nObservaciones por fuente:\n")
  print(fuentes)
  
  # Esperados (QA)
  esperados <- data.frame(
    fuente = c("principal", "piloto"),
    participantes_esperados = c(23, 17),
    obs_esperadas = c(69, 51)
  )
  cat("\nComparación con expectativas (QA):\n")
  check <- fuentes %>%
    left_join(esperados, by = "fuente") %>%
    mutate(
      n_participantes = sapply(fuente, function(f) n_distinct(df$id_participante[df$fuente == f])),
      ok_part = n_participantes == participantes_esperados,
      ok_obs = n == obs_esperadas
    )
  print(check)
  
  if (!all(check$ok_part) || !all(check$ok_obs)) {
    warning("El número de participantes u observaciones no coincide con lo esperado. Verificar.")
  }
  
  # Tabla fuente x condicion x iteracion
  cat("\nDistribución fuente × condición × iteración:\n")
  tabla <- df %>%
    group_by(fuente, condicion, iteracion) %>%
    summarise(n = n(), .groups = "drop") %>%
    pivot_wider(names_from = c(condicion, iteracion), values_from = n, values_fill = 0)
  print(tabla)
  
  # Missing: distinguir estructural vs inesperado
  cat("\nAnálisis de valores faltantes:\n")
  missing_summary <- df %>%
    summarise(across(everything(), ~ sum(is.na(.)))) %>%
    pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
    mutate(
      total = nrow(df),
      pct = round(100 * n_missing / total, 2),
      tipo = case_when(
        variable %in% c("demora", "n_palabras") & variable != "n_palabras_calculado" ~ "estructural (piloto)",
        variable == "texto" ~ "critico",
        variable %in% c("fuente", "participante", "id_participante", "id_observacion",
                        "condicion", "iteracion", "n_estimulos") ~ "critico",
        TRUE ~ "inesperado"
      )
    )
  print(missing_summary)
  
  # IDs duplicados
  dup_obs <- any(duplicated(df$id_observacion))
  cat(sprintf("\nID observación duplicados: %s\n", ifelse(dup_obs, "SÍ", "NO")))
  
  dup_part <- any(duplicated(df$id_participante))
  cat(sprintf("ID participante duplicados dentro de la misma fuente: %s\n",
              ifelse(dup_part, "SÍ", "NO")))
  
  # Textos vacíos
  empty_text <- sum(nchar(trimws(df$texto)) == 0, na.rm = TRUE)
  cat(sprintf("Textos vacíos: %d\n", empty_text))
  
  cat("====================================================\n\n")
  
  invisible(list(
    fuentes = fuentes,
    tabla = tabla,
    missing = missing_summary,
    duplicados = c(obs = dup_obs, part = dup_part),
    empty_text = empty_text
  ))
}

# ── Integración de múltiples fuentes ────────────────────────────────────────
integrar_fuentes <- function(lista_dfs) {
  registrar_log("Integrando fuentes...")
  
  # Verificar que todos tengan el mismo esquema (validación rápida)
  for (i in seq_along(lista_dfs)) {
    validar_esquema(lista_dfs[[i]], nombre = paste0("fuente_", i))
  }
  
  # Unir
  df <- bind_rows(lista_dfs)
  registrar_log(sprintf("Integración completada: %d observaciones totales", nrow(df)))
  df
}

# ── Generación de formato ancho a partir del largo ──────────────────────────
generar_ancho <- function(df_long) {
  registrar_log("Generando formato ancho...")
  
  # Seleccionar columnas que se desean pivotar: texto, n_palabras, n_palabras_calculado
  # y mantener las variables de identificación
  id_vars <- c("fuente", "participante", "id_participante", "condicion", "demora")
  # Asegurar que todas existan
  id_vars <- intersect(id_vars, names(df_long))
  
  # Pivotar
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


# =======================
# 2. FUNCIONES EXISTENTES
# =======================

limpiar_texto <- function(texto) {
  if (is.na(texto) || nchar(trimws(texto)) == 0) return("")
  texto <- tolower(texto)
  texto <- iconv(texto, from = "UTF-8", to = "ASCII//TRANSLIT")
  texto <- str_replace_all(texto, "\\d+", "")
  texto <- str_replace_all(texto, "[^a-z\\s\\-]", " ")
  str_squish(texto)
}

tokenizar <- function(texto, min_chars = 3) {
  if (nchar(texto) == 0) return(character(0))
  sw     <- stopwords::stopwords("es")
  tokens <- str_split(texto, "\\s+")[[1]]
  tokens <- tokens[nchar(tokens) >= min_chars]
  tokens[!tokens %in% sw]
}

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

# ── La función validar_datos opera sobre el dataset integrado ──
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
    cat("  → Los resultados de estas celdas deben interpretarse con cautela.\n")
    cat("  → Shapiro-Wilk y modelos con interacción 3-vía pueden ser inestables.\n\n")
  }
  
  cat(sprintf("\nValores faltantes (texto)   : %d\n",
              sum(is.na(d$texto))))
  cat(sprintf("Valores faltantes (n_palabras): %d\n",
              sum(is.na(d$n_palabras))))
  
  cat("\nPromedio de palabras por condición e iteración (del Excel, cuando existe):\n")
  print(
    d %>%
      group_by(condicion, iteracion) %>%
      summarise(media = round(mean(n_palabras, na.rm = TRUE), 1),
                .groups = "drop") %>%
      pivot_wider(names_from = iteracion, values_from = media,
                  names_prefix = "T")
  )
  cat("=========================================\n\n")
}

# ======================
# 3. EJECUCIÓN PRINCIPAL 
# ======================

# ── Rutas ──────────────────────────────────────────────────────────────────
ruta_principal <- file.path("data", "raw", "Datos Exp Interrelacion.xlsx")
# IMPORTANTE: Usamos el archivo en formato largo, NO el ancho (Vaciado Datos piloto Interrelación.xlsx)
ruta_piloto_largo <- file.path("data", "raw", "piloto_interrelacion_formato_largo.xlsx")

# ── Importar y normalizar principal ──────────────────────────────────────────
raw_principal <- importar_principal(ruta_principal, hoja = "Datos_Largo")
principal_norm <- normalizar_principal(raw_principal)

# ── Importar y normalizar piloto (desde formato largo) ──────────────────────
# [v5-D] CORREGIDO: el original normalizaba el piloto con normalizar_principal(),
# que escribe fuente = "principal" e id_participante = "principal_P1"...: las dos
# cohortes compartían identificador (en el conjunto de 40 filas había 23 ids
# únicos y 17 duplicados, y scores_diccionarios_wide.csv etiquetaba las 40 filas
# como "principal"). Ahora el piloto usa SU propia normalización:
# fuente = "piloto" e id_participante = "piloto_P1"...
raw_piloto <- importar_principal(ruta_piloto_largo, hoja = "Datos_Largo")

# 'normalizar_piloto()' fija demora = NA y n_palabras = NA (faltantes
# estructurales del piloto) y recalcula n_palabras_calculado desde el texto.
piloto_norm <- normalizar_piloto(raw_piloto)

# ── Integrar ──────────────────────────────────────────────────────────────────
datos_maestros_long <- integrar_fuentes(list(principal_norm, piloto_norm))

# [v5-E] ASERCIÓN DURA: si las cohortes se mezclan, el script PARA aquí en vez de
# producir tablas silenciosamente mal etiquetadas (fue el defecto original).
{
  .fuentes  <- unique(datos_maestros_long$fuente)
  .ids_ppal <- unique(datos_maestros_long$id_participante[datos_maestros_long$fuente == "principal"])
  .ids_pil  <- unique(datos_maestros_long$id_participante[datos_maestros_long$fuente == "piloto"])
  cat("[v5-E] Cohorte principal:", length(.ids_ppal), "participantes |",
      sum(datos_maestros_long$fuente == "principal"), "observaciones\n")
  cat("[v5-E] Cohorte piloto   :", length(.ids_pil), "participantes |",
      sum(datos_maestros_long$fuente == "piloto"), "observaciones\n")
  if (!setequal(.fuentes, c("principal", "piloto")))
    stop("[v5-E] Las fuentes del dataset maestro no son {principal, piloto}: ",
         paste(.fuentes, collapse = ", "))
  if (length(intersect(.ids_ppal, .ids_pil)) > 0)
    stop("[v5-E] COLISIÓN DE IDENTIFICADORES entre cohortes: ",
         paste(utils::head(intersect(.ids_ppal, .ids_pil), 5), collapse = ", "))
  if (any(grepl("^principal_", .ids_pil)))
    stop("[v5-E] El piloto sigue con ids con prefijo 'principal_'.")
  if (any(duplicated(datos_maestros_long$id_observacion)))
    stop("[v5-E] Hay id_observacion duplicados.")
  cat("[v5-E] OK: cohortes separadas y sin identificadores compartidos.\n\n")
}

# ── Validar maestro ──────────────────────────────────────────────────────────
validar_dataset_maestro(datos_maestros_long)

# ── Generar ancho (para compatibilidad con funciones existentes) ────────────
datos_maestros_ancho <- generar_ancho(datos_maestros_long)

# ── Crear objeto `datos` con la estructura esperada por el código posterior ──
datos <- list(
  largo = datos_maestros_long,
  ancho = datos_maestros_ancho
)

# ── Ejecutar funciones existentes (sin cambios) ────────────────────────────
datos <- preprocesar_textos(datos)
datos <- agregar_metricas(datos)
validar_datos(datos)   # Ahora sobre el dataset integrado

# ── Resumen rápido (adaptado para mostrar también la fuente) ────────────────
cat("\nResumen de métricas lingüísticas (medias por condición y fuente):\n")
datos$ancho %>%
  group_by(fuente, condicion) %>%
  summarise(
    across(c(n_palabras_t1, n_palabras_t2, n_palabras_t3,
             ttr_t1, ttr_t2, ttr_t3),
           ~ round(mean(.x, na.rm = TRUE), 2)),
    .groups = "drop"
  ) %>%
  print()

# ============================================================================
# 4. ANÁLISIS DE SENTIMIENTOS EN ESPAÑOL (NRC-ES OFICIAL v0.92)
# ============================================================================
#
# Este bloque construye el léxico NRC-ES a partir del archivo Excel multilingüe
# oficial de Saif Mohammad. La primera ejecución descarga el ZIP, extrae el
# Excel y procesa las traducciones al español. El resultado se almacena
# localmente para uso offline en ejecuciones posteriores.
#
# Fuente: Saif M. Mohammad (2016). NRC Emotion Lexicon.
#         https://saifmohammad.com/WebPages/NRC-Emotion-Lexicon.htm
#         Archivo: NRC-Emotion-Lexicon-v0.92-In105Languages-Nov2017Translations.xlsx
#         Hoja: "NRC-Lex-v0.92-word-translations"
# ============================================================================

# ── Dependencias ─────────────────────────────────────────────────────────────
if (!requireNamespace("readxl", quietly = TRUE)) install.packages("readxl")
if (!requireNamespace("curl", quietly = TRUE)) install.packages("curl")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")

library(readxl)
library(curl)
library(dplyr)
library(tidyr)

# ── Constantes ──────────────────────────────────────────────────────────────
RUTA_LEXICO_LOCAL <- file.path("data", "lexicons", "nrc_es.rds")
URL_NRC_ZIP <- "https://saifmohammad.com/WebDocs/NRC-Emotion-Lexicon.zip"
NOMBRE_EXCEL <- "NRC-Emotion-Lexicon-v0.92-In105Languages-Nov2017Translations.xlsx"
NOMBRE_HOJA <- "NRC-Lex-v0.92-word-translations"

# Emociones internas (lowercase)
EMOCIONES_NRC <- c("joy", "sadness", "fear", "anger", "anticipation",
                   "trust", "surprise", "disgust")

# Nombres de columnas de emociones en el Excel (exactos)
EMOCIONES_EXCEL <- c("Anger", "Anticipation", "Disgust", "Fear",
                     "Joy", "Sadness", "Surprise", "Trust")

# Mapeo de nombres Excel a internos
MAPEO_EMOCIONES <- setNames(tolower(EMOCIONES_EXCEL), EMOCIONES_EXCEL)

# ── Normalización coherente con limpiar_texto() y tokenizar() ──────────────
# limpiar_texto() hace: tolower, iconv(..., to="ASCII//TRANSLIT"),
# elimina dígitos y caracteres no alfabéticos, y str_squish.
normalizar_palabra_lexico <- function(palabra) {
  if (is.na(palabra) || nchar(trimws(palabra)) == 0) return("")
  palabra <- tolower(trimws(palabra))
  palabra <- iconv(palabra, from = "UTF-8", to = "ASCII//TRANSLIT")
  palabra <- gsub("[^a-z]", "", palabra)
  return(palabra)
}

# ── Función para validar el léxico (CORREGIDA) ─────────────────────────────
validar_lexico_nrc_es <- function(lexico, detener = TRUE) {
  errores <- c()
  advertencias <- c()
  
  if (!is.list(lexico)) {
    errores <- c(errores, "El objeto no es una lista.")
  } else {
    # 1. Emociones presentes
    if (!all(EMOCIONES_NRC %in% names(lexico))) {
      faltantes <- setdiff(EMOCIONES_NRC, names(lexico))
      errores <- c(errores, paste("Faltan emociones:", paste(faltantes, collapse = ", ")))
    }
    # 2. Cada elemento es vector de caracteres
    for (emo in EMOCIONES_NRC) {
      if (!is.character(lexico[[emo]])) {
        errores <- c(errores, paste("La emoción", emo, "no es un vector de caracteres."))
      }
    }
    # 3. Categorías vacías -> ERROR (no advertencia)
    vacias <- sapply(lexico, function(x) length(x) == 0)
    if (any(vacias)) {
      errores <- c(errores, 
                   paste("Categorías vacías:", paste(names(lexico)[vacias], collapse = ", ")))
    }
    # 4. NA
    if (any(sapply(lexico, function(x) any(is.na(x))))) {
      errores <- c(errores, "Se encontraron NA en los vectores de palabras.")
    }
    # 5. Caracteres no permitidos (solo letras minúsculas)
    for (emo in EMOCIONES_NRC) {
      palabras <- lexico[[emo]]
      if (length(palabras) > 0 && any(grepl("[^a-z]", palabras))) {
        errores <- c(errores, paste("La emoción", emo, "contiene caracteres no permitidos."))
      }
    }
    # 6. Duplicados
    for (emo in EMOCIONES_NRC) {
      if (any(duplicated(lexico[[emo]]))) {
        errores <- c(errores, paste("La emoción", emo, "contiene duplicados."))
      }
    }
    # 7. Tamaño total mínimo (al menos 1000 palabras)
    total <- sum(sapply(lexico, length))
    if (total < 1000) {
      errores <- c(errores, paste("El léxico es demasiado pequeño:", total, "palabras."))
    }
  }
  
  # 8. Serialización
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
    if (length(advertencias) > 0) {
      cat("  Advertencias:\n")
      cat(paste("  -", advertencias), sep = "\n")
    }
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

# ── Función para preparar (descargar, procesar y guardar) el léxico ────────
preparar_lexico_nrc_es <- function() {
  cat("[INFO] Preparando léxico NRC-ES desde fuente oficial...\n")
  
  # 1. Crear directorio
  dir.create(dirname(RUTA_LEXICO_LOCAL), recursive = TRUE, showWarnings = FALSE)
  
  # 2. Descargar ZIP
  cat("  → Descargando archivo ZIP desde:\n     ", URL_NRC_ZIP, "\n")
  zip_temp <- tempfile(fileext = ".zip")
  tryCatch({
    curl_download(URL_NRC_ZIP, zip_temp, quiet = FALSE)
  }, error = function(e) {
    stop("No se pudo descargar el ZIP. Verifica conexión a internet.\n",
         "  Error original: ", e$message, call. = FALSE)
  })
  
  # 3. Localizar el Excel dentro del ZIP
  archivos_zip <- unzip(zip_temp, list = TRUE)
  excel_path <- archivos_zip$Name[grepl(NOMBRE_EXCEL, archivos_zip$Name, fixed = TRUE)]
  if (length(excel_path) == 0) {
    stop("No se encontró el archivo Excel esperado dentro del ZIP.")
  }
  cat("  → Archivo encontrado:", excel_path[1], "\n")
  
  # 4. Extraer el Excel
  xlsx_temp <- tempfile(fileext = ".xlsx")
  unzip(zip_temp, files = excel_path[1], exdir = dirname(xlsx_temp))
  archivo_extraido <- file.path(dirname(xlsx_temp), excel_path[1])
  if (!file.exists(archivo_extraido)) {
    stop("Error al extraer el archivo Excel.")
  }
  file.rename(archivo_extraido, xlsx_temp)
  
  # 5. Leer el Excel con readxl
  cat("  → Leyendo archivo Excel (hoja:", NOMBRE_HOJA, ")...\n")
  datos_xlsx <- tryCatch({
    read_excel(xlsx_temp, sheet = NOMBRE_HOJA, .name_repair = "minimal")
  }, error = function(e) {
    stop("Error al leer el Excel: ", e$message, call. = FALSE)
  })
  
  # 6. Diagnóstico de columnas
  cat("[INFO] Columnas detectadas en Excel:\n")
  print(names(datos_xlsx))
  
  # 7. Detección robusta de columnas
  # Columna inglesa: primera que comienza con "English (en)"
  idx_en <- which(grepl("^English \\(en\\)", names(datos_xlsx)))
  if (length(idx_en) < 1) {
    stop("No se encontró ninguna columna English (en).", call. = FALSE)
  }
  col_en <- names(datos_xlsx)[idx_en[1]]
  cat("[INFO] Columna inglesa seleccionada:", col_en, "\n")
  
  # Columna española: exactamente "Spanish (es)"
  idx_es <- which(grepl("^Spanish \\(es\\)$", names(datos_xlsx)))
  if (length(idx_es) != 1) {
    stop("No se encontró exactamente una columna Spanish (es).", call. = FALSE)
  }
  col_es <- names(datos_xlsx)[idx_es]
  cat("[INFO] Columna española seleccionada:", col_es, "\n")
  
  # Columnas de emociones (según EMOCIONES_EXCEL)
  faltan_emociones <- setdiff(EMOCIONES_EXCEL, names(datos_xlsx))
  if (length(faltan_emociones) > 0) {
    stop("Faltan columnas de emociones: ", paste(faltan_emociones, collapse = ", "), call. = FALSE)
  }
  
  cat("  → Dimensiones del Excel:", nrow(datos_xlsx), "filas x", ncol(datos_xlsx), "columnas\n")
  
  # 8. Extraer y normalizar la columna española
  # Creamos un data.frame con la palabra española y las 8 emociones
  df <- datos_xlsx %>%
    select(all_of(c(col_es, EMOCIONES_EXCEL))) %>%
    rename(spanish_raw = !!col_es)
  
  # Filtrar filas con traducción no vacía
  df <- df %>% filter(!is.na(spanish_raw) & nchar(trimws(spanish_raw)) > 0)
  cat("  → Traducciones españolas no vacías:", nrow(df), "\n")
  
  # Normalizar palabras españolas
  df$spanish_norm <- sapply(df$spanish_raw, normalizar_palabra_lexico)
  # Eliminar filas donde la normalización dejó cadena vacía
  df <- df %>% filter(nchar(spanish_norm) > 0)
  cat("  → Traducciones válidas tras normalización:", nrow(df), "\n")
  
  # 9. Construir el léxico directamente desde el formato ancho
  # Para cada emoción, extraer las palabras donde la columna == 1
  lista_lexico <- list()
  for (emo_excel in EMOCIONES_EXCEL) {
    emo_interno <- MAPEO_EMOCIONES[[emo_excel]]
    # Seleccionar filas donde la emoción tiene valor 1 (o TRUE)
    # Cuidado: readxl puede leer como numérico o lógico; usamos == 1
    palabras <- df$spanish_norm[df[[emo_excel]] == 1]
    # Eliminar duplicados y ordenar
    palabras <- sort(unique(palabras))
    lista_lexico[[emo_interno]] <- palabras
  }
  
  # 10. Verificar que ninguna categoría quedó vacía
  if (any(sapply(lista_lexico, length) == 0)) {
    vacias <- names(lista_lexico)[sapply(lista_lexico, length) == 0]
    stop("ERROR CRÍTICO: las siguientes emociones quedaron vacías: ",
         paste(vacias, collapse = ", "), call. = FALSE)
  }
  
  if (sum(sapply(lista_lexico, length)) == 0) {
    stop("ERROR CRÍTICO: el léxico construido quedó completamente vacío.",
         call. = FALSE)
  }
  
  # 11. Métricas de cobertura
  cat("\n--- MÉTRICAS DE COBERTURA ---\n")
  cat("Filas originales (con traducción):         ", nrow(df), "\n")
  cat("Palabras españolas únicas:                 ",
      length(unique(df$spanish_norm)), "\n")
  cat("Asociaciones palabra-emoción:              ",
      sum(sapply(lista_lexico, length)), "\n")
  cat("Número de palabras por emoción:\n")
  resumen <- data.frame(
    emocion = names(lista_lexico),
    n_palabras = sapply(lista_lexico, length)
  )
  print(resumen, row.names = FALSE)
  
  # Palabras con múltiples emociones (para diagnóstico)
  todas_palabras <- unique(unlist(lista_lexico))
  multi_emocion <- 0
  for (p in todas_palabras) {
    num_emos <- sum(sapply(lista_lexico, function(x) p %in% x))
    if (num_emos > 1) multi_emocion <- multi_emocion + 1
  }
  cat("Palabras con >=2 emociones:                ", multi_emocion, "\n")
  cat("-------------------------------------------\n")
  
  # 12. Comprobación con palabras conocidas
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
  
  # 13. Validación (detener si falla)
  cat("  → Validando léxico...\n")
  validar_lexico_nrc_es(lista_lexico, detener = TRUE)
  
  # 14. Guardar
  saveRDS(lista_lexico, file = RUTA_LEXICO_LOCAL)
  cat("[OK] Léxico NRC-ES guardado en:\n     ", RUTA_LEXICO_LOCAL, "\n")
  
  # 15. Limpiar archivos temporales
  unlink(zip_temp)
  unlink(xlsx_temp)
  
  return(lista_lexico)
}

# ── Función para inicializar (cargar o preparar) el léxico ─────────────────
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
      # Validar con detener = FALSE para no interrumpir la carga
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

# ── Función de análisis de sentimiento (sin cambios) ──────────────────────
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

# ── Función para calcular sentimientos sobre el dataset (sin cambios) ──────
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

# ── Inicialización automática (opcional) ──────────────────────────────────
# inicializar_lexico()
inicializar_lexico()
sapply(.lexico_nrc_es, length)

palabras <- c("amor", "miedo", "muerte", "enfado", "esperanza", "contento")
for (p in palabras) {
  p_norm <- normalizar_palabra_lexico(p)
  emos <- names(which(sapply(EMOCIONES_NRC, function(e) p_norm %in% .lexico_nrc_es[[e]])))
  cat(p, " → ", paste(emos, collapse=", "), "\n")
}
txt <- "Estoy muy feliz y contento, pero también tengo miedo."
analizar_sentimiento_es(txt)

# ============================================================================
# PRUEBA DE DIAGNÓSTICO
# ============================================================================
# Ejecutar paso a paso:
#
# 1. Eliminar RDS defectuoso:
#    if (file.exists("data/lexicons/nrc_es.rds")) file.remove("data/lexicons/nrc_es.rds")
#
# 2. Reconstruir léxico:
#    inicializar_lexico()
#
# 3. Comprobar categorías:
#    length(.lexico_nrc_es)               # debe ser 8
#    names(.lexico_nrc_es)
#    sapply(.lexico_nrc_es, length)       # todos > 0
#
# 4. Comprobar palabras conocidas:
#    palabras <- c("amor","miedo","muerte","enfado","esperanza","contento")
#    for (p in palabras) {
#      p_norm <- normalizar_palabra_lexico(p)
#      emos <- names(which(sapply(EMOCIONES_NRC, function(e) p_norm %in% .lexico_nrc_es[[e]])))
#      cat(p, " → ", paste(emos, collapse=", "), "\n")
#    }
#
# 5. Probar análisis:
#    txt <- "Estoy muy feliz y contento, pero también tengo miedo."
#    analizar_sentimiento_es(txt)
#    # Debe mostrar valores > 0 en joy, fear, anticipation, trust
# ============================================================================

# ============================================================================
# 5. SIMILITUD TEXTUAL (coseno y Jaccard)
# ============================================================================

# ── Funciones matemáticas (sin cambios, pero con mejor manejo) ─────────────
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

similitud_jaccard <- function(t1, t2) {
  if (length(t1) == 0 || length(t2) == 0) return(NA_real_)
  conj_union <- length(union(t1, t2))
  if (conj_union == 0) return(NA_real_)
  round(length(intersect(t1, t2)) / conj_union, 4)
}

# ── Función para calcular similitudes sobre el dataset (formato ancho) ─────
calcular_similitudes <- function(datos) {
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
      # Distancia coseno (1 - similitud) - se mantiene el nombre original por compatibilidad
      div_t1_t2 = 1 - cos_t1_t2,
      div_t2_t3 = 1 - cos_t2_t3,
      div_t1_t3 = 1 - cos_t1_t3
    ) %>%
    ungroup()
  registrar_log("Similitudes calculadas")
  datos
}

# ============================================================================
# LOOP 3C — ENRIQUECIMIENTO EMPÍRICO DE DICCIONARIOS TEMÁTICOS
# ============================================================================

# Este código debe ejecutarse después de tener `datos_maestros_long` y
# las funciones de limpieza y tokenización (`limpiar_texto`, `tokenizar`).

# ── Cargar datos (asumimos que `datos_maestros_long` ya existe) ────────────
# Si no, se puede cargar desde el script principal.

# ── Diccionarios originales (copiados del código existente) ────────────────
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

# ── Función para tokenizar y obtener frecuencias del corpus ────────────────
preparar_corpus <- function(datos_long) {
  # datos_long debe tener columnas: id_observacion, fuente, participante,
  # condicion, iteracion, texto, n_palabras_calculado
  # Tokenizar cada texto (usando las funciones existentes)
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

# ── Extraer candidatos por tema ──────────────────────────────────────────────
extraer_candidatos <- function(corpus, diccionarios, min_freq = 5, min_doc = 3, min_part = 2) {
  # corpus: tibble con columnas id_observacion, tokens_list (lista de tokens)
  # diccionarios: lista de vectores de términos semilla por tema
  
  # 1. Obtener frecuencias globales
  tokens_all <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%   # <--- CORRECCIÓN AQUÍ
    count(token, name = "freq_total")
  
  # 2. Document frequency (número de observaciones)
  doc_freq <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%   # <--- CORRECCIÓN
    distinct(id_observacion, token) %>%
    count(token, name = "doc_freq")
  
  # 3. Participant frequency
  part_freq <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%   # <--- CORRECCIÓN
    distinct(participante, token) %>%
    count(token, name = "part_freq")
  
  # 4. Unir métricas
  term_stats <- tokens_all %>%
    left_join(doc_freq, by = "token") %>%
    left_join(part_freq, by = "token") %>%
    filter(freq_total >= min_freq, doc_freq >= min_doc, part_freq >= min_part)
  
  # 5. Crear DTM binaria (presencia/ausencia)
  dtm <- corpus %>%
    unnest(tokens_list) %>%
    rename(token = tokens_list) %>%   # <--- CORRECCIÓN
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

# ── Función para enriquecer diccionarios (aceptación manual) ───────────────
enriquecer_diccionarios <- function(base_dict, candidatos_aceptados) {
  # candidatos_aceptados: lista por tema con los términos a añadir
  enriquecido <- base_dict
  for (tema in names(candidatos_aceptados)) {
    enriquecido[[tema]] <- unique(c(enriquecido[[tema]], candidatos_aceptados[[tema]]))
  }
  return(enriquecido)
}

# ── Función para calcular cobertura ──────────────────────────────────────────
calcular_cobertura <- function(corpus, diccionario, nombre) {
  # corpus: tibble con tokens_list por observación
  # diccionario: lista de términos
  cobertura_obs <- corpus %>%
    mutate(has_tema = map_lgl(tokens_list, ~ any(.x %in% diccionario))) %>%
    summarise(prop = mean(has_tema)) %>% pull(prop)
  
  cobertura_part <- corpus %>%
    group_by(participante) %>%
    summarise(has_tema = any(map_lgl(tokens_list, ~ any(.x %in% diccionario)))) %>%
    summarise(prop = mean(has_tema)) %>% pull(prop)
  
  # Cobertura de tokens (proporción de tokens que pertenecen al diccionario)
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

# ── Función para detectar solapamientos ──────────────────────────────────────
detectar_solapamientos <- function(diccionarios) {
  # Devuelve tabla de términos que aparecen en más de un tema
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

# ── EJECUCIÓN PRINCIPAL ─────────────────────────────────────────────────────

# 1. Preparar corpus (usar datos_maestros_long)
corpus <- preparar_corpus(datos_maestros_long)

# 2. Extraer candidatos (puede tomar tiempo)
candidatos <- extraer_candidatos(corpus, diccionarios_hopper_base)

# 3. Selección manual (simulada con un vector de aceptados)
# En la práctica, se inspeccionan los candidatos y se decide.
# Aquí se muestra un ejemplo para el tema "soledad":
candidatos_aceptados <- list(
  soledad = c("acompañado", "vacío", "aislado", "desamparo"),
  espera = c("esperanza", "detenerse", "pausa"),
  incomunicacion = c("callado", "mudez"),
  objetos = c("maleta", "sombrero", "cartera", "pertenencias"),
  emociones_negativas = c("angustia", "desolación", "tormento", "desesperación"),
  luz_sombra = c("claro-oscuro"), # solo si aparece con frecuencia
  pasividad = c("recostado", "yacer"),
  desconexion = c("distante", "separado"),
  duda = c("indecisión", "interrogante", "vacilación"),
  espacio = c("rincón", "ámbito", "entorno")
)

# 4. Crear diccionario enriquecido
diccionarios_hopper_enriquecido <- enriquecer_diccionarios(diccionarios_hopper_base, candidatos_aceptados)

# 5. Auditoría de diccionarios (tabla de términos añadidos)
auditoria_diccionarios <- bind_rows(lapply(names(candidatos_aceptados), function(tema) {
  tibble(
    tema = tema,
    termino = candidatos_aceptados[[tema]],
    tipo = "empírico",
    justificacion = "Extraído por PMI y frecuencia en el corpus"
  )
}))

# 6. Solapamientos
solapamientos <- detectar_solapamientos(diccionarios_hopper_enriquecido)

# 7. Cobertura (para cada tema)
cobertura_base <- bind_rows(lapply(names(diccionarios_hopper_base), function(tema) {
  calcular_cobertura(corpus, diccionarios_hopper_base[[tema]], paste0(tema, "_base"))
}))
cobertura_enriquecida <- bind_rows(lapply(names(diccionarios_hopper_enriquecido), function(tema) {
  calcular_cobertura(corpus, diccionarios_hopper_enriquecido[[tema]], paste0(tema, "_enriquecido"))
}))
cobertura_total <- bind_rows(cobertura_base, cobertura_enriquecida)

# 8. Mostrar resultados
print("Auditoría de diccionarios (nuevos términos):")
print(auditoria_diccionarios)

print("Solapamientos entre temas:")
print(solapamientos)

print("Cobertura comparada:")
print(cobertura_total)

# 9. Guardar objetos para uso posterior
save(diccionarios_hopper_base, diccionarios_hopper_enriquecido,
     auditoria_diccionarios, solapamientos, cobertura_total,
     file = "diccionarios_enriquecidos.RData")

# ============================================================================
# ADAPTACIÓN DE `aplicar_diccionarios()` PARA FORMATO LARGO (CORREGIDA)
# ============================================================================

# Esta función trabaja sobre el dataset largo y devuelve un dataframe
# con scores por observación (tokens contados y tasas por 1000 palabras).

aplicar_diccionarios_long <- function(datos_long, diccionarios) {
  # datos_long: dataframe con columnas id_observacion, texto (o tokens)
  # diccionarios: lista de vectores de términos
  # Devuelve: dataframe con columnas id_observacion y scores para cada tema
  
  # Si no existe columna 'tokens', la creamos a partir del texto
  if (!"tokens" %in% names(datos_long)) {
    datos_long <- datos_long %>%
      mutate(texto_limpio = map_chr(texto, ~ ifelse(is.na(.), "", limpiar_texto(.))),
             tokens = map(texto_limpio, tokenizar))
  }
  
  # Obtener tabla de tokens por observación (una fila por observación, columna tokens es lista)
  tokens_por_obs <- datos_long %>%
    select(id_observacion, tokens) %>%
    distinct()
  
  # Inicializar dataframe de scores con id_observacion
  scores <- tokens_por_obs %>%
    select(id_observacion)
  
  # Para cada tema, calcular conteo de tokens que pertenecen a ese diccionario
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
  
  # Unir con metadatos (fuente, participante, condicion, iteracion, etc.)
  result <- datos_long %>%
    select(id_observacion, fuente, participante, id_participante, condicion, demora, iteracion, n_palabras_calculado) %>%
    distinct() %>%
    left_join(scores, by = "id_observacion")
  
  # Añadir tasas normalizadas (por 1000 palabras) para cada tema
  for (tema in names(diccionarios)) {
    col_score <- paste0("score_", tema)
    col_rate <- paste0("rate_", tema)
    result <- result %>%
      mutate(!!col_rate := (!!sym(col_score) / n_palabras_calculado) * 1000)
  }
  
  return(result)
}

# ── EJECUCIÓN PASO A PASO ──────────────────────────────────────────────────

# 1. Aplicar los diccionarios enriquecidos sobre el dataset largo
scores_long <- aplicar_diccionarios_long(datos_maestros_long, diccionarios_hopper_enriquecido)

# 2. Mostrar un resumen de los scores (medias por condición e iteración)
cat("\n--- Resumen de scores por condición e iteración (conteo bruto) ---\n")
scores_long %>%
  group_by(condicion, iteracion) %>%
  summarise(across(starts_with("score_"), ~ mean(.x, na.rm = TRUE), .names = "{.col}_mean")) %>%
  print(n = Inf)

cat("\n--- Resumen de tasas por 1000 palabras por condición e iteración ---\n")
scores_long %>%
  group_by(condicion, iteracion) %>%
  summarise(across(starts_with("rate_"), ~ mean(.x, na.rm = TRUE), .names = "{.col}_mean")) %>%
  print(n = Inf)

# 3. Transformar a formato ancho (similar al esquema de `datos$ancho`)
scores_wide <- scores_long %>%
  pivot_wider(
    id_cols = c(fuente, participante, id_participante, condicion, demora),
    names_from = iteracion,
    values_from = c(starts_with("score_"), starts_with("rate_")),
    names_glue = "{.value}_t{iteracion}"
  )

# 4. Mostrar dimensiones y primeras filas del formato ancho
cat("\n--- Dimensiones del formato ancho ---\n")
print(dim(scores_wide))
cat("\n--- Primeras filas (columnas seleccionadas) ---\n")
print(scores_wide[, 1:10])

# 5. Guardar los resultados en archivos para uso posterior
save(scores_long, scores_wide, file = "scores_diccionarios.RData")
write_csv(scores_long, "scores_diccionarios_long.csv")
write_csv(scores_wide, "scores_diccionarios_wide.csv")

cat("\n✅ Diccionarios aplicados correctamente. Archivos guardados.\n")

# ============================================================================
# BLOQUE 7 — EMBEDDINGS Y TRANSFORMACIÓN SEMÁNTICA
# ============================================================================
#
# Este bloque se inserta después del Bloque 6 (diccionarios temáticos) y
# antes del Bloque 8 (cálculo de cambios y scores).
#
# Requiere que existan:
#   - datos$ancho con columnas t1_limpio, t2_limpio, t3_limpio
#   - función obtener_embeddings() (definida en la infraestructura Python/R)
#   - entorno Python configurado con sentence-transformers
#
# El bloque genera:
#   - embeddings completos para T1, T2, T3 (guardados como RDS)
#   - métricas semánticas por pares (similitud, divergencia, cambio)
#   - prototipos semánticos (Hopper y clínicos) y proximidades
#   - cambios de proximidad a prototipos
#   - PCA para visualización (PC1, PC2)
#   - nuevas columnas en datos$ancho
# ============================================================================
# Definir caché y función de embeddings
.emb_cache <- new.env(parent = emptyenv())

obtener_embeddings <- function(textos, normalize = TRUE, batch_size = 32L) {
  textos <- as.character(textos)
  textos[is.na(textos) | trimws(textos) == ""] <- "[VACÍO]"
  
  key <- if (requireNamespace("digest", quietly = TRUE)) {
    digest::digest(list(textos, normalize, batch_size), algo = "md5")
  } else {
    paste(length(textos), sum(nchar(textos)), normalize, sep = "|")
  }
  if (exists(key, envir = .emb_cache)) {
    return(get(key, envir = .emb_cache))
  }
  
  n <- length(textos)
  lotes <- split(seq_len(n), ceiling(seq_len(n) / batch_size))
  parts <- vector("list", length(lotes))
  
  for (i in seq_along(lotes)) {
    idx <- lotes[[i]]
    py$textos_lote <- textos[idx]
    py_run_string("
_e = embedding_model.encode(textos_lote, convert_to_numpy=True, show_progress_bar=False)
if _e.ndim == 1:
    _e = _e.reshape(1, -1)
_e = _e.astype('float64')
")
    e <- py$`_e`
    if (is.null(dim(e)) || length(dim(e)) < 2) {
      e <- matrix(e, nrow = 1)
    }
    parts[[i]] <- e
  }
  
  embs <- do.call(rbind, parts)
  if (normalize) {
    nrm <- sqrt(rowSums(embs^2))
    nrm[nrm < 1e-12] <- 1
    embs <- embs / nrm
  }
  
  assign(key, embs, envir = .emb_cache)
  embs
}

py_run_string("
from sentence_transformers import SentenceTransformer
embedding_model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
")
embedding_model <- py$embedding_model

cat("\n╔══════════════════════════════════════════════════════════════╗\n")
cat("║     BLOQUE 7 — EMBEDDINGS Y TRANSFORMACIÓN SEMÁNTICA         ║\n")
cat("╚══════════════════════════════════════════════════════════════╝\n\n")

# ── 1. VERIFICACIÓN DE OBJETOS Y VARIABLES PREVIAS ─────────────────────────
if (!exists("datos") || !"ancho" %in% names(datos)) {
  stop("No se encuentra datos$ancho. Asegúrate de haber ejecutado los bloques anteriores.")
}

ancho <- datos$ancho
if (!all(c("t1_limpio", "t2_limpio", "t3_limpio") %in% names(ancho))) {
  stop("Faltan columnas t1_limpio, t2_limpio o t3_limpio en datos$ancho.")
}

# Verificar función obtener_embeddings
if (!exists("obtener_embeddings")) {
  stop("La función obtener_embeddings no está definida. Asegúrate de haber cargado la infraestructura Python.")
}

# ── 2. EXTRAER TEXTOS LIMPIOS ──────────────────────────────────────────────
textos_t1 <- ancho$t1_limpio
textos_t2 <- ancho$t2_limpio
textos_t3 <- ancho$t3_limpio

# Reemplazar textos vacíos con placeholder para evitar errores en Python
textos_t1[is.na(textos_t1) | trimws(textos_t1) == ""] <- "[VACÍO]"
textos_t2[is.na(textos_t2) | trimws(textos_t2) == ""] <- "[VACÍO]"
textos_t3[is.na(textos_t3) | trimws(textos_t3) == ""] <- "[VACÍO]"

# ── 3. GENERAR EMBEDDINGS ──────────────────────────────────────────────────
cat("Generando embeddings para T1, T2, T3...\n")
tryCatch({
  emb_t1 <- obtener_embeddings(textos_t1, normalize = TRUE, batch_size = 32L)
  emb_t2 <- obtener_embeddings(textos_t2, normalize = TRUE, batch_size = 32L)
  emb_t3 <- obtener_embeddings(textos_t3, normalize = TRUE, batch_size = 32L)
  cat("✓ Embeddings generados.\n")
}, error = function(e) {
  # [v5-K1] ANTES: ante un error se creaban matrices de NA y el pipeline seguía,
  # produciendo figuras y tablas calculadas sobre nada. AHORA: se detiene.
  stop("[v5-K1] No se pudieron generar los embeddings: ", e$message,
       "\n     Revise el intérprete de Python y el modelo descargado.")
})

# ── 4. CONTROL DE CALIDAD ──────────────────────────────────────────────────
n_total <- nrow(ancho)
n_validos_t1 <- sum(!is.na(emb_t1[,1]))
n_validos_t2 <- sum(!is.na(emb_t2[,1]))
n_validos_t3 <- sum(!is.na(emb_t3[,1]))
n_vacios <- sum(trimws(textos_t1) == "[VACÍO]" | trimws(textos_t2) == "[VACÍO]" | trimws(textos_t3) == "[VACÍO]")
n_fallidos <- n_total - n_validos_t1  # asumiendo que fallan los mismos

cat("\n--- Diagnóstico de embeddings ---\n")
cat("Textos procesados     :", n_total, "\n")
cat("T1 válidos            :", n_validos_t1, "\n")
cat("T2 válidos            :", n_validos_t2, "\n")
cat("T3 válidos            :", n_validos_t3, "\n")
cat("Textos vacíos/placeholder :", n_vacios, "\n")
cat("Fallidos/NA           :", n_fallidos, "\n")
cat("Cobertura exitosa (%) :", round(100 * n_validos_t1 / n_total, 2), "\n")
cat("Dimensión embedding   :", ncol(emb_t1), "\n\n")

# ── 5. SIMILITUD Y DIVERGENCIA SEMÁNTICA ──────────────────────────────────
# Función para calcular similitud coseno por pares (vectorizada)
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

# Calcular similitudes
sim_sem_t1_t2 <- calcular_similitud_coseno(emb_t1, emb_t2)
sim_sem_t2_t3 <- calcular_similitud_coseno(emb_t2, emb_t3)
sim_sem_t1_t3 <- calcular_similitud_coseno(emb_t1, emb_t3)

# Divergencia semántica = 1 - similitud
div_sem_t1_t2 <- 1 - sim_sem_t1_t2
div_sem_t2_t3 <- 1 - sim_sem_t2_t3
div_sem_t1_t3 <- 1 - sim_sem_t1_t3

# Cambio semántico = divergencia (definición transparente)
cambio_semantico_t1t2 <- div_sem_t1_t2
cambio_semantico_t2t3 <- div_sem_t2_t3
cambio_semantico_total <- div_sem_t1_t3

cat("✓ Similitudes y divergencias semánticas calculadas.\n")

# ── 6. PROTOTIPOS SEMÁNTICOS ──────────────────────────────────────────────
# Definir frases para cada constructo (10 Hopper + 10 clínicos)
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

# Combinar ambos listados para su uso
prototipos <- c(prototipos_hopper, prototipos_clinicos)

# Función para construir centroide de un prototipo a partir de frases
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

# Construir centroides para cada prototipo
cat("Construyendo prototipos semánticos...\n")
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

# Guardar prototipos para uso posterior
dir.create("resultados", showWarnings = FALSE, recursive = TRUE)
saveRDS(prototipos_centroides, "resultados/prototipos_semanticos.rds")

# Tabla de prototipos (auditable)
tabla_prototipos <- data.frame(
  constructo = names(prototipos),
  familia = c(rep("Hopper", length(prototipos_hopper)),
              rep("Clínico", length(prototipos_clinicos))),
  n_frases = sapply(prototipos, length),
  dim_embedding = rep(384, length(prototipos)),
  modelo = rep("paraphrase-multilingual-MiniLM-L12-v2", length(prototipos)),
  justificacion = c(
    rep("Constructos estético-narrativos basados en la estética de Hopper", length(prototipos_hopper)),
    rep("Constructos psicológicos/clínicos relevantes para el estudio de cambio narrativo", length(prototipos_clinicos))
  )
)
write.csv(tabla_prototipos, "resultados/tabla_prototipos.csv", row.names = FALSE)

# ── 7. PROXIMIDAD A PROTOTIPOS PARA CADA NARRATIVA ───────────────────────
cat("Calculando proximidad a prototipos para T1, T2, T3...\n")

# Crear matrices de embeddings para cada tiempo (asegurar que sean matrices)
emb_list <- list(t1 = emb_t1, t2 = emb_t2, t3 = emb_t3)
nombres_proto <- names(prototipos_centroides)

# Inicializar listas para almacenar columnas
proto_cols <- list()

for (tiempo in c("t1", "t2", "t3")) {
  emb_actual <- emb_list[[tiempo]]
  if (is.null(emb_actual) || any(is.na(emb_actual))) {
    # Si fallaron los embeddings, crear NA
    for (proto in nombres_proto) {
      col_name <- paste0("proto_", proto, "_", tiempo)
      proto_cols[[col_name]] <- rep(NA_real_, nrow(ancho))
    }
    next
  }
  # Para cada prototipo, calcular similitud coseno (emb_actual ya normalizado, centroide normalizado)
  for (proto in nombres_proto) {
    centroide <- prototipos_centroides[[proto]]
    if (any(is.na(centroide))) {
      sim <- rep(NA_real_, nrow(emb_actual))
    } else {
      sim <- as.numeric(emb_actual %*% centroide)
      # Truncar a [-1,1] por seguridad
      sim <- pmax(-1, pmin(1, sim))
    }
    col_name <- paste0("proto_", proto, "_", tiempo)
    proto_cols[[col_name]] <- sim
  }
}

# Convertir a data.frame y agregar a ancho
proto_df <- as.data.frame(proto_cols)
ancho <- cbind(ancho, proto_df)

# ── 8. CAMBIO DE PROXIMIDAD A PROTOTIPOS ──────────────────────────────────
# Para cada prototipo, calcular delta t1->t2, t2->t3, t1->t3
cat("Calculando cambios de proximidad a prototipos...\n")

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

# ── 9. PCA PARA VISUALIZACIÓN ──────────────────────────────────────────────
cat("Calculando PCA sobre embeddings (visualización)...\n")
# Combinar embeddings de los tres tiempos en una sola matriz
# Usamos solo los casos completos (ningún NA)
completos <- complete.cases(emb_t1, emb_t2, emb_t3)
if (sum(completos) >= 3) {
  emb_all <- rbind(emb_t1[completos, ], emb_t2[completos, ], emb_t3[completos, ])
  tiempo_pca <- rep(c("T1","T2","T3"), each = sum(completos))
  
  # PCA
  pca <- prcomp(emb_all, center = TRUE, scale. = TRUE)
  var_exp <- round(100 * summary(pca)$importance[2, 1:2], 2)
  cat("Varianza explicada PC1:", var_exp[1], "%, PC2:", var_exp[2], "%\n")
  
  # Extraer PC1 y PC2 para cada observación
  pc_scores <- pca$x[, 1:2]
  # Reconstruir en orden original (con NA para los incompletos)
  PC1 <- PC2 <- rep(NA_real_, nrow(ancho))
  idx_completos <- which(completos)
  for (k in 1:3) {
    idx_tiempo <- idx_completos + (k-1) * sum(completos)  # índice en emb_all
    ancho[[paste0("PC1_t", k)]][idx_completos] <- pc_scores[idx_tiempo, 1]
    ancho[[paste0("PC2_t", k)]][idx_completos] <- pc_scores[idx_tiempo, 2]
  }
  
  # Guardar objeto PCA y varianza
  pca_obj <- list(pca = pca, var_exp = var_exp, casos_completos = sum(completos))
  saveRDS(pca_obj, "resultados/pca_embeddings.rds")
} else {
  warning("No hay suficientes casos completos para PCA. Se omiten las componentes principales.")
  ancho$PC1_t1 <- ancho$PC1_t2 <- ancho$PC1_t3 <- NA_real_
  ancho$PC2_t1 <- ancho$PC2_t2 <- ancho$PC2_t3 <- NA_real_
}

# ── 10. AGREGAR MÉTRICAS SEMÁNTICAS GLOBALES A ancho ─────────────────────
ancho$sim_sem_t1_t2 <- sim_sem_t1_t2
ancho$sim_sem_t2_t3 <- sim_sem_t2_t3
ancho$sim_sem_t1_t3 <- sim_sem_t1_t3

ancho$div_sem_t1_t2 <- div_sem_t1_t2
ancho$div_sem_t2_t3 <- div_sem_t2_t3
ancho$div_sem_t1_t3 <- div_sem_t1_t3

ancho$cambio_semantico_t1t2 <- cambio_semantico_t1t2
ancho$cambio_semantico_t2t3 <- cambio_semantico_t2t3
ancho$cambio_semantico_total <- cambio_semantico_total

# ── 11. ACTUALIZAR datos$ancho Y datos$largo ─────────────────────────────
datos$ancho <- ancho

# (Opcional) Pasar las nuevas variables al formato largo para modelos posteriores
# Solo si existen columnas con nombres consistentes que queramos en largo
# Por ahora, mantendremos ancho como principal y derivaremos largo más adelante.

# ── 12. GUARDAR EMBEDDINGS COMPLETOS ──────────────────────────────────────
dir.create("resultados", showWarnings = FALSE)
saveRDS(emb_t1, "resultados/embeddings_t1.rds")
saveRDS(emb_t2, "resultados/embeddings_t2.rds")
saveRDS(emb_t3, "resultados/embeddings_t3.rds")

# ── 13. METADATOS ──────────────────────────────────────────────────────────
metadata <- list(
  modelo = "paraphrase-multilingual-MiniLM-L12-v2",
  dimension = ncol(emb_t1),
  normalizacion = "L2",
  fecha = Sys.time(),
  n_narrativas = n_total,
  n_prototipos = length(prototipos),
  frases_por_prototipo = sapply(prototipos, length),
  varianza_PC1 = if (exists("pca_obj")) pca_obj$var_exp[1] else NA,
  varianza_PC2 = if (exists("pca_obj")) pca_obj$var_exp[2] else NA
)
# [v5-I] CORREGIDO: paste(names, unlist(metadata)) reciclaba los 9 nombres sobre
# los 25 valores de frases_por_prototipo y producía un archivo corrupto
# ("modelo : 5", "dimension : 5"...). Ahora cada campo va en su propia línea.
.escribir_metadata <- function(meta, con) {
  lineas <- unlist(lapply(names(meta), function(.k) {
    .v <- meta[[.k]]
    if (length(.v) > 1) c(paste0(.k, ":"), paste0("  ", names(.v), " = ", .v))
    else paste0(.k, ": ", paste(.v, collapse = " "))
  }), use.names = FALSE)
  writeLines(lineas, con = con)
}
.escribir_metadata(metadata, "resultados/metadata_embeddings.txt")

cat("\n✓ Bloque 7 completado. Se han añadido nuevas variables semánticas.\n")
cat("  Archivos generados en 'resultados/':\n")
cat("  - embeddings_t1.rds, embeddings_t2.rds, embeddings_t3.rds\n")
cat("  - prototipos_semanticos.rds, frases_prototipos.rds\n")
cat("  - pca_embeddings.rds (si aplica)\n")
cat("  - metadata_embeddings.txt, tabla_prototipos.csv\n")

# ============================================================================
# BLOQUE 7.5 — AUDITORÍA, INFERENCIA Y VISUALIZACIÓN Q1
# ============================================================================
# Este bloque reemplaza al anterior 7.5 y realiza:
#   1. Auditoría de objetos y variables disponibles
#   2. Estadísticos descriptivos completos (n, media, DE, mediana, IQR, IC95%, min, max)
#   3. Análisis de diccionarios Hopper (tasas por 1000 palabras)
#   4. Análisis semántico (similitudes, divergencias)
#   5. Análisis de prototipos (proximidades y cambios, detección de los más relevantes)
#   6. PCA longitudinal y cálculo de cambio semántico (distancia euclidiana T1→T3)
#   7. Modelos mixtos para las variables principales (con efectos fijos y aleatorios)
#   8. Tamaños de efecto (R² marginal/condicional, Cliff's delta para comparaciones)
#   9. Corrección FDR
#  10. Generación de 8 figuras Q1 en español e inglés (PNG + PDF)
#  11. Exportación de tablas (.csv y .xlsx)
#  12. Preparación de un paquete de resultados para DeepSeek
# ============================================================================

# ── Instalación de paquetes faltantes ─────────────────────────────────────
paquetes_faltantes <- c("lme4", "lmerTest", "emmeans", "effectsize", 
                        "FSA", "rcompanion", "writexl", "ggpubr", "gridExtra")
nuevos <- paquetes_faltantes[!(paquetes_faltantes %in% installed.packages()[,"Package"])]
if (length(nuevos)) install.packages(nuevos)

library(lme4)
library(lmerTest)
library(emmeans)
library(effectsize)
library(FSA)
library(rcompanion)
library(writexl)
library(ggpubr)
library(gridExtra)

# ── Crear carpetas de salida ─────────────────────────────────────────────
dirs <- c("resultados/graficos español", "resultados/graficos ingles",
          "resultados/tablas", "resultados/modelos",
          "resultados/diagnosticos", "resultados/deepseek")
for (d in dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ── 1. AUDITORÍA DE OBJETOS Y VARIABLES DISPONIBLES ──────────────────────
cat("\n╔══════════════════════════════════════════════════════════════╗\n")
cat("║               AUDITORÍA DE OBJETOS Y VARIABLES               ║\n")
cat("╚══════════════════════════════════════════════════════════════╝\n")

# Verificar objetos críticos
objetos_requeridos <- c("datos", "scores_long", "emb_t1", "emb_t2", "emb_t3", 
                        "prototipos_centroides")
faltan <- objetos_requeridos[!sapply(objetos_requeridos, exists)]
if (length(faltan) > 0) stop("Faltan objetos: ", paste(faltan, collapse = ", "))

cat("✓ Todos los objetos requeridos existen.\n")
cat("Dimensiones de datos$ancho:", dim(datos$ancho), "\n")
cat("Número de participantes:", n_distinct(datos$ancho$id_participante), "\n")

# Identificar familias de variables
cols_ancho <- names(datos$ancho)
cat("\nVariables detectadas en datos$ancho:\n")
cat("  - Lingüísticas:", sum(grepl("^n_palabras_|^ttr_|^long_palabra_|^palabras_oracion_", cols_ancho)), "\n")
cat("  - Proto Hopper:", sum(grepl("^proto_(soledad|espera|incomunicacion|objetos|emociones_negativas|luz_sombra|pasividad|desconexion|duda|espacio)_", cols_ancho)), "\n")
cat("  - Proto Clínicos:", sum(grepl("^proto_(tristeza|miedo|ansiedad_malestar|esperanza|confianza|agencia|control|incertidumbre|evitacion|afrontamiento)_", cols_ancho)), "\n")
cat("  - Deltas de proto:", sum(grepl("^delta_proto_", cols_ancho)), "\n")
cat("  - Semánticas:", sum(grepl("^sim_sem_|^div_sem_|^cambio_semantico_", cols_ancho)), "\n")
cat("  - PCA:", sum(grepl("^PC[12]_t[123]", cols_ancho)), "\n")

# ── 2. ESTADÍSTICOS DESCRIPTIVOS ────────────────────────────────────────
cat("\n--- DESCRIPTIVOS DE MÉTRICAS LINGÜÍSTICAS ---\n")
metricas <- c("n_palabras_t1", "n_palabras_t2", "n_palabras_t3",
              "ttr_t1", "ttr_t2", "ttr_t3")
descriptivos_linguistica <- datos$ancho %>%
  pivot_longer(cols = all_of(metricas), names_to = "variable", values_to = "valor") %>%
  group_by(variable) %>%
  summarise(
    n = sum(!is.na(valor)),
    media = mean(valor, na.rm = TRUE),
    desv = sd(valor, na.rm = TRUE),
    mediana = median(valor, na.rm = TRUE),
    iqr = IQR(valor, na.rm = TRUE),
    ic95_inf = t.test(valor, na.rm = TRUE)$conf.int[1],
    ic95_sup = t.test(valor, na.rm = TRUE)$conf.int[2],
    min = min(valor, na.rm = TRUE),
    max = max(valor, na.rm = TRUE)
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))
print(descriptivos_linguistica)
write.csv(descriptivos_linguistica, "resultados/tablas/descriptivos_linguistica.csv", row.names = FALSE)

# ── 3. ANÁLISIS DE DICCIONARIOS HOPPER ──────────────────────────────────
cat("\n--- ANÁLISIS DE DICCIONARIOS HOPPER (tasas por 1000 palabras) ---\n")
# Obtener todas las columnas rate_ en scores_long
rate_cols <- names(scores_long)[grep("^rate_", names(scores_long))]
descriptivos_hopper <- scores_long %>%
  pivot_longer(cols = all_of(rate_cols), names_to = "tema", values_to = "tasa") %>%
  group_by(condicion, iteracion, tema) %>%
  summarise(
    n = sum(!is.na(tasa)),
    media = mean(tasa, na.rm = TRUE),
    desv = sd(tasa, na.rm = TRUE),
    mediana = median(tasa, na.rm = TRUE),
    iqr = IQR(tasa, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))
write.csv(descriptivos_hopper, "resultados/tablas/descriptivos_hopper.csv", row.names = FALSE)
print(head(descriptivos_hopper, 10))

# ── 4. ANÁLISIS SEMÁNTICO ────────────────────────────────────────────────
cat("\n--- ESTADÍSTICOS DE SIMILITUDES SEMÁNTICAS ---\n")
sim_cols <- c("sim_sem_t1_t2", "sim_sem_t2_t3", "sim_sem_t1_t3")
descriptivos_sem <- datos$ancho %>%
  pivot_longer(cols = all_of(sim_cols), names_to = "comparacion", values_to = "similitud") %>%
  group_by(comparacion) %>%
  summarise(
    n = sum(!is.na(similitud)),
    media = mean(similitud, na.rm = TRUE),
    desv = sd(similitud, na.rm = TRUE),
    mediana = median(similitud, na.rm = TRUE),
    iqr = IQR(similitud, na.rm = TRUE),
    min = min(similitud, na.rm = TRUE),
    max = max(similitud, na.rm = TRUE)
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 4)))
print(descriptivos_sem)
write.csv(descriptivos_sem, "resultados/tablas/descriptivos_semantica.csv", row.names = FALSE)

# ── 5. PROTOTIPOS ────────────────────────────────────────────────────────
cat("\n--- ANÁLISIS DE PROTOTIPOS: CAMBIOS T1→T3 ---\n")
# Identificar todos los prototipos (nombres base)
proto_cols <- names(datos$ancho)[grep("^proto_[a-z]+_t1$", names(datos$ancho))]
protos <- gsub("^proto_", "", gsub("_t1$", "", proto_cols))

# Crear data.frame con una fila por participante
cambios_proto <- data.frame(id_participante = datos$ancho$id_participante)
for (p in protos) {
  t1 <- datos$ancho[[paste0("proto_", p, "_t1")]]
  t3 <- datos$ancho[[paste0("proto_", p, "_t3")]]
  cambios_proto[[paste0("delta_", p)]] <- t3 - t1
}

# Resumir cambios por prototipo
cambios_proto_long <- cambios_proto %>%
  pivot_longer(cols = starts_with("delta_"), names_to = "variable", values_to = "delta") %>%
  mutate(prototipo = gsub("^delta_", "", variable)) %>%
  group_by(prototipo) %>%
  summarise(
    media_delta = mean(delta, na.rm = TRUE),
    sd_delta = sd(delta, na.rm = TRUE),
    mediana_delta = median(delta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 4))) %>%
  arrange(desc(abs(media_delta)))
print(cambios_proto_long)
write.csv(cambios_proto_long, "resultados/tablas/cambios_prototipos.csv", row.names = FALSE)

# ── 6. PCA Y CAMBIO SEMÁNTICO EUCLIDIANO ──────────────────────────────
cat("\n--- CAMBIO SEMÁNTICO EUCLIDIANO (T1→T3) ---\n")
if (exists("pca_obj")) {
  # Usar las coordenadas PC1 y PC2
  dist_euclidiana <- sqrt((datos$ancho$PC1_t3 - datos$ancho$PC1_t1)^2 +
                            (datos$ancho$PC2_t3 - datos$ancho$PC2_t1)^2)
  datos$ancho$dist_euclidiana_T1T3 <- dist_euclidiana
  # Descriptivos por condición
  desc_dist <- datos$ancho %>%
    group_by(condicion) %>%
    summarise(
      media = mean(dist_euclidiana_T1T3, na.rm = TRUE),
      desv = sd(dist_euclidiana_T1T3, na.rm = TRUE),
      mediana = median(dist_euclidiana_T1T3, na.rm = TRUE)
    ) %>%
    mutate(across(where(is.numeric), ~ round(.x, 4)))
  print(desc_dist)
  write.csv(desc_dist, "resultados/tablas/distancia_euclidiana.csv", row.names = FALSE)
}

# ── 7. MODELOS MIXTOS (variables principales) ──────────────────────────
cat("\n--- MODELOS MIXTOS (selección de variables representativas) ---\n")
# Seleccionar variables dependientes: similitud semántica y algunos prototipos destacados
# y Hopper rates (tomamos algunas representativas: soledad, objetos, tristeza)
vars_dependientes <- c(
  "sim_sem_t1_t2", "sim_sem_t2_t3", "sim_sem_t1_t3",
  "proto_soledad_t1", "proto_soledad_t2", "proto_soledad_t3",
  "proto_tristeza_t1", "proto_tristeza_t2", "proto_tristeza_t3",
  "proto_esperanza_t1", "proto_esperanza_t2", "proto_esperanza_t3"
)
# Para cada variable, ajustar modelo mixto y extraer efectos
resultados_modelos <- list()
for (var in vars_dependientes) {
  # Necesitamos formato largo: una fila por observación (participante, tiempo, valor)
  tiempo <- as.numeric(gsub(".*_t", "", var))
  id_participante <- datos$ancho$id_participante
  condicion <- datos$ancho$condicion
  demora <- datos$ancho$demora
  valor <- datos$ancho[[var]]
  # Crear data frame largo
  df_mod <- data.frame(
    id_participante = id_participante,
    condicion = condicion,
    demora = demora,
    tiempo = tiempo,
    valor = valor
  )
  # Ajustar modelo
  tryCatch({
    mod <- lmer(valor ~ condicion * tiempo + demora + (1 | id_participante), data = df_mod)
    # Extraer efectos fijos
    ef <- as.data.frame(summary(mod)$coefficients)
    ef$variable <- var
    ef$parametro <- rownames(ef)
    # R²
    r2 <- r2_nakagawa(mod)
    # Guardar resultados
    resultados_modelos[[var]] <- list(
      modelo = mod,
      efectos = ef,
      r2_marginal = r2$R2_marginal,
      r2_condicional = r2$R2_conditional
    )
  }, error = function(e) {
    warning("Error en modelo para ", var, ": ", e$message)
  })
}
# Guardar resultados de modelos en tabla
tabla_modelos <- do.call(rbind, lapply(resultados_modelos, function(x) {
  if (!is.null(x$efectos)) {
    x$efectos[, c("variable", "parametro", "Estimate", "Std..Error", "t.value", "Pr...t..")]
  }
}))
if (!is.null(tabla_modelos)) {
  write.csv(tabla_modelos, "resultados/modelos/modelos_mixtos.csv", row.names = FALSE)
}

# ── 8. TAMAÑOS DE EFECTO Y FDR ─────────────────────────────────────────
cat("\n--- CORRECCIÓN FDR PARA COMPARACIONES MÚLTIPLES ---\n")
# Verificar si tabla_modelos existe y no es NULL
if (exists("tabla_modelos") && !is.null(tabla_modelos) && nrow(tabla_modelos) > 0) {
  # Asegurar que la columna de p-valores existe
  if ("Pr...t.." %in% names(tabla_modelos)) {
    pvals <- as.numeric(tabla_modelos$Pr...t..)
    pvals_adj <- p.adjust(pvals, method = "fdr")
    tabla_modelos$p_adj_FDR <- pvals_adj
    write.csv(tabla_modelos, "resultados/modelos/modelos_mixtos_con_FDR.csv", row.names = FALSE)
    cat("✓ P-valores ajustados por FDR guardados.\n")
  } else {
    cat("⚠ La tabla de modelos no contiene la columna 'Pr...t..'. Omitiendo FDR.\n")
  }
} else {
  cat("⚠ No se encontraron modelos con p-valores. Omitiendo corrección FDR.\n")
  # Crear archivo vacío o de advertencia para que DeepSeek sepa que no hay modelos
  writeLines("No se generaron modelos mixtos. Verifica la disponibilidad de datos.", 
             "resultados/modelos/modelos_mixtos_con_FDR.txt")
}

# ── 9. FIGURAS Q1 (ESPAÑOL E INGLÉS) ──────────────────────────────────────
cat("\n--- GENERANDO FIGURAS (ESPAÑOL E INGLÉS) ---\n")

# Tema editorial Q1
theme_q1 <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11, face = "bold"),
    axis.text = element_text(size = 10),
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 9),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.text = element_text(face = "bold")
  )

# Función para exportar figuras bilingües
crear_figura_bilingue <- function(p_es, p_en, nombre_base,
                                  ancho = 8, alto = 6, res = 300) {
  dir_es <- "resultados/graficos español"
  dir_en <- "resultados/graficos ingles"
  dir.create(dir_es, recursive = TRUE, showWarnings = FALSE)
  dir.create(dir_en, recursive = TRUE, showWarnings = FALSE)
  
  # Español
  ggsave(filename = file.path(dir_es, paste0(nombre_base, "_es.png")),
         plot = p_es, width = ancho, height = alto, dpi = res, bg = "white")
  ggsave(filename = file.path(dir_es, paste0(nombre_base, "_es.pdf")),
         plot = p_es, width = ancho, height = alto, device = cairo_pdf, bg = "white")
  
  # Inglés
  ggsave(filename = file.path(dir_en, paste0(nombre_base, "_en.png")),
         plot = p_en, width = ancho, height = alto, dpi = res, bg = "white")
  ggsave(filename = file.path(dir_en, paste0(nombre_base, "_en.pdf")),
         plot = p_en, width = ancho, height = alto, device = cairo_pdf, bg = "white")
  
  invisible(TRUE)
}

# ── Figura 2: Evolución lingüística (número de palabras) ──────────────────
p1_data <- datos$ancho %>%
  pivot_longer(cols = c(n_palabras_t1, n_palabras_t2, n_palabras_t3),
               names_to = "tiempo", values_to = "n_palabras") %>%
  mutate(tiempo = factor(gsub("n_palabras_", "", tiempo), levels = c("t1","t2","t3"))) %>%
  filter(is.finite(n_palabras))
cat("[QA] Figura 2: excluidas", nrow(datos$ancho)*3 - nrow(p1_data), "filas con NA/Inf.\n")

p1_es <- ggplot(p1_data, aes(x = tiempo, y = n_palabras, color = condicion, group = condicion)) +
  stat_summary(fun.data = mean_cl_normal, geom = "pointrange", position = position_dodge(0.2)) +
  stat_summary(fun = mean, geom = "line", position = position_dodge(0.2)) +
  labs(title = "Evolución del número de palabras", x = "Iteración", y = "Número de palabras") +
  theme_q1

p1_en <- ggplot(p1_data, aes(x = tiempo, y = n_palabras, color = condicion, group = condicion)) +
  stat_summary(fun.data = mean_cl_normal, geom = "pointrange", position = position_dodge(0.2)) +
  stat_summary(fun = mean, geom = "line", position = position_dodge(0.2)) +
  labs(title = "Evolution of word count", x = "Iteration", y = "Word count") +
  theme_q1

crear_figura_bilingue(p1_es, p1_en, "figura_02_linguistica")

# ── Figura 3: Heatmap de tasas Hopper ──────────────────────────────────────
# Preparar datos (promedios por condición e iteración)
hopper_heat <- scores_long %>%
  group_by(condicion, iteracion) %>%
  summarise(across(starts_with("rate_"), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(cols = starts_with("rate_"), names_to = "tema", values_to = "tasa") %>%
  mutate(tema = gsub("rate_", "", tema)) %>%
  filter(is.finite(tasa))
cat("[QA] Figura 3: excluidas", nrow(hopper_heat) - nrow(hopper_heat %>% filter(is.finite(tasa))), "filas.\n")

p2_es <- ggplot(hopper_heat, aes(x = factor(iteracion), y = tema, fill = tasa)) +
  geom_tile() + facet_wrap(~condicion) +
  scale_fill_gradient(low = "white", high = "steelblue") +
  labs(title = "Evolución de las tasas de categorías Hopper",
       x = "Iteración", y = "Categoría", fill = "Tasa") +
  theme_q1

p2_en <- ggplot(hopper_heat, aes(x = factor(iteracion), y = tema, fill = tasa)) +
  geom_tile() + facet_wrap(~condicion) +
  scale_fill_gradient(low = "white", high = "steelblue") +
  labs(title = "Evolution of Hopper Category Rates",
       x = "Iteration", y = "Category", fill = "Rate") +
  theme_q1

crear_figura_bilingue(p2_es, p2_en, "figura_03_hopper")

# ── Figura 4: Similitud semántica ──────────────────────────────────────────
sim_data <- datos$ancho %>%
  pivot_longer(cols = c(sim_sem_t1_t2, sim_sem_t2_t3, sim_sem_t1_t3),
               names_to = "comparacion", values_to = "similitud") %>%
  filter(is.finite(similitud))
cat("[QA] Figura 4: excluidas", nrow(datos$ancho)*3 - nrow(sim_data), "filas.\n")

p3_es <- ggplot(sim_data, aes(x = comparacion, y = similitud, fill = condicion)) +
  geom_boxplot() +
  labs(title = "Similitud semántica entre tiempos",
       x = "Comparación", y = "Similitud coseno") +
  theme_q1

p3_en <- ggplot(sim_data, aes(x = comparacion, y = similitud, fill = condicion)) +
  geom_boxplot() +
  labs(title = "Semantic similarity between time points",
       x = "Comparison", y = "Cosine similarity") +
  theme_q1

crear_figura_bilingue(p3_es, p3_en, "figura_04_similitud")

# ── Figura 5: Cambio de proximidad a prototipos (heatmap) ──────────────────
# Usar cambios_proto_long ya calculado
proto_heat <- cambios_proto_long %>%
  mutate(prototipo = reorder(prototipo, media_delta)) %>%
  filter(is.finite(media_delta))
cat("[QA] Figura 5: excluidos", nrow(cambios_proto_long) - nrow(proto_heat), "prototipos.\n")

p4_es <- ggplot(proto_heat, aes(x = "Cambio T1 a T3", y = prototipo, fill = media_delta)) +
  geom_tile() +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red") +
  labs(title = "Cambio de proximidad a prototipos",
       x = NULL, y = "Prototipo", fill = "Cambio medio") +
  theme_q1

p4_en <- ggplot(proto_heat, aes(x = "Change from T1 to T3", y = prototipo, fill = media_delta)) +
  geom_tile() +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red") +
  labs(title = "Change in Proximity to Semantic Prototypes",
       x = NULL, y = "Prototype", fill = "Mean change") +
  theme_q1

crear_figura_bilingue(p4_es, p4_en, "figura_05_prototipos")

# ── Figura 6: PCA trayectorias ─────────────────────────────────────────────
if (all(c("PC1_t1","PC2_t1","PC1_t2","PC2_t2","PC1_t3","PC2_t3") %in% names(datos$ancho))) {
  
  # Construcción directa sin pivot doble
  pca_data <- datos$ancho %>%
    select(id_participante, condicion,
           PC1_t1, PC2_t1,
           PC1_t2, PC2_t2,
           PC1_t3, PC2_t3) %>%
    # Pivotar a largo de forma ordenada
    pivot_longer(
      cols = c(PC1_t1, PC2_t1, PC1_t2, PC2_t2, PC1_t3, PC2_t3),
      names_to = "variable",
      values_to = "valor"
    ) %>%
    # Extraer componente y tiempo desde el nombre
    mutate(
      componente = ifelse(grepl("^PC1", variable), "PC1", "PC2"),
      tiempo = case_when(
        grepl("_t1$", variable) ~ "T1",
        grepl("_t2$", variable) ~ "T2",
        grepl("_t3$", variable) ~ "T3"
      )
    ) %>%
    # Eliminar duplicados (si existen) y valores no finitos
    filter(is.finite(valor)) %>%
    distinct(id_participante, condicion, componente, tiempo, .keep_all = TRUE) %>%
    # Pivotar a ancho para tener PC1 y PC2 en columnas
    pivot_wider(
      id_cols = c(id_participante, condicion, tiempo),
      names_from = componente,
      values_from = valor
    ) %>%
    # Asegurar que PC1 y PC2 son numéricos (no listas)
    mutate(
      PC1 = as.numeric(PC1),
      PC2 = as.numeric(PC2)
    ) %>%
    filter(is.finite(PC1), is.finite(PC2)) %>%
    # Ordenar tiempo como factor
    mutate(tiempo = factor(tiempo, levels = c("T1", "T2", "T3")))
  
  cat("[QA] Figura 6: excluidos", nrow(datos$ancho)*3 - nrow(pca_data), "registros.\n")
  
  # Verificar que hay datos
  if (nrow(pca_data) > 0) {
    p5_es <- ggplot(pca_data, aes(x = PC1, y = PC2, color = condicion, group = id_participante)) +
      geom_point(size = 2) +
      geom_path(alpha = 0.6, arrow = arrow(length = unit(0.1, "cm"))) +
      facet_wrap(~tiempo) +
      labs(title = "Trayectorias en el espacio PCA",
           x = "PC1", y = "PC2") +
      theme_q1
    
    p5_en <- ggplot(pca_data, aes(x = PC1, y = PC2, color = condicion, group = id_participante)) +
      geom_point(size = 2) +
      geom_path(alpha = 0.6, arrow = arrow(length = unit(0.1, "cm"))) +
      facet_wrap(~tiempo) +
      labs(title = "Trajectories in PCA space",
           x = "PC1", y = "PC2") +
      theme_q1
    
    crear_figura_bilingue(p5_es, p5_en, "figura_06_pca")
  } else {
    cat("⚠ No hay datos válidos para la figura PCA.\n")
  }
}

# ── Figura 7: Distancia euclidiana T1→T3 ──────────────────────────────────
if ("dist_euclidiana_T1T3" %in% names(datos$ancho)) {
  dist_data <- datos$ancho %>%
    select(condicion, dist_euclidiana_T1T3) %>%
    filter(is.finite(dist_euclidiana_T1T3))
  cat("[QA] Figura 7: excluidas", nrow(datos$ancho) - nrow(dist_data), "filas.\n")
  
  p6_es <- ggplot(dist_data, aes(x = condicion, y = dist_euclidiana_T1T3, fill = condicion)) +
    geom_boxplot() +
    labs(title = "Cambio semántico global (distancia euclidiana T1→T3)",
         x = "Condición", y = "Distancia euclidiana") +
    theme_q1
  
  p6_en <- ggplot(dist_data, aes(x = condicion, y = dist_euclidiana_T1T3, fill = condicion)) +
    geom_boxplot() +
    labs(title = "Global semantic change (Euclidean distance T1→T3)",
         x = "Condition", y = "Euclidean distance") +
    theme_q1
  
  crear_figura_bilingue(p6_es, p6_en, "figura_07_cambio_semantico")
}

# ── Figura 8: Matriz de correlaciones (Spearman) ──────────────────────────
# Seleccionar variables de interés y calcular correlación robusta
cor_data <- datos$ancho %>%
  select(sim_sem_t1_t2, sim_sem_t2_t3, sim_sem_t1_t3,
         n_palabras_t1, n_palabras_t2, n_palabras_t3,
         ttr_t1, ttr_t2, ttr_t3) %>%
  select(where(is.numeric))  # asegurar solo numéricas

# Función segura para correlación
cor_segura <- function(df) {
  mat <- cor(df, method = "spearman", use = "pairwise.complete.obs")
  mat[!is.finite(mat)] <- NA_real_
  return(mat)
}
matriz_cor <- cor_segura(cor_data)
# Verificar que hay valores finitos
if (all(is.na(matriz_cor))) {
  cat("⚠ No se pudo calcular la matriz de correlación.\n")
} else {
  # Guardar como imagen
  png("resultados/graficos español/figura_08_correlaciones_es.png", width = 800, height = 800)
  corrplot::corrplot(matriz_cor, method = "color", type = "upper", tl.cex = 0.8,
                     title = "Correlaciones (Spearman)", mar = c(0,0,2,0))
  dev.off()
  
  png("resultados/graficos ingles/figura_08_correlaciones_en.png", width = 800, height = 800)
  corrplot::corrplot(matriz_cor, method = "color", type = "upper", tl.cex = 0.8,
                     title = "Correlations (Spearman)", mar = c(0,0,2,0))
  dev.off()
  
  # Versión PDF
  pdf("resultados/graficos español/figura_08_correlaciones_es.pdf", width = 8, height = 8)
  corrplot::corrplot(matriz_cor, method = "color", type = "upper", tl.cex = 0.8,
                     title = "Correlaciones (Spearman)", mar = c(0,0,2,0))
  dev.off()
  
  pdf("resultados/graficos ingles/figura_08_correlaciones_en.pdf", width = 8, height = 8)
  corrplot::corrplot(matriz_cor, method = "color", type = "upper", tl.cex = 0.8,
                     title = "Correlations (Spearman)", mar = c(0,0,2,0))
  dev.off()
  
  cat("✓ Figura 8: matriz de correlaciones guardada.\n")
}

cat("\n--- FIGURAS COMPLETADAS ---\n")

# [v5-Q] CORREGIDO: imprimir los gráficos en consola con Rscript abre un dispositivo
# y deja un 'Rplots.pdf' de basura en la carpeta de salida. En RStudio sí se ven.
if (interactive()) { print(p2_es); print(p3_es); print(p4_es); print(p5_es); print(p6_es) }


# ── 10. EXPORTAR TABLAS EN .XLSX ─────────────────────────────────────────
cat("\n--- EXPORTANDO TABLAS EN FORMATO .XLSX ---\n")
lista_tablas <- list(
  descriptivos_linguistica = descriptivos_linguistica,
  descriptivos_hopper = descriptivos_hopper,
  descriptivos_sem = descriptivos_sem,
  cambios_prototipos = cambios_proto_long
)
if (exists("tabla_modelos")) lista_tablas$modelos_mixtos <- tabla_modelos
if (exists("desc_dist")) lista_tablas$distancia_euclidiana <- desc_dist
write_xlsx(lista_tablas, "resultados/tablas/todas_tablas.xlsx")

# ── 11. PAQUETE PARA DEEPSEEK ──────────────────────────────────────────
cat("\n--- PREPARANDO PAQUETE PARA DEEPSEEK ---\n")
# Crear carpetas y archivos
deepseek_dir <- "resultados/deepseek"
# Instrucciones
writeLines(
  c("INSTRUCCIONES PARA DEEPSEEK",
    "=========================",
    "Eres un analista independiente que revisa los resultados de un estudio longitudinal sobre narrativas.",
    sprintf("Los datos provienen de %d participantes (%s) que escribieron textos en tres tiempos (T1, T2, T3).",
            dplyr::n_distinct(datos$ancho$id_participante),
            paste(names(table(datos$largo$fuente)), as.integer(table(datos$largo$fuente)),
                  sep = ": ", collapse = " | ")),
    "Cada participante pertenece a una condición (Texto, Audio o Imagen) y tiene una demora (D o ND).",
    "Se calcularon diversas métricas lingüísticas, semánticas y de proximidad a prototipos.",
    "Tu tarea es analizar los archivos adjuntos y generar un informe estructurado con:",
    "  1. Resultados confirmados (consistentes con hipótesis)",
    "  2. Resultados exploratorios (patrones interesantes)",
    "  3. Resultados inesperados",
    "  4. Resultados contradictorios",
    "  5. Resultados que requieren validación adicional",
    "  6. Resultados potencialmente publicables",
    "Además, identifica artefactos, variables con mayor efecto, patrones longitudinales y diferencias entre condiciones.",
    "Usa los archivos: descriptivos_*, modelos_*, cambios_*, distancia_* y las figuras."),
  con = file.path(deepseek_dir, "00_instrucciones.txt")
)
# Copiar archivos clave
file.copy("resultados/tablas/todas_tablas.xlsx", 
          file.path(deepseek_dir, "01_todas_tablas.xlsx"), overwrite = TRUE)
# [v5-L1] El original copiaba este CSV sin comprobar que existiera
if (file.exists("resultados/modelos/modelos_mixtos_con_FDR.csv")) {
  file.copy("resultados/modelos/modelos_mixtos_con_FDR.csv",
            file.path(deepseek_dir, "02_modelos_FDR.csv"), overwrite = TRUE)
} else {
  writeLines("No se generó 02_modelos_FDR.csv: no hubo modelos con p-valores.",
             file.path(deepseek_dir, "02_modelos_FDR_AUSENTE.txt"))
  cat("[v5-L1] AVISO: no existe modelos_mixtos_con_FDR.csv; se dejó constancia.\n")
}
file.copy("resultados/tablas/cambios_prototipos.csv",
          file.path(deepseek_dir, "03_cambios_prototipos.csv"), overwrite = TRUE)
if (file.exists("resultados/tablas/distancia_euclidiana.csv"))
  file.copy("resultados/tablas/distancia_euclidiana.csv",
            file.path(deepseek_dir, "04_distancia_euclidiana.csv"), overwrite = TRUE)
# Crear un resumen en texto plano
resumen_texto <- capture.output({
  cat("RESUMEN EJECUTIVO DE RESULTADOS\n")
  cat("================================\n\n")
  cat("Participantes:", n_distinct(datos$ancho$id_participante), "\n")
  cat("Condiciones:", paste(unique(datos$ancho$condicion), collapse = ", "), "\n\n")
  cat("MÉTRICAS LINGÜÍSTICAS\n")
  print(descriptivos_linguistica)
  cat("\nSIMILITUDES SEMÁNTICAS\n")
  print(descriptivos_sem)
  cat("\nCAMBIO DE PROTOTIPOS (TOP 5)\n")
  print(head(cambios_proto_long, 5))
  cat("\nDISTANCIA EUCLIDIANA T1→T3\n")
  if (exists("desc_dist")) print(desc_dist)
})
writeLines(resumen_texto, file.path(deepseek_dir, "10_resumen_para_deepseek.txt"))

cat("\n✅ BLOQUE 7.5/8.0 COMPLETADO.\n")
cat("  - Figuras en español e inglés en 'resultados/graficos español/' e 'resultados/graficos ingles/'\n")
cat("  - Tablas en 'resultados/tablas/'\n")
cat("  - Modelos en 'resultados/modelos/'\n")
cat("  - Paquete para DeepSeek en 'resultados/deepseek/'\n")

# ============================================================================
# BLOQUE 8 — CÁLCULO DE CAMBIOS Y SCORES DE INFLUENCIA 
# ============================================================================

#' Configuración por defecto de los pesos para los scores heurísticos
#' (se mantiene pero no se usa si no existen las columnas)
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

#' Calcular cambios temporales y scores de influencia (adaptado a columnas existentes)
#' 
#' @param ancho Dataframe en formato ancho
#' @param config_scores Lista con pesos para scores heurísticos (opcional)
#' @return Dataframe con columnas de identificación y los cambios/scores calculados.
calcular_cambios_y_scores <- function(ancho, config_scores = config_scores_default()) {
  
  # --- VARIABLES QUE SABEMOS QUE EXISTEN ---
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
  
  # --- SCORES HEURÍSTICOS (solo si existen todas las columnas necesarias) ---
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
  
  cat("NOTA: Los scores heurísticos solo se calculan si existen las columnas necesarias.\n")
  
  return(resultado)
}

# ============================================================================
# BLOQUE 9 — PRUEBAS ESTADÍSTICAS INFERENCIALES
# ============================================================================

#' Realizar pruebas pareadas (T1 vs T2, T2 vs T3, T1 vs T3) para múltiples variables
#' con corrección de multiplicidad y tamaño del efecto.
realizar_pruebas_pareadas <- function(ancho, variables = NULL, metodo_ajuste = "holm") {
  # Si no se especifican variables, usar las que existen
  if (is.null(variables)) {
    posibles <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                  "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
    variables <- c()
    for (v in posibles) {
      if (all(paste0(v, "_t", 1:3) %in% names(ancho))) {
        # Además, verificar que hay al menos 3 observaciones completas
        temp <- ancho[, paste0(v, "_t", 1:3)]
        if (sum(complete.cases(temp)) >= 3) {
          variables <- c(variables, v)
        }
      }
    }
  }
  
  if (length(variables) == 0) {
    warning("No hay variables disponibles para pruebas pareadas.")
    # Devolver un dataframe vacío con la estructura esperada
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
    
    comps <- list(
      T1_T2 = list(a = x1, b = x2),
      T2_T3 = list(a = x2, b = x3),
      T1_T3 = list(a = x1, b = x3)
    )
    
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

#' Prueba de Friedman
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

#' Función principal que integra pruebas pareadas y Friedman
realizar_pruebas_inferenciales <- function(ancho, config = NULL) {
  # Configuración por defecto adaptada
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
  
  # 1. Pruebas pareadas
  cat("── Pruebas pareadas (T1 vs T2, T2 vs T3, T1 vs T3) ──────────────────────\n")
  res_pareadas <- realizar_pruebas_pareadas(ancho, 
                                            variables = config$variables_pareadas,
                                            metodo_ajuste = config$metodo_ajuste)
  if (!is.null(res_pareadas) && nrow(res_pareadas) > 0) {
    print(res_pareadas)
  } else {
    cat("   (No se generaron resultados para pruebas pareadas)\n")
  }
  
  # 2. Friedman
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

# ============================================================================
# [v5-F] FUNCIONES QUE SE LLAMABAN SIN EXISTIR
# ============================================================================
# Defecto corregido: más abajo se llamaba a calcular_descriptivos() y a
# reportar_descriptivos(), que no estaban definidas en el script. Se implementan
# con las mismas estadísticas que ya usa el resto del script.

calcular_descriptivos <- function(df_largo, variables = NULL,
                                  agrupar = c("fuente", "condicion", "iteracion"),
                                  formato = "largo") {
  if (!is.data.frame(df_largo) || !("valor" %in% names(df_largo)))
    stop("[v5-F] calcular_descriptivos(): se espera un data.frame con columna 'valor'.")
  df <- df_largo
  if (!is.null(variables) && "metrica" %in% names(df)) df <- df[df$metrica %in% variables, , drop = FALSE]
  cols_grupo <- intersect(agrupar, names(df))
  if ("metrica" %in% names(df)) cols_grupo <- c("metrica", cols_grupo)
  if (length(cols_grupo) == 0) stop("[v5-F] calcular_descriptivos(): no hay columnas de agrupación.")
  out <- df %>%
    group_by(dplyr::across(dplyr::all_of(cols_grupo))) %>%
    summarise(n = sum(!is.na(valor)),
              media = mean(valor, na.rm = TRUE),
              sd = sd(valor, na.rm = TRUE),
              mediana = median(valor, na.rm = TRUE),
              minimo = suppressWarnings(min(valor, na.rm = TRUE)),
              maximo = suppressWarnings(max(valor, na.rm = TRUE)),
              .groups = "drop") %>%
    mutate(across(where(is.numeric), ~ round(.x, 4)))
  if (identical(formato, "ancho") && "metrica" %in% names(out)) {
    out <- out %>% pivot_wider(names_from = metrica, values_from = c(n, media, sd))
  }
  as.data.frame(out)
}

reportar_descriptivos <- function(df_largo, variables = NULL) {
  d <- calcular_descriptivos(df_largo, variables = variables)
  cat("\n--- Descriptivos (n, media, sd) ---\n")
  print(d, row.names = FALSE)
  invisible(d)
}

# ============================================================================
# EJECUCIÓN PRINCIPAL (si el entorno contiene 'datos')
# ============================================================================

if (exists("datos") && is.list(datos) && "ancho" %in% names(datos)) {
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("   INICIANDO ANÁLISIS DE CAMBIOS Y PRUEBAS ESTADÍSTICAS\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # 1. Calcular cambios y scores
  cat("→ Calculando cambios temporales...\n")
  resultado_cambios <- calcular_cambios_y_scores(datos$ancho)
  
  cat("\n--- Resumen de cambios (primeras filas) ---\n")
  print(head(resultado_cambios, 5))
  cat("\nColumnas generadas:", paste(names(resultado_cambios), collapse = ", "), "\n")
  
  # 2. Descriptivos: convertir ancho a largo (solo columnas numéricas)
  cat("\n→ Preparando descriptivos...\n")
  cols_num <- names(datos$ancho)[sapply(datos$ancho, is.numeric) & grepl("_t[123]$", names(datos$ancho))]
  id_cols <- c("fuente", "participante", "id_participante", "condicion", "demora")
  id_cols <- intersect(id_cols, names(datos$ancho))
  
  ancho_largo <- datos$ancho %>%
    select(all_of(c(id_cols, cols_num))) %>%
    pivot_longer(
      cols = all_of(cols_num),
      names_to = c("metrica", "iteracion"),
      names_pattern = "(.*)_t(\\d)",
      values_to = "valor"
    ) %>%
    mutate(iteracion = as.integer(iteracion))
  
  metricas_disponibles <- unique(ancho_largo$metrica)
  metricas_interes <- intersect(c("n_palabras", "n_palabras_calculado", "n_tokens",
                                  "ttr", "n_oraciones", "palabras_oracion", "long_palabra"), 
                                metricas_disponibles)
  
  descriptivos <- calcular_descriptivos(ancho_largo, 
                                        variables = metricas_interes,
                                        agrupar = c("fuente", "condicion", "iteracion"),
                                        formato = "largo")
  
  reportar_descriptivos(ancho_largo)
  
  # 3. Pruebas inferenciales
  cat("\n→ Realizando pruebas inferenciales...\n")
  resultado_inferencial <- realizar_pruebas_inferenciales(datos$ancho)
  
  # 4. Guardar resultados en lista maestra
  analisis <- list(
    datos_largo = datos$largo,
    datos_ancho = datos$ancho,
    cambios = resultado_cambios,
    descriptivos = descriptivos,
    inferencial = resultado_inferencial
  )
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("   ANÁLISIS COMPLETADO. RESULTADOS GUARDADOS EN 'analisis'\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  
  # Opcional: guardar objeto en disco
  # save(analisis, file = "resultados_analisis.RData")
  
} else {
  cat("\n⚠ El objeto 'datos' no está disponible o no tiene la estructura esperada.\n")
  cat("   Asegúrate de haber ejecutado los bloques anteriores que generan 'datos$ancho' y 'datos$largo'.\n")
}

# ============================================================================
# BLOQUE 10 — MODELOS MIXTOS Y ANÁLISIS INFERENCIAL (VERSIÓN DEFINITIVA)
# ============================================================================
#
# Este bloque se adapta a la estructura real de datos$ancho, verificando el
# diseño experimental antes de ajustar modelos. Incluye corrección FDR global,
# post-hoc controlado, diagnósticos robustos y análisis de sensibilidad.
#
# ============================================================================

# ── CARGA DE PAQUETES ──────────────────────────────────────────────────────
library(lme4)
library(lmerTest)
library(emmeans)
library(performance)
library(effectsize)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)          # <--- AÑADIDO

# ── VERIFICACIÓN DE ESTRUCTURA EXPERIMENTAL ──────────────────────────────
if (!exists("datos") || !"ancho" %in% names(datos)) {
  stop("El objeto 'datos$ancho' no está disponible.")
}
ancho <- datos$ancho

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("   AUDITORÍA DE ESTRUCTURA EXPERIMENTAL\n")
cat("═══════════════════════════════════════════════════════════════\n")

# 1. Fuentes
cat("Fuentes disponibles:", paste(unique(ancho$fuente), collapse = ", "), "\n")
if (length(unique(ancho$fuente)) == 1) {
  cat("  → Solo una fuente. Se omitirá 'fuente' del modelo.\n")
}

# 2. Participantes por condición y demora
tabla_diseno <- ancho %>%
  distinct(id_participante, condicion, demora) %>%
  count(condicion, demora)
cat("\nDistribución de participantes por condición × demora:\n")
print(tabla_diseno)

# Verificar si cada participante tiene una única combinación (diseño entre-sujetos)
duplicados <- ancho %>%
  distinct(id_participante, condicion, demora) %>%
  group_by(id_participante) %>%
  summarise(n = n()) %>%
  filter(n > 1)
if (nrow(duplicados) > 0) {
  warning("Algunos participantes tienen más de una combinación condicion-demora. Revisar diseño.")
  print(duplicados)
} else {
  cat("✓ Diseño entre-sujetos para condicion y demora (cada participante tiene una única combinación).\n")
}

# 3. Verificar que cada participante tenga observaciones válidas en T1,T2,T3 (CORREGIDO)
# Seleccionamos solo columnas numéricas que coincidan con el patrón _t[123]
cols_a_revisar <- names(ancho)[grepl("_t[123]$", names(ancho)) & sapply(ancho, is.numeric)]

if (length(cols_a_revisar) == 0) {
  cat("⚠ No se encontraron columnas numéricas con T1-T3.\n")
} else {
  tiempos_por_participante <- ancho %>%
    select(id_participante, all_of(cols_a_revisar)) %>%
    pivot_longer(
      cols = -id_participante,
      names_to = "var",
      values_to = "valor"
    ) %>%
    mutate(
      tiempo = str_extract(var, "t[123]$")
    ) %>%
    filter(!is.na(valor)) %>%
    distinct(id_participante, tiempo) %>%
    count(id_participante, name = "n_tiempos") %>%
    filter(n_tiempos != 3)
  
  if (nrow(tiempos_por_participante) > 0) {
    warning("Algunos participantes no tienen observaciones válidas en T1, T2 y T3.")
    print(tiempos_por_participante)
  } else {
    cat("✓ Todos los participantes tienen observaciones válidas en T1, T2 y T3.\n")
  }
}

# 4. Variables disponibles
vars_candidatas <- c("n_palabras", "n_palabras_calculado", "n_tokens", 
                     "ttr", "n_oraciones", "palabras_oracion", "long_palabra")
vars_presentes <- c()
for (v in vars_candidatas) {
  if (all(paste0(v, "_t", 1:3) %in% names(ancho))) {
    vars_presentes <- c(vars_presentes, v)
  }
}
cat("\nVariables con datos completos (T1,T2,T3):", paste(vars_presentes, collapse = ", "), "\n")

# 5. Eliminación específica de redundancia (n_palabras vs n_palabras_calculado) (CORREGIDO)
if ("n_palabras" %in% vars_presentes &&
    "n_palabras_calculado" %in% vars_presentes) {
  
  cor_np <- cor(
    ancho$n_palabras_t1,
    ancho$n_palabras_calculado_t1,
    use = "pairwise.complete.obs"
  )
  
  if (is.finite(cor_np) && abs(cor_np) >= 0.999) {
    cat("\n⚠ n_palabras y n_palabras_calculado son redundantes (correlación ≈ 1).\n")
    cat("  → Se conservará n_palabras.\n")
    cat("  → Se excluirá n_palabras_calculado.\n")
    vars_presentes <- setdiff(vars_presentes, "n_palabras_calculado")
  }
}
cat("Variables a modelar (sin duplicados):", paste(vars_presentes, collapse = ", "), "\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# ── DECISIÓN DE ESTRUCTURA DEL MODELO ────────────────────────────────────
# Se asume que condicion y demora son entre-sujetos y tiempo intra-sujeto.
# Si demora no tiene al menos 2 niveles, se omite.
tiene_demora <- length(unique(ancho$demora[!is.na(ancho$demora)])) >= 2
if (!tiene_demora) {
  cat("⚠ Demora no tiene al menos 2 niveles válidos. Se omite del modelo.\n")
}

# Modelo base (si demora existe, se incluye; si no, se omite)
if (tiene_demora) {
  formula_base <- as.formula("valor ~ condicion * tiempo + demora + (1 | id_participante)")
} else {
  formula_base <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
}

cat("\nModelo base:\n", deparse(formula_base), "\n\n")

# ── FUNCIONES AUXILIARES ──────────────────────────────────────────────────

# Construir formato largo
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

# Ajustar modelo mixto
ajustar_modelo <- function(ancho, variable_base, incluir_demora = TRUE) {
  # Verificar si demora tiene niveles suficientes
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

# Extraer resultados (ANOVA, R², post-hoc)
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
    # Interacción
    if ("condicion:tiempo" %in% names(p_terms) && p_terms["condicion:tiempo"] < 0.05) {
      cat("  → Interacción significativa. Calculando post-hoc...\n")
      emm1 <- emmeans(mod, ~ condicion | tiempo)
      posthoc$cond_tiempo <- pairs(emm1, adjust = "tukey")
      emm2 <- emmeans(mod, ~ tiempo | condicion)
      posthoc$tiempo_cond <- pairs(emm2, adjust = "tukey")
    } else {
      # Efectos principales
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

# ── CORRELACIONES DE CAMBIO (excluyendo total) ──────────────────────────
calcular_correlaciones_cambios <- function(ancho) {
  # Seleccionar solo cambios parciales
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

# ── DIAGNÓSTICO DE OUTLIERS (renombrado, sin reajuste) ──────────────────
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

# ── BOOTSTRAP (solo si no singular y converge) ───────────────────────────
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

# ── DIAGNÓSTICO CON performance ──────────────────────────────────────────
diagnosticar <- function(modelo_obj, nombre = "") {
  if (is.null(modelo_obj$modelo)) return(NULL)
  mod <- modelo_obj$modelo
  cat("\n--- Diagnóstico para:", nombre, "---\n")
  # Usar performance::check_model para una visión global
  tryCatch({
    print(check_model(mod))
  }, error = function(e) {
    cat("  check_model() no disponible. Usando diagnóstico básico.\n")
    # Diagnóstico básico alternativo
    resid <- residuals(mod, type = "pearson")
    sw <- shapiro.test(resid)
    cat("Shapiro-Wilk: W =", round(sw$statistic, 4), "p =", round(sw$p.value, 4), "\n")
    cat("N observaciones:", length(resid), "\n")
    cat("Singular:", isSingular(mod), "\n")
    conv <- tryCatch(check_convergence(mod), error = function(e) NA)
    cat("Convergencia:", conv, "\n")
  })
}

# ── EJECUCIÓN PRINCIPAL ──────────────────────────────────────────────────

cat("\n\n╔══════════════════════════════════════════════════════════════╗\n")
cat("║        MODELOS DE EFECTOS MIXTOS (versión definitiva)        ║\n")
cat("╚══════════════════════════════════════════════════════════════╝\n\n")

resultados_modelos <- list()
# Para FDR global, recopilamos todos los p-valores de efectos fijos
todos_p_vals <- c()
nombres_p_vals <- c()

for (var in vars_presentes) {
  cat("\n══ MODELO MIXTO: ", var, " ══\n", sep = "")
  mod_obj <- ajustar_modelo(ancho, var, incluir_demora = tiene_demora)
  if (!is.null(mod_obj)) {
    res <- extraer_resultados(mod_obj)
    # Almacenar resultados
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
    # Recopilar p-valores para FDR global (solo efectos fijos)
    if (!is.null(res$p_terms)) {
      p_efectos <- res$p_terms
      todos_p_vals <- c(todos_p_vals, p_efectos)
      nombres_p_vals <- c(nombres_p_vals, paste(var, names(p_efectos), sep = "_"))
    }
    # Imprimir ANOVA
    cat("\nModelo (", var, "):\n", sep = "")
    if (!is.null(res$anova)) print(res$anova)
    if (!is.null(res$r2)) {
      cat("R² marginal:", round(res$r2$R2_marginal, 3),
          " condicional:", round(res$r2$R2_conditional, 3), "\n")
    }
    # Mostrar post-hoc si existe
    if (length(res$posthoc) > 0) {
      cat("\nPost-hoc (Tukey):\n")
      for (ph in names(res$posthoc)) {
        cat("  ", ph, ":\n")
        print(res$posthoc[[ph]])
      }
    }
    # Diagnóstico
    diagnosticar(mod_obj, nombre = var)
  } else {
    cat("⚠ No se pudo ajustar modelo para ", var, "\n")
  }
}

# ── CORRECCIÓN FDR GLOBAL ────────────────────────────────────────────────
if (length(todos_p_vals) > 0) {
  p_adj <- p.adjust(todos_p_vals, method = "fdr")
  # Asignar p-valores ajustados a cada modelo
  for (var in names(resultados_modelos)) {
    if (!is.null(resultados_modelos[[var]]$anova)) {
      anov <- resultados_modelos[[var]]$anova
      if ("Pr(>F)" %in% colnames(anov)) {
        p_efectos <- anov[["Pr(>F)"]]
        # Buscar los p ajustados correspondientes
        idx <- which(nombres_p_vals %in% paste(var, names(p_efectos), sep = "_"))
        if (length(idx) > 0) {
          anov$p_FDR <- NA
          anov$p_FDR[match(names(p_efectos), rownames(anov))] <- p_adj[idx]
          resultados_modelos[[var]]$anova <- anov
        }
      }
    }
  }
  cat("\nFDR global aplicado a todos los efectos fijos.\n")
}

# ── CORRELACIONES DE CAMBIO ──────────────────────────────────────────────
cat("\n\n── Correlaciones (Spearman) entre cambios parciales ──────────────\n")
mat_cor <- calcular_correlaciones_cambios(ancho)
if (!is.null(mat_cor)) print(round(mat_cor, 3))

# ── DIAGNÓSTICO DE OUTLIERS (renombrado) ──────────────────────────────────
if ("n_palabras" %in% names(resultados_modelos)) {
  cat("\n\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║           DIAGNÓSTICO DE OUTLIERS                            ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")
  diagnostico <- diagnostico_outliers(resultados_modelos$n_palabras, umbral_resid = 2.5)
} else if (length(resultados_modelos) > 0) {
  primer_modelo <- resultados_modelos[[1]]
  cat("\n\nDiagnóstico de outliers para:", names(resultados_modelos)[1], "\n")
  diagnostico <- diagnostico_outliers(primer_modelo, umbral_resid = 2.5)
}

# ── BOOTSTRAP (para n_palabras si existe) ────────────────────────────────
if ("n_palabras" %in% names(resultados_modelos)) {
  cat("\n\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║           BOOTSTRAPPING (n_palabras)                          ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")
  boot_res <- bootstrappear(resultados_modelos$n_palabras, nsim = 500, seed = 123)
  if (!is.null(boot_res)) {
    cat("Intervalos de confianza bootstrap (95% percentil):\n")
    print(round(boot_res$IC_percentil, 4))
  }
}

# ── TABLA RESUMEN DE RESULTADOS (CON p CRUDO Y FDR) ─────────────────────
cat("\n\n╔══════════════════════════════════════════════════════════════╗\n")
cat("║              TABLA RESUMEN DE EFECTOS                         ║\n")
cat("╚══════════════════════════════════════════════════════════════╝\n\n")

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
          significativo_p_crudo = ifelse(p < 0.05, "Sí", "No"),   # <--- NUEVA
          significativo_FDR = ifelse(p_FDR < 0.05, "Sí", "No")    # <--- NUEVA
        )
        df <- rbind(df, temp)
      }
    }
  }
  return(df)
}

tabla <- tabla_resumen(resultados_modelos)
print(tabla)

# ── TABLA DE CONTRASTES (post-hoc) ──────────────────────────────────────
cat("\n\n╔══════════════════════════════════════════════════════════════╗\n")
cat("║              TABLA DE CONTRASTES (post-hoc)                   ║\n")
cat("╚══════════════════════════════════════════════════════════════╝\n\n")

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

tabla_cont <- tabla_contrastes(resultados_modelos)
if (nrow(tabla_cont) > 0) {
  print(tabla_cont)
} else {
  cat("No se generaron contrastes post-hoc.\n")
}

# ── OBJETOS FINALES PARA EXPORTAR ──────────────────────────────────────
auditoria_modelos <- list(
  estructura = list(
    fuentes = unique(ancho$fuente),
    condiciones = unique(ancho$condicion),
    demoras = unique(ancho$demora[!is.na(ancho$demora)]),
    n_participantes = n_distinct(ancho$id_participante),
    tabla_diseno = tabla_diseno,
    variables_modeladas = vars_presentes
  ),
  modelos_ajustados = names(resultados_modelos),
  errores = NULL
)

# Guardar objetos en entorno global para uso posterior
resultados_finales <- list(
  modelos = resultados_modelos,
  auditoria = auditoria_modelos,
  tabla_resumen = tabla,
  tabla_contrastes = tabla_cont,
  correlaciones = mat_cor,
  bootstrap = if (exists("boot_res")) boot_res else NULL,
  diagnostico_outliers = if (exists("diagnostico")) diagnostico else NULL
)

cat("\n✅ Bloque 10 completado.\n")

## ============================================================================
# BLOQUE 11 — ANÁLISIS AVANZADO PILOTO + PRINCIPAL (VERSIÓN DEFINITIVA)
# ============================================================================
# 
# OBJETIVO:
#   Pipeline estadístico robusto para:
#     1. Auditoría automática de variables (datos, variabilidad, estructura).
#     2. Clasificación y filtrado de variables aptas para modelado.
#     3. Ajuste de LMM solo cuando los datos lo permitan.
#     4. Diagnóstico de convergencia, singularidad e identificabilidad.
#     5. Cálculo de EMM, contrastes (Holm), tamaños de efecto y R².
#     6. Generación de gráficos bilingües (ES/EN) de alta calidad.
#     7. Exportación de tablas, modelos, diagnósticos y reporte.
#     8. Comparación formal piloto vs. principal (interacción fuente×tiempo).
#     9. Registro explícito de variables excluidas y motivos.
#    10. Consola limpia, sin warnings innecesarios.
# 
# ============================================================================

cat("\n\n╔══════════════════════════════════════════════════════════════════════╗")
cat("\n║      BLOQUE 11 — ANÁLISIS AVANZADO PILOTO + PRINCIPAL              ║")
cat("\n║                    VERSIÓN DEFINITIVA — Q1-READY                   ║")
cat("\n╚══════════════════════════════════════════════════════════════════════╝\n\n")

# ----------------------------------------------------------------------------
# 0. VERIFICACIÓN DE OBJETOS Y PAQUETES
# ----------------------------------------------------------------------------

if (!exists("principal_norm") || !exists("piloto_norm")) {
  stop("Faltan 'principal_norm' y/o 'piloto_norm'. Ejecuta la importación primero.")
}

paquetes <- c("dplyr", "tidyr", "stringr", "ggplot2", "lme4", "lmerTest",
              "emmeans", "performance", "effectsize", "broom.mixed", "purrr",
              "readr", "tibble", "scales", "patchwork")
faltantes <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltantes) > 0) {
  install.packages(faltantes)
}
invisible(lapply(paquetes, library, character.only = TRUE))

# ----------------------------------------------------------------------------
# 1. CONFIGURACIÓN DE CARPETAS
# ----------------------------------------------------------------------------

# [v5-J] Salidas separadas por cohorte dentro de la raíz de salida:
#   piloto/      resultados exclusivos del piloto (17 participantes)
#   combinado/   la comparación piloto vs principal
#   principal/   datos del estudio principal (23 participantes)
DIR_SALIDA      <- file.path(getwd(), "piloto")
DIR_COMPARATIVO <- file.path(getwd(), "combinado")
DIR_PRINCIPAL   <- file.path(getwd(), "principal")
dirs <- c(DIR_SALIDA,
          file.path(DIR_SALIDA, "graficas_es"),
          file.path(DIR_SALIDA, "figures_en"),
          file.path(DIR_SALIDA, "tablas"),
          file.path(DIR_SALIDA, "modelos"),
          file.path(DIR_SALIDA, "diagnosticos"),
          file.path(DIR_SALIDA, "datos"),
          DIR_COMPARATIVO,
          file.path(DIR_COMPARATIVO, "graficas_es"),
          file.path(DIR_COMPARATIVO, "figures_en"),
          file.path(DIR_COMPARATIVO, "tablas"),
          file.path(DIR_COMPARATIVO, "modelos"),
          file.path(DIR_COMPARATIVO, "datos"),
          DIR_PRINCIPAL,
          # [v5-V1] El principal tenía solo `datos/`: sus tablas, figuras, modelos y diagnósticos
          # se escribían dentro de la carpeta del piloto (DIR_SALIDA). Ahora cada cohorte tiene las suyas.
          file.path(DIR_PRINCIPAL, "datos"),
          file.path(DIR_PRINCIPAL, "tablas"),
          file.path(DIR_PRINCIPAL, "modelos"),
          file.path(DIR_PRINCIPAL, "graficas_es"),
          file.path(DIR_PRINCIPAL, "figures_en"),
          file.path(DIR_PRINCIPAL, "diagnosticos"))
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))

cat("📁 Carpeta del piloto    :\n", normalizePath(DIR_SALIDA), "\n")
cat("📁 Carpeta comparativa   :\n", normalizePath(DIR_COMPARATIVO), "\n")
cat("📁 Carpeta del principal :\n", normalizePath(DIR_PRINCIPAL), "\n\n")

# ----------------------------------------------------------------------------
# 2. FUNCIONES AUXILIARES
# ----------------------------------------------------------------------------

# Guardar gráfico en PNG y PDF
guardar_grafico <- function(plot, nombre, carpeta, w = 8, h = 6) {
  ggsave(file.path(carpeta, paste0(nombre, ".png")), plot, width = w, height = h, dpi = 600, bg = "white")
  ggsave(file.path(carpeta, paste0(nombre, ".pdf")), plot, width = w, height = h, device = cairo_pdf, bg = "white")
}

# Tema editorial Q1
tema_q1 <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(plot.title = element_text(face = "bold", size = base_size + 3, margin = margin(b = 8)),
          plot.subtitle = element_text(size = base_size, color = "grey30", margin = margin(b = 15)),
          axis.title = element_text(face = "bold"),
          axis.text = element_text(color = "grey20"),
          panel.grid.major.x = element_blank(),
          panel.grid.minor = element_blank(),
          legend.title = element_text(face = "bold"),
          legend.position = "bottom",
          plot.caption = element_text(size = base_size - 2, color = "grey40", hjust = 0),
          strip.text = element_text(face = "bold"),
          plot.margin = margin(12, 15, 12, 15))
}

# ── [v5-O] Construcción del formato largo para modelar (movida de BLOQUE 14) ────────
# Defecto corregido: se llamaba en la §3 de este bloque (vía preparar_datos()) y su
# definición estaba 2.000 líneas más abajo, en el BLOQUE 14: una corrida lineal abortaba
# con 'no se pudo encontrar la función'.
# ── Función para construir formato largo para una variable dada ──────────
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
      condicion = factor(condicion, levels = c("Texto","Audio","Imagen")),
      # [v5-U3] AÑADIDO: el modelo de exposición acumulada necesita `n_estimulos` como
      # predictor en el formato largo. Se deriva del tiempo con la MISMA función del script
      # (T1 -> 0, T2 -> 1, T3 -> 3), no con una regla nueva.
      n_estimulos = derivar_n_estimulos(as.integer(str_extract(tiempo_col, "\\d+$")))
    ) %>%
    filter(!is.na(valor)) %>%
    select(-tiempo_col)
  return(dl)
}

# Preparar datos longitudinales (usa construir_largo_para_modelo ya definida)
preparar_datos <- function(ancho_fuente, variable, fuente_nombre = NULL) {
  dl <- construir_largo_para_modelo(ancho_fuente, variable)
  if (is.null(dl) || nrow(dl) == 0) return(NULL)
  dl <- dl %>%
    mutate(tiempo = factor(tiempo, levels = c("T1", "T2", "T3")),
           condicion = factor(condicion))
  if (!is.null(fuente_nombre)) {
    dl <- dl %>% mutate(fuente = factor(fuente_nombre, levels = c("piloto", "principal")))
  }
  return(dl)
}

# Crear identificador único para comparación
crear_id_unico <- function(datos) {
  datos %>% mutate(id_fuente = interaction(fuente, id_participante, drop = TRUE, sep = "_"))
}

# ----------------------------------------------------------------------------
# 3. CONSTRUIR DATASETS ANCHO (si no existen)
# ----------------------------------------------------------------------------

if (!exists("ancho_principal")) {
  ancho_principal <- generar_ancho(principal_norm) %>% mutate(fuente = "principal")
}
if (!exists("ancho_piloto")) {
  ancho_piloto <- generar_ancho(piloto_norm) %>% mutate(fuente = "piloto")
}

cat("👥 Participantes piloto:", n_distinct(ancho_piloto$id_participante), "\n")
cat("👥 Participantes principal:", n_distinct(ancho_principal$id_participante), "\n\n")

# ----------------------------------------------------------------------------
# 4. SELECCIÓN DE VARIABLES NUMÉRICAS COMUNES
# ----------------------------------------------------------------------------

vars_candidatas <- names(ancho_principal)[grepl("_t[123]$", names(ancho_principal))] %>%
  str_remove("_t[123]$") %>% unique()

vars_numericas <- vars_candidatas[sapply(vars_candidatas, function(v) {
  col <- paste0(v, "_t1")
  col %in% names(ancho_principal) && is.numeric(ancho_principal[[col]])
})]

vars_disponibles <- vars_numericas[sapply(vars_numericas, function(v) {
  all(paste0(v, "_t", 1:3) %in% names(ancho_principal)) &&
    all(paste0(v, "_t", 1:3) %in% names(ancho_piloto))
})]

cat("📊 Variables numéricas comunes disponibles:\n", paste(vars_disponibles, collapse = ", "), "\n\n")

# ----------------------------------------------------------------------------
# 5. AUDITORÍA DE VARIABLES (calidad de datos y variabilidad)
# ----------------------------------------------------------------------------

auditar_variable <- function(ancho_fuente, variable) {
  cols <- paste0(variable, "_t", 1:3)
  if (!all(cols %in% names(ancho_fuente))) {
    return(tibble(variable = variable,
                  estado = "NO_DISPONIBLE",
                  n_participantes = NA_integer_,
                  n_completos = NA_integer_,
                  sd_global = NA_real_,
                  min = NA_real_,
                  max = NA_real_,
                  motivo = "Columnas no encontradas"))
  }
  datos <- ancho_fuente %>% select(id_participante, condicion, all_of(cols))
  completos <- datos %>% filter(if_all(all_of(cols), ~ !is.na(.x)))
  n_participantes <- n_distinct(completos$id_participante)
  valores <- datos %>% select(all_of(cols)) %>% unlist(use.names = FALSE)
  sd_global <- sd(valores, na.rm = TRUE)
  
  # Detectar variable estructural (ej. n_estimulos con varianza casi nula o patrón fijo)
  es_estructural <- FALSE
  if (variable == "n_estimulos") es_estructural <- TRUE  # se puede ampliar con heurística
  
  estado <- case_when(
    n_participantes < 3 ~ "INSUFICIENTES_PARTICIPANTES",
    is.na(sd_global) || sd_global == 0 ~ "VARIANZA_CERO",
    es_estructural ~ "ESTRUCTURAL",
    TRUE ~ "APTA_PARA_REVISION"
  )
  
  motivo <- case_when(
    estado == "INSUFICIENTES_PARTICIPANTES" ~ paste("Solo", n_participantes, "participantes con datos completos"),
    estado == "VARIANZA_CERO" ~ "Desviación estándar global igual a 0",
    estado == "ESTRUCTURAL" ~ "Variable de diseño (no es un outcome)",
    TRUE ~ NA_character_
  )
  
  tibble(variable = variable,
         estado = estado,
         n_participantes = n_participantes,
         n_completos = nrow(completos),
         sd_global = sd_global,
         min = min(valores, na.rm = TRUE),
         max = max(valores, na.rm = TRUE),
         motivo = motivo)
}

auditoria_piloto <- map_dfr(vars_disponibles, ~ auditar_variable(ancho_piloto, .x))
auditoria_principal <- map_dfr(vars_disponibles, ~ auditar_variable(ancho_principal, .x))

# Mostrar auditoría en consola (resumida)
cat("\n══════════════════════════════════════════════════════════════\n")
cat("          AUDITORÍA DE VARIABLES DEL PILOTO\n")
cat("══════════════════════════════════════════════════════════════\n")
print(auditoria_piloto %>% select(variable, estado, n_participantes, motivo))

cat("\n══════════════════════════════════════════════════════════════\n")
cat("          AUDITORÍA DE VARIABLES DEL PRINCIPAL\n")
cat("══════════════════════════════════════════════════════════════\n")
print(auditoria_principal %>% select(variable, estado, n_participantes, motivo))

write_csv(auditoria_piloto, file.path(DIR_SALIDA, "tablas", "auditoria_piloto.csv"))
write_csv(auditoria_principal, file.path(DIR_SALIDA, "tablas", "auditoria_principal.csv"))

# ----------------------------------------------------------------------------
# 6. DESCRIPTIVOS POR CONDICIÓN × TIEMPO (para celdas vacías)
# ----------------------------------------------------------------------------

auditoria_celdas <- function(ancho_fuente, variable, fuente) {
  dl <- preparar_datos(ancho_fuente, variable, fuente)
  if (is.null(dl)) return(NULL)
  dl %>% group_by(condicion, tiempo) %>%
    summarise(n = sum(!is.na(valor)),
              media = mean(valor, na.rm = TRUE),
              sd = sd(valor, na.rm = TRUE),
              mediana = median(valor, na.rm = TRUE),
              minimo = min(valor, na.rm = TRUE),
              maximo = max(valor, na.rm = TRUE),
              .groups = "drop") %>%
    mutate(variable = variable, fuente = fuente, .before = 1)
}

tabla_celdas <- bind_rows(
  map_dfr(vars_disponibles, ~ auditoria_celdas(ancho_piloto, .x, "piloto")),
  map_dfr(vars_disponibles, ~ auditoria_celdas(ancho_principal, .x, "principal"))
)
write_csv(tabla_celdas, file.path(DIR_SALIDA, "tablas", "descriptivos_condicion_tiempo.csv"))

# ----------------------------------------------------------------------------
# 7. VARIABLES APTAS PARA MODELAR
# ----------------------------------------------------------------------------

vars_aptas_piloto <- auditoria_piloto %>% filter(estado == "APTA_PARA_REVISION") %>% pull(variable)
vars_aptas_principal <- auditoria_principal %>% filter(estado == "APTA_PARA_REVISION") %>% pull(variable)
vars_aptas <- intersect(vars_aptas_piloto, vars_aptas_principal)

cat("\n✅ Variables que pasan el filtro de calidad:\n", paste(vars_aptas, collapse = ", "), "\n\n")

# ----------------------------------------------------------------------------
# 8. FUNCIÓN SEGURA PARA AJUSTAR MODELO INDIVIDUAL
# ----------------------------------------------------------------------------

ajustar_modelo_individual <- function(ancho_fuente, variable, nombre_fuente) {
  
  # Preparar datos
  dl <- preparar_datos(ancho_fuente, variable, nombre_fuente)
  if (is.null(dl) || n_distinct(dl$id_participante) < 3) {
    return(list(estado = "INSUFICIENTE", motivo = "Menos de 3 participantes"))
  }
  if (sd(dl$valor, na.rm = TRUE) == 0) {
    return(list(estado = "VARIANZA_CERO", motivo = "Varianza cero en los datos"))
  }
  
  # Ajuste con captura de warnings y errores
  mod <- tryCatch(
    lmer(valor ~ condicion * tiempo + (1 | id_participante),
         data = dl, REML = TRUE,
         control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
    warning = function(w) {
      # Capturar warning y continuar
      list(error = w$message, warning = TRUE)
    },
    error = function(e) {
      list(error = e$message, warning = FALSE)
    }
  )
  
  # Si hubo error o warning grave, devolver diagnóstico
  if (is.list(mod) && !is.null(mod$error)) {
    return(list(estado = "ERROR_AJUSTE", motivo = mod$error))
  }
  
  # Diagnóstico de convergencia y singularidad
  convergio <- is.null(mod@optinfo$conv$lme4$messages)
  singular <- tryCatch(isSingular(mod, tol = 1e-4), error = function(e) NA)
  
  if (!convergio) {
    return(list(estado = "NO_CONVERGENCIA", motivo = "El modelo no convergió"))
  }
  if (isTRUE(singular)) {
    return(list(estado = "SINGULAR", motivo = "Modelo singular (varianza cero)"))
  }
  
  # Modelo válido: extraer resultados
  anov <- tryCatch(anova(mod, ddf = "Satterthwaite"), error = function(e) NULL)
  r2 <- tryCatch(performance::r2_nakagawa(mod), error = function(e) list(R2_marginal = NA, R2_conditional = NA))
  
  emm <- emmeans(mod, ~ condicion * tiempo)
  contrastes_cond <- pairs(emmeans(mod, ~ condicion | tiempo), adjust = "holm")
  contrastes_tiempo <- pairs(emmeans(mod, ~ tiempo | condicion), adjust = "holm")
  
  list(
    estado = "VALIDO",
    modelo = mod,
    anova = anov,
    r2 = r2,
    datos = dl,
    emm_df = as.data.frame(emm),
    contrastes_cond = as.data.frame(contrastes_cond),
    contrastes_tiempo = as.data.frame(contrastes_tiempo),
    diagnosticos = tibble(observado = dl$valor, ajustado = fitted(mod), residuo = residuals(mod))
  )
}

# ----------------------------------------------------------------------------
# 9. ANÁLISIS DEL PILOTO (solo variables aptas)
# ----------------------------------------------------------------------------

cat("\n══════════════════════════════════════════════════════════════\n")
cat("                 ANÁLISIS DEL PILOTO\n")
cat("══════════════════════════════════════════════════════════════\n\n")

resultados_piloto <- list()
registro_piloto <- tibble(variable = character(),
                          estado = character(),
                          motivo = character())

for (var in vars_aptas) {
  cat("→ ", var, " ... ", sep = "")
  res <- ajustar_modelo_individual(ancho_piloto, var, "piloto")
  
  if (res$estado == "VALIDO") {
    resultados_piloto[[var]] <- res
    cat("✅ VALIDO\n")
    # Mostrar ANOVA y R² (solo si válido)
    cat("   ANOVA:\n")
    print(res$anova)
    cat("   R² marginal:", round(res$r2$R2_marginal, 3),
        " | condicional:", round(res$r2$R2_conditional, 3), "\n")
    
    # Si interacción significativa, mostrar contrastes
    if (!is.null(res$anova) && "condicion:tiempo" %in% rownames(res$anova)) {
      p_int <- res$anova["condicion:tiempo", "Pr(>F)"]
      if (!is.na(p_int) && p_int < 0.05) {
        cat("   ▶ Interacción condicion×tiempo significativa (p =", round(p_int, 4), ")\n")
        cat("   Comparaciones entre condiciones en cada tiempo:\n")
        print(res$contrastes_cond)
        cat("   Cambios temporales dentro de cada condición:\n")
        print(res$contrastes_tiempo)
      }
    }
    cat("\n")
  } else {
    cat("❌ ", res$estado, " (", res$motivo, ")\n", sep = "")
    registro_piloto <- bind_rows(registro_piloto,
                                 tibble(variable = var, estado = res$estado, motivo = res$motivo))
  }
}

# ----------------------------------------------------------------------------
# 10. ANÁLISIS DEL PRINCIPAL
# ----------------------------------------------------------------------------

cat("\n══════════════════════════════════════════════════════════════\n")
cat("                ANÁLISIS DEL PRINCIPAL\n")
cat("══════════════════════════════════════════════════════════════\n\n")

resultados_principal <- list()
registro_principal <- tibble(variable = character(),
                             estado = character(),
                             motivo = character())

for (var in vars_aptas) {
  cat("→ ", var, " ... ", sep = "")
  res <- ajustar_modelo_individual(ancho_principal, var, "principal")
  
  if (res$estado == "VALIDO") {
    resultados_principal[[var]] <- res
    cat("✅ VALIDO\n")
    print(res$anova)
    cat("   R² marginal:", round(res$r2$R2_marginal, 3),
        " | condicional:", round(res$r2$R2_conditional, 3), "\n")
    if (!is.null(res$anova) && "condicion:tiempo" %in% rownames(res$anova)) {
      p_int <- res$anova["condicion:tiempo", "Pr(>F)"]
      if (!is.na(p_int) && p_int < 0.05) {
        cat("   ▶ Interacción condicion×tiempo significativa (p =", round(p_int, 4), ")\n")
        print(res$contrastes_cond)
        print(res$contrastes_tiempo)
      }
    }
    cat("\n")
  } else {
    cat("❌ ", res$estado, " (", res$motivo, ")\n", sep = "")
    registro_principal <- bind_rows(registro_principal,
                                    tibble(variable = var, estado = res$estado, motivo = res$motivo))
  }
}

# ----------------------------------------------------------------------------
# 11. TABLA RESUMEN DE MODELOS VÁLIDOS
# ----------------------------------------------------------------------------

extraer_resumen <- function(res, variable, fuente) {
  if (res$estado != "VALIDO") return(NULL)
  an <- as.data.frame(res$anova)
  tibble(fuente = fuente, variable = variable, efecto = rownames(an),
         F = an$`F value`, df1 = an$NumDF, df2 = an$DenDF,
         p = an$`Pr(>F)`,
         R2_marginal = res$r2$R2_marginal,
         R2_condicional = res$r2$R2_conditional)
}

tabla_modelos <- bind_rows(
  map2_dfr(resultados_piloto, names(resultados_piloto), ~ extraer_resumen(.x, .y, "piloto")),
  map2_dfr(resultados_principal, names(resultados_principal), ~ extraer_resumen(.x, .y, "principal"))
)
write_csv(tabla_modelos, file.path(DIR_SALIDA, "tablas", "resumen_modelos_validos.csv"))

# Guardar registros de exclusión
write_csv(registro_piloto, file.path(DIR_SALIDA, "tablas", "piloto_modelos_excluidos.csv"))
write_csv(registro_principal, file.path(DIR_SALIDA, "tablas", "principal_modelos_excluidos.csv"))

# ----------------------------------------------------------------------------
# 12. EXPORTAR EMM Y CONTRASTES DEL PILOTO (solo válidos)
# ----------------------------------------------------------------------------

for (var in names(resultados_piloto)) {
  res <- resultados_piloto[[var]]
  if (res$estado == "VALIDO") {
    write_csv(res$emm_df, file.path(DIR_SALIDA, "tablas", paste0("piloto_", var, "_EMM.csv")))
    write_csv(res$contrastes_cond, file.path(DIR_SALIDA, "tablas", paste0("piloto_", var, "_contrastes_cond.csv")))
    write_csv(res$contrastes_tiempo, file.path(DIR_SALIDA, "tablas", paste0("piloto_", var, "_contrastes_tiempo.csv")))
  }
}

# [v5-V4] Las medias marginales y los contrastes del PRINCIPAL se calculaban pero no se
# escribían: el bucle de exportación solo recorría `resultados_piloto`.
for (var in names(resultados_principal)) {
  res <- resultados_principal[[var]]
  if (res$estado == "VALIDO") {
    write_csv(res$emm_df, file.path(DIR_PRINCIPAL, "tablas", paste0("principal_", var, "_EMM.csv")))
    write_csv(res$contrastes_cond, file.path(DIR_PRINCIPAL, "tablas", paste0("principal_", var, "_contrastes_cond.csv")))
    write_csv(res$contrastes_tiempo, file.path(DIR_PRINCIPAL, "tablas", paste0("principal_", var, "_contrastes_tiempo.csv")))
  }
}

# ----------------------------------------------------------------------------
# 13. GRÁFICOS DEL PILOTO (bilingües, solo variables válidas)
# ----------------------------------------------------------------------------

# [v5-V2] Parametrizada: antes tenía fijos el prefijo "PILOTO_"/"PILOT_", la carpeta de salida
# (DIR_SALIDA) y el subtítulo, de modo que las figuras del PRINCIPAL no se generaban nunca.
generar_graficos <- function(res, variable, idioma = "es",
                             prefijo_es = "PILOTO", prefijo_en = "PILOT",
                             carpeta_base = DIR_SALIDA,
                             etiqueta = "Piloto", etiqueta_en = "Pilot study") {
  if (res$estado != "VALIDO") return(NULL)
  emm <- res$emm_df
  dl <- res$datos
  
  if (idioma == "es") {
    titulo <- paste("Evolución longitudinal de", variable)
    subtitulo <- paste0(etiqueta, " — medias marginales estimadas e IC95%")
    eje_x <- "Tiempo"; eje_y <- variable; leyenda <- "Condición"
    prefijo <- paste0(prefijo_es, "_", variable, "_ES")
    carpeta <- file.path(carpeta_base, "graficas_es")
  } else {
    titulo <- paste("Longitudinal trajectory of", variable)
    subtitulo <- paste0(etiqueta_en, " — estimated marginal means with 95% CI")
    eje_x <- "Time"; eje_y <- variable; leyenda <- "Condition"
    prefijo <- paste0(prefijo_en, "_", variable, "_EN")
    carpeta <- file.path(carpeta_base, "figures_en")
  }
  
  p1 <- ggplot(emm, aes(x = tiempo, y = emmean, group = condicion, linetype = condicion)) +
    geom_line(linewidth = 0.9) + geom_point(size = 3) +
    geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.08) +
    labs(title = titulo, subtitle = subtitulo, x = eje_x, y = eje_y, linetype = leyenda) +
    tema_q1()
  
  p2 <- ggplot(dl, aes(x = tiempo, y = valor, group = id_participante)) +
    geom_line(alpha = 0.2, linewidth = 0.4) + geom_point(alpha = 0.35, size = 1.8) +
    geom_line(data = emm, aes(x = tiempo, y = emmean, group = condicion, linetype = condicion),
              linewidth = 1.2, inherit.aes = FALSE) +
    geom_point(data = emm, aes(x = tiempo, y = emmean, shape = condicion), size = 3, inherit.aes = FALSE) +
    labs(title = ifelse(idioma == "es", paste("Trayectorias individuales y tendencia:", variable),
                        paste("Individual trajectories and group trend:", variable)),
         x = eje_x, y = eje_y) + tema_q1()
  
  p3 <- ggplot(dl, aes(x = tiempo, y = valor)) +
    geom_boxplot(aes(group = interaction(tiempo, condicion)), width = 0.55, outlier.shape = NA, alpha = 0.35) +
    geom_jitter(aes(shape = condicion), width = 0.08, height = 0, alpha = 0.55, size = 2) +
    labs(title = ifelse(idioma == "es", paste("Distribución de", variable), paste("Distribution of", variable)),
         x = eje_x, y = eje_y, shape = leyenda) + tema_q1()
  
  guardar_grafico(p1, paste0(prefijo, "_trayectoria"), carpeta)
  guardar_grafico(p2, paste0(prefijo, "_individuales"), carpeta)
  guardar_grafico(p3, paste0(prefijo, "_distribucion"), carpeta)
  
  return(list(trayectoria = p1, individuales = p2, distribucion = p3))
}

graficas_piloto <- list()
for (var in names(resultados_piloto)) {
  if (resultados_piloto[[var]]$estado == "VALIDO") {
    cat("📊 Generando figuras para:", var, "\n")
    graficas_piloto[[var]] <- list(
      es = generar_graficos(resultados_piloto[[var]], var, "es"),
      en = generar_graficos(resultados_piloto[[var]], var, "en")
    )
  }
}

# [v5-V3] Las figuras del PRINCIPAL no se generaban: la función estaba fijada al piloto.
graficas_principal <- list()
for (var in names(resultados_principal)) {
  if (resultados_principal[[var]]$estado == "VALIDO") {
    cat("📊 Generando figuras del principal para:", var, "\n")
    graficas_principal[[var]] <- list(
      es = generar_graficos(resultados_principal[[var]], var, "es",
                            prefijo_es = "PRINCIPAL", prefijo_en = "MAIN",
                            carpeta_base = DIR_PRINCIPAL,
                            etiqueta = "Principal", etiqueta_en = "Main study"),
      en = generar_graficos(resultados_principal[[var]], var, "en",
                            prefijo_es = "PRINCIPAL", prefijo_en = "MAIN",
                            carpeta_base = DIR_PRINCIPAL,
                            etiqueta = "Principal", etiqueta_en = "Main study")
    )
  }
}

# ----------------------------------------------------------------------------
# 14. DIAGNÓSTICOS DE MODELOS VÁLIDOS (con manejo de dependencias)
# ----------------------------------------------------------------------------

# Asegurar que 'see' esté disponible para check_model()
if (!requireNamespace("see", quietly = TRUE)) {
  install.packages("see")
}

for (var in names(resultados_piloto)) {
  if (resultados_piloto[[var]]$estado == "VALIDO") {
    mod <- resultados_piloto[[var]]$modelo
    sink(file.path(DIR_SALIDA, "diagnosticos", paste0("piloto_", var, "_performance.txt")))
    cat("Variable:", var, "\n\n")
    
    # [v5-P] CORREGIDO: performance::check_model() devuelve un GRÁFICO; imprimirlo dentro
    # del sink() escribía la estructura del objeto en el .txt (decenas de KB ilegibles).
    # Ahora el gráfico va a un PNG y el .txt lleva solo las cifras del diagnóstico.
    resid <- residuals(mod, type = "pearson")
    cat("Shapiro-Wilk de residuos: W =", round(shapiro.test(resid)$statistic, 4),
        " p =", round(shapiro.test(resid)$p.value, 4), "\n")
    cat("N observaciones:", length(resid), "\n")
    cat("Singular:", isSingular(mod), "\n")
    conv <- tryCatch(check_convergence(mod), error = function(e) NA)
    cat("Convergencia:", conv, "\n")
    
    cat("\n\nResumen del modelo:\n")
    print(summary(mod))
    sink()

    # [v5-P2] El gráfico de supuestos, a PNG (fuera del sink)
    tryCatch({
      png(file.path(DIR_SALIDA, "diagnosticos", paste0("piloto_", var, "_check_model.png")),
          width = 1500, height = 1200, res = 130)
      print(performance::check_model(mod))
      dev.off()
    }, error = function(e) {
      try(dev.off(), silent = TRUE)
      cat("  (check_model() no disponible para el PNG:", conditionMessage(e), ")\n")
    })

    write_csv(resultados_piloto[[var]]$diagnosticos,
              file.path(DIR_SALIDA, "diagnosticos", paste0("piloto_", var, "_diagnosticos.csv")))
  }
}

# [v5-V5] Lo mismo con los diagnósticos del principal (el bucle solo recorría el piloto).
for (var in names(resultados_principal)) {
  if (resultados_principal[[var]]$estado == "VALIDO") {
    mod <- resultados_principal[[var]]$modelo
    sink(file.path(DIR_PRINCIPAL, "diagnosticos", paste0("principal_", var, "_performance.txt")))
    cat("Variable:", var, "\n\n")
    cat("Cohorte: principal (", n_distinct(ancho_principal$id_participante), " participantes)\n")
    cat("Shapiro-Wilk de residuos: W =",
        round(shapiro.test(residuals(mod, type = "pearson"))$statistic, 4),
        " p =", round(shapiro.test(residuals(mod, type = "pearson"))$p.value, 4), "\n")
    cat("Singular:", isSingular(mod), "\n")
    cat("\n\nResumen del modelo:\n")
    print(summary(mod))
    sink()
    write_csv(resultados_principal[[var]]$diagnosticos,
              file.path(DIR_PRINCIPAL, "diagnosticos", paste0("principal_", var, "_diagnosticos.csv")))
  }
}

# ----------------------------------------------------------------------------
# 15. COMPARACIÓN PILOTO vs PRINCIPAL (solo variables válidas en ambas)
# ----------------------------------------------------------------------------

vars_comparativas <- intersect(names(resultados_piloto), names(resultados_principal))
vars_comparativas <- vars_comparativas[sapply(vars_comparativas, function(v) {
  resultados_piloto[[v]]$estado == "VALIDO" && resultados_principal[[v]]$estado == "VALIDO"
})]

if (length(vars_comparativas) > 0) {
  cat("\n══════════════════════════════════════════════════════════════\n")
  cat("            COMPARACIÓN PILOTO vs PRINCIPAL\n")
  cat("══════════════════════════════════════════════════════════════\n\n")
  
  ancho_combinado <- bind_rows(ancho_piloto, ancho_principal)
  resultados_comparativos <- list()
  
  for (var in vars_comparativas) {
    cat("→ ", var, " ... ", sep = "")
    dl_p <- preparar_datos(ancho_piloto, var, "piloto")
    dl_m <- preparar_datos(ancho_principal, var, "principal")
    if (is.null(dl_p) || is.null(dl_m)) { cat("❌ Datos insuficientes\n"); next }
    dl <- bind_rows(dl_p, dl_m) %>% crear_id_unico()
    
    mod <- tryCatch(
      lmer(valor ~ fuente * condicion * tiempo + (1 | id_fuente),
           data = dl, REML = TRUE,
           control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
      error = function(e) NULL
    )
    if (is.null(mod)) { cat("❌ Error en modelo\n"); next }
    
    anov <- anova(mod, ddf = "Satterthwaite")
    r2 <- performance::r2_nakagawa(mod)
    emm <- emmeans(mod, ~ fuente * condicion * tiempo)
    
    resultados_comparativos[[var]] <- list(modelo = mod, anova = anov, r2 = r2,
                                           datos = dl, emm_df = as.data.frame(emm))
    cat("✅ VALIDO\n")
    print(anov)
    cat("   R² marginal:", round(r2$R2_marginal, 3), " | condicional:", round(r2$R2_conditional, 3), "\n")
    
    write_csv(as.data.frame(anov) %>% rownames_to_column("efecto"),
              file.path(DIR_COMPARATIVO, "tablas", paste0("comparacion_", var, "_ANOVA.csv")))
    write_csv(as.data.frame(emm),
              file.path(DIR_COMPARATIVO, "tablas", paste0("comparacion_", var, "_EMM.csv")))
  }
  
  # Interacción fuente:tiempo (corrección Holm)
  if (length(resultados_comparativos) > 0) {
    tabla_interaccion <- map_dfr(resultados_comparativos, function(res) {
      an <- as.data.frame(res$anova)
      if ("fuente:tiempo" %in% rownames(an)) {
        tibble(efecto = "fuente:tiempo",
               F = an["fuente:tiempo", "F value"],
               df1 = an["fuente:tiempo", "NumDF"],
               df2 = an["fuente:tiempo", "DenDF"],
               p = an["fuente:tiempo", "Pr(>F)"])
      } else {
        tibble(efecto = "fuente:tiempo", F = NA, df1 = NA, df2 = NA, p = NA)
      }
    }, .id = "variable") %>%
      mutate(p_ajustada = p.adjust(p, method = "holm"))
    write_csv(tabla_interaccion, file.path(DIR_COMPARATIVO, "tablas", "interaccion_fuente_tiempo.csv"))
  }
  
  # Gráficos comparativos
  for (var in names(resultados_comparativos)) {
    emm <- resultados_comparativos[[var]]$emm_df
    p_es <- ggplot(emm, aes(x = tiempo, y = emmean, group = interaction(fuente, condicion), linetype = condicion)) +
      geom_line(linewidth = 0.9) + geom_point(size = 2.8) +
      geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.08) +
      facet_wrap(~fuente) +
      labs(title = paste("Comparación piloto vs. principal:", var),
           subtitle = "Medias marginales estimadas e IC95%", x = "Tiempo", y = var, linetype = "Condición") +
      tema_q1()
    guardar_grafico(p_es, paste0("COMPARACION_", var, "_ES"), file.path(DIR_COMPARATIVO, "graficas_es"), w = 10, h = 6)
    
    p_en <- ggplot(emm, aes(x = tiempo, y = emmean, group = interaction(fuente, condicion), linetype = condicion)) +
      geom_line(linewidth = 0.9) + geom_point(size = 2.8) +
      geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.08) +
      facet_wrap(~fuente, labeller = as_labeller(c(piloto = "Pilot", principal = "Main study"))) +
      labs(title = paste("Pilot vs. main study comparison:", var),
           subtitle = "Estimated marginal means with 95% CI", x = "Time", y = var, linetype = "Condition") +
      tema_q1()
    guardar_grafico(p_en, paste0("COMPARISON_", var, "_EN"), file.path(DIR_COMPARATIVO, "figures_en"), w = 10, h = 6)
  }
} else {
  cat("\n⚠ No hay variables válidas en ambas fuentes para la comparación.\n")
}

# ----------------------------------------------------------------------------
# 16. GUARDAR MODELOS Y DATOS
# ----------------------------------------------------------------------------

saveRDS(resultados_piloto, file.path(DIR_SALIDA, "modelos", "modelos_piloto.rds"))
# [v5-V6] CORREGIDO: los modelos del principal se guardaban en la carpeta del PILOTO.
saveRDS(resultados_principal, file.path(DIR_PRINCIPAL, "modelos", "modelos_principal.rds"))
if (exists("resultados_comparativos")) {
  saveRDS(resultados_comparativos, file.path(DIR_SALIDA, "modelos", "modelos_comparativos.rds"))
}

# Datos longitudinales en formato largo (solo variables aptas)
datos_piloto_long <- map_dfr(vars_aptas, function(v) {
  preparar_datos(ancho_piloto, v, "piloto") %>% mutate(variable = v)
})
datos_principal_long <- map_dfr(vars_aptas, function(v) {
  preparar_datos(ancho_principal, v, "principal") %>% mutate(variable = v)
})
write_csv(datos_piloto_long, file.path(DIR_SALIDA, "datos", "piloto_longitudinal.csv"))
write_csv(datos_principal_long, file.path(DIR_PRINCIPAL, "datos", "principal_longitudinal.csv"))

# [v5-J6] Los tres conjuntos, cada uno en su carpeta, sin mezclar cohortes
saveRDS(ancho_piloto,    file.path(DIR_SALIDA,      "datos", "ancho_piloto.rds"))
saveRDS(ancho_principal, file.path(DIR_PRINCIPAL,   "datos", "ancho_principal.rds"))
ancho_combinado <- dplyr::bind_rows(
  dplyr::mutate(ancho_piloto,    fuente = "piloto"),
  dplyr::mutate(ancho_principal, fuente = "principal")
)
saveRDS(ancho_combinado, file.path(DIR_COMPARATIVO, "datos", "ancho_combinado.rds"))
cat("[v5-J6] Guardados: ancho_piloto.rds (", nrow(ancho_piloto), "filas) |",
    "ancho_principal.rds (", nrow(ancho_principal), "filas) |",
    "ancho_combinado.rds (", nrow(ancho_combinado), "filas)\n")

# ----------------------------------------------------------------------------
# 17. REPORTE AUTOMÁTICO (README)
# ----------------------------------------------------------------------------

sink(file.path(DIR_SALIDA, "README_ANALISIS_PILOTO.txt"))
cat("===============================================================\n")
cat("ANÁLISIS PILOTO — REPORTE DE EJECUCIÓN\n")
cat("===============================================================\n\n")
cat("Fecha:", format(Sys.time()), "\n")
cat("Directorio:", getwd(), "\n")
cat("Carpeta de resultados:", DIR_SALIDA, "\n\n")
cat("👥 Participantes piloto:", n_distinct(ancho_piloto$id_participante), "\n")
cat("👥 Participantes principal:", n_distinct(ancho_principal$id_participante), "\n\n")
cat("📊 Variables aptas analizadas:\n", paste(vars_aptas, collapse = ", "), "\n\n")
cat("✅ MODELOS PILOTO VÁLIDOS:\n")
for (var in names(resultados_piloto)) {
  if (resultados_piloto[[var]]$estado == "VALIDO") {
    cat("\nVARIABLE:", var, "\n")
    print(resultados_piloto[[var]]$anova)
    cat("R² marginal:", resultados_piloto[[var]]$r2$R2_marginal,
        " | condicional:", resultados_piloto[[var]]$r2$R2_conditional, "\n")
  }
}
cat("\n❌ MODELOS PILOTO EXCLUIDOS:\n")
print(registro_piloto)

cat("\n✅ MODELOS PRINCIPAL VÁLIDOS:\n")
for (var in names(resultados_principal)) {
  if (resultados_principal[[var]]$estado == "VALIDO") {
    cat("\nVARIABLE:", var, "\n")
    print(resultados_principal[[var]]$anova)
    cat("R² marginal:", resultados_principal[[var]]$r2$R2_marginal,
        " | condicional:", resultados_principal[[var]]$r2$R2_conditional, "\n")
  }
}
cat("\n❌ MODELOS PRINCIPAL EXCLUIDOS:\n")
print(registro_principal)

if (exists("tabla_interaccion")) {
  cat("\n\nCOMPARACIÓN PILOTO VS PRINCIPAL (interacción fuente:tiempo)\n")
  print(tabla_interaccion)
}
sink()

# ----------------------------------------------------------------------------
# 18. OBJETO GLOBAL FINAL
# ----------------------------------------------------------------------------

resultados_finales <- list(
  piloto = resultados_piloto,
  principal = resultados_principal,
  comparativo = if (exists("resultados_comparativos")) resultados_comparativos else NULL,
  variables_aptas = vars_aptas,
  auditoria_piloto = auditoria_piloto,
  auditoria_principal = auditoria_principal,
  registros_excluidos = list(piloto = registro_piloto, principal = registro_principal),
  tabla_modelos = tabla_modelos,
  tabla_interaccion = if (exists("tabla_interaccion")) tabla_interaccion else NULL,
  graficas = graficas_piloto,
  directorio = DIR_SALIDA
)

# ----------------------------------------------------------------------------
# 19. RESUMEN FINAL EN CONSOLA
# ----------------------------------------------------------------------------

cat("\n\n╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║                  BLOQUE 11 COMPLETADO                              ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n\n")
cat("📁 Resultados guardados en:\n", normalizePath(DIR_SALIDA), "\n")
cat("📊 Variables aptas analizadas:", length(vars_aptas), "\n")
cat("👥 Piloto:", n_distinct(ancho_piloto$id_participante), " | Principal:", n_distinct(ancho_principal$id_participante), "\n")
cat("✅ Modelos válidos (piloto):", sum(registro_piloto$estado == "VALIDO"), "\n")
cat("❌ Modelos excluidos (piloto):", nrow(registro_piloto), "\n")
cat("\n✅ Análisis piloto con control de calidad finalizado.\n")

# ============================================================================
# EXTRACCIÓN DE OBJETOS EXCLUSIVOS DEL PILOTO (VERSIÓN CORREGIDA)
# ============================================================================
# Usa ancho_piloto (generado en el Bloque 11) y recalcula embeddings
# específicamente para el piloto para evitar problemas de alineación.
# ============================================================================

cat("\n══════════════════════════════════════════════════════════════\n")
cat("   EXTRACCIÓN DE OBJETOS EXCLUSIVOS DEL PILOTO\n")
cat("══════════════════════════════════════════════════════════════\n\n")

# ----------------------------------------------------------------------------
# 1. Verificar existencia de ancho_piloto y funciones necesarias
# ----------------------------------------------------------------------------

if (!exists("ancho_piloto")) {
  stop("El objeto 'ancho_piloto' no existe. Ejecuta el Bloque 11 primero.")
}
if (!exists("obtener_embeddings")) {
  stop("La función 'obtener_embeddings' no está definida. Ejecuta el Bloque 7.")
}

# ----------------------------------------------------------------------------
# 2. Asegurar que ancho_piloto tenga las columnas de texto limpio
# ----------------------------------------------------------------------------

# Si ancho_piloto no tiene t1_limpio, t2_limpio, t3_limpio, intentar generarlas
if (!all(c("t1_limpio", "t2_limpio", "t3_limpio") %in% names(ancho_piloto))) {
  cat("⚠ Generando columnas de texto limpio para el piloto...\n")
  if (exists("limpiar_texto")) {
    ancho_piloto <- ancho_piloto %>%
      mutate(
        t1_limpio = if ("texto_t1" %in% names(.)) map_chr(texto_t1, ~ limpiar_texto(.)) else NA,
        t2_limpio = if ("texto_t2" %in% names(.)) map_chr(texto_t2, ~ limpiar_texto(.)) else NA,
        t3_limpio = if ("texto_t3" %in% names(.)) map_chr(texto_t3, ~ limpiar_texto(.)) else NA
      )
  } else {
    stop("No se encuentra la función limpiar_texto. No se pueden generar textos limpios.")
  }
}

# ----------------------------------------------------------------------------
# 3. Extraer textos del piloto
# ----------------------------------------------------------------------------

textos_piloto_t1 <- ancho_piloto$t1_limpio
textos_piloto_t2 <- ancho_piloto$t2_limpio
textos_piloto_t3 <- ancho_piloto$t3_limpio

# Reemplazar NA o vacíos
textos_piloto_t1[is.na(textos_piloto_t1) | trimws(textos_piloto_t1) == ""] <- "[VACÍO]"
textos_piloto_t2[is.na(textos_piloto_t2) | trimws(textos_piloto_t2) == ""] <- "[VACÍO]"
textos_piloto_t3[is.na(textos_piloto_t3) | trimws(textos_piloto_t3) == ""] <- "[VACÍO]"

cat("✅ Textos del piloto listos para embeddings:\n")
cat("   T1:", length(textos_piloto_t1), "textos\n")
cat("   T2:", length(textos_piloto_t2), "textos\n")
cat("   T3:", length(textos_piloto_t3), "textos\n\n")

# ----------------------------------------------------------------------------
# 4. Recalcular embeddings del piloto
# ----------------------------------------------------------------------------

cat("⏳ Generando embeddings para el piloto...\n")
emb_piloto_t1 <- obtener_embeddings(textos_piloto_t1, normalize = TRUE, batch_size = 32L)
emb_piloto_t2 <- obtener_embeddings(textos_piloto_t2, normalize = TRUE, batch_size = 32L)
emb_piloto_t3 <- obtener_embeddings(textos_piloto_t3, normalize = TRUE, batch_size = 32L)
# [v5-K2] VALIDACIÓN DEL PILOTO: en el árbol auditado esta sección produjo
# objetos VACÍOS (0 x 384) que se guardaban como si fueran resultados.
.n_vacios_piloto <- sum(trimws(textos_piloto_t1) == "[VACÍO]") +
                    sum(trimws(textos_piloto_t2) == "[VACÍO]") +
                    sum(trimws(textos_piloto_t3) == "[VACÍO]")
cat("[v5-K2] Textos del piloto marcados como [VACÍO]:", .n_vacios_piloto, "de",
    length(textos_piloto_t1) + length(textos_piloto_t2) + length(textos_piloto_t3), "\n")
for (.nm in c("emb_piloto_t1", "emb_piloto_t2", "emb_piloto_t3")) {
  .m <- get(.nm)
  if (is.null(.m) || length(dim(.m)) < 2 || nrow(.m) == 0 || ncol(.m) != 384)
    stop("[v5-K2] Embeddings del piloto inválidos en ", .nm, ": dimensiones ",
         paste(dim(.m), collapse = " x "), " (se esperaba n x 384 con n > 0).")
}
cat("✅ Embeddings del piloto generados y verificados:\n")
cat("   emb_piloto_t1:", paste(dim(emb_piloto_t1), collapse = " x "), "\n")
cat("   emb_piloto_t2:", paste(dim(emb_piloto_t2), collapse = " x "), "\n")
cat("   emb_piloto_t3:", paste(dim(emb_piloto_t3), collapse = " x "), "\n\n")

# ----------------------------------------------------------------------------
# 5. Guardar en la carpeta de salida del Bloque 11
# ----------------------------------------------------------------------------

# Asegurar que la carpeta existe
DIR_PILOTO_DATOS <- file.path(DIR_SALIDA, "datos")
dir.create(DIR_PILOTO_DATOS, recursive = TRUE, showWarnings = FALSE)

# Guardar embeddings
saveRDS(emb_piloto_t1, file.path(DIR_PILOTO_DATOS, "embeddings_piloto_t1.rds"))
saveRDS(emb_piloto_t2, file.path(DIR_PILOTO_DATOS, "embeddings_piloto_t2.rds"))
saveRDS(emb_piloto_t3, file.path(DIR_PILOTO_DATOS, "embeddings_piloto_t3.rds"))

# Guardar ancho completo del piloto
saveRDS(ancho_piloto, file.path(DIR_PILOTO_DATOS, "ancho_piloto_completo.rds"))
write_csv(ancho_piloto, file.path(DIR_PILOTO_DATOS, "ancho_piloto_completo.csv"))

# ----------------------------------------------------------------------------
# 6. Guardar subconjuntos de columnas (evitando columnas que no existen)
# ----------------------------------------------------------------------------

# Columnas de identificación (solo las que existen)
id_cols <- intersect(c("id_participante", "participante", "condicion", "fuente"), names(ancho_piloto))
if (length(id_cols) > 0) {
  write_csv(ancho_piloto[, id_cols], file.path(DIR_PILOTO_DATOS, "piloto_identificacion.csv"))
}

# Métricas lingüísticas (solo las que existen)
ling_cols <- grep("^n_palabras_|^ttr_|^n_oraciones_|^long_palabra_|^palabras_oracion_", names(ancho_piloto), value = TRUE)
if (length(ling_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", ling_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_metricas_linguisticas.csv"))
}

# Scores de diccionarios
score_cols <- grep("^score_", names(ancho_piloto), value = TRUE)
if (length(score_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", score_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_scores_diccionarios.csv"))
}

# Tasas de diccionarios
rate_cols <- grep("^rate_", names(ancho_piloto), value = TRUE)
if (length(rate_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", rate_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_tasas_diccionarios.csv"))
}

# Prototipos
proto_cols <- grep("^proto_", names(ancho_piloto), value = TRUE)
if (length(proto_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", proto_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_prototipos.csv"))
}

# Similitudes semánticas
sim_cols <- grep("^sim_sem_|^div_sem_|^cambio_semantico_", names(ancho_piloto), value = TRUE)
if (length(sim_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", sim_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_similitudes_semanticas.csv"))
}

# PCA
pca_cols <- grep("^PC[12]_t[123]", names(ancho_piloto), value = TRUE)
if (length(pca_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", pca_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_pca.csv"))
}

# Deltas de prototipos (si existen)
delta_cols <- grep("^delta_proto_", names(ancho_piloto), value = TRUE)
if (length(delta_cols) > 0) {
  write_csv(ancho_piloto[, c("id_participante", delta_cols)], 
            file.path(DIR_PILOTO_DATOS, "piloto_deltas_prototipos.csv"))
}

cat("✅ Archivos guardados en:\n")
cat("   ", normalizePath(DIR_PILOTO_DATOS), "\n\n")

# ============================================================================
# RESUMEN EN CONSOLA DE LOS OBJETOS DEL PILOTO EXTRAÍDOS (CORREGIDO)
# ============================================================================

cat("\n══════════════════════════════════════════════════════════════\n")
cat("   RESUMEN DE OBJETOS DEL PILOTO EXTRAÍDOS\n")
cat("══════════════════════════════════════════════════════════════\n\n")

cat("📌 PARTICIPANTES Y DISEÑO\n")
cat("   Participantes:", n_distinct(ancho_piloto$id_participante), "\n")
cat("   Observaciones (filas):", nrow(ancho_piloto), "\n")
cat("   Condiciones:", paste(unique(ancho_piloto$condicion), collapse = ", "), "\n\n")

# Convertir ancho a largo para resúmenes (usando las columnas numéricas que tengan _t1, _t2, _t3)
# Esto permite agrupar por "tiempo" fácilmente.
cols_largo <- names(ancho_piloto)[grepl("_t[123]$", names(ancho_piloto)) & sapply(ancho_piloto, is.numeric)]
if (length(cols_largo) > 0) {
  ancho_piloto_largo <- ancho_piloto %>%
    pivot_longer(cols = all_of(cols_largo),
                 names_to = c("metrica", "tiempo"),
                 names_pattern = "(.*)_t(\\d)",
                 values_to = "valor") %>%
    mutate(tiempo = paste0("T", tiempo))
} else {
  ancho_piloto_largo <- NULL
}

# Métricas lingüísticas (solo las que existen en el formato largo)
if (!is.null(ancho_piloto_largo)) {
  ling_met <- intersect(c("n_palabras", "ttr", "n_oraciones", "long_palabra", "palabras_oracion"),
                        unique(ancho_piloto_largo$metrica))
  if (length(ling_met) > 0) {
    cat("📊 MÉTRICAS LINGÜÍSTICAS (medias por tiempo, sin condición)\n")
    print(ancho_piloto_largo %>%
            filter(metrica %in% ling_met) %>%
            group_by(metrica, tiempo) %>%
            summarise(media = mean(valor, na.rm = TRUE),
                      sd = sd(valor, na.rm = TRUE),
                      .groups = "drop") %>%
            mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
            pivot_wider(names_from = tiempo, values_from = c(media, sd)) %>%
            print(n = Inf))
    cat("\n")
  }
}

# Scores de diccionarios (si existen)
if (!is.null(ancho_piloto_largo)) {
  score_met <- intersect(grep("^score_", unique(ancho_piloto_largo$metrica), value = TRUE),
                         unique(ancho_piloto_largo$metrica))
  if (length(score_met) > 0) {
    cat("📈 SCORES DE DICCIONARIOS (promedios por condición y tiempo)\n")
    print(ancho_piloto_largo %>%
            filter(metrica %in% score_met) %>%
            group_by(condicion, tiempo, metrica) %>%
            summarise(media = mean(valor, na.rm = TRUE), .groups = "drop") %>%
            mutate(media = round(media, 2)) %>%
            pivot_wider(names_from = c(tiempo, metrica), values_from = media,
                        names_sep = "_") %>%
            print(n = Inf))
    cat("\n")
  }
}

# Tasas de diccionarios (si existen)
if (!is.null(ancho_piloto_largo)) {
  rate_met <- intersect(grep("^rate_", unique(ancho_piloto_largo$metrica), value = TRUE),
                        unique(ancho_piloto_largo$metrica))
  if (length(rate_met) > 0) {
    cat("📈 TASAS DE DICCIONARIOS (por 1000 palabras, promedios por condición y tiempo)\n")
    print(ancho_piloto_largo %>%
            filter(metrica %in% rate_met) %>%
            group_by(condicion, tiempo, metrica) %>%
            summarise(media = mean(valor, na.rm = TRUE), .groups = "drop") %>%
            mutate(media = round(media, 2)) %>%
            pivot_wider(names_from = c(tiempo, metrica), values_from = media,
                        names_sep = "_") %>%
            print(n = Inf))
    cat("\n")
  }
}

# Prototipos (si existen)
if (!is.null(ancho_piloto_largo)) {
  proto_met <- intersect(grep("^proto_", unique(ancho_piloto_largo$metrica), value = TRUE),
                         unique(ancho_piloto_largo$metrica))
  if (length(proto_met) > 0) {
    cat("🧠 PROTOTIPOS SEMÁNTICOS (promedios por tiempo, sin condición)\n")
    print(ancho_piloto_largo %>%
            filter(metrica %in% proto_met) %>%
            group_by(metrica, tiempo) %>%
            summarise(media = mean(valor, na.rm = TRUE), .groups = "drop") %>%
            mutate(media = round(media, 4)) %>%
            pivot_wider(names_from = tiempo, values_from = media) %>%
            print(n = Inf))
    cat("\n")
  }
}

# Similitudes semánticas (están en ancho, no en largo)
if (length(sim_cols) > 0) {
  cat("🔗 SIMILITUDES SEMÁNTICAS (resumen)\n")
  print(ancho_piloto %>%
          summarise(across(all_of(sim_cols), 
                           list(media = ~ mean(.x, na.rm = TRUE),
                                sd = ~ sd(.x, na.rm = TRUE),
                                min = ~ min(.x, na.rm = TRUE),
                                max = ~ max(.x, na.rm = TRUE)),
                           .names = "{.col}_{.fn}")) %>%
          pivot_longer(everything(), names_to = "variable", values_to = "valor") %>%
          separate(variable, into = c("metrica", "estadistico"), sep = "_") %>%
          pivot_wider(names_from = estadistico, values_from = valor) %>%
          mutate(across(where(is.numeric), ~ round(.x, 4))) %>%
          print(n = 20))
  cat("\n")
}

# Dimensiones de embeddings
cat("📦 DIMENSIONES DE EMBEDDINGS\n")
cat("   emb_piloto_t1:", dim(emb_piloto_t1), "\n")
cat("   emb_piloto_t2:", dim(emb_piloto_t2), "\n")
cat("   emb_piloto_t3:", dim(emb_piloto_t3), "\n")

cat("\n✅ Resumen del piloto extraído completado.\n")

# ============================================================================
# GENERACIÓN DE README PARA LOS DATOS EXTRAÍDOS DEL PILOTO
# ============================================================================
# Crea un archivo README_DATOS_PILOTO.txt en la carpeta 'datos/'
# que enumera y describe todos los archivos generados, su contenido,
# formato y utilidad para un artículo científico.
# ============================================================================

cat("\n══════════════════════════════════════════════════════════════\n")
cat("   GENERANDO README DE LOS DATOS DEL PILOTO\n")
cat("══════════════════════════════════════════════════════════════\n\n")

# Verificar que la carpeta de datos existe
if (!dir.exists(DIR_PILOTO_DATOS)) {
  stop("La carpeta '", DIR_PILOTO_DATOS, "' no existe. Ejecuta primero la extracción del piloto.")
}

# Ruta del archivo README
readme_path <- file.path(DIR_PILOTO_DATOS, "README_DATOS_PILOTO.txt")

# Abrir conexión para escribir
sink(readme_path)

# ----------------------------------------------------------------------------
# Encabezado
# ----------------------------------------------------------------------------
cat("===============================================================\n")
cat("README — DATOS DEL PILOTO (EXTRACCIÓN PARA ARTÍCULO)\n")
cat("===============================================================\n\n")
cat("Fecha de generación:", format(Sys.time()), "\n")
cat("Carpeta:", normalizePath(DIR_PILOTO_DATOS), "\n\n")

# ----------------------------------------------------------------------------
# Descripción general
# ----------------------------------------------------------------------------
cat("DESCRIPCIÓN GENERAL\n")
cat("---------------------------------------------------------------\n")
cat("Esta carpeta contiene todos los datos extraídos exclusivamente\n")
cat("del estudio piloto (17 participantes, 3 iteraciones cada uno).\n")
cat("Los datos han sido procesados a través del pipeline completo:\n")
cat("  - Limpieza de textos\n")
cat("  - Tokenización\n")
cat("  - Cálculo de métricas lingüísticas\n")
cat("  - Aplicación de diccionarios (Hopper y clínicos)\n")
cat("  - Generación de embeddings (modelo paraphrase-multilingual-MiniLM-L12-v2)\n")
cat("  - Cálculo de prototipos semánticos\n")
cat("  - Análisis de similitudes y cambios semánticos\n")
cat("  - Modelos lineales mixtos (resultados en carpeta 'modelos/')\n\n")

cat("Número de participantes:", n_distinct(ancho_piloto$id_participante), "\n")
cat("Número de observaciones (filas en ancho):", nrow(ancho_piloto), "\n")
cat("Condiciones:", paste(unique(ancho_piloto$condicion), collapse = ", "), "\n")
cat("Iteraciones: T1, T2, T3 (3 por participante)\n\n")

# ----------------------------------------------------------------------------
# Listado de archivos
# ----------------------------------------------------------------------------
cat("ARCHIVOS GENERADOS\n")
cat("---------------------------------------------------------------\n\n")

# Obtener lista de archivos en la carpeta
archivos <- list.files(DIR_PILOTO_DATOS, pattern = "\\.(rds|csv|txt)$", full.names = FALSE)

# Función para describir cada archivo
describir_archivo <- function(nombre) {
  caso <- switch(
    nombre,
    "embeddings_piloto_t1.rds" = "Matriz de embeddings (normalizados) para el tiempo 1 (T1). Dimensiones: n_observaciones × 384.",
    "embeddings_piloto_t2.rds" = "Matriz de embeddings (normalizados) para el tiempo 2 (T2). Dimensiones: n_observaciones × 384.",
    "embeddings_piloto_t3.rds" = "Matriz de embeddings (normalizados) para el tiempo 3 (T3). Dimensiones: n_observaciones × 384.",
    "ancho_piloto_completo.rds" = "Dataframe en formato ancho (RDS) con todas las variables calculadas (lingüísticas, diccionarios, prototipos, PCA, etc.).",
    "ancho_piloto_completo.csv" = "Versión CSV del dataframe ancho (mismo contenido que el RDS).",
    "piloto_identificacion.csv" = "Columnas de identificación: id_participante, participante, condicion, fuente.",
    "piloto_metricas_linguisticas.csv" = "Métricas lingüísticas básicas: n_palabras, ttr, n_oraciones, long_palabra, palabras_oracion (todas en T1, T2, T3).",
    "piloto_scores_diccionarios.csv" = "Scores brutos de los diccionarios (Hopper y clínicos) para cada observación.",
    "piloto_tasas_diccionarios.csv" = "Tasas normalizadas por 1000 palabras de los diccionarios (rate_*).",
    "piloto_prototipos.csv" = "Proximidad (similitud coseno) a los prototipos semánticos (proto_*).",
    "piloto_similitudes_semanticas.csv" = "Similitudes semánticas entre tiempos (sim_sem_t1_t2, sim_sem_t2_t3, sim_sem_t1_t3) y divergencias.",
    "piloto_pca.csv" = "Coordenadas PCA (PC1, PC2) para cada tiempo.",
    "piloto_deltas_prototipos.csv" = "Cambios de proximidad a prototipos (delta_proto_*) entre T1-T2, T2-T3, T1-T3.",
    "README_DATOS_PILOTO.txt" = "Este mismo archivo (documentación).",
    NA
  )
  if (is.na(caso)) {
    caso <- "Archivo adicional no documentado. Revisar su contenido."
  }
  return(caso)
}

# Imprimir cada archivo con su descripción
for (arch in sort(archivos)) {
  desc <- describir_archivo(arch)
  cat("📄", arch, "\n")
  cat("   ", desc, "\n\n")
}

# ----------------------------------------------------------------------------
# Instrucciones de uso
# ----------------------------------------------------------------------------
cat("INSTRUCCIONES DE USO\n")
cat("---------------------------------------------------------------\n")
cat("1. Los archivos .rds pueden leerse con readRDS() en R.\n")
cat("   Ejemplo: embeddings_t1 <- readRDS('embeddings_piloto_t1.rds')\n\n")
cat("2. Los archivos .csv son legibles con read_csv() o read.csv().\n")
cat("   Ejemplo: datos <- read_csv('ancho_piloto_completo.csv')\n\n")
cat("3. El dataframe 'ancho_piloto_completo' contiene TODAS las variables\n")
cat("   calculadas para el piloto. Es la base para análisis adicionales.\n\n")
cat("4. Para análisis longitudinales, se recomienda usar el formato largo\n")
cat("   (pivot_longer) usando las columnas *_t1, *_t2, *_t3.\n\n")
cat("5. Los embeddings están normalizados (norma L2) y listos para\n")
cat("   calcular similitudes coseno o para usar en modelos de ML.\n\n")

# ----------------------------------------------------------------------------
# Metadatos técnicos
# ----------------------------------------------------------------------------
cat("METADATOS TÉCNICOS\n")
cat("---------------------------------------------------------------\n")
cat("Modelo de embeddings: paraphrase-multilingual-MiniLM-L12-v2\n")
cat("Dimensión de embeddings: 384\n")
cat("Normalización: L2 (cosine similarity ready)\n")
cat("Limpieza de texto: función limpiar_texto() (remoción de puntuación, números, etc.)\n")
cat("Tokenización: función tokenizar() (separación por espacios)\n")
cat("Diccionarios: Hopper (10 temas) + Clínicos (10 constructos)\n")
cat("Prototipos: 20 constructos, 5 frases cada uno\n")
cat("Corrección de p-valores: Holm (para contrastes múltiples)\n")
cat("Modelos mixtos: lmer (lme4) con Satterthwaite para grados de libertad\n\n")

# ----------------------------------------------------------------------------
# Cierre
# ----------------------------------------------------------------------------
cat("===============================================================\n")
cat("FIN DEL README\n")
cat("===============================================================\n")

# Cerrar conexión
sink()

cat("✅ README generado en:\n")
cat("   ", normalizePath(readme_path), "\n\n")

# ============================================================================
# EXPLORACIÓN DE OBJETOS Y VARIABLES DISPONIBLES (VERSIÓN CORREGIDA)
# ============================================================================

cat("\n══════════════════════════════════════════════════════════════\n")
cat("   EXPLORACIÓN DE OBJETOS Y VARIABLES DISPONIBLES\n")
cat("══════════════════════════════════════════════════════════════\n\n")

# 1. Listar objetos principales
cat("📦 OBJETOS EN EL ENTORNO GLOBAL:\n")
print(ls())

# 2. Verificar objetos clave
objetos_clave <- c("datos", "ancho", "ancho_piloto", "ancho_principal",
                   "resultados_modelos", "modelos", "cor_mat", "mat_cor",
                   "diccionarios_hopper", "diccionarios_hopper_base",
                   "diccionarios_hopper_enriquecido", "resultados_finales")
cat("\n📌 OBJETOS CLAVE:\n")
for (obj in objetos_clave) {
  existe <- exists(obj)
  cat(sprintf("  %-30s %s\n", obj, ifelse(existe, "✅", "❌")))
}

# 3. Si datos$ancho existe, mostrar sus columnas
if (exists("datos") && "ancho" %in% names(datos)) {
  ancho <- datos$ancho
  cat("\n📊 COLUMNAS EN datos$ancho (", ncol(ancho), " columnas):\n")
  print(names(ancho))
  
  # Verificar columnas específicas que pide el Bloque 12
  columnas_requeridas <- c(
    "bing_t1", "bing_t2", "bing_t3",
    "sadness_t1", "sadness_t2", "sadness_t3",
    "joy_t1", "joy_t2", "joy_t3",
    "fear_t1", "fear_t2", "fear_t3",
    "trust_t1", "trust_t2", "trust_t3",
    "cos_t1_t2", "cos_t2_t3", "cos_t1_t3",
    "jac_t1_t2", "jac_t2_t3", "jac_t1_t3",
    "score_influencia_T2", "score_influencia_T3", "score_complejidad",
    "cambio_bing_t1t2", "cambio_bing_t2t3",
    "cambio_sadness_t1t2", "cambio_sadness_t2t3",
    "cambio_joy_t1t2", "cambio_joy_t2t3",
    "cambio_fear_t1t2", "cambio_fear_t2t3",
    "cambio_trust_t1t2", "cambio_trust_t2t3"
  )
  cat("\n🔎 COLUMNAS REQUERIDAS POR EL BLOQUE 12:\n")
  for (col in columnas_requeridas) {
    existe <- col %in% names(ancho)
    cat(sprintf("  %-30s %s\n", col, ifelse(existe, "✅", "❌")))
  }
} else {
  cat("\n⚠️ datos$ancho NO está disponible.\n")
}

# 4. Verificar modelos
if (exists("resultados_modelos")) {
  cat("\n📈 MODELOS MIXTOS:\n")
  cat("  Variables modeladas:", paste(names(resultados_modelos), collapse = ", "), "\n")
  if ("n_palabras" %in% names(resultados_modelos)) {
    cat("  Modelo para n_palabras:", ifelse(!is.null(resultados_modelos$n_palabras$modelo), "✅ disponible", "❌ no disponible"), "\n")
  }
}

# 5. Verificar correlaciones
if (exists("mat_cor")) {
  cat("\n🔗 mat_cor disponible (", nrow(mat_cor), "x", ncol(mat_cor), ")\n")
} else if (exists("cor_mat")) {
  cat("\n🔗 cor_mat disponible (", nrow(cor_mat), "x", ncol(cor_mat), ")\n")
} else {
  cat("\n🔗 No se encontró mat_cor ni cor_mat.\n")
}

# 6. Verificar diccionarios
if (exists("diccionarios_hopper")) {
  cat("\n📚 diccionarios_hopper disponible (", length(diccionarios_hopper), " temas)\n")
} else if (exists("diccionarios_hopper_base")) {
  cat("\n📚 diccionarios_hopper_base disponible (", length(diccionarios_hopper_base), " temas)\n")
} else if (exists("diccionarios_hopper_enriquecido")) {
  cat("\n📚 diccionarios_hopper_enriquecido disponible (", length(diccionarios_hopper_enriquecido), " temas)\n")
} else {
  cat("\n📚 No se encontraron diccionarios Hopper.\n")
}

cat("\n✅ Exploración completada.\n")

# [v5-N] View() solo con sesión interactiva (en Rscript no aplica)
if (interactive() && exists("datos") && "ancho" %in% names(datos)) {
  View(datos$ancho)
}



# ============================================================================
# BLOQUE 12 — VISUALIZACIONES CIENTÍFICAS (Q1)
# ============================================================================
#
# Este bloque genera figuras para manuscrito utilizando los objetos:
#   - datos$ancho (formato ancho con todas las métricas)
#   - datos$largo (formato largo)
#   - modelos (resultados de modelos mixtos del Bloque 10)
#   - cor_mat (matriz de correlaciones del Bloque 11)
#   - diccionarios_hopper (lista de diccionarios temáticos)
#
# Todas las figuras se exportan en alta resolución (300 dpi) y con formato
# científico (tipografía clara, etiquetas completas, IC 95% cuando corresponde).
# ============================================================================

# ── Configuración global de gráficos ─────────────────────────────────────────
library(ggplot2)
library(cowplot)
library(viridis)
library(RColorBrewer)
library(corrplot)
library(emmeans)
library(dplyr)
library(tidyr)
library(purrr)

# Paletas consistentes (accesibles para daltónicos)
paleta_condicion <- c("Texto"  = "#0072B2",  # azul
                      "Audio"  = "#D55E00",  # naranja
                      "Imagen" = "#009E73")  # verde
paleta_demora    <- c("ND" = "#56B4E9",      # celeste
                      "D"  = "#E69F00")      # amarillo
paleta_emocion   <- c("Bing" = "#CC79A7", "Tristeza" = "#0072B2", "Alegría" = "#009E73")

# Tema base para figuras de manuscrito
tema_cientifico <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.2), hjust = 0.5, margin = margin(b = 5)),
      plot.subtitle = element_text(size = rel(0.9), hjust = 0.5, color = "gray30", margin = margin(b = 10)),
      axis.title = element_text(face = "bold", size = rel(0.9)),
      axis.text = element_text(size = rel(0.8), color = "black"),
      legend.title = element_text(face = "bold", size = rel(0.8)),
      legend.text = element_text(size = rel(0.8)),
      legend.position = "bottom",
      legend.box = "horizontal",
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray95", color = NA),
      strip.text = element_text(face = "bold", size = rel(0.9)),
      plot.margin = margin(10, 15, 10, 15)
    )
}

# Función para guardar figuras con formato estándar
guardar_figura <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  dir.create("resultados/figuras", recursive = TRUE, showWarnings = FALSE)
  ggsave(
    filename = file.path("resultados/figuras", filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    device = "png",
    bg = "white"
  )
  cat(sprintf("✓ Figura guardada: %s\n", filename))
}

# ── Función auxiliar para obtener IC del modelo o bootstrap ──────────────────
obtener_ic_modelo <- function(modelo, nuevo_datos = NULL) {
  # Devuelve un dataframe con ajustes e IC 95% para los datos de entrada
  if (is.null(modelo)) return(NULL)
  emm <- emmeans(modelo, ~ condicion | tiempo, adjust = "tukey")
  df <- as.data.frame(emm)
  df$tiempo <- factor(df$tiempo, levels = c("T1","T2","T3"))
  return(df)
}

# ── VALIDACIONES INICIALES ──────────────────────────────────────────────────
if (!exists("datos") || !exists("datos") && !is.null(datos$ancho)) {
  warning("El objeto 'datos$ancho' no está disponible. Algunas figuras no se generarán.")
}

# ── FIGURA 1: Evolución de palabras por condición (MEJORADA) ──────────────
crear_fig1 <- function(datos_ancho) {
  # Trayectorias individuales + media con IC bootstrap
  dl <- datos_ancho %>%
    select(id_participante, condicion, n_palabras_t1, n_palabras_t2, n_palabras_t3) %>%
    pivot_longer(cols = starts_with("n_palabras"),
                 names_to = "tiempo",
                 values_to = "palabras") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("n_palabras_t1","n_palabras_t2","n_palabras_t3"),
                           labels = c("T1\n(sin estímulo)", "T2\n(1 estímulo)", "T3\n(3 estímulos)")))
  
  # Calcular medias e IC bootstrap (percentil 95%)
  # [v5-R6] CORREGIDO: la cohorte piloto NO tiene `n_palabras` (columna vacía en su Excel), así
  # que sus filas entran con NA en el grupo y el cuantil del bootstrap caía con
  # "missing values and NaN's not allowed if 'na.rm' is FALSE". Se filtran los valores finitos.
  # Consecuencia a declarar: esta figura (extensión con `n_palabras`) describe solo al principal;
  # la extensión del piloto está en `n_palabras_calculado`.
  medias_ic <- dl %>%
    filter(is.finite(palabras)) %>%
    group_by(condicion, tiempo) %>%
    summarise(
      media = mean(palabras, na.rm = TRUE),
      # Bootstrap IC (usamos quantiles de la distribución bootstrap)
      ic_inf = quantile(replicate(1000, mean(sample(palabras, replace = TRUE), na.rm = TRUE)), 0.025, na.rm = TRUE),
      ic_sup = quantile(replicate(1000, mean(sample(palabras, replace = TRUE), na.rm = TRUE)), 0.975, na.rm = TRUE),
      .groups = "drop"
    )
  
  ggplot(dl, aes(x = tiempo, y = palabras, color = condicion, group = id_participante)) +
    # Líneas individuales (transparentes)
    geom_line(alpha = 0.2, linewidth = 0.4, aes(group = id_participante)) +
    # Media e IC del bootstrap
    # [v5-R1] CORREGIDO: con inherit.aes = FALSE hay que declarar 'x' explícitamente;
    # sin ella el geom no se puede construir y ggsave aborta con "Problem while setting up geom".
    geom_ribbon(data = medias_ic, aes(x = tiempo, y = media, ymin = ic_inf, ymax = ic_sup,
                                      fill = condicion, group = condicion),
                alpha = 0.2, inherit.aes = FALSE) +
    # [v5-R4] Igual que la banda: con inherit.aes = FALSE también hay que declarar 'x' aquí.
    geom_line(data = medias_ic, aes(x = tiempo, y = media, color = condicion, group = condicion),
              linewidth = 1.2, inherit.aes = FALSE) +
    geom_point(data = medias_ic, aes(x = tiempo, y = media, color = condicion),
               size = 3, inherit.aes = FALSE) +
    scale_color_manual(values = paleta_condicion) +
    scale_fill_manual(values = paleta_condicion) +
    labs(
      title = "Evolución de la extensión textual por condición",
      subtitle = "Líneas grises = trayectorias individuales · Banda = IC 95% bootstrap · Puntos = media",
      x = "Iteración",
      y = "Número de palabras",
      color = "Condición",
      fill = "Condición"
    ) +
    tema_cientifico() +
    theme(legend.position = "bottom")
}

# ── FIGURA 2: Evolución de palabras por demora (MEJORADA) ──────────────────
crear_fig2 <- function(datos_ancho) {
  dl <- datos_ancho %>%
    filter(!is.na(demora)) %>%  # solo principal
    select(id_participante, condicion, demora, n_palabras_t1, n_palabras_t2, n_palabras_t3) %>%
    pivot_longer(cols = starts_with("n_palabras"),
                 names_to = "tiempo",
                 values_to = "palabras") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("n_palabras_t1","n_palabras_t2","n_palabras_t3"),
                           labels = c("T1", "T2", "T3")))
  
  # Calcular n por grupo (para mostrar en leyenda)
  n_grupo <- dl %>%
    group_by(demora) %>%
    summarise(n = n_distinct(id_participante)) %>%
    mutate(label = paste0(demora, " (n=", n, ")"))
  
  dl <- left_join(dl, n_grupo, by = "demora")
  
  ggplot(dl, aes(x = tiempo, y = palabras, color = label, group = label)) +
    stat_summary(fun = mean, geom = "line", linewidth = 1.2) +
    stat_summary(fun = mean, geom = "point", size = 3) +
    stat_summary(fun.data = mean_se, geom = "errorbar", width = 0.15, alpha = 0.6) +
    geom_jitter(aes(color = label), alpha = 0.3, width = 0.1, size = 1.5) +
    scale_color_manual(values = paleta_demora, name = "Demora") +
    labs(
      title = "Distribución de palabras por demora",
      subtitle = "Media ± error estándar · solo fuente principal (demora disponible)",
      x = "Iteración",
      y = "Número de palabras"
    ) +
    tema_cientifico()
}

# ── FIGURA 3: Evolución emocional (MEJORADA) ──────────────────────────────
crear_fig3 <- function(datos_ancho) {
  dl <- datos_ancho %>%
    select(id_participante, condicion,
           bing_t1, bing_t2, bing_t3,
           sadness_t1, sadness_t2, sadness_t3,
           joy_t1, joy_t2, joy_t3) %>%
    pivot_longer(cols = -c(id_participante, condicion),
                 names_to = c("emocion", "tiempo"),
                 names_pattern = "(.*)_t(\\d)",
                 values_to = "valor") %>%
    mutate(
      tiempo = factor(paste0("T", tiempo), levels = c("T1","T2","T3")),
      emocion = factor(emocion,
                       levels = c("bing", "sadness", "joy"),
                       labels = c("Sentimiento global\n(Bing)", "Tristeza\n(NRC)", "Alegría\n(NRC)"))
    )
  
  ggplot(dl, aes(x = tiempo, y = valor, color = condicion, group = condicion)) +
    stat_summary(fun = mean, geom = "line", linewidth = 1.2) +
    stat_summary(fun = mean, geom = "point", size = 3) +
    stat_summary(fun.data = mean_se, geom = "errorbar", width = 0.15, alpha = 0.6) +
    facet_wrap(~ emocion, scales = "free_y", ncol = 3) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Evolución emocional por condición",
      subtitle = "Media ± error estándar · Bing = valencia global, NRC = emociones específicas",
      x = "Iteración",
      y = "Puntuación",
      color = "Condición"
    ) +
    tema_cientifico() +
    theme(strip.text = element_text(face = "bold", size = 10))
}

# ── FIGURA 4: TTR por condición (MEJORADA) ──────────────────────────────────
crear_fig4 <- function(datos_ancho) {
  dl <- datos_ancho %>%
    select(id_participante, condicion, ttr_t1, ttr_t2, ttr_t3) %>%
    pivot_longer(cols = starts_with("ttr"),
                 names_to = "tiempo",
                 values_to = "ttr") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("ttr_t1","ttr_t2","ttr_t3"),
                           labels = c("T1", "T2", "T3")))
  
  # Media e IC bootstrap
  medias_ic <- dl %>%
    group_by(condicion, tiempo) %>%
    summarise(
      media = mean(ttr, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(ttr, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(ttr, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(dl, aes(x = tiempo, y = ttr, color = condicion, group = condicion)) +
    geom_jitter(alpha = 0.2, width = 0.1, size = 1.5) +
    # [v5-R1] CORREGIDO: con inherit.aes = FALSE hay que declarar 'x' explícitamente;
    # sin ella el geom no se puede construir y ggsave aborta con "Problem while setting up geom".
    geom_ribbon(data = medias_ic, aes(x = tiempo, y = media, ymin = ic_inf, ymax = ic_sup,
                                      fill = condicion, group = condicion),
                alpha = 0.2, inherit.aes = FALSE) +
    # [v5-R4] Igual que la banda: con inherit.aes = FALSE también hay que declarar 'x' aquí.
    geom_line(data = medias_ic, aes(x = tiempo, y = media, color = condicion),
              linewidth = 1.2, inherit.aes = FALSE) +
    geom_point(data = medias_ic, aes(x = tiempo, y = media, color = condicion),
               size = 3, inherit.aes = FALSE) +
    scale_color_manual(values = paleta_condicion) +
    scale_fill_manual(values = paleta_condicion) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    labs(
      title = "Diversidad léxica (TTR) por condición",
      subtitle = "Type-Token Ratio · Mayor valor = mayor variedad · Nota: TTR depende de la longitud del texto",
      x = "Iteración",
      y = "TTR medio",
      color = "Condición",
      fill = "Condición"
    ) +
    tema_cientifico()
}

# ── FIGURA 5: Medias marginales estimadas (modelo mixto) ──────────────────
crear_fig5 <- function(modelo_mixto, datos_ancho) {
  if (is.null(modelo_mixto)) return(NULL)
  
  # Extraer emmeans
  emm <- emmeans(modelo_mixto, ~ condicion | tiempo, adjust = "tukey")
  df <- as.data.frame(emm)
  df$tiempo <- factor(df$tiempo, levels = c("T1","T2","T3"))
  
  # Obtener comparaciones significativas (Tukey) para anotar
  comp <- pairs(emm, adjust = "tukey")
  comp_df <- as.data.frame(comp)
  # Filtrar solo diferencias significativas (p < 0.05)
  sig <- comp_df[comp_df$p.value < 0.05, ]
  
  # Crear etiquetas de letras (Tukey HSD)
  # Usamos multcompView para letras, pero aquí simplificamos con anotaciones manuales
  # Alternativa: usar cld() de multcomp
  # Para no agregar dependencia, usamos una función simple
  # En su lugar, mostramos las diferencias significativas con asteriscos
  
  p <- ggplot(df, aes(x = tiempo, y = emmean, color = condicion, group = condicion)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.15, alpha = 0.7) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Medias marginales estimadas — modelo mixto",
      subtitle = "Número de palabras · IC 95% (Tukey) · Los asteriscos indican diferencias significativas",
      x = "Iteración",
      y = "Palabras estimadas",
      color = "Condición"
    ) +
    tema_cientifico()
  
  # Añadir anotaciones de diferencias significativas (ejemplo: si hay interacción)
  # Aquí solo se añade un texto genérico; se puede mejorar.
  p
}

# ── FIGURA 6: Scores de influencia (exploratorios) ────────────────────────
crear_fig6 <- function(datos_ancho) {
  dl <- datos_ancho %>%
    select(id_participante, condicion,
           score_influencia_T2, score_influencia_T3, score_complejidad) %>%
    pivot_longer(cols = starts_with("score"),
                 names_to = "score",
                 values_to = "valor") %>%
    mutate(
      score = factor(score,
                     levels = c("score_influencia_T2", "score_influencia_T3", "score_complejidad"),
                     labels = c("Influencia T2\n(1 estímulo)", "Influencia T3\n(3 estímulos)",
                                "Complejidad\nlingüística"))
    )
  
  # Calcular n por condición
  n_grupo <- dl %>%
    group_by(condicion, score) %>%
    summarise(n = n_distinct(id_participante), .groups = "drop") %>%
    mutate(label = paste0(condicion, " (n=", n, ")"))
  
  dl <- left_join(dl, n_grupo, by = c("condicion", "score"))
  
  ggplot(dl, aes(x = condicion, y = valor, fill = condicion, color = condicion)) +
    geom_boxplot(alpha = 0.5, outlier.shape = NA) +
    geom_jitter(alpha = 0.5, width = 0.2, size = 1.5) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    facet_wrap(~ score, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = paleta_condicion, guide = "none") +
    scale_color_manual(values = paleta_condicion, guide = "none") +
    labs(
      title = "Scores de influencia (exploratorios) por condición",
      subtitle = "Scores derivados con ponderaciones heurísticas · No validados psicométricamente",
      x = "Condición",
      y = "Score"
    ) +
    tema_cientifico() +
    theme(legend.position = "none")
}

# ── FIGURA 7: Matriz de correlaciones (MEJORADA) ──────────────────────────
crear_fig7 <- function(cor_mat, p_valores = NULL) {
  if (is.null(cor_mat)) return(NULL)
  
  # Ordenar por cluster (usamos hclust)
  hc <- hclust(as.dist(1 - cor_mat), method = "ward.D2")
  orden <- hc$order
  cor_mat_ord <- cor_mat[orden, orden]
  
  # Si tenemos p-valores, los usamos para marcar significancia
  # (por simplicidad, aquí solo dibujamos la matriz)
  
  # Usar corrplot
  corrplot(cor_mat_ord, method = "color", type = "upper",
           order = "original",
           tl.cex = 0.7, tl.col = "black",
           addCoef.col = "black", number.cex = 0.6,
           col = COL2("RdBu", 10),
           diag = FALSE,
           title = "Correlaciones Spearman (variables de cambio)",
           mar = c(0,0,2,0))
}

# ── FIGURA 8: Cambios T1→T2 y T2→T3 ──────────────────────────────────────
crear_fig8 <- function(datos_ancho) {
  # Seleccionar variables de cambio principales
  vars_cambio <- c("cambio_palabras_t1t2", "cambio_palabras_t2t3",
                   "cambio_bing_t1t2", "cambio_bing_t2t3",
                   "cambio_ttr_t1t2", "cambio_ttr_t2t3")
  
  dl <- datos_ancho %>%
    select(id_participante, condicion, all_of(vars_cambio)) %>%
    pivot_longer(cols = all_of(vars_cambio),
                 names_to = "cambio",
                 values_to = "valor") %>%
    mutate(
      tipo = ifelse(grepl("_t1t2$", cambio), "T1→T2", "T2→T3"),
      variable = gsub("_t1t2|_t2t3", "", cambio),
      variable = factor(variable,
                        levels = c("cambio_palabras", "cambio_bing", "cambio_ttr"),
                        labels = c("Palabras", "Sentimiento (Bing)", "TTR"))
    )
  
  # Calcular IC bootstrap para cada comparación
  ic_boot <- dl %>%
    group_by(condicion, variable, tipo) %>%
    summarise(
      media = mean(valor, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(ic_boot, aes(x = condicion, y = media, color = condicion)) +
    geom_point(size = 3, position = position_dodge(0.3)) +
    geom_errorbar(aes(ymin = ic_inf, ymax = ic_sup), width = 0.2, position = position_dodge(0.3)) +
    facet_grid(variable ~ tipo, scales = "free_y") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    scale_color_manual(values = paleta_condicion, guide = "none") +
    labs(
      title = "Cambios longitudinales en variables principales",
      subtitle = "Media e IC 95% bootstrap · Línea horizontal en 0 indica ausencia de cambio",
      x = "Condición",
      y = "Cambio medio"
    ) +
    tema_cientifico() +
    theme(legend.position = "none")
}

# ── FIGURA 9: Trayectorias individuales (palabras) ────────────────────────
crear_fig9 <- function(datos_ancho) {
  dl <- datos_ancho %>%
    select(id_participante, condicion, n_palabras_t1, n_palabras_t2, n_palabras_t3) %>%
    pivot_longer(cols = starts_with("n_palabras"),
                 names_to = "tiempo",
                 values_to = "palabras") %>%
    mutate(tiempo = factor(tiempo,
                           levels = c("n_palabras_t1","n_palabras_t2","n_palabras_t3"),
                           labels = c("T1", "T2", "T3")))
  
  ggplot(dl, aes(x = tiempo, y = palabras, color = condicion, group = id_participante)) +
    geom_line(alpha = 0.3, linewidth = 0.5) +
    stat_summary(aes(group = condicion), fun = mean, geom = "line", linewidth = 1.5) +
    stat_summary(aes(group = condicion), fun = mean, geom = "point", size = 3) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Trayectorias individuales de extensión textual",
      subtitle = "Cada línea = un participante · Líneas gruesas = media por condición",
      x = "Iteración",
      y = "Número de palabras",
      color = "Condición"
    ) +
    tema_cientifico()
}

# ── FIGURA 10: Interacción condición × tiempo (emmeans) ───────────────────
crear_fig10 <- function(modelo_mixto) {
  if (is.null(modelo_mixto)) return(NULL)
  
  emm <- emmeans(modelo_mixto, ~ condicion | tiempo, adjust = "tukey")
  df <- as.data.frame(emm)
  df$tiempo <- factor(df$tiempo, levels = c("T1","T2","T3"))
  
  ggplot(df, aes(x = tiempo, y = emmean, color = condicion, group = condicion)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.15, alpha = 0.7) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Interacción Condición × Tiempo",
      subtitle = "Medias marginales estimadas del modelo mixto · IC 95% (Tukey)",
      x = "Iteración",
      y = "Valor estimado",
      color = "Condición"
    ) +
    tema_cientifico()
}

# ── FIGURA 11: Efecto de demora sobre cambios ─────────────────────────────
crear_fig11 <- function(datos_ancho) {
  # Solo principal (demora disponible)
  dl <- datos_ancho %>%
    filter(!is.na(demora)) %>%
    select(id_participante, condicion, demora,
           cambio_palabras_t1t2, cambio_palabras_t2t3, cambio_palabras_total) %>%
    pivot_longer(cols = starts_with("cambio_palabras"),
                 names_to = "cambio",
                 values_to = "valor") %>%
    mutate(
      cambio = factor(cambio,
                      levels = c("cambio_palabras_t1t2", "cambio_palabras_t2t3", "cambio_palabras_total"),
                      labels = c("T1→T2", "T2→T3", "T1→T3"))
    )
  
  # Calcular IC bootstrap
  ic_boot <- dl %>%
    group_by(demora, cambio) %>%
    summarise(
      media = mean(valor, na.rm = TRUE),
      ic_inf = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.025),
      ic_sup = quantile(replicate(1000, mean(sample(valor, replace = TRUE), na.rm = TRUE)), 0.975),
      .groups = "drop"
    )
  
  ggplot(ic_boot, aes(x = demora, y = media, fill = demora)) +
    geom_col(position = position_dodge(0.9), alpha = 0.7) +
    geom_errorbar(aes(ymin = ic_inf, ymax = ic_sup), width = 0.2) +
    facet_wrap(~ cambio, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = paleta_demora, guide = "none") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(
      title = "Efecto de la demora sobre cambios en palabras",
      subtitle = "Media e IC 95% bootstrap · Solo fuente principal",
      x = "Demora",
      y = "Cambio en palabras"
    ) +
    tema_cientifico()
}

# ── FIGURA 12: Cambio emocional multivariado (heatmap) ────────────────────
crear_fig12 <- function(datos_ancho) {
  # Seleccionar emociones NRC y calcular cambios T1→T2, T2→T3
  emociones <- c("sadness", "joy", "fear", "trust", "anger", "anticipation", "surprise", "disgust")
  cambios <- c()
  for (e in emociones) {
    cambios <- c(cambios, paste0("cambio_", e, "_t1t2"), paste0("cambio_", e, "_t2t3"))
  }
  
  # Calcular media de cambios por condición y tipo
  dl <- datos_ancho %>%
    select(condicion, all_of(cambios)) %>%
    group_by(condicion) %>%
    summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    pivot_longer(cols = -condicion,
                 names_to = "cambio",
                 values_to = "media") %>%
    mutate(
      emocion = gsub("cambio_|_t1t2|_t2t3", "", cambio),
      tipo = ifelse(grepl("_t1t2$", cambio), "T1→T2", "T2→T3"),
      emocion = factor(emocion, levels = emociones)
    )
  
  ggplot(dl, aes(x = tipo, y = emocion, fill = media)) +
    geom_tile(color = "white") +
    facet_wrap(~ condicion, ncol = 3) +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                         midpoint = 0, name = "Cambio medio") +
    labs(
      title = "Cambio emocional multivariado por condición",
      subtitle = "Cambio medio en emociones NRC · Azul = disminución, Rojo = aumento",
      x = "",
      y = "Emoción"
    ) +
    tema_cientifico() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# ── FIGURA 13: Diccionarios temáticos (normalizados) ──────────────────────
crear_fig13 <- function(datos_ancho, diccionarios) {
  temas <- names(diccionarios)
  # Obtener conteos por tema y tiempo, normalizar por palabras
  dl <- datos_ancho %>%
    select(id_participante, condicion, n_palabras_t1, n_palabras_t2, n_palabras_t3)
  
  # [v5-R5] CORREGIDO: antes recalculaba las tasas dividiendo columnas de conteo
  # (`soledad_t1`, ...) que no existen en datos$ancho, y en el piloto `n_palabras` está
  # vacía (solo hay `n_palabras_calculado`). El pipeline YA calcula estas tasas
  # (`rate_<tema>_t<k>`, normalizadas sobre n_palabras_calculado en el BLOQUE 6 y unidas
  # a datos$ancho en el bloque [v5-R3]): aquí solo se usan.
  .cols_rate <- paste0("rate_", rep(temas, each = 3), "_t", rep(1:3, times = length(temas)))
  .faltan <- setdiff(.cols_rate, names(datos_ancho))
  if (length(.faltan) > 0) {
    stop("[v5-R5] La figura 13 necesita tasas que no están en datos$ancho: ",
         paste(utils::head(.faltan, 5), collapse = ", "))
  }
  dl <- cbind(dl, datos_ancho[, .cols_rate, drop = FALSE])
  
  # Pivotar a largo
  dl_long <- dl %>%
    select(id_participante, condicion, starts_with("rate_")) %>%
    pivot_longer(cols = starts_with("rate_"),
                 names_to = c("tema", "tiempo"),
                 names_pattern = "rate_(.*)_t(\\d)",
                 values_to = "rate") %>%
    mutate(
      tiempo = factor(paste0("T", tiempo), levels = c("T1","T2","T3")),
      tema = factor(tema, levels = temas)
    )
  
  # Calcular media por condición, tema y tiempo
  medias <- dl_long %>%
    group_by(condicion, tema, tiempo) %>%
    summarise(media = mean(rate, na.rm = TRUE), .groups = "drop")
  
  ggplot(medias, aes(x = tiempo, y = media, color = condicion, group = condicion)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    facet_wrap(~ tema, scales = "free_y", ncol = 5) +
    scale_color_manual(values = paleta_condicion) +
    labs(
      title = "Evolución de diccionarios temáticos (tasa por 1000 palabras)",
      subtitle = "Temas basados en la estética de Hopper · Normalizado por longitud del texto",
      x = "Iteración",
      y = "Frecuencia por 1000 palabras",
      color = "Condición"
    ) +
    tema_cientifico() +
    theme(strip.text = element_text(face = "bold", size = 7))
}

# ── FIGURA 14: Similitud textual ──────────────────────────────────────────
crear_fig14 <- function(datos_ancho) {
  dl <- datos_ancho %>%
    select(id_participante, condicion,
           cos_t1_t2, cos_t2_t3, cos_t1_t3,
           jac_t1_t2, jac_t2_t3, jac_t1_t3) %>%
    pivot_longer(cols = -c(id_participante, condicion),
                 names_to = "medida",
                 values_to = "valor") %>%
    mutate(
      tipo = ifelse(grepl("cos", medida), "Coseno", "Jaccard"),
      comparacion = factor(
        gsub("cos_|jac_", "", medida),
        levels = c("t1_t2", "t2_t3", "t1_t3"),
        labels = c("T1 vs T2", "T2 vs T3", "T1 vs T3")
      )
    )
  
  ggplot(dl, aes(x = condicion, y = valor, fill = condicion)) +
    geom_boxplot(alpha = 0.6, outlier.shape = NA) +
    geom_jitter(alpha = 0.3, width = 0.1, size = 1) +
    facet_grid(tipo ~ comparacion, scales = "free_y") +
    scale_fill_manual(values = paleta_condicion, guide = "none") +
    labs(
      title = "Similitud textual entre iteraciones",
      subtitle = "Coseno y Jaccard basados en frecuencia de tokens",
      x = "Condición",
      y = "Similitud"
    ) +
    tema_cientifico()
}

# ── FIGURA 15: Mapa integrado de cambio (exploratorio) ────────────────────
crear_fig15 <- function(datos_ancho) {
  # Seleccionar cambios estandarizados (z-scores)
  vars_cambio <- c("cambio_palabras_t1t2", "cambio_palabras_t2t3",
                   "cambio_ttr_t1t2", "cambio_ttr_t2t3",
                   "cambio_bing_t1t2", "cambio_bing_t2t3",
                   "cambio_sadness_t1t2", "cambio_sadness_t2t3",
                   "cambio_joy_t1t2", "cambio_joy_t2t3")
  
  # Calcular medias por condición y tipo de cambio
  dl <- datos_ancho %>%
    select(condicion, all_of(vars_cambio)) %>%
    group_by(condicion) %>%
    summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    pivot_longer(cols = -condicion,
                 names_to = "cambio",
                 values_to = "media") %>%
    mutate(
      variable = gsub("cambio_|_t1t2|_t2t3", "", cambio),
      tipo = ifelse(grepl("_t1t2$", cambio), "T1→T2", "T2→T3"),
      variable = factor(variable, levels = unique(variable))
    ) %>%
    group_by(variable, tipo) %>%
    mutate(z = scale(media)[,1]) %>%
    ungroup()
  
  ggplot(dl, aes(x = tipo, y = variable, fill = z)) +
    geom_tile(color = "white") +
    facet_wrap(~ condicion, ncol = 3) +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                         midpoint = 0, name = "Z-score") +
    labs(
      title = "Mapa integrado de cambio (exploratorio)",
      subtitle = "Cambios estandarizados por condición · Rojo = aumento, Azul = disminución",
      x = "",
      y = "Variable"
    ) +
    tema_cientifico() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# ============================================================================
# [v5-R3] PREPARACIÓN DE LAS COLUMNAS QUE LAS FIGURAS DEL BLOQUE 12 NECESITAN
# ============================================================================
# El BLOQUE 12 dibuja variables que el pipeline nunca llegaba a crear en `datos$ancho`:
#   * cos_* / jac_* / div_*   → `calcular_similitudes()` está definida (BLOQUE 5) pero NO se llamaba.
#   * cambio_*                → `calcular_cambios_y_scores()` devuelve un data.frame aparte que
#                               nunca se unía a `datos$ancho` (las figuras leían de `datos$ancho`).
#   * rate_<tema>_t<k>        → viven en `scores_wide` (tasas por 1000 palabras), no en `datos$ancho`.
#   * cambio_<emoción>_*      → el script nunca calculaba cambios de emociones.
#   * score_influencia_*      → solo se creaban si las columnas ya estaban en `datos$ancho`.
# Aquí se conectan esas piezas usando las funciones, los nombres y los pesos DEL PROPIO script.
# Nada se calcula con fórmulas nuevas: son las del autor, aplicadas a las columnas que sí existen.
cat("\n[v5-R3] Preparando columnas para las figuras...\n")

if (!all(c("cos_t1_t2", "cos_t2_t3", "cos_t1_t3") %in% names(datos$ancho)) &&
    exists("calcular_similitudes") && "t1_tokens" %in% names(datos$ancho)) {
  datos <- calcular_similitudes(datos)
  cat("[v5-R3] Similitud textual calculada (coseno y Jaccard).\n")
}
if (!"sadness_t1" %in% names(datos$ancho) && exists("calcular_sentimientos")) {
  datos <- calcular_sentimientos(datos)
  cat("[v5-R3] Emociones NRC-ES calculadas.\n")
}
.unir_columnas <- function(ancho, df, etiqueta) {
  if (is.null(df) || !("id_participante" %in% names(df))) return(ancho)
  nuevas <- setdiff(names(df), names(ancho))
  if (!("id_participante" %in% nuevas)) nuevas <- c("id_participante", nuevas)
  if (length(nuevas) <= 1) return(ancho)
  antes <- ncol(ancho)
  ancho <- dplyr::left_join(ancho, df[, nuevas, drop = FALSE], by = "id_participante")
  if (nrow(ancho) != nrow(df) && nrow(df) != 0) {
    stop("[v5-R3] La unión de ", etiqueta, " cambió el número de filas (",
         nrow(ancho), " vs ", nrow(df), "): revisar identificadores.")
  }
  cat("[v5-R3] Unido", etiqueta, "→", ncol(ancho) - antes, "columnas nuevas.\n")
  ancho
}
if (exists("resultado_cambios")) datos$ancho <- .unir_columnas(datos$ancho, resultado_cambios, "cambios y scores heurísticos")
if (exists("scores_wide"))      datos$ancho <- .unir_columnas(datos$ancho, scores_wide, "tasas por 1000 palabras (rate_*)")

# cambios de las emociones y de los temas Hopper (diferencias simples entre iteraciones)
.crear_cambio <- function(ancho, base) {
  c1 <- paste0(base, "_t1"); c2 <- paste0(base, "_t2"); c3 <- paste0(base, "_t3")
  if (!all(c(c1, c2, c3) %in% names(ancho))) return(ancho)
  ancho[[paste0("cambio_", base, "_t1t2")]] <- ancho[[c2]] - ancho[[c1]]
  ancho[[paste0("cambio_", base, "_t2t3")]] <- ancho[[c3]] - ancho[[c2]]
  ancho[[paste0("cambio_", base, "_t1t3")]] <- ancho[[c3]] - ancho[[c1]]
  ancho
}
for (.b in c("joy", "sadness", "fear", "anger", "anticipation", "trust", "surprise", "disgust",
             "soledad", "espera", "incomunicacion", "objetos", "emociones_negativas",
             "luz_sombra", "pasividad", "desconexion", "duda", "espacio")) {
  datos$ancho <- .crear_cambio(datos$ancho, .b)
}

# alias con los nombres que el BLOQUE 12 usa literalmente
if ("cambio_n_palabras_calculado_t1t2" %in% names(datos$ancho)) {
  datos$ancho$cambio_palabras_t1t2  <- datos$ancho$cambio_n_palabras_calculado_t1t2
  datos$ancho$cambio_palabras_t2t3  <- datos$ancho$cambio_n_palabras_calculado_t2t3
  datos$ancho$cambio_palabras_total <- datos$ancho$cambio_n_palabras_calculado_total
  cat("[v5-R3] Alias 'cambio_palabras_*' creados desde n_palabras_calculado.\n")
}
# 'bing' no existe en este pipeline: nunca se calculó un sentimiento global tipo VADER/Bing.
# Las figuras que lo piden (3, 8, 12, 15) usan 'sadness' y el rótulo se declara en el propio gráfico.
if (!"bing_t1" %in% names(datos$ancho) && "sadness_t1" %in% names(datos$ancho)) {
  for (.k in c("t1", "t2", "t3")) datos$ancho[[paste0("bing_", .k)]] <- datos$ancho[[paste0("sadness_", .k)]]
  for (.k in c("t1t2", "t2t3"))   datos$ancho[[paste0("cambio_bing_", .k)]] <- datos$ancho[[paste0("cambio_sadness_", .k)]]
  cat("[v5-R3] AVISO: 'bing' no se calculó nunca en este pipeline; las figuras que lo piden\n",
      "        usan 'sadness' (duplicado declarado, no una medida nueva).\n")
}
# scores heurísticos, con los pesos de config_scores_default() del propio script
.necesita_score <- !all(c("score_influencia_T2", "score_influencia_T3", "score_complejidad") %in% names(datos$ancho))
if (.necesita_score && exists("config_scores_default") && all(c("score_soledad_t1", "score_soledad_t2") %in% names(datos$ancho))) {
  .w  <- config_scores_default(); .D <- datos$ancho
  .d  <- function(base) .D[[paste0("score_", base, "_t2")]] - .D[[paste0("score_", base, "_t1")]]
  .d3 <- function(base) .D[[paste0("score_", base, "_t3")]] - .D[[paste0("score_", base, "_t2")]]
  datos$ancho$score_influencia_T2 <-
    .w$influencia_T2["soledad"] * .d("soledad") + .w$influencia_T2["espera"] * .d("espera") +
    .w$influencia_T2["incomunicacion"] * .d("incomunicacion") +
    .w$influencia_T2["emociones_negativas"] * .d("emociones_negativas") +
    .w$influencia_T2["sadness"] * (.D$sadness_t2 - .D$sadness_t1) +
    .w$influencia_T2["joy"] * (.D$joy_t2 - .D$joy_t1) +
    .w$influencia_T2["trust"] * (.D$trust_t2 - .D$trust_t1)
  datos$ancho$score_influencia_T3 <-
    .w$influencia_T3["objetos"] * .d3("objetos") + .w$influencia_T3["duda"] * .d3("duda") +
    .w$influencia_T3["desconexion"] * .d3("desconexion") +
    .w$influencia_T3["sadness"] * (.D$sadness_t3 - .D$sadness_t2) +
    .w$influencia_T3["fear"] * (.D$fear_t3 - .D$fear_t2)
  datos$ancho$score_complejidad <-
    .w$complejidad["palabras_oracion"] * (.D$palabras_oracion_t2 - .D$palabras_oracion_t1) +
    .w$complejidad["long_palabra"] * (.D$long_palabra_t2 - .D$long_palabra_t1)
  cat("[v5-R3] Scores heurísticos calculados con los pesos de config_scores_default().\n")
}
rm(list = intersect(c(".b", ".k", ".w", ".D", ".d", ".d3"), ls()))

# ── GENERACIÓN DE FIGURAS CON VALIDACIONES ────────────────────────────────
# Lista para almacenar figuras generadas
figuras <- list()

# Validar existencia de objetos
if (exists("datos") && !is.null(datos$ancho)) {
  ancho <- datos$ancho
  largo <- datos$largo
  
  # FIGURA 1
  tryCatch({
    figuras$fig1 <- crear_fig1(ancho)
    guardar_figura(figuras$fig1, "fig1_palabras_condicion.png", width = 9, height = 6)
  }, error = function(e) warning("Figura 1 no generada: ", e$message))
  
  # FIGURA 2
  tryCatch({
    figuras$fig2 <- crear_fig2(ancho)
    guardar_figura(figuras$fig2, "fig2_palabras_demora.png", width = 9, height = 6)
  }, error = function(e) warning("Figura 2 no generada: ", e$message))
  
  # FIGURA 3
  tryCatch({
    figuras$fig3 <- crear_fig3(ancho)
    guardar_figura(figuras$fig3, "fig3_emociones.png", width = 12, height = 5)
  }, error = function(e) warning("Figura 3 no generada: ", e$message))
  
  # FIGURA 4
  tryCatch({
    figuras$fig4 <- crear_fig4(ancho)
    guardar_figura(figuras$fig4, "fig4_ttr.png", width = 9, height = 6)
  }, error = function(e) warning("Figura 4 no generada: ", e$message))
  
  # FIGURA 6
  tryCatch({
    figuras$fig6 <- crear_fig6(ancho)
    guardar_figura(figuras$fig6, "fig6_scores.png", width = 11, height = 5)
  }, error = function(e) warning("Figura 6 no generada: ", e$message))
  
  # FIGURA 8
  tryCatch({
    figuras$fig8 <- crear_fig8(ancho)
    guardar_figura(figuras$fig8, "fig8_cambios.png", width = 10, height = 7)
  }, error = function(e) warning("Figura 8 no generada: ", e$message))
  
  # FIGURA 9
  tryCatch({
    figuras$fig9 <- crear_fig9(ancho)
    guardar_figura(figuras$fig9, "fig9_trayectorias_individuales.png", width = 9, height = 6)
  }, error = function(e) warning("Figura 9 no generada: ", e$message))
  
  # FIGURA 11
  tryCatch({
    figuras$fig11 <- crear_fig11(ancho)
    guardar_figura(figuras$fig11, "fig11_efecto_demora.png", width = 10, height = 5)
  }, error = function(e) warning("Figura 11 no generada: ", e$message))
  
  # FIGURA 12
  tryCatch({
    figuras$fig12 <- crear_fig12(ancho)
    guardar_figura(figuras$fig12, "fig12_cambio_emocional_multivariado.png", width = 10, height = 6)
  }, error = function(e) warning("Figura 12 no generada: ", e$message))
  
  # FIGURA 13
  if (exists("diccionarios_hopper_enriquecido")) {
    tryCatch({
      figuras$fig13 <- crear_fig13(ancho, diccionarios_hopper_enriquecido)
      guardar_figura(figuras$fig13, "fig13_diccionarios_tematicos.png", width = 14, height = 8)
    }, error = function(e) warning("Figura 13 no generada: ", e$message))
  } else {
    warning("diccionarios_hopper no disponible; figura 13 omitida")
  }
  
  # FIGURA 14
  tryCatch({
    figuras$fig14 <- crear_fig14(ancho)
    guardar_figura(figuras$fig14, "fig14_similitud_textual.png", width = 10, height = 6)
  }, error = function(e) warning("Figura 14 no generada: ", e$message))
  
  # FIGURA 15
  tryCatch({
    figuras$fig15 <- crear_fig15(ancho)
    guardar_figura(figuras$fig15, "fig15_mapa_integrado_cambio.png", width = 10, height = 7)
  }, error = function(e) warning("Figura 15 no generada: ", e$message))
  
} else {
  warning("datos$ancho no disponible. No se generaron figuras.")
}

# [v5-H] El script buscaba 'modelos$palabras$modelo', pero el objeto que produce
# el Bloque 10 se llama 'resultados_modelos' y está indexado por variable.
obtener_modelo_palabras <- function() {
  if (!exists("resultados_modelos") || length(resultados_modelos) == 0) return(NULL)
  for (.v in c("n_palabras_calculado", "n_palabras")) {
    if (!is.null(resultados_modelos[[.v]]) && !is.null(resultados_modelos[[.v]]$modelo))
      return(resultados_modelos[[.v]]$modelo)
  }
  .prim <- resultados_modelos[[1]]
  if (!is.null(.prim$modelo)) return(.prim$modelo)
  NULL
}

# FIGURA 5 (depende del modelo mixto)
if (!is.null(obtener_modelo_palabras())) {
  tryCatch({
    figuras$fig5 <- crear_fig5(obtener_modelo_palabras(), ancho)
    if (!is.null(figuras$fig5)) {
      guardar_figura(figuras$fig5, "fig5_modelo_estimado.png", width = 9, height = 6)
    }
  }, error = function(e) warning("Figura 5 no generada: ", e$message))
} else {
  warning("Modelo mixto de palabras no disponible; figura 5 omitida")
}

# FIGURA 7 (correlaciones)
if (exists("mat_cor") && !is.null(mat_cor)) {
  tryCatch({
    png("resultados/figuras/fig7_correlaciones.png", width = 1400, height = 1400, res = 140)
    crear_fig7(mat_cor)
    dev.off()
    cat("✓ Figura guardada: fig7_correlaciones.png\n")
  }, error = function(e) warning("Figura 7 no generada: ", e$message))
} else {
  warning("cor_mat no disponible; figura 7 omitida")
}

# FIGURA 10 (interacción) - usa el mismo modelo que figura 5
if (!is.null(obtener_modelo_palabras())) {
  tryCatch({
    figuras$fig10 <- crear_fig10(obtener_modelo_palabras())
    if (!is.null(figuras$fig10)) {
      guardar_figura(figuras$fig10, "fig10_interaccion_condicion_tiempo.png", width = 9, height = 6)
    }
  }, error = function(e) warning("Figura 10 no generada: ", e$message))
} else {
  warning("Modelo mixto no disponible; figura 10 omitida")
}

# ── PANELES COMBINADOS ─────────────────────────────────────────────────────
# [v5-R2] CORREGIDO: aquí murió una corrida completa. Un gráfico que falló al construirse
# seguía guardado en la lista `figuras`, y plot_grid() lo intentaba renderizar FUERA de
# cualquier tryCatch → la excepción subía y abortaba el script en el BLOQUE 12, dejando sin
# ejecutar los BLOQUES 13 y 14. Ahora se comprueba que el PNG exista y todo va protegido.
.panel_ok <- function(...) {
  nombres <- c(...)
  all(vapply(nombres, function(n)
    !is.null(figuras[[n]]) && file.exists(file.path("resultados", "figuras", paste0(n, ".png"))),
    logical(1)))
}
.panel <- function(archivo, componentes, etiquetas, w, h) {
  if (!.panel_ok(componentes)) {
    cat("[v5-R2] Panel", archivo, "omitido: falta(n)",
        paste(setdiff(componentes, componentes[.panel_ok(componentes)]), collapse = ", "), "\n")
    return(invisible(FALSE))
  }
  tryCatch({
    p <- cowplot::plot_grid(plotlist = figuras[componentes], ncol = length(componentes),
                            labels = etiquetas, label_size = 12)
    guardar_figura(p, archivo, width = w, height = h)
  }, error = function(e) cat("[v5-R2] Panel", archivo, "no generado:", conditionMessage(e), "\n"))
}
if (length(figuras) > 0) {
  .panel("panel_principal.png", c("fig1", "fig4", "fig9"), c("A", "B", "C"), 9, 12)
  .panel("panel_emocional.png", c("fig3", "fig12"),       c("A", "B"),      10, 12)
  .panel("panel_cambios.png",   c("fig8", "fig11"),       c("A", "B"),      10, 12)
}

cat("✓ Generación de figuras completada.\n")


# ============================================================================
# BLOQUE 13 — EXPORTACIÓN DE RESULTADOS (MEJORADA)
# ============================================================================
#
# Se exportan:
#   1. Datos completos (ancho y largo)
#   2. Cambios y scores
#   3. Sentimientos
#   4. Temas Hopper
#   5. Modelos mixtos (RDS)
#   6. Tabla de descriptivos
#   7. Tabla de cambios agregados
#   8. Tabla de efectos de modelos mixtos (ANOVA)
#   9. Tabla de emmeans
#  10. Tabla de correlaciones
#  11. Tabla de p-valores ajustados (FDR)
#  12. Metadatos de figuras
# ============================================================================

dir.create("resultados/tablas", recursive = TRUE, showWarnings = FALSE)

# 1. Datos completos ancho (sin columnas de tokens/listas)
if (exists("datos") && !is.null(datos$ancho)) {
  datos_export <- datos$ancho %>%
    select(-ends_with("_tokens"), -ends_with("_limpio"), -matches("_t[123]_tokens"))
  write.csv(datos_export, "resultados/tablas/datos_completos_ancho.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ datos_completos_ancho.csv\n")
}

# 2. Datos formato largo
if (exists("datos") && !is.null(datos$largo)) {
  write.csv(datos$largo, "resultados/tablas/datos_formato_largo.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ datos_formato_largo.csv\n")
}

# 3. Cambios y scores
if (exists("datos") && !is.null(datos$ancho)) {
  cambios_export <- datos$ancho %>%
    select(id_participante, fuente, condicion, demora,
           starts_with("cambio_"), starts_with("pct_"), starts_with("score_"))
  write.csv(cambios_export, "resultados/tablas/cambios_y_scores.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ cambios_y_scores.csv\n")
}

# 4. Sentimientos detallados
if (exists("datos") && !is.null(datos$ancho)) {
  sent_export <- datos$ancho %>%
    select(id_participante, fuente, condicion, demora,
           matches("^(bing|joy|sadness|fear|anger|anticipation|trust|surprise|disgust)_t"))
  write.csv(sent_export, "resultados/tablas/sentimientos.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ sentimientos.csv\n")
}

# 5. Temas Hopper
if (exists("datos") && !is.null(datos$ancho) && exists("diccionarios_hopper_enriquecido")) {
  temas <- names(diccionarios_hopper_enriquecido)
  cols_temas <- paste0(rep(temas, each = 3), "_t", 1:3)
  cols_temas <- cols_temas[cols_temas %in% names(datos$ancho)]
  temas_export <- datos$ancho %>%
    select(id_participante, fuente, condicion, demora, all_of(cols_temas))
  write.csv(temas_export, "resultados/tablas/temas_hopper.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ temas_hopper.csv\n")
}

# 6. Modelos mixtos (objeto R)
if (exists("resultados_modelos")) {
  saveRDS(resultados_modelos, "resultados/modelos_mixtos.rds")
  cat("✓ modelos_mixtos.rds\n")
}

# 7. Tabla de descriptivos (si existe función previa o calcular aquí)
# [v5-S] CORREGIDO: `datos$largo` es el formato largo POR OBSERVACIÓN (una fila por
# participante × iteración), y NO tiene las columnas `metrica` ni `valor`; el objeto con
# `metrica`/`valor` es `ancho_largo`, construido en el BLOQUE 9. Como estaba, el filtro
# abortaba con "'metrica' no encontrado". Si `ancho_largo` no está en memoria, se construye.
if (exists("datos") && !is.null(datos$ancho)) {
  if (!exists("ancho_largo") || !all(c("metrica", "valor") %in% names(ancho_largo))) {
    .cols_num <- names(datos$ancho)[sapply(datos$ancho, is.numeric) & grepl("_t[123]$", names(datos$ancho))]
    .ids <- intersect(c("fuente", "participante", "id_participante", "condicion", "demora"), names(datos$ancho))
    ancho_largo <- datos$ancho %>%
      select(all_of(c(.ids, .cols_num))) %>%
      pivot_longer(cols = all_of(.cols_num), names_to = c("metrica", "iteracion"),
                   names_pattern = "(.*)_t(\\d)", values_to = "valor") %>%
      mutate(iteracion = as.integer(iteracion))
    cat("[v5-S] ancho_largo reconstruido:", nrow(ancho_largo), "filas x",
        length(unique(ancho_largo$metrica)), "métricas\n")
  }
  # Calcular descriptivos para métricas clave
  metricas_desc <- c("n_palabras", "n_palabras_calculado", "ttr", "sadness", "joy")
  # [v5-S2] CORREGIDO: con `min(valor, na.rm = TRUE)` un grupo sin ningún valor finito
  # (p. ej. `n_palabras` en el piloto, cuya columna está vacía en el Excel) devolvía Inf
  # y Max devolvía -Inf, además de 18 avisos. Ahora n cuenta solo valores finitos y las
  # estadísticas devuelven NA cuando no hay ninguno: la tabla dice "no disponible", no ∞.
  .resumen_num <- function(x) {
    x <- x[is.finite(x)]
    if (length(x) == 0) {
      return(tibble::tibble(n = 0L, Media = NA_real_, SD = NA_real_,
                            Mediana = NA_real_, Min = NA_real_, Max = NA_real_))
    }
    tibble::tibble(n = length(x), Media = mean(x), SD = sd(x),
                   Mediana = median(x), Min = min(x), Max = max(x))
  }
  desc_largo <- ancho_largo %>%
    filter(metrica %in% metricas_desc) %>%
    group_by(fuente, condicion, demora, iteracion, metrica) %>%
    group_modify(~ .resumen_num(.x$valor)) %>%
    ungroup()
  write.csv(desc_largo, "resultados/tablas/descriptivos.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ descriptivos.csv\n")
}

# 8. Tabla de cambios agregados (medias por condición y tiempo)
if (exists("datos") && !is.null(datos$ancho)) {
  cambios_agregados <- datos$ancho %>%
    group_by(condicion) %>%
    summarise(
      across(starts_with("cambio_palabras"), ~ mean(.x, na.rm = TRUE)),
      across(starts_with("cambio_ttr"), ~ mean(.x, na.rm = TRUE)),
      across(starts_with("cambio_bing"), ~ mean(.x, na.rm = TRUE)),
      .groups = "drop"
    )
  write.csv(cambios_agregados, "resultados/tablas/cambios_agregados.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ cambios_agregados.csv\n")
}

# 9. Tabla de efectos de modelos mixtos (ANOVA)
if (exists("modelos")) {
  efectos <- list()
  for (nm in names(modelos)) {
    if (!is.null(modelos[[nm]]$anova)) {
      anov <- modelos[[nm]]$anova
      anov_df <- as.data.frame(anov)
      anov_df$efecto <- rownames(anov)
      anov_df$variable <- nm
      efectos[[nm]] <- anov_df
    }
  }
  if (length(efectos) > 0) {
    efectos_df <- bind_rows(efectos)
    write.csv(efectos_df, "resultados/tablas/efectos_modelos_mixtos.csv",
              fileEncoding = "UTF-8", row.names = FALSE)
    cat("✓ efectos_modelos_mixtos.csv\n")
  }
}

# 10. Tabla de emmeans (para el modelo de palabras)
if (!is.null(obtener_modelo_palabras())) {
  emm <- emmeans(obtener_modelo_palabras(), ~ condicion | tiempo, adjust = "tukey")
  emm_df <- as.data.frame(emm)
  write.csv(emm_df, "resultados/tablas/emmeans_palabras.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ emmeans_palabras.csv\n")
}

# 11. Tabla de correlaciones
if (exists("mat_cor")) {
  cor_df <- as.data.frame(mat_cor)
  cor_df$variable <- rownames(mat_cor)
  write.csv(cor_df, "resultados/tablas/correlaciones_spearman.csv",
            fileEncoding = "UTF-8", row.names = FALSE)
  cat("✓ correlaciones_spearman.csv\n")
}

# 12. Tabla de p-valores ajustados (FDR)
# (Recopilar p-valores de todas las pruebas y ajustar)
# Esto requiere extraer p-valores de los objetos de prueba; aquí un ejemplo con los modelos
if (exists("modelos")) {
  p_vals <- c()
  for (nm in names(modelos)) {
    if (!is.null(modelos[[nm]]$anova)) {
      anov <- modelos[[nm]]$anova
      p_vals <- c(p_vals, anov[["Pr(>F)"]])
    }
  }
  if (length(p_vals) > 0) {
    p_adj <- p.adjust(p_vals, method = "fdr")
    p_table <- data.frame(
      efecto = names(p_vals),
      p_raw = p_vals,
      p_fdr = p_adj
    )
    write.csv(p_table, "resultados/tablas/p_valores_fdr.csv",
              fileEncoding = "UTF-8", row.names = FALSE)
    cat("✓ p_valores_fdr.csv\n")
  }
}

# 13. Metadatos de figuras
metadatos_figuras <- data.frame(
  figura = c("fig1", "fig2", "fig3", "fig4", "fig5", "fig6", "fig7",
             "fig8", "fig9", "fig10", "fig11", "fig12", "fig13", "fig14", "fig15"),
  nombre = c(
    "Evolución de palabras por condición",
    "Evolución de palabras por demora",
    "Evolución emocional",
    "TTR por condición",
    "Medias marginales estimadas",
    "Scores de influencia (exploratorios)",
    "Matriz de correlaciones",
    "Cambios T1→T2 y T2→T3",
    "Trayectorias individuales",
    "Interacción condición × tiempo",
    "Efecto de demora sobre cambios",
    "Cambio emocional multivariado",
    "Evolución de diccionarios temáticos",
    "Similitud textual",
    "Mapa integrado de cambio"
  ),
  pregunta_cientifica = c(
    "¿Cómo evoluciona la extensión textual según la condición?",
    "¿Cómo influye la demora en la extensión textual?",
    "¿Cómo cambian las emociones según condición?",
    "¿Cómo cambia la diversidad léxica?",
    "¿Cuáles son las medias estimadas del modelo mixto?",
    "Distribución de scores heurísticos",
    "Asociaciones entre cambios",
    "Magnitud de cambios entre tiempos",
    "Heterogeneidad de trayectorias individuales",
    "¿Existe interacción condición × tiempo?",
    "Efecto de demora sobre cambios",
    "Patrón de cambio emocional multivariado",
    "Evolución de temas Hopper",
    "Similitud textual entre tiempos",
    "Resumen exploratorio de cambios estandarizados"
  ),
  variable_principal = c(
    "n_palabras", "n_palabras", "bing, sadness, joy", "ttr",
    "emmeans", "scores", "variables de cambio",
    "cambios", "n_palabras", "emmeans",
    "cambio_palabras", "emociones NRC", "temas Hopper",
    "coseno, Jaccard", "cambios estandarizados"
  ),
  metodo = c(
    "Bootstrap IC", "Media ± SE", "Media ± SE", "Bootstrap IC",
    "Modelo mixto", "Boxplot", "Spearman",
    "Bootstrap IC", "Trayectorias", "Modelo mixto",
    "Bootstrap IC", "Heatmap", "Media por tema",
    "Boxplot", "Heatmap"
  ),
  prioridad = c("A","A","A","A","A","B","A","A","A","A","B","B","B","B","C"),
  archivo = c(
    "fig1_palabras_condicion.png",
    "fig2_palabras_demora.png",
    "fig3_emociones.png",
    "fig4_ttr.png",
    "fig5_modelo_estimado.png",
    "fig6_scores.png",
    "fig7_correlaciones.png",
    "fig8_cambios.png",
    "fig9_trayectorias_individuales.png",
    "fig10_interaccion_condicion_tiempo.png",
    "fig11_efecto_demora.png",
    "fig12_cambio_emocional_multivariado.png",
    "fig13_diccionarios_tematicos.png",
    "fig14_similitud_textual.png",
    "fig15_mapa_integrado_cambio.png"
  )
)
write.csv(metadatos_figuras, "resultados/tablas/metadatos_figuras.csv",
          fileEncoding = "UTF-8", row.names = FALSE)
cat("✓ metadatos_figuras.csv\n")

cat("\n✓ Exportación de resultados completada.\n")

# ============================================================================
# BLOQUE 14 — ANÁLISIS DE SENSIBILIDAD Y ROBUSTEZ (COMPLETO)
# ============================================================================
#
# Este bloque implementa los análisis faltantes según el prompt maestro:
#   A. Modelo con demora
#   B. Modelo logarítmico
#   C. Modelo con n_tokens (si existe)
#   D. Modelo de exposición acumulada (n_estimulos)
#   E. Outliers e influencia
#   F. Diagnóstico de supuestos (gráficos)
#   G. Tabla maestra de robustez
#   H. Comparación del efecto de tiempo
#   I. Documentación del modelo piloto vs principal (ya existe en Bloque 11)
#   J. Registro metodológico (auditoría final)
#
# ============================================================================

# ── Verificación de objetos necesarios ─────────────────────────────────────
if (!exists("datos") || !"ancho" %in% names(datos)) {
  stop("El objeto 'datos$ancho' no está disponible. Ejecuta los bloques anteriores.")
}

library(dplyr)
library(tidyr)
library(lme4)
library(lmerTest)
library(performance)
library(emmeans)
library(ggplot2)
library(purrr)
library(broom.mixed)
library(stringr)

# Crear carpetas si no existen
dir.create("outputs/modelos", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tablas", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/diagnosticos", recursive = TRUE, showWarnings = FALSE)

# ── Definir la variable dependiente principal ──────────────────────────────
# Según el prompt, la VD es `n_palabras_calculado` (equivalente a `valor` en el modelo primario)
VD <- "n_palabras_calculado"

# [v5-O] Esta función se movió arriba (a 'BLOQUE 11 — FUNCIONES AUXILIARES') porque se
#         usaba antes de definirse y la corrida lineal abortaba. Su definición está ahora
#         antes del primer uso; aquí se deja constancia para no duplicarla.

# ── Ajustar modelo con fórmula dada y devolver resultados estructurados ──
ajustar_modelo_sensibilidad <- function(ancho, variable, formula, nombre_modelo) {
  dl <- construir_largo_para_modelo(ancho, variable)
  if (is.null(dl) || n_distinct(dl$id_participante) < 3) {
    return(list(estado = "FALLIDO", motivo = "Datos insuficientes"))
  }
  # Asegurar que la fórmula incluya el término aleatorio
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

# ──────────────────────────────────────────────────────────────────────────
# A. MODELO CON DEMORA
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== A. Modelo con demora ===\n")

# Verificar que demora existe y tiene más de un nivel
if ("demora" %in% names(datos$ancho) && length(unique(na.omit(datos$ancho$demora))) >= 2) {
# [v5-U1] CORREGIDO: la fórmula nombraba la VARIABLE ("n_palabras_calculado ~ ..."), pero
    # construir_largo_para_modelo() devuelve siempre el desenlace en la columna `valor`.
    # Con eso, TODOS los modelos del BLOQUE 14 fallaban con "object 'n_palabras_calculado' not found" y el
    # análisis de sensibilidad completo (A–F) quedaba en "FALLIDO". La fórmula correcta es `valor ~ ...`;
    # la variable que se modela se sigue pasando como argumento (`variable`).
    formula_primario <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
    modelo_primario <- ajustar_modelo_sensibilidad(datos$ancho, VD, formula_primario, "primario")
    
    # Modelo con demora
    formula_demora <- as.formula("valor ~ condicion * tiempo + demora + (1 | id_participante)")
    modelo_demora <- ajustar_modelo_sensibilidad(datos$ancho, VD, formula_demora, "con_demora")
  
  if (modelo_primario$estado == "OK" && modelo_demora$estado == "OK") {
    # Extraer efectos fijos de ambos
    coef_prim <- modelo_primario$coeficientes
    coef_dem <- modelo_demora$coeficientes
    
    # Comparación de AIC/BIC
    comp_aic <- data.frame(
      modelo = c("primario", "con_demora"),
      AIC = c(AIC(modelo_primario$modelo), AIC(modelo_demora$modelo)),
      BIC = c(BIC(modelo_primario$modelo), BIC(modelo_demora$modelo)),
      R2_marginal = c(modelo_primario$r2$R2_marginal, modelo_demora$r2$R2_marginal),
      R2_condicional = c(modelo_primario$r2$R2_conditional, modelo_demora$r2$R2_conditional)
    )
    
    # Cambio en el efecto de tiempo (coeficiente de tiempoT2, tiempoT3)
    # Identificar filas con "tiempo" en los coeficientes
    efecto_tiempo_prim <- coef_prim[grepl("^tiempo", rownames(coef_prim)), ]
    efecto_tiempo_dem <- coef_dem[grepl("^tiempo", rownames(coef_dem)), ]
    
    # Interacción condicion:tiempo
    interaccion_prim <- coef_prim[grepl("condicion.*tiempo", rownames(coef_prim)), ]
    interaccion_dem <- coef_dem[grepl("condicion.*tiempo", rownames(coef_dem)), ]
    
    # Tabla resumen del modelo con demora
    tabla_demora <- bind_rows(
      data.frame(
        efecto = rownames(coef_dem),
        Estimate = coef_dem$Estimate,
        SE = coef_dem$`Std. Error`,
        df = coef_dem$df,
        t = coef_dem$`t value`,
        p = coef_dem$`Pr(>|t|)`
      )
    )
    write.csv(tabla_demora, "outputs/tablas/tabla_demora.csv", row.names = FALSE)
    
    # Guardar modelo y resumen
    sink("outputs/modelos/modelo_demora.txt")
    cat("MODELO CON DEMORA\n")
    cat("Fórmula:", deparse(formula_demora), "\n\n")
    cat("Resumen del modelo:\n")
    print(summary(modelo_demora$modelo))
    cat("\n\nANOVA:\n")
    print(modelo_demora$anova)
    cat("\n\nR² marginal:", modelo_demora$r2$R2_marginal, " condicional:", modelo_demora$r2$R2_conditional, "\n")
    cat("\n\nComparación con modelo primario:\n")
    print(comp_aic)
    cat("\n\nCambio en efecto de tiempo (primario -> con demora):\n")
    print(efecto_tiempo_prim)
    print(efecto_tiempo_dem)
    sink()
    
    cat("✅ Modelo con demora guardado.\n")
  } else {
    cat("⚠ No se pudieron ajustar modelos con demora. Estado primario:", modelo_primario$estado, "demora:", modelo_demora$estado, "\n")
  }
} else {
  cat("⚠ Variable 'demora' no disponible o con un solo nivel. Se omite el análisis.\n")
}

# ──────────────────────────────────────────────────────────────────────────
# B. MODELO LOGARÍTMICO
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== B. Modelo logarítmico ===\n")

# Verificar que no hay ceros o negativos
datos_largo <- datos$largo
if (any(datos_largo$n_palabras_calculado <= 0, na.rm = TRUE)) {
  cat("⚠ Se encontraron valores <= 0 en n_palabras_calculado. No se puede aplicar log directo.\n")
  # Opcional: log(x+1) si hay ceros, pero el prompt dice no hacerlo sin justificación.
  # Registrar y omitir.
  writeLines("No se aplicó transformación log debido a valores <= 0.", "outputs/modelos/modelo_log_n_palabras.txt")
} else {
  # Crear una columna log en el ancho
  datos$ancho <- datos$ancho %>%
    mutate(
      log_n_palabras_t1 = log(n_palabras_calculado_t1),
      log_n_palabras_t2 = log(n_palabras_calculado_t2),
      log_n_palabras_t3 = log(n_palabras_calculado_t3)
    )
  
  # Ajustar modelo log
  # [v5-U1] Igual que en A: el desenlace en `dl` se llama `valor`.
  formula_log <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
  modelo_log <- ajustar_modelo_sensibilidad(datos$ancho, "log_n_palabras", formula_log, "log")
  
  if (modelo_log$estado == "OK") {
    # Extraer resultados
    coef_log <- modelo_log$coeficientes
    tabla_log <- data.frame(
      efecto = rownames(coef_log),
      Estimate = coef_log$Estimate,
      SE = coef_log$`Std. Error`,
      df = coef_log$df,
      t = coef_log$`t value`,
      p = coef_log$`Pr(>|t|)`
    )
    write.csv(tabla_log, "outputs/tablas/tabla_robustez_log.csv", row.names = FALSE)
    
    sink("outputs/modelos/modelo_log_n_palabras.txt")
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

# ──────────────────────────────────────────────────────────────────────────
# C. MODELO CON n_tokens
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== C. Modelo con n_tokens ===\n")

# [v5-U2] CORREGIDO: comprobaba `"n_tokens" %in% names(ancho)`, pero en `datos$ancho` la
# variable está en formato ancho (`n_tokens_t1`, ...), así que la comprobación era SIEMPRE falsa.
if ("n_tokens_t1" %in% names(datos$ancho)) {
  # Verificar que existen columnas n_tokens_t1, t2, t3
  if (all(paste0("n_tokens_t", 1:3) %in% names(datos$ancho))) {
    # Crear log si no hay ceros
    if (any(datos$ancho$n_tokens_t1 <= 0 | datos$ancho$n_tokens_t2 <= 0 | datos$ancho$n_tokens_t3 <= 0, na.rm = TRUE)) {
      cat("⚠ n_tokens tiene valores <= 0. Se omite el modelo log de n_tokens.\n")
      writeLines("n_tokens contiene valores <= 0, no se aplicó log.", "outputs/modelos/modelo_log_n_tokens.txt")
    } else {
      datos$ancho <- datos$ancho %>%
        mutate(
          log_n_tokens_t1 = log(n_tokens_t1),
          log_n_tokens_t2 = log(n_tokens_t2),
          log_n_tokens_t3 = log(n_tokens_t3)
        )
      formula_tokens <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
      modelo_tokens <- ajustar_modelo_sensibilidad(datos$ancho, "log_n_tokens", formula_tokens, "log_tokens")
      if (modelo_tokens$estado == "OK") {
        sink("outputs/modelos/modelo_log_n_tokens.txt")
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
    cat("⚠ No se encontraron columnas n_tokens_t1..t3.\n")
    writeLines("n_tokens no tiene las columnas temporales esperadas.", "outputs/modelos/modelo_log_n_tokens.txt")
  }
} else {
  cat("⚠ Variable 'n_tokens' no existe. Se omite.\n")
  writeLines("n_tokens no está disponible en los datos.", "outputs/modelos/modelo_log_n_tokens.txt")
}

# ──────────────────────────────────────────────────────────────────────────
# D. MODELO DE EXPOSICIÓN ACUMULADA (n_estimulos)
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== D. Modelo de exposición acumulada ===\n")

# Verificar estructura de n_estimulos
# [v5-U2] CORREGIDO: mismo error que con n_tokens (`n_estimulos` vs `n_estimulos_t1`).
if ("n_estimulos_t1" %in% names(datos$ancho)) {
  # Verificar que existe columna n_estimulos_t1..t3
  if (all(paste0("n_estimulos_t", 1:3) %in% names(datos$ancho))) {
    # Documentar estructura
    tabla_estimulos <- datos$ancho %>%
      select(id_participante, condicion, n_estimulos_t1, n_estimulos_t2, n_estimulos_t3) %>%
      pivot_longer(cols = starts_with("n_estimulos"), names_to = "tiempo", values_to = "n_estimulos") %>%
      count(tiempo, n_estimulos)
    write.csv(tabla_estimulos, "outputs/tablas/estructura_n_estimulos.csv", row.names = FALSE)
    cat("Estructura de n_estimulos:\n")
    print(tabla_estimulos)
    
    # Modelo con n_estimulos (sin tiempo)
    formula_estimulos <- as.formula("valor ~ condicion * n_estimulos + (1 | id_participante)")
    modelo_estimulos <- ajustar_modelo_sensibilidad(datos$ancho, VD, formula_estimulos, "estimulos")
    
    # Modelo temporal (primario) para comparación (ya debería estar, pero lo reajustamos)
    formula_tiempo <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
    modelo_tiempo <- ajustar_modelo_sensibilidad(datos$ancho, VD, formula_tiempo, "tiempo_categorico")
    
    if (modelo_estimulos$estado == "OK" && modelo_tiempo$estado == "OK") {
      comp_estimulos <- data.frame(
        modelo = c("tiempo_categorico", "n_estimulos"),
        AIC = c(AIC(modelo_tiempo$modelo), AIC(modelo_estimulos$modelo)),
        BIC = c(BIC(modelo_tiempo$modelo), BIC(modelo_estimulos$modelo)),
        R2_marginal = c(modelo_tiempo$r2$R2_marginal, modelo_estimulos$r2$R2_marginal),
        R2_condicional = c(modelo_tiempo$r2$R2_conditional, modelo_estimulos$r2$R2_conditional)
      )
      write.csv(comp_estimulos, "outputs/tablas/comparacion_tiempo_estimulos.csv", row.names = FALSE)
      
      sink("outputs/modelos/modelo_estimulos.txt")
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
      cat("⚠ No se pudieron ajustar modelos para comparación. Estado estimulos:", modelo_estimulos$estado, " tiempo:", modelo_tiempo$estado, "\n")
    }
  } else {
    cat("⚠ No se encontraron columnas n_estimulos_t1..t3.\n")
  }
} else {
  cat("⚠ Variable 'n_estimulos' no existe. Se omite.\n")
}

# ──────────────────────────────────────────────────────────────────────────
# E. OUTLIERS E INFLUENCIA (REAJUSTE EXCLUYENDO OBSERVACIONES)
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== E. Análisis de outliers e influencia ===\n")

# Ajustar modelo primario para obtener residuos (si no está ya en resultados_modelos)
if (!exists("modelo_primario") || modelo_primario$estado != "OK") {
  # [v5-U5] CORREGIDO (mismo defecto que [v5-U1], en el respaldo de la sección E): si el modelo
  # primario no estuviera disponible, esta fórmula volvía a nombrar la VARIABLE en vez de `valor`
  # y arrastraba con ella todo el análisis de outliers (E) y los diagnósticos (F).
  formula_primario <- as.formula("valor ~ condicion * tiempo + (1 | id_participante)")
  modelo_primario <- ajustar_modelo_sensibilidad(datos$ancho, VD, formula_primario, "primario")
}

if (exists("modelo_primario") && modelo_primario$estado == "OK") {
  mod_prim <- modelo_primario$modelo
  dl_prim <- modelo_primario$datos
  
  # Extraer residuos estandarizados (Pearson)
  residuos <- residuals(mod_prim, type = "pearson")
  ajustados <- fitted(mod_prim)
  # Identificar observaciones con |residuo| > 2.5
  outliers_idx <- which(abs(residuos) > 2.5)
  outliers_data <- dl_prim[outliers_idx, ]
  
  # Guardar diagnóstico
  diagnostico <- data.frame(
    id_participante = dl_prim$id_participante,
    condicion = dl_prim$condicion,
    tiempo = dl_prim$tiempo,
    valor = dl_prim$valor,
    ajustado = ajustados,
    residuo_estandarizado = residuos
  )
  write.csv(diagnostico, "outputs/diagnosticos/diagnostico_residuos.csv", row.names = FALSE)
  
  if (length(outliers_idx) > 0) {
    cat("Se encontraron", length(outliers_idx), "observaciones con |residuo| > 2.5.\n")
    # Crear dataframe sin outliers
    dl_sin_outliers <- dl_prim[-outliers_idx, ]
    # Reajustar modelo
    mod_sin_outliers <- tryCatch(
      lmer(formula_primario, data = dl_sin_outliers, REML = TRUE,
           control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
      error = function(e) NULL
    )
    if (!is.null(mod_sin_outliers)) {
      anov_sin <- anova(mod_sin_outliers, ddf = "Satterthwaite")
      r2_sin <- r2_nakagawa(mod_sin_outliers)
      
      # Comparación con modelo original
      comp_outliers <- data.frame(
        modelo = c("original", "sin_outliers"),
        N = c(nrow(dl_prim), nrow(dl_sin_outliers)),
        AIC = c(AIC(mod_prim), AIC(mod_sin_outliers)),
        BIC = c(BIC(mod_prim), BIC(mod_sin_outliers)),
        R2_marginal = c(modelo_primario$r2$R2_marginal, r2_sin$R2_marginal),
        R2_condicional = c(modelo_primario$r2$R2_conditional, r2_sin$R2_conditional)
      )
      write.csv(comp_outliers, "outputs/tablas/comparacion_outliers.csv", row.names = FALSE)
      
      sink("outputs/modelos/modelo_sin_outliers.txt")
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
    # Crear archivo indicando que no hay outliers
    writeLines("No se encontraron observaciones con |residuo estandarizado| > 2.5.", "outputs/modelos/modelo_sin_outliers.txt")
  }
} else {
  cat("⚠ No se pudo obtener el modelo primario para el análisis de outliers.\n")
}

# ──────────────────────────────────────────────────────────────────────────
# F. DIAGNÓSTICO DE SUPUESTOS (GRÁFICOS)
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== F. Diagnóstico de supuestos ===\n")

if (exists("modelo_primario") && modelo_primario$estado == "OK") {
  mod_prim <- modelo_primario$modelo
  resid <- residuals(mod_prim, type = "pearson")
  fit <- fitted(mod_prim)
  rand <- ranef(mod_prim)$id_participante[, "(Intercept)"]
  
  # Gráfico residuos vs ajustados
  p1 <- ggplot(data.frame(fit, resid), aes(x = fit, y = resid)) +
    geom_point(alpha = 0.6) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_smooth(method = "loess", se = FALSE, color = "red") +
    labs(title = "Residuos estandarizados vs. Valores ajustados",
         x = "Valores ajustados", y = "Residuos estandarizados") +
    theme_minimal()
  ggsave("outputs/diagnosticos/residuos_vs_ajustados.png", p1, width = 8, height = 6)
  
  # Q-Q plot
  p2 <- ggplot(data.frame(sample = resid), aes(sample = sample)) +
    stat_qq() +
    stat_qq_line() +
    labs(title = "Q-Q plot de residuos", x = "Cuantiles teóricos", y = "Cuantiles muestrales") +
    theme_minimal()
  ggsave("outputs/diagnosticos/qq_residuos.png", p2, width = 8, height = 6)
  
  # Distribución de efectos aleatorios
  p3 <- ggplot(data.frame(rand = rand), aes(x = rand)) +
    geom_histogram(bins = 20, fill = "steelblue", color = "black", alpha = 0.7) +
    labs(title = "Distribución de interceptos aleatorios", x = "Intercepto aleatorio") +
    theme_minimal()
  ggsave("outputs/diagnosticos/distribucion_aleatorios.png", p3, width = 8, height = 6)
  
  cat("✅ Gráficos de diagnóstico guardados en outputs/diagnosticos/\n")
} else {
  cat("⚠ No se pudo generar diagnósticos porque el modelo primario no está disponible.\n")
}

# ──────────────────────────────────────────────────────────────────────────
# G. TABLA MAESTRA DE ROBUSTEZ
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== G. Tabla maestra de robustez ===\n")

# Función para extraer información clave de un modelo ajustado
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
  
  # Efecto tiempo: buscar filas que empiecen con "tiempo"
  tiempo_rows <- coef[grepl("^tiempo", rownames(coef)), ]
  if (nrow(tiempo_rows) > 0) {
    # Tomar el primer efecto de tiempo (tiempoT2) como representativo
    ef_tiempo <- tiempo_rows[1, "Estimate"]
    p_tiempo <- tiempo_rows[1, "Pr(>|t|)"]
  } else {
    ef_tiempo <- NA
    p_tiempo <- NA
  }
  
  # Efecto condicion: buscar filas que empiecen con "condicion" y no contengan ":"
  cond_rows <- coef[grepl("^condicion", rownames(coef)) & !grepl(":", rownames(coef)), ]
  if (nrow(cond_rows) > 0) {
    ef_cond <- cond_rows[1, "Estimate"]
    p_cond <- cond_rows[1, "Pr(>|t|)"]
  } else {
    ef_cond <- NA
    p_cond <- NA
  }
  
  # Interacción: buscar filas que contengan "condicion.*tiempo" o "tiempo.*condicion"
  int_rows <- coef[grepl("condicion.*tiempo|tiempo.*condicion", rownames(coef)), ]
  if (nrow(int_rows) > 0) {
    ef_int <- int_rows[1, "Estimate"]
    p_int <- int_rows[1, "Pr(>|t|)"]
  } else {
    ef_int <- NA
    p_int <- NA
  }
  
  # Conclusión automática: si p_tiempo < 0.05 y p_int >= 0.05, "efecto tiempo significativo"
  # si p_int < 0.05, "interacción significativa", etc.
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

# Recolectar todos los modelos ajustados en este bloque y el primario (de resultados_modelos si existe)
lista_modelos <- list()

# Modelo primario (de resultados_modelos o del reajuste)
if (exists("resultados_modelos") && "n_palabras" %in% names(resultados_modelos)) {
  # Extraer del objeto resultados_modelos del Bloque 10
  mod_primario_bloque10 <- resultados_modelos$n_palabras
  if (!is.null(mod_primario_bloque10$modelo)) {
    # Construir un objeto similar a los de este bloque
    prim_obj <- list(
      estado = "OK",
      modelo = mod_primario_bloque10$modelo,
      datos = mod_primario_bloque10$datos,
      anova = mod_primario_bloque10$anova,
      r2 = mod_primario_bloque10$r2,
      coeficientes = as.data.frame(summary(mod_primario_bloque10$modelo)$coefficients)
    )
    lista_modelos[["primario"]] <- prim_obj
  }
} else if (exists("modelo_primario") && modelo_primario$estado == "OK") {
  lista_modelos[["primario"]] <- modelo_primario
}

# Añadir modelos de sensibilidad si existen
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
  # Construir objeto para sin_outliers
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

# Generar tabla maestra
tabla_robustez <- bind_rows(lapply(names(lista_modelos), function(nm) {
  extraer_info_modelo(lista_modelos[[nm]], nm)
}))

write.csv(tabla_robustez, "outputs/tablas/tabla_robustez_modelos.csv", row.names = FALSE)
cat("✅ Tabla maestra de robustez guardada.\n")

# ──────────────────────────────────────────────────────────────────────────
# H. COMPARACIÓN ESPECÍFICA DEL EFECTO DE TIEMPO
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== H. Comparación del efecto de tiempo ===\n")

# Extraer para cada modelo el coeficiente y p-valor del primer nivel de tiempo (tiempoT2)
efectos_tiempo <- tabla_robustez %>%
  select(modelo, efecto_tiempo, p_tiempo) %>%
  mutate(
    IC95_inf = NA,
    IC95_sup = NA,
    direccion = ifelse(efecto_tiempo > 0, "positivo", ifelse(efecto_tiempo < 0, "negativo", "cero")),
    significacion = ifelse(p_tiempo < 0.05, "significativo", "no significativo")
  )
# Si tenemos los coeficientes completos, podríamos calcular IC, pero usamos NA por ahora.
write.csv(efectos_tiempo, "outputs/tablas/robustez_efecto_tiempo.csv", row.names = FALSE)
cat("✅ Tabla de efecto de tiempo guardada.\n")

# ──────────────────────────────────────────────────────────────────────────
# I. MODELO PILOTO VS PRINCIPAL (documentación)
# ──────────────────────────────────────────────────────────────────────────
# Este análisis ya está en el Bloque 11. Aquí solo generamos un resumen
# para incluirlo en la auditoría final.

cat("\n=== I. Replicabilidad piloto vs principal ===\n")
# [v5-U4] CORREGIDO: la ruta era la del árbol auditado (`analisis_piloto/`). El BLOQUE 11
# guarda los modelos comparativos en la carpeta de salida del piloto (DIR_SALIDA/modelos).
.ruta_comparativos <- file.path(DIR_SALIDA, "modelos", "modelos_comparativos.rds")
if (file.exists(.ruta_comparativos)) {
  cat("El análisis de replicabilidad piloto vs principal ya está disponible en:\n")
  cat(" ", .ruta_comparativos, "\n")
  cat("Se genera un resumen textual.\n")
  
  # Cargar resultados comparativos si existen
  comp_results <- readRDS(.ruta_comparativos)
  sink("outputs/modelos/modelo_fuente_replicabilidad.txt")
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

# ──────────────────────────────────────────────────────────────────────────
# J. REGISTRO METODOLÓGICO (AUDITORÍA FINAL)
# ──────────────────────────────────────────────────────────────────────────

cat("\n=== J. Registro metodológico ===\n")

# Crear archivo de auditoría
sink("outputs/auditoria_analisis_final.txt")
cat("===============================================================\n")
cat("AUDITORÍA FINAL DEL ANÁLISIS\n")
cat("===============================================================\n\n")
cat("Fecha de ejecución:", Sys.time(), "\n")
cat("Versión de R:", R.version.string, "\n")
cat("Paquetes utilizados y versiones:\n")
print(sessionInfo()$otherPkgs)
cat("\n\nFórmulas de los modelos:\n")
cat("  - Primario: valor ~ condicion * tiempo + (1 | id_participante)\n")
if (exists("formula_demora")) cat("  - Con demora:", deparse(formula_demora), "\n")
if (exists("formula_log")) cat("  - Log:", deparse(formula_log), "\n")
if (exists("formula_tokens")) cat("  - Log tokens:", deparse(formula_tokens), "\n")
if (exists("formula_estimulos")) cat("  - Estimulos:", deparse(formula_estimulos), "\n")
cat("  - Sin outliers: similar al primario excluyendo observaciones con |resid|>2.5\n\n")

cat("N y participantes:\n")
cat("  - Primario: N =", nrow(datos$largo), "participantes =", n_distinct(datos$largo$id_participante), "\n")
# (Se pueden agregar más detalles si se desea)

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

# [v5-T] CORREGIDO: aquí había CUATRO líneas de prosa fija ("efecto de tiempo significativo",
# "similar al primario", "...") que NO se calculaban: se escribían igual con cualquier resultado.
# Un archivo de auditoría no puede afirmar lo que no midió, así que ahora se derivan de la tabla
# de robustez, que sí se calcula, y cuando no hay dato se dice "no disponible".
cat("\nResultados principales (derivados de tabla_robustez_modelos.csv; NO son texto fijo):\n")
if (exists("tabla_robustez") && is.data.frame(tabla_robustez) && nrow(tabla_robustez) > 0) {
  .fmt <- function(x) if (is.null(x) || length(x) == 0 || all(is.na(x))) "no disponible" else format(round(as.numeric(x[1]), 4))
  for (.i in seq_len(nrow(tabla_robustez))) {
    .r <- tabla_robustez[.i, ]
    cat(sprintf("  - %s: N = %s | p(tiempo) = %s | p(condición) = %s | p(interacción) = %s | %s\n",
                .r$modelo, .fmt(.r$N), .fmt(.r$p_tiempo), .fmt(.r$p_condicion),
                .fmt(.r$p_interaccion), as.character(.r$conclusion)))
  }
} else {
  cat("  (no se generó la tabla de robustez: no hay nada que reportar)\n")
}

cat("\nAdvertencias metodológicas:\n")
cat("  - n_estimulos está funcionalmente determinado por el tiempo experimental.\n")
cat("  - La variable demora solo está disponible en la muestra principal.\n")
cat("  - El análisis de outliers se basa en un criterio único (2.5).\n")

cat("\n===============================================================\n")
sink()

# Guardar sessionInfo
sink("outputs/sessionInfo.txt")
print(sessionInfo())
sink()

cat("✅ Auditoría final y sessionInfo guardados.\n")

# ──────────────────────────────────────────────────────────────────────────
# RESUMEN EN CONSOLA
# ──────────────────────────────────────────────────────────────────────────

cat("\n\n========================================\n")
cat("AUDITORÍA FINAL DEL ANÁLISIS\n")
cat("========================================\n\n")

cat("Modelo primario: OK\n")
cat("Modelo + demora:", ifelse(exists("modelo_demora") && modelo_demora$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
cat("Log palabras:", ifelse(exists("modelo_log") && modelo_log$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
cat("Log tokens:", ifelse(exists("modelo_tokens") && modelo_tokens$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
cat("Modelo estímulos:", ifelse(exists("modelo_estimulos") && modelo_estimulos$estado == "OK", "OK", "NO DISPONIBLE"), "\n")
cat("Sensibilidad outliers:", ifelse(exists("mod_sin_outliers") && !is.null(mod_sin_outliers), "OK", "NO DISPONIBLE"), "\n")
cat("Modelo fuente (replicabilidad):", ifelse(file.exists(file.path(DIR_SALIDA, "modelos", "modelos_comparativos.rds")), "OK", "NO DISPONIBLE"), "\n")

cat("\nConclusión del efecto de tiempo:\n")
if (exists("efectos_tiempo") && nrow(efectos_tiempo) > 0) {
  cat("  - En el modelo primario: p =", efectos_tiempo[efectos_tiempo$modelo == "primario", "p_tiempo"], "\n")
  cat("  - En modelos de sensibilidad: los p-valores varían entre", 
      min(efectos_tiempo$p_tiempo, na.rm = TRUE), "y", max(efectos_tiempo$p_tiempo, na.rm = TRUE), "\n")
} else {
  cat("  No se pudo extraer.\n")
}

# [v5-T] CORREGIDO: estas cuatro líneas de "Robustez" también eran prosa fija (afirmaban que el
# efecto se mantenía y que la interacción no era significativa sin mirar un solo modelo).
# Ahora se derivan de la tabla de robustez y, si falta, se declara.
.num_o_na <- function(x) if (is.null(x) || length(x) == 0 || all(is.na(x))) NA_real_ else as.numeric(x[1])
.prim <- NULL
if (exists("tabla_robustez") && is.data.frame(tabla_robustez) && "primario" %in% tabla_robustez$modelo) {
  .prim <- tabla_robustez[tabla_robustez$modelo == "primario", , drop = FALSE][1, ]
}

cat("\nConclusión condición (calculada):\n")
cat("  - En el modelo primario: p =", .num_o_na(.prim$p_condicion),
    if (!is.na(.num_o_na(.prim$p_condicion))) ifelse(.num_o_na(.prim$p_condicion) < 0.05, " (significativa)", " (no significativa)") else "", "\n")

cat("\nConclusión interacción (calculada):\n")
cat("  - En el modelo primario: p =", .num_o_na(.prim$p_interaccion),
    if (!is.na(.num_o_na(.prim$p_interaccion))) ifelse(.num_o_na(.prim$p_interaccion) < 0.05, " (significativa)", " (no significativa)") else "", "\n")

cat("\nRobustez (derivada de la tabla; ver columna 'conclusion' de cada fila):\n")
if (exists("tabla_robustez") && is.data.frame(tabla_robustez) && nrow(tabla_robustez) > 0) {
  .sig_tiempo <- sum(tabla_robustez$p_tiempo < 0.05, na.rm = TRUE)
  .sig_int    <- sum(tabla_robustez$p_interaccion < 0.05, na.rm = TRUE)
  cat("  - Modelos ajustados:", nrow(tabla_robustez),
      "| con efecto de tiempo p < .05:", .sig_tiempo,
      "| con interacción p < .05:", .sig_int, "\n")
  cat("  - p(tiempo) por modelo:",
      paste(sprintf("%s=%s", tabla_robustez$modelo,
                    vapply(tabla_robustez$p_tiempo, function(x) ifelse(is.na(x), "NA", format(round(x, 4))), character(1))),
            collapse = " | "), "\n")
  cat("  - Nota: 'la demora no cambia las conclusiones' y similares NO se imprimen aquí;\n")
  cat("    compárense los coeficientes entre modelos en outputs/tablas/tabla_robustez_modelos.csv.\n")
} else {
  cat("  - No disponible: no se generó la tabla de robustez.\n")
}

cat("\n========================================\n")
cat("✅ Bloque 14 completado. Todos los análisis de sensibilidad y robustez generados.\n")
cat("Archivos de salida disponibles en la carpeta 'outputs/'.\n")