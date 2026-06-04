# Evaluación de 4 modelos LLM como evaluadores de un experimento de determinismo

## Preámbulo

### Tipo de tarea

Se sometió a 4 modelos LLM (versiones gratuitas de OpenCode Zen) al mismo cuestionario de **8 preguntas secuenciales** de análisis comparativo sobre documentos técnicos. La tarea no era trivial: los modelos debían leer, comprender, comparar y puntuar múltiples documentos generados en un experimento previo sobre **determinismo** de modelos LLM. Ese experimento original partía de una misma sesión de conversación, la forkeaba en 3 ramas al mismo modelo y registraba los documentos resultantes para medir si —y en qué grado— el modelo producía outputs divergentes partiendo del mismo estado. A partir de esos documentos iniciales se generó una cadena de derivados (`modelov* → modelor* → READMEv* → READMEr*`) que constituyen el corpus que los modelos evaluadores tuvieron que analizar. Cada documento de la cadena tenía estructura, conclusiones y formatos distintos, reflejando la divergencia natural del modelo base. A medida que avanzaba el cuestionario, se les pedía integrar nueva información, recalibrar evaluaciones previas y finalmente diseñar un marco métrico y redactar un informe completo.

Cada modelo partió del mismo prompt inicial y recibió exactamente las mismas instrucciones en el mismo orden. Las diferencias observadas se deben exclusivamente al comportamiento de cada modelo ante una tarea analítica compleja y secuencial.

**Índice**

