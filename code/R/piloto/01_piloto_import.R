# ============================================================================
# 01_piloto_import.R — CARGA Y NORMALIZACIÓN DE DATOS DEL PILOTO
# ============================================================================
# Este script importa el archivo Excel del piloto (formato largo), lo normaliza
# al esquema canónico y genera los objetos datos_piloto_largo y datos_piloto_ancho,
# además de la lista datos_piloto que contiene ambos.
# ============================================================================

# ── Dependencias ─────────────────────────────────────────────────────────────
# Este script asume que 00_config.R y 01_import_data.R ya han sido sourceados.
# En run_piloto.R se debe llamar a:
#   source(here::here("code", "R", "00_config.R"))
#   source(here::here("code", "R", "01_import_data.R"))
#   source(here::here("code", "R", "piloto", "00_piloto_config.R"))
#   source(here::here("code", "R", "piloto", "01_piloto_import.R"))

# ── Definición de ruta del archivo del piloto ──────────────────────────────
# Se puede definir en 00_piloto_config.R o establecer aquí.
# Usamos una ruta relativa con here::here().
RUTA_PILOTO_EXCEL <- here::here("data", "raw", "piloto_interrelacion_formato_largo.xlsx")

# Verificar que el archivo existe
if (!file.exists(RUTA_PILOTO_EXCEL)) {
  stop("❌ No se encontró el archivo del piloto en: ", RUTA_PILOTO_EXCEL,
       "\n   Asegúrate de que el archivo esté en 'data/raw/' y se llame 'piloto_interrelacion_formato_largo.xlsx'.")
}

# ── Función para cargar el piloto (opcional, puede usarse desde run_piloto.R) ──
#' Cargar y normalizar los datos del piloto
#'
#' @param ruta Ruta al archivo Excel del piloto (formato largo).
#' @return Lista con elementos `largo` y `ancho`.
cargar_piloto <- function(ruta = RUTA_PILOTO_EXCEL) {
  
  cat("\n=== CARGANDO DATOS DEL PILOTO ===\n")
  
  # 1. Importar el dataset piloto (formato largo, usando importar_piloto corregida)
  cat("→ Importando archivo:", ruta, "\n")
  raw_piloto <- importar_piloto(ruta, hoja = "Datos_Largo")
  
  # El piloto en formato largo puede tener una columna 'n_palabras_excel'
  # que se renombra a 'n_palabras' dentro de importar_piloto.
  # Usaremos normalizar_piloto, que no requiere n_palabras y asigna fuente = "piloto".
  
  # 2. Normalizar al esquema canónico (fuente = "piloto", demora = NA, n_palabras = NA)
  cat("→ Normalizando datos del piloto...\n")
  piloto_norm <- normalizar_piloto(raw_piloto)
  # 3. Validar el esquema (opcional)
  validar_esquema(piloto_norm, nombre = "piloto_norm")
  
  # 4. Generar formato ancho
  cat("→ Generando formato ancho...\n")
  piloto_ancho <- generar_ancho(piloto_norm)
  
  # 5. Crear la lista datos_piloto (similar al objeto 'datos' en el análisis principal)
  datos_piloto <- list(
    largo = piloto_norm,
    ancho = piloto_ancho
  )
  
  cat("✅ Datos del piloto cargados correctamente.\n")
  cat("   Observaciones (largo):", nrow(datos_piloto$largo), "\n")
  cat("   Participantes (ancho):", nrow(datos_piloto$ancho), "\n")
  cat("   Columnas en ancho:", ncol(datos_piloto$ancho), "\n\n")
  
  return(datos_piloto)
}

# ── Ejecución directa (si se sourcea este script) ──────────────────────────
# Si este script se ejecuta directamente (no desde run_piloto.R),
# se cargará el piloto y se asignará a la variable global 'datos_piloto'.
# Si ya existe un objeto con ese nombre, se sobrescribirá.

if (interactive() || Sys.getenv("RUN_PILOTO") == "TRUE") {
  datos_piloto <- cargar_piloto()
} else {
  # Si se sourcea desde run_piloto.R, la función cargar_piloto estará disponible.
  cat("ℹ️ Función 'cargar_piloto()' definida. Ejecutar para cargar los datos.\n")
}