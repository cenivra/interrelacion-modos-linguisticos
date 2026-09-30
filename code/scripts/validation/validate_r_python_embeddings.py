from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.decomposition import PCA


# ============================================================
# CONFIGURACIÓN
# ============================================================

ROOT = Path(__file__).resolve().parents[2]

EMB_DIR = ROOT / "data" / "processed" / "embeddings"
CSV_DIR = EMB_DIR / "csv"
R_PCA_DIR = CSV_DIR / "pca"
PY_PCA_DIR = EMB_DIR / "python" / "pca"

RANK_TOL = 1e-12
COMPONENT_TOL = 1e-10
OPERATIONAL_COMPONENTS = 60


# ============================================================
# UTILIDADES
# ============================================================

def read_matrix(path: Path) -> np.ndarray:
    if not path.exists():
        raise FileNotFoundError(f"No existe: {path}")

    df = pd.read_csv(path)

    pc_columns = [
        column
        for column in df.columns
        if str(column).upper().startswith("PC")
        and str(column)[2:].isdigit()
    ]

    if pc_columns:
        pc_columns = sorted(
            pc_columns,
            key=lambda x: int(str(x)[2:])
        )
        return df[pc_columns].to_numpy(dtype=float)

    return df.to_numpy(dtype=float)


def read_vector(path: Path) -> np.ndarray:
    if not path.exists():
        raise FileNotFoundError(f"No existe: {path}")

    df = pd.read_csv(path)

    numeric = df.select_dtypes(include=[np.number])

    if numeric.shape[1] == 0:
        raise ValueError(f"No hay columnas numéricas en {path}")

    return numeric.iloc[:, -1].to_numpy(dtype=float)


def check_close(name, actual, expected, atol=COMPONENT_TOL):
    diff = np.max(np.abs(actual - expected))

    if diff <= atol:
        print(f"OK {name} max_abs_diff={diff:.3e}")
        return True

    print(f"FAIL {name} max_abs_diff={diff:.3e}")
    return False


# ============================================================
# RESULTADOS
# ============================================================

all_ok = True

print("=" * 70)
print("VALIDACIÓN R → PYTHON: EMBEDDINGS Y PCA")
print("=" * 70)


# ============================================================
# 1. EMBEDDINGS
# ============================================================

print()
print("1. CARGA Y ESTRUCTURA DE EMBEDDINGS")
print("-" * 70)

t1 = read_matrix(
    CSV_DIR / "embeddings" / "embeddings_t1.csv"
)

t2 = read_matrix(
    CSV_DIR / "embeddings" / "embeddings_t2.csv"
)

t3 = read_matrix(
    CSV_DIR / "embeddings" / "embeddings_t3.csv"
)

for name, matrix in [("T1", t1), ("T2", t2), ("T3", t3)]:
    if matrix.shape == (40, 384):
        print(f"OK {name} {matrix.shape}")
    else:
        print(f"FAIL {name} {matrix.shape}")
        all_ok = False


# ============================================================
# 2. CHECKSUMS
# ============================================================

print()
print("2. CHECKSUMS NUMÉRICOS")
print("-" * 70)

expected = {
    "T1_sum": 0.9317055,
    "T2_sum": 0.6700813,
    "T3_sum": 0.5650851,
    "T1_mean": 6.065791e-05,
    "T2_mean": 4.362508e-05,
    "T3_mean": 3.678939e-05,
    "T1_sd": 0.05103266,
    "T2_sd": 0.05103268,
    "T3_sd": 0.05103268,
}

actual = {
    "T1_sum": np.sum(t1),
    "T2_sum": np.sum(t2),
    "T3_sum": np.sum(t3),
    "T1_mean": np.mean(t1),
    "T2_mean": np.mean(t2),
    "T3_mean": np.mean(t3),
    "T1_sd": np.std(t1, ddof=1),
    "T2_sd": np.std(t2, ddof=1),
    "T3_sd": np.std(t3, ddof=1),
}

for key in expected:
    diff = abs(actual[key] - expected[key])

    if diff <= 1e-7:
        print(
            f"OK {key} "
            f"Python={actual[key]:.12g} "
            f"R={expected[key]:.12g}"
        )
    else:
        print(
            f"FAIL {key} "
            f"Python={actual[key]:.12g} "
            f"R={expected[key]:.12g}"
        )
        all_ok = False


# ============================================================
# 3. PROTOTIPOS
# ============================================================

print()
print("3. PROTOTIPOS SEMÁNTICOS")
print("-" * 70)

proto_path = (
    CSV_DIR
    / "semantic_prototypes"
    / "prototipos_semanticos.csv"
)

proto = pd.read_csv(proto_path)

numeric_proto = proto.select_dtypes(include=[np.number])

if numeric_proto.shape == (20, 384):
    print(f"OK Prototipos {numeric_proto.shape}")
else:
    print(f"FAIL Prototipos {numeric_proto.shape}")
    all_ok = False


# ============================================================
# 4. PCA R
# ============================================================

print()
print("4. PCA EXPORTADO DESDE R")
print("-" * 70)

