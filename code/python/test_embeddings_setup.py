import sys
import numpy as np

sys.path.insert(0, "./python")

from embeddings_setup import encode_texts, get_model_info

print("=" * 70)
print("SISAP — PRUEBA CONTROLADA DE encode_texts()")
print("=" * 70)

print("\n[1] INFORMACIÓN DEL MODELO")
info = get_model_info()

for key, value in info.items():
    print(f"{key}: {value}")


# ----------------------------------------------------------------------
# PRUEBA 1 — TEXTO NORMAL
# ----------------------------------------------------------------------

print("\n" + "=" * 70)
print("[2] PRUEBA 1 — TEXTO NORMAL")
print("=" * 70)

texto = ["Me siento solo y aislado de los demás"]

emb = encode_texts(texto)

print(f"Tipo: {type(emb)}")
print(f"Shape: {emb.shape}")
print(f"Dtype: {emb.dtype}")
print(f"Norma L2: {np.linalg.norm(emb[0]):.10f}")

assert emb.shape == (1, 384), \
    f"ERROR: se esperaba (1, 384), se obtuvo {emb.shape}"

assert np.isclose(np.linalg.norm(emb[0]), 1.0, atol=1e-6), \
    "ERROR: el embedding no está normalizado."

print("OK — texto normal produce 1 × 384 normalizado.")


# ----------------------------------------------------------------------
# PRUEBA 2 — TEXTO VACÍO / None
# ----------------------------------------------------------------------

print("\n" + "=" * 70)
print("[3] PRUEBA 2 — TEXTO VACÍO / None")
print("=" * 70)

textos_vacios = [
    "",
    "   ",
    None
]

emb_vacios = encode_texts(textos_vacios)

print(f"Shape: {emb_vacios.shape}")
print(f"Dtype: {emb_vacios.dtype}")

for i, vector in enumerate(emb_vacios):
    print(
        f"Vector {i + 1}: "
        f"norma L2 = {np.linalg.norm(vector):.10f}"
    )

assert emb_vacios.shape == (3, 384), \
    f"ERROR: se esperaba (3, 384), se obtuvo {emb_vacios.shape}"

normas = np.linalg.norm(emb_vacios, axis=1)

assert np.allclose(normas, 1.0, atol=1e-6), \
    "ERROR: los embeddings de [VACÍO] no están normalizados."

print("OK — '', '   ' y None son tratados como [VACÍO].")


# ----------------------------------------------------------------------
# PRUEBA 3 — VARIOS TEXTOS
# ----------------------------------------------------------------------

print("\n" + "=" * 70)
print("[4] PRUEBA 3 — VARIOS TEXTOS")
print("=" * 70)

textos = [
    "Me siento solo y aislado de los demás",
    "Tengo esperanza de que las cosas mejoren",
    "No sé lo que va a pasar mañana",
    "Busco maneras de enfrentar las dificultades",
    "Prefiero no pensar en los problemas"
]

emb_multi = encode_texts(
    textos,
    normalize=True,
    batch_size=2
)

print(f"Número de textos: {len(textos)}")
print(f"Shape: {emb_multi.shape}")
print(f"Dtype: {emb_multi.dtype}")

assert emb_multi.shape == (5, 384), \
    f"ERROR: se esperaba (5, 384), se obtuvo {emb_multi.shape}"

normas_multi = np.linalg.norm(emb_multi, axis=1)

print("\nNormas L2:")

for i, norma in enumerate(normas_multi):
    print(f"  Texto {i + 1}: {norma:.10f}")

assert np.allclose(normas_multi, 1.0, atol=1e-6), \
    "ERROR: uno o más embeddings no están normalizados."

print("OK — 5 textos producen matriz 5 × 384 normalizada.")


# ----------------------------------------------------------------------
# RESULTADO FINAL
# ----------------------------------------------------------------------

print("\n" + "=" * 70)
print("RESULTADO FINAL")
print("=" * 70)

print("PASS — encode_texts() supera las tres pruebas controladas.")
print("=" * 70)
