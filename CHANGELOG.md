# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Verisoning](https://semver.org/spec/v2.0.0.html).

## [2.1.1] - 2026-09-29

### Los manuscritos de resultados salen del repositorio

El autor principal enviará los manuscritos de piloto, principal y combinado a una revista, por lo que
**no se versionan** en este repositorio. Se retiraron de la lista de artefactos mínimos y se agregó una
comprobación que falla si alguno reaparece en el árbol.

- Los manuscritos siguen en la copia de trabajo local (`resultados en latex/`), no en Git.
- La comprobación 6 ahora exige los artefactos que sí permanecen: los informes de piloto y principal, la
  documentación integrada, el inventario de resultados, y el informe, la figura y la tabla principales de
  la corrida del 2026-09-29, además del guion de robustez.

## [2.1.0] - 2026-09-29

### Robustez, capa bayesiana y familias nuevas — corrida principal (23 participantes)

Corrida del **29 de septiembre de 2026, 17:37:59 a 18:45:44** (hora del centro de México, UTC−6). No modifica
la corrida original ni sus cifras: lee sus artefactos y agrega comprobaciones. El guion verificado
`Experimento ALC_v5_corregido.R` (v5.9) permanece intacto.

- `results/corrida_2026-09-29/` — informe con la hora de cada bloque, 10 figuras, 21 tablas, 5 registros con
  marca de tiempo y los resúmenes en lenguaje llano; incluye la cohorte piloto.
- `code/analisis_nuevos/` — seis guiones de análisis (robustez y capa bayesiana, familias nuevas derivadas del
  artículo, comparación de verosimilitudes, t de Student corregida, figuras y segundo modelo de embeddings) y
  los dos generadores de entregables.

#### Resultados

| Bloque | Resultado |
| --- | --- |
| Robustez | Influencia por participante 43.1–57.9 (ninguna persona sostiene el efecto); **MATTR p = .049** frente al descenso del TTR, que es efecto de la longitud; sólo `soledad` sobrevive a FDR (**p FDR = .029**); bootstrap [24.2, 80.0] palabras |
| Capa bayesiana | Crecimiento T1→T3 **80 palabras, IC 95 % [54.9, 111.1]** → cambio sustancial; Audio − Texto 22.9 [−43.9, 88.5] → **no concluyente**; el modelo sin modalidad predice mejor por LOO; potencia con n=28 para 20 palabras = 0.10 |
| Familias nuevas | Cuatro diccionarios de modo (94 términos) sin efecto de tiempo; **elaboración entre textos 0.579 → 0.680** con contenido nuevo 0.421 → 0.320 |
| Familias estadísticas | Crecimiento entre 71 y 80 palabras y contraste entre modos no concluyente en las cuatro verosimilitudes; lognormal ≈ gamma por LOO |
| Instrumentos | TF-IDF, MiniLM y MPNet coinciden en el orden de similitud (correlación 0.97 entre los dos modelos de embeddings) |

## [2.0.0] - 2026-09-25

### Reinicio del historial del repositorio

El historial anterior conservaba, en commits del 2026-09-07, dos objetos con narrativas de
participantes —`data/processed/piloto/ancho_piloto_base.rds` y
`data/processed/piloto/ancho_piloto_procesado.rds`— que seguían siendo recuperables aunque ya no
estuvieran en el árbol: borrarlos en un commit posterior no los borra del pasado. Se sustituyó
**todo** el historial por un único commit con el estado actual verificado.

- `main` contiene **un solo commit** con los 288 archivos del estado consolidado. Se eliminaron
  del remoto la rama `zarakaeldiosdelcaos-byte-patch-1` y, en el clon local, la etiqueta
  `backup-interrelacion-2026-09-24` y las ramas de respaldo, que mantenían vivo el historial
  antiguo; después se descartaron los objetos con `git gc --prune=now`.
- Comprobación ruta por ruta: ninguno de los tres archivos sensibles aparece en commit alguno
  (`ancho_piloto_base.rds`, `ancho_piloto_procesado.rds` y `nrc_es.rds`: 0 coincidencias).
- Respaldo del historial anterior, fuera del repositorio:
  `C:\Users\saraq\Documents\respaldo-experimento-nlp-20260925.bundle`.
- Se añade `.gitattributes` con `* text=auto eol=lf`: las huellas del manifiesto son idénticas
  en cualquier sistema, y `tests/check_hashes.sh` tolera CRLF al leer el manifiesto.
