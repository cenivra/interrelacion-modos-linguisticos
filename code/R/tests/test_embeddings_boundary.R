# ============================================================================
# test_embeddings_boundary.R
# ============================================================================
# Diagnóstico de la frontera Python -> R mediante reticulate.
#
# Objetivo:
# determinar si la discrepancia aparece:
#
#   Python -> Python
#   Python -> reticulate -> R
#
# No utiliza datos reales.
# No modifica 05_embeddings.R.
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("DIAGNÓSTICO — FRONTERA PYTHON -> R\n")
cat(strrep("=", 70), "\n\n")

suppressPackageStartupMessages({
  library(reticulate)
})

use_python(
  "C:/venvs/renv311/Scripts/python.exe",
  required = TRUE
)

source_python(
  file.path(
    getwd(),
    "python",
    "embeddings_setup.py"
  )
)

textos <- c(
  "Me siento solo y aislado de los demás.",
  "Tengo esperanza de que las cosas mejoren.",
  "La incertidumbre me impide avanzar.",
  "Busco maneras de enfrentar las dificultades.",
  "No logro comunicarme con los demás.",
  "La tristeza y el dolor me acompañan constantemente.",
  "Tengo control sobre mis decisiones.",
  "",
  NA_character_
)

cat("[1] PREPARACIÓN\n")

textos_py <- as.character(textos)

textos_py[
  is.na(textos_py) |
    trimws(textos_py) == ""
] <- "[VACÍO]"

py$textos_boundary <- textos_py

cat("Textos:", length(textos_py), "\n\n")

# ============================================================================
# A. GENERAR EN PYTHON SIN NORMALIZACIÓN
# ============================================================================

cat("[2] GENERACIÓN PYTHON — RAW\n")

py_run_string("
boundary_raw = model.encode(
    textos_boundary,
    convert_to_numpy=True,
    normalize_embeddings=False,
    show_progress_bar=False
)

boundary_raw = boundary_raw.astype('float64')
")

# ============================================================================
# B. NORMALIZACIÓN DENTRO DE PYTHON
# ============================================================================

py_run_string("
boundary_python_normalized = boundary_raw / (
    np.linalg.norm(
        boundary_raw,
        axis=1,
        keepdims=True
    )
)
")

# ============================================================================
# C. EXTRAER RAW A R
# ============================================================================

cat("[3] PYTHON RAW -> R\n")

raw_r <- py$boundary_raw

if (is.null(dim(raw_r)) || length(dim(raw_r)) < 2) {
  raw_r <- matrix(
    raw_r,
    nrow = length(textos_py)
  )
}

cat(
  "Dimensión:",
  paste(dim(raw_r), collapse = " x "),
  "\n"
)

# ============================================================================
# D. EXTRAER PYTHON-NORMALIZED A R
# ============================================================================

cat("[4] PYTHON NORMALIZED -> R\n")

normalized_r <- py$boundary_python_normalized

if (is.null(dim(normalized_r)) || length(dim(normalized_r)) < 2) {
  normalized_r <- matrix(
    normalized_r,
    nrow = length(textos_py)
  )
}

cat(
  "Dimensión:",
  paste(dim(normalized_r), collapse = " x "),
  "\n"
)

# ============================================================================
# E. NORMALIZAR RAW YA EN R
# ============================================================================

cat("[5] NORMALIZACIÓN EN R\n")

raw_r_normalized <- raw_r / sqrt(
  rowSums(raw_r^2)
)

# ============================================================================
# F. COMPARACIÓN
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("[6] COMPARACIÓN\n")
cat(strrep("=", 70), "\n\n")

diff_python_vs_r <- (
  normalized_r -
    raw_r_normalized
)

max_diff_python_r <- max(
  abs(diff_python_vs_r)
)

mean_diff_python_r <- mean(
  abs(diff_python_vs_r)
)

rmse_python_r <- sqrt(
  mean(diff_python_vs_r^2)
)

cat(
  "Python normalized vs R normalized\n"
)

cat(
  "Máxima diferencia:",
  format(max_diff_python_r, scientific = TRUE),
  "\n"
)

cat(
  "Diferencia media:",
  format(mean_diff_python_r, scientific = TRUE),
  "\n"
)

cat(
  "RMSE:",
  format(rmse_python_r, scientific = TRUE),
  "\n\n"
)

# ============================================================================
# G. COMPARACIÓN CON encode_texts()
# ============================================================================

cat("[7] encode_texts() -> R\n\n")

new_r <- encode_texts(
  textos,
  normalize = TRUE,
  batch_size = 32L
)

diff_new <- normalized_r - new_r

max_diff_new <- max(
  abs(diff_new)
)

mean_diff_new <- mean(
  abs(diff_new)
)

rmse_new <- sqrt(
  mean(diff_new^2)
)

cat(
  "Python normalized vs encode_texts()\n"
)

cat(
  "Máxima diferencia:",
  format(max_diff_new, scientific = TRUE),
  "\n"
)

cat(
  "Diferencia media:",
  format(mean_diff_new, scientific = TRUE),
  "\n"
)

cat(
  "RMSE:",
  format(rmse_new, scientific = TRUE),
  "\n\n"
)

# ============================================================================
# H. COMPARACIÓN FILA POR FILA
# ============================================================================

cosine <- function(x, y) {
  sum(x * y) /
    sqrt(
      sum(x^2) *
        sum(y^2)
    )
}

cosines_new <- vapply(
  seq_len(nrow(normalized_r)),
  function(i) {
    cosine(
      normalized_r[i, ],
      new_r[i, ]
    )
  },
  numeric(1)
)

cat("Coseno mínimo:", format(min(cosines_new), digits = 15), "\n")
cat("Coseno máximo:", format(max(cosines_new), digits = 15), "\n\n")

# ============================================================================
# RESULTADO
# ============================================================================

cat(strrep("=", 70), "\n")

if (
  max_diff_python_r <= 1e-7 &&
  max_diff_new <= 1e-7
) {

  cat("PASS — la frontera Python -> R es consistente.\n")

} else {

  cat("FAIL — la discrepancia aparece en la frontera Python -> R.\n")
}

cat(strrep("=", 70), "\n")