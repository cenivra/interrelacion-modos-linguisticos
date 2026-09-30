# ============================================================================
#  Figuras de los resultados nuevos — corrida principal (23 participantes)
# ----------------------------------------------------------------------------
#  Genera las gráficas que acompañan a los resultados nuevos:
#    F1 influencia por participante        F5 potencia y diferencia detectable
#    F2 MATTR frente a TTR                 F6 elaboración entre textos
#    F3 diccionarios con FDR               F7 diccionarios de modo
#    F4 posteriores bayesianos (ROPE)
#  y un panel compuesto (2 x 3) para la diapositiva «Resultados».
#  Salida: <corrida>/figuras_nuevas/*.png
# ============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(patchwork); library(brms); library(posterior)
})
A <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Analisis agosto v2"
SAL <- file.path(A, "figuras_nuevas")
dir.create(SAL, recursive = TRUE, showWarnings = FALSE)
T_ROB <- file.path(A, "robustez_bayesiano/principal/tablas")
T_NUE <- file.path(A, "familias_nuevas/principal/tablas")
T_EMB <- file.path(A, "sensibilidad_embeddings2/principal/tablas")
tema <- theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12),
        panel.grid.minor = element_blank(),
        plot.caption = element_text(size = 8, colour = "grey40"))
gris <- "grey35"; azul <- "#2b6cb0"; rojo <- "#c53030"; verde <- "#2f855a"