r_scores = read_matrix(
    R_PCA_DIR / "pca_embeddings_scores.csv"
)

r_rotation = read_matrix(
    R_PCA_DIR / "pca_embeddings_loadings.csv"
)

r_sdev = read_vector(
    R_PCA_DIR / "pca_embeddings_sdev.csv"
)

r_center = read_vector(
    R_PCA_DIR / "pca_embeddings_center.csv"
)

r_scale = read_vector(
    R_PCA_DIR / "pca_embeddings_scale.csv"
)

print(f"R scores:    {r_scores.shape}")
print(f"R rotation:  {r_rotation.shape}")
print(f"R sdev:      {r_sdev.shape}")
print(f"R center:    {r_center.shape}")
print(f"R scale:     {r_scale.shape}")

if r_scores.shape != (120, 120):
    all_ok = False

if r_rotation.shape != (384, 120):
    all_ok = False

if r_sdev.shape != (120,):
    all_ok = False


# ============================================================
# 5. RECONSTRUCCIÓN emb_all
# ============================================================

print()
print("5. RECONSTRUCCIÓN DE emb_all")
print("-" * 70)

emb_all = np.vstack([t1, t2, t3])

if emb_all.shape == (120, 384):
    print("OK emb_all (120,384)")
    print("Order: 1-40 T1, 41-80 T2, 81-120 T3")
else:
    print(f"FAIL emb_all {emb_all.shape}")
    all_ok = False


# ============================================================
# 6. CENTER / SCALE
# ============================================================

print()
print("6. CENTER / SCALE")
print("-" * 70)

if (
    r_center.shape == (384,)
    and r_scale.shape == (384,)
):
    X_scaled = (
        emb_all - r_center
    ) / r_scale

    print("OK estandarización reproducida usando center/scale de R")
else:
    raise RuntimeError("Center/scale inválidos")


# ============================================================
# 7. RANGO NUMÉRICO
# ============================================================

print()
print("7. RANGO NUMÉRICO")
print("-" * 70)

python_rank = np.linalg.matrix_rank(
    X_scaled,
    tol=RANK_TOL
)

r_rank = np.sum(
    r_sdev > RANK_TOL
)

print(f"Rango Python: {python_rank}")
print(f"Rango R:      {r_rank}")

if python_rank == 94 and r_rank == 94:
    print("OK rango numérico = 94")
else:
    print("FAIL rango numérico")
    all_ok = False


# ============================================================
# 8. PCA PYTHON COMPLETA
# ============================================================

print()
print("8. PCA PYTHON")
print("-" * 70)

pca = PCA(n_components=120)

py_scores = pca.fit_transform(X_scaled)

py_rotation = pca.components_.T

py_sdev = (
    pca.singular_values_
    / np.sqrt(X_scaled.shape[0] - 1)
)

print(f"Python scores:   {py_scores.shape}")
print(f"Python rotation: {py_rotation.shape}")
print(f"Python sdev:     {py_sdev.shape}")


# ============================================================
# 9. VARIANZA EXPLICADA
# ============================================================

print()
print("9. VARIANZA EXPLICADA")
print("-" * 70)

r_var = (
    r_sdev ** 2
    / np.sum(r_sdev ** 2)
)

py_var = pca.explained_variance_ratio_

var_diff = np.max(
    np.abs(r_var - py_var)
)

if var_diff <= 1e-12:
    print(
        f"OK max_abs_diff={var_diff:.3e}"
    )
else:
    print(
        f"FAIL max_abs_diff={var_diff:.3e}"
    )
    all_ok = False

for i in range(5):
    print(
        f"PC{i+1} "
        f"R={r_var[i]*100:.9f} "
        f"Python={py_var[i]*100:.9f}"
    )


# ============================================================
# 10. SDEV
# ============================================================

print()
print("10. SDEV")
print("-" * 70)

sdev_diff = np.max(
    np.abs(r_sdev - py_sdev)
)

if sdev_diff <= 1e-12:
    print(
        f"OK max_abs_diff={sdev_diff:.3e}"
    )
else:
    print(
        f"FAIL max_abs_diff={sdev_diff:.3e}"
    )
    all_ok = False


# ============================================================
# 11. EQUIVALENCIA PCA
# ============================================================

print()
print("=" * 70)
print("11. EQUIVALENCIA PCA")
print("=" * 70)

EFFECTIVE_RANK = 94

r_loadings_informative = r_rotation[:, :EFFECTIVE_RANK]
py_loadings_informative = py_rotation[:, :EFFECTIVE_RANK]

r_scores_informative = r_scores[:, :EFFECTIVE_RANK]
py_scores_informative = py_scores[:, :EFFECTIVE_RANK]


# ------------------------------------------------------------
# ALINEACIÓN DE SIGNOS
# ------------------------------------------------------------

signs = np.ones(EFFECTIVE_RANK)

for j in range(EFFECTIVE_RANK):

    dot = np.dot(
        py_loadings_informative[:, j],
        r_loadings_informative[:, j]
    )

    if dot < 0:
        signs[j] = -1

        py_loadings_informative[:, j] *= -1
        py_scores_informative[:, j] *= -1