- El léxico NRC queda fuera del repositorio (`data/raw/lexicons/*.rds`), como ya se había
  decidido; los artefactos numéricos agregados (embeddings, PCA, prototipos, modelos) se
  conservan.

## [1.3.0] - 2026-09-25

### Manuscritos de resultados por cohorte (piloto, principal y combinado)

Se incorporan los tres documentos de resultados redactados a partir de la corrida verificada del
pipeline (v5.9, SHA-256 `1143b36a…`) y del borrador de resultados del autor. Cada uno vive en la
carpeta de su cohorte, en `results/<cohorte>/manuscrito/`, con las figuras que cita en
`manuscrito/figuras/` (paquete autocontenido: compila con dos pasadas de `pdflatex`).

- `results/piloto/manuscrito/resultados_piloto.{tex,pdf,md}` — 17 páginas, 4 figuras. Solo la cohorte
  piloto (n = 17): el efecto de tiempo **no** es significativo (F(2,28) = 1.845, p = .177) y la
  interacción condición × tiempo sí lo es (p = .016).
- `results/principal/manuscrito/resultados_principal.{tex,pdf}` — 19 páginas, 10 figuras. Cohorte
  principal (n = 23): tiempo F(2,40) = 25.503 (p < .001); condición (p = .559) e interacción (p = .989)
  no significativas.
- `results/combinado/manuscrito/resultados_combinado.{tex,pdf}` — 22 páginas, 14 figuras. Las dos
  cohortes se tratan como **muestras independientes**: `fuente` no significativa (p = .939),
  `fuente` × `tiempo` significativa (F(2,68) = 6.848, p = .002).

Propiedades verificadas de los tres documentos: compilan sin errores ni referencias sin resolver;
fuentes Type 1 con mapa Unicode; rótulos de figura y tabla en español; los `.tex` del repositorio son
idénticos (mismo SHA-256) a los del equipo local; no contienen texto de participantes ni datos
individuales. Las citas se limitan a claves ya presentes en el borrador del autor
(`CamachoGomez2007`, `FuentesRibes2001`, `Ryle2005`) más `LopezCorral2024`; no se agregó ninguna
referencia no verificada.

- `manifests/SHA256_REPO.txt` — regenerado sobre el árbol de trabajo (289 archivos).
- `manifests/INVENTARIO_RESULTADOS.csv` — 140 → 175 filas.
- `tests/check_hashes.sh` — la cuarta comprobación verifica también los tres manuscritos.

## [1.2.0] - 2026-09-25

### Integración de los resultados de la corrida completa del pipeline

Se incorporan al repositorio los 140 artefactos admisibles de la corrida verificada del pipeline
(`Experimento ALC_v5_corregido.R`, v5.9, SHA-256 `1143b36a…`): **informes**, **figuras** (todas, ES/EN,
PNG y PDF), **tablas agregadas**, **objetos de modelo** y **registros de ejecución**.

- `results/piloto/`, `results/principal/`, `results/combinado/` — informes por cohorte y su comparación,
  con las tablas, figuras, modelos y diagnósticos de cada una.
- `results/tablas/`, `results/figuras/{es,en}/` — tablas y figuras del pipeline completo.
- `results/combinado/sensibilidad/` — los seis modelos del análisis de sensibilidad y robustez.
- `results/combinado/revision/` — el paquete preparado para revisión independiente.
- `results/modelos/`, `results/diagnosticos/`, `results/logs/`.
- `manifests/INVENTARIO_RESULTADOS.csv` — inventario de lo integrado (ruta, bytes, SHA-256).
- `docs/resultados_integrados.md` — **política de admisibilidad y lista de exclusiones con motivo**.

**Política aplicada** (ver `docs/resultados_integrados.md`): no entra ningún archivo con texto escrito por
participantes, ni tablas con una fila por observación o por participante, ni insumos crudos, ni árboles
duplicados. Los objetos `.rds` de modelo se integran sin sus slots de datos por participante (`datos`,
`diagnosticos`), conservando modelo, ANOVA, R², medias marginales y contrastes. Cada archivo candidato pasa
por una comprobación de contenido: ninguna celda de texto puede superar los 200 caracteres.

