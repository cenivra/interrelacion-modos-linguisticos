# R/README.md — Módulos del análisis NLP para el piloto del estudio

Este directorio contiene todos los módulos de R que componen el pipeline de análisis del experimento NLP.  
La estructura está diseñada para ser modular, reproducible y reutilizable.

## Estructura general

```
R/
├── 00_config.R            # Configuración global (librerías, opciones, logging, Python)
├── 01_import_data.R       # Importación y normalización de datos (principal y piloto)
├── 02_text_processing.R   # Limpieza, tokenización y métricas lingüísticas
├── 03_sentiment.R         # Léxico NRC‑ES y análisis de sentimiento
├── 04_dictionaries.R      # Diccionarios temáticos de Hopper
├── 05_embeddings.R        # Embeddings, prototipos y PCA (funciones)
├── 06_similarity.R        # Similitudes textuales (coseno y Jaccard)
├── 07_models.R            # Modelos mixtos, pruebas inferenciales y bootstrap
├── 08_visualization.R     # Figuras científicas (temas, funciones de creación)
├── 09_sensitivity.R       # Análisis de sensibilidad y robustez
└── piloto/                # Pipeline independiente para el análisis piloto
    ├── README.md          # Documentación específica del piloto
    ├── 00_piloto_config.R
    ├── 01_piloto_import.R
    ├── 02_piloto_analysis.R
    ├── 03_piloto_models.R
    ├── 04_piloto_figures.R
    ├── 05_piloto_results.R
    └── run_piloto.R       # Script principal para ejecutar el análisis piloto
```

## Flujo de ejecución

El pipeline principal (`run_analysis.R` en la raíz del repositorio) carga estos módulos en el siguiente orden:

```
00_config.R
    ↓
01_import_data.R
    ↓
02_text_processing.R
    ↓
03_sentiment.R
    ↓
04_dictionaries.R
    ↓
05_embeddings.R
    ↓
06_similarity.R
    ↓
07_models.R
    ↓
08_visualization.R
    ↓
09_sensitivity.R
```

El análisis piloto (`run_piloto.R` dentro de `piloto/`) utiliza los mismos módulos comunes, pero procesa exclusivamente los datos del piloto y genera resultados independientes.

## Módulos comunes

| Módulo | Propósito | Dependencias |
|--------|-----------|--------------|
| `00_config.R` | Carga librerías, opciones globales, logging y configuración de Python. | Ninguna |
| `01_import_data.R` | Importa y normaliza los datasets (principal y piloto), integra fuentes, genera formato ancho. | `00_config.R` |
| `02_text_processing.R` | Limpia textos, tokeniza y calcula métricas lingüísticas. | `00_config.R` |
| `03_sentiment.R` | Gestiona el léxico NRC‑ES y realiza análisis de sentimiento. | `00_config.R`, `02_text_processing.R` |
| `04_dictionaries.R` | Define y aplica diccionarios temáticos de Hopper. | `00_config.R`, `02_text_processing.R` |
| `05_embeddings.R` | Funciones para obtener embeddings y construir prototipos semánticos. | `00_config.R` + Python (reticulate) |
| `06_similarity.R` | Calcula similitudes textuales basadas en tokens (coseno y Jaccard). | `00_config.R` |
| `07_models.R` | Modelos mixtos, pruebas inferenciales, bootstrap y funciones de sensibilidad. | `00_config.R` |
| `08_visualization.R` | Temas, paletas y funciones para generar figuras científicas. | `00_config.R`, `07_models.R` |
| `09_sensitivity.R` | Orquesta el análisis de sensibilidad y robustez. | `00_config.R`, `07_models.R`, `08_visualization.R` |

## Módulos del piloto

La carpeta `piloto/` contiene un pipeline autocontenido para el análisis del estudio piloto.  
Está diseñado para ejecutarse de forma independiente y generar todos los resultados necesarios para un artículo científico.

Consultar `piloto/README.md` para más detalles.

## Uso

### Análisis completo (principal + piloto)
```bash
Rscript run_analysis.R
```

### Análisis piloto
```bash
Rscript R/piloto/run_piloto.R
```

## Notas importantes

```
- Los módulos asumen que los datos crudos se encuentran en `data/raw/`.
- Las salidas se generan en `resultados/` (análisis completo) y `outputs/piloto/` (análisis piloto).
- El entorno Python debe estar configurado correctamente para que funcionen los embeddings (`05_embeddings.R`).
- Se recomienda utilizar `renv` para gestionar las dependencias de R.
```

---

# R/piloto/README.md — Análisis piloto independiente

Este directorio contiene el pipeline completo para el análisis del **estudio piloto** del experimento NLP.  
El objetivo es proporcionar un flujo de trabajo reproducible que permita generar todos los resultados (tablas, figuras, modelos) necesarios para un artículo científico basado exclusivamente en los datos del piloto.

## Estructura

```
piloto/
├── 00_piloto_config.R   # Configuración específica del piloto (rutas, parámetros)
├── 01_piloto_import.R   # Importación y normalización de los datos del piloto
├── 02_piloto_analysis.R # Procesamiento completo (texto, sentimiento, diccionarios, embeddings)
├── 03_piloto_models.R   # Modelos estadísticos, pruebas, bootstrap y sensibilidad
├── 04_piloto_figures.R  # Generación de figuras científicas
├── 05_piloto_results.R  # Exportación de resultados (tablas, resúmenes, Excel)
└── run_piloto.R         # Script principal que ejecuta todo el pipeline
```

