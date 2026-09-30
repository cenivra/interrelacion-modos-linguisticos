# Metodología del Pipeline NLP Longitudinal

![Metodología del Pipeline NLP Longitudinal](assets/portada_metodologia_pipeline_nlp.jpg)

**Arquitectura de procesamiento, representación semántica y análisis estadístico longitudinal**

## 1. Diseño analítico y arquitectura general

Se implementó un pipeline longitudinal de procesamiento y análisis de lenguaje natural (*Natural Language Processing*, NLP) orientado a cuantificar cambios en la producción escrita generada bajo tres condiciones experimentales: **Texto, Audio e Imagen**, a través de tres momentos de observación: **T1, T2 y T3**.

El procedimiento computacional integró métodos de análisis lingüístico, análisis léxico-emocional, análisis temático basado en diccionarios, representación semántica mediante embeddings de lenguaje, construcción de prototipos semánticos, reducción dimensional y modelamiento estadístico para medidas repetidas.

La arquitectura del pipeline fue diseñada de forma modular para mantener la trazabilidad entre las distintas etapas de procesamiento, desde la importación y normalización de los datos hasta la generación de variables analíticas, estimación de modelos estadísticos, diagnóstico y exportación de resultados.

De manera general, el flujo de procesamiento siguió la secuencia:

**datos originales → normalización → estructura longitudinal canónica → preprocesamiento textual → tokenización → características lingüísticas → análisis emocional → análisis temático → embeddings semánticos → prototipos semánticos → PCA → variables de cambio → modelos longitudinales → análisis post-hoc → análisis de sensibilidad y diagnóstico → visualización y exportación.**

La unidad básica de análisis fue el texto producido por un participante en una determinada iteración. En consecuencia, las observaciones longitudinales estuvieron anidadas dentro de participantes.

## 2. Estructura de los datos

El procesamiento integró dos fuentes de datos: una **muestra principal** y una **muestra piloto**. La muestra principal comprendió 23 participantes y la muestra piloto 17 participantes. Considerando tres observaciones potenciales por participante, la estructura nominal del conjunto integrado correspondió a 120 observaciones.

La muestra principal estuvo distribuida entre las condiciones Texto, Audio e Imagen y entre dos niveles de demora, identificados como D y ND. La muestra piloto se incorporó como una fuente independiente y conservó una variable de procedencia (`fuente`) destinada a diferenciarla de la muestra principal.

Los datos fueron transformados a una estructura longitudinal canónica que incluyó, entre otras, las siguientes variables:

* `participante`;
* `condicion`;
* `demora`;
* `iteracion`;
* `texto`;
* número de palabras;
* `fuente`;
* identificador individual del participante;
* identificador de observación;
* número acumulado de estímulos.

Se generaron dos representaciones complementarias. La primera correspondió a un formato largo, con una fila por participante, iteración y observación. La segunda correspondió a un formato ancho, en el que las mediciones de T1, T2 y T3 se almacenaron en columnas independientes.

Los identificadores compuestos se construyeron mediante la combinación de la fuente y el identificador del participante y, posteriormente, mediante la incorporación de la iteración. Esta estructura permitió identificar de manera inequívoca cada observación longitudinal.

El número acumulado de estímulos se derivó de la iteración según la correspondencia:

* T1 = 0 estímulos;
* T2 = 1 estímulo;
* T3 = 3 estímulos.

Antes del análisis se realizaron comprobaciones de estructura, tipos de datos, valores permitidos, consistencia entre variables derivadas y duplicación de identificadores.

## 3. Preprocesamiento textual

El procesamiento textual se implementó en R, utilizando el entorno RStudio 2026.08.2+200.

Cada texto fue sometido a una secuencia estandarizada de normalización. En primer lugar, los textos se transformaron a minúsculas. Posteriormente se realizó una transliteración ASCII mediante `iconv`, de modo que los caracteres acentuados y otros caracteres especiales fueran transformados a su representación ASCII correspondiente.

