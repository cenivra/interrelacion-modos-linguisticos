# ============================================================================
# test_encode_texts_input.R
# ============================================================================
# Diagnóstico del argumento R -> Python para encode_texts().
#
# Objetivo:
# determinar si la discrepancia aparece por la conversión del vector R
# hacia Python antes de ejecutar el modelo.
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("DIAGNÓSTICO — ARGUMENTO R -> encode_texts()\n")
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

# ============================================================================
# TEXTOS
# ============================================================================

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

textos_py <- as.character(textos)

textos_py[
  is.na(textos_py) |
    trimws(textos_py) == ""
] <- "[VACÍO]"

cat("[1] TEXTOS NORMALIZADOS EN R\n\n")

print(textos_py)

# ============================================================================
# PASAR EXPLÍCITAMENTE LA LISTA A PYTHON
# ============================================================================

py$textos_explicitos <- textos_py

py_run_string("
print('--- PYTHON: textos_explicitos ---')
print(type(textos_explicitos))
print(len(textos_explicitos))

for i, x in enumerate(textos_explicitos):
    print(i + 1, repr(x), type(x))
")

# ============================================================================
# A. model.encode DIRECTO CON LA LISTA PYTHON
# ============================================================================

cat("\n")
cat("[2] model.encode() DIRECTO DESDE PYTHON\n\n")

py_run_string("
direct_python = model.encode(
    textos_explicitos,
    convert_to_numpy=True,
    normalize_embeddings=True,
    show_progress_bar=False
)

direct_python = direct_python.astype('float64')
")

direct_r <- py$direct_python

if (is.null(dim(direct_r)) || length(dim(direct_r)) < 2) {
  direct_r <- matrix(
    direct_r,
    nrow = length(textos_py)
  )
}

cat(
  "Dimensión:",
  paste(dim(direct_r), collapse = " x "),
  "\n"
)

# ============================================================================
# B. encode_texts() DESDE PYTHON CON LISTA EXPLÍCITA
# ============================================================================

cat("\n")
cat("[3] encode_texts() CON LISTA PYTHON EXPLÍCITA\n\n")

py_run_string("
wrapper_python = encode_texts(
    textos_explicitos,
    normalize=True,
    batch_size=32
)

wrapper_python = wrapper_python.astype('float64')
")

wrapper_python_r <- py$wrapper_python

if (
  is.null(dim(wrapper_python_r)) ||
  length(dim(wrapper_python_r)) < 2
) {
  wrapper_python_r <- matrix(
    wrapper_python_r,
    nrow = length(textos_py)
  )
}

cat(
  "Dimensión:",
  paste(dim(wrapper_python_r), collapse = " x "),
  "\n"
)

# ============================================================================
# C. encode_texts() RECIBIENDO DIRECTAMENTE EL VECTOR R
# ============================================================================

cat("\n")
cat("[4] encode_texts() RECIBIENDO VECTOR R\n\n")

wrapper_r <- encode_texts(
  textos,
  normalize = TRUE,
  batch_size = 32L
)

cat(
  "Dimensión:",
  paste(dim(wrapper_r), collapse = " x "),
  "\n"
)

# ============================================================================
# D. COMPARACIONES
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("[5] COMPARACIONES\n")
cat(strrep("=", 70), "\n\n")

compare <- function(a, b) {

  diff <- a - b

  c(
    max_abs = max(abs(diff)),
    mean_abs = mean(abs(diff)),
    rmse = sqrt(mean(diff^2))
  )
}

cat("DIRECT PYTHON vs WRAPPER PYTHON\n")

print(
  compare(
    direct_r,
    wrapper_python_r
  )
)

cat("\nWRAPPER PYTHON vs WRAPPER R\n")

print(
  compare(
    wrapper_python_r,
    wrapper_r
  )
)

cat("\nDIRECT PYTHON vs WRAPPER R\n")

print(
  compare(
    direct_r,
    wrapper_r
  )
)

# ============================================================================
# E. COMPARACIÓN POR FILA
# ============================================================================

cosine <- function(x, y) {

  sum(x * y) /
    sqrt(
      sum(x^2) *
        sum(y^2)
    )
}

cat("\n")
cat(strrep("=", 70), "\n")
cat("[6] COSENO POR FILA\n")
cat(strrep("=", 70), "\n\n")

cos_direct_wrapper_python <- vapply(
  seq_len(nrow(direct_r)),
  function(i) {
    cosine(
      direct_r[i, ],
      wrapper_python_r[i, ]
    )
  },
  numeric(1)
)

cos_direct_wrapper_r <- vapply(
  seq_len(nrow(direct_r)),
  function(i) {
    cosine(
      direct_r[i, ],
      wrapper_r[i, ]
    )
  },
  numeric(1)
)

result <- data.frame(
  fila = seq_along(textos_py),
  texto = textos_py,
  cos_python_wrapper = cos_direct_wrapper_python,
  cos_python_r = cos_direct_wrapper_r
)

print(result, row.names = FALSE)

cat("\n")
cat(strrep("=", 70), "\n")

if (
  max(abs(direct_r - wrapper_python_r)) <= 1e-7
) {

  cat(
    "PASS — encode_texts() funciona correctamente con una lista Python.\n"
  )

} else {

  cat(
    "FAIL — encode_texts() difiere incluso con una lista Python.\n"
  )
}

cat(strrep("=", 70), "\n")