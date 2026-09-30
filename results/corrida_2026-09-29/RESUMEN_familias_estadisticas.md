# ¿Cambiar de familia? Comparación con los datos — cohorte principal

Modelo: `val ~ con * tie + (1|id)` con cuatro verosimilitudes, 69 observaciones de 23 participantes. Semilla 20260925, 4 cadenas × 2000.

## Qué familia describen mejor los datos

| modelo | ΔELPD | EE |
| --- | --- | --- |
| gaussiana_log | 0 | 0 |
| lognormal | -325.4 | 5.7 |
| gamma | -328.3 | 6.1 |
| student | -455.4 | 11.9 |

## ¿Cambia la conclusión según la familia?

| familia | crecimiento T1→T3 | IC 95 % | P(>0) | Audio − Texto | IC 95 % |
| lognormal | 80 | [54.9, 111.1] | 1.000 | 22.9 | [-43.9, 88.5] |
| gamma | 78.3 | [50, 114.7] | 1.000 | 20.7 | [-43.6, 88.8] |
| student | 0 | [-1.1, 1.1] | 0.485 | 0 | [-1.1, 1.1] |
| gaussiana_log | 76.4 | [51.2, 107.7] | 1.000 | 18.3 | [-46.7, 87.6] |

Si el crecimiento se mantiene con las cuatro familias y la diferencia entre modos queda no concluyente
en todas, la elección de familia deja de ser una decisión arbitraria: es una decisión sin consecuencias
sobre la conclusión, y eso conviene declararlo así en el manuscrito.

Fecha: 2026-09-29 18:41