A continuación, se eliminaron los dígitos y los caracteres distintos de letras minúsculas, espacios y guiones mediante expresiones regulares. Finalmente, se realizó una compresión de los espacios consecutivos.

La secuencia operacional comprendió:

1. tratamiento de valores ausentes o cadenas vacías;
2. conversión a minúsculas;
3. transliteración ASCII;
4. eliminación de dígitos;
5. eliminación de puntuación y caracteres no alfabéticos;
6. normalización de espacios.

Cuando fue necesario generar embeddings para textos vacíos, estos fueron representados mediante el marcador `[VACÍO]` con el objetivo de evitar errores durante la comunicación entre R y Python.

No se implementaron procedimientos de *stemming* ni lematización. Tampoco se incorporó una etapa independiente de detección automática del idioma.

Una consecuencia metodológica relevante de esta transformación es que la representación textual utilizada en los análisis léxicos no conserva la información ortográfica asociada con los acentos ni con determinados caracteres propios del español. Esta característica forma parte del procesamiento efectivamente implementado y debe considerarse en la interpretación de los resultados.

## 4. Tokenización y eliminación de palabras funcionales

La tokenización se realizó mediante la separación de los textos normalizados utilizando los espacios en blanco como delimitadores.

Posteriormente se aplicó un filtro mínimo de longitud de tres caracteres. Los tokens con menos de tres caracteres fueron excluidos.

Después de este filtrado se eliminaron las palabras funcionales contenidas en la lista estándar de *stopwords* en español proporcionada por el paquete `stopwords`.

El resultado fue un vector de tokens para cada observación y momento temporal, que constituyó la base de los análisis lingüísticos, emocionales y temáticos posteriores.

## 5. Características lingüísticas

Para cada texto se calcularon medidas descriptivas de su estructura lingüística.

El número de tokens correspondió al número de elementos restantes después de la tokenización, el filtro de longitud y la eliminación de palabras funcionales.

El número de oraciones se estimó mediante la función de delimitación de fronteras oracionales de `stringi`. Se estableció un mínimo de una oración para evitar divisiones por cero en los cálculos posteriores.

La diversidad léxica se estimó mediante el *Type-Token Ratio* (TTR):

$$
TTR = \frac{V}{N}
$$

donde \(V\) representa el número de tipos léxicos únicos y \(N\) el número total de tokens.

También se calculó la longitud media de palabra, expresada como el promedio del número de caracteres de los tokens, así como el número de palabras por oración.

De manera independiente, durante la etapa de normalización se obtuvo un conteo del número de palabras mediante la expresión regular `\\S+`, denominado `n_palabras_calculado`.

Las principales características lingüísticas obtenidas fueron:

* número de palabras;
* número de tokens;
* número de oraciones;
* TTR;
* longitud media de palabra;
* palabras por oración.

Estas variables fueron calculadas de manera independiente para T1, T2 y T3.

## 6. Análisis emocional mediante NRC

El contenido emocional se analizó mediante el **NRC Emotion Lexicon v0.92**, utilizando su versión traducida al español.

El léxico fue incorporado al pipeline mediante su obtención y posterior procesamiento. Se identificó la columna correspondiente a la versión española y se normalizaron las palabras mediante conversión a minúsculas, transliteración ASCII y eliminación de caracteres no alfabéticos.

Se analizaron ocho categorías emocionales:

* ira (*anger*);
* anticipación (*anticipation*);
* disgusto (*disgust*);
* miedo (*fear*);
* alegría (*joy*);
* tristeza (*sadness*);
* sorpresa (*surprise*);
* confianza (*trust*).

Para cada texto, el procedimiento comprendió:

1. aplicación de la misma función de limpieza empleada en el resto del pipeline;
2. tokenización;
3. cálculo de la frecuencia de aparición de cada token;
4. identificación de coincidencias entre los tokens y las categorías emocionales;
5. suma de las frecuencias correspondientes.

