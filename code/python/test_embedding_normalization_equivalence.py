"""
Diagnóstico:
equivalencia entre normalización posterior y normalize_embeddings=True.

Este test NO usa R.
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
        elif not isinstance(text, str):
            raise TypeError("Texto inválido.")
        elif text.strip() == "":
            result.append("[VACÍO]")
        else:
            result.append(text)

    return result


def normalize_rows(x):
    norms = np.linalg.norm(x, axis=1)
    norms[norms < 1e-12] = 1.0
    return x / norms[:, None]


print("=" * 70)
print("DIAGNÓSTICO PYTHON — NORMALIZACIÓN")
print("=" * 70)

texts = preprocess(TEXTS)

model = SentenceTransformer(
    MODEL_NAME,
    device="cpu"
)

print("Modelo:", MODEL_NAME)
print("Textos:", len(texts))
print()

# ----------------------------------------------------------------------
# CAMINO A
# encode sin normalización + normalización NumPy
# ----------------------------------------------------------------------

raw = model.encode(
    texts,
    convert_to_numpy=True,
    normalize_embeddings=False,
    show_progress_bar=False
)

raw = np.asarray(raw, dtype=np.float64)

if raw.ndim == 1:
    raw = raw.reshape(1, -1)

a = normalize_rows(raw)

# ----------------------------------------------------------------------
# CAMINO B
# encode con normalización interna
# ----------------------------------------------------------------------

b = model.encode(
    texts,
    convert_to_numpy=True,
    normalize_embeddings=True,
    show_progress_bar=False
)

b = np.asarray(b, dtype=np.float64)

if b.ndim == 1:
    b = b.reshape(1, -1)

# ----------------------------------------------------------------------
# COMPARACIÓN
# ----------------------------------------------------------------------

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

print("Normas A:")
print(np.round(np.linalg.norm(a, axis=1), 10))
print()

print("Normas B:")
print(np.round(np.linalg.norm(b, axis=1), 10))
print()

print("-" * 70)
print("DIFERENCIAS")
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

# ----------------------------------------------------------------------
# CRITERIO
# ----------------------------------------------------------------------

PASS = (
    max_abs_diff <= 1e-6
    and mean_abs_diff <= 1e-8
    and np.max(np.abs(1.0 - cosines)) <= 1e-8
)

print("=" * 70)

if PASS:
    print("PASS — normalización posterior e interna son equivalentes.")
    print("=" * 70)
    raise SystemExit(0)

else:
    print("FAIL — existe discrepancia dentro de Python.")
    print("=" * 70)
    raise SystemExit(1)