- [Resumen ejecutivo](#resumen-ejecutivo)
- [Volumen de lectura](#volumen-de-lectura)
- [Preguntas del cuestionario](#preguntas-del-cuestionario-evaluadas-p1-p8)
- [Modelos evaluados](#modelos-evaluados)
- [Comportamiento general](#comportamiento-general-de-cada-modelo)
- [Bloque A1 — Puntuación por pregunta](#bloque-a1--puntuación-por-pregunta-0-10)
- [Bloque A2 — Coherencia global](#bloque-a2--coherencia-global-0-10)
- [Bloque A3 — Informe final](#bloque-a3--informe-final-de-determinismo-0-10)
- [Bloque B — Fluidez operativa](#bloque-b--fluidez-operativa-0-10)
- [Bloque C — Coste teórico](#bloque-c--coste-teórico)
- [Bloque D — Privacidad](#bloque-d--privacidad-y-condiciones-de-uso)
- [Nota global](#nota-global)
- [Perfiles cualitativos](#perfiles-cualitativos-por-modelo)
- [Evolución intra-sesión](#evolución-intra-sesión-la-calidad-por-pregunta)
- [Validación cruzada](#validación-cruzada-determinismo-de-la-propia-evaluación)
- [Qué hemos aprendido](#qué-hemos-aprendido)
- [Glosario](#glosario)

### Volumen de lectura

A lo largo del cuestionario, cada modelo tuvo que leer 12 archivos distintos:

| Pregunta | Archivos leídos | Tamaño total |
|---|---|---|
| P1 | `modelov1.md` + `modelov2.md` + `modelov3.md` | 54 KB |
| P2 | `modelov1r.md` + `modelov2r.md` + `modelov3r.md` | 21 KB |
| P4 | `READMEv1.es.md` + `READMEv2.es.md` + `READMEv3.es.md` | 125 KB |
| P5 | `READMEr1.es.md` + `READMEr2.es.md` + `READMEr3.es.md` | 143 KB |
| **Total** | 12 archivos | **343 KB** |

Las preguntas P3, P6, P7 y P8 no requerían lectura de archivos nuevos, sino síntesis y reflexión sobre lo ya leído, lo que permitía evaluar la capacidad de los modelos para retener y articular información sin depender del contexto inmediato.

### Preguntas del cuestionario evaluadas (P1-P8)

| # | Descripción | Habilidad evaluada |
|---|---|---|
| P1 | Comparar y puntuar 3 documentos (`modelov1/v2/v3.md`) | Análisis comparativo inicial |
| P2 | Comparar y puntuar 3 documentos (`modelov1r/v2r/v3r.md`) | Análisis comparativo sobre segunda serie |
| P3 | Tabla ranking de pares `v?+v?r` con puntuaciones de utilidad y coherencia | Síntesis tabular y trazabilidad |
| P4 | Evaluar `READMEv*.es.md` en relación con todo lo previamente analizado | Integración secuencial de información |
| P5 | Evaluar `READMEr*.es.md` contra toda la serie previa | Recalibración con nuevo contexto |
| P6 | Tabla ranking comparando cada `READMEr` con su `READMEv` tras revelar las etiquetas del single-blind | Comparación pre/post desenmascaramiento |
| P7 | Diseñar qué factores medir para analizar determinismo | Meta-análisis y diseño metodológico |
| P8 | Escribir un informe completo sobre determinismo en un archivo | Síntesis extensa y generación de documento |

Se excluyeron del análisis las interacciones posteriores a P8 (compactación, propuesta de nombres, etc.) por corresponder a una fase experimental distinta.

### Modelos evaluados

| ID de sesión | Modelo (OpenCode Zen Free) | Proveedor subyacente |
|---|---|---|
| `cEHnhJLL` | DeepSeek V4 Flash Free | DeepSeek |
| `7FnPYnCv` | MiMo V2.5 Free | MiMo |
| `Rg310ly8` | MiniMax M3 Free | MiniMax |
| `kLZ1EfTf` | Nemotron 3 Super Free | NVIDIA |

### Alcance de esta evaluación

No se evalúa el contenido original del experimento de determinismo (los archivos `modelov*`, `modelor*`, `READMEv*`, `READMEr*` y las sesiones de fork). Se evalúa **cómo cada modelo desempeñó la tarea de evaluador**: su profundidad analítica, su coherencia a lo largo de 8 preguntas secuenciales, su fluidez operativa (tiempos, errores, completitud) y una estimación del coste teórico de cada sesión. Se añade un bloque sobre privacidad y condiciones de uso de cada modelo gratuito.

---

## Resumen ejecutivo

| Ranking | Modelo | Global | Perfil |
|---|---|---|---|
| 🥇 | **DeepSeek V4 Flash Free** | **9.14** | Mejor profundidad analítica y coherencia. Sin errores. Informe preciso. |
| 🥈 | **MiMo V2.5 Free** | **8.64** | Más rápido y barato. Errores de formato en P2-P3 pero se recupera. |
| 🥉 | **MiniMax M3 Free** | **7.16** | Competente pero 3.7× más lento. Inconsistencias de criterio. |
| 4º | **Nemotron 3 Super Free** | **4.29** | Fallos operativos y analíticos. No recomendable. |

**5 datos clave:**
1. **DeepSeek gana por coherencia** — sin altibajos en 8 preguntas (σ=0.35).
2. **MiMo es el más rápido** (213s vs 305s DeepSeek) y el más barato en coste teórico.
3. **MiniMax es 3.7× más lento** que MiMo y su coste teórico es 22× superior.
4. **Nemotron falla en 2 de 8 preguntas** (P6 vacía, P5 en inglés) y se contradice a sí mismo.
5. **El ranking se validó con 10 réplicas** del mismo modelo: el orden ordinal es estable (100% en cola, 60% en cabeza), aunque las puntuaciones varían ±0.5 pts.

---

## Comportamiento general de cada modelo

Antes de entrar en las puntuaciones por bloque, es útil tener una caracterización cualitativa de cómo se comportó cada modelo durante la sesión completa.

### DeepSeek V4 Flash Free

DeepSeek fue el modelo más sólido globalmente. Sus respuestas fueron consistentemente bien estructuradas, en español, y demostraron capacidad para detectar patrones transversales entre preguntas. En P1 ya identificó que la velocidad de generación (tok/s) era el factor más discriminatorio entre documentos, un insight que mantuvo y refinó en preguntas posteriores. En P2 detectó que dos de los tres documentos de recomendación usaban asignaciones pre-revisión, ignorando los cambios documentados en el compaction research — una observación que requería haber retenido información de la pregunta anterior. En P5 fue el que más claramente articuló que los tres READMEr convergían en las mismas asignaciones, resolviendo la divergencia de los niveles anteriores. Su informe de determinismo (P8) fue completo y se escribió al archivo sin necesidad de recordatorio. Su única debilidad menor fue un tiempo de respuesta ligeramente superior al de MiMo.

### MiMo V2.5 Free

MiMo fue el modelo más rápido con diferencia (213s totales frente a 305s de DeepSeek, 790s de MiniMax y 1207s de Nemotron). Completó las 8 preguntas con rankings estables. Su criterio se mantuvo homogéneo a lo largo de toda la sesión, y fue el único modelo que señaló que la recalibración de v1→r1 fue negativa en lugar de positiva, un matiz que los demás pasaron por alto.

Sin embargo, acumuló varios problemas que lo penalizan:
- **Mezcla de idiomas**: 2 caracteres chinos incrustados en respuestas en español ("有些" en P1, "分歧" en P2)
- **P3**: No respondió al formato pedido. La pregunta solicitaba emparejar cada `modelov?r.md` con su `modelov?.md`. MiMo devolvió un ranking de 6 documentos sueltos sin relacionarlos.
- **P2**: No conectó los documentos `modelov?r.md` con sus respectivos padres `modelov?.md`, tratándolos como independientes.

Estos errores no son fatales pero indican una menor atención al detalle en el cumplimiento de instrucciones que DeepSeek o MiniMax.

### MiniMax M3 Free

MiniMax fue competentemente analítico pero extremadamente lento. Su tiempo total de LLM fue de 790s (13 minutos), casi 4 veces más que MiMo, con respuestas individuales que llegaron a durar hasta 230s (casi 4 minutos) en P1. Esta lentitud no se tradujo en mayor calidad: su coherencia global fue la más baja de los tres modelos funcionales. En P4 dio el primer puesto a READMEv1 (empatado con v3), y en P6 invirtió su ranking respecto a P5 sin justificación. También utilizó un sistema de puntuación 17/20 en lugar de 0-10 en P6, un cambio de formato no estándar. Su informe de P8 fue el más extenso en número de líneas (~640), pero también el que más tardó en generar.

### Nemotron 3 Super Free

Nemotron fue, con diferencia, el peor rendimiento. Acumuló múltiples fallos operativos: P3 requirió que el usuario repitiera la pregunta porque la primera respuesta fue vacía; P6 no fue respondida en absoluto (el asistente produjo solo "---"); P8 generó el contenido del informe pero no lo escribió al archivo, necesitando dos recordatorios del usuario para completar la instrucción. Además, P5 fue respondida en inglés a pesar de que el prompt estaba en español. Sus rankings fueron inconsistentes entre preguntas (v2 primero en P1-P3, v3 primero en P7), lo que sugiere que no retenía ni aplicaba un criterio estable. Sus tiempos fueron los más largos (1207s de LLM, 20 minutos), con una respuesta de 301s (5 minutos) en P7 para un resultado mediocre. En total realizó 34 llamadas API, casi el doble que los demás, debido a tool calls fallidas y reintentos.

---

## Bloque A1 — Puntuación por pregunta (0-10)

Cada pregunta se puntúa 0-10 considerando: profundidad del análisis (identifica causas y patrones, no solo describe), precisión factual, claridad expositiva y cumplimiento del formato solicitado.

### P1 — Comparar modelov1/v2/v3.md (análisis inicial de 3 documentos)

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **9.0** | Identificó velocidad de generación como discriminante clave. Ranking: v1=8.0, v2=6.5, v3=8.5. Bien justificado. |
| MiMo | **7.5** | Análisis sólido pero menos incisivo. Ranking: v1=8.25, v2=8.1, v3=7.5. Carácter chino "有些" en respuesta. |
| MiniMax | **7.5** | Ranking: v1=8.0, v2=6.8, v3=7.2. Detectó contradicción en v3 (asigna Pro Max pero config no lo permite). Insight único. |
| Nemotron | **7.0** | Correcto pero ranking invertido (v2=8.5, v3=8.0, v1=7.5), divergente del resto. |

### P2 — Comparar modelov1r/v2r/v3r.md (segunda serie, documentos de recomendación)

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **9.0** | Detectó que v1r y v2r usan asignaciones pre-revisión. Insight transversal. |
| MiMo | **7.0** | Buena comparación pero **no relaciona vr con su padre v**. Trata los 3 vr como independientes + carácter chino "分歧". |
| MiniMax | **7.5** | Correcto. Detectó inconsistencia: v2r asigna Op2=Pro Max cuando su padre v2 dice Flash Max. |
| Nemotron | **7.0** | Ranking invertido (v2r primero). No detecta herencia de asignaciones pre-revisión. |

### P3 — Tabla ranking con utilidad y coherencia por par (v?+v?r)

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **9.5** | Tabla completa emparejando vr con v, detecta incoherencias de asignación entre pares (tablas 7-9). |
| MiMo | **6.0** | **No responde al formato pedido**: ranking de 6 docs sueltos sin emparejar vr con v. No detecta incoherencias entre análisis y recomendación. |
| MiniMax | **8.0** | Tabla correcta emparejando coherencia con padre. v3r=8.5, v1r=5.5, v2r=5.0. |
| Nemotron | **5.0** | Falló en primer intento (respuesta vacía). Usuario repitió. Ranking invertido (v2 primero) y tabla repetida 3 veces. |

### P4 — Evaluar READMEv*.md contra los previos

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **8.5** | Detectó que READMEv2 es incoherente con su propio modelov2. |
| MiMo | **8.0** | Evaluación correcta. Ranking v3>v1>v2 consistente con su criterio previo. |
| MiniMax | **7.5** | Ranking divergente (v1>v3>v2), rompiendo con su criterio de P1-P3. |
| Nemotron | **7.0** | Análisis superficial. Destaca solo v2 por la Prueba 7, sin comparar los tres. |

### P5 — Evaluar READMEr*.md (recalibrados tras revelar etiquetas)

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **9.0** | Detectó que los tres READMEr convergen en las mismas asignaciones. Insight clave. |
| MiMo | **8.5** | Detectó convergencia. Señaló recalibración negativa en v1/r1. |
| MiniMax | **8.0** | Detectó convergencia. Ranking r3>r1=r2. |
| Nemotron | **4.0** | Respondió en **inglés** pese al prompt en español. **No evaluó READMEr3** ("not provided"). No detectó convergencia de asignaciones. |

### P6 — Tabla ranking READMEr vs READMEv (post-desenmascaramiento)

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **8.5** | Tabla clara. Distinguió recalibración limpia (v3→r3) vs dramática (v2→r2). |
| MiMo | **8.0** | Tabla correcta con impacto de recalibración. |
| MiniMax | **7.5** | Usó sistema 17/20 no estándar. Correcto pero formato inconsistente. |
| Nemotron | **0.0** | **No respondió.** El asistente produjo solo "---". |

### P7 — Diseñar métricas para medir determinismo

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **8.5** | Propuso ID compuesto con fórmula (αA+βB+γC). Concreto y medible. |
| MiMo | **8.5** | Propuso 7 métricas con ID compuesto. Muy completo. ID global 0.68. |
| MiniMax | **8.0** | 5 dimensiones, 6 métricas. Destacó contraste 100%→0% entre datos e interpretación. |
| Nemotron | **7.0** | 6 factores. Ranking v3>v2>v1 contradice sus propias notas P1-P3 (v2>v3). |

### P8 — Escribir informe completo de determinismo

| Modelo | Nota | Observaciones |
|---|---|---|
| DeepSeek | **9.0** | Informe completo escrito al archivo. ID calculado (38.6%). Sin recordatorio. |
| MiMo | **8.5** | Informe completo. ID 0.68 (moderadamente determinista). Sin recordatorio. |
| MiniMax | **8.5** | Informe más extenso (~640 líneas). 7 hallazgos, 7 limitaciones. Sin recordatorio. |
| Nemotron | **6.5** | Contenido generado (~270 líneas) pero **no lo escribió al archivo**. Requirió 2 recordatorios. Además P5 respondida en inglés sin evaluar READMEr3. |

### Media A1

| Modelo | Media |
|---|---|
| **DeepSeek V4 Flash Free** | **8.88** |
| **MiMo V2.5 Free** | **7.75** |
| **MiniMax M3 Free** | **7.81** |
| **Nemotron 3 Super Free** | **5.44** |

**Mapa de calor A1:** notas por modelo y pregunta (🟢 ≥ 8.5, 🟡 7.0-8.4, 🔴 < 7.0)

| Modelo | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 |
|---|---|---|---|---|---|---|---|---|
| DeepSeek | 🟢9.0 | 🟢9.0 | 🟢9.5 | 🟢8.5 | 🟢9.0 | 🟢8.5 | 🟢8.5 | 🟢9.0 |
| MiMo | 🟡7.5 | 🟡7.0 | 🔴6.0 | 🟢8.0 | 🟢8.5 | 🟢8.0 | 🟢8.5 | 🟢8.5 |
| MiniMax | 🟡7.5 | 🟡7.5 | 🟢8.0 | 🟡7.5 | 🟢8.0 | 🟡7.5 | 🟢8.0 | 🟢8.5 |
| Nemotron | 🟡7.0 | 🟡7.0 | 🔴5.0 | 🟡7.0 | 🔴4.0 | 🔴0.0 | 🟡7.0 | 🔴6.5 |

**Patrón:** DeepSeek es todo verde (consistencia total). MiMo y MiniMax tienen verde en la segunda mitad (mejoran). Nemotron solo puntos amarillos aislados con dos desplomes.

### Desviación típica por pregunta (poder discriminante entre modelos)

La desviación indica qué preguntas separan mejor a los modelos. Una σ alta significa que los modelos rindieron de forma muy distinta en esa pregunta.

| Pregunta | σ | Interpretación |
|---|---|---|
| P6 — Tabla ranking post-desenmascaramiento | 3.51 | Máxima. Nemotron no respondió (0), los demás obtuvieron 7.5-8.5. |
| P3 — Tabla ranking pares v?+v?r | 1.75 | Alta. Nemotron (5.0) por fallo inicial; DeepSeek (9.5) destaca sobre el resto. |
| P5 — Evaluar READMEr* | 1.98 | Alta. Nemotron (4.0) por responder en inglés sin evaluar r3; los demás 8.0-9.0. |
| P8 — Informe determinismo | 0.93 | Media. Nemotron sin write baja la media. Diferencia menos marcada. |
| P1 — Comparar modelov* | 0.72 | Media. Todos respondieron correctamente, varía la profundidad. |
| P2 — Comparar modelor* | 0.72 | Media. Mismo patrón que P1. |
| P4 — Evaluar READMEv* | 0.64 | Baja. Todos funcionaron de forma similar. |
| P7 — Diseñar métricas | 0.62 | Baja. Todos propusieron marcos métricos aceptables. |

**Conclusión:** Las preguntas que requieren **formato estructurado** (tablas, rankings) y **seguimiento preciso de instrucciones** son las que más discriminan entre modelos. Las preguntas abiertas de diseño (P7, P8) muestran menos dispersión porque todos los modelos pueden producir algo aceptable aunque con distinta profundidad.

---

## Bloque A2 — Coherencia global (0-10)

Mide la consistencia transversal del criterio del modelo a lo largo de las 8 preguntas: si los rankings se mantienen estables, si los criterios de valoración son los mismos de una pregunta a otra, si hay contradicciones internas, y si el modelo detecta y corrige arrastres de errores.

### DeepSeek V4 Flash Free — 9.0

DeepSeek fue el modelo más coherente. Sus rankings mantuvieron consistentemente a v3/Op3 como el mejor documento en todas las preguntas donde se pedía comparar. El criterio de valoración (velocidad de generación como discriminante principal) se estableció en P1 y se mantuvo hasta P6. Detectó patrones transversales como la convergencia de READMEr en P5 y la contradicción entre v1r/v2r con sus respectivos v1/v2 en P2-P3. No hubo contradicciones internas detectadas.

### MiMo V2.5 Free — 8.0

MiMo mantuvo rankings estables (v3/r3 siempre primero) y un criterio de fondo homogéneo. Detectó la recalibración negativa de v1→r1, un matiz que DeepSeek no señaló. Sin embargo, presenta dos problemas de consistencia: en P2 no conectó los documentos `modelov?r.md` con sus respectivos padres `modelov?.md`, tratándolos como independientes, y en P3 no respondió al formato solicitado (ranking plano sin emparejar). Esto indica que su coherencia de criterio se mantiene a nivel macro pero falla en la ejecución detalle a detalle. Además, mezcla de idiomas (caracteres chinos) en P1 y P2 penaliza la consistencia formal.

### MiniMax M3 Free — 6.5

MiniMax presentó varias inconsistencias. En P4 dio como mejor a READMEv1 (empatado con v3 a 0.1 de distancia), pero en P5 r3 fue claramente primero. La contradicción más clara está entre P5 y P6: en P5 su ranking era r3>r1=r2, pero en P6 invierte a r1>r3>r2 sin justificación. Además, en P6 usó un sistema de puntuación 17/20 no estándar en lugar del 0-10 usado por los demás, lo que dificulta la comparación directa. No hay una contradicción flagrante de criterio, pero el orden de preferencia varía entre preguntas sin que se explique el cambio.

### Nemotron 3 Super Free — 2.5

Nemotron mostró contradicciones graves. En P1-P3 clasificó a v2 como el mejor documento, mientras que en P7 clasificó a v3 como el mejor, sin señalar el cambio de criterio ni justificarlo. Además, dejó P6 sin responder, P5 la respondió en inglés sin evaluar READMEr3, y P8 no escribió el archivo (2 recordatorios). El arrastre de errores fue total: su criterio inicial (v2 primero) se contradice con sus propias puntuaciones posteriores, y no hay evidencia de autocorrección ni conciencia de la contradicción.

---

## Bloque A3 — Informe final de determinismo (0-10)

Evalúa la calidad del archivo `research/deepseek-v4-flash-determinism/README.*.md` que cada modelo escribió como síntesis final de todo su análisis. Es el entregable tangible del trabajo.

### Criterios evaluados

| Criterio | Peso | Qué mide |
|---|---|---|
| **Fidelidad** | 30% | Si el informe refleja las conclusiones de la sesión sin contradecirlas |
| **Profundidad técnica** | 30% | Si propone métricas concretas (ID numérico, fórmula) o es descriptivo genérico |
| **Utilidad práctica** | 25% | Si da recomendaciones accionables o solo describe el problema |
| **Autonomía** | 15% | Si lo escribió sin recordatorio o necesitó intervención del usuario |

### Evaluación

| Modelo | Fidelidad | Profundidad | Utilidad | Autonomía | **A3** |
|---|---|---|---|---|---|
| **DeepSeek V4 Flash Free** | 10 | 9 | 9 | 10 | **9.5** |
| **MiMo V2.5 Free** | 9 | 10 | 9 | 10 | **9.5** |
| **MiniMax M3 Free** | 9 | 9 | 8 | 10 | **9.0** |
| **Nemotron 3 Super Free** | 4 | 6 | 5 | 4 | **4.8** |

### Observaciones

**DeepSeek (9.5):** Informe completo de 486 líneas con diseño experimental detallado, índice de determinismo concreto (ID=38.6%), 7 secciones bien estructuradas, y recomendaciones accionables. Sin recordatorio.

**MiMo (9.5):** Informe de 488 líneas con 10 secciones y 3 apéndices. Obtuvo la mejor nota en profundidad técnica: define 7 métricas (A-G) con fórmula ID compuesta y calcula el ID para cada nivel (0.53, 0.49, 0.74, 0.97). Sin recordatorio.

**MiniMax (9.0):** Informe más extenso (675 líneas, 8 secciones, 4 anexos). Marco de 5 dimensiones (D1-D5) con 6 métricas operacionales. Sin embargo, no calcula un ID numérico final, lo que resta concreción. Sin recordatorio.

**Nemotron (4.8):** Informe de 271 líneas que describe un marco teórico genérico de 6 factores pero **no lo aplica a los datos del experimento**. No hay tabla de asignaciones, ni ID calculado, ni referencias a los documentos concretos. Además, requirió 2 recordatorios del usuario para escribirlo. Es un marco metodológico, no un análisis del experimento realizado.

---

## Bloque B — Fluidez operativa (0-10)

Compuesto por cuatro subcomponentes promediados.

### B1 — Completitud

Porcentaje de las 8 preguntas que recibieron una respuesta sustantiva.

| Modelo | Preguntas respondidas | Nota |
|---|---|---|
| DeepSeek | 8/8 | 10.0 |
| MiMo | 8/8 | 10.0 |
| MiniMax | 8/8 | 10.0 |
| Nemotron | 7/8 | 8.75 |

Nemotron falló en P6 (respuesta vacía "---"). Además, P3 requirió repetición del usuario, aunque finalmente sí respondió.

### B2 — Errores de procesamiento

Se contabilizan tool calls fallidas, formatos incorrectos, instrucciones ignoradas y necesidad de intervención del usuario.

| Modelo | Errores | Nota |
|---|---|---|
| DeepSeek | Ninguno | 10.0 |
| MiMo | 2 caracteres chinos en respuestas: "有些" (P1), "分歧" (P2). Además P3 no responde al formato solicitado (no empareja vr con v). | 6.0 |
| MiniMax | 1 carácter chino aislado en respuesta P2 ("优势的逐条比较") | 9.0 |
| Nemotron | P6 sin respuesta; P3 requirió repetición; P8 no escribió archivo (2 recordatorios); P5 en inglés + no evaluó r3 | 4.0 |

### B3 — Tiempo LLM puro (P1-P8)

Se midió exclusivamente el tiempo de las respuestas del asistente que **no** contenían tool calls de lectura de archivos. Las tool calls se excluyeron porque el tiempo de lectura depende del sistema, no del modelo. Una respuesta del asistente se clasifica como "LLM" cuando su bloque de pensamiento no contiene instrucciones `**Tool:**`.

| Modelo | Tiempo total P1-P8 | Media por pregunta | Máximo individual | Relación vs más rápido |
|---|---|---|---|---|
| **MiMo V2.5 Free** | 213s (3.6 min) | 26.6s | 34.4s (P6) | 1.0× (referencia) |
| **DeepSeek V4 Flash Free** | 305s (5.1 min) | 38.2s | 66.9s (P5) | 1.4× |
| **MiniMax M3 Free** | 790s (13.2 min) | 98.7s | 229.6s (P1) | 3.7× |
| **Nemotron 3 Super Free** | 1207s (20.1 min) | 150.9s | 301.5s (P7) | 5.7× |

**Análisis detallado de tiempos:**

Las diferencias son notables. MiMo resolvió todo el cuestionario en el tiempo que MiniMax tardó solo en P1 (213s vs 229s). Nemotron necesitó más tiempo para P7 (301s) que MiMo para las 8 preguntas juntas.

DeepSeek, aunque más lento que MiMo, mantuvo tiempos razonables (media 38s por respuesta). Sus picos corresponden a preguntas que requerían leer documentos grandes (P5: 67s para evaluar los tres READMEr).

MiniMax mostró una latencia basal alta desde la primera respuesta (P1: 229.6s). Esto no es un fallo, sino una característica del modelo. Pero multiplica por 3.7 el tiempo total.

Nemotron combinó latencia alta con tool calls fallidas que obligaban a reintentos, resultando en 34 llamadas API totales (vs 20-22 de los demás).

### B4 — Formato del informe final

Evalúa la estructura, navegabilidad y calidad formal del archivo `README.*.md` que cada modelo escribió como síntesis final.

| Modelo | B4 | Observaciones |
|---|---|---|
| **DeepSeek V4 Flash Free** | 9 | 7 secciones, tablas claras, índice de determinismo concreto |
| **MiMo V2.5 Free** | 10 | 10 secciones + 3 apéndices, muy completo, datos detallados |
| **MiniMax M3 Free** | 9 | 8 secciones + 4 anexos, bien estructurado |
| **Nemotron 3 Super Free** | 7 | Marco teórico genérico, sin aplicación a datos del experimento |

### Media del Bloque B

Ahora compuesto por 4 subcomponentes: (B1+B2+B3+B4)/4.

| Modelo | B1 | B2 | B3 | B4 | **Media B** |
|---|---|---|---|---|---|
| **MiMo V2.5 Free** | 10.0 | 6.0 | 10.0 | 10 | **9.00** |
| **DeepSeek V4 Flash Free** | 10.0 | 10.0 | 7.0 | 9 | **9.00** |
| **MiniMax M3 Free** | 10.0 | 9.0 | 2.7 | 9 | **7.68** |
| **Nemotron 3 Super Free** | 8.75 | 4.0 | 1.8 | 7 | **5.39** |

---

## Bloque C — Coste teórico

### Metodología

DeepSeek V4 Flash (no free) tiene precio conocido: $0.14/1M tokens input, $0.28/1M output. Los demás modelos no tienen precio publicado. Para estimar su coste teórico se aplicó la siguiente aproximación: se toma la relación inversa entre los límites mensuales de requests gratuitos de cada modelo respecto a Flash. Si un modelo tiene un límite N veces menor, se asume que su coste por token es N veces mayor.

**Advertencia:** Esta es una aproximación. No existe relación lineal publicada entre límites gratuitos y precios de API. Los datos se ofrecen como referencia orientativa para comparar órdenes de magnitud, no como precios reales. Cada lector puede aplicar su propio criterio de ponderación.

### Límites mensuales y precios inferidos

| Modelo | Límite/mes | Ratio vs Flash (inverso) | Precio input inferido | Precio output inferido |
|---|---|---|---|---|
| DeepSeek V4 Flash | 158,150 | 1.000× (referencia) | $0.140 | $0.280 |
| MiMo-V2.5 | 150,400 | ×1.052 | $0.147 | $0.295 |
| MiniMax M3 | 7,000 | ×22.59 | $3.163 | $6.325 |
| Nemotron 3 | — | No disponible | — | — |

### Consumo real de tokens por sesión

Datos extraídos del archivo de costes de OpenCode Zen, sumando todas las llamadas API de cada sesión correspondientes al modelo free (se excluyen 3 llamadas al modelo `deepseek-v4-flash` de pago que aparecen mezcladas en las sesiones por un error de registro).

| Modelo | Llamadas API | Input tokens | Output tokens |
|---|---|---|---|
| **DeepSeek V4 Flash Free** | 21 | 1,881,012 | 47,109 |
| **MiMo V2.5 Free** | 19 | 1,718,951 | 28,710 |
| **MiniMax M3 Free** | 21 | 1,696,255 | 55,218 |
| **Nemotron 3 Super Free** | 34 | 3,246,948 | 33,383 |

### Coste teórico total por sesión

| Modelo | Coste input | Coste output | **Coste teórico total** | **Nota C (inversa)** |
|---|---|---|---|---|
| **MiMo V2.5 Free** | $0.253 | $0.008 | **$0.261** | **10.0** |
| **DeepSeek V4 Flash Free** | $0.263 | $0.013 | **$0.276** | **9.5** |
| **MiniMax M3 Free** | $5.365 | $0.349 | **$5.714** | **0.5** |
| **Nemotron 3 Super Free** | — | — | **$0** (descartado) | — |

Nemotron se descarta del bloque C por no tener modelo de pago equivalente en la tabla de precios de OpenCode Zen.

Coste real del experimento: **$0** (todos los modelos fueron gratuitos). Las 3 llamadas de pago a `deepseek-v4-flash` ($0.0232 total) se excluyeron por no pertenecer al experimento.

El coste teórico de MiniMax M3 ($5.71) es 22 veces superior al de MiMo o DeepSeek ($0.26-$0.28), debido a su límite mensual mucho más restrictivo (7,000 vs ~155,000 requests). Esto no refleja necesariamente el precio real que OpenCode Zen aplicaría, sino la relación entre capacidad gratuita ofrecida y coste inferido.

---

## Bloque D — Privacidad y condiciones de uso

Según la política publicada de OpenCode Zen, los siguientes modelos gratuitos tienen cláusulas específicas de retención de datos:

| Modelo | Política aplicable | Implicación |
|---|---|---|
| **DeepSeek V4 Flash Free** | Durante su período free, los datos recogidos pueden usarse para mejorar el modelo | No usar con datos sensibles o confidenciales |
| **MiMo V2.5 Free** | Durante su período free, los datos recogidos pueden usarse para mejorar el modelo | No usar con datos sensibles o confidenciales |
| **Nemotron 3 Super Free** | Logs explícitos por NVIDIA. Solo trial. No producción ni datos sensibles. | Los prompts y outputs son registrados por NVIDIA |
| **MiniMax M3 Free** | No listado como excepción en la política de zero-retention | Mejor perfil de privacidad de los 4 |

Ninguno de los 4 modelos gratuitos es recomendable para información sensible, confidencial o sujeta a protección de datos.

---

## Nota global

### Pesos aplicados

Para calcular una nota global que refleje la importancia relativa de cada dimensión se usaron los siguientes pesos:

| Bloque | Peso | Justificación |
|---|---|---|
| **A1 — Media por pregunta** | 35% | Núcleo de la tarea: calidad de cada respuesta individual |
| **A2 — Coherencia global** | 15% | Cómo construye criterio acumulativamente a lo largo de la sesión |
| **A3 — Informe final** | 25% | El entregable tangible donde confluye todo el análisis |
| **B — Fluidez operativa** | 15% | Relevante pero secundario frente a la calidad del contenido |
| **C — Coste teórico** | 10% | Desempate entre modelos de rendimiento similar |

El bloque D (privacidad) no se integra en la nota porque no discrimina entre modelos free: todos tienen limitaciones.

### Cálculo

| Modelo | A1 (×35%) | A2 (×15%) | A3 (×25%) | B (×15%) | C (×10%) | **Global** |
|---|---|---|---|---|---|---|
| **DeepSeek V4 Flash Free** | 3.11 | 1.35 | 2.38 | 1.35 | 0.95 | **9.14** |
| **MiMo V2.5 Free** | 2.71 | 1.20 | 2.38 | 1.35 | 1.00 | **8.64** |
| **MiniMax M3 Free** | 2.73 | 0.98 | 2.25 | 1.15 | 0.05 | **7.16** |
| **Nemotron 3 Super Free** | 1.90 | 0.38 | 1.20 | 0.81 | — | **4.29*** |

\*Nemotron: sin nota C. Suma de A1(35%)+A2(15%)+A3(25%)+B(15%) = 90%.

**Sensibilidad de los pesos:** Para quien desee aplicar ponderaciones distintas, los datos brutos de cada bloque están disponibles en las secciones anteriores. La nota global puede recalcularse multiplicando cada columna por el peso deseado.

---

## Perfiles cualitativos por modelo

### DeepSeek V4 Flash Free — Líder global (9.14)
**Fortalezas:** Mejor profundidad analítica de los cuatro. Capacidad para detectar patrones transversales entre preguntas. Rankings estables y criterio homogéneo. Sin errores operativos. Informe de determinismo completo y preciso (ID=38.6%), escrito sin recordatorio. Mejor informe final de los cuatro.

**Debilidades:** Ligeramente más lento que MiMo en tiempo LLM (305s vs 213s). Coste teórico marginalmente superior.

**Perfil:** Recomendado para tareas analíticas complejas donde la profundidad y la coherencia importan más que la velocidad.

### MiMo V2.5 Free — Segundo (8.64)

**Fortalezas:** El más rápido (213s, 3.6 min). Rankings estables. Coste teórico mínimo. Detectó matices que los demás pasaron por alto (recalibración negativa). Informe de determinismo muy completo (ID por nivel), el mejor en profundidad técnica y formato (10 secciones + 3 apéndices).

**Debilidades:** Mezcla de idiomas (2 caracteres chinos en P1/P2). Error de formato en P3 (no emparejó vr con v). En P2 no conectó vr con su padre v.

**Perfil:** Opción competitiva si se toleran errores de formato menores. No recomendado para tareas que requieran seguimiento preciso de instrucciones de formato.

### MiniMax M3 Free — Competente pero lento (7.16)

**Fortalezas:** Respuestas completas a las 8 preguntas. Informe de determinismo extenso y bien estructurado. Sin errores significativos de procesamiento (1 carácter chino aislado).

**Debilidades:** Extremadamente lento (3.7× más que MiMo). Coste teórico desfavorable. Algunas inconsistencias de criterio entre preguntas.

**Perfil:** Utilizable si el tiempo de respuesta no es un factor relevante. No recomendado para sesiones interactivas o iterativas.

**Nota metodológica:** El perfil de MiniMax M3 (1,400 req/5h en OpenCode Go) lo sitúa en la categoría de modelos de razonamiento profundo, análogo a DeepSeek V4 Pro (3,450 req/5h) en la comparativa [research/deepseek-battle-compaction/README.es.md](https://github.com/criterium/opencode-lab/blob/main/research/deepseek-battle-compaction/README.es.md). En esa investigación se observó que Pro fracasaba en tareas de extracción y síntesis porque "sobre-analiza y filtra por juicio", mientras que modelos de extracción como Flash (31,650 req/5h) producían mejores resultados a 1/13 del coste y 4× más rápido. MiniMax M3, con un límite aún más restrictivo (1,400), probablemente comparte esa misma tendencia al sobre-análisis, lo que explicaría su lentitud y sus inconsistencias de criterio en una tarea que requería comparación y síntesis rápidas. Esto no lo exime del resultado, pero ayuda a contextualizarlo: no es el modelo adecuado para este tipo de trabajo.

### Nemotron 3 Super Free — No recomendable (4.29)

**Fortalezas:** Ninguna relevante para esta tarea.

**Debilidades:** P6 sin respuesta. P3 requirió repetición. P8 no escribió archivo (2 recordatorios). Rankings contradictorios. Tiempo extremo (5.7× más que MiMo). Mayor consumo de tokens (3.2M input, duplicando a los demás). Sesión con 34 llamadas vs ~20 del resto.

**Perfil:** No recomendado para tareas analíticas secuenciales. Sus fallos operativos y su inconsistencia interna lo descartan frente a las alternativas.

---

## Evolución intra-sesión: la calidad por pregunta

Trazar la nota de cada modelo pregunta por pregunta revela cómo se comportan bajo una secuencia de 8 tareas acumulativas:

| Pregunta | DeepSeek | MiMo | MiniMax | Nemotron |
|---|---|---|---|---|
| **P1** — modelov* | 9.0 | 7.5 | 7.5 | 7.0 |
| **P2** — modelovr* | 9.0 | 7.0 | 7.5 | 7.0 |
| **P3** — Tabla pares | **9.5** | **6.0** | 8.0 | 5.0 |
| **P4** — READMEv* | 8.5 | 8.0 | 7.5 | 7.0 |
| **P5** — READMEr* | 9.0 | 8.5 | 8.0 | **4.0** |
| **P6** — Tabla pre/post | 8.5 | 8.0 | 7.5 | **0.0** |
| **P7** — Diseño métrico | 8.5 | 8.5 | 8.0 | 7.0 |
| **P8** — Informe | 9.0 | 8.5 | **8.5** | 6.5 |

| Modelo | Rango | Tendencia |
|---|---|---|
| **DeepSeek** | 8.5-9.5 (σ=0.35) | **Estable →**. Se mantiene en una banda estrecha de alta calidad. Sin apenas variación. |
| **MiMo** | 6.0-8.5 (σ=0.89) | **Variable ↑**. Empieza bien (7.5), colapsa en P3 (6.0) por no respetar el formato, y se recupera progresivamente hasta 8.5. Sus errores se concentran al principio. |
| **MiniMax** | 7.5-8.5 (σ=0.38) | **Estable ↑**. Mejora ligeramente con el tiempo. Empieza en 7.5 y termina en 8.5, con una progresión casi lineal. |
| **Nemotron** | 0.0-7.0 (σ=2.39) | **Errática ↓**. Comienza aceptable (7.0) pero colapsa en P5-P6 (inglés + respuesta vacía). Se recupera parcialmente al final pero sin alcanzar su nivel inicial. |

**Observaciones clave:**

- **MiMo** muestra el patrón más interesante: su peor momento es P3 (no emparejó vr con v), pero luego aprende y se recupera hasta empatar con DeepSeek en P7-P8. Esto sugiere que sus errores son de atención al formato, no de capacidad analítica. La pregunta que más penaliza el formato (P3) es la que más lo separa del líder.

- **DeepSeek** no tiene altibajos. Su rendimiento es plano y alto. No aprende porque no necesita hacerlo — ya empieza en un nivel que los demás alcanzan solo al final (o nunca).

- **Nemotron** colapsa justo en las preguntas que requieren seguir instrucciones precisas (P5: idioma, P6: tabla). Su recuperación parcial en P7-P8 es insuficiente y tardía.

- **La evolución no correlaciona con el tiempo invertido.** MiMo tardó 213s (el más rápido) y aún así mejoró con las preguntas. Nemotron tardó 1207s (el más lento) y empeoró. El tiempo no es garantía de calidad.

---

## Validación cruzada: determinismo de la propia evaluación

Para medir la estabilidad de esta misma evaluación, un mismo modelo evaluó los 4 informes finales de determinismo (A3) en **10 sesiones independientes** con idéntico prompt y criterios numéricos 0-10. Los resultados confirman el patrón del ID bajo descrito por DeepSeek:

| Modelo evaluado | Media 10 sesiones | σ | Nuestro A3 | Diferencia |
|---|---|---|---|---|
| **MiMo V2.5 Free** | 8.89 | 0.30 | 9.5 | +0.61 |
| **DeepSeek V4 Flash Free** | 8.74 | 0.49 | 9.5 | +0.76 |
| **MiniMax M3 Free** | 7.55 | 0.52 | 9.0 | +1.45 |
| **Nemotron 3 Super Free** | 4.19 | 0.72 | 4.8 | +0.61 |

**Estabilidad ordinal:** 100% de acuerdo en que MiniMax es 3º y Nemotron 4º. 60% de acuerdo en que MiMo es 1º vs DeepSeek (diferencia media entre ambos: solo 0.15 puntos). El ranking ordinal es fiable; las puntuaciones absolutas varían ±0.5 puntos de media.

Los detalles completos de estos ID y su cálculo están en `research/deepseek-v4-flash-determinism/README.es.md`.

Nuestras notas A3 y B4 son consistentes con el consenso del modelo, aunque sistemáticamente ~1 punto por encima de su media. No hay error sistemático — solo el modelo siendo menos generoso consigo mismo que el evaluador humano que analizó las sesiones completas.

---

## Qué hemos aprendido

Lecciones prácticas para el uso diario de LLMs en tareas analíticas:

1. **No uses Nemotron.** Es la única conclusión sólida de todo el estudio. Falla donde otros aciertan, es lento donde otros son rápidos, y se contradice a sí mismo.

2. **DeepSeek es la opción por defecto para análisis.** Si no sabes qué modelo elegir para una tarea de comparación o síntesis de documentos, empieza con DeepSeek. Su coherencia de criterio (σ=0.35) y su nula tasa de errores lo hacen fiable incluso en sesiones largas.

3. **MiMo es la opción rápida con reservas.** Si el tiempo importa, MiMo es 1.4× más rápido que DeepSeek. Pero revisa los formatos de salida: puede mezclar idiomas o ignorar instrucciones de estructura.

4. **MiniMax para pensamiento profundo muy focalizado, no para análisis panorámicos.** Su lentitud (3.7×) y coste teórico (22×) lo descartan para tareas que requieran barrido amplio o iteración rápida. Sin embargo, su perfil de razonamiento profundo —consistente con su límite de 1,400 req/5h, análogo a modelos de alta capacidad— podría ser adecuado para problemas muy acotados que requieran una sola respuesta meditada. Para el tipo de tarea de este estudio (comparación secuencial de 8 preguntas sobre 12 documentos), no es el modelo adecuado.

5. **El informe final es un buen predictor de la calidad general.** Los dos mejores informes (DeepSeek y MiMo, A3=9.5) corresponden a los dos mejores evaluadores globales. Si necesitas evaluar a un modelo rápidamente, pídele un informe extenso y júzgalo por su profundidad y autonomía.

6. **Ningún modelo gratuito es adecuado para datos sensibles.** Todos los evaluados tienen cláusulas de retención de datos. Para trabajo confidencial, usa modelos de pago con zero-retention garantizada.

7. **Una sola evaluación no es suficiente.** La validación cruzada mostró que las puntuaciones varían ±0.5 pts entre sesiones del mismo modelo. Cualquier decisión basada en una única evaluación debe tomarse con ese margen de error.

8. **Profundidad analítica ≠ determinismo.** Los modelos que exploran más caminos de razonamiento (DeepSeek) producen mayor divergencia entre forks, pero también mayor riqueza de insights. Un análisis más profundo genera respuestas más diversas, no más parecidas. El bajo determinismo puede ser señal de riqueza analítica, no de defecto.

---

## Glosario

| Término | Significado |
|---|---|
| **A1** | Media de puntuaciones en las 8 preguntas del cuestionario |
| **A2** | Coherencia global: consistencia del criterio a lo largo de la sesión |
| **A3** | Calidad del informe final de determinismo que cada modelo escribió |
| **B1** | Completitud: porcentaje de preguntas respondidas |
| **B2** | Errores de procesamiento y formato |
| **B3** | Tiempo LLM puro (excluyendo tool calls de lectura) |
| **B4** | Formato y estructura del informe final |
| **B** | Media de B1+B2+B3+B4 |
| **C** | Coste teórico estimado por sesión |
| **D** | Privacidad y condiciones de uso |
| **σ** | Desviación típica (medida de variabilidad) |
| **ID** | Índice de Determinismo (0-100%, mide consistencia entre forks) |
| **P1-P8** | Las 8 preguntas del cuestionario secuencial |
| **modelov\*** | Documentos de análisis de las 3 opciones (fork 1, 2, 3) |
| **modelovr\*** | Documentos de recomendación derivados de cada fork |
| **READMEv\*** | Documentos principales de investigación (versión ciega) |
| **READMEr\*** | Documentos recalibrados tras revelar las etiquetas reales |
| **Single-blind** | Metodología donde el evaluado no conoce la verdad pero el evaluador sí |
| **Token** | Unidad de texto que el modelo procesa (~0.75 palabras en español) |
| **Fork** | Copia independiente de una sesión que hereda el historial completo |

---

## Nota final

Este estudio comparó 4 modelos LLM gratuitos de OpenCode Zen en una tarea de evaluación analítica secuencial de 8 preguntas sobre 343 KB de documentos técnicos. Se evaluaron 5 dimensiones con pesos A1=35%, A2=15%, A3=25%, B=15%, C=10%.

**Para este tipo de tarea (evaluación analítica secuencial de documentos), el orden de preferencia es:**

| Prioridad | Modelo | Global | Fortaleza principal | Debilidad principal |
|---|---|---|---|---|
| 🥇 | **DeepSeek V4 Flash Free** | **9.14** | Profundidad analítica, coherencia, sin errores | Ligeramente más lento que MiMo |
| 🥈 | **MiMo V2.5 Free** | **8.64** | Más rápido, mejor informe final en técnica y formato | Errores de idioma y formato en P2-P3 |
| 🥉 | **MiniMax M3 Free** | **7.16** | Informe final extenso y bien estructurado | Lento (3.7×), coste alto (22×), inconsistencias |
| ❌ | **Nemotron 3 Super Free** | **4.29** | Ninguna relevante | Fallos operativos, inconsistencia, lentitud |

> **Nota:** este ranking refleja el desempeño en tareas de comparación y síntesis de documentos. Otros tipos de tarea (generación de código, traducción, clasificación) podrían favorecer modelos distintos. En particular, MiniMax M3, penalizado aquí por su lentitud, podría rendir mejor en problemas que requieran una sola respuesta de razonamiento profundo sin presión de tiempo.
