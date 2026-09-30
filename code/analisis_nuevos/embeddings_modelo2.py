#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Segundo modelo de embeddings — prueba de sensibilidad de los hallazgos semánticos.

Modelo 1 (el del pipeline): paraphrase-multilingual-MiniLM-L12-v2  (MiniLM, 384 dims)
Modelo 2 (este script):     paraphrase-multilingual-mpnet-base-v2  (MPNet, 768 dims)
                            → otra familia arquitectónica, como pide el plan.

Entradas (escritas por el driver en R, borradas al terminar):
  --textos    TSV con id, momento, texto          (120 filas: 40 participantes × 3)
  --prototipos CSV con constructo, familia, frase (100 del catálogo + los nuevos)

Salidas (sólo números, sin texto de participantes):
  --salida-textos      CSV id, momento, dim_1..dim_n
  --salida-prototipos  CSV constructo, familia, frase_idx, dim_1..dim_n

No imprime texto alguno de participantes: sólo formas, dimensiones y tiempos.
"""
import argparse, csv, sys, time
import numpy as np

MODELO = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"

ap = argparse.ArgumentParser()
ap.add_argument("--textos", required=True)
ap.add_argument("--prototipos", required=True)
ap.add_argument("--salida-textos", required=True)
ap.add_argument("--salida-prototipos", required=True)
ap.add_argument("--modelo", default=MODELO)
a = ap.parse_args()

from sentence_transformers import SentenceTransformer

t0 = time.time()
print(f"  modelo: {a.modelo}")
modelo = SentenceTransformer(a.modelo)
print(f"  cargado en {time.time()-t0:.1f} s | dimensión = {modelo.get_sentence_embedding_dimension()}")

# ---- textos
ids, momentos, textos = [], [], []
with open(a.textos, encoding="utf-8") as fh:
    for fila in csv.reader(fh, delimiter="\t"):
        if len(fila) < 3:
            continue
        ids.append(fila[0]); momentos.append(fila[1]); textos.append(fila[2])
t0 = time.time()
V = modelo.encode(textos, normalize_embeddings=True, batch_size=8, show_progress_bar=False)
V = np.asarray(V)
print(f"  textos codificados: {V.shape[0]} × {V.shape[1]} en {time.time()-t0:.1f} s")
print(f"  norma media antes de normalizar: {np.linalg.norm(V, axis=1).mean():.3f} (normalizado ⇒ ~1)")
with open(a.salida_textos, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["id", "momento"] + [f"d{i}" for i in range(V.shape[1])])
    for k in range(V.shape[0]):
        w.writerow([ids[k], momentos[k]] + [f"{x:.6f}" for x in V[k]])
print(f"  guardado: {a.salida_textos}")

# ---- prototipos
cons, fams, frases = [], [], []
with open(a.prototipos, encoding="utf-8-sig") as fh:
    for fila in csv.DictReader(fh):
        cons.append(fila["constructo"]); fams.append(fila["familia"]); frases.append(fila["frase"])
P = np.asarray(modelo.encode(frases, normalize_embeddings=True, batch_size=8, show_progress_bar=False))
print(f"  prototipos codificados: {P.shape[0]} frases × {P.shape[1]} dimensiones")
with open(a.salida_prototipos, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["constructo", "familia", "frase_idx"] + [f"d{i}" for i in range(P.shape[1])])
    for k in range(P.shape[0]):
        w.writerow([cons[k], fams[k], k] + [f"{x:.6f}" for x in P[k]])
print(f"  guardado: {a.salida_prototipos}")
print("  listo.")
