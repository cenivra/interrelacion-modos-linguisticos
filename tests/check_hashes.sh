# ============================================================================
# Verificación de integridad del repositorio
#
# Uso:
#   bash tests/check_hashes.sh
#   bash tests/check_hashes.sh ruta/al/manifiesto.txt
#
# El script comprueba:
#   1. Presencia de posibles microdatos entre los archivos versionados.
#   2. Ausencia de narrativas extensas en CSV/XLSX versionados.
#   3. Correspondencia EXACTA entre el manifiesto y los archivos versionados.
#   4. Integridad SHA-256 según la regla canónica del repositorio.
#   5. Estructura de los CSV relevantes.
#   6. Presencia de los artefactos mínimos del repositorio.
#
# La regla de hashing debe coincidir exactamente con:
#   scripts/validation/generate_repo_manifest.py
#
# Regla de huella:
#   - binarios -> SHA-256 de los bytes originales;
#   - texto    -> SHA-256 con CRLF normalizado a LF.
# ============================================================================

set -uo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: no se pudo localizar la raíz del repositorio Git."
    exit 1
}

MANIFEST="${1:-manifests/SHA256_REPO.txt}"
FALLOS=0

# ----------------------------------------------------------------------------
# Dependencias obligatorias
# ----------------------------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: Git no está disponible."
    exit 1
fi

PYTHON=""
for CANDIDATO in python3 python py; do
    if command -v "$CANDIDATO" >/dev/null 2>&1; then
        PYTHON="$CANDIDATO"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python es necesario para las comprobaciones de integridad."
    exit 1
fi

# ----------------------------------------------------------------------------
# 1. Archivos versionados potencialmente incompatibles con la política
# ----------------------------------------------------------------------------

echo "== 1. Control de archivos potencialmente sensibles =="

SOSPECHOSOS="$(
    {
        git ls-files | grep -Ei \
            'ancho_.*completo|_longitudinal\.csv|identificacion\.csv|scores_diccionarios|Vaciado|Datos Exp|datos_experimento|piloto_interrelacion|datos_completos_ancho|datos_formato_largo|\.RData' \
            || true

        git ls-files | grep -Ei '\.(xlsx|xls|xlsm)$' \
            | grep -v '^results/' \
            || true
    } | sort -u
)"

if [ -n "$SOSPECHOSOS" ]; then
    echo "   REVISAR: se detectaron archivos que podrían corresponder a microdatos:"
    printf '%s\n' "$SOSPECHOSOS" | sed 's/^/     /'
    FALLOS=$((FALLOS + 1))
else
    echo "   OK: no se detectaron archivos potencialmente sensibles."
fi

# ----------------------------------------------------------------------------
# 2–5. Comprobaciones estructurales y numéricas en Python
# ----------------------------------------------------------------------------

echo
echo "== 2–5. Integridad de contenido, manifiesto y CSV =="

"$PYTHON" - "$MANIFEST" <<'PYEOF'
from __future__ import annotations

import csv
import hashlib
import os
import subprocess
import sys
from pathlib import Path
import zipfile
import re


MANIFEST = Path(sys.argv[1])

BINARIAS = (
    ".rds",
    ".png",
    ".pdf",
    ".jpg",
    ".jpeg",
    ".gif",
    ".xlsx",
    ".xls",
    ".zip",
    ".gz",
    ".rda",
    ".rdata",
)


def git_files() -> list[str]:
    """Obtiene exactamente las rutas versionadas por Git."""
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return [
        os.fsdecode(p)
        for p in result.stdout.split(b"\0")
        if p
    ]


def hash_file(path: Path) -> str:
    """Aplica la regla canónica de hash del proyecto."""
    data = path.read_bytes()

    if not path.name.lower().endswith(BINARIAS):
        data = data.replace(b"\r\n", b"\n")

    return hashlib.sha256(data).hexdigest()


def scan_csv(path: Path, threshold: int = 200) -> tuple[bool, str | None]:
    """Busca cadenas largas y errores de estructura CSV."""
    try:
        with path.open(
            newline="",
            encoding="utf-8-sig",
            errors="replace",
        ) as fh:
            reader = csv.reader(fh)
            rows = list(reader)
    except Exception as exc:
        return False, f"no se pudo leer: {exc}"

    if not rows:
        return False, "archivo vacío"

    width = len(rows[0])

    for row_number, row in enumerate(rows[1:], 2):
        if len(row) != width:
            return False, (
                f"fila {row_number} con {len(row)} campos; "
                f"encabezado con {width}"
            )

        if any(len(cell) > threshold for cell in row):
            return False, (
                f"fila {row_number} contiene una celda "
                f"superior a {threshold} caracteres"
            )

    return True, None


