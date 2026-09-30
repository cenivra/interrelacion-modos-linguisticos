# ============================================================================
#  ¿Los hallazgos semánticos dependen del modelo de embeddings?
#  Prueba de sensibilidad con un segundo modelo de otra familia arquitectónica
# ----------------------------------------------------------------------------
#  Modelo 1 (pipeline): paraphrase-multilingual-MiniLM-L12-v2 (MiniLM, 384 dims)
#  Modelo 2 (aquí):     paraphrase-multilingual-mpnet-base-v2 (MPNet, 768 dims)
#
#  Qué se replica con el modelo 2, contra lo ya guardado del modelo 1:
#    a) similitud entre momentos (sim_sem_*) — ¿se conserva el orden T2-T3 > T1-T2 > T1-T3?
#    b) distancia en el espacio reducido (dist_euclidiana_T1T3) — ¿se conserva el orden
#       Imagen > Audio > Texto?
#    c) proximidad a los 22 prototipos (20 del catálogo + 2 nuevos) — ¿se conserva el
#       conjunto de constructos que más cambian?
#
#  El texto de los participantes se escribe a un TSV temporal, se codifica y se borra
#  en la misma corrida: no queda copia, no se imprime, no entra al repositorio.
#  Uso: Rscript --vanilla sensibilidad_embeddings2.R [cohorte]
# ============================================================================
suppressPackageStartupMessages({ library(jsonlite); library(dplyr) })

COHORTE <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "principal"
CORRIDA <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Analisis agosto v2"
SALIDA  <- file.path(CORRIDA, "sensibilidad_embeddings2", COHORTE)
dir.create(file.path(SALIDA, "tablas"), recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(SALIDA, "registro.txt")
diario <- function(...) { l <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(..., collapse = "")); cat(l, "\n"); cat(l, "\n", file = LOG, append = TRUE) }

PY <- "C:/venvs/renv-nlp/Scripts/python.exe"
PY_SCRIPT <- file.path(CORRIDA, "..", "Script en R", "embeddings_modelo2.py")
PY_SCRIPT <- "C:/Users/saraq/Downloads/Experimento Alfonso Lopez Corral/Script en R/embeddings_modelo2.py"
TMP <- file.path(SALIDA, "_tmp")
dir.create(TMP, recursive = TRUE, showWarnings = FALSE)
TSV <- file.path(TMP, "textos.txt")
PROT <- file.path(TMP, "prototipos.csv")
VEC_T <- file.path(TMP, "vectores_textos.csv")
VEC_P <- file.path(TMP, "vectores_prototipos.csv")

# ---------------------------------------------------------------- datos
ancho_csv <- file.path(CORRIDA, "resultados", "tablas", "datos_completos_ancho.csv")
ancho <- read.csv(ancho_csv, stringsAsFactors = FALSE, check.names = FALSE)
dat <- ancho[ancho$fuente == COHORTE, ]
IDCOL <- if ("id_participante" %in% names(dat)) "id_participante" else grep("^id", names(dat), value = TRUE)[1]
dat$id_participante <- dat[[IDCOL]]
diario("cohorte ", COHORTE, ": ", nrow(dat), " participantes | columnas: ", ncol(dat), " | columna id: ", IDCOL)