## Flujo de ejecución

El script `run_piloto.R` orquesta los pasos en este orden:

```
00_piloto_config.R  ← Carga configuración global + específica
        ↓
01_piloto_import.R  ← Carga y normaliza los datos del piloto
        ↓
02_piloto_analysis.R ← Procesa textos, sentimiento, diccionarios, embeddings, similitudes
        ↓
03_piloto_models.R   ← Modelos mixtos, pruebas, bootstrap, sensibilidad
        ↓
04_piloto_figures.R  ← Genera figuras y paneles
        ↓
05_piloto_results.R  ← Exporta tablas y resultados finales
```

## Requisitos previos

- **R** >= 4.0 con los paquetes listados en `R/00_config.R`.
- **Python** 3.8+ con `sentence-transformers` instalado (para embeddings).
- Los datos del piloto deben estar en `data/raw/piloto_interrelacion_formato_largo.xlsx`.
- El script debe ejecutarse desde la raíz del proyecto (o con `here::here()` funcionando correctamente).

## Ejecución

Para ejecutar el análisis piloto completo:

```bash
Rscript R/piloto/run_piloto.R
```

Si se prefiere ejecutar paso a paso desde RStudio, se pueden `source` los scripts individualmente, pero se recomienda usar `run_piloto.R` para garantizar el orden y la reproducibilidad.

## Descripción de cada script

### `00_piloto_config.R`
- Carga la configuración global (`R/00_config.R`).
- Define rutas de salida específicas para el piloto (`OUTPUT_DIR_PILOTO`).
- Establece parámetros como `PILOTO_TIENE_DEMORA = FALSE` (el piloto carece de esta variable).

### `01_piloto_import.R`
- Usa `importar_piloto()` y `normalizar_piloto()` para generar el objeto `datos_piloto` (largo y ancho).
- Valida la estructura de los datos.
- Puede ejecutarse directamente o mediante la función `cargar_piloto()`.

### `02_piloto_analysis.R`
- Aplica `preprocesar_textos()`, `agregar_metricas()` y `calcular_sentimientos()`.
- Calcula scores de diccionarios Hopper (`aplicar_diccionarios_long`).
- Genera embeddings, prototipos y PCA (si está disponible Python).
- Calcula similitudes textuales.
- Guarda el objeto `datos_piloto` enriquecido.

### `03_piloto_models.R`
- Calcula cambios y scores heurísticos (`calcular_cambios_y_scores`).
- Realiza pruebas inferenciales (pareadas y Friedman).
- Ajusta modelos mixtos para variables lingüísticas, emocionales y semánticas.
- Aplica corrección FDR, bootstrap (para el modelo de palabras) y análisis de sensibilidad (opcional).
- Genera tablas de efectos y contrastes.

### `04_piloto_figures.R`
- Utiliza las funciones de `08_visualization.R` para crear figuras específicas del piloto.
- Guarda las figuras en `outputs/piloto/figuras/`, `graficos_es/` y `graficos_en/`.
- Incluye paneles combinados (principal, emocional, cambios).

### `05_piloto_results.R`
- Exporta todas las tablas (descriptivos, efectos, contrastes, correlaciones, bootstrap) a CSV.
- Guarda objetos RDS de datos y modelos.
- Genera un resumen ejecutivo en texto plano (`piloto_results.txt`).
- Opcionalmente, exporta una hoja de Excel con todas las tablas (si `writexl` está instalado).

## Salidas generadas

Todas las salidas se almacenan en `outputs/piloto/`:

```
outputs/piloto/
├── figuras/               # Figuras en PNG
├── graficos_es/           # Versiones en español (PNG/PDF)
├── graficos_en/           # Versiones en inglés (PNG/PDF)
├── tablas/                # Tablas en CSV y Excel
├── modelos/               # Objetos RDS (modelos, datos procesados)
├── diagnosticos/          # Diagnósticos de modelos (si se generan)
├── sensibilidad/          # Resultados del análisis de sensibilidad
├── piloto_log.txt         # Log de la ejecución
└── piloto_results.txt     # Resumen ejecutivo
```

## Personalización

- Para desactivar el análisis de sensibilidad, modificar `realizar_sensibilidad = FALSE` en `03_piloto_models.R`.
- Para omitir el cálculo de embeddings (si no se dispone de Python), establecer `calcular_embeddings = FALSE` en `02_piloto_analysis.R`.
- Para cambiar los umbrales de los diccionarios, ajustar `min_freq`, `min_doc`, `min_part` en `02_piloto_analysis.R`.

## Dependencias

- Los módulos comunes de `R/` deben estar presentes.
- El entorno Python debe estar configurado (reticulate) para los embeddings.
- Los datos del piloto deben estar en el formato esperado (largo, con columnas: participante, condicion, iteracion, texto).

## Notas

- Este pipeline está diseñado para ser ejecutado de forma **independiente** del análisis principal.
- No utiliza ni modifica los datos del estudio principal.
- Los resultados están listos para ser utilizados en un artículo científico sobre el piloto.

## Soporte

Para cualquier duda, consultar la documentación general del proyecto (`README.md` en la raíz) o contactar con el equipo de investigación.
```