Los resultados se expresaron como conteos brutos de palabras asociadas con cada categoría emocional.

Los scores NRC no fueron normalizados por longitud textual. En consecuencia, las diferencias observadas entre textos de distinta extensión deben interpretarse teniendo en cuenta esta característica.

El pipeline contempla adicionalmente una variable de valencia procedente del léxico `bing`. Sin embargo, su construcción no se encuentra documentada con el mismo nivel de detalle en la reconstrucción metodológica disponible, por lo que se considera una medida léxica complementaria.

## 7. Análisis temático basado en diccionarios

Se construyeron diez diccionarios temáticos a partir de categorías derivadas de la estética de Hopper. Los constructos incluidos fueron:

* soledad;
* espera;
* incomunicación;
* objetos;
* emociones negativas;
* luz/sombra;
* pasividad;
* desconexión;
* duda;
* espacio.

Cada categoría se inició a partir de un conjunto de términos semilla definidos en el script.

Posteriormente se implementó un procedimiento de enriquecimiento empírico del vocabulario. Se construyó un corpus tokenizado y se identificaron candidatos utilizando tres criterios mínimos:

* frecuencia global ≥ 5;
* frecuencia documental ≥ 3;
* presencia en al menos 2 participantes.

La asociación entre candidatos y términos semilla se evaluó mediante una medida de información mutua puntual (PMI). Los valores de PMI se promediaron sobre las semillas disponibles para cada categoría. Los candidatos con valores positivos se ordenaron y posteriormente se incorporaron mediante una etapa de aceptación manual.

La estrategia combinó, por tanto, una definición conceptual inicial, una selección estadística de candidatos y una revisión manual del vocabulario.

Para cada observación se calculó el número de tokens pertenecientes a cada categoría temática. Además del conteo bruto, se obtuvo una tasa normalizada por cada 1,000 palabras:

$$
Tasa_{tema} = \frac{N_{tema}}{N_{palabras}} \times 1000
$$

Esta normalización permite reducir la dependencia directa de las diferencias en longitud textual.

También se calcularon medidas de cobertura de los diccionarios y se identificaron términos que aparecían simultáneamente en más de una categoría.

## 8. Representación semántica mediante embeddings

La representación semántica se realizó mediante **Sentence Transformers**, utilizando el modelo preentrenado:

`paraphrase-multilingual-MiniLM-L12-v2`.

El modelo genera representaciones vectoriales de **384 dimensiones**.

La integración entre R y Python se realizó mediante `reticulate`, utilizando la biblioteca `sentence-transformers`.

Los textos fueron procesados en lotes de 32 observaciones. Los embeddings fueron normalizados mediante normalización L2 y almacenados mediante un mecanismo de caché basado en identificadores derivados del contenido para evitar cálculos redundantes.

La normalización L2 puede expresarse como:

$$
\hat{x}=\frac{x}{\|x\|_2}
$$

Se generaron matrices independientes correspondientes a T1, T2 y T3.

## 9. Similitud y cambio semántico

El cambio semántico longitudinal se estimó mediante la comparación de los embeddings obtenidos en los diferentes momentos.

Para dos embeddings normalizados \(x\) y \(y\), la similitud coseno se expresó como:

$$
\cos(x,y)=x \cdot y
$$

debido a la normalización L2.

Se obtuvieron medidas de similitud para:

* T1–T2;
* T2–T3;
* T1–T3.

La divergencia semántica se definió operacionalmente como:

$$
D_{sem}=1-\cos(x,y)
$$

Por tanto, un incremento de la divergencia corresponde a una disminución de la similitud entre las representaciones semánticas de dos momentos.

De manera complementaria, se calcularon medidas de similitud textual basadas en tokens:

* similitud coseno sobre frecuencias léxicas;
* índice de Jaccard.

El índice de Jaccard se definió como:

$$
J(A,B)=\frac{|A \cap B|}{|A \cup B|}
$$

