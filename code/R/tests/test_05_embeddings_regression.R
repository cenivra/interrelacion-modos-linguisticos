# ============================================================================
# test_05_embeddings_regression.R
# ============================================================================
# REGRESIÓN DEL MÓDULO 05_embeddings.R
# ============================================================================

cat("\n")
cat(strrep("=", 78), "\n")
cat("REGRESIÓN — R/05_embeddings.R\n")
cat(strrep("=", 78), "\n\n")

suppressPackageStartupMessages({
  library(reticulate)
})

use_python(
  "C:/venvs/renv311/Scripts/python.exe",
  required = TRUE
)

# Cargar exclusivamente el módulo bajo prueba.
source(
  file.path(
    getwd(),
    "R",
    "05_embeddings.R"
  ),
  local = TRUE
)

# ---------------------------------------------------------------------------
# 1. FUNCIONES PRINCIPALES
# ---------------------------------------------------------------------------

required_functions <- c(
  "obtener_embeddings",
  "construir_centroide",
  "calcular_similitud_coseno",
  "calcular_proximidad_prototipos"
)

cat("[1] FUNCIONES\n\n")

for (fn in required_functions) {

  exists_fn <- exists(
    fn,
    inherits = TRUE
  )

  cat(
    fn,
    ": ",
    ifelse(exists_fn, "PASS", "FAIL"),
    "\n",
    sep = ""
  )

  if (!exists_fn) {
    stop(
      "Falta la función requerida: ",
      fn
    )
  }
}

# ---------------------------------------------------------------------------
# 2. PROTOTIPOS
# ---------------------------------------------------------------------------

cat("\n")
cat("[2] PROTOTIPOS\n\n")

cat(
  "Hopper:",
  length(prototipos_hopper),
  "\n"
)

cat(
  "Clínicos:",
  length(prototipos_clinicos),
  "\n"
)

cat(
  "Total:",
  length(prototipos),
  "\n"
)

stopifnot(
  length(prototipos_hopper) == 10,
  length(prototipos_clinicos) == 10,
  length(prototipos) == 20
)

for (nombre in names(prototipos)) {

  n_frases <- length(
    prototipos[[nombre]]
  )

  cat(
    sprintf(
      "  %-25s %d frases\n",
      nombre,
      n_frases
    )
  )

  stopifnot(
    n_frases == 5
  )
}

cat("PASS — estructura de prototipos intacta.\n")

# ---------------------------------------------------------------------------
# 3. EMBEDDINGS BÁSICOS
# ---------------------------------------------------------------------------

cat("\n")
cat("[3] EMBEDDINGS BÁSICOS\n\n")

textos <- c(
  "Me siento solo y aislado de los demás.",
  "Tengo esperanza de que las cosas mejoren.",
  "La incertidumbre me impide avanzar.",
  "",
  NA_character_
)

emb <- obtener_embeddings(
  textos,
  normalize = TRUE,
  batch_size = 4L
)

cat(
  "Dimensión:",
  paste(dim(emb), collapse = " x "),
  "\n"
)

stopifnot(
  is.matrix(emb),
  nrow(emb) == 5,
  ncol(emb) == 384
)

normas <- sqrt(
  rowSums(emb^2)
)

cat(
  "Norma mínima:",
  sprintf("%.15f", min(normas)),
  "\n"
)

cat(
  "Norma máxima:",
  sprintf("%.15f", max(normas)),
  "\n"
)

stopifnot(
  all(
    abs(normas - 1) < 1e-7
  )
)

cat("PASS — embeddings básicos.\n")

# ---------------------------------------------------------------------------
# 4. NA Y VACÍOS
# ---------------------------------------------------------------------------

cat("\n")
cat("[4] NA / VACÍOS\n\n")

emb_vacios <- obtener_embeddings(
  c("", NA_character_),
  normalize = TRUE
)

cosine <- function(x, y) {

  sum(x * y) /
    sqrt(
      sum(x^2) *
        sum(y^2)
    )
}

cos_vacios <- cosine(
  emb_vacios[1, ],
  emb_vacios[2, ]
)

cat(
  "Coseno '' vs NA:",
  sprintf("%.15f", cos_vacios),
  "\n"
)

stopifnot(
  cos_vacios >= 0.9999999
)

cat("PASS — '' y NA tienen representación idéntica.\n")

# ---------------------------------------------------------------------------
# 5. CACHÉ
# ---------------------------------------------------------------------------

cat("\n")
cat("[5] CACHÉ\n\n")

emb_cache_1 <- obtener_embeddings(
  "Texto de prueba de caché.",
  normalize = TRUE
)

emb_cache_2 <- obtener_embeddings(
  "Texto de prueba de caché.",
  normalize = TRUE
)

cache_diff <- max(
  abs(
    emb_cache_1 -
      emb_cache_2
  )
)

cat(
  "Diferencia entre llamadas:",
  sprintf("%.15e", cache_diff),
  "\n"
)

stopifnot(
  cache_diff == 0
)

cat("PASS — caché estable.\n")

# ---------------------------------------------------------------------------
# 6. CENTROIDE
# ---------------------------------------------------------------------------

cat("\n")
cat("[6] CENTROIDE\n\n")

centroide <- construir_centroide(
  prototipos_hopper$soledad,
  normalize = TRUE
)

cat(
  "Dimensión:",
  length(centroide),
  "\n"
)

centroide_norm <- sqrt(
  sum(centroide^2)
)

cat(
  "Norma:",
  sprintf("%.15f", centroide_norm),
  "\n"
)

stopifnot(
  length(centroide) == 384,
  abs(centroide_norm - 1) < 1e-7
)

cat("PASS — centroide válido.\n")

# ---------------------------------------------------------------------------
# 7. PROXIMIDAD A PROTOTIPOS
# ---------------------------------------------------------------------------

cat("\n")
cat("[7] PROXIMIDAD A PROTOTIPOS\n\n")

centroides <- list(
  soledad = centroide,
  tristeza = construir_centroide(
    prototipos_clinicos$tristeza,
    normalize = TRUE
  )
)

proximidad <- calcular_proximidad_prototipos(
  emb[1:3, , drop = FALSE],
  centroides
)

cat(
  "Dimensión:",
  paste(dim(proximidad), collapse = " x "),
  "\n"
)

print(proximidad)

stopifnot(
  is.data.frame(proximidad),
  nrow(proximidad) == 3,
  ncol(proximidad) == 2
)

stopifnot(
  all(
    is.finite(
      as.matrix(proximidad)
    )
  )
)

stopifnot(
  all(
    as.matrix(proximidad) >= -1,
    as.matrix(proximidad) <= 1
  )
)

cat("PASS — proximidad válida.\n")

# ---------------------------------------------------------------------------
# 8. SIMILITUD COSENO
# ---------------------------------------------------------------------------

cat("\n")
cat("[8] SIMILITUD COSENO\n\n")

sim_igual <- calcular_similitud_coseno(
  emb[1, , drop = FALSE],
  emb[1, , drop = FALSE]
)

cat(
  "Similitud idéntica:",
  sprintf("%.15f", sim_igual[1]),
  "\n"
)

stopifnot(
  abs(sim_igual[1] - 1) < 1e-7
)

cat("PASS — similitud coseno.\n")

# ---------------------------------------------------------------------------
# 9. RESULTADO FINAL
# ---------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 78), "\n")
cat("PASS — REGRESIÓN DE 05_embeddings.R COMPLETADA.\n")
cat(strrep("=", 78), "\n")