# ============================================================================
# GENERADOR DE INFORMES — piloto / principal / combinado
# ----------------------------------------------------------------------------
# Lee los artefactos que produce 'Experimento ALC_v5_corregido.R' en
# 'Analisis agosto v2' y escribe tres informes en markdown en 'informes/'.
#
# Reglas:
#  - Solo se publican AGREGADOS (n, medias, sd, efectos, p). Nunca narrativas.
#  - Si un artefacto no existe, se declara como ausente en lugar de inventarlo.
# ============================================================================

RAIZ <- normalizePath(".", winslash = "/", mustWork = FALSE)
DIR_INF <- file.path(RAIZ, "informes")
dir.create(DIR_INF, recursive = TRUE, showWarnings = FALSE)
opciones_num <- options(digits = 4, scipen = 999)

# ── utilidades ──────────────────────────────────────────────────────────────
faltantes <- character(0)

leer <- function(...) {
  p <- file.path(RAIZ, ...)
  if (!file.exists(p)) { faltantes <<- c(faltantes, paste0(..., collapse = "/")); return(NULL) }
  tryCatch(utils::read.csv(p, fileEncoding = "UTF-8", check.names = FALSE, stringsAsFactors = FALSE),
           error = function(e) { faltantes <<- c(faltantes, paste0(..., collapse = "/")); NULL })
}

leer_txt <- function(...) {
  p <- file.path(RAIZ, ...)
  if (!file.exists(p)) { faltantes <<- c(faltantes, paste0(..., collapse = "/")); return(NULL) }
  readLines(p, warn = FALSE, encoding = "UTF-8")
}

num <- function(x, d = 3) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return("—")
  x <- as.numeric(x[1])
  if (is.na(x)) return("—")
  if (abs(x) < 1e-4 && x != 0) return(formatC(x, format = "e", digits = 2))
  formatC(x, format = "f", digits = d)
}

p_fmt <- function(p) {
  if (is.null(p) || is.na(p[1])) return("—")
  p <- as.numeric(p[1])
  if (is.na(p)) return("—")
  if (p < 1e-4) return(formatC(p, format = "e", digits = 2))
  formatC(p, format = "f", digits = 4)
}

sig <- function(p, alfa = 0.05) if (is.na(p[1])) "—" else if (as.numeric(p[1]) < alfa) "**sí**" else "no"

md <- function(df, d = 3) {
  if (is.null(df) || nrow(df) == 0) return("_(sin datos)_\n")
  df <- as.data.frame(df)
  for (j in seq_along(df)) {
    if (is.numeric(df[[j]])) df[[j]] <- vapply(df[[j]], function(v) num(v, d), character(1))
    else df[[j]] <- gsub("|", "/", as.character(df[[j]]), fixed = TRUE)
  }
  enc <- paste(names(df), collapse = " | ")
  sep <- paste(rep("---", ncol(df)), collapse = " | ")
  filas <- apply(df, 1, function(r) paste(r, collapse = " | "))
  paste0("| ", enc, " |\n| ", sep, " |\n", paste0("| ", filas, " |", collapse = "\n"), "\n")
}

seccion <- function(titulo) paste0("\n## ", titulo, "\n")
h3 <- function(titulo) paste0("\n### ", titulo, "\n")   # NO llamar `sub`: enmascara a base::sub()

