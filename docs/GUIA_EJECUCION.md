# Guía de Ejecución — Pipeline NLP (3 Tiempos)

## Requisitos previos

1. **R ≥ 4.6.1** instalado en `C:/Program Files/R/R-4.6.1/`
2. **Paquetes R** (se instalan automáticamente al cargar `R/00_config.R`):
   - tidyverse, tidytext, readxl, stringr, stringi, tokenizers, stopwords, text2vec, proxy, tm, syuzhet
   - lme4, lmerTest, emmeans, performance, effectsize, rstatix, effsize, car
   - topicmodels, ggplot2, cowplot, viridis, corrplot, RColorBrewer, ggraph, igraph, wordcloud
   - readr, scales, writexl, ggpubr, gridExtra, broom.mixed, patchwork, see, FSA, rcompanion
   - reticulate, here, digest

3. **Entorno Python con sentence-transformers**:
   - Opción A (recomendada), entorno ya creado y validado en este equipo:
     ```
     uv venv C:/venvs/renv-nlp --python 3.11
     uv pip install --python C:/venvs/renv-nlp/Scripts/python.exe --index-url https://download.pytorch.org/whl/cpu torch
     uv pip install --python C:/venvs/renv-nlp/Scripts/python.exe -r requirements.txt
     ```
     (tan larga la primera línea: el `uv` NO vive dentro del venv, se invoca desde fuera y se
     apunta al intérprete con `--python`)
   - Opción B: Usar `C:/venvs/renv311` si ya existe y funciona
   - Opción C: Definir variable de entorno `NLP_PYTHON` apuntando a un `python.exe` válido con `sentence-transformers`
   - El modelo `paraphrase-multilingual-MiniLM-L12-v2` (384 dims, L2) se descarga automáticamente la primera vez y queda en caché de HuggingFace (no requiere red en ejecuciones posteriores)

4. **Datos crudos** (NO están en el repo; colocar en la ruta configurada):
   - `Datos Exp Interrelacion.xlsx` (hoja `Datos_Largo`) — estudio principal
   - `piloto_interrelacion_formato_largo.xlsx` (hoja `Datos_Largo`) — estudio piloto
   - Por defecto se busca en: `data/raw/`
   - Para cambiar la ruta: editar `RUTA_DATOS_CRUDOS` en `R/00_config.R`

## Estructura de salidas

El pipeline escribe en directorios **separados por cohorte**:

```
data/processed/
  principal/
    ancho_principal_base.rds           # 23 filas
    ancho_principal_procesado.rds      # 23 filas
  piloto/
    ancho_piloto_base.rds              # 17 filas
    ancho_piloto_procesado.rds         # 17 filas
  combinado/
    ancho_combinado_procesado.rds      # 40 filas (con columna 'fuente')
  embeddings/
    principal/embeddings_principal_t{1,2,3}.rds   # 23 × 384 + _meta.txt
    piloto/embeddings_piloto_t{1,2,3}.rds         # 17 × 384 + _meta.txt
    combinado/embeddings_combinado_t{1,2,3}.rds   # 40 × 384 + _meta.txt
  prototypes/prototipos_semanticos.rds

outputs/
  principal/{tablas,modelos,figuras,diagnosticos}/
  piloto/{tablas,modelos,figuras,diagnosticos}/
  combinado/{tablas,modelos,figuras,diagnosticos}/
  logs/

resultados/  (salidas del pipeline principal: figuras, tablas, modelos, PCA, prototipos)
```

## Ejecución

### Pipeline completo (principal + piloto + combinado)

```cmd
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" --vanilla run_analysis.R
```

### Solo piloto (independiente, sin datos del principal)

```cmd
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" --vanilla R/piloto/piloto_run.R
```

Ambos comandos deben ejecutarse desde la **raíz del repositorio**:

```cmd
cd /d "G:\Mi unidad\GITHUB_REPOS\experimento-nlp"
```

Los datos crudos **no están en el repositorio** (contienen narrativas de participantes). La ruta se
configura en `RUTA_DATOS_CRUDOS` dentro de `R/00_config.R` (por defecto apunta a la carpeta local
`la ruta local configurada en `RUTA_DATOS_CRUDOS``).

## Verificación rápida

Al finalizar `run_analysis.R`, se imprime un resumen con:
- n de participantes por cohorte
- n de embeddings por cohorte  
- rutas de salida principales

Si algo falla, el script se detiene con un mensaje de error claro (fallo ruidoso).

## Notas importantes

- **Cohortes separadas**: El piloto **nunca** se mezcla con el principal. Cada cohorte tiene su propio `fuente` ("principal" / "piloto") y prefijo en `id_participante` ("principal_P1..." / "piloto_P1...").
- **Validación estricta**: `validar_esquema()` y `validar_dataset_maestro()` fallan con `stop()` si hay columnas faltantes, tipos incorrectos, duplicados en `id_observacion`, o prefijos de cohorte no únicos.
- **Variable dependiente piloto**: Se usa `n_palabras_calculado` (no `n_palabras`, que está vacía en el piloto). Variables con < 3 valores no faltantes se excluyen explícitamente con log.
- **Textos vacíos**: Se reemplazan por `[VACÍO]` para la inferencia, pero se **cuentan y registran** en el log y en los metadatos de embeddings. Nunca se presentan como observaciones válidas.
- **Datos de personas**: Los Excel contienen narrativas reales. **No abrir, imprimir ni volcar** los textos. Solo dimensiones, nombres de columnas y conteos.

## Solución de problemas

| Problema | Solución |
|----------|----------|
| "No se encontró un intérprete Python válido" | `uv venv C:/venvs/renv-nlp --python 3.11` y luego `uv pip install --python C:/venvs/renv-nlp/Scripts/python.exe sentence-transformers torch` |
| "Archivo principal no encontrado" | Verificar `RUTA_DATOS_CRUDOS` en `R/00_config.R` |
| "Prefijos de id_participante NO son únicos" | Revisar que `normalizar_principal` y `normalizar_piloto` asignen `fuente` correcto |
| Error en `validar_esquema` | El mensaje indica exactamente qué falla (columnas, tipos, duplicados, etc.) |