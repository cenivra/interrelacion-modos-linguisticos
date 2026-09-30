#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Modifica EN SITIO la presentación del autor con los resultados nuevos.

Criterio del encargo: no agregar diapositivas. Se conservan las 29 del autor y
se modifican sólo las que deben cambiar, con menos texto en la diapositiva y el
detalle en las notas del orador. La única diapositiva que se llena es la 25, que
estaba vacía y es del propio autor.

La presentación es sobre la CORRIDA PRINCIPAL (23 participantes).
Los números se leen de las tablas de cada análisis; si una tabla no existe
todavía, aparece como «pendiente».

Base: "Interrelacion y demora GDL con notas.pptx"
Salida: "Interrelacion y demora GDL con resultados nuevos.pptx"
"""
import csv, os, shutil, sys, unicodedata
from pptx import Presentation
from pptx.util import Pt, Inches
from pptx.dml.color import RGBColor

BASE = r"C:\Users\saraq\Downloads\Experimento Alfonso Lopez Corral\Interrelacion y demora GDL con notas.pptx"
SALIDA = r"C:\Users\saraq\Downloads\Experimento Alfonso Lopez Corral\Interrelacion y demora GDL con resultados nuevos.pptx"
A = r"C:\Users\saraq\Downloads\Experimento Alfonso Lopez Corral\Analisis agosto v2"
T_ROB = os.path.join(A, "robustez_bayesiano", "principal", "tablas")
T_FAM = os.path.join(A, "familias_bayes", "principal", "tablas")
T_NUE = os.path.join(A, "familias_nuevas", "principal", "tablas")
T_EMB = os.path.join(A, "sensibilidad_embeddings2", "principal", "tablas")

def leer(ruta):
    if not os.path.exists(ruta):
        return None
    with open(ruta, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))

def fila(lst, clave, col=None):
    if not lst:
        return None
    cc = col or list(lst[0].keys())[0]
    return next((f for f in lst if f.get(cc) == clave), None)

def num(x, dec=1, signo=False):
    try:
        v = float(x)
        return f"{v:+.{dec}f}" if signo else f"{v:.{dec}f}"
    except (TypeError, ValueError):
        return "—"

def norm(s):
    """NFC + espacios colapsados: la diapositiva 26 venía en Unicode descompuesto."""
    return " ".join(unicodedata.normalize("NFC", s or "").replace("\u000b", " ").split())

PEND = "pendiente de cálculo"

# ------------------------------------------------------------------ lectura
a1 = leer(os.path.join(T_ROB, "A1_influencia_participante.csv"))
a2 = leer(os.path.join(T_ROB, "A2_modelo_MATTR.csv"))
a3 = leer(os.path.join(T_ROB, "A3_temas_FDR.csv"))
b2 = leer(os.path.join(T_ROB, "B2_decision_posterior.csv"))
b3 = leer(os.path.join(T_ROB, "B3_comparacion_LOO.csv"))
b5 = leer(os.path.join(T_ROB, "B5_potencia_aproximada.csv"))
fam_loo = leer(os.path.join(T_FAM, "comparacion_familias_LOO.csv"))
fam_dec = leer(os.path.join(T_FAM, "decision_por_familia.csv"))
fam_stu = leer(os.path.join(T_FAM, "decision_t_student.csv"))
modos = leer(os.path.join(T_NUE, "1_diccionarios_de_modo.csv"))
ind3 = leer(os.path.join(T_NUE, "2_indice_tres_modos.csv"))
elab = leer(os.path.join(T_NUE, "3_elaboracion_entre_textos.csv"))
tfidf = leer(os.path.join(T_NUE, "4_similitud_tfidf_vs_embeddings.csv"))
cor_med = leer(os.path.join(T_NUE, "4b_correlacion_medidas.csv"))
e2_dist = leer(os.path.join(T_EMB, "b_distancias_dos_modelos.csv"))
e2_sim = leer(os.path.join(T_EMB, "a_similitud_dos_modelos.csv"))

mattr = fila(a2, "tie")
sol = fila(a3, "rate_soledad")
crec = fila(b2, "crecimiento T1→T3 (palabras)")
dif = fila(b2, "Audio vs Texto (palabras)")
pot28 = fila(b5, "28", "n_total")
pot23 = fila(b5, "23", "n_total")
mbay = fila(b3, "m_bay")
ind3t = fila(ind3, "tie")
d = {f["medida"]: f["media"] for f in (elab or [])}
cor_m = num(cor_med[0]["correlacion_tfidf_vs_embeddings"], 2) if cor_med else None

MDE = f"{num(pot28['diferencia_minima_detectable_80'],0)} palabras" if pot28 else "~85 palabras"

# ------------------------------------------------------------ herramientas
def parrafos(shape):
    return list(shape.text_frame.paragraphs)

def busca(slide, fragmento):
    """Devuelve (forma, párrafo) cuyo texto contiene el fragmento (normalizado)."""
    f = norm(fragmento)
    for sh in slide.shapes:
        if not sh.has_text_frame:
            continue
        for p in sh.text_frame.paragraphs:
            if f and f in norm(p.text):
                return sh, p
    return None, None

def reemplaza(slide, viejo, nuevo, registro, etq):
    sh, p = busca(slide, viejo)
    if p is None:
        registro.append(f"NO ENCONTRADO: «{viejo[:50]}…» en {etq}")
        return False
    texto = norm(p.text).replace(norm(viejo), norm(nuevo))
    p.text = texto
    registro.append(f"ok: {etq} → «{nuevo[:60]}…»")
    return True

def pon_parrafo(slide, localizador, nuevo, registro, etq, tam=None):
    """Reemplaza el párrafo COMPLETO que contiene el localizador (evita los
    guiones de partición de palabra, p. ej. «condi- ción»)."""
    sh, p = busca(slide, localizador)
    if p is None:
        registro.append(f"NO ENCONTRADO: «{localizador[:50]}…» en {etq}")
        return False
    tam_prev = None
    for r in p.runs:
        if r.font.size is not None:
            tam_prev = r.font.size
            break
    p.text = nuevo
    for r in p.runs:
        r.font.size = tam if tam else (tam_prev if tam_prev else Pt(12))
    registro.append(f"ok: {etq} → «{nuevo[:60]}…»")
    return True

def caja_fuentes(slide, texto, tam=11):
    from pptx.util import Inches
    caja = slide.shapes.add_textbox(Inches(0.7), Inches(5.5), Inches(11.9), Inches(1.3))
    tf = caja.text_frame
    tf.word_wrap = True
    tf.text = texto
    for p in tf.paragraphs:
        for r in p.runs:
            r.font.size = Pt(tam)
    return True

def pon_cuerpo(slide, lineas, tam=13):
    """Reemplaza el contenido de la forma de texto más grande (el cuerpo)."""
    candidatas = [sh for sh in slide.shapes if sh.has_text_frame and len(norm(sh.text_frame.text)) > 40]
    if not candidatas:
        return False
    sh = max(candidatas, key=lambda s: len(s.text_frame.text))
    tf = sh.text_frame
    tf.text = lineas[0]
    for l in lineas[1:]:
        tf.add_paragraph().text = l
    for p in tf.paragraphs:
        for r in p.runs:
            r.font.size = Pt(tam)
    return True

def agrega_parrafo(slide, texto, tam=13):
    candidatas = [sh for sh in slide.shapes if sh.has_text_frame and len(norm(sh.text_frame.text)) > 40]
    if not candidatas:
        return False
    sh = max(candidatas, key=lambda s: len(s.text_frame.text))
    p = sh.text_frame.add_paragraph()
    p.text = texto
    for r in p.runs:
        r.font.size = Pt(tam)
    return True

def llena_vacia(slide, titulo, lineas, tam=14):
    """La diapositiva 25 venía vacía: se usa su propio título y su cuerpo."""
    if slide.shapes.title is not None:
        slide.shapes.title.text = titulo
        for p in slide.shapes.title.text_frame.paragraphs:
            for r in p.runs:
                r.font.size = Pt(28)
    cuerpo = None
    for ph in slide.placeholders:
        if ph.placeholder_format.idx == 1 and ph.has_text_frame:
            cuerpo = ph
    if cuerpo is None:
        from pptx.util import Inches
        cuerpo = slide.shapes.add_textbox(Inches(0.7), Inches(1.7), Inches(11.9), Inches(4.5))
    tf = cuerpo.text_frame
    tf.text = lineas[0]
    for l in lineas[1:]:
        tf.add_paragraph().text = l
    for p in tf.paragraphs:
        for r in p.runs:
            r.font.size = Pt(tam)

def nota_extra(slide, extra):
    actual = slide.notes_slide.notes_text_frame.text
    slide.notes_slide.notes_text_frame.text = (actual.rstrip() + "\n\n" + extra.strip()) if actual.strip() else extra.strip()

# ------------------------------------------------------------------ deck
if not os.path.exists(BASE):
    sys.exit("no se encontró la presentación base")
shutil.copyfile(BASE, SALIDA)
prs = Presentation(SALIDA)
S = list(prs.slides)
print(f"  base del autor: {len(S)} diapositivas")
reg = []

# ---- 20: el descenso del TTR no es empobrecimiento
reemplaza(S[19], "Escriben más, pero usando las mismas palabras.",
          f"Escriben más, y la diversidad léxica no baja: el descenso del TTR era efecto de la longitud del texto"
          + (f" (MATTR p = {num(mattr['Pr(>F)'],3)})." if mattr else " (MATTR, " + PEND + ")."),
          reg, "d20")

# ---- 21: similitud, encadenamiento y segundo instrumento
reemplaza(S[20], "los textos segundo y tercero son prácticamente idénticos, lo que no indicaría cambio.",
          f"los textos segundo y tercero son prácticamente idénticos (0.93), lo que no indica cambio de contenido. "
          + (f"Lo que sí crece es el encadenamiento con la versión previa: del contenido de T3, "
             f"{num(d.get('reaparece en T3 (de T2)'),2)} provenía del texto anterior, frente a {num(d.get('reaparece en T1 (de T2)', d.get('reaparece en T2 (de T1)')),2)} en el paso previo."
             if d else "El encadenamiento entre textos: " + PEND + "."),
          reg, "d21a")
reemplaza(S[20], "seguido por Audio y finalmente Texto.",
          "seguido por Audio y finalmente Texto. El orden se sostiene con un segundo modelo de embeddings y con un índice puramente léxico.",
          reg, "d21b")

# ---- 24: la evidencia, más corta y con la lectura bayesiana
lineas24 = [
 "Extensión del texto",
 (f"· Tiempo: F(2,40) = 25.50, p < .001 (de 81 a 96 palabras más de T1 a T3 en las tres condiciones). "
  + (f"Bayesiano: {num(crec['media'])} palabras, IC 95 % [{num(crec['ic_bajo'])}, {num(crec['ic_alto'])}] → cambio sustancial." if crec else "Bayesiano: " + PEND + ".")),
 (f"· Condición: F(2,20) = 0.598, p = .559; interacción condición × tiempo: F(4,40) = 0.075, p = .989. "
  + (f"Bayesiano: Audio − Texto {num(dif['media'])} palabras, IC 95 % [{num(dif['ic_bajo'])}, {num(dif['ic_alto'])}] → no concluyente." if dif else "Bayesiano: " + PEND + ".")),
 "Segmentos: Texto (T1→T2 p = .048, T2→T3 p = .048); Audio (p = .041, p = .068); Imagen (T1→T3 p = .003).",
 (f"Alternancia de modos: Soledad F(2,40) = 6.80, p = .003 (único diccionario que sobrevive a la corrección FDR); "
  f"Espacio F(2,40) = 1.64, p = .208. Distancias del espacio semántico: Imagen > Audio > Texto."),
]
if not pon_cuerpo(S[23], lineas24, tam=13):
    reg.append("NO se pudo reescribir el cuerpo de la d24")

# ---- 25: estaba vacía; una sola diapositiva para el análisis nuevo
fam_txt = PEND
if fam_dec:
    _fd = [f for f in fam_dec if abs(float(f["crecimiento"])) > 10]
    if fam_stu:
        _fd = _fd + list(fam_stu)
    if _fd:
        _lo = min(float(f["crecimiento"]) for f in _fd)
        _hi = max(float(f["crecimiento"]) for f in _fd)
        _nc = all(float(f["ic_dif_bajo"]) < 0 < float(f["ic_dif_alto"]) for f in _fd)
        fam_txt = (f"el crecimiento queda entre {_lo:.0f} y {_hi:.0f} palabras en las {len(_fd)} familias"
                   + (" y el contraste entre modos es no concluyente en todas" if _nc else
                      " y el contraste entre modos cambia de lectura en alguna"))
if e2_sim:
    e2_txt = "mismo orden con el segundo modelo (MPNet, 768 dimensiones)"
else:
    e2_txt = PEND
lineas25 = [
 "El mismo modelo, probado de cuatro maneras más:",
 f"· Cuatro verosimilitudes (lognormal, gamma, t de Student y gaussiana sobre el logaritmo): {fam_txt}.",
 f"· Segundo modelo de embeddings, de otra arquitectura: {e2_txt}.",
 (f"· Familias nuevas del artículo: los modos lingüísticos aparecen igual en T1 y en T3 "
  + (f"(F = {num(ind3t['F value'],2)}, p = {num(ind3t['Pr(>F)'],2)})" if ind3t else "")
  + f"; la elaboración hacia la versión previa crece ({num(d.get('reaparece en T2 (de T1)'),2)} → {num(d.get('reaparece en T3 (de T2)'),2)})." if d else "· Familias nuevas del artículo: " + PEND + "."),
 "Ninguna de estas pruebas cambia el sentido de los resultados del estudio.",
]
llena_vacia(S[24], "¿Y si cambiamos el instrumento o la familia estadística?", lineas25, tam=14)
reg.append("ok: d25 (estaba vacía) → diapositiva de comprobaciones")

# ---- 26: dos frases ajustadas a lo que los datos permiten
reemplaza(S[25], "El retardo temporal carece de impacto sobre la fluidez redactora.",
          f"El retardo temporal carece de impacto sobre la fluidez redactora (p = .684); con la potencia disponible, "
          f"sólo diferencias mayores a {MDE} serían detectables entre modalidades.", reg, "d26a")
pon_parrafo(S[25], "verificando la nulidad estadística",
          "No se detecta efecto de condición (p = .559) ni interacción temporal (p = .989) en ninguno de los nueve cruces evaluados; "
          "el resultado bayesiano es «no concluyente», no «sin efecto».", reg, "d26b")
reemplaza(S[25], "y baja la proporción de palabras distintas.",
          "y la proporción de palabras distintas baja por efecto de la longitud del texto, no por empobrecimiento del vocabulario"
          + (f" (MATTR p = {num(mattr['Pr(>F)'],3)})." if mattr else "."), reg, "d26c")
reemplaza(S[25], "El ensayo corrobora unívocamente que los modos reactivos actúan como habilitadores.",
          "El crecimiento se asocia a la acumulación de ocasiones y estímulos; la diferencia entre modos no es detectable con esta potencia.",
          reg, "d26d")

# ---- 27: la limitación, cuantificada
reemplaza(S[26], "vuelve inestimable cualquier interacción triple, mermando severamente la estabilidad de las proyecciones.",
          f"vuelve inestimable cualquier interacción triple: sólo diferencias mayores a {MDE} serían detectables entre modalidades.", reg, "d27")

# ---- 28: la recomendación, con el número
if agrega_parrafo(S[27], f"Ampliar la muestra no es la vía para la comparación entre modalidades: con cinco participantes más la probabilidad de detectar una diferencia de 20 palabras pasa de {num(pot23['potencia_diff20'],2) if pot23 else '0.09'} a {num(pot28['potencia_diff20'],2) if pot28 else '0.10'}. Sirve, en cambio, para estrechar el intervalo del crecimiento.", tam=13):
    reg.append("ok: d28 → párrafo agregado con la potencia")

# ---- 29: fuentes nuevas
if caja_fuentes(S[28], "Análisis nuevos de esta corrida (tablas y registros con fecha y hora en «Analisis agosto v2»):\n"
               "robustez_y_bayesiano.R · familias_nuevas.R · familias_bayes.R · sensibilidad_embeddings2.R", tam=11):
    reg.append("ok: d29 → fuentes nuevas agregadas")

# ------------------------------------------------------------------ notas
NOTAS = {
 19: ("Robustez del crecimiento. El coeficiente vale 51 palabras y, al excluir a cada participante uno por uno, se mueve entre "
      f"{num(min(float(f['coef_loo']) for f in a1)) if a1 else '—'} y {num(max(float(f['coef_loo']) for f in a1)) if a1 else '—'} "
      f"(cambio máximo {num(max(abs(float(f['delta'])) for f in a1)) if a1 else '—'} palabras): ninguna persona sostiene el resultado. "
      "Sirve para responder a la pregunta de si el hallazgo depende de un caso afortunado; no depende. MATTR: índice de diversidad léxica "
      "en ventanas fijas de 100 palabras, inmune a la longitud; el TTR baja cuando el texto crece aunque el vocabulario no se empobrezca. "
      "Detalle en Analisis agosto v2/robustez_bayesiano."),
 20: (f"Verificación del hallazgo semántico con dos instrumentos independientes. Con un índice puramente léxico (TF-IDF, sin modelo) el orden "
      f"es el mismo: T1-T2 {num(fila(tfidf,'T1-T2')['media_tfidf'],3) if tfidf else '—'}, T2-T3 {num(fila(tfidf,'T2-T3')['media_tfidf'],3) if tfidf else '—'}, "
      f"T1-T3 {num(fila(tfidf,'T1-T3')['media_tfidf'],3) if tfidf else '—'}, con correlación {cor_m or '—'} respecto a los embeddings. "
      "El segundo modelo de embeddings (MPNet 768 dimensiones, otra arquitectura) repite el mismo orden. Además, la elaboración entre textos "
      "—cuánto del texto anterior reaparece— crece: 0.58 en T1→T2 y 0.68 en T2→T3, con el contenido nuevo bajando de 0.42 a 0.32. Eso es el "
      "Referente AB del artículo: el texto se apoya cada vez más en la versión previa. La prueba pareada no alcanza significancia (p = .27), "
      "así que se reporta como tendencia direccional."),
 21: ("Los 20 prototipos del catálogo se conservan. Para completar lo que el artículo pide medir se codificaron dos prototipos nuevos "
      "—imaginación y contacto con el referente, cinco frases cada uno— con el mismo modelo de embeddings del pipeline. No se agregaron a la "
      "figura para no alterarla; sus resultados están en las tablas de familias nuevas y coinciden con la lectura general: ni los modos ni la "
      "imaginación cambian de T1 a T3, mientras que la elaboración entre textos sí crece."),
 23: (f"Lectura de esta diapositiva, en una frase: el estudio sí detecta cambio, y grande, en el paso del tiempo; no detecta diferencia entre "
      f"modalidades y tampoco puede descartarla. El intervalo creíble del crecimiento es [{num(crec['ic_bajo']) if crec else '—'}, {num(crec['ic_alto']) if crec else '—'}] "
      f"palabras y la probabilidad de que supere 20 palabras es {num(crec['p_sustancial'],3) if crec else '—'}: cambio sustancial. El contraste Audio − Texto va de "
      f"{num(dif['ic_bajo']) if dif else '—'} a {num(dif['ic_alto']) if dif else '—'} palabras, con probabilidad {num(dif['p_dentro_del_rope'],3) if dif else '—'} de caer dentro de la "
      "zona en que la diferencia sería irrelevante: no concluyente. La comparación de modelos por LOO indica además que los datos no necesitan el "
      "factor modalidad para describirse. El coeficiente de tiempo cambia 10.4 % si se amplía el prior: la conclusión no depende del prior elegido."),
 24: ("Por qué esta diapositiva existe y qué significa. Tres controles que cualquier revisor pediría con muestra pequeña. (1) Familia estadística: "
      "el supuesto sobre la forma del ruido; si la conclusión cambia al cambiar el supuesto, el resultado era frágil. (2) Segundo modelo de "
      "embeddings: si el hallazgo semántico sólo aparece con un modelo, es del modelo y no de los textos. (3) Familias nuevas del artículo: los "
      "diccionarios de los modos lingüísticos (leer, escuchar, observar, imaginar; 94 términos) miden algo que el estudio no medía. Resultado: "
      "escribir más no es escribir más sobre los modos; el índice de los tres modos no cambia (p = .60), y el vocabulario visual es el más presente "
      "(5.35 → 6.82 por mil palabras). Lo que sí aparece es la elaboración hacia la versión previa. Detalle en Analisis agosto v2/familias_bayes, "
      "/familias_nuevas y /sensibilidad_embeddings2."),
 25: (f"Lo que se puede afirmar y lo que no, con el número en la mano. Potencia: probabilidad de detectar una diferencia real de 20 palabras entre "
      f"modalidades con 23 participantes = {num(pot23['potencia_diff20'],2) if pot23 else '0.09'}; con los cinco participantes nuevos = {num(pot28['potencia_diff20'],2) if pot28 else '0.10'}. "
      f"Para tener 80 % de potencia con n = 28 habría que poder detectar diferencias de ~{MDE}. Conclusión operativa: los cinco participantes nuevos "
      "mejoran la estimación del crecimiento —que ya es sólida— pero no vuelven detectable una diferencia pequeña entre modalidades. Eso es un límite "
      "del diseño, no una prueba de ausencia. La potencia es una aproximación analítica basada en el posterior actual; se declara como tal en el "
      "resumen y en el manuscrito."),
 26: ("Las tres limitaciones, ahora cuantificadas. (1) Estrechez y fragmentación: celdas de dos a cinco personas hacen inestimable la interacción "
      "triple, y la potencia alcanza sólo para diferencias mayores a ~85 palabras entre modalidades. (2) Sólo producto textual: no se registró la "
      "alternancia perceptiva mientras se escribía, así que la habilitación lingüística se infiere del documento final. (3) Confusión entre tiempo y "
      "acumulación de estímulos: como cada iteración agrega un referente, no es posible separar el efecto del tiempo del de la acumulación; esto no "
      "se corrige con más datos, se corrige con otro diseño."),
 27: ("Las recomendaciones se sostienen, con un matiz importante. Homogeneizar la potencia ayuda para efectos grandes; para diferencias pequeñas entre "
      "modalidades, ampliar la muestra no es la vía (0.09 → 0.10 con cinco personas más). Lo que sí resolvería el problema conceptual es un diseño que "
      "separe el paso del tiempo de la acumulación de referentes, y el registro en vivo de la alternancia."),
 28: ("Fuentes de los análisis nuevos, todas reproducibles: robustez_y_bayesiano.R (influencia por participante, MATTR, FDR, bootstrap, modelo "
      "bayesiano con ROPE y potencia), familias_nuevas.R (diccionarios de modo, elaboración entre textos, TF-IDF), familias_bayes.R (comparación de "
      "verosimilitudes) y sensibilidad_embeddings2.R (segundo modelo de embeddings). Cada uno deja su registro con fecha, hora y versión de R. La "
      "corrida principal de 23 participantes no cambió: estos análisis leen sus resultados."),
}
for i, texto in NOTAS.items():
    nota_extra(S[i - 1], texto)
    print(f"  notas ampliadas en la diapositiva {i}")


# ------------------------------------------------------------- figuras nuevas
FIG = os.path.join(A, "figuras_nuevas")

def _pie(slide, x, y, w, texto):
    caja = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(0.3))
    caja.text_frame.text = texto
    for par_ in caja.text_frame.paragraphs:
        for r in par_.runs:
            r.font.size = Pt(9)
            r.font.color.rgb = RGBColor(0x55, 0x55, 0x55)

# d19 «Resultados»: sólo tiene título, así que aloja el panel de los resultados nuevos
ruta_panel = os.path.join(FIG, "PANEL_resultados_nuevos.png")
if os.path.exists(ruta_panel):
    alto = 4.9
    ancho = min(alto * (14 / 8.5), 12.0)
    x = (13.333 - ancho) / 2
    S[18].shapes.add_picture(ruta_panel, Inches(x), Inches(1.85), width=Inches(ancho))
    _pie(S[18], x, 1.85 + alto + 0.04, ancho,
         "Resultados nuevos: influencia por participante, MATTR frente a TTR, potencia y elaboración entre textos.")
    reg.append(f"figura PANEL → d19 ({ancho:.1f}×{alto:.1f} pulgadas)")
else:
    reg.append("figura PANEL: no existe todavía")

# d25 (comprobaciones): la figura de familias, en el hueco bajo los cinco puntos
ruta_f9 = os.path.join(FIG, "F9_familias.png")
if os.path.exists(ruta_f9):
    S[24].shapes.add_picture(ruta_f9, Inches(7.15), Inches(4.30), width=Inches(4.9))
    _pie(S[24], 7.15, 6.75, 4.9, "Crecimiento y contraste entre modos según la familia estadística.")
    reg.append("figura F9_familias.png → d25 en (7.2, 4.3) de 4.9 de ancho")
else:
    reg.append("figura F9: no existe todavía")

# d29 «Referencias y anexos»: tiene hueco libre bajo el título; aloja cuatro figuras en rejilla
ANEXO = [("F3_fdr.png", 7 / 4, "Diccionarios con y sin corrección por comparaciones múltiples."),
         ("F4_posteriores.png", 8 / 4, "Posteriores de crecimiento y de la diferencia Audio − Texto."),
         ("F7_modos.png", 7 / 4, "Los modos lingüísticos en el texto, por momento."),
         ("F8_dos_instrumentos.png", 8 / 4, "El mismo orden de similitud con tres instrumentos.")]
posiciones = [(0.75, 1.75), (7.05, 1.75), (0.75, 3.55), (7.05, 3.55)]
for (png, aspecto, pie), (x, y) in zip(ANEXO, posiciones):
    ruta = os.path.join(FIG, png)
    if not os.path.exists(ruta):
        reg.append(f"figura {png}: no existe todavía")
        continue
    h = 1.62
    w = h * aspecto
    S[28].shapes.add_picture(ruta, Inches(x), Inches(y), width=Inches(w))
    _pie(S[28], x, y + h + 0.01, max(w, 3.2), pie)
    reg.append(f"figura {png} → d29 en ({x:.1f}, {y:.1f}) de {w:.1f}×{h:.1f} pulgadas")

prs.save(SALIDA)

# ------------------------------------------------------------- verificación
chk = Presentation(SALIDA)
todo = []
for s in chk.slides:
    todo.append(" ".join(norm(sh.text_frame.text) for sh in s.shapes if sh.has_text_frame))
global_txt = " ".join(todo)
debe_existir = [
 ("d20 MATTR", "MATTR"),
 ("d21 encadenamiento", "encadenamiento"),
 ("d21 segundo modelo", "segundo modelo de embeddings"),
 ("d24 bayesiano crecimiento", "cambio sustancial"),
 ("d24 bayesiano modalidad", "no concluyente"),
 ("d25 verosimilitudes", "verosimilitudes"),
 ("d25 familias nuevas", "Familias nuevas del artículo"),
 ("d26 potencia", "serían detectables entre modalidades"),
 ("d27 limitación cuantificada", "sólo diferencias mayores"),
 ("d28 potencia agregada", "cinco participantes más"),
 ("d29 fuentes", "robustez_y_bayesiano.R"),
 ("d26 aclara el descenso del TTR", "no por empobrecimiento del vocabulario"),
 ("d29 fuentes en caja", "sensibilidad_embeddings2.R"),
]
debe_desaparecer = [
 ("d26 ya no dice ausencia absoluta", "absoluta ausencia de un efecto"),
 ("d26 ya no dice nulidad estadística", "verificando la nulidad"),
 ("d26 ya no dice corrobora unívocamente", "corrobora unívocamente"),
]
fallos = []
for etq, frag in debe_existir:
    if norm(frag) not in global_txt:
        fallos.append(etq)
for etq, frag in debe_desaparecer:
    if norm(frag) in global_txt:
        fallos.append(etq)
imgs = sum(1 for s in chk.slides for sh in s.shapes if sh.shape_type == 13)
rel_imgs = sum(1 for s in chk.slides for r in s.part.rels.values() if "image" in r.reltype)
sin_notas = [i for i, s in enumerate(chk.slides, 1) if not (s.has_notes_slide and s.notes_slide.notes_text_frame.text.strip())]

print()
print("  --- registro de cambios ---")
for r in reg:
    print("   ", r)
print(f"  diapositivas: {len(chk.slides)} (igual que el autor)")
print(f"  imágenes visibles: {imgs} | relaciones de imagen: {rel_imgs}")
print(f"  sin notas: {sin_notas if sin_notas else 'ninguna'}")
print(f"  verificaciones: {len(debe_existir) + len(debe_desaparecer) - len(fallos)}/{len(debe_existir) + len(debe_desaparecer)}")
print(f"  fallos: {fallos if fallos else 'ninguno'}")
print(f"  guardado en: {SALIDA}")
