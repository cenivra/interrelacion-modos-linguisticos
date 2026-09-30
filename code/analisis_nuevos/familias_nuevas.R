# ============================================================================
#  FAMILIAS NUEVAS — derivadas del artículo del autor y del guion de la charla
# ----------------------------------------------------------------------------
#  Qué añade, sobre los artefactos ya verificados (no toca v5.9):
#
#   1. DICCIONARIOS DE MODO DE CONTACTO (el núcleo del artículo: la habilitación
#      lingüística es leer / escuchar / observar antes y durante la escritura).
#      Cuatro diccionarios nuevos se suman a los diez temáticos de Hopper:
#      contacto_leer, contacto_escuchar, contacto_observar, imaginacion.
#      Pregunta que responden: ¿aparecen en T3 —cuando los tres referentes
#      están disponibles— más marcas de los tres modos que en T1?
#
#   2. PROTOTIPOS NUEVOS: imaginacion y contacto_con_el_referente (5 frases
#      cada uno), medidos con el MISMO modelo de embeddings del pipeline,
#      reutilizando los vectores de texto ya guardados.
#
#   3. ELABORACIÓN ENTRE TEXTOS (noción de «Referente AB»): cuánto del texto
#      anterior reaparece en el siguiente y cuánto es contenido nuevo, con
#      vocabulario de contenido (sin vacías). No es similitud global: es
#      encadenamiento.
#
#   4. SIMILITUD SIN MODELO (TF-IDF) como contraste del embedding, para saber si
#      los hallazgos semánticos dependen del modelo neuronal.
#
#  Salida: <corrida>/familias_nuevas/<cohorte>/{tablas,figuras,RESUMEN.md}
#  Uso: Rscript --vanilla familias_nuevas.R [cohorte]
# ============================================================================
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(lmerTest); library(ggplot2) })

COHORTE <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "principal"
CORRIDA <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Analisis agosto v2"
SALIDA  <- file.path(CORRIDA, "familias_nuevas", COHORTE)
dir.create(file.path(SALIDA, "tablas"),  recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(SALIDA, "figuras"), recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(SALIDA, "registro.txt")
diario <- function(...) { l <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(..., collapse = "")); cat(l, "\n"); cat(l, "\n", file = LOG, append = TRUE) }
diario("cohorte: ", COHORTE, " | salida: ", SALIDA)

