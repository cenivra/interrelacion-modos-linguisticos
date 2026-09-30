# Informe de resultados — cohorte PRINCIPAL

![Resultados de la cohorte principal](../../docs/assets/portada_resultados_principal.jpg)

**Generado:** 2026-09-25 19:16  
**Cohorte:** estudio principal (23 participantes)  
**Datos de origen:** `Analisis agosto v2/` (corrida del script `Experimento ALC_v5_corregido.R`)  
**Contenido:** solo agregados (n, medias, desviaciones, efectos, p-valores). Este informe **no contiene narrativas** de participantes.  
**Muestra:** 23 (Texto 8 · Audio 8 · Imagen 7)  

---


## 1. Diseño y flujo de participantes

Tres iteraciones por participante: **T1** sin estímulo (línea base), **T2** un estímulo, 
**T3** tres estímulos acumulados. Condiciones: Texto (leer), Audio (escuchar), Imagen (observar).

- Participantes: **23**
- Observaciones por participante: **3** (T1, T2, T3) → total 69 observaciones

Reparto por condición:

| condición | participantes |
| --- | --- |
| Audio | 8 |
| Imagen | 7 |
| Texto | 8 |

Reparto por demora:

| demora | participantes |
| --- | --- |
| D | 11 |
| ND | 12 |

![Diseño y flujo de participantes](../../docs/assets/diseno_flujo_participantes.jpg)

## 2. Auditoría de variables: qué se pudo modelar y qué no

Se auditaron **3 variables**. De ellas, **2** pasaron el filtro de calidad (`APTA_PARA_REVISION`) y 1 se excluyeron.

| variable | estado | n_participantes | n_completos | sd_global | motivo |
| --- | --- | --- | --- | --- | --- |
| n_palabras | APTA_PARA_REVISION | 23.00 | 23.00 | 87.21 | NA |
| n_palabras_calculado | APTA_PARA_REVISION | 23.00 | 23.00 | 87.21 | NA |
| n_estimulos | ESTRUCTURAL | 23.00 | 23.00 | 1.26 | Variable de diseño (no es un outcome) |

Variables excluidas del modelado:

_Ninguna variable quedó excluida del modelado en la cohorte principal._


## 3. Descriptivos por condición e iteración


### `n_palabras`

| condicion | tiempo | n | media | sd | mediana | minimo | maximo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Texto | T1 | 8.000 | 88.500 | 54.882 | 87.500 | 28.000 | 186.000 |
| Texto | T2 | 8.000 | 138.125 | 87.383 | 129.500 | 28.000 | 311.000 |
| Texto | T3 | 8.000 | 184.625 | 136.040 | 129.000 | 42.000 | 401.000 |
| Audio | T1 | 8.000 | 109.875 | 79.506 | 89.000 | 29.000 | 227.000 |
| Audio | T2 | 8.000 | 160.875 | 65.747 | 168.000 | 86.000 | 231.000 |
| Audio | T3 | 8.000 | 200.500 | 66.444 | 212.000 | 106.000 | 304.000 |
| Imagen | T1 | 7.000 | 74.429 | 33.271 | 70.000 | 37.000 | 135.000 |
| Imagen | T2 | 7.000 | 115.286 | 66.817 | 102.000 | 45.000 | 245.000 |
| Imagen | T3 | 7.000 | 155.000 | 101.346 | 125.000 | 60.000 | 325.000 |


### `n_palabras_calculado`

| condicion | tiempo | n | media | sd | mediana | minimo | maximo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Texto | T1 | 8.000 | 88.500 | 54.882 | 87.500 | 28.000 | 186.000 |
| Texto | T2 | 8.000 | 138.125 | 87.383 | 129.500 | 28.000 | 311.000 |
| Texto | T3 | 8.000 | 184.625 | 136.040 | 129.000 | 42.000 | 401.000 |
| Audio | T1 | 8.000 | 109.875 | 79.506 | 89.000 | 29.000 | 227.000 |
| Audio | T2 | 8.000 | 160.875 | 65.747 | 168.000 | 86.000 | 231.000 |
| Audio | T3 | 8.000 | 200.500 | 66.444 | 212.000 | 106.000 | 304.000 |
| Imagen | T1 | 7.000 | 74.429 | 33.271 | 70.000 | 37.000 | 135.000 |
| Imagen | T2 | 7.000 | 115.286 | 66.817 | 102.000 | 45.000 | 245.000 |
| Imagen | T3 | 7.000 | 155.000 | 101.346 | 125.000 | 60.000 | 325.000 |


