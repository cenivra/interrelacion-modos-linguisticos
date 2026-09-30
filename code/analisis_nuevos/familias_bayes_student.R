# ============================================================================
#  t de Student corregida: el prior de la primera corrida estaba en la escala
#  del logaritmo y este modelo se ajusta sobre la escala de palabras, de modo
#  que el intercepto quedó fuera de rango y la posterior colapsó a cero.
#  Aquí se ajusta con priors en la escala de palabras y se deja la comparación
#  por LOO frente a lognormal y gamma, que SÍ comparten la misma variable.
# ============================================================================
suppressPackageStartupMessages({ library(brms); library(loo); library(dplyr) })
A <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Analisis agosto v2"
SALIDA <- file.path(A, "familias_bayes", "principal")
dir.create(file.path(SALIDA, "tablas"), recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(SALIDA, "registro_student.txt")
diario <- function(...) { l <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(..., collapse = "")); cat(l, "\n"); cat(l, "\n", file = LOG, append = TRUE) }

ancho <- read.csv(file.path(A, "resultados/tablas/datos_completos_ancho.csv"), stringsAsFactors = FALSE, check.names = FALSE)
dat <- ancho[ancho$fuente == "principal", ]
dat$id_participante <- factor(dat$id_participante)
pal <- function(k) suppressWarnings(as.numeric(dat[[paste0("n_palabras_calculado_t", k)]]))
largo <- data.frame(id = factor(rep(dat$id_participante, 3)), con = factor(rep(dat$condicion, 3)),
                    tie = factor(rep(1:3, each = nrow(dat))), val = c(pal(1), pal(2), pal(3)))
largo <- largo[is.finite(largo$val) & largo$val > 0, ]
diario("observaciones: ", nrow(largo), " de ", length(unique(largo$id)), " participantes")
diario("media de palabras: ", round(mean(largo$val), 1))

t0 <- Sys.time()
m <- brm(val ~ con * tie + (1 | id), data = largo, family = student(),
         prior = c(prior(normal(130, 60), class = Intercept),
                   prior(normal(0, 30), class = b),
                   prior(normal(0, 30), class = sd),
                   prior(exponential(0.02), class = sigma)),
         chains = 4, iter = 2000, warmup = 1000, seed = 20260925, refresh = 0,
         save_pars = save_pars(all = TRUE))
diario("t de Student ajustada en ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")

nd <- expand.grid(con = factor(levels(largo$con), levels = levels(largo$con)), tie = factor(1:3, levels = 1:3))
ep <- posterior_epred(m, newdata = nd, re_formula = NA)
colnames(ep) <- paste(nd$con, nd$tie, sep = "-")
prom <- function(c, t) ep[, paste(c, t, sep = "-")]
crec <- (prom("Texto", 3) + prom("Audio", 3) + prom("Imagen", 3)) / 3 -
        (prom("Texto", 1) + prom("Audio", 1) + prom("Imagen", 1)) / 3
dcon <- (prom("Audio", 1) + prom("Audio", 2) + prom("Audio", 3)) / 3 -
        (prom("Texto", 1) + prom("Texto", 2) + prom("Texto", 3)) / 3

res <- data.frame(familia = "t de Student",
                  crecimiento = mean(crec), ic_crec_bajo = quantile(crec, .025), ic_crec_alto = quantile(crec, .975),
                  p_crec_positivo = mean(crec > 0),
                  audio_menos_texto = mean(dcon), ic_dif_bajo = quantile(dcon, .025), ic_dif_alto = quantile(dcon, .975),
                  p_dif_positiva = mean(dcon > 0))
write.csv(res, file.path(SALIDA, "tablas", "decision_t_student.csv"), row.names = FALSE)
diario("crecimiento ", round(res$crecimiento, 1), " [", round(res$ic_crec_bajo, 1), ", ", round(res$ic_crec_alto, 1),
       "] | Audio-Texto ", round(res$audio_menos_texto, 1), " [", round(res$ic_dif_bajo, 1), ", ", round(res$ic_dif_alto, 1), "]")

l <- loo(m)
saveRDS(l, file.path(SALIDA, "tablas", "loo_t_student.rds"))
diario("LOO propio: elpd = ", round(l$estimates["elpd_loo", "Estimate"], 1),
       " (EE ", round(l$estimates["elpd_loo", "SE"], 1), "), p_loo = ", round(l$estimates["p_loo", "Estimate"], 1))
diario("listo. Para comparar con lognormal y gamma hay que rehacer la comparación juntas (misma variable).")