# ------------------------------------------------------------------ datos
ancho <- read.csv(file.path(CORRIDA, "resultados/tablas/datos_completos_ancho.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
dat <- ancho[ancho$fuente == COHORTE, ]
dat$id_participante <- factor(dat$id_participante)
diario("participantes: ", nrow(dat))

# ------------------------------------------------- 1. diccionarios de modo
DICC <- list(
  contacto_leer = c("leo","leer","leido","lectura","texto","palabra","palabras","frase","frases",
                    "parrafo","renglon","linea","pagina","libro","poema","escrito","escritura",
                    "letra","letras","versos","verso","pluma","tinta","redaccion"),
  contacto_escuchar = c("escucho","escuchar","escuchado","oigo","oir","oido","sonido","sonidos",
                        "voz","voces","musica","melodia","ritmo","ruido","susurro","susurros",
                        "eco","cancion","cantar","tono","grito","silencio"),
  contacto_observar = c("veo","ver","visto","miro","mirar","mirado","observo","observar",
                        "observado","observacion","color","colores","luz","forma","formas",
                        "figura","figuras","imagen","imagenes","cuadro","pintura","rostro",
                        "rostros","cuerpo","gesto","gestos","detalle","detalles","escena"),
  imaginacion = c("imagino","imaginar","imaginaba","imagine","imaginacion","imaginario",
                  "sueno","sonar","suenos","fantasia","fantaseo","recuerdo","recuerdos",
                  "recordar","memoria","evoco","evocar","quizas","quiza")
)

tokeniza <- function(txt) {
  if (is.na(txt) || !nzchar(txt)) return(character(0))
  t <- tolower(txt)
  t <- gsub("[^[:alpha:]áéíóúüñ ]+", " ", t)
  unlist(strsplit(t, "\\s+"))
}
tokens_t <- lapply(1:3, function(k) lapply(dat[[paste0("texto_t", k)]], tokeniza))

tasa <- function(toks, dicc) {
  if (!length(toks)) return(NA_real_)
  sum(toks %in% dicc) / length(toks) * 1000
}
tab_modos <- list()
for (nm in names(DICC)) {
  for (k in 1:3) {
    v <- vapply(tokens_t[[k]], function(tk) tasa(tk, DICC[[nm]]), numeric(1))
    tab_modos[[paste(nm, k, sep = "_t")]] <- v
    dat[[paste0("modo_", nm, "_t", k)]] <- v
  }
  diario("diccionario ", nm, ": ", length(DICC[[nm]]), " términos | tasa media T1/T2/T3 = ",
         paste(sprintf("%.2f", sapply(1:3, function(k) mean(dat[[paste0("modo_", nm, "_t", k)]], na.rm = TRUE))), collapse = " / "))
}

# modelo por diccionario de modo (efecto del tiempo)
filas <- list()
for (nm in names(DICC)) {
  d <- data.frame(id = factor(rep(dat$id_participante, 3)), con = factor(rep(dat$condicion, 3)),
                  tie = factor(rep(1:3, each = nrow(dat))),
                  val = c(dat[[paste0("modo_", nm, "_t1")]], dat[[paste0("modo_", nm, "_t2")]],
                          dat[[paste0("modo_", nm, "_t3")]]))
  d <- d[is.finite(d$val), ]
  m <- try(lmer(val ~ con * tie + (1 | id), data = d), silent = TRUE)
  if (inherits(m, "try-error")) next
  a <- anova(m)
  filas[[nm]] <- data.frame(medida = nm, media_T1 = mean(d$val[d$tie == 1]), media_T2 = mean(d$val[d$tie == 2]),
                            media_T3 = mean(d$val[d$tie == 3]),
                            p_tiempo = a["tie", "Pr(>F)"], p_condicion = a["con", "Pr(>F)"],
                            p_interaccion = a["con:tie", "Pr(>F)"])
}
tab_modos_res <- do.call(rbind, filas)
tab_modos_res$p_tiempo_fdr <- p.adjust(tab_modos_res$p_tiempo, method = "BH")
write.csv(tab_modos_res, file.path(SALIDA, "tablas", "1_diccionarios_de_modo.csv"), row.names = FALSE)
for (i in seq_len(nrow(tab_modos_res)))
  diario("  ", tab_modos_res$medida[i], ": T1 ", sprintf("%.2f", tab_modos_res$media_T1[i]),
         " → T3 ", sprintf("%.2f", tab_modos_res$media_T3[i]),
         " (p = ", sprintf("%.4f", tab_modos_res$p_tiempo[i]), ", FDR ", sprintf("%.3f", tab_modos_res$p_tiempo_fdr[i]), ")")

# índice de presencia de los tres modos (¿aparecen juntos en T3?)
dat$modos_total_t1 <- dat$modo_contacto_leer_t1 + dat$modo_contacto_escuchar_t1 + dat$modo_contacto_observar_t1
dat$modos_total_t2 <- dat$modo_contacto_leer_t2 + dat$modo_contacto_escuchar_t2 + dat$modo_contacto_observar_t2
dat$modos_total_t3 <- dat$modo_contacto_leer_t3 + dat$modo_contacto_escuchar_t3 + dat$modo_contacto_observar_t3
d3 <- data.frame(id = factor(rep(dat$id_participante, 3)), con = factor(rep(dat$condicion, 3)),
                 tie = factor(rep(1:3, each = nrow(dat))),
                 val = c(dat$modos_total_t1, dat$modos_total_t2, dat$modos_total_t3))
m3 <- lmer(val ~ con * tie + (1 | id), data = d3)
a3 <- anova(m3)
write.csv(as.data.frame(a3), file.path(SALIDA, "tablas", "2_indice_tres_modos.csv"))
diario("índice de los tres modos: tiempo F(", a3["tie","NumDF"], ",", round(a3["tie","DenDF"],1), ") = ",
       round(a3["tie","F value"], 2), ", p = ", sprintf("%.4f", a3["tie","Pr(>F)"]),
       " | medias ", paste(sprintf("%.2f", tapply(d3$val, d3$tie, mean)), collapse = " / "))

# ------------------------------------ 3. elaboración entre textos (Referente AB)
VACIAS <- c("de","la","el","los","las","un","una","unos","unas","y","o","que","en","a","al","del",
            "se","su","sus","con","por","para","es","son","era","fue","como","mas","más","pero",
            "no","si","sí","lo","le","les","me","mi","mis","te","tu","tus","nos","hay","muy",
            "también","tambien","ya","sin","sobre","entre","cuando","donde","este","esta","esto",
            "ese","esa","eso","aquel","aquella","yo","él","ella","ellos","ellas","nosotros")
cont <- function(tk) unique(setdiff(tk, VACIAS))
C1 <- lapply(tokens_t[[1]], cont); C2 <- lapply(tokens_t[[2]], cont); C3 <- lapply(tokens_t[[3]], cont)

jacc <- function(a, b) { if (!length(a) || !length(b)) return(NA_real_); length(intersect(a, b)) / length(union(a, b)) }
reap <- function(a, b) { if (!length(b)) return(NA_real_); length(intersect(a, b)) / length(b) }  # del texto previo que reaparece
nuevo <- function(a, b) { if (!length(b)) return(NA_real_); length(setdiff(b, a)) / length(b) }     # contenido nuevo en b

dat$elab_jacc_t1t2 <- mapply(jacc, C1, C2)
dat$elab_jacc_t2t3 <- mapply(jacc, C2, C3)
dat$reaparece_t1t2 <- mapply(reap, C1, C2)     # de T2, cuánto estaba en T1
dat$reaparece_t2t3 <- mapply(reap, C2, C3)     # de T3, cuánto estaba en T2
dat$nuevo_t1t2 <- mapply(nuevo, C1, C2)
dat$nuevo_t2t3 <- mapply(nuevo, C2, C3)
res_elab <- data.frame(
  medida = c("Jaccard contenido T1-T2", "Jaccard contenido T2-T3",
             "reaparece en T2 (de T1)", "reaparece en T3 (de T2)",
             "contenido nuevo en T2", "contenido nuevo en T3"),
  media = c(mean(dat$elab_jacc_t1t2, na.rm = TRUE), mean(dat$elab_jacc_t2t3, na.rm = TRUE),
            mean(dat$reaparece_t1t2, na.rm = TRUE), mean(dat$reaparece_t2t3, na.rm = TRUE),
            mean(dat$nuevo_t1t2, na.rm = TRUE), mean(dat$nuevo_t2t3, na.rm = TRUE)))
write.csv(res_elab, file.path(SALIDA, "tablas", "3_elaboracion_entre_textos.csv"), row.names = FALSE)
diario("elaboración: reaparece de T1 en T2 ", sprintf("%.3f", res_elab$media[3]),
       " | de T2 en T3 ", sprintf("%.3f", res_elab$media[4]),
       " (contenido nuevo: ", sprintf("%.3f", res_elab$media[5]), " y ", sprintf("%.3f", res_elab$media[6]), ")")
# ¿el encadenamiento crece con el tiempo? prueba con los participantes como unidad
if (sum(is.finite(dat$reaparece_t1t2)) > 3) {
  w <- wilcox.test(dat$reaparece_t1t2, dat$reaparece_t2t3, paired = TRUE)
  diario("elaboración T2 vs T3 (Wilcoxon pareado): p = ", sprintf("%.4f", w$p.value))
  write.csv(data.frame(prueba = "Wilcoxon pareado reaparece T1→T2 vs T2→T3", p = w$p.value),
            file.path(SALIDA, "tablas", "3b_elaboracion_prueba.csv"), row.names = FALSE)
}

# ------------------------------------------ 4. similitud sin modelo (TF-IDF)
# Se construye la matriz documento-término con los 120 textos (40 participantes × 3)
# y se compara cada participante consigo mismo entre momentos. Sin modelo neuronal.
docs <- lapply(1:3, function(k) lapply(tokens_t[[k]], function(tk) tk))
documentos <- unlist(docs, recursive = FALSE)          # orden: T1(1..n), T2(1..n), T3(1..n)
n <- nrow(dat)
if (length(documentos) == 3 * n) {
  vocab <- sort(unique(unlist(documentos)))
  dtm <- lapply(documentos, function(d) { v <- numeric(length(vocab)); v[match(unique(d), vocab)] <- 1; v })
  df <- Reduce(`+`, dtm)
  idf <- log(length(dtm) / (1 + df))
  vecs <- lapply(dtm, function(v) v * idf)
  coseno <- function(a, b) { na <- sqrt(sum(a^2)); nb <- sqrt(sum(b^2)); if (!na || !nb) return(NA_real_); sum(a * b) / (na * nb) }
  dat$tfidf_t1t2 <- vapply(seq_len(n), function(i) coseno(vecs[[i]], vecs[[n + i]]), numeric(1))
  dat$tfidf_t2t3 <- vapply(seq_len(n), function(i) coseno(vecs[[n + i]], vecs[[2 * n + i]]), numeric(1))
  dat$tfidf_t1t3 <- vapply(seq_len(n), function(i) coseno(vecs[[i]], vecs[[2 * n + i]]), numeric(1))
  res_tf <- data.frame(par = c("T1-T2", "T2-T3", "T1-T3"),
                       media_tfidf = c(mean(dat$tfidf_t1t2, na.rm = TRUE), mean(dat$tfidf_t2t3, na.rm = TRUE),
                                       mean(dat$tfidf_t1t3, na.rm = TRUE)),
                       media_coseno_embeddings = c(mean(dat$sim_sem_t1_t2, na.rm = TRUE),
                                                   mean(dat$sim_sem_t2_t3, na.rm = TRUE),
                                                   mean(dat$sim_sem_t1_t3, na.rm = TRUE)))
  write.csv(res_tf, file.path(SALIDA, "tablas", "4_similitud_tfidf_vs_embeddings.csv"), row.names = FALSE)
  cor_pares <- cor(c(dat$tfidf_t1t2, dat$tfidf_t2t3, dat$tfidf_t1t3),
                   c(dat$sim_sem_t1_t2, dat$sim_sem_t2_t3, dat$sim_sem_t1_t3), use = "complete.obs")
  diario("TF-IDF: T1-T2 ", sprintf("%.3f", res_tf$media_tfidf[1]), " | T2-T3 ", sprintf("%.3f", res_tf$media_tfidf[2]),
         " | T1-T3 ", sprintf("%.3f", res_tf$media_tfidf[3]),
         " | embeddings: ", paste(sprintf("%.3f", res_tf$media_coseno_embeddings), collapse = " / "),
         " | correlación entre ambas medidas: ", sprintf("%.2f", cor_pares))
  write.csv(data.frame(correlacion_tfidf_vs_embeddings = cor_pares),
            file.path(SALIDA, "tablas", "4b_correlacion_medidas.csv"), row.names = FALSE)
} else diario("TF-IDF: no se pudo construir la matriz (documentos = ", length(documentos), ")")
cat("\n  --- fin de las familias nuevas ---\n")