def scan_xlsx(path: Path, threshold: int = 200) -> tuple[bool, str | None]:
    """
    Inspección básica de XLSX/XLSM.

    Se revisan los nodos de texto XML contenidos en el paquete OOXML.
    Los archivos XLS binarios no se interpretan aquí y permanecen sujetos
    a las reglas de clasificación y hashing.
    """
    try:
        with zipfile.ZipFile(path) as z:
            count = 0

            for member in z.namelist():
                if not member.endswith(".xml"):
                    continue

                text = z.read(member).decode("utf-8", "replace")

                for value in re.findall(
                    r"<t[^>]*>(.*?)</t>",
                    text,
                    flags=re.DOTALL,
                ):
                    if len(value) > threshold:
                        count += 1

            if count:
                return False, f"{count} cadenas superiores a {threshold} caracteres"

    except Exception as exc:
        return False, f"no se pudo inspeccionar: {exc}"

    return True, None


# ============================================================================
# Lista versionada
# ============================================================================

tracked = sorted(git_files())
tracked_set = set(tracked)

print(f"   Archivos versionados por Git: {len(tracked)}")


# ============================================================================
# 2. Contenido CSV / XLSX
# ============================================================================

csv_files = [
    f for f in tracked
    if f.lower().endswith((".csv", ".tsv"))
]

xlsx_files = [
    f for f in tracked
    if f.lower().endswith((".xlsx", ".xlsm"))
]

content_failures = []

for filename in csv_files:
    ok, reason = scan_csv(Path(filename))
    if not ok:
        content_failures.append((filename, reason))


for filename in xlsx_files:
    ok, reason = scan_xlsx(Path(filename))
    if not ok:
        content_failures.append((filename, reason))


if content_failures:
    print("   REVISAR: archivos con problemas de contenido:")
    for filename, reason in content_failures:
        print(f"     {filename} -> {reason}")
    content_status = False
else:
    print(
        f"   OK: {len(csv_files)} CSV/TSV y "
        f"{len(xlsx_files)} XLSX/XLSM revisados."
    )
    content_status = True


# ============================================================================
# 3–4. Verificación del manifiesto
# ============================================================================

manifest_status = True

if not MANIFEST.is_file():
    print(f"   ERROR: no existe el manifiesto: {MANIFEST}")
    manifest_status = False
else:
    entries: dict[str, str] = {}
    malformed = []
    duplicates = []

    with MANIFEST.open(
        encoding="utf-8",
        errors="replace",
    ) as fh:
        for raw in fh:
            line = raw.rstrip("\r\n")

            if not line.strip():
                continue

            parts = line.split(None, 1)

            if len(parts) != 2:
                malformed.append(line)
                continue

            digest, path_text = parts

            if path_text.startswith("*"):
                path_text = path_text[1:]

            if not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
                malformed.append(line)
                continue

            if path_text in entries:
                duplicates.append(path_text)

            entries[path_text] = digest.lower()

    manifest_set = set(entries)

    # ------------------------------------------------------------------------
    # Completitud respecto de Git
    # ------------------------------------------------------------------------

    # En Windows str(Path(...)) usa barras invertidas y Git usa barras
    # normales: se comparan las dos formas para excluir el propio manifiesto.
    missing_from_manifest = sorted(
        tracked_set - manifest_set
        - {str(MANIFEST), Path(MANIFEST).as_posix()}
    )

    extra_in_manifest = sorted(
        manifest_set - tracked_set
    )

    if malformed:
        print(
            f"   ERROR: {len(malformed)} líneas del manifiesto "
            f"tienen formato inválido."
        )
        manifest_status = False

    if duplicates:
        print(
            f"   ERROR: {len(duplicates)} rutas aparecen duplicadas "
            f"en el manifiesto."
        )
        manifest_status = False

    if missing_from_manifest:
        print(
            f"   ERROR: {len(missing_from_manifest)} archivos versionados "
            f"no aparecen en el manifiesto:"
        )
        for filename in missing_from_manifest[:20]:
            print(f"     - {filename}")
        manifest_status = False

    if extra_in_manifest:
        print(
            f"   ERROR: {len(extra_in_manifest)} rutas aparecen en el "
            f"manifiesto pero no están versionadas:"
        )
        for filename in extra_in_manifest[:20]:
            print(f"     - {filename}")
        manifest_status = False

    # ------------------------------------------------------------------------
    # Integridad de cada entrada
    # ------------------------------------------------------------------------

    discrepancies = []

    for filename, expected_hash in entries.items():
        path = Path(filename)

        if not path.is_file():
            discrepancies.append((filename, "no existe en el árbol de trabajo"))
            continue

        observed_hash = hash_file(path)

        if observed_hash != expected_hash:
            discrepancies.append((filename, "hash distinto"))

    if discrepancies:
        print(
            f"   ERROR: {len(discrepancies)} discrepancias "
            f"de integridad."
        )

        for filename, reason in discrepancies[:20]:
            print(f"     {filename} -> {reason}")

        manifest_status = False
    else:
        print(
            f"   OK: {len(entries)} entradas del manifiesto "
            f"verificadas, sin discrepancias."
        )


