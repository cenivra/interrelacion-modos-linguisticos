# Robustez y análisis bayesiano — cohorte principal

Participantes: 23 | observaciones: 69
Modelo bayesiano: lognormal multinivel, 4 cadenas × 2000 iteraciones, semilla 20260925.

## Lo que responde al «no hubo cambios»
- **El crecimiento existe y es sustancial.** T1→T3: 80 palabras, intervalo creíble del 95 % [54.9, 111.1]; P(> 0) = 1.000 y P(> 20 palabras) = 1.000 → cambio sustancial.
- **La diferencia entre modalidades no se puede declarar ni descartar.** Audio vs Texto: 22.9 palabras, IC 95 % [-43.9, 88.5]; P(dentro del ROPE ±20 palabras) = 0.372 → no concluyente.
- **El modelo sin el factor modalidad predice igual o mejor** (LOO: gana m_sin, ΔELPD = 4.6): los datos no piden un efecto de modalidad para describirse.
- **Potencia.** Para una diferencia real de 20 palabras, la potencia pasa de 0.09 (n=23) a 0.10 (n=28); para 40 palabras es de 0.26. Con n=28 la diferencia mínima detectable al 80 % es de 85 palabras. Es decir: cinco personas más reducen la incertidumbre pero no convierten en detectable una diferencia pequeña entre modalidades.

## Robustez frecuentista (de la corrida del módulo)
- **Influencia**: el coeficiente del primer paso de tiempo es de 51 palabras y al excluir a 
  cualquier participante se mueve entre 43.1 y 57.9 (cambio máximo 7.9): ninguna persona lo sostiene.
- **MATTR** (diversidad léxica con ventana de 100 palabras): F(2,15.4) = 3.70, p = .049, con medias
  0.651 → 0.662 → 0.667. La diversidad no baja cuando el texto crece: el descenso del TTR era el
  artefacto de longitud.
- **Temas con FDR**: de los diez diccionarios solo *soledad* muestra efecto de tiempo, y sobrevive
  a la corrección por comparaciones múltiples.
- **Bootstrap** por participante (200 réplicas): primer contraste de tiempo IC 95 % [24.2, 80.0] palabras.

## Advertencias declaradas
- La potencia es una **aproximación analítica** basada en el posterior actual y el escalado del error
  estándar con la raíz del número de participantes; no sustituye una simulación con reajustes.
- Algunos modelos de tema presentan **ajuste singular** (varianza de participante cercana a cero).
- Cinco observaciones del modelo principal tienen **Pareto-k > 0.7**; la comparación por LOO se hizo
  con *moment matching*, pero conviene revisarlas si el resultado se reporta.
- Sensibilidad al prior: el coeficiente de tiempo cambia 10.4% al ampliarlo; la conclusión no cambia.

Fecha: 2026-09-29 17:47 | R R version 4.6.1 (2026-06-24 ucrt)
