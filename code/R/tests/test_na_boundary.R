# ============================================================================
# test_na_boundary.R
# ============================================================================
# Diagnóstico mínimo de NA -> Python -> encode_texts()
# ============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("DIAGNÓSTICO MÍNIMO — NA EN LA FRONTERA R/PYTHON\n")
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

# ---------------------------------------------------------------------------
# CASO A — dos strings explícitos idénticos
# ---------------------------------------------------------------------------

a <- c(
  "[VACÍO]",
  "[VACÍO]"
)

# ---------------------------------------------------------------------------
# CASO B — string vacío + NA
# ---------------------------------------------------------------------------

b <- c(
  "",
  NA_character_
)

cat("[1] VECTOR A EN R\n")
print(a)

cat("\n[2] VECTOR B EN R\n")
print(b)

# ---------------------------------------------------------------------------
# Enviar ambos directamente a Python
# ---------------------------------------------------------------------------

py$a <- a
py$b <- b

py_run_string("
print('\\n--- PYTHON: A ---')
print(type(a))
print(len(a))

for i, x in enumerate(a):
    print(i + 1, repr(x), type(x))

print('\\n--- PYTHON: B ---')
print(type(b))
print(len(b))

for i, x in enumerate(b):
    print(i + 1, repr(x), type(x))
")

# ---------------------------------------------------------------------------
# Aplicar exactamente la lógica de limpieza del wrapper
# ---------------------------------------------------------------------------

py_run_string("
def inspect_processing(values):

    values = list(values)

    processed = []

    for text in values:

        print(
            'INPUT:',
            repr(text),
            type(text)
        )

        if text is None:
            processed.append('[VACÍO]')

        elif not isinstance(text, str):
            processed.append(
                f'<NO_STR:{type(text).__name__}>'
            )

        elif text.strip() == '':
            processed.append('[VACÍO]')

        else:
            processed.append(text)

    print('PROCESSED:')

    for i, text in enumerate(processed):
        print(i + 1, repr(text), type(text))

    return processed

processed_a = inspect_processing(a)
processed_b = inspect_processing(b)
")

cat("\n")
cat(strrep("=", 70), "\n")
cat("[3] RESULTADO DEL PROCESAMIENTO\n")
cat(strrep("=", 70), "\n")

processed_a_r <- py$processed_a
processed_b_r <- py$processed_b

cat("\nA procesado:\n")
print(processed_a_r)

cat("\nB procesado:\n")
print(processed_b_r)

# ---------------------------------------------------------------------------
# Embeddings
# ---------------------------------------------------------------------------

cat("\n")
cat(strrep("=", 70), "\n")
cat("[4] EMBEDDINGS\n")
cat(strrep("=", 70), "\n\n")

emb_a <- encode_texts(
  a,
  normalize = TRUE,
  batch_size = 32L
)

emb_b <- encode_texts(
  b,
  normalize = TRUE,
  batch_size = 32L
)

cat(
  "A dimensión:",
  paste(dim(emb_a), collapse = " x "),
  "\n"
)

cat(
  "B dimensión:",
  paste(dim(emb_b), collapse = " x "),
  "\n"
)

# ---------------------------------------------------------------------------
# Comparaciones
# ---------------------------------------------------------------------------

cosine <- function(x, y) {

  sum(x * y) /
    sqrt(
      sum(x^2) *
        sum(y^2)
    )
}

cat("\n")
cat(strrep("=", 70), "\n")
cat("[5] COMPARACIÓN\n")
cat(strrep("=", 70), "\n\n")

cat(
  "A[1] vs A[2]: ",
  cosine(emb_a[1, ], emb_a[2, ]),
  "\n"
)

cat(
  "B[1] vs B[2]: ",
  cosine(emb_b[1, ], emb_b[2, ]),
  "\n"
)

cat(
  "A[1] vs B[1]: ",
  cosine(emb_a[1, ], emb_b[1, ]),
  "\n"
)

cat(
  "A[2] vs B[2]: ",
  cosine(emb_a[2, ], emb_b[2, ]),
  "\n"
)

cat(
  "A[2] vs B[1]: ",
  cosine(emb_a[2, ], emb_b[1, ]),
  "\n"
)

cat(
  "A[1] vs B[2]: ",
  cosine(emb_a[1, ], emb_b[2, ]),
  "\n"
)

cat("\n")
cat(strrep("=", 70), "\n")
cat("FIN DEL DIAGNÓSTICO\n")
cat(strrep("=", 70), "\n")