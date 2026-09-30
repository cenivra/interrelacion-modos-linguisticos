"""
Diagnóstico:
comparación de dos instancias independientes del mismo
SentenceTransformer.
"""

import numpy as np
from sentence_transformers import SentenceTransformer


MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"

TEXTS = [
    "Me siento solo y aislado de los demás.",
    "Tengo esperanza de que las cosas mejoren.",
    "La incertidumbre me impide avanzar.",
    "Busco maneras de enfrentar las dificultades.",
    "No logro comunicarme con los demás.",
    "La tristeza y el dolor me acompañan constantemente.",
    "Tengo control sobre mis decisiones.",
    "",
    None,
]


def preprocess(texts):
    result = []

    for text in texts:
        if text is None:
            result.append("[VACÍO]")
        elif text.strip() == "":
            result.append("[VACÍO]")
        else:
            result.append(text)

    return result


texts = preprocess(TEXTS)

print("=" * 70)
print("DIAGNÓSTICO — DOS INSTANCIAS DEL MISMO MODELO")
print("=" * 70)

print("Cargando instancia A...")

model_a = SentenceTransformer(
    MODEL_NAME,
    device="cpu"
)

print("Cargando instancia B...")

model_b = SentenceTransformer(
    MODEL_NAME,
    device="cpu"
)

print()
print("Generando embeddings...")
print()

a = model_a.encode(
    texts,
    convert_to_numpy=True,
    normalize_embeddings=True,
    show_progress_bar=False
)

b = model_b.encode(
    texts,
    convert_to_numpy=True,
    normalize_embeddings=True,
    show_progress_bar=False
)

a = np.asarray(a, dtype=np.float64)
b = np.asarray(b, dtype=np.float64)

if a.ndim == 1:
    a = a.reshape(1, -1)

if b.ndim == 1:
    b = b.reshape(1, -1)

diff = a - b

max_abs_diff = np.max(np.abs(diff))
mean_abs_diff = np.mean(np.abs(diff))
rmse = np.sqrt(np.mean(diff ** 2))

cosines = np.sum(a * b, axis=1) / (
    np.linalg.norm(a, axis=1) *
    np.linalg.norm(b, axis=1)
)

print("Dimensión A:", a.shape)
print("Dimensión B:", b.shape)
print()

print("-" * 70)
print("DIFERENCIAS ENTRE INSTANCIAS")
print("-" * 70)

print(f"Diferencia absoluta máxima: {max_abs_diff:.12e}")
print(f"Diferencia absoluta media:  {mean_abs_diff:.12e}")
print(f"RMSE:                       {rmse:.12e}")
print()

print("Coseno por observación:")

for i, cosine in enumerate(cosines, start=1):
    print(f"{i}: {cosine:.12f}")

print()
print("Coseno mínimo:", f"{np.min(cosines):.12f}")
print("Coseno máximo:", f"{np.max(cosines):.12f}")

print()
print("=" * 70)

PASS = (
    max_abs_diff <= 1e-6
    and mean_abs_diff <= 1e-8
    and np.max(np.abs(1.0 - cosines)) <= 1e-8
)

if PASS:
    print("PASS — ambas instancias producen embeddings equivalentes.")
    print("=" * 70)
    raise SystemExit(0)

else:
    print("FAIL — las dos instancias producen embeddings diferentes.")
    print("=" * 70)
    raise SystemExit(1)