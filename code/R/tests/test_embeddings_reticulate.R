# ============================================================================
# test_embeddings_reticulate.R
# ============================================================================
# Prueba controlada del puente:
#
#     R -> reticulate -> Python -> encode_texts() -> R
#
# NO modifica R/05_embeddings.R
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("SISAP — PRUEBA R → RETICULATE → PYTHON → R\n")
cat(strrep("=", 70), "\n\n")


# ----------------------------------------------------------------------------
# 1. CARGAR RETICULATE
# ----------------------------------------------------------------------------

if (!requireNamespace("reticulate", quietly = TRUE)) {
  stop(
    "El paquete 'reticulate' no está instalado en el entorno R actual."
  )
}

library(reticulate)

cat("[1] RETICULATE\n")
cat("Versión: ", as.character(packageVersion("reticulate")), "\n\n", sep = "")


# ----------------------------------------------------------------------------
# 2. CONFIGURAR EL PYTHON CONTROLADO
# ----------------------------------------------------------------------------

python_path <- "C:/venvs/renv311/Scripts/python.exe"

if (!file.exists(python_path)) {
  stop(
    "No se encontró el Python esperado:\n",
    python_path
  )
}

use_python(python_path, required = TRUE)

cat("[2] PYTHON CONFIGURADO\n")
cat("Python: ", py_config()$python, "\n", sep = "")
cat("Versión: ", py_config()$version_string, "\n\n", sep = "")


# ----------------------------------------------------------------------------
# 3. CARGAR embeddings_setup.py
# ----------------------------------------------------------------------------

python_module <- file.path(
  getwd(),
  "python",
  "embeddings_setup.py"
)

if (!file.exists(python_module)) {
  stop(
    "No se encontró embeddings_setup.py:\n",
    python_module
  )
}

cat("[3] CARGANDO MÓDULO PYTHON\n")
cat("Archivo: ", python_module, "\n\n", sep = "")

source_python(python_module)


# ----------------------------------------------------------------------------
# 4. OBTENER METADATOS DEL MODELO
# ----------------------------------------------------------------------------

cat(strrep("=", 70), "\n")
cat("[4] INFORMACIÓN DEL MODELO\n")
cat(strrep("=", 70), "\n")

info <- get_model_info()

print(info)


# ----------------------------------------------------------------------------
# 5. PRUEBA 1 — TEXTO NORMAL
# ----------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 70), "\n")
cat("[5] PRUEBA 1 — TEXTO NORMAL\n")
cat(strrep("=", 70), "\n")

texto_normal <- c(
  "Me siento solo y aislado de los demás"
)

emb_normal <- encode_texts(
  texto_normal,
  normalize = TRUE,
  batch_size = 32L
)

emb_normal <- as.matrix(emb_normal)

cat("Clase R: ", paste(class(emb_normal), collapse = ", "), "\n", sep = "")
cat("Dimensión: ", paste(dim(emb_normal), collapse = " x "), "\n", sep = "")
cat("Dtype recibido/conversión R: numeric\n")
cat(
  "Norma L2: ",
  format(sqrt(sum(emb_normal[1, ]^2)), digits = 12),
  "\n",
  sep = ""
)

stopifnot(
  identical(dim(emb_normal), c(1L, 384L))
)

stopifnot(
  isTRUE(
    all.equal(
      sqrt(sum(emb_normal[1, ]^2)),
      1,
      tolerance = 1e-6
    )
  )
)

cat("PASS — R recibió correctamente 1 × 384 normalizado.\n")


# ----------------------------------------------------------------------------
# 6. PRUEBA 2 — VACÍOS / NA
# ----------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 70), "\n")
cat("[6] PRUEBA 2 — VACÍOS / NA\n")
cat(strrep("=", 70), "\n")

textos_vacios <- c(
  "",
  "   ",
  NA_character_
)

# Reproducimos aquí el contrato que actualmente existe en 05_embeddings.R:
# NA / vacío -> "[VACÍO]"
textos_vacios <- as.character(textos_vacios)
textos_vacios[
  is.na(textos_vacios) | trimws(textos_vacios) == ""
] <- "[VACÍO]"

cat("Textos enviados a Python:\n")
print(textos_vacios)

emb_vacios <- encode_texts(
  textos_vacios,
  normalize = TRUE,
  batch_size = 32L
)

emb_vacios <- as.matrix(emb_vacios)

cat("\nDimensión: ", paste(dim(emb_vacios), collapse = " x "), "\n", sep = "")

stopifnot(
  identical(dim(emb_vacios), c(3L, 384L))
)

normas_vacios <- sqrt(rowSums(emb_vacios^2))

cat("Normas L2:\n")
print(normas_vacios)

stopifnot(
  all(abs(normas_vacios - 1) <= 1e-6)
)

cat("PASS — vacíos/NA producen 3 × 384 normalizado.\n")


# ----------------------------------------------------------------------------
# 7. PRUEBA 3 — VARIOS TEXTOS
# ----------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 70), "\n")
cat("[7] PRUEBA 3 — VARIOS TEXTOS\n")
cat(strrep("=", 70), "\n")

textos <- c(
  "Me siento solo y aislado de los demás",
  "Tengo esperanza de que las cosas mejoren",
  "No sé lo que va a pasar mañana",
  "Busco maneras de enfrentar las dificultades",
  "Prefiero no pensar en los problemas"
)

emb_multi <- encode_texts(
  textos,
  normalize = TRUE,
  batch_size = 2L
)

emb_multi <- as.matrix(emb_multi)

cat("Número de textos: ", length(textos), "\n", sep = "")
cat("Dimensión: ", paste(dim(emb_multi), collapse = " x "), "\n", sep = "")

stopifnot(
  identical(dim(emb_multi), c(5L, 384L))
)

normas_multi <- sqrt(rowSums(emb_multi^2))

cat("\nNormas L2:\n")
print(normas_multi)

stopifnot(
  all(abs(normas_multi - 1) <= 1e-6)
)

cat("PASS — R recibió correctamente 5 × 384 normalizado.\n")


# ----------------------------------------------------------------------------
# 8. PRUEBA 4 — COMPROBAR TIPO Y VALORES FINITOS
# ----------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 70), "\n")
cat("[8] INTEGRIDAD NUMÉRICA\n")
cat(strrep("=", 70), "\n")

cat(
  "Valores no finitos: ",
  sum(!is.finite(emb_multi)),
  "\n",
  sep = ""
)

stopifnot(
  all(is.finite(emb_multi))
)

cat("Rango observado:\n")
cat(
  "  mínimo = ",
  format(min(emb_multi), digits = 8),
  "\n",
  sep = ""
)
cat(
  "  máximo = ",
  format(max(emb_multi), digits = 8),
  "\n",
  sep = ""
)

cat("PASS — todos los valores son finitos.\n")


# ----------------------------------------------------------------------------
# 9. RESULTADO FINAL
# ----------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 70), "\n")
cat("RESULTADO FINAL\n")
cat(strrep("=", 70), "\n")

cat("PASS — puente R → reticulate → Python → R validado.\n")

cat("\nContrato validado:\n")
cat("  [✓] Python controlado\n")
cat("  [✓] embeddings_setup.py cargado desde R\n")
cat("  [✓] encode_texts() invocado desde R\n")
cat("  [✓] numpy.ndarray recibido por R\n")
cat("  [✓] conversión a matriz R\n")
cat("  [✓] dimensión n × 384\n")
cat("  [✓] normalización L2\n")
cat("  [✓] tratamiento de textos vacíos/NA\n")
cat("  [✓] valores numéricos finitos\n")

cat("\n")
cat(strrep("=", 70), "\n")