reutilizar <- file.exists(VEC_T) && file.exists(VEC_P)
if (reutilizar) diario("se reutilizan los vectores ya codificados (no se vuelve a codificar)")
if (!reutilizar) {
# TSV temporal (se borra al final de la corrida)
con <- file(TSV, "w", encoding = "UTF-8")
for (k in 1:3) for (i in seq_len(nrow(dat))) {
  t <- dat[[paste0("texto_t", k)]][i]
  if (is.na(t) || !nzchar(t)) next
  t <- gsub("[\r\n\t]+", " ", t)
  writeLines(paste(dat$id_participante[i], k, t, sep = "\t"), con)
}
close(con)
diario("textos preparados para codificar: ", length(readLines(TSV)), " (T1+T2+T3)")

# prototipos: catálogo de 20 + los dos nuevos
esp <- read.csv("C:/Users/saraq/Documents/interrelacion-modos-linguisticos/data_spec/prototipos.csv",
                stringsAsFactors = FALSE, encoding = "UTF-8")
prot <- data.frame(constructo = esp$constructo, familia = esp$familia, frase = esp$frase)
nuevos <- read.csv("C:/Users/saraq/AppData/Local/Temp/prototipos_nuevos.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
prot <- rbind(prot, nuevos)
write.csv(prot, PROT, row.names = FALSE, fileEncoding = "UTF-8")
diario("prototipos a codificar: ", nrow(prot), " frases de ", length(unique(prot$constructo)), " constructos")

# ---------------------------------------------------- codificación (modelo 2)
t0 <- Sys.time()
sal <- system2(PY, c(shQuote(PY_SCRIPT),
                     "--textos", shQuote(TSV), "--prototipos", shQuote(PROT),
                     "--salida-textos", shQuote(VEC_T), "--salida-prototipos", shQuote(VEC_P)),
               stdout = TRUE, stderr = TRUE)
cat(paste0("  ", sal, "\n"))
diario("codificación con el modelo 2 terminada en ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")

# el TSV con texto se elimina de inmediato
unlink(TSV); if (file.exists(TSV)) stop("no se pudo borrar el TSV temporal con texto")
diario("TSV temporal eliminado: ", !file.exists(TSV))
}
stopifnot(file.exists(VEC_T), file.exists(VEC_P))

# ---------------------------------------------------------------- vectores
VT <- read.csv(VEC_T, stringsAsFactors = FALSE, check.names = FALSE)
VP <- read.csv(VEC_P, stringsAsFactors = FALSE, check.names = FALSE)
mtext <- as.matrix(VT[, grep("^d[0-9]+$", names(VT))])
mprot <- as.matrix(VP[, grep("^d[0-9]+$", names(VP))])
diario("vectores: textos ", nrow(mtext), "×", ncol(mtext), " | prototipos ", nrow(mprot), "×", ncol(mprot))

cos_v <- function(A, B) {  # filas ya normalizadas
  s <- rowSums(A * B)
  s
}
idx <- function(id, k) which(VT$id == id & as.character(VT$momento) == as.character(k))

# a) similitud entre momentos
ids <- unique(dat$id_participante)
sim2 <- data.frame(id = ids,
                   t1t2 = vapply(ids, function(i) cos_v(mtext[idx(i, 1), , drop = FALSE], mtext[idx(i, 2), , drop = FALSE]), numeric(1)),
                   t2t3 = vapply(ids, function(i) cos_v(mtext[idx(i, 2), , drop = FALSE], mtext[idx(i, 3), , drop = FALSE]), numeric(1)),
                   t1t3 = vapply(ids, function(i) cos_v(mtext[idx(i, 1), , drop = FALSE], mtext[idx(i, 3), , drop = FALSE]), numeric(1)))
m1 <- dat[match(sim2$id, dat$id_participante), c("sim_sem_t1_t2", "sim_sem_t2_t3", "sim_sem_t1_t3")]
tab_sim <- data.frame(par = c("T1-T2", "T2-T3", "T1-T3"),
                      modelo1_miniLM = c(mean(m1$sim_sem_t1_t2, na.rm = TRUE), mean(m1$sim_sem_t2_t3, na.rm = TRUE), mean(m1$sim_sem_t1_t3, na.rm = TRUE)),
                      modelo2_mpnet = c(mean(sim2$t1t2), mean(sim2$t2t3), mean(sim2$t1t3)))
tab_sim$diferencia <- tab_sim$modelo2_mpnet - tab_sim$modelo1_miniLM
cor_sim <- cor(c(sim2$t1t2, sim2$t2t3, sim2$t1t3), c(m1$sim_sem_t1_t2, m1$sim_sem_t2_t3, m1$sim_sem_t1_t3), use = "complete.obs")
write.csv(tab_sim, file.path(SALIDA, "tablas", "a_similitud_dos_modelos.csv"), row.names = FALSE)
diario("a) similitud  modelo1 ", paste(sprintf("%.3f", tab_sim$modelo1_miniLM), collapse = " / "),
       " | modelo2 ", paste(sprintf("%.3f", tab_sim$modelo2_mpnet), collapse = " / "),
       " | correlación por participante ", sprintf("%.2f", cor_sim))
orden_ok <- function(v) { m <- setNames(v, tab_sim$par); m["T2-T3"] > m["T1-T2"] && m["T1-T2"] > m["T1-T3"] }
diario("a) orden T2-T3 > T1-T2 > T1-T3 — modelo1: ", orden_ok(tab_sim$modelo1_miniLM),
       " | modelo2: ", orden_ok(tab_sim$modelo2_mpnet))

# b) distancia en el espacio reducido y su orden por condición
pc <- prcomp(mtext, center = TRUE, scale. = FALSE)
var_exp <- summary(pc)$importance[2, 1:2]
sc <- pc$x[, 1:2]
sc <- data.frame(id = VT$id, momento = VT$momento, PC1 = sc[, 1], PC2 = sc[, 2])
d2 <- sapply(ids, function(i) {
  a <- sc[sc$id == i & sc$momento == 1, ]; b <- sc[sc$id == i & sc$momento == 3, ]
  sqrt(sum((a$PC1 - b$PC1)^2 + (a$PC2 - b$PC2)^2))
})
dd <- data.frame(id = ids, dist_modelo2 = as.numeric(d2))
dd$condicion <- dat$condicion[match(dd$id, dat$id_participante)]
dd$dist_modelo1 <- dat$dist_euclidiana_T1T3[match(dd$id, dat$id_participante)]
tab_dist <- dd %>% group_by(condicion) %>%
  summarise(modelo1_miniLM = mean(dist_modelo1, na.rm = TRUE), modelo2_mpnet = mean(dist_modelo2), .groups = "drop")
tab_dist <- tab_dist[order(-tab_dist$modelo2_mpnet), ]
write.csv(tab_dist, file.path(SALIDA, "tablas", "b_distancias_dos_modelos.csv"), row.names = FALSE)
diario("b) distancia T1-T3 por condición (modelo2, mayor a menor): ",
       paste(tab_dist$condicion, sprintf("%.2f", tab_dist$modelo2_mpnet), sep = " ", collapse = " | "))
diario("b) varianza retenida PC1+PC2 modelo2: ", sprintf("%.2f%%", 100 * sum(var_exp)),
       " (modelo1: 20.19%) | correlación de distancias ", sprintf("%.2f", cor(dd$dist_modelo1, dd$dist_modelo2, use = "complete.obs")))

# c) proximidad a los prototipos (media de las frases de cada constructo)
cons <- unique(VP$constructo)
filas_prox <- list()
for (cn in cons) {
  Pc <- mprot[which(VP$constructo == cn), , drop = FALSE]
  prox_de <- function(i, k) mean(as.vector(Pc %*% as.vector(mtext[idx(i, k), , drop = FALSE])))
  v1 <- vapply(ids, function(i) prox_de(i, 1), numeric(1))
  v2 <- vapply(ids, function(i) prox_de(i, 2), numeric(1))
  v3 <- vapply(ids, function(i) prox_de(i, 3), numeric(1))
  cols <- paste0("proto_", cn, "_t", 1:3)
  m1d <- NA_real_
  if (all(cols %in% names(dat))) {
    d <- dat[match(ids, dat$id_participante), ]
    m1d <- mean(as.numeric(d[[cols[3]]]) - as.numeric(d[[cols[1]]]), na.rm = TRUE)
  }
  filas_prox[[cn]] <- data.frame(constructo = cn,
                                 prox_t1_modelo2 = mean(v1), prox_t2_modelo2 = mean(v2), prox_t3_modelo2 = mean(v3),
                                 delta_T3_T1_modelo2 = mean(v3) - mean(v1),
                                 delta_T3_T1_modelo1 = m1d)
}
prox_tab <- do.call(rbind, filas_prox)
prox_tab <- prox_tab[order(-abs(prox_tab$delta_T3_T1_modelo2)), ]
write.csv(prox_tab, file.path(SALIDA, "tablas", "c_prototipos_dos_modelos.csv"), row.names = FALSE)
top2 <- head(prox_tab, 6)
diario("c) constructos con mayor cambio (modelo2):")
for (i in seq_len(nrow(top2))) diario("   ", top2$constructo[i],
       ": modelo2 ", sprintf("%+.4f", top2$delta_T3_T1_modelo2[i]),
       " | modelo1 ", ifelse(is.na(top2$delta_T3_T1_modelo1[i]), "sin dato", sprintf("%+.4f", top2$delta_T3_T1_modelo1[i])))
cor_prox <- cor(prox_tab$delta_T3_T1_modelo2, prox_tab$delta_T3_T1_modelo1, use = "complete.obs")
diario("c) correlación de los cambios por constructo entre modelos: ", sprintf("%.2f", cor_prox))

# ------------------------------------------------------------------ resumen
resumen <- c(
  paste0("# ¿Dependen los hallazgos semánticos del modelo de embeddings? — cohorte ", COHORTE),
  "",
  "Modelo 1 (pipeline): `paraphrase-multilingual-MiniLM-L12-v2`, MiniLM, 384 dimensiones.",
  "Modelo 2 (prueba): `paraphrase-multilingual-mpnet-base-v2`, MPNet, 768 dimensiones.",
  "Mismo texto, mismos parámetros de comparación (coseno sobre vectores normalizados).",
  "",
  "## a) Similitud entre momentos",
  "",
  "| par | modelo 1 (MiniLM) | modelo 2 (MPNet) |",
  "| --- | --- | --- |",
  sapply(seq_len(nrow(tab_sim)), function(i) paste0("| ", tab_sim$par[i], " | ",
                                                    sprintf("%.3f", tab_sim$modelo1_miniLM[i]), " | ",
                                                    sprintf("%.3f", tab_sim$modelo2_mpnet[i]), " |")),
  "",
  paste0("Correlación entre modelos por participante: **", sprintf("%.2f", cor_sim), "**."),
  paste0("Orden T2-T3 > T1-T2 > T1-T3 en el modelo 1: **", orden_ok(tab_sim$modelo1_miniLM),
         "**; en el modelo 2: **", orden_ok(tab_sim$modelo2_mpnet), "**."),
  "",
  "## b) Distancia T1-T3 en el espacio reducido",
  "",
  "| condición | modelo 1 | modelo 2 |",
  "| --- | --- | --- |",
  sapply(seq_len(nrow(tab_dist)), function(i) paste0("| ", tab_dist$condicion[i], " | ",
                                                     sprintf("%.2f", tab_dist$modelo1_miniLM[i]), " | ",
                                                     sprintf("%.2f", tab_dist$modelo2_mpnet[i]), " |")),
  "",
  paste0("Varianza retenida por las dos primeras componentes — modelo 1: 20.19 %; modelo 2: ",
         sprintf("%.2f%%", 100 * sum(var_exp)), "."),
  "",
  "## c) Prototipos",
  "",
  paste0("Correlación de los cambios T1→T3 por constructo entre ambos modelos: **", sprintf("%.2f", cor_prox), "**."),
  "",
  "| constructo | Δ T1→T3 modelo 2 | Δ T1→T3 modelo 1 |",
  "| --- | --- | --- |",
  sapply(seq_len(nrow(top2)), function(i) paste0("| ", top2$constructo[i], " | ",
                                                 sprintf("%+.4f", top2$delta_T3_T1_modelo2[i]), " | ",
                                                 ifelse(is.na(top2$delta_T3_T1_modelo1[i]), "—", sprintf("%+.4f", top2$delta_T3_T1_modelo1[i])), " |")),
  "",
  "Si los tres órdenes coinciden y las correlaciones son altas, el hallazgo semántico no es un",
  "artefacto del instrumento y así se declara en el manuscrito; si discrepan, se reportan las dos",
  "lecturas y se marca el límite.",
  "",
  paste0("Cookie de trazabilidad — modelo 2: MPNet 768 dims | textos codificados: ", nrow(mtext),
         " | prototipos: ", length(cons), " | fecha: ", format(Sys.time(), "%Y-%m-%d %H:%M"))
)
writeLines(resumen, file.path(SALIDA, "RESUMEN.md"))

# limpieza de los vectores temporales (se quedan las tablas y el resumen)
unlink(TMP, recursive = TRUE)
diario("terminado. archivos: ", paste(basename(list.files(SALIDA, recursive = TRUE)), collapse = ", "))