Estas medidas proporcionaron una perspectiva complementaria sobre el cambio textual, diferenciando la similitud léxica directa de la similitud semántica derivada de representaciones vectoriales.

## 10. Prototipos semánticos

Para complementar la representación distribuida de los textos se construyó un conjunto de **20 prototipos semánticos**, organizados en dos grupos.

El primer grupo comprendió diez constructos derivados del marco temático de Hopper:

* soledad;
* espera;
* incomunicación;
* objetos;
* emociones negativas;
* luz/sombra;
* pasividad;
* desconexión;
* duda;
* espacio.

El segundo grupo comprendió diez constructos de carácter clínico o psicológico:

* tristeza;
* miedo;
* ansiedad/malestar;
* esperanza;
* confianza;
* agencia;
* control;
* incertidumbre;
* evitación;
* afrontamiento.

Cada constructo se representó mediante cinco frases definitorias.

Las cinco frases correspondientes a cada constructo fueron transformadas en embeddings y posteriormente promediadas dimensión por dimensión para obtener un centroide:

$$
C_k=\frac{1}{m}\sum_{j=1}^{m}E_j
$$

donde \(E_j\) representa el embedding de cada frase definitoria y \(m=5\).

El centroide fue posteriormente normalizado mediante L2.

La proximidad entre un texto y un prototipo se calculó mediante el producto punto entre el embedding normalizado del texto y el centroide normalizado:

$$
P_{ik}=E_i \cdot C_k
$$

Debido a la normalización de ambos vectores, esta cantidad es equivalente a la similitud coseno.

Para cada constructo se obtuvieron valores de proximidad en T1, T2 y T3. Asimismo, se calcularon cambios longitudinales:

$$
P_{T2-T1}=P_{T2}-P_{T1}
$$

$$
P_{T3-T2}=P_{T3}-P_{T2}
$$

$$
P_{T3-T1}=P_{T3}-P_{T1}
$$

Estos valores representan cambios relativos en la proximidad semántica de los textos respecto de los constructos definidos.

## 11. Reducción dimensional mediante PCA

Para facilitar la representación de las trayectorias semánticas se aplicó un análisis de componentes principales (PCA) sobre la matriz combinada de embeddings correspondiente a los tres momentos.

La matriz incluyó las representaciones de T1, T2 y T3 correspondientes a los casos completos.

Antes del PCA, las variables fueron centradas y escaladas mediante:

```r
prcomp(emb_all, center = TRUE, scale. = TRUE)
```

Se extrajeron las dos primeras componentes principales, PC1 y PC2, y se asignaron nuevamente a cada observación y momento temporal.

La varianza explicada por las componentes se almacenó en el objeto correspondiente del análisis.

Como medida global de desplazamiento semántico se calculó la distancia euclidiana entre T1 y T3 en el plano definido por las dos primeras componentes:

$$
D_{T1,T3}
=
\sqrt{
(PC1_{T3}-PC1_{T1})^2+
(PC2_{T3}-PC2_{T1})^2
}
$$

Esta medida representa el desplazamiento de cada participante dentro del espacio bidimensional determinado por las dos primeras componentes principales.

## 12. Variables longitudinales derivadas

El pipeline generó variables de cambio para las características lingüísticas, emocionales, temáticas y semánticas.

Para una variable \(X\), los cambios absolutos se definieron como:

$$
X_{T2-T1}=X_{T2}-X_{T1}
$$

$$
X_{T3-T2}=X_{T3}-X_{T2}
$$

$$
X_{T3-T1}=X_{T3}-X_{T1}
$$

Para determinadas variables de longitud textual también se calculó el cambio porcentual con respecto al valor inicial.

Cuando el valor inicial fue cero, el cambio porcentual se estableció como no estimable (`NA`).

En el dominio semántico, el cambio se representó mediante divergencia entre embeddings, diferencias de proximidad respecto de prototipos y distancia euclidiana en el espacio PCA.

## 13. Índices y scores heurísticos

