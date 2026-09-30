from pathlib import Path
import json
import numpy as np
import pandas as pd
from sklearn.decomposition import PCA


# ============================================================
# CONFIGURACIÓN
# ============================================================

ROOT = Path(__file__).resolve().parents[2]

EMB_DIR = (
    ROOT
    / "data"
    / "processed"
    / "embeddings"
)

R_PCA_DIR = EMB_DIR / "csv" / "pca"

OUT_DIR = (
    EMB_DIR
    / "python"
    / "pca"
)

OUT_DIR.mkdir(parents=True, exist_ok=True)

N_COMPONENTS_OPERATIONAL = 60
RANK_TOL = 1e-12


# ============================================================
# UTILIDADES
# ============================================================

def read_embedding(path: Path) -> np.ndarray:
    df = pd.read_csv(path)

    # Embeddings exportados desde R pueden contener índice.
    # Solo conservamos columnas numéricas correspondientes
    # a las 384 dimensiones.
    numeric = df.select_dtypes(include=[np.number])

    if numeric.shape[1] > 384:
        numeric = numeric.iloc[:, -384:]

    if numeric.shape != (40, 384):
        raise ValueError(
            f"Dimensiones inesperadas en {path}: {numeric.shape}"
        )

    return numeric.to_numpy(dtype=float)


def read_pc_matrix(path: Path) -> np.ndarray:
    df = pd.read_csv(path)

    pc_columns = [
        c for c in df.columns
        if str(c).upper().startswith("PC")
        and str(c)[2:].isdigit()
    ]

    pc_columns = sorted(
        pc_columns,
        key=lambda x: int(str(x)[2:])
    )

    if not pc_columns:
        raise ValueError(f"No se encontraron columnas PC en {path}")

    return df[pc_columns].to_numpy(dtype=float)


# ============================================================
# 1. CARGAR EMBEDDINGS
# ============================================================

print("=" * 70)
print("PCA OPERACIONAL PYTHON")
print("=" * 70)

t1 = read_embedding(
    EMB_DIR / "csv" / "embeddings" / "embeddings_t1.csv"
)

t2 = read_embedding(
    EMB_DIR / "csv" / "embeddings" / "embeddings_t2.csv"
)

t3 = read_embedding(
    EMB_DIR / "csv" / "embeddings" / "embeddings_t3.csv"
)

print(f"T1: {t1.shape}")
print(f"T2: {t2.shape}")
print(f"T3: {t3.shape}")


# ============================================================
# 2. RECONSTRUIR emb_all EXACTAMENTE COMO R
# ============================================================

emb_all = np.vstack([t1, t2, t3])

print(f"emb_all: {emb_all.shape}")

if emb_all.shape != (120, 384):
    raise ValueError(
        f"emb_all inesperado: {emb_all.shape}"
    )


# ============================================================
# 3. CARGAR CENTER / SCALE PRODUCIDOS POR R
# ============================================================

center = pd.read_csv(
    R_PCA_DIR / "pca_embeddings_center.csv"
).iloc[:, -1].to_numpy(dtype=float)

scale = pd.read_csv(
    R_PCA_DIR / "pca_embeddings_scale.csv"
).iloc[:, -1].to_numpy(dtype=float)

if center.shape != (384,):
    raise ValueError(f"center inesperado: {center.shape}")

if scale.shape != (384,):
    raise ValueError(f"scale inesperado: {scale.shape}")


# ============================================================
# 4. ESTANDARIZACIÓN EXACTA
# ============================================================

X_scaled = (emb_all - center) / scale

print(f"X_scaled: {X_scaled.shape}")


# ============================================================
# 5. RANGO NUMÉRICO
# ============================================================

effective_rank = np.linalg.matrix_rank(
    X_scaled,
    tol=RANK_TOL
)

print()
print(f"Rango numérico: {effective_rank}")

if effective_rank != 94:
    raise RuntimeError(
        f"El rango esperado era 94 y se obtuvo {effective_rank}"
    )


# ============================================================
# 6. PCA PYTHON
# ============================================================

pca = PCA(n_components=60)

scores = pca.fit_transform(X_scaled)
loadings = pca.components_.T
sdev = pca.singular_values_ / np.sqrt(X_scaled.shape[0] - 1)

print(f"Scores: {scores.shape}")
print(f"Loadings: {loadings.shape}")
print(f"Sdev: {sdev.shape}")


# ============================================================
# 7. ALINEAR SIGNOS CON PCA DE R
#
# Los signos de una componente PCA son arbitrarios.
# Alineamos cada componente Python con la correspondiente
# componente de R para preservar trazabilidad.
# ============================================================

r_loadings = read_pc_matrix(
    R_PCA_DIR / "pca_embeddings_loadings.csv"
)

r_scores = read_pc_matrix(
    R_PCA_DIR / "pca_embeddings_scores.csv"
)

signs = []

