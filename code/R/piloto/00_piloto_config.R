# ============================================================================
# 00_piloto_config.R — CONFIGURACIÓN ESPECÍFICA PARA EL ANÁLISIS PILOTO
# ============================================================================
# Este archivo carga la configuración global (R/00_config.R) y luego aplica
# sobrescrituras o definiciones adicionales necesarias para el análisis piloto.
# Debe ser el primer archivo en ser sourceado en el pipeline piloto.
# ============================================================================

# ── 1. Cargar configuración global ──────────────────────────────────────────
# Esto carga librerías, opciones, logging, configuración de Python, etc.
source(here::here("code", "R", "00_config.R"))

# ── 2. Configuraciones específicas para el piloto ──────────────────────────

# 2.1. Rutas de salida para el piloto (independientes del análisis principal)
OUTPUT_DIR_PILOTO <- here::here("results", "piloto")
dir.create(OUTPUT_DIR_PILOTO, recursive = TRUE, showWarnings = FALSE)

# Subdirectorios
dirs_piloto <- c(
  "figuras",
  "tablas",
  "modelos",
  "diagnosticos",
  "datos",
  "sensibilidad"
)
for (d in dirs_piloto) {
  dir.create(file.path(OUTPUT_DIR_PILOTO, d), recursive = TRUE, showWarnings = FALSE)
}

# 2.2. Archivo de log específico para el piloto
LOG_FILE_PILOTO <- file.path(OUTPUT_DIR_PILOTO, "piloto_log.txt")
# Redirigir la función de logging para que use este archivo (opcional)
# Si se desea mantener el log global, se puede dejar como está.
# Aquí se redefine registrar_log para que escriba también en el archivo del piloto.
# Pero para no romper la consistencia, se mantiene la función original y se
# añade una función específica si se necesita.

# 2.3. Semilla específica para el piloto (para reproducibilidad)
# Nota: la semilla global ya se fijó en 00_config.R (20260526).
# Si se desea una semilla diferente para el piloto, se puede cambiar aquí.
# Pero se recomienda mantener la misma para que los resultados sean comparables.
# set.seed(20260526)  # ya se fijó en 00_config.R

# 2.4. Parámetros específicos del piloto
# Por ejemplo, si el piloto no tiene demora, podemos forzar que los modelos
# no la incluyan. Esto se manejará en los scripts de análisis, pero podemos
# definir una variable global para ello.
PILOTO_TIENE_DEMORA <- FALSE  # el piloto no tiene información de demora

# 2.5. Nombres de archivos de datos de entrada
# Se pueden definir rutas de los archivos Excel del piloto si se desea
# que estén centralizadas aquí.
# Ejemplo:
# RUTA_PILOTO_EXCEL <- here::here("data", "raw", "piloto_interrelacion_formato_largo.xlsx")

# ── 3. Mensaje de confirmación ─────────────────────────────────────────────
cat("\n✅ Configuración para análisis piloto cargada.\n")
cat("   Directorio de salida:", OUTPUT_DIR_PILOTO, "\n")
cat("   Archivo de log:", LOG_FILE_PILOTO, "\n")