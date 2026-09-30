# Integridad y trazabilidad

El repositorio utiliza **tres conjuntos de hashes**, cada uno asociado con una pregunta diferente sobre la procedencia e integridad de los materiales:

1. **¿Coinciden los archivos actualmente versionados con los identificados en el repositorio?**
2. **¿Qué materiales formaban parte del árbol de trabajo utilizado como fuente del paquete?**
3. **¿Qué versión de determinados artefactos citados en la documentación fue utilizada en el análisis?**

Mantener estas capas separadas permite distinguir entre la integridad de los archivos actualmente publicados y la procedencia de los materiales que dieron origen al análisis.

---

## 1. Integridad de los artefactos del repositorio

`manifests/SHA256_REPO.txt` contiene el hash SHA-256 de los archivos versionados en el repositorio, utilizando rutas relativas a su raíz.

La comprobación puede realizarse mediante:

```bash
bash tests/check_hashes.sh
```

o directamente con:

```bash
sha256sum -c manifests/SHA256_REPO.txt
```

El manifiesto se regenera a partir del estado actual del repositorio mediante:

```bash
cd <raíz del repositorio>
git ls-files -z | xargs -0 sha256sum > manifests/SHA256_REPO.txt
```

El archivo no debe editarse manualmente.

`manifests/INVENTARIO_REPO.csv` complementa este manifiesto con información sobre tamaño y fecha de los archivos registrada durante la generación del inventario.

---

## 2. Procedencia del árbol de trabajo utilizado como fuente

Los manifiestos de procedencia documentan el árbol de trabajo a partir del cual se seleccionaron y organizaron los materiales que dieron lugar al repositorio actual.

Estos manifiestos permiten conservar la **trazabilidad histórica del material de origen**, aunque sus rutas originales correspondan a ubicaciones locales y, por ello, no puedan reproducirse directamente desde otro equipo.

| Archivo                                                  | Contenido                                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `manifests/SHA256_ARBOL_AUDITADO.txt`                    | Hash SHA-256 de los 311 archivos identificados en el árbol de trabajo de origen                        |
| `manifests/INVENTARIO_COMPLETO_ARBOL_AUDITADO.csv`       | Inventario con tamaño, fecha y extensión de los archivos de origen                                     |
| `manifests/INDICE_DUPLICADOS.csv`                        | Identificación de 103 grupos de archivos duplicados, con aproximadamente 40 MB de contenido redundante |
| `manifests/MANIFIESTO_SHA256_MATERIAL_PILOTO.{txt,csv}`  | Hashes correspondientes a los 60 archivos considerados como material del piloto                        |
| `manifests/MANIFIESTO_SHA256_PAQUETE_COMPLETO.{txt,csv}` | Hashes correspondientes al paquete completo de auditoría, compuesto por 73 archivos                    |

Esta capa de documentación tiene una función de **procedencia histórica** y no debe confundirse con el manifiesto de los archivos actualmente versionados.

---

## 3. Integridad de artefactos específicos citados en la documentación

Algunos documentos hacen referencia a artefactos concretos cuyo hash se conserva para facilitar su identificación y comparación con las versiones descritas en el proyecto.

| Artefacto                                           | SHA-256                                                            | Ubicación o procedencia                            |
| --------------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------- |
| `Experimento ALC.R` (versión original)              | `a781da40333aa7c7ee0a401ea9ab404f57b0260e876e6555acfbd4c1088b5950` | Material de origen; no forma parte del repositorio |
| `Experimento ALC_v5_corregido.R` (versión reparada) | `0ddbe5cceb298e85456600d57541b9474f9ca55b89674e4bbbb704b9c6ee2bb1` | `code/01_pipeline_nlp.R`                           |
| Manuscrito `resultados.tex` / `resultados.pdf`      | texto idéntico entre ambas versiones (`fa7bea79…`)                 | Material de origen                                 |
| `embeddings_piloto_t1..t3.rds`                      | 17 × 384; no vacíos                                                | `data/processed/piloto/`                           |

Los hashes de esta sección funcionan como referencias de identidad de los artefactos y complementan, sin sustituir, el manifiesto general del repositorio.

---

## 4. Principios de integridad

El repositorio adopta las siguientes reglas para mantener la trazabilidad de sus materiales:

1. **Los materiales con información individual no forman parte del control de versiones.** Las comprobaciones de `tests/check_hashes.sh` se aplican sobre los archivos rastreados por Git y permiten detectar incorporaciones que no correspondan al contenido previsto.

2. **Los manifiestos se generan a partir de los archivos existentes.** No deben modificarse manualmente, ya que su función es representar el estado efectivo de los materiales en el momento de su generación.

3. **Los artefactos sin contenido analítico no se presentan como resultados.** La revisión del material de origen identificó objetos del piloto almacenados sin datos útiles; estos no se consideran evidencia publicable.

4. **Los resultados incluidos en este paquete corresponden a la corrida analítica documentada.** Para este empaquetado no se realizó una nueva ejecución integral del pipeline. El código fue objeto de verificación sintáctica mediante `parse()`, pero esta comprobación no equivale a una ejecución completa de extremo a extremo.

En conjunto, estos mecanismos permiten diferenciar **integridad del repositorio, procedencia del material de origen e identidad de artefactos específicos**, proporcionando una base verificable para la documentación y el mantenimiento del proyecto.
