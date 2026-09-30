#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Documento de Word que explica los resultados nuevos de la corrida principal
(23 participantes), escrito para el autor principal: sin jerga de NLP y con una
sección que aclara, sin ambigüedad, si esto es inteligencia artificial y de qué
tipo — porque sí es IA, pero no IA generativa como ChatGPT.
"""
import os, sys, glob
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

A = r"C:\Users\saraq\Downloads\Experimento Alfonso Lopez Corral\Analisis agosto v2"
FIG = os.path.join(A, "figuras_nuevas")
SALIDA = r"C:\Users\saraq\Downloads\Experimento Alfonso Lopez Corral\Explicacion_resultados_nuevos.docx"

doc = Document()
est = doc.styles["Normal"]
est.font.name = "Calibri"
est.font.size = Pt(11)

def h(txt, nivel=1):
    p = doc.add_heading(txt, level=nivel)
    return p

def par(txt, negrita=False, cursiva=False, tam=11, color=None, esp=6):
    p = doc.add_paragraph()
    r = p.add_run(txt)
    r.bold = negrita; r.italic = cursiva; r.font.size = Pt(tam)
    if color: r.font.color.rgb = RGBColor(*color)
    p.paragraph_format.space_after = Pt(esp)
    return p

def bullets(items):
    for it in items:
        p = doc.add_paragraph(it, style="List Bullet")
        p.paragraph_format.space_after = Pt(3)

def figura(nombre, pie, ancho=16.5):
    ruta = os.path.join(FIG, nombre)
    if not os.path.exists(ruta):
        par(f"[Figura pendiente: {nombre}]", cursiva=True, color=(0x80, 0x80, 0x80))
        return
    doc.add_picture(ruta, width=Cm(ancho))
    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
    p = doc.add_paragraph()
    r = p.add_run(pie)
    r.italic = True; r.font.size = Pt(9); r.font.color.rgb = RGBColor(0x55, 0x55, 0x55)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(10)

# ------------------------------------------------------------------ portada
t = doc.add_heading("Qué se hizo de nuevo y qué significan los resultados nuevos", level=0)
par("Estudio de interrelación de modos lingüísticos — corrida principal, 23 participantes",
    negrita=True, tam=12)
par("Documento de trabajo para el autor principal. Explica, en palabras llanas, los cuatro análisis nuevos "
    "que se agregaron a la corrida principal, qué encontró cada uno y qué implica para las conclusiones del "
    "estudio. Incluye una sección inicial que aclara si esto es inteligencia artificial, y de qué tipo.", esp=12)

# ------------------------------------------- 1. ¿Esto es inteligencia artificial?
h("1. ¿Esto es inteligencia artificial? Sí, pero no como ChatGPT", 1)
par("La respuesta corta es que sí: el análisis de textos del estudio usa inteligencia artificial, y la usa desde "
    "una de las tradiciones fundadoras del campo. Pero no usa inteligencia artificial generativa, que es la de "
    "ChatGPT. Ninguna palabra de los textos que analizamos la escribió un programa: las escribieron los 23 "
    "participantes. La distinción importa y aquí va explicada por partes.")

h("Qué hacía la inteligencia artificial cuando nació", 2)
par("El procesamiento de lenguaje natural es una de las áreas con las que nació la inteligencia artificial, hacia "
    "los años cincuenta. Su primer gran problema fue la traducción automática entre idiomas: darle a una máquina "
    "un texto en un idioma para obtenerlo en otro. Es la misma idea que está detrás de las imágenes que abren esta "
    "presentación: la piedra de Rosetta, las máquinas que escriben, el esfuerzo humano por hacer que una máquina "
    "trate con el lenguaje. Durante décadas esos programas funcionaron con reglas escritas a mano; después, con "
    "estadística sobre grandes colecciones de texto; y desde los años diez, con redes neuronales. Las tres etapas "
    "son inteligencia artificial, y las tres siguen en uso.")

h("Qué hace aquí la inteligencia artificial: medir, no escribir", 2)
par("El análisis del estudio hace tres cosas, y sólo la primera es inteligencia artificial de la familia "
    "neuronal:",
    esp=4)
bullets([
    "Convierte cada texto en una lista de números (lo que llamamos embeddings). Eso lo hace una red neuronal "
    "entrenada con millones de textos en muchos idiomas, y es el único componente verdaderamente neuronal del "
    "análisis. Su trabajo es representar el significado: dos textos que hablan de lo mismo quedan cerca en esa "
    "lista de números. Es un instrumento de medida, no un redactor.",
    "Cuenta palabras con diccionarios construidos para el estudio (los temas: soledad, espera, objetos, etcétera). "
    "Esto es conteo sobre listas, y no es inteligencia artificial; es el mismo principio que un índice al final "
    "de un libro, sólo que hecho por computadora.",
    "Ajusta modelos estadísticos para estimar cómo cambia el texto con el tiempo, con la condición y entre "
    "personas. Esto tampoco es inteligencia artificial: es estadística, y es la parte que sostiene las "
    "conclusiones del estudio.",
])

h("Por qué no es IA generativa", 2)
par("La inteligencia artificial generativa produce contenido: escribe párrafos, responde preguntas, inventa "
    "imágenes. Un modelo como ChatGPT, ante una petición, redacta texto nuevo. Aquí no se genera ni una frase. "
    "El programa recibe textos que ya existen —los de los participantes— y devuelve números: similitudes, "
    "proporciones, conteos, estimaciones. Nadie escribió con ayuda de un modelo generativo, y por eso la autoría "
    "de los textos es de los participantes sin ninguna duda. Si quisiéramos una analogía, el modelo de embeddings "
    "es como un traductor de significados que convierte cada texto en coordenadas; el resto del análisis es "
    "aritmética y estadística sobre esas coordenadas.", esp=12)

# ------------------------------------------------- 2. qué se agregó y por qué
h("2. Qué se agregó y por qué", 1)
par("El autor leyó el resultado nulo como «no hubo cambios». Un valor p por sí solo no puede decir eso: sólo "
    "informa si lo observado es compatible con el azar. No dice cuánto cambió, ni si ese cambio importa, ni si el "
    "estudio tenía fuerza para verlo. Los cuatro análisis que siguen responden esas preguntas con los mismos datos, "
    "sin cambiar la corrida original ni una cifra de lo ya presentado.")

# --------------------------------------------------------- 3. robustez
h("3. Robustez: ¿el resultado depende de alguien o de algo mal medido?", 1)
h("3.1 Ninguna persona sostiene el efecto", 2)
par("Se repitió el análisis excluyendo a cada participante, uno por uno. El coeficiente de crecimiento vale 51 "
    "palabras; al quitar a cualquier persona se mueve entre 43.1 y 57.9, es decir, siete palabras y media en el "
    "peor caso. El hallazgo es colectivo.")
figura("F1_influencia.png", "Figura 1. Coeficiente de crecimiento al excluir a cada participante. La banda roja marca el rango "
                            "observado; la línea punteada, el valor original (51 palabras).")

h("3.2 La diversidad léxica no baja: el problema era el índice", 2)
par("El análisis original decía que baja la proporción de palabras distintas. Esa proporción —el TTR— depende de la "
    "longitud del texto: mientras más se escribe, más palabras se repiten, aunque el vocabulario no se empobrezca. "
    "Con un índice que mide en ventanas fijas de 100 palabras (MATTR) la diversidad no baja, sube ligeramente: "
    "0.651, 0.662 y 0.667 en T1, T2 y T3 (efecto de tiempo p = .049). Dos corridas del mismo estudio dan resultados "
    "opuestos con TTR y coinciden con MATTR; por eso el descenso hay que leerlo como efecto de la longitud.")
figura("F2_mattr_ttr.png", "Figura 2. El índice sensible a la longitud (rojo) baja mientras el índice robusto (verde) sube. "
                            "La diferencia es el artefacto de medición.")

h("3.3 Diez diccionarios, una sola señal", 2)
par("Al probar diez diccionarios se hacen diez pruebas y alguna puede salir significativa por azar. Con la "
    "corrección por comparaciones múltiples (FDR), sólo soledad conserva su efecto de tiempo (p = .029); los otros "
    "nueve no muestran señal. Es un resultado más exigente que el original, no menos.")
figura("F3_fdr.png", "Figura 3. Valor p de cada diccionario antes (gris) y después (azul) de la corrección. Sólo soledad cruza "
                      "el umbral convencional después de corregir.")

# --------------------------------------------------------- 4. bayesiano
h("4. La capa bayesiana: tres respuestas en lugar de dos", 1)
par("Un contraste tradicional responde «sí» o «no». La inferencia bayesiana responde sobre el tamaño del efecto y "
    "permite una tercera respuesta: «no concluyente», que es distinta de «sin efecto» y es la que corresponde "
    "cuando el estudio no tuvo fuerza para ver. Con la zona de equivalencia práctica (ROPE) se fija de antemano qué "
    "diferencia sería irrelevante; aquí, ±20 palabras.")
bullets([
    "Crecimiento de T1 a T3: 80 palabras, intervalo creíble del 95 % de 54.9 a 111.1; probabilidad de superar 20 "
    "palabras = 1.000. Lectura: cambio sustancial.",
    "Audio frente a Texto: 22.9 palabras, intervalo de −43.9 a 88.5; probabilidad de caer dentro de la zona "
    "irrelevante = 0.372. Lectura: no concluyente, ni se afirma ni se descarta.",
    "Comparación de modelos: el modelo sin el factor modalidad predice mejor que el que lo incluye. Los datos no "
    "necesitan la modalidad para describirse, lo que refuerza la lectura anterior.",
    "Sensibilidad al prior: al ampliarlo, el coeficiente de tiempo cambia 10.4 %; la conclusión no cambia.",
])
figura("F4_posteriores.png", "Figura 4. Distribución posterior del crecimiento (izquierda) y de la diferencia Audio − Texto "
                             "(derecha). El punteado rojo delimita la zona de equivalencia práctica.")

h("4.1 ¿Y cinco participantes más cambian algo?", 2)
par("Para la comparación entre modalidades, no. Con 23 participantes, la probabilidad de detectar una diferencia "
    "real de 20 palabras es 0.09; con los cinco participantes nuevos sube a 0.10. Para una diferencia de 40 "
    "palabras, de 0.22 a 0.26. Para tener 80 % de potencia con 28 participantes habría que poder detectar "
    "diferencias de unas 85 palabras, que es enorme. Los cinco participantes nuevos sirven para estrechar el "
    "intervalo del crecimiento —que ya es sólido—, no para volver detectable una diferencia pequeña entre "
    "modalidades. El cálculo es una aproximación analítica basada en la distribución posterior actual y se declara "
    "como tal; la simulación formal con reajustes es el paso siguiente si se desea el número exacto.")
figura("F5_potencia.png", "Figura 5. Potencia según el tamaño de muestra para dos tamaños de diferencia real. La línea punteada "
                          "marca la muestra con los cinco participantes nuevos.")

# --------------------------------------------------------- 5. familias nuevas
h("5. Familias nuevas a partir del artículo: los modos en el texto y el Referente AB", 1)
par("El artículo sostiene que la escritura se habilita leyendo, escuchando u observando, y que el texto se apoya en "
    "un referente que se va elaborando. El estudio medía el contenido de los textos, pero no medía los modos. Se "
    "construyeron cuatro diccionarios para eso —observar, escuchar, leer, imaginar; 94 términos— y un índice que "
    "combina los tres modos.")
bullets([
    "Ninguno cambia de T1 a T3 (p entre .61 y .98; el índice de los tres modos p = .60). Escribir más no es "
    "escribir más sobre los modos.",
    "El vocabulario visual es el más presente (de 5.35 a 6.82 por mil palabras), después el auditivo y al final el "
    "textual: coherente con la estética de las imágenes de Hopper que usó el estudio.",
    "Lo que sí aparece es el encadenamiento: del vocabulario de contenido de T3, 0.68 ya estaba en el texto "
    "anterior, frente a 0.58 en el paso previo, y el contenido nuevo baja de 0.42 a 0.32. Es exactamente la "
    "elaboración del Referente AB que predice el artículo, aunque con 23 participantes la prueba pareada no alcanza "
    "significancia (p = .27) y se reporta como tendencia direccional.",
])
figura("F6_elaboracion.png", "Figura 6. Lo que reaparece del texto anterior y lo que es contenido nuevo, en los dos pasos de "
                             "escritura.")
figura("F7_modos.png", "Figura 7. Menciones de cada modo lingüístico por mil palabras en los tres momentos. Las cuatro líneas "
                       "quedan planas: no hay efecto del tiempo.")

# --------------------------------------------------------- 6. dos instrumentos
h("6. El instrumento de medida, probado dos veces", 1)
par("Todo el análisis semántico dependía de un solo modelo de embeddings, y eso es una vulnerabilidad: si el modelo "
    "tiene un sesgo, el resultado lo hereda. Se repitió con una medida que no usa ningún modelo —sólo coincidencia "
    "de palabras (TF-IDF)— y con un segundo modelo de otra arquitectura (MPNet, 768 dimensiones, frente al MiniLM "
    "de 384 del análisis original). Los tres coinciden en el orden: el par T2–T3 es el más parecido, después "
    "T1–T2, y el menos parecido T1–T3. Con dos instrumentos independientes de acuerdo, el hallazgo semántico no es "
    "un artefacto del instrumento.")
figura("F8_dos_instrumentos.png", "Figura 8. Similitud entre momentos con tres instrumentos distintos. El orden coincide en los "
                                  "tres casos.")

h("6.1 ¿Y si cambiamos la familia estadística?", 2)
par("Se repitió el mismo modelo con cuatro verosimilitudes distintas: la lognormal que se usó, una gamma, una t "
    "de Student y una gaussiana sobre el logaritmo. La pregunta es si la conclusión depende del supuesto sobre la "
    "forma del ruido; con textos que van de 47 a 378 palabras, ese supuesto no es un detalle.")
bullets([
 "El crecimiento queda entre 76 y 80 palabras según la familia, con intervalos que se superponen: cambio "
 "sustancial en todas.",
 "El contraste Audio − Texto queda entre 18 y 23 palabras, con el intervalo cruza el cero en todas: no "
 "concluyente en todas.",
 "Comparadas por LOO, la lognormal y la gamma son indistinguibles (diferencia de 3 unidades con error de 6); la "
 "gaussiana sobre el logaritmo no es comparable por LOO con las anteriores porque su variable es el logaritmo, "
 "no el conteo, y eso se declara en lugar de presentarse como una ventaja.",
 "La t de Student de la primera corrida colapsó a cero porque su prior de intercepto estaba en la escala del "
 "logaritmo mientras el modelo se ajustaba sobre palabras; se corrigió la escala y se reajustó aparte.",
])
figura("F9_familias.png", "Figura 9. Crecimiento y contraste entre modalidades según la familia estadística. Los intervalos "
                          "se superponen y el contraste cruza el cero en todas.", ancho=16.0)

# --------------------------------------------------------- 7. qué cambia
h("7. Qué cambia y qué no cambia", 1)
doc.add_paragraph()
tbl = doc.add_table(rows=1, cols=3)
tbl.style = "Light Grid Accent 1"
enc = tbl.rows[0].cells
enc[0].text = "Resultado"; enc[1].text = "Lectura anterior"; enc[2].text = "Lectura con los análisis nuevos"
datos = [
 ("Crecimiento del texto", "Efecto sólido del tiempo", "Se mantiene y se cuantifica: 80 palabras, IC 95 % [54.9, 111.1]; cambio sustancial. Ninguna persona lo sostiene."),
 ("Diversidad léxica", "Baja la proporción de palabras distintas", "Se corrige: no baja. El descenso del TTR era efecto de la longitud (MATTR p = .049)."),
 ("Diferencia entre modalidades", "Ausencia de efecto", "No concluyente, no ausencia: potencia insuficiente, y los cinco participantes nuevos no la resuelven."),
 ("Demora", "Sin efecto detectable", "Se mantiene, con el número: sólo se detectarían diferencias mayores a unas 85 palabras."),
 ("Temas", "Soledad con efecto de tiempo", "Se mantiene y se refuerza: sobrevive a la corrección por diez pruebas (p FDR = .029)."),
 ("Modos lingüísticos", "No se medían", "Se miden: no aumentan con el tiempo; el vocabulario visual domina."),
 ("Elaboración entre textos", "No se medía", "Se mide: crece el apoyo en la versión previa (0.58 → 0.68), como predice el Referente AB."),
 ("Dependencia del instrumento", "No se había probado", "Se prueba con tres instrumentos: el orden se conserva. El hallazgo no depende del modelo."),
]
for a, b, c in datos:
    r = tbl.add_row().cells
    r[0].text = a; r[1].text = b; r[2].text = c
for fila in tbl.rows:
    for celda in fila.cells:
        for p in celda.paragraphs:
            for r in p.runs:
                r.font.size = Pt(9.5)
doc.add_paragraph()

h("8. Qué sigue", 1)
bullets([
 "Del autor: su tesis central por escrito, los archivos de los cinco participantes nuevos con su asignación a "
 "condición, la definición operativa de demora, y saber si el diseño nuevo separa el paso del tiempo de la "
 "acumulación de ocasiones.",
 "Del diseño: mientras cada iteración agregue un referente, el tiempo y la acumulación de estímulos seguirán "
 "confundidos; eso no se corrige con más datos, se corrige cambiando el diseño.",
 "Del análisis: si se desea el número exacto de potencia, hacer la simulación con reajustes; hoy se reporta la "
 "aproximación analítica, declarada como tal.",
])

h("9. Advertencias declaradas", 1)
bullets([
 "La potencia es una aproximación analítica basada en la distribución posterior actual; no sustituye una "
 "simulación con reajustes.",
 "Algunos modelos de tema presentan ajuste singular (varianza de participante cercana a cero).",
 "Cinco observaciones del modelo principal tienen Pareto-k mayor a 0.7 (casos con influencia alta); la comparación "
 "por LOO se hizo con emparejamiento de momentos.",
 "El tamaño de las celdas de condición por demora (de dos a cinco personas) vuelve inestimable la interacción "
 "triple.",
])

h("10. Dónde está todo", 1)
par("Cada análisis deja sus tablas, sus figuras y un registro con fecha, hora y versión de R, en la carpeta "
    "«Analisis agosto v2»:", esp=4)
bullets([
 "robustez_bayesiano.R — influencia por participante, MATTR, FDR, bootstrap y modelo bayesiano con ROPE y potencia.",
 "familias_nuevas.R — diccionarios de modo, elaboración entre textos y similitud sin modelo (TF-IDF).",
 "familias_bayes.R — comparación de verosimilitudes (lognormal, gamma, t de Student, gaussiana sobre el logaritmo).",
 "sensibilidad_embeddings2.R — segundo modelo de embeddings (MPNet, 768 dimensiones).",
 "figuras_nuevas.R — las ocho figuras de este documento.",
])
par("La corrida principal de 23 participantes no se modificó: estos análisis leen sus resultados y agregan "
    "comprobaciones. Ninguna cifra del manuscrito cambia por generación automática de texto: no se usa IA "
    "generativa en ninguna etapa.", cursiva=True)

doc.save(SALIDA)

# ------------------------------------------------------------- verificación
chk = Document(SALIDA)
texto = "\n".join(p.text for p in chk.paragraphs)
imgs = sum(1 for r in chk.part.rels.values() if "image" in r.reltype)
print(f"  guardado: {SALIDA}")
print(f"  párrafos: {len(chk.paragraphs)} | tablas: {len(chk.tables)} | imágenes: {imgs}")
print(f"  caracteres: {len(texto)}")
obligatorios = ["Sí, pero no como ChatGPT", "no es IA generativa", "cambio sustancial",
                "no concluyente", "MATTR", "Referente AB", "MPNet", "85 palabras"]
faltan = [f for f in obligatorios if f not in texto]
print(f"  secciones obligatorias presentes: {len(obligatorios) - len(faltan)}/{len(obligatorios)}")
print(f"  faltantes: {faltan if faltan else 'ninguna'}")
print(f"  ok: {len(faltan) == 0 and imgs > 0 and len(chk.tables) == 1}")