# ── lectura de artefactos comunes ───────────────────────────────────────────
aud_pil   <- leer("piloto", "tablas", "auditoria_piloto.csv")
aud_pri   <- leer("piloto", "tablas", "auditoria_principal.csv")
celdas    <- leer("piloto", "tablas", "descriptivos_condicion_tiempo.csv")
modelos_v <- leer("piloto", "tablas", "resumen_modelos_validos.csv")
excl_pil  <- leer("piloto", "tablas", "piloto_modelos_excluidos.csv")
excl_pri  <- leer("piloto", "tablas", "principal_modelos_excluidos.csv")
comparac  <- leer("combinado", "tablas", "interaccion_fuente_tiempo.csv")
d_ling    <- leer("resultados", "tablas", "descriptivos_linguistica.csv")
d_hop     <- leer("resultados", "tablas", "descriptivos_hopper.csv")
d_sem     <- leer("resultados", "tablas", "descriptivos_semantica.csv")
d_proto   <- leer("resultados", "tablas", "cambios_prototipos.csv")
d_dist    <- leer("resultados", "tablas", "distancia_euclidiana.csv")
m_fdr     <- leer("resultados", "modelos", "modelos_mixtos_con_FDR.csv")
robustez  <- leer("outputs", "tablas", "tabla_robustez_modelos.csv")
resumen_ds <- leer_txt("resultados", "deepseek", "10_resumen_para_deepseek.txt")

narrativa_auditoria <- function(aud, etiqueta) {
  if (is.null(aud)) return(paste0("_No se generó la auditoría de variables de ", etiqueta, "._\n"))
  d <- aud
  ok <- if ("estado" %in% names(d)) sum(d$estado == "APTA_PARA_REVISION") else NA
  paste0(
    "Se auditaron **", nrow(d), " variables**. ",
    if (!is.na(ok)) paste0("De ellas, **", ok, "** pasaron el filtro de calidad (`APTA_PARA_REVISION`) y ",
                           nrow(d) - ok, " se excluyeron.\n") else "",
    "\n", md(d[, intersect(c("variable", "estado", "n_participantes", "n_completos", "sd_global", "motivo"), names(d))], 2))
}

bloque_modelos <- function(d, etiqueta) {
  if (is.null(d)) return(paste0("_No se generó la tabla de modelos válidos._\n"))
  vars <- unique(d$variable)
  out <- c(paste0("Se ajustaron modelos lineales mixtos (`valor ~ condición × tiempo + (1|participante)`, ",
                  "REML, Satterthwaite) para **", length(vars), " variables** en la cohorte **", etiqueta, "**: ",
                  paste0("`", vars, "`", collapse = ", "), ".\n"),
           "", md(d, 4))
  # frases automáticas por variable
  for (v in vars) {
    dv <- d[d$variable == v, , drop = FALSE]
    ft <- dv[grepl("tiempo", dv$efecto), , drop = FALSE]
    fi <- dv[grepl(":", dv$efecto), , drop = FALSE]
    if (nrow(ft) > 0) {
      out <- c(out, paste0("- **", v, "**: efecto de tiempo F = ", num(ft$F[1]),
                           " (p = ", p_fmt(ft$p[1]), ") → significativo: ", sig(ft$p[1]), "."))
    }
    if (nrow(fi) > 0) {
      out <- c(out, paste0("  Interacción condición×tiempo: F = ", num(fi$F[1]), " (p = ", p_fmt(fi$p[1]),
                           ") → significativa: ", sig(fi$p[1]), "."))
    }
    if (!is.null(dv$R2_marginal)) {
      out <- c(out, paste0("  R² marginal = ", num(dv$R2_marginal[1]), "; R² condicional = ", num(dv$R2_condicional[1]), "."))
    }
  }
  paste0(paste(out, collapse = "\n"), "\n")
}

bloque_excluidos <- function(d, etiqueta) {
  if (is.null(d) || nrow(d) == 0)
    return(paste0("_Ninguna variable quedó excluida del modelado en la cohorte ", etiqueta, "._\n"))
  paste0("Variables que **no** pudieron modelarse y el motivo registrado:\n\n", md(d, 3))
}

tabla_celdas <- function(d, fuente, variable) {
  if (is.null(d)) return(NULL)
  x <- d[d$fuente == fuente & d$variable == variable, , drop = FALSE]
  if (nrow(x) == 0) return(NULL)
  x[, intersect(c("condicion", "tiempo", "n", "media", "sd", "mediana", "minimo", "maximo"), names(x))]
}

