# ============================================================================
# test_embeddings_equivalence.R
# ============================================================================
# Prueba de equivalencia numÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rica entre:
#
#   A) ImplementaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n anterior:
#      SentenceTransformer -> encode sin normalizar -> normalizaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n L2 en R
#
#   B) ImplementaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n nueva:
#      embeddings_setup.py -> encode_texts(normalize = TRUE)
#
# No utiliza 05_embeddings.R.
# No utiliza datos reales.
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("PRUEBA DE EQUIVALENCIA ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â EMBEDDINGS ANTIGUO VS NUEVO\n")
cat(strrep("=", 70), "\n\n")


# ============================================================================
# 1. RETICULATE
# ============================================================================

suppressPackageStartupMessages({
  library(reticulate)
})

cat("[1] RETICULATE\n")
cat("VersiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n:", as.character(packageVersion("reticulate")), "\n\n")


# ============================================================================
# 2. PYTHON
# ============================================================================

python_path <- "C:/venvs/renv311/Scripts/python.exe"

use_python(
  python_path,
  required = TRUE
)

cfg <- py_config()

cat("[2] PYTHON CONFIGURADO\n")
cat("Python:", cfg$python, "\n")
cat("Python configurado correctamente.\n\n")


# ============================================================================
# 3. CARGAR IMPLEMENTACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN NUEVA
# ============================================================================

python_module <- normalizePath(
  file.path(
    getwd(),
    "python",
    "embeddings_setup.py"
  ),
  winslash = "/",
  mustWork = TRUE
)

cat("[3] CARGANDO IMPLEMENTACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN NUEVA\n")
cat("Archivo:", python_module, "\n\n")

source_python(python_module)


# ============================================================================
# 4. CONJUNTO DE TEXTOS FIJO
# ============================================================================

textos <- c(
  "Me siento solo y aislado de los demÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s.",
  "Tengo esperanza de que las cosas mejoren.",
  "La incertidumbre me impide avanzar.",
  "Busco maneras de enfrentar las dificultades.",
  "No logro comunicarme con los demÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s.",
  "La tristeza y el dolor me acompaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±an constantemente.",
  "Tengo control sobre mis decisiones.",
  "",
  NA_character_
)

cat("[4] TEXTOS DE PRUEBA\n")
cat("NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero de textos:", length(textos), "\n\n")

print(textos)

cat("\n")


# ============================================================================
# 5. CAMINO A ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â IMPLEMENTACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN ANTERIOR
# ============================================================================

cat(strrep("=", 70), "\n")
cat("[5] CAMINO A ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â IMPLEMENTACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN ANTERIOR\n")
cat(strrep("=", 70), "\n")

# PreparaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n equivalente a 05_embeddings.R
textos_old <- as.character(textos)

textos_old[
  is.na(textos_old) |
    trimws(textos_old) == ""
] <- "[VACÃƒÆ’Ã†â€™Ãƒâ€šÃ‚ÂO]"


