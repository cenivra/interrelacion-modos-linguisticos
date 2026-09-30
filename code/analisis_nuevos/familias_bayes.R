# ============================================================================
#  ¿Podemos cambiar de familia? Comparación de verosimilitudes con lo que hay
# ----------------------------------------------------------------------------
#  Ajusta el MISMO modelo (val ~ con * tie + (1|id)) con cuatro familias y
#  compara por LOO: lognormal (la usada), gamma, t de Student sobre el conteo y
#  gaussiana sobre el logaritmo. Responde con los datos, no por preferencia.
#  Uso: Rscript --vanilla familias_bayes.R [cohorte]   (por defecto: principal)
# ============================================================================
suppressPackageStartupMessages({ library(brms); library(loo); library(dplyr) })
COHORTE <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "principal"
CORRIDA <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Analisis agosto v2"
SALIDA  <- file.path(CORRIDA, "familias_bayes", COHORTE)
dir.create(file.path(SALIDA, "tablas"), recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(SALIDA, "registro.txt")
diario <- function(...) { l <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(..., collapse = "")); cat(l, "\n"); cat(l, "\n", file = LOG, append = TRUE) }

ancho <- read.csv(file.path(CORRIDA, "resultados/tablas/datos_completos_ancho.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
dat <- ancho[ancho$fuente == COHORTE, ]
dat$id_participante <- factor(dat$id_participante)
pal <- function(k) suppressWarnings(as.numeric(dat[[paste0("n_palabras_calculado_t", k)]]))
largo <- data.frame(id = factor(rep(dat$id_participante, 3)), con = factor(rep(dat$condicion, 3)),
                    tie = factor(rep(1:3, each = nrow(dat))), val = c(pal(1), pal(2), pal(3)))
largo <- largo[is.finite(largo$val) & largo$val > 0, ]
largo$log_val <- log(largo$val)
diario("cohorte ", COHORTE, ": ", nrow(largo), " observaciones de ", length(unique(largo$id)), " participantes")

priors_de <- function(familia) {
  base <- c(prior(normal(4.8, 1), class = Intercept), prior(normal(0, 0.5), class = b),
            prior(normal(0, 0.5), class = sd))
  if (tolower(familia$family) == "gamma") c(base, prior(exponential(1), class = shape))
  else c(base, prior(exponential(1), class = sigma))
}

ajusta <- function(nombre, familia, formula = val ~ con * tie + (1 | id), datos = largo, pri = NULL) {
  if (is.null(pri)) pri <- priors_de(familia)
  t0 <- Sys.time()
  m <- brm(formula, data = datos, family = familia, prior = pri, chains = 4, iter = 2000,
           warmup = 1000, seed = 20260925, refresh = 0, save_pars = save_pars(all = TRUE))
  diario("  ", nombre, " ajustado en ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")
  m
}

modelos <- list()
modelos$lognormal      <- ajusta("lognormal",      lognormal())
modelos$gamma          <- ajusta("gamma",          Gamma(link = "log"))
modelos$student        <- ajusta("t de Student",   student())
modelos$gaussiana_log  <- ajusta("gaussiana log",  gaussian(), formula = log_val ~ con * tie + (1 | id))

loos <- lapply(modelos, function(m) loo(m))
cmp <- loo_compare(loos)
write.csv(as.data.frame(cmp), file.path(SALIDA, "tablas", "comparacion_familias_LOO.csv"))
writeLines(capture.output(print(cmp)), file.path(SALIDA, "tablas", "comparacion_familias_LOO.txt"))
diario("comparación por LOO (mejor primero):")
for (i in seq_len(nrow(cmp)))
  diario("   ", rownames(cmp)[i], " → ΔELPD = ", round(cmp[i, "elpd_diff"], 1),
         " (EE ", round(cmp[i, "se_diff"], 1), ")")

# ¿cambia la conclusión con la familia? crecimiento y contraste de modos por familia
lineas <- list()
for (nm in names(modelos)) {
  m <- modelos[[nm]]
  if (nm == "gaussiana_log") {
    nd <- expand.grid(con = factor(levels(largo$con), levels = levels(largo$con)),
                      tie = factor(1:3, levels = 1:3))
    ep <- exp(posterior_epred(m, newdata = nd, re_formula = NA))
  } else {
    nd <- expand.grid(con = factor(levels(largo$con), levels = levels(largo$con)),
                      tie = factor(1:3, levels = 1:3))
    ep <- posterior_epred(m, newdata = nd, re_formula = NA)
  }
  colnames(ep) <- paste(nd$con, nd$tie, sep = "-")
  ci <- function(c, t) which(nd$con == c & nd$tie == t)
  prom <- function(c, t) rowMeans(ep[, ci(c, t), drop = FALSE])
  crec <- (prom("Texto", 3) + prom("Audio", 3) + prom("Imagen", 3)) / 3 -
          (prom("Texto", 1) + prom("Audio", 1) + prom("Imagen", 1)) / 3
  dcon <- (prom("Audio", 1) + prom("Audio", 2) + prom("Audio", 3)) / 3 -
          (prom("Texto", 1) + prom("Texto", 2) + prom("Texto", 3)) / 3
  lineas[[nm]] <- data.frame(familia = nm,
    crecimiento = mean(crec), ic_crec_bajo = quantile(crec, .025), ic_crec_alto = quantile(crec, .975),
    p_crec_positivo = mean(crec > 0),
    audio_menos_texto = mean(dcon), ic_dif_bajo = quantile(dcon, .025), ic_dif_alto = quantile(dcon, .975),
    p_dif_positiva = mean(dcon > 0))
}
tab_fam <- do.call(rbind, lineas)
write.csv(tab_fam, file.path(SALIDA, "tablas", "decision_por_familia.csv"), row.names = FALSE)
for (i in seq_len(nrow(tab_fam)))
  diario("  ", tab_fam$familia[i], ": crecimiento ", round(tab_fam$crecimiento[i], 1),
         " [", round(tab_fam$ic_crec_bajo[i], 1), ", ", round(tab_fam$ic_crec_alto[i], 1),
         "] | Audio-Texto ", round(tab_fam$audio_menos_texto[i], 1),
         " [", round(tab_fam$ic_dif_bajo[i], 1), ", ", round(tab_fam$ic_dif_alto[i], 1), "]")

resumen <- c(
  paste0("# ¿Cambiar de familia? Comparación con los datos — cohorte ", COHORTE),
  "",
  paste0("Modelo: `val ~ con * tie + (1|id)` con cuatro verosimilitudes, ", nrow(largo),
         " observaciones de ", length(unique(largo$id)), " participantes. Semilla 20260925, 4 cadenas × 2000."),
  "",
  "## Qué familia describen mejor los datos",
  "",
  paste0("| modelo | ΔELPD | EE |"),
  paste0("| --- | --- | --- |"),
  sapply(seq_len(nrow(cmp)), function(i) paste0("| ", rownames(cmp)[i], " | ", round(cmp[i, "elpd_diff"], 1),
                                                " | ", round(cmp[i, "se_diff"], 1), " |")),
  "",
  "## ¿Cambia la conclusión según la familia?",
  "",
  "| familia | crecimiento T1→T3 | IC 95 % | P(>0) | Audio − Texto | IC 95 % |",
  sapply(seq_len(nrow(tab_fam)), function(i)
    paste0("| ", tab_fam$familia[i], " | ", round(tab_fam$crecimiento[i], 1), " | [",
           round(tab_fam$ic_crec_bajo[i], 1), ", ", round(tab_fam$ic_crec_alto[i], 1), "] | ",
           sprintf("%.3f", tab_fam$p_crec_positivo[i]), " | ", round(tab_fam$audio_menos_texto[i], 1),
           " | [", round(tab_fam$ic_dif_bajo[i], 1), ", ", round(tab_fam$ic_dif_alto[i], 1), "] |")),
  "",
  "Si el crecimiento se mantiene con las cuatro familias y la diferencia entre modos queda no concluyente",
  "en todas, la elección de familia deja de ser una decisión arbitraria: es una decisión sin consecuencias",
  "sobre la conclusión, y eso conviene declararlo así en el manuscrito.",
  "",
  paste0("Fecha: ", format(Sys.time(), "%Y-%m-%d %H:%M"))
)
writeLines(resumen, file.path(SALIDA, "RESUMEN.md"))
diario("RESUMEN.md escrito. listo.")