# ── EMM y contrastes por variable (cohorte) ─────────────────────────────────
bloque_emm <- function(cohorte, etiqueta) {
  if (is.null(modelos_v)) return("")
  vars <- unique(modelos_v$variable[modelos_v$fuente == etiqueta])
  if (length(vars) == 0) return("")
  out <- c(seccion(paste0("Medias marginales estimadas y contrastes — ", cohorte)))
  for (v in vars) {
    emm <- leer(cohorte, "tablas", paste0(cohorte, "_", v, "_EMM.csv"))
    cc  <- leer(cohorte, "tablas", paste0(cohorte, "_", v, "_contrastes_cond.csv"))
    ct  <- leer(cohorte, "tablas", paste0(cohorte, "_", v, "_contrastes_tiempo.csv"))
    out <- c(out, h3(paste0("`", v, "`")))
    if (!is.null(emm)) out <- c(out, "Medias marginales (emmeans):", "", md(emm, 3))
    if (!is.null(cc))  out <- c(out, "Contrastes **entre condiciones** en cada tiempo (ajuste Holm):", "", md(cc, 3))
    if (!is.null(ct))  out <- c(out, "Contrastes **entre tiempos** en cada condición (ajuste Holm):", "", md(ct, 3))
  }
  paste0(paste(out, collapse = "\n"), "\n")
}

# ── lista de figuras de una carpeta ─────────────────────────────────────────
figuras_de <- function(...) {
  p <- file.path(RAIZ, ...)
  if (!dir.exists(p)) { faltantes <<- c(faltantes, paste0(..., collapse = "/")); return("_(sin figuras)_\n") }
  fs <- list.files(p, pattern = "\\.(png|pdf)$", recursive = TRUE)
  if (length(fs) == 0) return("_(carpeta vacía)_\n")
  paste0(paste0("- `", p, "/", sort(fs), "`", collapse = "\n"), "\n")
}

# ============================================================================
# CUERPOS DE LOS TRES INFORMES
# ============================================================================
FECHA <- format(Sys.time(), "%Y-%m-%d %H:%M")
ENCABEZADO <- function(titulo, sub_titulo, n_cohorte) {
  c(paste0("# ", titulo), "",
    paste0("**Generado:** ", FECHA, "  "),
    paste0("**Cohorte:** ", sub_titulo, "  "),
    paste0("**Datos de origen:** `Analisis agosto v2/` (corrida del script `Experimento ALC_v5_corregido.R`)  "),
    paste0("**Contenido:** solo agregados (n, medias, desviaciones, efectos, p-valores). ",
           "Este informe **no contiene narrativas** de participantes.  "),
    paste0("**Muestra:** ", n_cohorte, "  "), "",
    "---", "")
}

flujo_participantes <- function(ancho_rds, etiqueta) {
  if (!file.exists(ancho_rds)) { faltantes <<- c(faltantes, basename(ancho_rds)); return("_(no se encontró el objeto ancho)_\n") }
  a <- tryCatch(readRDS(ancho_rds), error = function(e) NULL)
  if (is.null(a)) return("_(no se pudo leer el objeto ancho)_\n")
  t1 <- as.data.frame(table(a$condicion))
  names(t1) <- c("condición", "participantes")
  if ("demora" %in% names(a)) {
    dm <- a$demora; dm[is.na(dm)] <- "(no capturada)"
    t2 <- as.data.frame(table(dm)); names(t2) <- c("demora", "participantes")
  } else t2 <- NULL
  res <- c(paste0("- Participantes: **", nrow(a), "**"),
           paste0("- Observaciones por participante: **3** (T1, T2, T3) → total ",
                  nrow(a) * 3, " observaciones"),
           "", "Reparto por condición:", "", md(t1, 0))
  if (!is.null(t2)) res <- c(res, "Reparto por demora:", "", md(t2, 0))
  paste0(paste(res, collapse = "\n"), "\n")
}