# Crear modelo independiente con la misma configuraciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n
py_run_string("
from sentence_transformers import SentenceTransformer

old_embedding_model = SentenceTransformer(
    'paraphrase-multilingual-MiniLM-L12-v2'
)
")


# Enviar textos al entorno Python
py$textos_old <- textos_old


# CodificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n SIN normalizaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n.
# Esto reproduce el comportamiento anterior.
py_run_string("
old_embeddings_raw = old_embedding_model.encode(
    textos_old,
    convert_to_numpy=True,
    show_progress_bar=False
)

if old_embeddings_raw.ndim == 1:
    old_embeddings_raw = old_embeddings_raw.reshape(1, -1)

old_embeddings_raw = old_embeddings_raw.astype('float64')
")


emb_old <- py$old_embeddings_raw

if (is.null(dim(emb_old)) || length(dim(emb_old)) < 2) {
  emb_old <- matrix(
    emb_old,
    nrow = length(textos_old)
  )
}


# NormalizaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n L2 equivalente a 05_embeddings.R
normas_old <- sqrt(
  rowSums(emb_old^2)
)

normas_old[normas_old < 1e-12] <- 1

emb_old_norm <- emb_old / normas_old


cat("DimensiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n:", paste(dim(emb_old_norm), collapse = " x "), "\n")
cat("Normas L2:\n")
print(round(sqrt(rowSums(emb_old_norm^2)), 10))

cat("\n")


# ============================================================================
# 6. CAMINO B ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â IMPLEMENTACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN NUEVA
# ============================================================================

cat(strrep("=", 70), "\n")
cat("[6] CAMINO B ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â IMPLEMENTACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN NUEVA\n")
cat(strrep("=", 70), "\n")


emb_new <- encode_texts(
  textos,
  normalize = TRUE,
  batch_size = 32L
)


cat("DimensiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n:", paste(dim(emb_new), collapse = " x "), "\n")
cat("Normas L2:\n")
print(round(sqrt(rowSums(emb_new^2)), 10))

cat("\n")


# ============================================================================
# 7. VALIDACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN ESTRUCTURAL
# ============================================================================

cat(strrep("=", 70), "\n")
cat("[7] VALIDACIÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œN ESTRUCTURAL\n")
cat(strrep("=", 70), "\n")


stopifnot(
  identical(
    dim(emb_old_norm),
    dim(emb_new)
  )
)

stopifnot(
  ncol(emb_old_norm) == 384
)

stopifnot(
  all(is.finite(emb_old_norm))
)

stopifnot(
  all(is.finite(emb_new))
)

cat("PASS ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ambas matrices tienen la misma dimensiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n.\n")
cat("PASS ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ambas matrices tienen 384 dimensiones.\n")
cat("PASS ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ambas matrices contienen ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnicamente valores finitos.\n\n")


# ============================================================================
# 8. DIFERENCIA ELEMENTO A ELEMENTO
# ============================================================================

cat(strrep("=", 70), "\n")
cat("[8] DIFERENCIA NUMÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°RICA\n")
cat(strrep("=", 70), "\n")


diff_matrix <- emb_old_norm - emb_new

abs_diff <- abs(diff_matrix)

max_abs_diff <- max(
  abs_diff,
  na.rm = TRUE
)

mean_abs_diff <- mean(
  abs_diff,
  na.rm = TRUE
)

rmse_diff <- sqrt(
  mean(
    diff_matrix^2,
    na.rm = TRUE
  )
)


cat(
  "Diferencia absoluta mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡xima:",
  format(max_abs_diff, scientific = TRUE),
  "\n"
)

cat(
  "Diferencia absoluta media:",
  format(mean_abs_diff, scientific = TRUE),
  "\n"
)

cat(
  "RMSE de la diferencia:",
  format(rmse_diff, scientific = TRUE),
  "\n\n"
)


# ============================================================================
# 9. SIMILITUD ENTRE VECTORES CORRESPONDIENTES
# ============================================================================

cat(strrep("=", 70), "\n")
cat("[9] SIMILITUD COSENO ENTRE RESULTADOS\n")
cat(strrep("=", 70), "\n")


cosine_similarity <- function(x, y) {
  sum(x * y) /
    sqrt(sum(x^2) * sum(y^2))
}


cosines <- vapply(
  seq_len(nrow(emb_old_norm)),
  function(i) {
    cosine_similarity(
      emb_old_norm[i, ],
      emb_new[i, ]
    )
  },
  numeric(1)
)


cosine_diff_from_one <- abs(
  1 - cosines
)

cat("MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo:", format(min(cosines), digits = 12), "\n")
cat("MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo:", format(max(cosines), digits = 12), "\n")
cat(
  "MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡xima distancia respecto a coseno = 1:",
  format(max(cosine_diff_from_one), scientific = TRUE),
  "\n\n"
)


# ============================================================================
# 10. CRITERIO DE EQUIVALENCIA
# ============================================================================

cat(strrep("=", 70), "\n")
cat("[10] CRITERIO DE EQUIVALENCIA\n")
cat(strrep("=", 70), "\n")


# Tolerancias deliberadamente estrictas pero razonables
# para operaciones de punto flotante en CPU.
TOL_MAX <- 1e-5
TOL_MEAN <- 1e-7
TOL_COS <- 1e-7


pass_max <- max_abs_diff <= TOL_MAX
pass_mean <- mean_abs_diff <= TOL_MEAN
pass_cos <- max(cosine_diff_from_one) <= TOL_COS


cat(
  "MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡xima diferencia <= ",
  TOL_MAX,
  ": ",
  ifelse(pass_max, "PASS", "FAIL"),
  "\n",
  sep = ""
)

cat(
  "Diferencia media <= ",
  TOL_MEAN,
  ": ",
  ifelse(pass_mean, "PASS", "FAIL"),
  "\n",
  sep = ""
)

cat(
  "Distancia coseno <= ",
  TOL_COS,
  ": ",
  ifelse(pass_cos, "PASS", "FAIL"),
  "\n",
  sep = ""
)


# ============================================================================
# RESULTADO FINAL
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")

if (pass_max && pass_mean && pass_cos) {

  cat("PASS ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â equivalencia numÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rica validada.\n")
  cat("\n")
  cat("La implementaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n nueva reproduce el resultado del\n")
  cat("pipeline anterior dentro de las tolerancias establecidas.\n")

} else {

  cat("FAIL ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â equivalencia numÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rica NO validada.\n")
  cat("\n")
  cat("NO modificar 05_embeddings.R todavÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­a.\n")

  quit(
    status = 1
  )
}

cat(strrep("=", 70), "\n")