for j in range(N_COMPONENTS_OPERATIONAL):

    correlation = np.dot(
        loadings[:, j],
        r_loadings[:, j]
    )

    sign = 1.0 if correlation >= 0 else -1.0

    loadings[:, j] *= sign
    scores[:, j] *= sign

    signs.append(int(sign))

signs = np.asarray(signs)


# ============================================================
# 8. VARIANZA EXPLICADA
# ============================================================

explained_variance_ratio = (
    pca.explained_variance_ratio_
)

explained_percent = (
    explained_variance_ratio * 100
)

cumulative_percent = np.cumsum(
    explained_percent
)


# ============================================================
# 9. GUARDAR SCORES
# ============================================================

score_df = pd.DataFrame(
    scores,
    columns=[
        f"PC{i}"
        for i in range(1, N_COMPONENTS_OPERATIONAL + 1)
    ]
)

score_df.insert(
    0,
    "row_id",
    np.arange(1, len(score_df) + 1)
)

score_df.to_csv(
    OUT_DIR / "pca_embeddings_pc60_scores.csv",
    index=False
)


# ============================================================
# 10. GUARDAR LOADINGS
# ============================================================

loading_df = pd.DataFrame(
    loadings,
    columns=[
        f"PC{i}"
        for i in range(1, N_COMPONENTS_OPERATIONAL + 1)
    ]
)

loading_df.insert(
    0,
    "embedding_dimension",
    np.arange(1, loadings.shape[0] + 1)
)

loading_df.to_csv(
    OUT_DIR / "pca_embeddings_pc60_loadings.csv",
    index=False
)


# ============================================================
# 11. SDEV
# ============================================================

pd.DataFrame({
    "PC": [
        f"PC{i}"
        for i in range(1, N_COMPONENTS_OPERATIONAL + 1)
    ],
    "sdev": sdev
}).to_csv(
    OUT_DIR / "pca_embeddings_pc60_sdev.csv",
    index=False
)


# ============================================================
# 12. CENTER
# ============================================================

pd.DataFrame({
    "dimension": np.arange(1, 385),
    "center": center
}).to_csv(
    OUT_DIR / "pca_embeddings_pc60_center.csv",
    index=False
)


# ============================================================
# 13. SCALE
# ============================================================

pd.DataFrame({
    "dimension": np.arange(1, 385),
    "scale": scale
}).to_csv(
    OUT_DIR / "pca_embeddings_pc60_scale.csv",
    index=False
)


# ============================================================
# 14. VARIANZA
# ============================================================

pd.DataFrame({
    "PC": [
        f"PC{i}"
        for i in range(1, N_COMPONENTS_OPERATIONAL + 1)
    ],
    "variance_percent": explained_percent,
    "cumulative_percent": cumulative_percent
}).to_csv(
    OUT_DIR / "pca_embeddings_pc60_variance.csv",
    index=False
)


# ============================================================
# 15. METADATA
# ============================================================

metadata = {
    "artifact": "operational_pca_python",
    "created": "2026-09-07",
    "source": {
        "language": "R",
        "pca_source": "data/processed/embeddings/csv/pca/pca_embeddings_*.csv",
        "embedding_source": "data/processed/embeddings/csv/embeddings/"
    },
    "construction": {
        "matrix": "vstack(T1, T2, T3)",
        "n_rows": 120,
        "n_dimensions": 384,
        "center": "R pca_embeddings_center.csv",
        "scale": "R pca_embeddings_scale.csv",
        "algorithm": "sklearn.decomposition.PCA",
        "sign_alignment": "aligned to R loadings"
    },
    "rank": {
        "effective_rank": int(effective_rank),
        "rank_tolerance": RANK_TOL,
        "informative_components": "PC1-PC94",
        "numerically_null_components": "PC95-PC120"
    },
    "operational_selection": {
        "components_retained": "PC1-PC60",
        "n_components": 60,
        "cumulative_variance_percent": float(cumulative_percent[-1])
    },
    "variance_reference": {
        "PC8": 50.8594,
        "PC15": 70.0,
        "PC21": 78.7197,
        "PC31": 89.5191,
        "PC41": 95.0,
        "PC60": 99.0474,
        "PC94": 100.0
    },
    "provenance": {
        "original_r_pca_preserved": True,
        "r_pca_modified": False,
        "derived_artifact": True
    }
}

with open(
    OUT_DIR / "metadata.json",
    "w",
    encoding="utf-8"
) as f:
    json.dump(
        metadata,
        f,
        indent=2,
        ensure_ascii=False
    )


# ============================================================
# 16. RESUMEN
# ============================================================

print()
print("=" * 70)
print("RESULTADO")
print("=" * 70)

print(f"Rango numérico:       {effective_rank}")
print(f"Componentes guardadas: {N_COMPONENTS_OPERATIONAL}")
print(
    f"Varianza acumulada:    "
    f"{cumulative_percent[-1]:.4f}%"
)

print()
print("Artefactos generados:")
for path in sorted(OUT_DIR.iterdir()):
    print(f"  {path.name}")

print()
print("OK PCA operacional Python creada.")
