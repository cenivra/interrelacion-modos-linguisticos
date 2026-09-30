# Resultados integrados en el repositorio

**Origen de los resultados:** ejecución completa y verificada del pipeline v5.9, identificada mediante el hash `1143b36a…`, aplicada a textos procedentes de participantes reales.

El presente documento establece el alcance de los materiales incorporados al repositorio de resultados, así como los criterios utilizados para determinar su admisibilidad, exclusión y conservación.

## Política de admisibilidad

Se consideran admisibles para integración en el repositorio los siguientes tipos de materiales:

* informes y documentos derivados del análisis;
* figuras en sus versiones ES/EN y en formatos PNG y PDF;
* tablas agregadas por grupo, modelo o efecto;
* objetos de modelo que no contengan estructuras con una fila por participante u observación, incluyendo específicamente la exclusión de los slots `datos` y `diagnosticos`, pero conservando el modelo, ANOVA, R², medias marginales estimadas y contrastes;
* centroides de prototipos semánticos;
* registros de ejecución;
* inventarios y manifiestos de trazabilidad.

No se consideran admisibles:

* archivos que contengan texto escrito por participantes;
* tablas con una fila por observación o por participante, incluso cuando la información contenida sea exclusivamente numérica;
* insumos crudos de análisis, incluyendo archivos `.xlsx`, léxicos y volcados `.RData`;
* árboles o directorios duplicados derivados de copias del material de trabajo;
* residuos o artefactos temporales de sesión.

Además de estos criterios de contenido, cada archivo candidato fue sometido a una comprobación específica de seguridad del contenido. Cuando algún campo de texto contiene una cadena superior a 200 caracteres, el archivo se considera no admisible.

Para los objetos `.rds` correspondientes a modelos se aplica una comprobación adicional: se recorre la estructura del objeto y se contabilizan las cadenas de texto superiores a 120 caracteres. El criterio de admisibilidad exige que el número de cadenas que superan dicho umbral sea **cero**.

## Materiales integrados

Se integraron **140 archivos** en el conjunto de resultados.

El inventario correspondiente, que registra rutas, tamaños y valores SHA-256, se encuentra en:

```text
manifests/INVENTARIO_RESULTADOS.csv
```

Este inventario constituye la referencia para identificar los archivos efectivamente incorporados y facilitar su trazabilidad dentro del repositorio.

## Documentos de resultados (manuscritos)

Los tres manuscritos de resultados se almacenan junto con los materiales gráficos correspondientes a cada cohorte. De esta manera, cada directorio constituye un paquete autocontenido que reúne el documento y las figuras que este referencia.

| Documento                                 | Ruta                            | Páginas | Figuras |
| ----------------------------------------- | ------------------------------- | ------: | ------: |
| Resultados del estudio piloto (n = 17)    | `results/piloto/manuscrito/`    |      17 |       4 |
| Resultados del estudio principal (n = 23) | `results/principal/manuscrito/` |      19 |      10 |
| Resultados del conjunto (17 + 23)         | `results/combinado/manuscrito/` |      22 |      14 |

Los tres manuscritos especifican explícitamente:

* la cohorte correspondiente al análisis;
* que el conjunto total de 40 participantes corresponde a **dos muestras independientes** y no a una única muestra de tamaño 40;
* que las figuras rotuladas como *sentimiento global* utilizan *tristeza* como sustituto declarado, debido a que el pipeline no calculó una medida de sentimiento del tipo Bing o VADER;
* que el criterio de identificación de casos influyentes resulta inoperante para el modelo del conjunto, debido a que fueron marcadas 115 de las 120 observaciones.

Los manuscritos y sus materiales asociados contienen exclusivamente resultados agregados. No se incorporan celdas con texto producido por participantes ni tablas estructuradas con una fila individual por participante.

## Manuscritos: no versionados por decisión editorial

Los manuscritos de resultados (piloto, principal y combinado) **no se versionan** en este repositorio: el
autor principal los enviará a una revista y no deben estar publicados antes de su aparición. Permanecen
únicamente en la copia de trabajo local, en `resultados en latex/<cohorte>/`, con sus figuras.

`tests/check_hashes.sh` comprueba que las seis rutas de manuscrito estén **ausentes**; si alguna reaparece
en el árbol, la comprobación falla.

## Resultados de la corrida del 29 de septiembre de 2026

Los cuatro análisis de robustez, capa bayesiana y familias nuevas de la **corrida principal (23 participantes)**
se ejecutaron el **29 de septiembre de 2026 entre las 17:37:59 y las 18:45:44** (UTC−6) y están versionados en
`results/corrida_2026-09-29/`: informe (`INFORME_2026-09-29.md`), 10 figuras, 21 tablas CSV, 5 registros con
marca de fecha y hora, y los resúmenes por bloque, además de la cohorte piloto. Los guiones viven en
`code/analisis_nuevos/`.

Estos análisis **no modifican la corrida original**: leen sus artefactos. Los modelos bayesianos ajustados
(objetos `brmsfit`, varios megas) no se versionan por tamaño; se reproducen con los guiones y la semilla
`20260925` indicada en el informe.

## Materiales excluidos y justificación

Los siguientes archivos, identificados durante la ejecución del pipeline, fueron excluidos del conjunto integrado por las razones indicadas:

| Archivo identificado en la corrida              | Motivo de exclusión                                                                                            |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `logs/ejecucion_v5_20260925_1910_v59_final.log` | Contiene 2 celdas con texto superior a 200 caracteres.                                                         |
| `resultados/tablas/datos_completos_ancho.csv`   | Contiene las columnas `texto_t1`, `texto_t2` y `texto_t3`, correspondientes a las narrativas de participantes. |
| `resultados/tablas/datos_formato_largo.csv`     | Contiene la columna `texto`, correspondiente a las narrativas de participantes.                                |

La exclusión se realizó con independencia del formato técnico del archivo: la presencia de contenido textual de participantes constituye por sí misma un criterio suficiente para impedir su incorporación al conjunto público de resultados.

## Materiales no encontrados

Durante la comprobación del conjunto de resultados se identificaron como no disponibles los siguientes archivos esperados:

```text
modelo limpio: modelos_comparativos.rds
modelo limpio: modelos_piloto.rds
modelo limpio: modelos_principal.rds
resultados/modelos/modelos_mixtos.rds
```

Estos archivos no forman parte del inventario de materiales integrados y, por tanto, no deben considerarse artefactos disponibles del repositorio hasta que exista una versión identificable y verificable de los mismos.

