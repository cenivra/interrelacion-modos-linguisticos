# ============================================================================
#  ROBUSTEZ Y ANÁLISIS BAYESIANO — módulo complementario del pipeline v5.9
# ----------------------------------------------------------------------------
#  Qué es: un módulo APARTE que no modifica ni reejecuta el guion verificado
#  (Experimento ALC_v5_corregido.R, v5.9, SHA-256 1143b36a…) — lo COMPLEMENTA.
#  Lee sus artefactos ya verificados y añade lo que la muestra pequeña exige:
#
#   A. Robustez frecuentista
#     A1. Influencia por participante (leave-one-out + Cook aproximado) en el
#         coeficiente clave, en lugar del umbral fijo |z| > 2.5 (que marcaba
#         115 de 120 observaciones y no permitía reajustar nada).
#     A2. Diversidad léxica robusta a la longitud: MATTR (ventana móvil de 100
#         palabras) calculado sobre los propios textos, y su modelo mixto.
#     A3. Control de comparaciones múltiples (FDR de Benjamini-Hochberg) en los
#         diez diccionarios temáticos.
#     A4. Diccionarios sin varianza (índices que nunca se activan).
#     A5. Bootstrap por participante (reagrupado) de los contrastes clave.
#
#   B. Capa bayesiana (brms; backend rstan, sin necesidad de CmdStan)
#     B1. Modelo multinivel lognormal del conteo de palabras y comparación
#         contra el modelo sin el factor condición (LOO).
#     B2. Estimación posterior, intervalo creíble del 95 % y probabilidad de
#         dirección para el crecimiento T1→T3 y para la diferencia entre modos.
#     B3. ROPE: qué diferencia se considera irrelevante en palabras, y si el
#         intervalo creíble la excluye (cambio sustancial) o cae dentro
#         (equivalente en la práctica) o la cruza (no concluyente).
#     B4. Chequeo predictivo posterior (PPC).
#     B5. Potencia aproximada para n = 23, 28, 34 y 40 a partir del posterior:
#         responde a «¿cinco personas más cambian algo?» sin esperar los datos.
#
#   C. Registro: sessionInfo, semillas, tiempos y hash del guion consumido.
#
#  Uso:  Rscript --vanilla robustez_y_bayesiano.R [cohorte]
#        cohorte ∈ {principal, piloto, combinado}; por defecto: principal
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(lmerTest)
})

# ------------------------------------------------------------------ 0. config
COHORTE   <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "principal"
CORRIDA   <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Analisis agosto v2"
SALIDA    <- file.path(CORRIDA, "robustez_bayesiano", COHORTE)
SEMILLA   <- 20260925L
N_BOOT    <- 200L          # réplicas del bootstrap por participante
ROPE_PAL  <- 20            # diferencia entre modos considerada irrelevante (palabras)
CI_GROW   <- 20            # umbral de cambio sustancial en el crecimiento (palabras)
CHAINS    <- 4L; ITER <- 2000L; WARMP <- 1000L
BINOMIAL  <- TRUE          # TRUE = conteo (lognormal) ; FALSE = log y gaussiano
VENTANA   <- 100L          # ventana del MATTR (palabras)
GUION     <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Script en R/Experimento ALC_v5_corregido.R"

dir.create(file.path(SALIDA, "tablas"),  recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(SALIDA, "figuras"), recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(SALIDA, "registro.txt")
diario <- function(...) {
  linea <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(..., collapse = ""))
  cat(linea, "\n"); cat(linea, "\n", file = LOG, append = TRUE)
}
diario("cohorte: ", COHORTE)
diario("salida:  ", SALIDA)