n_inverted = np.sum(signs < 0)

print(
    f"Componentes con signo invertido: "
    f"{n_inverted} / {EFFECTIVE_RANK}"
)


# ------------------------------------------------------------
# ROTATION
# ------------------------------------------------------------

rotation_diff = np.max(
    np.abs(
        r_loadings_informative
        - py_loadings_informative
    )
)

if rotation_diff <= COMPONENT_TOL:
    print(
        f"OK rotation PC1-PC94 "
        f"max_abs_diff={rotation_diff:.3e}"
    )
else:
    print(
        f"FAIL rotation PC1-PC94 "
        f"max_abs_diff={rotation_diff:.3e}"
    )
    all_ok = False


# ------------------------------------------------------------
# SCORES
# ------------------------------------------------------------

scores_diff = np.max(
    np.abs(
        r_scores_informative
        - py_scores_informative
    )
)

if scores_diff <= COMPONENT_TOL:
    print(
        f"OK scores PC1-PC94 "
        f"max_abs_diff={scores_diff:.3e}"
    )
else:
    print(
        f"FAIL scores PC1-PC94 "
        f"max_abs_diff={scores_diff:.3e}"
    )
    all_ok = False


# ============================================================
# 12. COMPONENTES NULAS
# ============================================================

print()
print("12. COMPONENTES PC95-PC120")
print("-" * 70)

null_sdev = r_sdev[EFFECTIVE_RANK:]

max_null_sdev = np.max(
    np.abs(null_sdev)
)

null_variance = np.sum(
    null_sdev ** 2
)

total_variance = np.sum(
    r_sdev ** 2
)

relative_null_variance = (
    null_variance / total_variance
)

print(
    f"PC95-PC120 sdev máximo: "
    f"{max_null_sdev:.3e}"
)

print(
    f"Varianza relativa PC95-PC120: "
    f"{relative_null_variance:.3e}"
)

if max_null_sdev <= RANK_TOL:
    print(
        "INFO componentes numéricamente nulos"
    )
else:
    print(
        "INFO componentes posteriores al rango efectivo"
    )

print(
    "INFO no se exige equivalencia vectorial individual "
    "para PC95-PC120"
)


# ============================================================
# 13. PCA OPERACIONAL PC1-PC60
# ============================================================

print()
print("13. PCA OPERACIONAL PC1-PC60")
print("-" * 70)

operational_scores = (
    PY_PCA_DIR
    / "pca_embeddings_pc60_scores.csv"
)

operational_loadings = (
    PY_PCA_DIR
    / "pca_embeddings_pc60_loadings.csv"
)

operational_variance = (
    PY_PCA_DIR
    / "pca_embeddings_pc60_variance.csv"
)

metadata = (
    PY_PCA_DIR
    / "metadata.json"
)

required_files = [
    operational_scores,
    operational_loadings,
    operational_variance,
    metadata,
]

for path in required_files:

    if path.exists():
        print(f"OK {path.name}")
    else:
        print(f"FAIL falta {path.name}")
        all_ok = False


if operational_scores.exists():

    op_scores = read_matrix(
        operational_scores
    )

    if op_scores.shape == (120, 60):
        print(
            "OK scores operacionales (120,60)"
        )
    else:
        print(
            f"FAIL scores operacionales "
            f"{op_scores.shape}"
        )
        all_ok = False


if operational_loadings.exists():

    op_loadings = read_matrix(
        operational_loadings
    )

    if op_loadings.shape == (384, 60):
        print(
            "OK loadings operacionales (384,60)"
        )
    else:
        print(
            f"FAIL loadings operacionales "
            f"{op_loadings.shape}"
        )
        all_ok = False


if operational_variance.exists():

    op_variance = pd.read_csv(
        operational_variance
    )

    final_variance = float(
        op_variance.iloc[-1]["cumulative_percent"]
    )

    print(
        f"Varianza acumulada PC60: "
        f"{final_variance:.6f}%"
    )

    if abs(final_variance - 99.0474073656) <= 1e-9:
        print(
            "OK PC1-PC60 conserva "
            "99.0474% de varianza"
        )
    else:
        print(
            "FAIL varianza acumulada PC60"
        )
        all_ok = False


# ============================================================
# RESULTADO FINAL
# ============================================================

print()
print("=" * 70)
print("RESULTADO FINAL")
print("=" * 70)

if all_ok:

    print()
    print(
        "PASS — equivalencia R → Python validada "
        "para el rango numéricamente identificable "
        "(PC1-PC94)."
    )

    print()
    print(
        "PASS — PCA operacional PC1-PC60 validada."
    )

    print()
    print(
        "INFO — PC95-PC120 clasificados como "
        "componentes numéricamente nulos."
    )

    print()
    print(
        "INFO — PCA R original preservada como "
        "fuente de verdad."
    )

else:

    print()
    print(
        "FAIL — revisar las discrepancias anteriores."
    )

    raise SystemExit(1)

