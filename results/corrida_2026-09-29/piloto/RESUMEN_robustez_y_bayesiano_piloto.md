# Robustez y análisis bayesiano — cohorte piloto

Participantes: 17 | observaciones: 51

## A. Robustez frecuentista
- **A1 Influencia.** Coeficiente del primer paso de tiempo: 38.5; al excluir un participante va de 24.6 a 47 (cambio máximo 13.8999999999997, en piloto_P12).
- **A2 MATTR** (ventana 100): tiempo F(2,9.0)=0.51 p=0.617; medias por momento 0.686 / 0.702 / 0.698. Es la diversidad léxica sin el artefacto de longitud del TTR.
- **A3 Temas con FDR**: 10 evaluados; con varianza cero: rate_desconexion.
- **A5 Bootstrap** (200 réplicas por participante): primer contraste de tiempo IC 95 % [6.4, 79.4].

## B. Capa bayesiana
- **Crecimiento T1→T3**: 19.8 palabras, IC creíble 95 % [-11.9, 53.7], P(> 0) = 0.900 → no concluyente.
- **Diferencia Audio vs Texto**: 36.3 palabras, IC creíble 95 % [-36, 108.7], P(dentro del ROPE ±20 palabras) = 0.259 → no concluyente.
- **Comparación de modelos (LOO)**: mejor modelo = m_bay.
- **Potencia aproximada** (respuesta a «¿cinco personas más cambian algo?»): para una diferencia real de 20 palabras, la potencia pasa de 0.09 (n=23) a 0.11 (n=28) y a 0.13 (n=40). La diferencia mínima detectable al 80 % con n=28 es de 79 palabras; para diferencias pequeñas (20 palabras) haría falta un n muy superior.
- Este es el punto que responde al «no hubo cambios»: lo que la muestra pequeña no puede hacer
  es *declarar* diferencias, no *detectarlas en la estimación*. El crecimiento se estima con un
  intervalo estrecho y lejos de cero; la diferencia entre modos queda, con estos datos, en «no concluyente».

## C. Registro
- Semilla: 20260925 | réplicas de bootstrap: 200 | cadenas: 4 × 2000 iteraciones
- Guion consumido: Experimento ALC_v5_corregido.R
- Fecha: 2026-09-29 18:03 | R R version 4.6.1 (2026-06-24 ucrt)