El script incorpora diversos scores derivados mediante ponderaciones definidas manualmente. Entre ellos se encuentran:

* `score_influencia_T2`;
* `score_influencia_T3`;
* `score_complejidad`;
* `score_audio_T3`.

Estos índices combinan cambios en variables lingüísticas, emocionales y temáticas mediante ponderaciones predefinidas.

De manera general, su construcción puede representarse como:

$$
Score=\sum_i w_i\Delta X_i
$$

donde \(w_i\) representa la ponderación asignada a cada componente y \(\Delta X_i\) el cambio correspondiente.

Las ponderaciones incluyen contribuciones positivas y negativas de distintas categorías emocionales y temáticas.

Estos indicadores se consideran **variables derivadas o índices heurísticos**, no escalas psicométricas validadas. El pipeline no proporciona evidencia de validación psicométrica, análisis factorial, consistencia interna o validación externa de estos scores.

Su función dentro del procedimiento es principalmente exploratoria y operacional.

## 14. Análisis estadístico longitudinal

### 14.1 Modelo principal

Para evaluar la evolución longitudinal del número de palabras se utilizó un modelo lineal mixto mediante `lmer()`.

El modelo principal correspondió a:

$$
Y_{ij}
=
\beta_0
+\beta_1 Condición_i
+\beta_2 Tiempo_j
+\beta_3(Condición_i\times Tiempo_j)
+u_i+\epsilon_{ij}
$$

y a la fórmula:

```r
valor ~ condicion * tiempo + (1 | id_participante)
```

El outcome principal fue `n_palabras_calculado`.

Los efectos fijos fueron:

* condición experimental: Texto, Audio e Imagen;
* tiempo: T1, T2 y T3;
* interacción condición × tiempo.

Se incorporó un intercepto aleatorio por participante para modelar la dependencia entre las observaciones repetidas del mismo individuo.

Los modelos fueron estimados mediante REML. La optimización utilizó `bobyqa` con un máximo de 200,000 evaluaciones (`maxfun = 2e5`). Los grados de libertad para las pruebas inferenciales se estimaron mediante el procedimiento de Satterthwaite implementado por `lmerTest`.

La interacción condición × tiempo permitió evaluar si la trayectoria longitudinal difería entre las condiciones experimentales.

### 14.2 Comparaciones post-hoc

Cuando fue necesario descomponer los efectos de los factores, se calcularon medias marginales estimadas mediante `emmeans`.

Se consideraron dos conjuntos principales de comparaciones:

* comparación entre condiciones dentro de cada momento temporal;
* comparación entre momentos temporales dentro de cada condición.

Los contrastes por pares se calcularon mediante `pairs()`, utilizando ajuste de Tukey para controlar la multiplicidad dentro de estos contrastes.

### 14.3 Corrección por comparaciones múltiples

Además del ajuste de Tukey aplicado a las comparaciones post-hoc, determinados conjuntos de pruebas múltiples fueron sometidos a corrección de la tasa de falsos descubrimientos mediante el procedimiento FDR de Benjamini–Hochberg:

```r
p.adjust(method = "fdr")
```

La utilización de ambos procedimientos responde a niveles diferentes del análisis: Tukey se empleó en las comparaciones post-hoc derivadas de las medias marginales, mientras que FDR se aplicó a los conjuntos de pruebas múltiples contemplados por el pipeline.

### 14.4 Tamaño del efecto

Para los modelos mixtos se obtuvieron medidas de \(R^2\) mediante `r2_nakagawa()`, diferenciando entre:

* **\(R^2\) marginal:** varianza explicada por los efectos fijos;
* **\(R^2\) condicional:** varianza explicada conjuntamente por los efectos fijos y aleatorios.

Estas medidas se utilizaron como indicadores complementarios a las pruebas de significación estadística.

## 15. Análisis de correlación

Se calcularon correlaciones de Spearman entre variables de cambio.

El análisis se aplicó principalmente a los cambios longitudinales de variables lingüísticas y emocionales, incluyendo las diferencias T1–T2 y T2–T3.

