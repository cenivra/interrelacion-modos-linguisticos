# ============================================================================
# AUDITORIA ESTRUCTURAL DE ARCHIVOS RDS
# ============================================================================

cat("\n")
cat(strrep("=", 78), "\n")
cat("AUDITORÍA ESTRUCTURAL DE RDS\n")
cat(strrep("=", 78), "\n\n")

archivos <- list.files(
  path = ".",
  pattern = "\\.rds$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

for (f in sort(archivos)) {

  cat("\n")
  cat(strrep("-", 78), "\n")
  cat("ARCHIVO:\n")
  cat(f, "\n")
  cat(strrep("-", 78), "\n")

  obj <- tryCatch(
    readRDS(f),
    error = function(e) {
      cat("ERROR AL LEER:", conditionMessage(e), "\n")
      return(NULL)
    }
  )

  if (is.null(obj)) {
    cat("OBJETO = NULL o ERROR\n")
    next
  }

  cat("Clase:\n")
  print(class(obj))

  cat("\nTipo interno:\n")
  print(typeof(obj))

  cat("\nLongitud:\n")
  print(length(obj))

  cat("\nDimensión:\n")
  print(dim(obj))

  cat("\nNombres:\n")
  nm <- names(obj)

  if (is.null(nm)) {
    cat("NULL\n")
  } else {
    print(nm)
  }

  cat("\nEstructura resumida:\n")
  print(
    utils::capture.output(
      str(
        obj,
        max.level = 2,
        vec.len = 5
      )
    )
  )
}