### `n_estimulos`

| condicion | tiempo | n | media | sd | mediana | minimo | maximo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Texto | T1 | 8.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Texto | T2 | 8.000 | 1.000 | 0.000 | 1.000 | 1.000 | 1.000 |
| Texto | T3 | 8.000 | 3.000 | 0.000 | 3.000 | 3.000 | 3.000 |
| Audio | T1 | 8.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Audio | T2 | 8.000 | 1.000 | 0.000 | 1.000 | 1.000 | 1.000 |
| Audio | T3 | 8.000 | 3.000 | 0.000 | 3.000 | 3.000 | 3.000 |
| Imagen | T1 | 7.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| Imagen | T2 | 7.000 | 1.000 | 0.000 | 1.000 | 1.000 | 1.000 |
| Imagen | T3 | 7.000 | 3.000 | 0.000 | 3.000 | 3.000 | 3.000 |


## 4. Modelos lineales mixtos

Especificación: `valor ~ condición × tiempo + (1 | participante)`, estimación REML, 
grados de libertad Satterthwaite. La condición es un factor **entre** sujetos y el tiempo **intra** sujeto.

Se ajustaron modelos lineales mixtos (`valor ~ condición × tiempo + (1|participante)`, REML, Satterthwaite) para **1 variables** en la cohorte **principal**: `n_palabras_calculado`.

![Modelo lineal mixto y resultados principales](../../docs/assets/modelo_mixto_principal.jpg)

La estructura del modelo y la magnitud relativa de sus efectos se sintetizan visualmente en la figura siguiente. Esta representación permite distinguir el efecto temporal de la ausencia de efectos atribuibles a la condición o a su interacción con el tiempo, así como observar la proporción de variabilidad asociada a los efectos fijos y a las diferencias entre participantes.

| fuente | variable | efecto | F | df1 | df2 | p | R2_marginal | R2_condicional |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| principal | n_palabras_calculado | condicion | 0.5981 | 2.0000 | 20.0000 | 0.5594 | 0.1972 | 0.7875 |
| principal | n_palabras_calculado | tiempo | 25.5037 | 2.0000 | 40.0000 | 7.24e-08 | 0.1972 | 0.7875 |
| principal | n_palabras_calculado | condicion:tiempo | 0.0750 | 4.0000 | 40.0000 | 0.9894 | 0.1972 | 0.7875 |

- **n_palabras_calculado**: efecto de tiempo F = 25.504 (p = 7.24e-08) → significativo: **sí**.
  Interacción condición×tiempo: F = 0.075 (p = 0.9894) → significativa: no.
  R² marginal = 0.197; R² condicional = 0.787.


## Medias marginales estimadas y contrastes — principal


### `n_palabras_calculado`

Medias marginales (emmeans):

| condicion | tiempo | emmean | SE | df | lower.CL | upper.CL |
| --- | --- | --- | --- | --- | --- | --- |
| Texto | T1 | 88.500 | 29.031 | 28.830 | 29.109 | 147.891 |
| Audio | T1 | 109.875 | 29.031 | 28.830 | 50.484 | 169.266 |
| Imagen | T1 | 74.429 | 31.036 | 28.830 | 10.937 | 137.920 |
| Texto | T2 | 138.125 | 29.031 | 28.830 | 78.734 | 197.516 |
| Audio | T2 | 160.875 | 29.031 | 28.830 | 101.484 | 220.266 |
| Imagen | T2 | 115.286 | 31.036 | 28.830 | 51.794 | 178.777 |
| Texto | T3 | 184.625 | 29.031 | 28.830 | 125.234 | 244.016 |
| Audio | T3 | 200.500 | 29.031 | 28.830 | 141.109 | 259.891 |
| Imagen | T3 | 155.000 | 31.036 | 28.830 | 91.509 | 218.491 |

Contrastes **entre condiciones** en cada tiempo (ajuste Holm):

| contrast | tiempo | estimate | SE | df | t.ratio | p.value |
| --- | --- | --- | --- | --- | --- | --- |
| Texto - Audio | T1 | -21.375 | 41.056 | 28.830 | -0.521 | 1.000 |
| Texto - Imagen | T1 | 14.071 | 42.497 | 28.830 | 0.331 | 1.000 |
| Audio - Imagen | T1 | 35.446 | 42.497 | 28.830 | 0.834 | 1.000 |
| Texto - Audio | T2 | -22.750 | 41.056 | 28.830 | -0.554 | 1.000 |
| Texto - Imagen | T2 | 22.839 | 42.497 | 28.830 | 0.537 | 1.000 |
| Audio - Imagen | T2 | 45.589 | 42.497 | 28.830 | 1.073 | 0.877 |
| Texto - Audio | T3 | -15.875 | 41.056 | 28.830 | -0.387 | 0.983 |
| Texto - Imagen | T3 | 29.625 | 42.497 | 28.830 | 0.697 | 0.983 |
| Audio - Imagen | T3 | 45.500 | 42.497 | 28.830 | 1.071 | 0.880 |

