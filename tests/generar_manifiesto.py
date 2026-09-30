"""
Genera manifests/SHA256_REPO.txt a partir de los archivos versionados por Git.

Regla de huella:
  - archivos binarios: SHA-256 de los bytes tal cual;
  - archivos de texto: SHA-256 del contenido con finales de línea
    normalizados a LF.

La regla debe coincidir exactamente con tests/check_hashes.sh.

El propio manifiesto se excluye de la huella porque no puede contener
consigo mismo de forma estable.
"""

from __future__ import annotations

import hashlib
import os
import subprocess
from pathlib import Path


MANIFEST_REL = Path("manifests/SHA256_REPO.txt")

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


def ejecutar_git(*args: str) -> bytes:
    """Ejecuta un comando Git y devuelve stdout como bytes."""
    resultado = subprocess.run(
        ["git", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return resultado.stdout


def obtener_raiz_repo() -> Path:
    """Obtiene la raíz del repositorio Git."""
    salida = ejecutar_git("rev-parse", "--show-toplevel")
    return Path(os.fsdecode(salida.rstrip(b"\r\n"))).resolve()


def listar_archivos_versionados() -> list[str]:
    """
    Obtiene las rutas versionadas por Git.

    Se utiliza -z para que incluso nombres de archivo con espacios,
    tabulaciones o saltos de línea puedan procesarse sin ambigüedad.
    """
    salida = ejecutar_git("ls-files", "-z")

    archivos: list[str] = []

    for ruta_bytes in salida.split(b"\0"):
        if not ruta_bytes:
            continue

        ruta = os.fsdecode(ruta_bytes)

        if Path(ruta) != MANIFEST_REL:
            archivos.append(ruta)

    return sorted(archivos)


def huella(ruta: Path) -> str:
    """
    Calcula el SHA-256 según la regla de normalización del proyecto.

    Los archivos binarios conservan sus bytes originales.
    Los archivos de texto convierten CRLF a LF.
    """
    datos = ruta.read_bytes()

    if not ruta.name.lower().endswith(BINARIAS):
        datos = datos.replace(b"\r\n", b"\n")

    return hashlib.sha256(datos).hexdigest()


def main() -> int:
    """Genera el manifiesto de integridad del repositorio."""
    repo_root = obtener_raiz_repo()
    os.chdir(repo_root)

    manifest = repo_root / MANIFEST_REL
    manifest.parent.mkdir(parents=True, exist_ok=True)

    archivos = listar_archivos_versionados()

    lineas: list[str] = []
    faltantes: list[str] = []

    for ruta_rel in archivos:
        ruta = repo_root / ruta_rel

        if not ruta.is_file():
            faltantes.append(ruta_rel)
            continue

        lineas.append(f"{huella(ruta)} *{ruta_rel}")

    if faltantes:
        print("ERROR: existen archivos versionados ausentes del árbol de trabajo:")
        for ruta in faltantes:
            print(f"   - {ruta}")

        print(
            f"\nNo se generó el manifiesto. "
            f"Archivos ausentes: {len(faltantes)}"
        )
        return 1

    contenido = "\n".join(lineas) + "\n"

    manifest.write_text(
        contenido,
        encoding="utf-8",
        newline="\n",
    )

    print(
        f"   manifiesto escrito: {len(lineas)} archivos -> "
        f"{MANIFEST_REL.as_posix()}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
