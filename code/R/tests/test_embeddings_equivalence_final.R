# ============================================================================
# test_embeddings_equivalence_final.R
# ============================================================================
# TEST DEFINITIVO DE EQUIVALENCIA
#
# Objetivo:
# comparar el pipeline antiguo y el nuevo despuÃƒÂ©s de normalizar NA en R.
#
# Pipeline A Ã¢â‚¬â€ LEGACY:
#   SentenceTransformer
#   -> encode sin normalizaciÃƒÂ³n interna
#   -> conversiÃƒÂ³n Python -> R
#   -> normalizaciÃƒÂ³n L2 en R
#
# Pipeline B Ã¢â‚¬â€ NUEVO:
#   R normaliza NA/vacÃƒÂ­os
#   -> encode_texts()
#   -> normalizaciÃƒÂ³n L2 en Python
#   -> conversiÃƒÂ³n Python -> R
#
# Criterio:
#   max_abs <= 1e-7
#   mean_abs <= 1e-8
#   RMSE <= 1e-9
#   coseno mÃƒÂ­nimo >= 1 - 1e-9
#
# No modificar producciÃƒÂ³n hasta que este test pase.
# ============================================================================

cat("\n")
cat(strrep("=", 78), "\n")
cat("TEST DEFINITIVO Ã¢â‚¬â€ EQUIVALENCIA EMBEDDINGS LEGACY vs NUEVO\n")
cat(strrep("=", 78), "\n\n")

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

# ---------------------------------------------------------------------------
# 1. DATOS FIJOS DE PRUEBA
# ---------------------------------------------------------------------------

textos_originales <- c(
  "Me siento solo y aislado de los demÃƒÂ¡s.",
  "Tengo esperanza de que las cosas mejoren.",
  "La incertidumbre me impide avanzar.",
  "Busco maneras de enfrentar las dificultades.",
  "No logro comunicarme con los demÃƒÂ¡s.",
  "La tristeza y el dolor me acompaÃƒÂ±an constantemente.",
  "Tengo control sobre mis decisiones.",
  "",
  NA_character_
)

# ---------------------------------------------------------------------------
# 2. NORMALIZACIÃƒâ€œN EXACTAMENTE COMO EN EL PIPELINE LEGACY
# ---------------------------------------------------------------------------

textos <- as.character(textos_originales)

textos[
  is.na(textos) |
    trimws(textos) == ""
] <- "[VACÃƒÂO]"

cat("[1] TEXTOS NORMALIZADOS\n\n")

for (i in seq_along(textos)) {
  cat(
    sprintf(
      "%d: %s\n",
      i,
      dQuote(textos[i])
    )
  )
}

# ---------------------------------------------------------------------------
# 3. PIPELINE LEGACY
# ---------------------------------------------------------------------------

cat("\n")
cat(strrep("-", 78), "\n")
cat("[2] PIPELINE LEGACY\n")
cat(strrep("-", 78), "\n\n")

py$textos_legacy <- textos