# ============================================================================
# Resultado Python
# ============================================================================

python_failures = 0

if not content_status:
    python_failures += 1

if not manifest_status:
    python_failures += 1

sys.exit(python_failures)
PYEOF

[ $? -ne 0 ] && FALLOS=$((FALLOS + 1))

# ----------------------------------------------------------------------------
# 6. Estructura mínima del repositorio
# ----------------------------------------------------------------------------

echo
echo "== 6. Artefactos mínimos del repositorio =="

# Los manuscritos de resultados (piloto, principal y combinado) NO se versionan:
# el autor principal los envía a una revista, y no deben estar en un repositorio
# antes de su publicación. Viven únicamente en la copia de trabajo local.
esperados=(
    "results/piloto/INFORME_PILOTO.md"
    "results/principal/INFORME_PRINCIPAL.md"
    "docs/resultados_integrados.md"
    "manifests/INVENTARIO_RESULTADOS.csv"
    "results/corrida_2026-09-29/INFORME_2026-09-29.md"
    "results/corrida_2026-09-29/figuras/PANEL_resultados_nuevos.png"
    "results/corrida_2026-09-29/tablas/B2_decision_posterior.csv"
    "code/analisis_nuevos/robustez_y_bayesiano.R"
)

# Rutas que NO deben existir en el repositorio por decisión editorial.
prohibidos=(
    "results/piloto/manuscrito/resultados_piloto.tex"
    "results/piloto/manuscrito/resultados_piloto.pdf"
    "results/principal/manuscrito/resultados_principal.tex"
    "results/principal/manuscrito/resultados_principal.pdf"
    "results/combinado/manuscrito/resultados_combinado.tex"
    "results/combinado/manuscrito/resultados_combinado.pdf"
)

presentes=()

for archivo in "${prohibidos[@]}"; do
    if [ -f "$archivo" ]; then
        presentes+=("$archivo")
    fi
done

if [ "${#presentes[@]}" -gt 0 ]; then
    echo "   ERROR: ${#presentes[@]} manuscritos no deben estar en el repositorio (van a revista):"
    for archivo in "${presentes[@]}"; do
        echo "     - $archivo"
    done
    FALLOS=$((FALLOS + 1))
fi

faltan=()

for archivo in "${esperados[@]}"; do
    if [ ! -f "$archivo" ]; then
        faltan+=("$archivo")
    fi
done

if [ "${#faltan[@]}" -gt 0 ]; then
    echo "   REVISAR: faltan ${#faltan[@]} artefactos requeridos:"
    for archivo in "${faltan[@]}"; do
        echo "     - $archivo"
    done
    FALLOS=$((FALLOS + 1))
else
    echo "   OK: los ${#esperados[@]} artefactos mínimos están presentes."
fi

FIGURAS=$(find results/figuras -maxdepth 1 -type f -name '*.png' 2>/dev/null | wc -l)

echo "   Figuras PNG en results/figuras/: $FIGURAS"

if [ "$FIGURAS" -lt 15 ]; then
    echo "   REVISAR: se esperan al menos 15 figuras PNG."
    FALLOS=$((FALLOS + 1))
else
    echo "   OK: número de figuras compatible con el pipeline."
fi

# ----------------------------------------------------------------------------
# Resultado final
# ----------------------------------------------------------------------------

echo
if [ "$FALLOS" -eq 0 ]; then
    echo "======================================================================"
    echo "RESULTADO: PASS — integridad del repositorio verificada"
    echo "======================================================================"
else
    echo "======================================================================"
    echo "RESULTADO: FAIL — $FALLOS comprobación(es) con problemas"
    echo "======================================================================"
fi

exit "$FALLOS"
```