informe <- function(nombre, titulo, sub_titulo, n_cohorte, cohorte, etiqueta, ancho_rds, dir_figs) {
  L <- ENCABEZADO(titulo, sub_titulo, n_cohorte)

  L <- c(L, seccion("1. Diseño y flujo de participantes"),
         "Tres iteraciones por participante: **T1** sin estímulo (línea base), **T2** un estímulo, ",
         "**T3** tres estímulos acumulados. Condiciones: Texto (leer), Audio (escuchar), Imagen (observar).", "",
         flujo_participantes(ancho_rds, etiqueta))

  L <- c(L, seccion("2. Auditoría de variables: qué se pudo modelar y qué no"),
         narrativa_auditoria(if (etiqueta == "piloto") aud_pil else aud_pri, etiqueta),
         "Variables excluidas del modelado:", "", bloque_excluidos(if (etiqueta == "piloto") excl_pil else excl_pri, etiqueta))

  L <- c(L, seccion("3. Descriptivos por condición e iteración"))
  if (is.null(celdas)) {
    L <- c(L, "_No se generó la tabla de descriptivos por condición e iteración._")
  } else {
    vars <- unique(celdas$variable[celdas$fuente == etiqueta])
    for (v in vars) {
      tb <- tabla_celdas(celdas, etiqueta, v)
      if (!is.null(tb)) L <- c(L, h3(paste0("`", v, "`")), md(tb, 3))
    }
  }

  L <- c(L, seccion("4. Modelos lineales mixtos"),
         "Especificación: `valor ~ condición × tiempo + (1 | participante)`, estimación REML, ",
         "grados de libertad Satterthwaite. La condición es un factor **entre** sujetos y el tiempo **intra** sujeto.", "",
         bloque_modelos(if (is.null(modelos_v)) NULL else modelos_v[modelos_v$fuente == etiqueta, , drop = FALSE], etiqueta))

  L <- c(L, bloque_emm(cohorte, etiqueta))

  L <- c(L, seccion("5. Figuras"),
         figuras_de(dir_figs, "graficas_es"), figuras_de(dir_figs, "figures_en"))

  L <- c(L, seccion("6. Lo que este informe NO permite afirmar"))
  if (etiqueta == "piloto") {
    L <- c(L, "- La cohorte piloto **no tiene `demora`**: cualquier comparación D/ND es del estudio principal.",
           "- En el piloto `n_palabras` está **vacía** en el archivo de captura; la medida usada es",
           "  `n_palabras_calculado` (conteo desde el texto).",
           "- Con 17 participantes y 6/6/5 por condición, los contrastes **entre condiciones** tienen potencia muy baja:",
           "  la ausencia de diferencias no es evidencia de ausencia de efecto.",
           "- Los análisis semánticos, de prototipos y de diccionarios del conjunto de 40 **no** están",
           "  desagregados por cohorte en las tablas conjuntas (ver informe combinado).")
  } else {
    L <- c(L, "- Los grupos por condición × demora son pequeños (varias celdas con n ≤ 5):",
           "  la interacción triple condición × demora × tiempo no es estimable con estabilidad.",
           "- Las tablas conjuntas de 40 participantes mezclan cohortes; aquí se usan solo las del principal.")
  }
  L <- c(L, "")

  L <- c(L, seccion("7. Trazabilidad"),
         "Artefactos de los que sale cada número (rutas relativas a `Analisis agosto v2/`):", "",
         paste0("- `", cohorte, "/tablas/auditoria_", etiqueta, ".csv`"),
         paste0("- `", cohorte, "/tablas/descriptivos_condicion_tiempo.csv`"),
         paste0("- `", cohorte, "/tablas/resumen_modelos_validos.csv`"),
         paste0("- `", cohorte, "/tablas/", cohorte, "_<variable>_EMM.csv` y `..._contrastes_{cond,tiempo}.csv`"),
         paste0("- `", cohorte, "/modelos/modelos_", etiqueta, ".rds`"),
         paste0("- `", dir_figs, "/...`"), "")

  writeLines(unlist(L), file.path(DIR_INF, nombre), useBytes = TRUE)
  cat("escrito:", nombre, "(", length(unlist(L)), "líneas )\n")
}

