# ¿Dependen los hallazgos semánticos del modelo de embeddings? — cohorte principal

Modelo 1 (pipeline): `paraphrase-multilingual-MiniLM-L12-v2`, MiniLM, 384 dimensiones.
Modelo 2 (prueba): `paraphrase-multilingual-mpnet-base-v2`, MPNet, 768 dimensiones.
Mismo texto, mismos parámetros de comparación (coseno sobre vectores normalizados).

## a) Similitud entre momentos

| par | modelo 1 (MiniLM) | modelo 2 (MPNet) |
| --- | --- | --- |
| T1-T2 | 0.898 | 0.909 |
| T2-T3 | 0.927 | 0.928 |
| T1-T3 | 0.866 | 0.875 |

Correlación entre modelos por participante: **0.97**.
Orden T2-T3 > T1-T2 > T1-T3 en el modelo 1: **TRUE**; en el modelo 2: **TRUE**.

## b) Distancia T1-T3 en el espacio reducido

| condición | modelo 1 | modelo 2 |
| --- | --- | --- |
| Imagen | 3.99 | 0.14 |
| Audio | 2.38 | 0.08 |
| Texto | 1.92 | 0.05 |

Varianza retenida por las dos primeras componentes — modelo 1: 20.19 %; modelo 2: 30.55%.

## c) Prototipos

Correlación de los cambios T1→T3 por constructo entre ambos modelos: **0.77**.

| constructo | Δ T1→T3 modelo 2 | Δ T1→T3 modelo 1 |
| --- | --- | --- |
| duda | +0.0333 | +0.0235 |
| incertidumbre | +0.0263 | +0.0100 |
| pasividad | -0.0246 | -0.0203 |
| afrontamiento | +0.0214 | +0.0042 |
| miedo | +0.0199 | +0.0126 |
| emociones_negativas | +0.0194 | +0.0128 |

Si los tres órdenes coinciden y las correlaciones son altas, el hallazgo semántico no es un
artefacto del instrumento y así se declara en el manuscrito; si discrepan, se reportan las dos
lecturas y se marca el límite.

Cookie de trazabilidad — modelo 2: MPNet 768 dims | textos codificados: 69 | prototipos: 22 | fecha: 2026-09-29 18:28