Contrastes **entre tiempos** en cada condición (ajuste Holm):

| contrast | condicion | estimate | SE | df | t.ratio | p.value |
| --- | --- | --- | --- | --- | --- | --- |
| T1 - T2 | Texto | -49.625 | 21.126 | 40.000 | -2.349 | 0.048 |
| T1 - T3 | Texto | -96.125 | 21.126 | 40.000 | -4.550 | 0.000 |
| T2 - T3 | Texto | -46.500 | 21.126 | 40.000 | -2.201 | 0.048 |
| T1 - T2 | Audio | -51.000 | 21.126 | 40.000 | -2.414 | 0.041 |
| T1 - T3 | Audio | -90.625 | 21.126 | 40.000 | -4.290 | 0.000 |
| T2 - T3 | Audio | -39.625 | 21.126 | 40.000 | -1.876 | 0.068 |
| T1 - T2 | Imagen | -40.857 | 22.584 | 40.000 | -1.809 | 0.156 |
| T1 - T3 | Imagen | -80.571 | 22.584 | 40.000 | -3.568 | 0.003 |
| T2 - T3 | Imagen | -39.714 | 22.584 | 40.000 | -1.759 | 0.156 |



## 5. Figuras

Las figuras correspondientes a los análisis de la cohorte principal fueron generadas mediante los scripts del pipeline ejecutados en **R/RStudio** y se encuentran disponibles en formatos PNG y PDF de alta resolución. Las versiones en español e inglés se conservan para facilitar tanto la revisión técnica como la preparación de manuscritos y presentaciones.

### Versión en español

- `outputs/figuras/principal/PRINCIPAL_n_palabras_calculado_ES_distribucion.pdf`
- `outputs/figuras/principal/PRINCIPAL_n_palabras_calculado_ES_distribucion.png`
- `outputs/figuras/principal/PRINCIPAL_n_palabras_calculado_ES_individuales.pdf`
- `outputs/figuras/principal/PRINCIPAL_n_palabras_calculado_ES_individuales.png`
- `outputs/figuras/principal/PRINCIPAL_n_palabras_calculado_ES_trayectoria.pdf`
- `outputs/figuras/principal/PRINCIPAL_n_palabras_calculado_ES_trayectoria.png`

### English version

- `outputs/figuras/principal/en/MAIN_n_palabras_calculado_EN_distribucion.pdf`
- `outputs/figuras/principal/en/MAIN_n_palabras_calculado_EN_distribucion.png`
- `outputs/figuras/principal/en/MAIN_n_palabras_calculado_EN_individuales.pdf`
- `outputs/figuras/principal/en/MAIN_n_palabras_calculado_EN_individuales.png`
- `outputs/figuras/principal/en/MAIN_n_palabras_calculado_EN_trayectoria.pdf`
- `outputs/figuras/principal/en/MAIN_n_palabras_calculado_EN_trayectoria.png`


## 6. Lo que este informe NO permite afirmar

- Los grupos por condición × demora son pequeños (varias celdas con n ≤ 5):
  la interacción triple condición × demora × tiempo no es estimable con estabilidad.
- Las tablas conjuntas de 40 participantes mezclan cohortes; aquí se usan solo las del principal.


## 7. Trazabilidad

Los siguientes artefactos constituyen las fuentes de los valores reportados en este informe. Las rutas se expresan de forma **relativa al directorio de análisis `Analisis agosto v2/`**, sin incorporar rutas locales o absolutas del equipo de análisis.

- `principal/tablas/auditoria_principal.csv`
- `principal/tablas/descriptivos_condicion_tiempo.csv`
- `principal/tablas/resumen_modelos_validos.csv`
- `principal/tablas/principal_<variable>_EMM.csv`
- `principal/tablas/principal_<variable>_contrastes_cond.csv`
- `principal/tablas/principal_<variable>_contrastes_tiempo.csv`
- `principal/modelos/modelos_principal.rds`
- `principal/...`