Las correlaciones se calcularon mediante:

```r
cor(..., method = "spearman", use = "pairwise.complete.obs")
```

Se generó una matriz de correlaciones que posteriormente fue exportada para análisis y visualización.

El uso del coeficiente de Spearman permitió evaluar asociaciones monotónicas sin requerir normalidad bivariada.

## 16. Bootstrap del modelo principal

Para complementar la inferencia paramétrica del modelo principal se implementó un bootstrap paramétrico mediante `bootMer()`.

El procedimiento utilizó:

* 500 réplicas;
* semilla 123;
* extracción de los coeficientes de efectos fijos mediante `fixef`;
* remuestreo paramétrico de la estructura del modelo;
* intervalos de confianza percentiles del 95%.

Los límites de los intervalos correspondieron a los percentiles 2.5 y 97.5 de la distribución bootstrap.

El procedimiento bootstrap se aplicó específicamente al modelo principal del número de palabras.

## 17. Diagnóstico de residuos y detección de observaciones extremas

La identificación de observaciones potencialmente influyentes se realizó utilizando residuos del modelo principal.

Se estableció como criterio operacional:

$$
|r_i|>2.5
$$

Las observaciones que superaron este umbral fueron identificadas y se estimó un modelo alternativo excluyéndolas.

La comparación entre el modelo original y la especificación sin observaciones extremas se realizó mediante indicadores como:

* AIC;
* BIC;
* \(R^2\).

Este procedimiento no implicó considerar automáticamente una observación extrema como un error. Su propósito fue evaluar la sensibilidad de las estimaciones frente a observaciones potencialmente influyentes.

## 18. Diagnóstico y validación computacional

El pipeline incorpora procedimientos de validación en distintos niveles.

### Validación estructural

Se comprobaron:

* existencia de columnas requeridas;
* tipos de variables;
* valores permitidos;
* correspondencia entre iteración y número de estímulos;
* duplicación de identificadores;
* número esperado de participantes y observaciones;
* distribución de los datos por fuente y condición;
* valores faltantes estructurales frente a valores faltantes inesperados.

### Validación del léxico

El léxico NRC-ES fue sometido a comprobaciones relacionadas con:

* estructura;
* presencia de las ocho categorías emocionales;
* tipos de datos;
* ausencia de valores `NA`;
* ausencia de duplicados;
* caracteres permitidos;
* tamaño mínimo del vocabulario;
* posibilidad de serialización.

### Diagnóstico de modelos

Se evaluaron:

* convergencia;
* singularidad;
* residuos frente a valores ajustados;
* distribución de residuos;
* gráficos Q-Q;
* distribución de interceptos aleatorios;
* prueba de Shapiro-Wilk como procedimiento diagnóstico complementario.

Estos procedimientos tuvieron como objetivo identificar problemas computacionales o estructurales en los modelos y no sustituyen la evaluación sustantiva de sus supuestos estadísticos.

## 19. Análisis de sensibilidad

Se implementaron cinco especificaciones alternativas para evaluar la estabilidad del resultado principal frente a diferentes decisiones analíticas.

### Modelo con demora

Se incorporó la variable `demora` como covariable:

$$
valor \sim condicion * tiempo + demora + (1|participante)
$$

### Modelo logarítmico

Se utilizó una transformación logarítmica de la variable dependiente:

$$
\log(valor) \sim condicion * tiempo + (1|participante)
$$

La transformación se aplicó únicamente cuando los valores observados permitieron su utilización.

### Modelo basado en número de tokens

Se utilizó `log(n_tokens)` como variable dependiente, proporcionando una alternativa al número bruto de palabras.

### Modelo basado en exposición acumulada

La variable categórica `tiempo` se sustituyó por `n_estimulos`, con valores 0, 1 y 3, con el objetivo de evaluar si la evolución podía representarse de manera directamente relacionada con la exposición acumulada a estímulos.