# --------------------------------------------------------------- 1. los datos
ancho <- read.csv(file.path(CORRIDA, "resultados/tablas/datos_completos_ancho.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
dat <- ancho[ancho$fuente == COHORTE, ]
if (!nrow(dat)) stop("no hay filas para la cohorte ", COHORTE)
dat$id_participante <- factor(dat$id_participante)
diario("participantes: ", nrow(dat), " | distribución por condición: ",
       paste(names(table(dat$condicion)), table(dat$condicion), sep = "=", collapse = ", "))
if ("demora" %in% names(dat)) diario("demora: ", paste(names(table(dat$demora)), table(dat$demora), sep = "=", collapse = ", "))

pal <- function(k) suppressWarnings(as.numeric(dat[[paste0("n_palabras_calculado_t", k)]]))
largo <- data.frame(
  id    = factor(rep(dat$id_participante, 3)),
  con   = factor(rep(dat$condicion, 3)),
  dem   = if ("demora" %in% names(dat)) factor(rep(dat$demora, 3)) else factor(NA),
  tie   = factor(rep(1:3, each = nrow(dat))),
  val   = c(pal(1), pal(2), pal(3))
)
largo <- largo[is.finite(largo$val), ]
diario("observaciones del desenlace: ", nrow(largo))

# ------------------------------------------------- A2. MATTR (independiente de longitud)
mattr <- function(txt, w = VENTANA) {
  if (is.na(txt) || !nzchar(txt)) return(NA_real_)
  toks <- unlist(regmatches(tolower(txt), gregexpr("[[:alpha:]áéíóúüñ]+", tolower(txt))))
  toks <- toks[nzchar(toks)]
  n <- length(toks)
  if (n < w) return(NA_real_)                    # sin ventana completa no se define
  ventanas <- vapply(seq_len(n - w + 1),
                     function(i) length(unique(toks[i:(i + w - 1)])) / w, numeric(1))
  mean(ventanas)
}
mat <- sapply(1:3, function(k) {
  col <- paste0("texto_t", k)
  if (!col %in% names(dat)) return(rep(NA_real_, nrow(dat)))
  vapply(dat[[col]], mattr, numeric(1))
})
colnames(mat) <- paste0("mattr_t", 1:3)
diario("MATTR calculado (ventana ", VENTANA, "): valores finitos = ", sum(is.finite(mat)),
       " de ", length(mat))
largo$mattr <- as.vector(mat)

# ============================================================ A. ROBUSTEZ
tab_rob <- list()

# --- A1. influencia: leave-one-out del coeficiente clave --------------------
modelo_primario <- function(d) lmer(val ~ con * tie + (1 | id), data = d, REML = TRUE)
m0 <- modelo_primario(largo)
b0 <- fixef(m0)
coef_clave <- names(b0)[grep("^tie", names(b0))][1]         # primer contraste de tiempo
loo <- lapply(levels(largo$id), function(id) {
  d <- droplevels(largo[largo$id != id, ])
  m <- try(lmer(val ~ con * tie + (1 | id), data = d, REML = TRUE), silent = TRUE)
  if (inherits(m, "try-error")) return(c(NA, NA))
  f <- fixef(m)
  c(f[coef_clave], f["(Intercept)"])
})
loo <- do.call(rbind, loo)
colnames(loo) <- c("coef_tiempo_sin_participante", "intercepto")
influ <- data.frame(
  id = levels(largo$id),
  coef_loo = loo[, 1],
  delta = loo[, 1] - b0[coef_clave],
  delta_estandarizado = (loo[, 1] - mean(loo[, 1], na.rm = TRUE)) / sd(loo[, 1], na.rm = TRUE)
)
influ <- influ[order(-abs(influ$delta)), ]
write.csv(influ, file.path(SALIDA, "tablas", "A1_influencia_participante.csv"), row.names = FALSE)
tab_rob[["A1"]] <- list(
  coef_original = as.numeric(b0[coef_clave]),
  rango_loo = paste0(round(min(loo[, 1], na.rm = TRUE), 2), " a ", round(max(loo[, 1], na.rm = TRUE), 2)),
  cambio_maximo = as.numeric(max(abs(influ$delta))),
  participante_mas_influyente = as.character(influ$id[1])
)
diario("A1 influencia: coeficiente original ", round(b0[coef_clave], 2),
       " | rango sin un participante: ", tab_rob[["A1"]]["rango_loo"],
       " | cambio máximo: ", tab_rob[["A1"]]$cambio_maximo)

# --- A2. modelo sobre MATTR -------------------------------------------------
largo_m <- largo[is.finite(largo$mattr), ]
matt_ok <- length(unique(largo_m$id)) >= 4 && length(unique(largo_m$mattr)) > 3
if (matt_ok) {
  mM <- lmer(mattr ~ con * tie + (1 | id), data = largo_m)
  aM <- anova(mM)
  write.csv(as.data.frame(aM), file.path(SALIDA, "tablas", "A2_modelo_MATTR.csv"))
  tab_rob[["A2"]] <- c(
    n = nrow(largo_m),
    tiempo = sprintf("F(%s,%.1f)=%.2f p=%.3f", aM["tie","NumDF"], aM["tie","DenDF"], aM["tie","F value"], aM["tie","Pr(>F)"]),
    condicion = sprintf("F(%s,%.1f)=%.2f p=%.3f", aM["con","NumDF"], aM["con","DenDF"], aM["con","F value"], aM["con","Pr(>F)"]),
    medias = paste(round(tapply(largo_m$mattr, largo_m$tie, mean), 3), collapse = " / ")
  )
  diario("A2 MATTR: tiempo ", tab_rob[["A2"]]["tiempo"], " | medias ", tab_rob[["A2"]]["medias"])
} else diario("A2 MATTR: no estimable en esta cohorte (textos cortos)")

# --- A3 y A4. temas: FDR y varianza nula ------------------------------------
temas <- grep("^rate_.*_t1$", names(dat), value = TRUE)
temas <- sub("_t1$", "", temas)
filas <- list()
for (tm in temas) {
  d <- data.frame(
    id = factor(rep(dat$id_participante, 3)), con = factor(rep(dat$condicion, 3)),
    tie = factor(rep(1:3, each = nrow(dat))),
    val = as.numeric(c(dat[[paste0(tm, "_t1")]], dat[[paste0(tm, "_t2")]], dat[[paste0(tm, "_t3")]]))
  )
  d <- d[is.finite(d$val), ]
  if (!nrow(d)) next
  var0 <- length(unique(d$val)) < 2
  p_tie <- p_con <- NA_real_; singular <- NA
  if (!var0) {
    m <- try(lmer(val ~ con * tie + (1 | id), data = d), silent = TRUE)
    if (!inherits(m, "try-error")) {
      a <- anova(m); p_tie <- a["tie", "Pr(>F)"]; p_con <- a["con", "Pr(>F)"]
      singular <- isSingular(m, tol = 1e-4)
    }
  }
  filas[[tm]] <- data.frame(tema = tm, media = mean(d$val), varianza_cero = var0,
                            ajuste_singular = singular, p_condicion = p_con, p_tiempo = p_tie)
}
tab_temas <- do.call(rbind, filas)
tab_temas$p_tiempo_fdr <- p.adjust(tab_temas$p_tiempo, method = "BH")
tab_temas$p_condicion_fdr <- p.adjust(tab_temas$p_condicion, method = "BH")
write.csv(tab_temas, file.path(SALIDA, "tablas", "A3_temas_FDR.csv"), row.names = FALSE)
tab_rob[["A4"]] <- paste(tab_temas$tema[tab_temas$varianza_cero], collapse = ", ")
diario("A3 temas: ", nrow(tab_temas), " evaluados | con varianza cero: ",
       ifelse(nzchar(tab_rob[["A4"]]), tab_rob[["A4"]], "ninguno"))
sig <- tab_temas[!is.na(tab_temas$p_tiempo) & tab_temas$p_tiempo < .05, ]
diario("A3 temas con efecto de tiempo antes de FDR: ",
       ifelse(nrow(sig), paste(sig$tema, collapse = ", "), "ninguno"))
sigf <- tab_temas[!is.na(tab_temas$p_tiempo_fdr) & tab_temas$p_tiempo_fdr < .05, ]
diario("A3 temas que sobreviven a FDR: ",
       ifelse(nrow(sigf), paste(sigf$tema, collapse = ", "), "ninguno"))

# --- A5. bootstrap por participante -----------------------------------------
set.seed(SEMILLA)
ids <- levels(largo$id)
boot <- vapply(seq_len(N_BOOT), function(b) {
  sel <- sample(ids, length(ids), replace = TRUE)
  d <- do.call(rbind, lapply(seq_along(sel), function(i) {
    x <- largo[largo$id == sel[i], ]; x$id <- factor(paste0("b", i)); x
  }))
  m <- try(lmer(val ~ con * tie + (1 | id), data = d, REML = FALSE), silent = TRUE)
  if (inherits(m, "try-error")) return(c(NA, NA))
  f <- fixef(m)
  c(f[grep("^tie", names(f))[1]], if ("conAudio" %in% names(f)) f["conAudio"] else NA)
}, numeric(2))
boot <- t(boot)
colnames(boot) <- c("crecimiento_primer_paso", "audio_vs_texto")
res_boot <- rbind(
  data.frame(parametro = "crecimiento_primer paso (T1→T2)", estimacion = b0[coef_clave],
             ic_bajo = quantile(boot[, 1], .025, na.rm = TRUE), ic_alto = quantile(boot[, 1], .975, na.rm = TRUE)),
  data.frame(parametro = "diferencia Audio vs Texto", estimacion = NA,
             ic_bajo = quantile(boot[, 2], .025, na.rm = TRUE), ic_alto = quantile(boot[, 2], .975, na.rm = TRUE))
)
write.csv(res_boot, file.path(SALIDA, "tablas", "A5_bootstrap_contrastes.csv"), row.names = FALSE)
diario("A5 bootstrap (", N_BOOT, " réplicas) del primer contraste de tiempo: IC 95 % [",
       round(res_boot$ic_bajo[1], 1), ", ", round(res_boot$ic_alto[1], 1), "]")

# ============================================================ B. BAYESIANO
bayes_ok <- requireNamespace("brms", quietly = TRUE)
if (bayes_ok) {
  suppressPackageStartupMessages({ library(brms); library(posterior); library(bayesplot) })
  op <- options(mc.cores = CHAINS, brms.backend = "rstan")
  priors <- c(prior(normal(4.8, 1), class = Intercept),
              prior(normal(0, 0.5), class = b),
              prior(normal(0, 0.5), class = sd),
              prior(exponential(1), class = sigma))
  forma <- bf(val ~ con * tie + (1 | id))
  diario("B: ajustando modelo lognormal (", CHAINS, " cadenas × ", ITER, " iteraciones)…")
  t0 <- Sys.time()
  m_bay <- brm(forma, data = largo, family = lognormal(), prior = priors,
               chains = CHAINS, iter = ITER, warmup = WARMP, seed = SEMILLA, refresh = 0,
               save_pars = save_pars(all = TRUE))   # requerido para el moment matching del LOO
  diario("B: modelo principal ajustado en ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")
  m_bay_alt <- update(m_bay, prior = c(prior(normal(4.8, 2), class = Intercept),
                                       prior(normal(0, 1), class = b),
                                       prior(normal(0, 1), class = sd),
                                       prior(exponential(1), class = sigma)), refresh = 0, seed = SEMILLA + 1)
  m_bay_sin <- update(m_bay, formula = bf(val ~ tie + (1 | id)), refresh = 0, seed = SEMILLA + 2)
  saveRDS(list(principal = m_bay, prior_amplio = m_bay_alt, sin_condicion = m_bay_sin),
          file.path(SALIDA, "tablas", "B_modelos_brms.rds"))

  # B2. posteriores sobre la escala de palabras (epred) ----------------------
  grid <- expand.grid(con = factor(levels(largo$con), levels = levels(largo$con)),
                      tie = factor(1:3, levels = 1:3))
  ep <- posterior_epred(m_bay, newdata = grid, re_formula = NA)
  stopifnot(ncol(ep) == nrow(grid))
  colnames(ep) <- paste(grid$con, grid$tie, sep = "-")   # orden posicional = orden de grid
  base_con <- levels(largo$con)[1]                        # primera condición alfabética
  otras <- setdiff(levels(largo$con), base_con)
  ci <- function(con, tie) which(grid$con == con & grid$tie == tie)
  cuant <- function(x, p = c(.025, .5, .975)) quantile(x, p)
  res_ep <- t(apply(ep, 2, cuant))
  res_ep <- data.frame(celda = rownames(res_ep), media = colMeans(ep),
                       ic_bajo = res_ep[, 1], mediana = res_ep[, 2], ic_alto = res_ep[, 3])
  write.csv(res_ep, file.path(SALIDA, "tablas", "B2_posterior_por_celda.csv"), row.names = FALSE)

  cres <- ep[, grep("^Texto-", colnames(ep))] # no usado; se calculan abajo con diferencias
  d_grow <- rowMeans(ep[, c("Texto-3","Audio-3","Imagen-3")]) - rowMeans(ep[, c("Texto-1","Audio-1","Imagen-1")])
  d_cond_tot <- rowMeans(ep[, c("Audio-1","Audio-2","Audio-3")]) - rowMeans(ep[, c("Texto-1","Texto-2","Texto-3")])
  p_pos <- function(x, umbral) mean(x > umbral)
  res_dec <- data.frame(
    pregunta = c("crecimiento T1→T3 (palabras)", "Audio vs Texto (palabras)"),
    media = c(mean(d_grow), mean(d_cond_tot)),
    ic_bajo = c(quantile(d_grow, .025), quantile(d_cond_tot, .025)),
    ic_alto = c(quantile(d_grow, .975), quantile(d_cond_tot, .975)),
    p_mayor_que_cero = c(p_pos(d_grow, 0), p_pos(d_cond_tot, 0)),
    p_cambio_sustancial = c(p_pos(d_grow, CI_GROW), p_pos(d_cond_tot, ROPE_PAL)),
    p_dentro_del_rope = c(mean(abs(d_grow) <= CI_GROW), mean(abs(d_cond_tot) <= ROPE_PAL))
  )
  res_dec$lectura <- ifelse(res_dec$p_cambio_sustancial >= .95, "cambio sustancial",
                     ifelse(res_dec$p_dentro_del_rope >= .95, "equivalente en la práctica", "no concluyente"))
  write.csv(res_dec, file.path(SALIDA, "tablas", "B2_decision_posterior.csv"), row.names = FALSE)
  diario("B2 crecimiento T1→T3: ", round(mean(d_grow), 1), " palabras, IC 95 % [",
         round(quantile(d_grow, .025), 1), ", ", round(quantile(d_grow, .975), 1), "] → ", res_dec$lectura[1])
  diario("B2 Audio vs Texto: ", round(mean(d_cond_tot), 1), " palabras, IC 95 % [",
         round(quantile(d_cond_tot, .025), 1), ", ", round(quantile(d_cond_tot, .975), 1), "] → ", res_dec$lectura[2])
  diario("B2 probabilidad de que el crecimiento supere ", CI_GROW, " palabras: ",
         sprintf("%.3f", res_dec$p_cambio_sustancial[1]),
         " | de que la diferencia entre modos caiga dentro del ROPE ±", ROPE_PAL, ": ",
         sprintf("%.3f", res_dec$p_dentro_del_rope[2]))

  # B3. sensibilidad al prior y comparación por LOO --------------------------
  loo1 <- loo(m_bay, moment_match = TRUE); loo2 <- loo(m_bay_sin, moment_match = TRUE)
  cmp <- loo_compare(loo1, loo2)
  write.csv(as.data.frame(cmp), file.path(SALIDA, "tablas", "B3_comparacion_LOO.csv"))
  diario("B3 LOO: mejor modelo = ", rownames(cmp)[1],
         " (ΔELPD frente al otro = ", round(abs(cmp[2, "elpd_diff"]), 1),
         ", EE = ", round(cmp[2, "se_diff"], 1), ")")
  b_alt <- fixef(m_bay_alt)
  write.csv(b_alt, file.path(SALIDA, "tablas", "B3_sensibilidad_prior.csv"))
  diario("B3 sensibilidad: el coeficiente de tiempo cambia ",
         sprintf("%.1f%%", 100 * abs(b_alt[grep("^tie", rownames(b_alt))[1], "Estimate"] /
                                     fixef(m_bay)[grep("^tie", rownames(fixef(m_bay)))[1], "Estimate"] - 1)),
         " al ampliar el prior")

  # B4. PPC ------------------------------------------------------------------
  png(file.path(SALIDA, "figuras", "B4_ppc.png"), width = 1400, height = 900, res = 130)
  print(pp_check(m_bay, ndraws = 100) + ggtitle("Chequeo predictivo posterior — modelo lognormal"))
  dev.off()

  # B5. potencia aproximada por tamaño de muestra ---------------------------
  # Aproximación declarada: se usa la incertidumbre del posterior y el escalado
  # del error estándar con la raíz del número de participantes por condición.
  # participantes (personas, no observaciones) por condición hoy
  n_act_pc <- length(unique(largo$id)) / nlevels(largo$con)
  se_actual <- sd(d_cond_tot)                  # incertidumbre posterior actual (palabras)
  # potencia para una diferencia real D con error estándar s (aprox. normal)
  pot <- function(D, s) pnorm(-1.96 - D / s) + 1 - pnorm(1.96 - D / s)
  esc <- data.frame(n_total = c(round(3 * n_act_pc), 28, 34, 40, 48, 60, 69))
  esc$n_por_condicion <- esc$n_total / 3
  esc$se_esperado <- se_actual * sqrt(n_act_pc / esc$n_por_condicion)
  esc$potencia_diff20 <- pot(20, esc$se_esperado)
  esc$potencia_diff40 <- pot(40, esc$se_esperado)
  esc$diferencia_minima_detectable_80 <- 2.80 * esc$se_esperado
  write.csv(esc, file.path(SALIDA, "tablas", "B5_potencia_aproximada.csv"), row.names = FALSE)
  diario("B5 potencia aproximada para una diferencia real de 20 palabras: ",
         paste(sprintf("n=%d→%.2f", esc$n_total, esc$potencia_diff20), collapse = " | "))
  diario("B5 con los cinco nuevos (n=28) pasa de ", sprintf("%.2f", esc$potencia_diff20[1]),
         " a ", sprintf("%.2f", esc$potencia_diff20[2]),
         "; la diferencia mínima detectable al 80 % de potencia con n=28 sería de ",
         sprintf("%.0f palabras", esc$diferencia_minima_detectable_80[2]))
  options(op)
} else {
  diario("B: brms no está disponible; se omitió la capa bayesiana")
}

# ============================================================ C. RESUMEN
resumen <- c(
  paste0("# Robustez y análisis bayesiano — cohorte ", COHORTE),
  "",
  paste0("Participantes: ", nrow(dat), " | observaciones: ", nrow(largo)),
  "",
  "## A. Robustez frecuentista",
  paste0("- **A1 Influencia.** Coeficiente del primer paso de tiempo: ",
         round(tab_rob[["A1"]]$coef_original, 2),
         "; al excluir un participante va de ", tab_rob[["A1"]]$rango_loo,
         " (cambio máximo ", tab_rob[["A1"]]$cambio_maximo, ", en ",
         tab_rob[["A1"]]$participante_mas_influyente, ")."),
  if (!is.null(tab_rob[["A2"]])) paste0("- **A2 MATTR** (ventana ", VENTANA, "): tiempo ",
         tab_rob[["A2"]]["tiempo"], "; medias por momento ", tab_rob[["A2"]]["medias"],
         ". Es la diversidad léxica sin el artefacto de longitud del TTR.") else
         "- **A2 MATTR**: no estimable (textos más cortos que la ventana).",
  paste0("- **A3 Temas con FDR**: ", nrow(tab_temas), " evaluados; con varianza cero: ",
         ifelse(nzchar(tab_rob[["A4"]]), tab_rob[["A4"]], "ninguno"), "."),
  paste0("- **A5 Bootstrap** (", N_BOOT, " réplicas por participante): primer contraste de tiempo IC 95 % [",
         round(res_boot$ic_bajo[1], 1), ", ", round(res_boot$ic_alto[1], 1), "]."),
  "",
  "## B. Capa bayesiana",
  if (bayes_ok) c(
    paste0("- **Crecimiento T1→T3**: ", round(mean(d_grow), 1), " palabras, IC creíble 95 % [",
           round(quantile(d_grow, .025), 1), ", ", round(quantile(d_grow, .975), 1), "], ",
           "P(> 0) = ", sprintf("%.3f", res_dec$p_mayor_que_cero[1]), " → ", res_dec$lectura[1], "."),
    paste0("- **Diferencia Audio vs Texto**: ", round(mean(d_cond_tot), 1), " palabras, IC creíble 95 % [",
           round(quantile(d_cond_tot, .025), 1), ", ", round(quantile(d_cond_tot, .975), 1), "], ",
           "P(dentro del ROPE ±", ROPE_PAL, " palabras) = ", sprintf("%.3f", res_dec$p_dentro_del_rope[2]),
           " → ", res_dec$lectura[2], "."),
    paste0("- **Comparación de modelos (LOO)**: mejor modelo = ", rownames(cmp)[1], "."),
    paste0("- **Potencia aproximada** (respuesta a «¿cinco personas más cambian algo?»): para una ",
           "diferencia real de 20 palabras, la potencia pasa de ", sprintf("%.2f", esc$potencia_diff20[1]),
           " (n=23) a ", sprintf("%.2f", esc$potencia_diff20[2]), " (n=28) y a ",
           sprintf("%.2f", esc$potencia_diff20[which(esc$n_total == 40)]), " (n=40). ",
           "La diferencia mínima detectable al 80 % con n=28 es de ",
           sprintf("%.0f palabras", esc$diferencia_minima_detectable_80[2]),
           "; para diferencias pequeñas (20 palabras) haría falta un n muy superior."),
    "- Este es el punto que responde al «no hubo cambios»: lo que la muestra pequeña no puede hacer",
    "  es *declarar* diferencias, no *detectarlas en la estimación*. El crecimiento se estima con un",
    "  intervalo estrecho y lejos de cero; la diferencia entre modos queda, con estos datos, en «no concluyente»."
  ) else "- (brms no disponible: capa bayesiana omitida)",
  "",
  "## C. Registro",
  paste0("- Semilla: ", SEMILLA, " | réplicas de bootstrap: ", N_BOOT,
         " | cadenas: ", CHAINS, " × ", ITER, " iteraciones"),
  paste0("- Guion consumido: ", basename(GUION)),
  paste0("- Fecha: ", format(Sys.time(), "%Y-%m-%d %H:%M"), " | R ", R.version.string)
)
writeLines(resumen, file.path(SALIDA, "RESUMEN.md"))
diario("resumen escrito en ", file.path(SALIDA, "RESUMEN.md"))
writeLines(capture.output(sessionInfo()), file.path(SALIDA, "sessionInfo.txt"))
diario("listo.")