`tests/check_hashes.sh` pasa de tres a **cuatro** comprobaciones: se añade la inspección del contenido de
los CSV y del interior de los `.xlsx` en busca de narrativa, y la verificación de que los informes y las
figuras estén donde dice el inventario.

## [1.1.0] - 2026-09-24

### Added
- `CITATION.cff` (plantilla: nombres, ORCID y año están marcados `TODO_CONFIRMAR` para el autor),
  `LICENSE` (MIT para el código, CC BY 4.0 para documentación y figuras).
- `docs/`: `decisiones.md`, `integridad.md`, `glosario_para_lectores.md` y
  `metodologia_pipeline_nlp.md` (convertido del documento del autor).
- `data_spec/`: `codebook.md` (las 6 variables del Codebook de captura), `prototipos.csv`
  (20 constructos × 5 frases = 100 filas, extraídas del script del estudio) y `diccionarios.md`
  (NRC-ES + 10 temas Hopper con 190 términos semilla).
- `manifests/`: manifiesto SHA-256 del repositorio y su inventario, más los manifiestos del árbol
  auditado como procedencia.
- `tests/check_hashes.sh`: tres comprobaciones en un comando (microdatos rastreados por git,
  integridad SHA-256, número de campos de los CSV de `results/`).
- `results/piloto/`, `results/principal/`, `results/combinado/`: separación de salidas por cohorte.

### Changed
- Estructura: `R/`, `python/`, `scripts/` y `run_analysis.R` → `code/`; `outputs/` → `results/`.
- Rutas internas repuntadas en 10 archivos (79 sustituciones): `here("R", …)` →
  `here("code", "R", …)`, `here("resultados"/"outputs", …)` → `here("results", …)`,
  `"R/…"` → `"code/R/…"`.
- `README.md`: se antepone el bloque de estado (qué es el estudio, cohortes, qué no se puede
  concluir, cómo se reproduce, datos no incluidos). El documento original se conserva íntegro.
- `.gitignore`: se retira la regla obsoleta `outputs/**`.
- `docs/GUIA_EJECUCION.md`: comandos correctos de `uv` (no vive dentro del venv) y ruta real del
  repositorio.

### Fixed
- `code/01_pipeline_nlp.R` (script del estudio) se publica con las correcciones `[v5-A]`…`[v5-N]`:
  separación real de cohortes (`fuente = "piloto"`, id `piloto_P*`), aserción que detiene el script
  si las cohortes comparten identificadores, funciones inexistentes implementadas
  (`calcular_descriptivos`, `reportar_descriptivos`), `rm(list = ls())` eliminado, intérprete de
  Python resuelto en cascada y comprobado, embeddings que no se guardan vacíos, metadatos
  corregidos y salidas separadas por cohorte.
- `code/R/03_sentiment.R`: el léxico se carga desde `data/raw/lexicons/nrc_es.rds` (antes
  `data/lexicons/…`, ruta inexistente en el repositorio).
- `code/R/08_visualization.R`: `dir.create()` anclado al repositorio en vez de relativo al cwd.
- `code/run_analysis.R`: los prototipos se guardan en
  `data/processed/embeddings/rds/semantic_prototypes/` (convención ya existente).
- `.gitignore`: se restaura `*.zip`, perdido en una edición anterior.

### Known issues
- Los resultados publicados no se han re-ejecutado en este empaquetado (`docs/integridad.md` §4).
- Las tablas del manuscrito siguen escritas a mano en el `.tex` (`docs/decisiones.md` D7).

## [1.0.0] - 2026-09-24

### Fixed

- **D1 - Cohort identifier collision**: `run_analysis.R` now imports and normalizes the pilot cohort using `importar_piloto()` + `normalizar_piloto()` (which produce `fuente = "piloto"` and `id_participante = "piloto_P1"...`), instead of incorrectly using `normalizar_principal()` which assigned `fuente = "principal"`.

- **D2 - Pilot import reads wrong sheet and infers condition incorrectly**: `importar_piloto()` in `R/01_import_data.R` now defaults to reading the `Datos_Largo` sheet (51 rows = 17 participants × 3 iterations) and takes `condicion` directly from the data. The legacy visual-layout parser (`Hoja1`) is retained as an explicit fallback with a console warning, but is no longer the default path.