### Modelo sin observaciones extremas

Se reestimó el modelo después de excluir las observaciones que superaron el criterio operacional de:

$$
|residuo|>2.5
$$

Para cada especificación alternativa se obtuvieron indicadores comparables, incluyendo AIC, BIC y medidas de \(R^2\).

## 20. Comparación entre muestra piloto y muestra principal

La muestra piloto y la muestra principal fueron analizadas inicialmente como fuentes diferenciadas.

Se realizó una evaluación de las variables disponibles para determinar si existían condiciones suficientes para su análisis, considerando aspectos como número de participantes, variabilidad y rango observado.

Posteriormente se estimaron modelos longitudinales para las variables que cumplían los criterios establecidos.

Para evaluar diferencias en las trayectorias entre ambas fuentes se implementó un modelo que incorporó la interacción entre fuente, condición y tiempo:

$$
valor \sim fuente * condicion * tiempo + (1|id_{fuente})
$$

La interacción `fuente:tiempo` se examinó como indicador de posibles diferencias en la evolución temporal entre la muestra piloto y la muestra principal. Los valores de significación se ajustaron mediante Holm.

Esta comparación se interpreta como un procedimiento de evaluación de consistencia entre fuentes y no como una sustitución del análisis específico correspondiente al diseño experimental original.

## 21. Visualización

El pipeline generó un conjunto de 15 figuras científicas en versiones en español e inglés.

Las visualizaciones incluyeron:

* evolución del número de palabras por condición;
* evolución del número de palabras según demora;
* evolución de indicadores emocionales;
* TTR por condición;
* medias marginales estimadas;
* distribución de scores heurísticos;
* matriz de correlaciones de Spearman;
* cambios T1–T2 y T2–T3;
* trayectorias individuales;
* interacción condición × tiempo;
* efecto de demora sobre el cambio;
* evolución multivariada de las emociones;
* evolución de los diccionarios temáticos;
* similitud textual mediante coseno y Jaccard;
* mapa integrado de cambios estandarizados.

Las figuras fueron generadas mediante `ggplot2` y exportadas en formato PNG a 300 dpi y en PDF mediante `cairo_pdf`.

## 22. Exportación y trazabilidad

El pipeline conserva productos analíticos intermedios y resultados finales.

Entre los productos generados se incluyen:

* datos en formato largo y ancho;
* tablas de cambios;
* resultados emocionales;
* resultados de diccionarios temáticos;
* estadísticos descriptivos;
* resultados de modelos mixtos;
* medias marginales estimadas;
* correlaciones;
* valores de significación ajustados;
* modelos estadísticos serializados;
* embeddings;
* prototipos semánticos;
* figuras;
* diagnósticos;
* registros de procesamiento y trazabilidad.

La estructura de exportación permite mantener la correspondencia entre las distintas etapas del procesamiento y los productos derivados de cada una de ellas.

## 23. Reproducibilidad computacional

El análisis fue implementado principalmente en R, con integración de Python mediante `reticulate` para la generación de embeddings.

Se estableció una semilla general mediante:

```r
set.seed(20260526)
```

y una semilla específica para el procedimiento bootstrap.

Los embeddings se almacenaron mediante un sistema de caché con el propósito de evitar cálculos redundantes.

El entorno Python utilizado incorpora `sentence-transformers`, y el pipeline contempla la instalación condicional de paquetes R cuando estos no se encuentran disponibles.

El procedimiento genera registros de ejecución y archivos de trazabilidad destinados a documentar las principales etapas del procesamiento.

Las características del entorno y de las dependencias condicionan la reproducibilidad exacta del análisis. En particular, deben considerarse las versiones de R y de los paquetes, la configuración del entorno Python y la disponibilidad de recursos externos empleados durante el procesamiento.

La reproducibilidad computacional exacta requiere, por tanto, fijar de forma explícita las versiones de software, dependencias, modelos y recursos externos, además de mantener rutas de ejecución independientes de configuraciones locales.