ancho <- read.csv(file.path(A, "resultados/tablas/datos_completos_ancho.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
dat <- ancho[ancho$fuente == "principal", ]

# ---------------------------------------------------------------- F1 influencia
a1 <- read.csv(file.path(T_ROB, "A1_influencia_participante.csv"), stringsAsFactors = FALSE)
a1$id_corto <- sub("principal_", "", a1$id)
a1 <- a1[order(a1$coef_loo), ]
a1$id_corto <- factor(a1$id_corto, levels = a1$id_corto)
p1 <- ggplot(a1, aes(x = id_corto, y = coef_loo)) +
  geom_hline(yintercept = 51, linetype = "dashed", colour = gris) +
  geom_point(colour = azul, size = 2.4) +
  annotate("segment", y = 43.14, yend = 57.86, x = 0.6, xend = nrow(a1) + 0.4, colour = rojo, linewidth = 0.7, alpha = .55) +
  labs(title = "Ninguna persona sostiene el efecto", subtitle = "Coeficiente de crecimiento al excluir a cada participante (línea roja: rango observado)",
       x = "participante excluido", y = "palabras ganadas T1→T3", caption = "robustez_y_bayesiano.R — A1") +
  tema
ggsave(file.path(SAL, "F1_influencia.png"), p1, width = 7, height = 4, dpi = 200)

# ------------------------------------------------------------ F2 MATTR vs TTR
tokeniza <- function(t) {
  if (is.na(t) || !nzchar(t)) return(character(0))
  unlist(strsplit(gsub("[^[:alpha:]áéíóúüñ ]+", " ", tolower(t)), "\\s+"))
}
mattr <- function(tk, v = 100) {
  tk <- tk[nzchar(tk)]
  if (length(tk) < v) return(NA_real_)
  n <- length(tk); v <- min(v, n)
  tt <- vapply(seq_len(n - v + 1), function(i) length(unique(tk[i:(i + v - 1)])) / v, numeric(1))
  mean(tt)
}
filas <- list()
for (k in 1:3) {
  tk <- lapply(dat[[paste0("texto_t", k)]], tokeniza)
  filas[[k]] <- data.frame(momento = factor(k, levels = 1:3),
                           mattr = vapply(tk, mattr, numeric(1)),
                           ttr = as.numeric(dat[[paste0("ttr_t", k)]]),
                           id = dat$id_participante)
}
tt <- bind_rows(filas)
res <- tt %>% group_by(momento) %>%
  summarise(mattr = mean(mattr, na.rm = TRUE), ttr = mean(ttr, na.rm = TRUE), .groups = "drop")
esc <- res %>% pivot_longer(c(mattr, ttr), names_to = "indice", values_to = "valor")
p2 <- ggplot(esc, aes(x = momento, y = valor, colour = indice, group = indice)) +
  geom_line(linewidth = 1) + geom_point(size = 3) +
  scale_colour_manual(values = c(mattr = verde, ttr = rojo), labels = c("MATTR (robusta)", "TTR (sensible a la longitud)")) +
  labs(title = "La diversidad léxica no baja: el TTR medía la longitud", x = "momento de escritura", y = "índice",
       colour = NULL, caption = "MATTR en ventanas de 100 palabras; robustez_y_bayesiano.R — A2") +
  tema + theme(legend.position = "bottom")
ggsave(file.path(SAL, "F2_mattr_ttr.png"), p2, width = 7, height = 4, dpi = 200)

# ------------------------------------------------------------------ F3 FDR
a3 <- read.csv(file.path(T_ROB, "A3_temas_FDR.csv"), stringsAsFactors = FALSE)
a3$tema <- sub("rate_", "", a3$tema)
a3l <- a3 %>% select(tema, p_tiempo, p_tiempo_fdr) %>%
  pivot_longer(c(p_tiempo, p_tiempo_fdr), names_to = "momento", values_to = "p")
a3l$momento <- factor(a3l$momento, levels = c("p_tiempo", "p_tiempo_fdr"),
                      labels = c("p original", "p con FDR"))
a3l$tema <- factor(a3l$tema, levels = a3$tema[order(a3$p_tiempo)])
p3 <- ggplot(a3l, aes(x = p, y = tema, colour = momento)) +
  geom_vline(xintercept = .05, linetype = "dotted", colour = gris) +
  geom_point(size = 3) +
  scale_colour_manual(values = c("p original" = gris, "p con FDR" = azul)) +
  labs(title = "Diez diccionarios, una sola señal", subtitle = "Corrección por comparaciones múltiples (FDR)",
       x = "valor p", y = NULL, colour = NULL, caption = "robustez_y_bayesiano.R — A3") +
  tema + theme(legend.position = "bottom")
ggsave(file.path(SAL, "F3_fdr.png"), p3, width = 7, height = 4, dpi = 200)

# --------------------------------------------------- F4 posteriores bayesianos
mods <- readRDS(file.path(T_ROB, "B_modelos_brms.rds"))
cat("  objetos en el .rds:", paste(names(mods), collapse = ", "), "\n")
m <- Filter(function(o) inherits(o, "brmsfit"), mods)[[1]]
cat("  modelo usado:", names(Filter(function(o) inherits(o, "brmsfit"), mods))[1], "| fórmula:", deparse(formula(m)), "\n")
largo <- data.frame(id = factor(rep(dat$id_participante, 3)), con = factor(rep(dat$condicion, 3)),
                    tie = factor(rep(1:3, each = nrow(dat))),
                    val = c(dat$n_palabras_calculado_t1, dat$n_palabras_calculado_t2, dat$n_palabras_calculado_t3))
largo <- largo[is.finite(largo$val) & largo$val > 0, ]
nd <- expand.grid(con = factor(levels(largo$con), levels = levels(largo$con)), tie = factor(1:3, levels = 1:3))
ep <- posterior_epred(m, newdata = nd, re_formula = NA)
colnames(ep) <- paste(nd$con, nd$tie, sep = "-")
prom <- function(c, t) ep[, paste(c, t, sep = "-")]
crec <- (prom("Texto", 3) + prom("Audio", 3) + prom("Imagen", 3)) / 3 -
        (prom("Texto", 1) + prom("Audio", 1) + prom("Imagen", 1)) / 3
dcon <- (prom("Audio", 1) + prom("Audio", 2) + prom("Audio", 3)) / 3 -
        (prom("Texto", 1) + prom("Texto", 2) + prom("Texto", 3)) / 3
d4 <- bind_rows(data.frame(v = crec, tipo = "Crecimiento T1→T3"),
                data.frame(v = dcon, tipo = "Audio − Texto"))
d4$tipo <- factor(d4$tipo, levels = c("Crecimiento T1→T3", "Audio − Texto"))
p4 <- ggplot(d4, aes(x = v, fill = tipo)) +
  geom_vline(xintercept = 0, colour = gris) +
  geom_vline(data = data.frame(tipo = factor("Audio − Texto", levels = levels(d4$tipo)), x = c(-20, 20)),
             aes(xintercept = x), linetype = "dashed", colour = rojo, inherit.aes = FALSE) +
  geom_density(alpha = .55, colour = NA, adjust = 1.2) +
  facet_wrap(~tipo, scales = "free") +
  scale_fill_manual(values = c(verde, azul), guide = "none") +
  labs(title = "Lo que responde la capa bayesiana", subtitle = "Distribución posterior (rojo punteado: equivalencia práctica ±20 palabras)",
       x = "palabras", y = "densidad", caption = "robustez_y_bayesiano.R — B2") +
  tema
ggsave(file.path(SAL, "F4_posteriores.png"), p4, width = 8, height = 4, dpi = 200)

# ---------------------------------------------------------------- F5 potencia
b5 <- read.csv(file.path(T_ROB, "B5_potencia_aproximada.csv"), stringsAsFactors = FALSE)
b5l <- b5 %>% select(n_total, potencia_diff20, potencia_diff40) %>%
  pivot_longer(-n_total, names_to = "efecto", values_to = "potencia")
b5l$efecto <- factor(b5l$efecto, levels = c("potencia_diff20", "potencia_diff40"),
                     labels = c("diferencia real de 20 palabras", "diferencia real de 40 palabras"))
p5 <- ggplot(b5l, aes(x = n_total, y = potencia, colour = efecto, group = efecto)) +
  geom_line(linewidth = 1) + geom_point(size = 2.2) +
  geom_vline(xintercept = 28, linetype = "dashed", colour = gris) +
  annotate("text", x = 28, y = .7, label = "con los 5\nparticipantes nuevos", size = 3, colour = gris, hjust = -.05) +
  scale_colour_manual(values = c(azul, verde), guide = "none") +
  facet_wrap(~efecto, nrow = 1) +
  labs(title = "¿Cinco participantes más cambian algo?", subtitle = "Probabilidad de detectar la diferencia, según el tamaño de muestra",
       x = "participantes totales", y = "potencia", caption = "robustez_y_bayesiano.R — B5 (aproximación analítica)") +
  tema
ggsave(file.path(SAL, "F5_potencia.png"), p5, width = 8, height = 4, dpi = 200)

# ------------------------------------------------------------- F6 elaboración
el <- read.csv(file.path(T_NUE, "3_elaboracion_entre_textos.csv"), stringsAsFactors = FALSE)
sel <- el %>% filter(medida %in% c("reaparece en T2 (de T1)", "reaparece en T3 (de T2)",
                                   "contenido nuevo en T2", "contenido nuevo en T3"))
sel$tipo <- ifelse(grepl("reaparece", sel$medida), "vuelve a aparecer", "contenido nuevo")
sel$paso <- ifelse(grepl("T2", sel$medida), "T1 → T2", "T2 → T3")
p6 <- ggplot(sel, aes(x = paso, y = media, fill = tipo)) +
  geom_col(position = position_dodge(.7), width = .62, alpha = .9) +
  geom_text(aes(label = sprintf("%.2f", media)), position = position_dodge(.7), vjust = -0.4, size = 3.4) +
  scale_fill_manual(values = c("vuelve a aparecer" = verde, "contenido nuevo" = azul), guide = "none") +
  facet_wrap(~tipo) +
  labs(title = "Elaboración entre textos (Referente AB)", subtitle = "Proporción del vocabulario de contenido",
       x = NULL, y = "proporción", caption = "familias_nuevas.R — 3") +
  tema
ggsave(file.path(SAL, "F6_elaboracion.png"), p6, width = 7, height = 4, dpi = 200)

# ------------------------------------------------------------------ F7 modos
mo <- read.csv(file.path(T_NUE, "1_diccionarios_de_modo.csv"), stringsAsFactors = FALSE)
mol <- mo %>% select(medida, media_T1, media_T2, media_T3) %>%
  pivot_longer(-medida, names_to = "momento", values_to = "tasa")
mol$momento <- factor(sub("media_", "", mol$momento), levels = c("T1", "T2", "T3"))
mol$medida <- factor(mol$medida, levels = c("contacto_observar", "contacto_escuchar", "contacto_leer", "imaginacion"),
                     labels = c("observar", "escuchar", "leer", "imaginar"))
p7 <- ggplot(mol, aes(x = momento, y = tasa, colour = medida, group = medida)) +
  geom_line(linewidth = 1) + geom_point(size = 3) +
  scale_colour_manual(values = c(azul, verde, "#b7791f", rojo)) +
  labs(title = "Los modos lingüísticos en el texto", subtitle = "Menciones por mil palabras (ninguna cambia de T1 a T3)",
       x = "momento", y = "por mil palabras", colour = NULL, caption = "familias_nuevas.R — 1") +
  tema + theme(legend.position = "bottom")
ggsave(file.path(SAL, "F7_modos.png"), p7, width = 7, height = 4, dpi = 200)

# ------------------------------------------------------------------- F8 dos instrumentos
if (file.exists(file.path(T_NUE, "4_similitud_tfidf_vs_embeddings.csv"))) {
  tf <- read.csv(file.path(T_NUE, "4_similitud_tfidf_vs_embeddings.csv"), stringsAsFactors = FALSE)
  tfl <- tf %>% pivot_longer(-par, names_to = "instrumento", values_to = "similitud")
  tfl$instrumento <- factor(tfl$instrumento, levels = c("media_tfidf", "media_coseno_embeddings"),
                            labels = c("TF-IDF (sin modelo)", "embeddings (MiniLM)"))
  if (file.exists(file.path(T_EMB, "a_similitud_dos_modelos.csv"))) {
    e2 <- read.csv(file.path(T_EMB, "a_similitud_dos_modelos.csv"), stringsAsFactors = FALSE)
    e2l <- e2 %>% select(par, modelo2_mpnet) %>% pivot_longer(-par, names_to = "instrumento", values_to = "similitud")
    e2l$instrumento <- "embeddings (MPNet)"
    tfl <- bind_rows(tfl, e2l)
  }
  p8 <- ggplot(tfl, aes(x = par, y = similitud, fill = instrumento)) +
    geom_col(position = position_dodge(.75), width = .68) +
    geom_text(aes(label = sprintf("%.2f", similitud)), position = position_dodge(.75), vjust = -0.4, size = 3.2) +
    scale_fill_manual(values = c("#718096", azul, verde), guide = "none") +
    facet_wrap(~instrumento, nrow = 1) +
    labs(title = "El mismo orden con tres instrumentos", subtitle = "Similitud entre momentos de escritura: T2–T3 siempre el más parecido",
         x = NULL, y = "similitud", caption = "familias_nuevas.R — 4; sensibilidad_embeddings2.R") +
    tema
  ggsave(file.path(SAL, "F8_dos_instrumentos.png"), p8, width = 8, height = 4, dpi = 200)
}


# ---------------------------------------------------------------- F9 familias
fam_dec <- file.path(A, "familias_bayes/principal/tablas/decision_por_familia.csv")
fam_stu <- file.path(A, "familias_bayes/principal/tablas/decision_t_student.csv")
if (file.exists(fam_dec)) {
  fd <- read.csv(fam_dec, stringsAsFactors = FALSE)
  fd <- fd[abs(fd$crecimiento) > 10, ]                      # se excluye el ajuste colapsado
  if (file.exists(fam_stu)) fd <- bind_rows(fd, read.csv(fam_stu, stringsAsFactors = FALSE))
  fd$familia <- factor(fd$familia, levels = fd$familia[order(fd$crecimiento)])
  fd$veredicto <- ifelse(fd$ic_dif_bajo > 0 | fd$ic_dif_alto < 0, "concluyente", "no concluyente")
  a <- ggplot(fd, aes(x = crecimiento, y = familia)) +
    geom_vline(xintercept = 0, colour = gris) +
    geom_errorbarh(aes(xmin = ic_crec_bajo, xmax = ic_crec_alto), height = .18, colour = verde, linewidth = .8) +
    geom_point(size = 3, colour = verde) +
    labs(title = "Crecimiento T1→T3 según la familia estadística", x = "palabras", y = NULL,
         caption = "familias_bayes.R — comparación de verosimilitudes") + tema
  b <- ggplot(fd, aes(x = audio_menos_texto, y = familia)) +
    geom_vline(xintercept = 0, colour = gris) +
    annotate("rect", xmin = -20, xmax = 20, ymin = 0.4, ymax = nrow(fd) + 0.6, fill = rojo, alpha = .12) +
    geom_errorbarh(aes(xmin = ic_dif_bajo, xmax = ic_dif_alto), height = .18, colour = azul, linewidth = .8) +
    geom_point(size = 3, colour = azul) +
    labs(title = "Audio − Texto: no concluyente en todas las familias", x = "palabras", y = NULL,
         caption = "Banda roja: equivalencia práctica ±20 palabras") + tema
  p9 <- a | b
  ggsave(file.path(SAL, "F9_familias.png"), p9, width = 11, height = 3.6, dpi = 200)
  cat("  F9_familias.png:", nrow(fd), "familias\n")
}

# -------------------------------------------------------------- panel compuesto
panel <- (p1 + p2) / (p5 + p6) + plot_annotation(
  title = "Resultados nuevos — corrida principal (23 participantes)",
  caption = "Robustez, capa bayesiana y familias nuevas sobre los mismos datos del estudio",
  theme = theme(plot.title = element_text(face = "bold", size = 15)))
ggsave(file.path(SAL, "PANEL_resultados_nuevos.png"), panel, width = 14, height = 8.5, dpi = 190)

cat("\n  figuras generadas en:", SAL, "\n")
for (f in list.files(SAL, pattern = "\\.png$")) cat("   ", f, round(file.size(file.path(SAL, f))/1024), "KB\n")