# ── combinado ──────────────────────────────────────────────────────────────
informe_combinado <- function() {
  L <- ENCABEZADO("Informe de resultados — comparación PILOTO vs PRINCIPAL",
                  "las dos cohortes (17 + 23 = 40 observaciones-participante)",
                  "17 piloto + 23 principal")
  L <- c(L, seccion("1. Advertencia imprescindible"),
         "> El piloto y el principal son **dos muestras distintas**, no dos olas del mismo estudio: 17 y 23",
         "> participantes capturados en momentos diferentes, con instrumentos distintos (`demora` y `n_palabras`",
         "> solo existen en el principal). Cualquier cifra agregada de «n = 40» mezcla cohortes y debe leerse",
         "> con esa reserva. La columna `fuente` es la que permite separarlas.", "",
         flujo_participantes(file.path(RAIZ, "combinado", "datos", "ancho_combinado.rds"), "combinado"))

  L <- c(L, seccion("2. Modelo de comparación"),
         "Se ajustó, para cada variable disponible en ambas cohortes, un modelo",
         "`valor ~ fuente × condición × tiempo + (1 | participante)`.",
         "La pregunta que responde la interacción `fuente:tiempo` es: **¿cambian igual a lo largo del",
         "episodio las dos cohortes?**", "")

  if (is.null(comparac)) {
    L <- c(L, "_No se generó la tabla de interacción `fuente:tiempo`._")
  } else {
    L <- c(L, md(comparac, 4))
    d <- comparac
    pcol <- intersect(c("p_ajustada", "p"), names(d))[1]
    for (i in seq_len(nrow(d))) {
      L <- c(L, paste0("- **", d$variable[i], "**: F = ", num(d$F[i]), " (p", 
                       if (identical(pcol, "p_ajustada")) " ajustada Holm" else "", " = ", p_fmt(d[[pcol]][i]),
                       ") → la trayectoria difiere entre cohortes: ", sig(d[[pcol]][i]), "."))
    }
  }

  # ANOVA por variable (solo los efectos que interesan)
  comp_files <- list.files(file.path(RAIZ, "combinado", "tablas"), pattern = "^comparacion_.*_ANOVA\\.csv$", full.names = TRUE)
  if (length(comp_files) > 0) {
    L <- c(L, h3("Efectos fijos del modelo de comparación, por variable"))
    for (f in sort(comp_files)) {
      v <- sub("^comparacion_(.*)_ANOVA\\.csv$", "\\1", basename(f))
      d <- tryCatch(utils::read.csv(f, fileEncoding = "UTF-8", check.names = FALSE), error = function(e) NULL)
      if (is.null(d) || nrow(d) == 0) next
      L <- c(L, paste0("**", v, "**"), "", md(d, 4))
    }
  } else {
    L <- c(L, "_No se encontraron las tablas ANOVA comparativas._")
  }

  L <- c(L, seccion("3. Replicabilidad: lectura de la interacción"),
         "Criterio explícito: si `fuente:tiempo` **no** es significativa, la trayectoria temporal es",
         "estadísticamente compatible entre cohortes (lo que apoyaría la replicabilidad del patrón);",
         "si es significativa, las cohortes **no** se comportan igual y el patrón del piloto no se replica",
         "en el principal. La significación no mide magnitud: revisar F y R² junto al p-valor.", "")

  L <- c(L, seccion("4. Descriptivos conjuntos (n = 40) — cohortes mezcladas"),
         "Estas tablas se calcularon sobre el conjunto completo; **no** están separadas por cohorte.", "",
         h3("Métricas lingüísticas"), md(d_ling, 3),
         h3("Similitud semántica entre tiempos"), md(d_sem, 4),
         h3("Cambio de proximidad a prototipos (T1→T3)"), md(d_proto, 4),
         h3("Cambio semántico global (distancia euclidiana)"), md(d_dist, 4),
         h3("Diccionarios temáticos (tasas por 1000 palabras)"), md(head(d_hop, 30), 3))

  L <- c(L, seccion("5. Análisis de sensibilidad y robustez"),
         "Modelos alternativos para comprobar si el efecto de tiempo depende de una sola especificación.",
         "",
         "**Tres advertencias para leer la tabla siguiente** (son propiedades de la tabla, no de los datos):",
         "",
         "1. La fila `primario` **no** es del conjunto de 40: es el modelo de `n_palabras` del BLOQUE 10, que",
         "   solo puede usar el principal (**N = 69, 23 participantes**) porque en el piloto esa columna está",
         "   vacía. Las demás filas usan las 120 observaciones de 40 participantes. Compárense solo dentro de",
         "   cada bloque de N.",
         "2. `efecto_tiempo` / `p_tiempo` y `efecto_condicion` / `p_condicion` son el **coeficiente del primer",
         "   contraste** (T2 frente a T1, y la primera condición frente a la de referencia), **no** la prueba",
         "   ómnibus del factor. Las pruebas ómnibus están en `piloto/tablas/resumen_modelos_validos.csv`",
         "   (por cohorte) y en `combinado/tablas/comparacion_*_ANOVA.csv`.",
         "3. La fila `sin_outliers` no existe: el criterio del script (|residuo| > 2.5) marca 115 de 120",
         "   observaciones y el reajuste no se pudo estimar. No hay resultados corregidos por outliers.",
         "",
         "Con esas reservas, el patrón de la tabla es: el efecto de tiempo se mantiene al añadir `demora`",
         "y en el modelo de exposición, pero **no** sobrevive a la transformación logarítmica (ver informe",
         "de discusión).", "",
         md(robustez, 4))

  L <- c(L, seccion("6. Figuras comparativas"),
         figuras_de("combinado", "graficas_es"), figuras_de("combinado", "figures_en"))

  L <- c(L, seccion("7. Lo que este informe NO permite afirmar"),
         "- **No** autoriza a tratar n = 40 como una sola muestra.",
         "- **No** establece causalidad de la condición sobre el cambio: no hay asignación aleatoria",
         "  documentada ni manipulación del orden de los estímulos.",
         "- Las diferencias entre cohortes pueden deberse al instrumento (el principal añade `demora`), al",
         "  momento de captura o a las personas, no al diseño del estímulo.", "")

  writeLines(unlist(L), file.path(DIR_INF, "INFORME_COMBINADO.md"), useBytes = TRUE)
  cat("escrito: INFORME_COMBINADO.md (", length(unlist(L)), "líneas )\n")
}

# ── ejecución ──────────────────────────────────────────────────────────────
informe("INFORME_PILOTO.md", "Informe de resultados — cohorte PILOTO",
        "estudio piloto (17 participantes)", "17 (Texto 6 · Audio 6 · Imagen 5)",
        "piloto", "piloto", file.path(RAIZ, "piloto", "datos", "ancho_piloto.rds"), "piloto")

informe("INFORME_PRINCIPAL.md", "Informe de resultados — cohorte PRINCIPAL",
        "estudio principal (23 participantes)", "23 (Texto 8 · Audio 8 · Imagen 7)",
        "principal", "principal", file.path(RAIZ, "principal", "datos", "ancho_principal.rds"), "principal")

informe_combinado()

cat("\n=== ARTEFACTOS FALTANTES (declarados, no inventados) ===\n")
if (length(faltantes) == 0) cat("ninguno\n") else cat(paste0("- ", unique(faltantes), collapse = "\n"), "\n")