## 24. Clasificación metodológica del pipeline

En conjunto, el procedimiento puede caracterizarse como un **pipeline multimétodo de NLP longitudinal**, compuesto por cuatro niveles analíticos complementarios.

### Nivel 1. Análisis léxico-lingüístico

Incluye:

* número de palabras;
* número de tokens;
* número de oraciones;
* TTR;
* longitud media de palabra;
* palabras por oración.

### Nivel 2. Análisis léxico-emocional y temático

Incluye:

* NRC Emotion Lexicon;
* diccionarios temáticos;
* conteos emocionales;
* tasas temáticas por 1,000 palabras.

### Nivel 3. Representación semántica distribuida

Incluye:

* embeddings de Sentence Transformers;
* similitud coseno;
* divergencia semántica;
* similitud textual;
* prototipos semánticos;
* proximidad a constructos;
* PCA;
* distancia euclidiana.

### Nivel 4. Inferencia longitudinal

Incluye:

* modelos lineales mixtos;
* interacción condición × tiempo;
* medias marginales estimadas;
* contrastes post-hoc;
* corrección por comparaciones múltiples;
* bootstrap paramétrico;
* análisis de correlación;
* análisis de sensibilidad;
* diagnóstico de residuos.

Esta arquitectura permite analizar simultáneamente la magnitud del cambio textual, las características lingüísticas asociadas, los patrones léxico-emocionales y temáticos y el desplazamiento de las representaciones textuales dentro de un espacio semántico.

## 25. Consideraciones metodológicas para la interpretación

Los resultados generados por el pipeline deben interpretarse considerando la naturaleza de cada tipo de variable.

Los indicadores lingüísticos constituyen medidas cuantitativas derivadas directamente de la producción textual.

Los scores emocionales obtenidos mediante NRC representan frecuencias de coincidencias léxicas y no deben interpretarse automáticamente como medidas psicométricas de estados emocionales.

Los scores temáticos representan frecuencias de términos pertenecientes a categorías léxicas definidas conceptualmente y posteriormente enriquecidas mediante información derivada del corpus.

Las proximidades respecto de prototipos representan similitud semántica con constructos definidos mediante frases de referencia. En consecuencia, expresan proximidad representacional y no constituyen indicadores clínicos ni diagnósticos.

Los scores de influencia, complejidad y audio constituyen índices heurísticos derivados de ponderaciones manuales. No deben considerarse escalas psicométricas ni medidas validadas en ausencia de evidencia específica de validación.

## 26. Síntesis de la metodología

El procedimiento permitió transformar producciones textuales longitudinales en un conjunto integrado de indicadores lingüísticos, emocionales, temáticos y semánticos.

La estrategia combinó métodos basados en frecuencia y diccionarios con representaciones semánticas distribuidas mediante embeddings. Esta integración permitió estudiar el fenómeno desde dos perspectivas complementarias: una perspectiva léxica, basada en las unidades lingüísticas efectivamente observadas, y una perspectiva semántica, basada en la posición de cada texto dentro de un espacio vectorial de representación.

La dimensión longitudinal se incorporó mediante comparaciones entre T1–T2, T2–T3 y T1–T3, mientras que la dependencia derivada de las mediciones repetidas se modeló mediante interceptos aleatorios por participante.

Finalmente, la estabilidad de los resultados se examinó mediante bootstrap, diagnóstico de residuos, identificación de observaciones potencialmente influyentes, especificaciones estadísticas alternativas y comparación entre las muestras piloto y principal.

En conjunto, el pipeline constituye una arquitectura computacional multimétodo que integra preprocesamiento textual, análisis léxico, análisis emocional, análisis temático, representación semántica mediante embeddings, construcción de prototipos conceptuales, reducción dimensional y modelamiento longitudinal mediante efectos mixtos. Su organización modular permite mantener la correspondencia entre las transformaciones realizadas, las variables derivadas, los modelos estimados y los productos analíticos resultantes.