- **D3 - Validators were stubs**: Implemented full `validar_esquema()` and `validar_dataset_maestro()` in `R/01_import_data.R` with:
  - Required columns, types, `n_palabras_calculado` non-negative
  - No duplicates in `id_observacion`
  - Explicit assertion: uniqueness of `id_participante` within each cohort
  - Explicit assertion: distinct prefixes between cohorts (`principal_` vs `piloto_`)
  - Fail loudly with `stop()` and clear messages (no silent failures)

- **D4a - Python path resolution**: `R/00_config.R` now resolves the Python interpreter in priority order:
  1. `NLP_PYTHON` environment variable
  2. `C:/venvs/renv-nlp/Scripts/python.exe`
  3. `C:/venvs/renv311/Scripts/python.exe`
  4. `Sys.which("python")`
  Each candidate is tested for `sentence_transformers` import; on total failure, stops with exact instructions to create the environment (`uv venv`, `uv pip install sentence-transformers torch`).

- **D4b - Embeddings Python script path**: `R/05_embeddings.R` now uses `here::here("python", "embeddings_setup.py")` instead of `file.path(getwd(), ...)`.

- **D4c - Sensitivity hardcoded path**: `R/09_sensitivity.R` now uses `file.path("outputs", "modelos", "comparativos", "modelos_comparativos.rds")` with `file.exists()` guard and clear message.

- **D4d - Raw data path configurable**: Added configurable `RUTA_DATOS_CRUDOS`, `RUTA_PRINCIPAL_EXCEL`, `RUTA_PILOTO_EXCEL` to `R/00_config.R`. `run_analysis.R` uses these with fallback to `data/raw/`.

- **D5 - Wrong dependent variable in pilot**: `R/piloto/03_piloto_models.R` now:
  - Uses `n_palabras_calculado` as default VD (since `n_palabras` is 100% empty in pilot)
  - Explicitly excludes any variable with < 3 non-missing values across T1+T2+T3, logging which variables were dropped and why
  - Sensitivity analysis also uses `n_palabras_calculado`

- **D6 - Mojibake in string literals**: Rewrote all `Ã¡`, `â` sequences in `R/05_embeddings.R` prototype phrases to proper UTF-8. All `.R` files touched are UTF-8 without BOM.

- **D7 - Repository garbage**: Deleted `R/05_embeddings.R.bak_20260907` (obsolete backup) and `renv.lock` (empty, 0 bytes, breaks `renv::restore()`).

### Added

- **Cohort-separated outputs**: Pipeline now writes separate outputs per cohort:
  - `data/processed/principal/`, `data/processed/piloto/`, `data/processed/combinado/`
  - `data/processed/embeddings/{principal,piloto,combinado}/` with per-timepoint `.rds` + `.txt` metadata
  - `outputs/{principal,piloto,combinado}/{tablas,modelos,figuras,diagnosticos}/`
  - `outputs/logs/` — one log per run

- **Parametrized embeddings function**: New `obtener_embeddings_cohorte()` and `calcular_embeddings_todas_cohortes()` in `R/05_embeddings.R` accept cohort label and output path, compute embeddings for all three sets (principal 23×384, pilot 17×384, combined 40×384) in one run.

- **Embeddings metadata**: Each saved `.rds` has an accompanying `.txt` with model, dimension, normalization, row count, date, and hash of input texts. Empty-text (`[VACÍO]`) count is logged and written to metadata.

- **Pilot standalone execution**: `R/piloto/piloto_run.R` works without principal data, using corrected `importar_piloto()` and writing to `outputs/piloto/` and `data/processed/piloto/`.

- **Pre-flight checks in `run_analysis.R`**: Verifies both Excel files exist and Python interpreter works with `sentence_transformers` before starting.

- **Execution documentation**: `docs/GUIA_EJECUCION.md` with requirements, paths, and the two literal command lines.

- **Updated `.gitignore`**: Added `data/processed/**`, `data/raw/*.xlsx`, `outputs/**` with comment explaining these may contain participant narratives.

### Changed

- `run_analysis.R` prints final summary with n per cohort, n embeddings per cohort, and output paths.
- `R/piloto/01_piloto_import.R` uses corrected `importar_piloto()` (reads `Datos_Largo`, uses `condicion` from data).
- All `.R` files confirmed UTF-8 without BOM.

### Not verified (require data + Python environment to test)

- End-to-end pipeline execution with real data
- Embedding generation and downstream PCA/prototypes/similarities
- Mixed-model fitting and bootstrap
- Figure generation
- Sensitivity analysis replication