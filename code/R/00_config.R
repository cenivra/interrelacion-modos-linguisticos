# ============================================================================
# 00_config.R — CONFIGURACIÓN GLOBAL DEL PROYECTO
# ============================================================================
# Este archivo carga librerías, establece opciones, semilla, logging
# y configura el entorno Python (reticulate) para los embeddings.
# ============================================================================

# ── Limpiar entorno y configurar opciones ────────────────────────────────────
# Nota: No uses setwd() aquí. Usa 'here::here()' en los scripts principales.
# Si quieres fijar la raíz del proyecto, ejecuta en la consola:
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

options(
  stringsAsFactors           = FALSE,
  scipen                     = 999,
  max.print                  = 1000,
  warn                       = 1,
  digits                     = 4
)

set.seed(20260526)

# ── Instalación condicional de paquetes ──────────────────────────────────────
instalar_paquetes <- function(pkgs, repo = "https://cloud.r-project.org") {
  nuevos <- pkgs[!(pkgs %in% rownames(installed.packages()))]
  if (length(nuevos) > 0) {
    cat("Instalando:", paste(nuevos, collapse = ", "), "\n")
    install.packages(nuevos, repos = repo, dependencies = TRUE)
  }
}

# ── Lista de paquetes necesarios ─────────────────────────────────────────────
paquetes_necesarios <- c(
  "tidyverse", "tidytext", "readxl", "stringr", "stringi",
  "tokenizers", "stopwords", "text2vec", "proxy", "tm",
  "syuzhet",
  "lme4", "lmerTest", "emmeans", "performance", "effectsize",
  "rstatix", "effsize", "car",
  "topicmodels",
  "ggplot2", "cowplot", "viridis", "corrplot", "RColorBrewer",
  "ggraph", "igraph", "wordcloud",
  "readr", "scales", "writexl", "ggpubr", "gridExtra",
  "broom.mixed", "patchwork", "see", "FSA", "rcompanion"
)

# ── Cargar librerías ──────────────────────────────────────────────────────────
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
  library(writexl)
  library(ggpubr)
  library(gridExtra)
  library(broom.mixed)
  library(patchwork)
  library(see)       # Para check_model()
  library(FSA)       # Para pruebas post-hoc alternativas
  library(rcompanion) 
})

cat("✓ Librerías cargadas\n\n")

# ── Sistema de logging ────────────────────────────────────────────────────────
registrar_log <- function(mensaje, nivel = "INFO",
                          archivo = "experimento_log.txt") {
  ts  <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- sprintf("[%s] %s: %s", ts, nivel, mensaje)
  cat(msg, "\n")
  cat(msg, "\n", file = archivo, append = TRUE)
}

# ── Configuración del entorno Python (reticulate) ──────────────────────────
# Solo se configura la ruta, el modelo y la función de embeddings se cargan
# en el módulo '05_embeddings.R' para no ralentizar la carga inicial.
#
# Resolución del intérprete Python (orden de prioridad):
#   1. Variable de entorno NLP_PYTHON
#   2. C:/venvs/renv-nlp/Scripts/python.exe
#   3. C:/venvs/renv311/Scripts/python.exe
#   4. Sys.which("python")
# Debe poder importar sentence_transformers.

resolver_python <- function() {
  candidatos <- c(
    Sys.getenv("NLP_PYTHON", unset = NA),
    "C:/venvs/renv-nlp/Scripts/python.exe",
    "C:/venvs/renv311/Scripts/python.exe",
    Sys.which("python")
  )
  candidatos <- candidatos[!is.na(candidatos) & nzchar(candidatos)]
  
  for (py in candidatos) {
    if (file.exists(py)) {
      # Verificar que puede importar sentence_transformers
      test_cmd <- sprintf('"%s" -c "import sentence_transformers; print(sentence_transformers.__version__)"', py)
      res <- system(test_cmd, intern = TRUE, ignore.stderr = TRUE)
      if (length(res) > 0 && nzchar(res[1])) {
        cat("✓ Intérprete Python válido encontrado:", py, "\n")
        cat("  sentence_transformers version:", res[1], "\n")
        return(py)
      } else {
        cat("⚠ Python en", py, "no puede importar sentence_transformers\n")
      }
    } else {
      cat("⚠ No existe:", py, "\n")
    }
  }
  
  # Ninguno funcionó
  stop(
    "❌ No se encontró un intérprete Python válido con sentence_transformers.\n",
    "  Cread uno con:\n",
    "    uv venv C:/venvs/renv-nlp\n",
    "    C:/venvs/renv-nlp/Scripts/uv pip install sentence-transformers torch\n",
    "  O defina la variable de entorno NLP_PYTHON apuntando a su python.exe."
  )
}

python_exe <- resolver_python()
Sys.setenv(RETICULATE_PYTHON = python_exe)
library(reticulate)
use_python(python_exe, required = TRUE)
# ── Rutas de datos ───────────────────────────────────────────────────────────
# Directorio base donde están los archivos Excel crudos (NO copiar al repo)
# Ajustar según la máquina del usuario
RUTA_DATOS_CRUDOS <- Sys.getenv("RUTA_DATOS_CRUDOS", unset = file.path(getwd(), "data", "raw"))

# Rutas completas a los archivos (se construyen aquí para uso en run_analysis.R)
RUTA_PRINCIPAL_EXCEL <- file.path(RUTA_DATOS_CRUDOS, "Datos Exp Interrelacion.xlsx")
RUTA_PILOTO_EXCEL <- file.path(RUTA_DATOS_CRUDOS, "piloto_interrelacion_formato_largo.xlsx")

cat("✓ Rutas de datos configuradas:\n")
cat("  Principal:", RUTA_PRINCIPAL_EXCEL, "\n")
cat("  Piloto:", RUTA_PILOTO_EXCEL, "\n")