py_run_string("
legacy_embeddings = model.encode(
    textos_legacy,
    convert_to_numpy=True,
    normalize_embeddings=False,
    show_progress_bar=False
)

legacy_embeddings = legacy_embeddings.astype('float64')
")

legacy <- py$legacy_embeddings

if (
  is.null(dim(legacy)) ||
  length(dim(legacy)) < 2
) {
  legacy <- matrix(
    legacy,
    nrow = length(textos)
  )
}

# NormalizaciÃƒÂ³n exactamente equivalente a la funciÃƒÂ³n R original.

legacy_norms <- sqrt(
  rowSums(legacy^2)
)

legacy_norms[
  legacy_norms < 1e-12
] <- 1

legacy <- legacy / legacy_norms

cat(
  "DimensiÃƒÂ³n legacy:",
  paste(dim(legacy), collapse = " x "),
  "\n"
)

cat(
  "Norma mÃƒÂ­nima:",
  sprintf("%.15f", min(sqrt(rowSums(legacy^2)))),
  "\n"
)

cat(
  "Norma mÃƒÂ¡xima:",
  sprintf("%.15f", max(sqrt(rowSums(legacy^2)))),
  "\n"
)

# ---------------------------------------------------------------------------
# 4. PIPELINE NUEVO
# ---------------------------------------------------------------------------

cat("\n")
cat(strrep("-", 78), "\n")
cat("[3] PIPELINE NUEVO\n")
cat(strrep("-", 78), "\n\n")

nuevo <- encode_texts(
  textos,
  normalize = TRUE,
  batch_size = 32L
)

cat(
  "DimensiÃƒÂ³n nueva:",
  paste(dim(nuevo), collapse = " x "),
  "\n"
)

cat(
  "Norma mÃƒÂ­nima:",
  sprintf("%.15f", min(sqrt(rowSums(nuevo^2)))),
  "\n"
)

cat(
  "Norma mÃƒÂ¡xima:",
  sprintf("%.15f", max(sqrt(rowSums(nuevo^2)))),
  "\n"
)

# ---------------------------------------------------------------------------
# 5. COMPARACIÃƒâ€œN NUMÃƒâ€°RICA
# ---------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 78), "\n")
cat("[4] COMPARACIÃƒâ€œN NUMÃƒâ€°RICA\n")
cat(strrep("=", 78), "\n\n")

diff <- legacy - nuevo

max_abs <- max(
  abs(diff)
)

mean_abs <- mean(
  abs(diff)
)

rmse <- sqrt(
  mean(diff^2)
)

cat(
  "Diferencia absoluta mÃƒÂ¡xima:",
  sprintf("%.15e", max_abs),
  "\n"
)

cat(
  "Diferencia absoluta media:",
  sprintf("%.15e", mean_abs),
  "\n"
)

cat(
  "RMSE:",
  sprintf("%.15e", rmse),
  "\n"
)

# ---------------------------------------------------------------------------
# 6. COSENO FILA POR FILA
# ---------------------------------------------------------------------------

cosine <- function(x, y) {

  denom <- sqrt(
    sum(x^2) *
      sum(y^2)
  )

  if (denom < 1e-12) {
    return(NA_real_)
  }

  sum(x * y) / denom
}

cosenos <- vapply(
  seq_len(nrow(legacy)),
  function(i) {
    cosine(
      legacy[i, ],
      nuevo[i, ]
    )
  },
  numeric(1)
)

cat("\nCoseno mÃƒÂ­nimo:", sprintf("%.15f", min(cosenos)))
cat("\nCoseno mÃƒÂ¡ximo:", sprintf("%.15f", max(cosenos)))
cat("\n")

cat("\nCoseno por fila:\n")

resultado <- data.frame(
  fila = seq_along(textos),
  texto = textos,
  coseno = cosenos
)

print(
  resultado,
  row.names = FALSE
)

# ---------------------------------------------------------------------------
# 7. CRITERIOS DE ACEPTACIÃƒâ€œN
# ---------------------------------------------------------------------------

pass_max <- max_abs <= 1e-7
pass_mean <- mean_abs <= 1e-8
pass_rmse <- rmse <= 1e-8
pass_cosine <- min(cosenos) >= (1 - 1e-9)

cat("\n")
cat(strrep("=", 78), "\n")
cat("[5] CRITERIOS DE ACEPTACIÃƒâ€œN\n")
cat(strrep("=", 78), "\n\n")

cat(
  "max_abs <= 1e-7:     ",
  ifelse(pass_max, "PASS", "FAIL"),
  "\n"
)

cat(
  "mean_abs <= 1e-8:    ",
  ifelse(pass_mean, "PASS", "FAIL"),
  "\n"
)

cat(
  "RMSE <= 1e-8:        ",
  ifelse(pass_rmse, "PASS", "FAIL"),
  "\n"
)

cat(
  "coseno mÃƒÂ­nimo >= 1-1e-9: ",
  ifelse(pass_cosine, "PASS", "FAIL"),
  "\n"
)

all_pass <- all(
  pass_max,
  pass_mean,
  pass_rmse,
  pass_cosine
)

cat("\n")
cat(strrep("=", 78), "\n")

if (all_pass) {

  cat(
    "PASS Ã¢â‚¬â€ EQUIVALENCIA NUMÃƒâ€°RICA VALIDADA.\n"
  )

  cat(
    "La migraciÃƒÂ³n Python conserva el comportamiento cientÃƒÂ­fico del pipeline legacy.\n"
  )

  cat(
    "Se puede proceder al cambio mÃƒÂ­nimo en 05_embeddings.R.\n"
  )

} else {

  cat(
    "FAIL Ã¢â‚¬â€ EQUIVALENCIA NO VALIDADA.\n"
  )

  cat(
    "NO modificar 05_embeddings.R todavÃƒÂ­a.\n"
  )
}

cat(strrep("=", 78), "\n")