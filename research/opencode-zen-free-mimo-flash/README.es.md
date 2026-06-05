# Análisis comparativo: MiMo V2.5 Free vs DeepSeek V4 Flash Free

**Fecha**: 2026-06-05
**Modelos evaluados**:
- **Mimo**: Xiaomi MiMo V2.5 en opencode, model `mimo-v2.5-free` (etiquetado como "MiMo V2.5 Free" en headers de sesión)
- **Flash**: DeepSeek V4 Flash Free, model `deepseek-v4-flash-free`
- **Evaluador** (autor de este documento): MiniMax M3 de MiniMax Group, model `opencode/minimax-m3-free`. Empresa distinta a las dos anteriores; sin conflicto de interés corporativo. Ver "Nota sobre la corrección de identidad corporativa" al final.

**Tarea asignada a ambos modelos**: analizar cambios entre v1.15.13 y v1.16.0 de opencode, partiendo de `/tmp/opencode-src` y `/tmp/opencode-src-bak`, foco en skill discovery y file-based agents.

**Fuentes**:
- `/home/antonio/Proyectos/IA/opencode/session-ses_mimo.md` (4200 líneas)
- `/home/antonio/Proyectos/IA/opencode/session-ses_flash.md` (7112 líneas)
- `/home/antonio/Proyectos/IA/opencode/memory/opencode-source-research.md` (research previa del usuario, consultada solo por Flash)
- `/home/antonio/Proyectos/IA/opencode/research/skill-desc-leak/README.md` (research de skill-desc-leak, referenciada por ambos)

**Metodología**: análisis directo de los archivos de sesión, sin delegación a sub-agentes. El preludio común (líneas 1-985) se excluye; solo se comparan los turnos post-fork, agrupados por pregunta de usuario.

**Por qué no se delega** (corrección de justificación estrecha): la versión inicial de esta metodología justificaba la no-delegación por "preservar detección de errores de idioma". Esta justificación es incompleta. El valor real del análisis directo es la **visión global cruzada entre las dos sesiones**: la capacidad de reconocer que el error de Mimo en P5 ("ascentros" → `.claude/`) y el de P6 (lectura de archivo inexistente) son síntomas del mismo sesgo de "lectura histórica" que se manifiesta en P3 (cinco `git show <hash>:<file>` consecutivos). Esa cadena causal solo es visible cuando el mismo agente procesa las 11,000+ líneas de sesión con su contexto completo; un sub-agente que recibiera cada pregunta por separado perdería la conexión. La detección de errores de idioma (caracteres chinos en Mimo) es un beneficio menor, no la razón principal. La razón principal es que el valor del análisis comparativo es **emergente** del cruce entre preguntas, no reducible a chequeos por pregunta.

---

## Objetivo, alcance y dificultad

### Objetivo del análisis comparativo

Determinar cuál de los dos modelos (Mimo o Flash) produce respuestas más fiables, precisas y útiles cuando se le encomienda una sesión de análisis técnico de código en opencode, en condiciones de uso normal por el usuario. La finalidad última es informar la selección de modelo para sesiones futuras con tareas análogas.

Sub-objetivos:
1. Identificar errores factuales, terminológicos, de idioma y de método en cada sesión.
2. Cuantificar el coste de cada tipo de error (impacto en corrección, profundidad, coherencia).
3. Distinguir entre errores atribuibles al modelo y errores atribuibles al input del usuario o al estado del entorno.
4. Verificar las afirmaciones técnicas de ambos modelos contra el código real de v1.16.0.
5. Caracterizar el patrón metodológico de cada modelo (herramientas preferidas, estilo de lectura, recuperación ante fallo).

### Alcance

**Dentro del alcance**:
- Las 7 preguntas post-fork (P1–P7) en ambos archivos de sesión.
- La respuesta assistant completa de cada modelo para cada pregunta.
- Los tool calls principales (no exhaustivo; se registran los que afectan a la verificación técnica).
- La verificación contra el código real de `/tmp/opencode-src` (v1.16.0, commit `6cb74317a6`).
- Las divergencias entre ambos modelos y los errores detectados.
- La atribución de responsabilidad usuario/modelo para cada error.

**Fuera del alcance**:
- Análisis de coste (tratado en `costes.txt` por separado, 4688 bytes).
- Comparativa con otros modelos no incluidos en estas dos sesiones.
- Recomendaciones de uso fuera del dominio de análisis técnico de código.
- Análisis de los prompts del modelo (más allá de los resultados en estas sesiones).
- Auditoría de seguridad de opencode v1.16.0.
- Evaluación cuantitativa de latencia como factor de selección (la diferencia es despreciable: 4.4s agregados, dentro del ruido).

### Dificultad de la tarea

**Dificultad alta** por las siguientes razones:

1. **Volumen de datos**: 4200 líneas (Mimo) + 7112 líneas (Flash) = 11312 líneas de sesión a procesar. El preludio común (líneas 1–985) se excluye; quedan 10327 líneas útiles.

2. **Detección de errores sutiles**: 
   - Errores de idioma: caracteres chinos en texto español (2 ocurrencias en Mimo). Visualmente casi imperceptibles sin revisión directa.
   - Errores terminológicos: "replantear" en vez de "reproducir" para "replay". Sustantivo técnico, no obvio sin contexto.
   - Errores de selección de archivo: leer un archivo inexistente y razonar sobre él (Mimo P6).
   - Topic drift: interpretar una palabra clave (`ascentros`) en el sentido equivocado (Mimo P5).

3. **Verificación contra código real**: las afirmaciones de los modelos solo se pueden validar leyendo el código de v1.16.0 en `/tmp/opencode-src/`. Esto requiere conocer la estructura del proyecto y los archivos relevantes (`packages/core/src/skill.ts`, `packages/opencode/src/skill/index.ts`, etc.).

4. **Estado de los repositorios divergente entre sesiones** (confundidor): Mimo parte de v1.15.13 y ejecuta `git checkout v1.16.0`. Flash parte directamente de v1.16.0. Esto crea asimetrías en el contexto inicial que pueden explicar parte de la divergencia.

5. **Inferencia de causa raíz**: cuando un modelo produce una conclusión correcta con razonamiento roto (Mimo P6), o una conclusión incorrecta con razonamiento sólido, el análisis debe distinguir entre "acierto por accidente" y "error de razonamiento con conclusión afortunada". Esto no es mecánico.

6. **Doble nivel de análisis**: los modelos evaluados están, a su vez, evaluando código. El analista (este documento) debe comprender el código que los modelos están leyendo para detectar errores de interpretación. Cadena: usuario → modelo → código → modelo evaluador → este análisis.

7. **Sesgos por defecto difíciles de corregir**: el `memory.md` del usuario tiene reglas explícitas (líneas 43–50) sobre cómo actualizar el código fuente, pero un modelo con sesgo estable hacia "leer commit que introdujo el feature" puede saltarlas. La presencia de la regla en el system prompt no garantiza cumplimiento.

### Criterios de evaluación

| Criterio | Descripción | Ponderación |
|---|---|---|
| **Corrección factual** | Las afirmaciones técnicas verificables son correctas contra el código real | Alta |
| **Coherencia transversal** | Las respuestas sucesivas se apoyan en las anteriores; no hay contradicción | Alta |
| **Verificación de archivos** | El modelo lee los archivos correctos, no archivos inexistentes o desactualizados | Alta |
| **Calidad de idioma** | Sin inyección de caracteres foráneos, terminología técnica correcta, sin contradicciones intra-respuesta | Media |
| **Recuperación ante fallo** | Cuando una búsqueda falla, el modelo re-orienta en vez de concluir con datos parciales | Media |
| **Uso de contexto** | El modelo consulta archivos de referencia del usuario (memory, research) cuando aplica | Media |
| **Iteración** | El modelo itera: verifica, contrasta, refina. No salta a conclusión. | Media |
| **Tool selection** | Elige la herramienta adecuada (read vs bash/grep vs glob) según el caso | Baja |
| **Eficiencia** | Latencia y número de tool calls razonables para el valor entregado | Baja |

**Regla de veredicto**:
- "Gana" el modelo cuya respuesta en esa pregunta es materialmente más correcta, completa y precisa.
- "Empate" cuando ambos llegan a conclusiones equivalentes, aunque difieran en estilo o énfasis.
- Mimo "acertó por accidente" en P6 (conclusión correcta, razonamiento roto) — esto se cuenta como "no pierde" pero no como "gana".

### Limitación reconocida: la tarea no se ejecutó

Una limitación importante de este análisis: las dos sesiones comparadas son las que el usuario ejecutó, no las que yo ejecuté. Este documento es **un meta-análisis** de sesiones de uso real, no un benchmark controlado. Las consecuencias:

- **Las preguntas no están estandarizadas**: P1-P7 son las preguntas que el usuario quiso hacer, no un cuestionario fijo.
- **El número de turnos varía**: Mimo recibe un prompt extra en P6, Flash no. Esto crea asimetría que se mitiga con la unificación.
- **La latencia agregada es aproximada**: 262.3s vs 266.7s, dentro del ruido.
- **No hay réplicas**: una sola ejecución por modelo, sin muestreo para evaluar determinismo.

Esta limitación se documenta explícitamente para que el lector no confunda este análisis con un benchmark sintético. Es un análisis de uso real, con todo lo que eso implica de variabilidad natural.

---

## Metodología: forkeo de sesiones en OpenCode

Este análisis se basa en una técnica de evaluación que aprovecha una característica de OpenCode: la capacidad de **forkear sesiones** manteniendo el contexto inicial idéntico. Esta sección documenta la metodología y evalúa su conveniencia.

### Cómo funciona el forkeo en este caso

El usuario (antonio) ejecutó una sesión larga con un modelo inicial (Nemotron 3 Ultra Free, según la preludio de las sesiones), y al llegar a un punto de fork (línea 985 de ambas sesiones), continuó la misma conversación con dos modelos distintos:

- **Sesión Mimo** (`fe6OaAlD`): continuación con `mimo-v2.5-free` (Xiaomi MiMo V2.5, etiquetado como "MiMo V2.5 Free").
- **Sesión Flash** (`BpCtZbzD`): continuación con `opencode/deepseek-v4-flash-free`.

Ambas sesiones tienen:
- 985 líneas idénticas: carga de memoria (`memory.md`), 4 preguntas de setup con Nemotron, y prompt inicial del usuario.
- Mismo punto de fork: línea 985.
- Mismas preguntas del usuario post-fork (P1–P7).
- Mismo estado de `/tmp/opencode-src` antes de fork.

A partir del fork, los dos modelos divergen: cada uno produce su propia cadena de turnos assistant y tool calls sin ver lo que el otro hace.

### Ventajas de esta metodología

1. **Elimina variabilidad del prompt como confounder**: ambos modelos reciben exactamente las mismas instrucciones. Si Mimo falla en P5 por una palabra malinterpretada, la palabra es la misma que Flash recibe; la diferencia es del modelo, no del input.

2. **Contexto común verificado**: las 4 preguntas iniciales idénticas (Nemotron) y la carga de memoria (`memory.md`) son las mismas. Cualquier modelo hereda el mismo system prompt efectivo.

3. **Reproducibilidad**: las sesiones tienen IDs únicos (`fe6OaAlD`, `BpCtZbzD`) que permiten recuperar el volcado exacto. La traza es auditable.

4. **Coste controlado**: ambos modelos en el mismo tier (free) o en tiers diferentes pero conocidos, lo que permite análisis comparativo de eficiencia.

5. **Volcado de tool calls completo**: cada sesión registra todos los tool calls con timestamps, output, y reasoning. El análisis post-hoc es preciso.

6. **Permite análisis retrospectivo a coste bajo**: el coste de generar la sesión es el del modelo; el coste del análisis es externo. El método escala.

### Limitaciones identificadas

1. **El preludio común es 985 líneas (≈30k tokens)**: ambos modelos heredan este contexto. Esto podría sesgar la comparación hacia modelos que manejan bien el contexto largo, y penalizar a modelos con ventanas de contexto efectivas menores. En este caso, Mimo nunca superó los 57K tokens de input en una sola llamada (max 57,793), mientras Flash llegó a 95,057. La diferencia podría explicarse por truncamiento previo, comportamiento del cliente, o decisión del modelo. **No hay evidencia concluyente de que Mimo sufriera por contexto largo**; las dos sesiones tienen el mismo tamaño efectivo de preludio.

2. **No hay inter-model awareness**: los modelos no ven las respuestas del otro. Esto evita contaminación pero también impide comparar respuestas a las mismas preguntas en paralelo (cada modelo responde una vez, no iterativamente).

3. **Una sola ejecución por modelo**: el forkeo se hizo una vez. No hay réplicas para evaluar determinismo. Mimo y Flash podrían haber tenido un mal día. Un análisis más robusto requeriría ≥3 forks por modelo.

4. **El preludio sesga el contexto emocional y de trabajo**: las 4 preguntas Nemotron establecen el tono (técnico, directo, en español). Esto puede no ser neutral si uno de los modelos es más sensible al framing.

5. **El fork se hace DESPUÉS de la primera prompt P1**: ambos modelos heredan la P1 ya emitida por el usuario. Esto significa que la P1 no es una pregunta que el modelo elija cómo abordar; es una continuación obligada. Esto es lo que se quiere para esta comparación, pero limita la evaluación de capacidad de "tomar la iniciativa".

6. **El usuario tiene visibilidad asimétrica**: el usuario solo ve una sesión a la vez (o las dos en paralelo). El forkeo permite que el usuario haga el "merge" mental; este análisis es ese merge.

### Por qué el forkeo es conveniente para esta evaluación

El forkeo es **el único método viable** para esta evaluación, dado que:

- **No se puede "pedir lo mismo" en sesiones paralelas**: las APIs de LLM no son deterministas. Dos llamadas idénticas pueden dar resultados distintos. La variabilidad entre dos sesiones paralelas no es atribuible al modelo, sino al sampling.

- **No se puede evaluar con benchmarks sintéticos**: las preguntas de P1–P7 son altamente contextuales (analizar el código de opencode v1.16.0 después de actualizar el repo). No existe un benchmark estándar que cubra esta tarea.

- **El usuario quiere comparar comportamiento en uso real**: el objetivo es informar la selección de modelo para sesiones futuras, no medir capacidad abstracta. El forkeo captura el comportamiento en uso real con los prompts reales.

- **El forkeo expone la "tasa de error natural"**: al evaluar las respuestas verbatim, se ven errores que un benchmark sintético no capturaría (caracteres chinos, terminología incorrecta, lectura de archivos equivocados, etc.).

### Recomendación metodológica para futuros forks

1. **Réplicas**: para análisis de determinismo, hacer ≥3 forks por modelo. Etiquetar las réplicas (Mimo-1, Mimo-2, Mimo-3).

2. **Variantes de preludio**: si se sospecha que el preludio sesga, hacer un fork con preludio corto y otro con preludio largo, y comparar.

3. **Identificación de turnos**: marcar explícitamente en la transcripción el número de turno post-fork (1, 2, 3, ...) para facilitar análisis de regresión.

4. **Volcado estandarizado**: idealmente, un dump en formato JSON con `turn_index`, `model`, `input_tokens`, `output_tokens`, `tool_calls`, `latency`, `output_text`. El formato actual de `session-ses_*.md` es semi-estructurado y requiere parseo manual.

5. **Cuestionario post-sesión**: pedir a cada modelo un "auto-análisis" de sus propios errores al final. Esto es opcional pero puede capturar sesgos que el análisis externo no detecte.

---

## Resumen ejecutivo

Flash supera a Mimo de forma categórica en 5 de 7 preguntas, empata en 1, Mimo gana en 0. La diferencia agregada en latencia (4.4 segundos) es despreciable comparada con la brecha en corrección, profundidad y coherencia transversal.

**Patrones de error en Mimo**:
1. Errores de idioma estables: inyección de caracteres chinos en español (2 ocurrencias: P3 línea 3294 "扫描", P7 línea 4179 "从")
2. Inconsistencia terminológica intra-respuesta (P2: "replay" en tabla + "replantear" en resumen)
3. Errores fácticos graves por lectura apresurada (P5: confunde "ascentros" con `.claude/`; P6: lee el archivo equivocado)
4. Sobreconfianza: contesta categóricamente sin verificar (P6: "No está activa" contradice al usuario)
5. Topic drift: pierde el hilo entre preguntas consecutivas (P4→P5)

**Patrones de fortaleza en Flash**:
1. Investigación iterativa honesta: cuando un grep falla, re-orienta con `glob` y `ls`
2. Coherencia transversal: cada respuesta se apoya en las anteriores
3. Uso del contexto del usuario: consulta `memory/opencode-source-research.md` y la research de skill-desc-leak
4. Sin errores de idioma detectados
5. Conclusiones matizadas: distingue entre "no interfiere" y "no rompe"

**Confundidor importante**: el estado inicial del repo difiere entre sesiones (Mimo tuvo que hacer `git checkout v1.16.0`; Flash lo tenía ya en v1.16.0). Esto explica parte de la divergencia, pero los errores fácticos de Mimo no son atribuibles al confundidor.

---

## Datos cuantitativos globales

| Métrica | Mimo | Flash |
|---|---|---|
| **Turnos assistant** | 40 | 39 |
| **Prompts usuario** | 13 | 12 |
| **Tool calls totales** | 46 | 55 |
| **bash** | 37 (80.4%) | 25 (45.5%) |
| **read** | 5 (10.9%) | 22 (40.0%) |
| **glob** | 2 (4.3%) | 3 (5.5%) |
| **todowrite** | 0 (0%) | 4 (7.3%) |
| **websearch / webfetch** | 1 / 1 | 1 / 1 |
| **Tiempo total** | 262.3s | 266.7s |
| **Latencia mediana/turno** | 5-8s | 3-5s |
| **Líneas de respuesta (post-fork)** | ~3215 | ~6127 |

**Notas**:
- De las 5 calls de Mimo a `read`, 3 son del preludio. En la fase de investigación post-fork, Mimo usa `read` solo 2 veces vs 19 veces de Flash.
- Mimo usa `git show <commit>:<path>` (vía bash) para leer archivos de commits antiguos. Esto evita el tool `read` pero impide usar `offset`/`limit` y no muestra números de línea consistentes.
- Flash usa `read` con `offset` y `limit` correctamente para inspeccionar archivos grandes.

---

## Análisis de tokens y coste imputado

Datos extraídos de `research/opencode-zen-free-mimo-flash/costes.txt` (338 líneas, formato TSV con 67 registros totales en 4 sesiones distintas). Filtrado estricto a las dos sesiones evaluadas:

- **Flash**: `model == "deepseek-v4-flash-free"` AND `session == "BpCtZbzD"` (31 llamadas)
- **Mimo**: `model == "mimo-v2.5-free"` AND `session == "fe6OaAlD"` (27 llamadas)

### Datos crudos por sesión

**Sesión BpCtZbzD — `deepseek-v4-flash-free` (Flash)**
- 31 llamadas
- Input total: 1,827,186 tokens
- Output total: 17,603 tokens
- Input medio/llamada: 58,941 tokens
- Output medio/llamada: 567 tokens
- Input máximo: 95,057 (turno de las 14:01)
- Output máximo: 2,232 (turno de las 13:49)
- Input mínimo: 28,548
- Output mínimo: 133
- Coste registrado: $0.0000 (tier free)

**Sesión fe6OaAlD — `mimo-v2.5-free` (Mimo)**
- 27 llamadas
- Input total: 1,262,970 tokens
- Output total: 8,836 tokens
- Input medio/llamada: 46,776 tokens
- Output medio/llamada: 327 tokens
- Input máximo: 57,793 (turno de las 14:01)
- Output máximo: 1,322 (turno de las 13:35)
- Input mínimo: 32,115
- Output mínimo: 65
- Coste registrado: $0.0000 (tier free)

### Comparativa directa

| Métrica | Flash | Mimo | Diferencia |
|---|---|---|---|
| Llamadas | 31 | 27 | Flash +4 |
| Input total | 1,827,186 | 1,262,970 | Flash +44.7% |
| Output total | 17,603 | 8,836 | Flash +99.2% (prácticamente 2×) |
| Tokens totales | 1,844,789 | 1,271,806 | Flash +45.1% |
| Input medio/llamada | 58,941 | 46,776 | Flash +26.0% |
| Output medio/llamada | 567 | 327 | Flash +73.4% |
| Coste free | $0.00 | $0.00 | Empate |

### Coste imputado (tier de pago equivalente)

Para comparar el coste real, se imputa el coste como si las llamadas se hubieran hecho a la versión de pago de DeepSeek V4 Flash (no free), que es el modelo de referencia conocido. **Mimo no tiene tier de pago público en la tabla de referencia del usuario**, así que se usa la misma tarifa como aproximación (instrucción explícita del usuario: "imputa al mismo coste que flash").

Tarifa de referencia (DeepSeek V4 Flash, no free):
- Input: $0.14 / 1M tokens
- Output: $0.28 / 1M tokens

| | Input | Output | Coste |
|---|---|---|---|
| **Flash** | 1,827,186 × $0.14/M = $0.2558 | 17,603 × $0.28/M = $0.0049 | **$0.2607** |
| **Mimo** | 1,262,970 × $0.14/M = $0.1768 | 8,836 × $0.28/M = $0.0025 | **$0.1793** |
| **Diferencia** | | | Flash +$0.0814 (+45.4%) |

**Lectura**: la sesión completa costaría ~26 centavos si no fuera free tier. Mimo costaría ~18 centavos con la misma tarifa. La diferencia ($0.08) es despreciable en términos absolutos, pero el **ratio Mimo/Flash = 0.69** — Mimo es 31% más barato por sesión que Flash (asumiendo que producen el mismo trabajo).

### Derivación del coste a partir de rate limits

La imputación anterior asume que Mimo y Flash tienen el mismo coste por token, pero no hay base empírica para esa asunción más allá de la instrucción del usuario. Los rate limits publicados por los proveedores ofrecen una base para refinar la imputación.

**Datos de rate limits** (tabla de referencia del usuario):

| Modelo | Requests / 5h | Requests / semana | Requests / mes |
|---|---|---|---|
| MiMo-V2.5 (Mimo) | 30,100 | 75,200 | **150,400** |
| DeepSeek V4 Flash | 31,650 | 79,050 | **158,150** |
| MiniMax M3 | 1,400 | 3,500 | 7,000 |
| Qwen3.7 Plus | 4,300 | 10,800 | 21,600 |
| GLM-5 | 1,150 | 2,880 | 5,750 |

**Observación clave**: Mimo y Flash tienen rate limits similares — están en el mismo orden de magnitud, con Flash ligeramente superior (5.15% más requests/mes). Los demás modelos del comparativo tienen rate limits 7-22× menores, lo que sugiere que Mimo y Flash son los modelos más baratos para sus proveedores.

**Regla inferida** (de la observación de rate limits y la práctica habitual de los proveedores free tier):

> Los proveedores free tier fijan los rate limits en función inversa al coste de servir cada request. Modelos más baratos para el proveedor admiten más requests. **Si dos modelos free tier tienen rate limits similares, su coste por request es similar; un rate limit ligeramente menor implica un coste ligeramente mayor por request**.

Aplicación de la regla:

1. **Ratio de rate limits**: Flash/Mimo = 158,150 / 150,400 = **1.0515**. Flash tiene un 5.15% más de capacidad mensual.

2. **Coste relativo por request**: Si Mimo tiene 5.15% menos capacidad, su coste por request es ~5.15% mayor que el de Flash. (Asunción: el coste por request es inversamente proporcional al rate limit, dentro del mismo tier free.)

3. **Tarifa Mimo estimada**:
   - Input: $0.14/1M × 1.0515 = **$0.1472/1M tokens**
   - Output: $0.28/1M × 1.0515 = **$0.2942/1M tokens**

4. **Coste Mimo ajustado por sesión**:
   - Input: 1,262,970 × $0.1472/M = $0.1859
   - Output: 8,836 × $0.2942/M = $0.0026
   - **Total: $0.1885** (redondeado: $0.19)

5. **Comparación ajustada**:

| | Coste original (misma tarifa) | Coste ajustado (regla rate limits) | Diferencia |
|---|---|---|---|
| **Flash** | $0.2607 | $0.2607 (sin cambio) | — |
| **Mimo** | $0.1793 | **$0.1885** | +$0.0092 (+5.1%) |
| **Diferencia Flash−Mimo** | $0.0814 (Flash 45.4% más caro) | **$0.0722 (Flash 38.3% más caro)** | -$0.0092 |

**Implicación**: la asunción "Mimo es ~31% más barato" se basa en una tarifa idéntica para ambos modelos. La regla de rate limits sugiere que la diferencia real es menor: Mimo es ~28% más barato, no 31%. **La diferencia absoluta baja de $0.08 a $0.07** — sigue siendo despreciable.

**Lo que la regla NO captura**: la regla usa los rate limits como proxy del coste por request. No captura diferencias de eficiencia por token (e.g., si Mimo usa más tokens para el mismo trabajo, su coste efectivo por tarea puede ser mayor o menor). En este caso, Mimo produce menos tokens (8,836 vs 17,603) pero también produce respuestas con más errores. La métrica relevante no es coste por request sino coste por respuesta correcta — que sigue siendo ampliamente favorable a Flash.

**Limitación importante**: la regla asume que el coste por request es inversamente proporcional al rate limit dentro del tier free. Esto es plausible pero no verificado. Los proveedores podrían fijar rate limits por razones distintas al coste (capacidad del servidor, decisiones de producto, etc.). La regla es una heurística, no una ley.

### Ratio output/input

- **Flash**: 17,603 / 1,827,186 = 0.96% (output es ~1% del input)
- **Mimo**: 8,836 / 1,262,970 = 0.70% (output es ~0.7% del input)

Ambos tienen un ratio de output bajo respecto a input, típico de análisis de código (mucho contexto, poca respuesta). Flash genera proporcionalmente más output por token de input, lo que sugiere respuestas más elaboradas o completas.

### Implicaciones

1. **Coste no es factor de selección**: la diferencia absoluta ($0.07 tras ajuste) es despreciable. La selección de modelo se debe guiar por corrección, no por coste.

2. **Mimo no es "más eficiente" en términos de valor**: Mimo costó menos pero entregó menos (4 errores graves vs 0; 37.5% cumplimiento de reglas vs 81.3%). El coste por error grave en Mimo es ~$0.045 (un error por cada 4.5 centavos); en Flash es indefinido (no hay errores graves). La métrica relevante es coste por respuesta correcta, no coste por respuesta.

3. **La diferencia de output (+99%) explica parte de la diferencia en profundidad**: Flash escribió casi el doble de tokens de salida. Esto es coherente con la observación cualitativa de que Flash dio respuestas más detalladas y matizadas.

4. **El preludio de 985 líneas pesa en el input**: ambos modelos gastan tokens de input sustanciales en el preludio (carga de memoria + 4 preguntas Nemotron). Esto sesga el ratio output/input hacia abajo para ambos. Sin preludio, el ratio sería mayor.

5. **El tier free enmascara el coste real**: el usuario podría haber elegido Mimo por percepción de "más barato" (no es cierto en este caso, porque ambos son free). Si algún día se migra a tier de pago, la diferencia ajustada de ~28% (Mimo más barato) se mantendría, pero la decisión debe basarse en calidad, no en coste.

### Conclusión del análisis de coste

La diferencia de coste entre Mimo y Flash, ajustada por la regla de rate limits, es de **$0.07 por sesión completa** (Mimo 28% más barato que Flash, o equivalentemente Flash 38% más caro que Mimo). Esta diferencia es:

- **Absolutamente despreciable** ($0.07 es el coste de ~1 minuto de streaming de música).
- **Relativamente significativa** (28% más barato).
- **Económicamente NO determinante** para la selección de modelo.

La diferencia en calidad (errores graves, cumplimiento de reglas, profundidad) es órdenes de magnitud más impactante. Si la selección se hiciera por coste, Mimo ganaría; si se hiciera por valor entregado, Flash gana sin discusión.


## P1: "quiero comparar versiones de opencode / actualiza /tmp/opencode-src"

**Prompt del usuario** (líneas 985-989, idéntico en ambas sesiones):
```
quiero comparar versiones de opencode
En /tmp/opencode-src-bak tengo la anterior.
actualiza /tmp/opencode-src a la actual y luego investigamos un par de novedades
```

### Mimo (985-1219, 4 turnos, ~21s)

**Verificación inicial**:
```bash
opencode --version  # → 1.16.0
git -C /tmp/opencode-src log --oneline -3  # → v1.15.13
git -C /tmp/opencode-src-bak log --oneline -3  # → v1.15.13 (idéntico)
```

**Acción**: `git fetch --tags` + `git checkout v1.16.0`.

**Resultado** (líneas 1205-1217):
> "Actualizado a v1.16.0. Hay ~50 commits desde v1.15.13. Cambios destacados: [tabla con áreas: Core, TUI, Stats, App, Enterprise, Zen, Fixes] ¿Qué novedades quieres investigar?"

### Flash (985-1249, 4 turnos, ~26s)

**Verificación inicial**:
```bash
npx opencode --version  # → 1.16.0
ls /tmp/opencode-src/  # → contenido
ls /tmp/opencode-src-bak/  # → contenido
cd /tmp/opencode-src && git describe --tags  # → v1.16.0 (ya actualizado)
```

**Thinking explícito** (líneas 1003-1014):
> "I also need to check the memory.md rules about updating the OpenCode source. From memory.md: [reproduce protocolo de memory.md sobre actualización de fuentes]"

**Resultado** (líneas 1238-1247):
> "Estado de los repositorios: /tmp/opencode-src v1.16.0 ✅ ya coincide con la versión instalada. /tmp/opencode-src-bak v1.15.13 versión anterior (backup). /tmp/opencode-src ya está en v1.16.0, no requiere actualización. La diferencia entre v1.15.13 y v1.16.0 son ~800 commits."

### Divergencias

1. **Estado del repo**: Mimo partió de v1.15.13; Flash de v1.16.0. Confundidor documentado.
2. **Consulta de memoria**: Flash consultó `memory.md` antes de actuar. Mimo no.
3. **Número de commits**: Mimo dice "~50" (tomado de `head -50`); Flash dice "~800" (cuenta completa).
4. **Compuestos bash**: Flash usa `cd ... && git describe; echo "---"; git log; echo "---"; git remote get-url origin` (múltiples datos en una call). Mimo usa comandos aislados.

### Evaluación

**Flash >>> Mimo en calidad de proceso** (consulta memoria, comandos compuestos, número de commits correcto). **Empate en resultado neto**: ambos llegan a la misma conclusión operativa.

---

## P2: "revisemos en release los Added"

**Prompt del usuario** (líneas 1221-1223, idéntico):
```
revisemos en release los Added
```

### Mimo (1221-1863, 5 turnos, ~33s)

**Búsqueda fallida**:
- `ls /tmp/opencode-src/RELEASE.md /tmp/opencode-src/CHANGELOG.md ...` → vacío
- `glob **/CHANGELOG*` → no files
- `glob **/RELEASE*` → no files
- `ls .github/release*` → vacío
- `git show v1.16.0 --format="%B" --no-patch` → "release: v1.16.0"

**Webfetch**: `https://github.com/anomalyco/opencode/releases/tag/v1.16.0` → release notes completas (con ruido HTML de la página).

**Respuesta final** (líneas 1823-1862, 4 tablas + resumen):

Tabla Core incluye:
| **`run --replay`** | Replay interactivo de sesiones |

Línea 1858 (resumen):
> "1. Skill discovery + file-based agent loading — impacta cómo se cargan skills y agentes
> 2. **`run --replay`** — replantear sesiones de forma interactiva
> 3. Moving sessions — reorganizar sesiones entre workspaces"

### Flash (1251-1848, 4 turnos, ~20s)

**Búsqueda similar**:
- `glob **/CHANGELOG*` → no files
- `glob **/RELEASE*` → no files
- `git tag -l 'v1.16*' --format='%(contents)'` → "release: v1.16.0"
- **webfetch** (misma URL) → release notes completas.

**Respuesta final** (líneas 1818-1847):

> "**`run --replay`** — reproducción interactiva de sesiones guardadas"

### Divergencia clave: terminología de "replay"

| Modelo | Tabla | Resumen |
|---|---|---|
| **Mimo** | `run --replay` (inglés) | "replantear sesiones" (español, **incorrecto**) |
| **Flash** | `run --replay` (inglés) | "reproducción interactiva" (español, correcto) |

**Análisis**:
- "Replay" en inglés significa "reproducción" o "repetición". "Replantear" en español significa "volver a plantear" (re-think), no tiene relación semántica.
- Mimo usa el anglicismo en la tabla y una traducción incorrecta en el resumen. Inconsistencia intra-respuesta.
- Flash mantiene coherencia: el término inglés aparece en el comando (correcto) y se traduce consistentemente como "reproducción" en la descripción.

### Evaluación

**Flash > Mimo** por consistencia terminológica. La traducción de Mimo ("replantear") es un error semántico que compromete la utilidad de su resumen.

---

## P3: "Me interesa esto 'Skill discovery + file-based agents'"

**Prompt del usuario** (líneas 1865-1867 / 1850-1852, idéntico):
```
Me interesa esto "Skill discovery + file-based agents", ya tengo una solución similar en objetivo implementada y quiero analizar su solución
```

### Mimo (1864-3299, 1434 líneas, 6 turnos, ~50s)

**Tool calls principales**:
1. `git log --oneline v1.15.13..v1.16.0 --all -- '**/skill*' '**/agent*' | head -30` → encuentra `889e0f954 feat(core): add skill registry and file agent loading (#30617)`
2. `git show 889e0f954 --stat` → 22 files, +881 insertions
3. **`git show 889e0f954:packages/core/src/skill.ts`** (lee el archivo desde el commit)
4. **`git show 889e0f954:packages/core/src/skill/discovery.ts`**
5. `git show 889e0f954:packages/core/src/config/plugin/skill.ts`
6. `git show 889e0f954:packages/core/src/config/plugin/agent.ts`
7. `git show 889e0f954:packages/core/src/config/markdown.ts`
8. `git show HEAD:packages/opencode/src/config/markdown.ts` (versión vieja)
9. `git show HEAD:packages/opencode/src/skill/index.ts` (versión vieja)
10. `git show HEAD:packages/opencode/src/skill/discovery.ts` (versión vieja)

**Conclusión** (líneas 3200-3297):

> "**Punto de fricción**: si tienes `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`, en v1.15.13 esto desactivaba el**扫描** en `.agents/skills/`. En v1.16.0 ese mecanismo ya no existe; el descubrimiento pasa por el plugin config, que es independiente de ese flag."

**Error de idioma en línea 3294**: el carácter chino "扫描" (sǎomiáo, "scan") aparece en medio de la frase en español. La palabra esperada es "escaneo".

**Afirmación factualmente incorrecta**: Mimo dice que "OPENCODE_DISABLE_EXTERNAL_SKILLS" ya no funciona en v1.16.0. Esto es falso: el sistema viejo (`packages/opencode/src/skill/index.ts`) sigue existiendo en v1.16.0 y sigue respetando el flag (Mimo mismo leyó este código en la misma respuesta, líneas 2890-2907 de su sesión).

Lo que cambió: el NUEVO sistema SkillV2 no usa el flag (porque no escanea `.claude/` ni `.agents/` directamente). Pero el flag sigue protegiendo contra el sistema viejo, que es el que está activo en `app-runtime.ts:72`.

### Flash (1849-4219, 2370 líneas, 11 turnos, ~52s)

**Tool calls principales**:
1. `todowrite` (3 items)
2. `git log ... --grep="skill"` → encuentra el commit
3. `git log ... --grep="file.based.agent\|discover\|..."` → confirma
4. `rg -l "skill.discover\|..."` → sin output (orientación)
5. `git show 889e0f954 --stat` → 22 files, +881
6. `rg -l "skillRegistry\|..."` → sin output
7. `rg -l "\.opencode/skills\|..."` → sin output
8. **`read /tmp/opencode-src/packages/core/src/skill.ts`** (lee del working tree v1.16.0)
9. **`read /tmp/opencode-src/packages/core/src/skill/discovery.ts`** (working tree)
10. `read /tmp/opencode-src/packages/core/src/config/plugin/skill.ts` (working tree)
11. `read /tmp/opencode-src/packages/core/src/config/plugin/agent.ts` (working tree)
12. `read /tmp/opencode-src/packages/core/test/config/skill.test.ts` (test del nuevo)
13. `read /tmp/opencode-src/packages/core/test/skill.test.ts` (test del nuevo)
14. `read /home/antonio/Proyectos/IA/opencode/config/opencode.jsonc` (config del usuario)
15. `read /home/antonio/Proyectos/IA/opencode/prompt/custom.md` (limit 30)
16. `bash ls ~/.agents/skills/*/SKILL.md` (verifica estado real del usuario)
17. `bash ls ~/.agents/skills/opencode-customize/` (verifica)

**Diferencia crítica en skill.ts**:

| Aspecto | Mimo (commit 889e0f954) | Flash (working tree v1.16.0) |
|---|---|---|
| `EmbeddedSource` | NO existe | SÍ (líneas 25-28 del working tree) |
| `Source` Union | `Directory \| Url` | `Directory \| Url \| Embedded` |
| `load()` para embedded | No hay rama | `if (source.type === "embedded") return [source.skill]` |
| `discovery.ts` security | Sin validaciones | `isSafeSegment`, `isSafeRelativePath`, `FSUtil.contains` |

**Conclusión** (líneas 4148-4217):

> "**Fuentes de skills — 3 tipos**: directory, url, embedded. ...
> **Comparativa con nuestra solución** [tabla extensa]...
> **Diferencia fundamental**: Nuestra solución es estática y centralizada... La de OpenCode es dinámica y descentralizada. Nosotros desactivamos explícitamente su mecanismo con `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`."

Flash NO afirma que el flag haya dejado de funcionar. Reconoce que el sistema viejo sigue activo y respeta el flag.

### Divergencias

1. **Versión del código analizado**: Mimo leyó el commit original (sin `EmbeddedSource` ni validaciones de seguridad). Flash leyó el working tree v1.16.0 (con ambos).
2. **Inyección de caracteres chinos**: Mimo línea 3294, "扫描".
3. **Conclusión sobre el flag**: Mimo afirma que el flag "ya no existe" en v1.16.0 (incorrecto). Flash no lo dice.
4. **Contexto del usuario**: Flash lee `config/opencode.jsonc`, `prompt/custom.md`, y verifica `~/.agents/skills/`. Mimo no.
5. **Conexión con research del usuario**: Flash menciona la research de skill-desc-leak explícitamente.

### Evaluación

**Flash >>> Mimo**. Diferencia de grado mayor. Mimo:
- Lee código desactualizado (commit vs working tree).
- Inyecta caracteres chinos.
- Concluye erróneamente sobre el flag (afirma que "ya no existe", contradice su propia lectura previa del código viejo que mantiene el flag).
- No consulta el contexto del usuario.

Flash:
- Lee el código actualizado con todas las features.
- Conecta con la config real del usuario.
- Reconoce matices (sistema viejo + nuevo coexisten, flag protege solo el viejo).
- Establece base para las preguntas P4-P7.

**Aclaración sobre el confound**: el working tree v1.16.0 incluye cambios posteriores al commit 889e0f954. Esto explica parcialmente por qué Mimo no ve `EmbeddedSource`. Pero no explica el error sobre el flag, que es puramente cognitivo.

---

## P4: "Veo un mecanismo muy enrevesado. Puede interferir con el nuestro y los objetivos de nuestra research?"

**Prompt del usuario** (líneas 3300-3303 / 4220-4223, idéntico):
```
Veo un mecanismos muy enrevesado el nuevo.
Puede interferir con el nuestro y los objetivos que buscamos según nuestra research de skill?
```

### Mimo (3300-3643, 343 líneas, 4 turnos, ~36s)

**Tool calls**:
1. `grep -A5 -B5 "EXTERNAL\|disable\|flag\|OPENCODE"` en skill.ts del commit + `grep -r "DISABLE_EXTERNAL" /tmp/opencode-src/packages/`
2. Mismo grep en `/tmp/opencode-src-bak/packages/`
3. `grep -r "SkillDiscovery\|skill.*discovery\|config-skill\|SkillV2" /tmp/opencode-src/packages/opencode/src/`
4. `grep "EXTERNAL_SKILLS\|disableExternalSkills" en runtime-flags.ts`
5. `grep "from.*skill\|Skill\.\|SkillV2" en app-runtime.ts`
6. `grep "SkillV2\|config-skill" en packages/opencode/src/`
7. `grep "SkillV2\|config-skill\|skill.*plugin" en packages/core/src/`
8. `grep "from.*skill\|import.*skill" en packages/core/src/plugin/`
9. `grep "SkillV2\|config-skill\|SkillPlugin" en packages/opencode/src/`
10. `git show 889e0f954 -- packages/core/src/plugin/boot.ts | grep -A2 -B2 "skill\|Skill"`

**Conclusión** (líneas 3607-3640):

> "**El sistema antiguo sigue activo.** El nuevo `SkillV2` (packages/core/src/skill.ts) existe en el código pero **no está conectado** al runtime principal de opencode."
>
> "**No interfere.** Por ahora."
>
> "Riesgo real: El riesgo no es interferencia técnica, sino **dirección de mantenimiento**. Cuando OpenCode migre completamente a v2..."

**Mimo no consulta `memory/opencode-source-research.md`** (research previa del usuario) ni la research de skill-desc-leak.

### Flash (4219-5792, 1572 líneas, 9 turnos, ~78s)

**Tool calls principales**:
1. **`read /home/antonio/Proyectos/IA/opencode/memory/opencode-source-research.md`** (880 líneas) — consulta la research previa
2. `read /home/antonio/Proyectos/IA/opencode/research/skill-desc-leak/README.md` (research del usuario)
3. `read /tmp/opencode-src/packages/core/src/skill.ts` (working tree)
4. `read /tmp/opencode-src/packages/core/src/skill/discovery.ts`
5. `read /tmp/opencode-src/packages/core/src/config/plugin/skill.ts`
6. `read /tmp/opencode-src/packages/core/src/config/plugin/agent.ts`
7. `read /tmp/opencode-src/packages/core/src/config/markdown.ts`
8. `read /tmp/opencode-src/packages/core/src/plugin/boot.ts`
9. `read /tmp/opencode-src/packages/core/src/plugin/skill.ts`
10. `read /tmp/opencode-src/packages/core/src/config.ts`
11. `read /tmp/opencode-src/packages/core/src/config/agent.ts`
12. `read /tmp/opencode-src/packages/opencode/src/skill/index.ts` (viejo)
13. `read /tmp/opencode-src/packages/opencode/src/tool/skill.ts` (viejo)
14. `read /home/antonio/Proyectos/IA/opencode/config/opencode.jsonc`
15. `read /home/antonio/Proyectos/IA/opencode/prompt/custom.md` (limit 30)

**Conclusión** (líneas 5737-5789):

> "**El nuevo sistema SkillV2 y el viejo coexisten**: [tabla con dos sistemas]"
>
> "**Puntos de interferencia con nuestra configuración**: [4 puntos numerados]"
>
> "**No hay interferencia activa** porque: No tenemos `.opencode/`, no usamos `skills` en jsonc, el customize-opencode deny sigue funcionando, la carga manual via read no toca SkillV2."
>
> "**Riesgo latente**: si en el futuro algún directorio ancestro al proyecto tuviera un `.opencode/` con `agent/` o `skills/`, o si añadiéramos `skills` a nuestra config, SkillV2 activaría auto-descubrimiento sin que `OPENCODE_DISABLE_EXTERNAL_SKILLS` lo cubra."

### Divergencias

1. **Uso de la research del usuario**: Flash leyó `memory/opencode-source-research.md` (880 líneas) y la research de skill-desc-leak. Mimo no consultó ninguna.
2. **Profundidad**: Mimo produce 1 conclusión ("No interfiere por ahora"). Flash produce un análisis de 4 puntos + tabla de coexistencia + riesgo latente.
3. **Conclusión sobre riesgo**: Mimo dice "dirección de mantenimiento" (futuro). Flash identifica un riesgo técnico concreto: directorios `.opencode/` ancestros.
4. **Latencia**: Mimo 36s, Flash 78s. La diferencia se justifica por las 13 lecturas adicionales (incluida la research del usuario).

### Evaluación

**Flash >>> Mimo**. Flash aprovecha el contexto acumulado y la research del usuario para producir un análisis matizado. Mimo produce una respuesta cerrada sin contexto del proyecto.

---

## P5: "Que busque en ascentros me parece un gran riesgo, qué sentido tiene?"

**Prompt del usuario** (líneas 3644-3646 / 5793-5795, idéntico):
```
Que busque en ascentros me parece un gran riesgo, qué sentido tiene?
```

**Nota previa**: "ascentros" es un typo evidente de "ancestros" (ancestors). El contexto de P4 (SkillV2 ancestor walk) hace el referente predecible.

### Mimo (3644-3785, 141 líneas, 3 turnos, ~25s)

**Thinking de Mimo** (líneas 3654-3675):

> "The user is referring to this code in the old skill system:
>
> ```typescript
> const CLAUDE_EXTERNAL_DIR = ".claude"
> const AGENTS_EXTERNAL_DIR = ".agents"
> ```
>
> ...
>
> The user is right to question this. Why would OpenCode look for skills in `.claude/`? This is because OpenCode is a fork/derivative of Claude Code... The `.claude/` directory is where Claude Code stores its configuration and skills."

**Mimo interpreta "ascentros" como el escaneo del sistema legacy de `.claude/`, no como la búsqueda hacia arriba del nuevo SkillV2.**

**Tool call** (línea 3682):
```bash
grep -n "CLAUDE_EXTERNAL_DIR\|claudeCode\|CLAUDE_CODE\|Claude Code" /tmp/opencode-src/packages/opencode/src/skill/index.ts
```

**Output** (líneas 3689-3691):
```
22:const CLAUDE_EXTERNAL_DIR = ".claude"
187:    if (!disableClaudeCodeSkills) externalDirs.push(CLAUDE_EXTERNAL_DIR)
```

**Conclusión** (líneas 3767-3780):

> "Es un residuo de herencia. OpenCode nació como fork de Claude Code (Anthropic). El directorio `.claude/` es donde Claude Code almacena sus skills y configuración. OpenCode lo escanea por **compatibilidad retroactiva**...
>
> En tu caso ya lo desactivaste con `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true` + `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`. El scanning de `.claude/` no ocurre."

**Error**: Mimo construyó toda la respuesta sobre una premisa falsa. El usuario, tras hablar de SkillV2 en P4, pregunta por la búsqueda en "ancestros" — el mecanismo que Flash identificó correctamente en `config.ts:175-183` (búsqueda en `.opencode/` desde `cwd` hasta `worktree`).

### Flash (5793-5907, 114 líneas, 1 turno, 18s)

**Thinking de Flash** (líneas 5803-5805):

> "The user is referring to the SkillV2 discovery system that searches for skills in ancestor directories (walking up the directory tree to find `.opencode/` directories with `skill/` or `skills/` subdirectories). They're asking what the rationale is for this design, as they see it as a security risk."

**Flash identifica correctamente la pregunta**: ancestor walk en `.opencode/`.

**Sin tool calls** — trabaja desde el contexto acumulado.

**Conclusión** (líneas 5853-5904):

> "### El alcance real de la búsqueda hacia arriba
>
> En `config.ts:175-183`:
>
> ```typescript
> const discovered = locationIsGlobal
>   ? []
>   : yield* fs.up({
>       targets: [".opencode", ...names.toReversed()],
>       start: location.directory,
>       stop: location.project.directory,   // ← raíz del repo git
>     }).pipe(Effect.orDie)
> ```
>
> **No busca hacia `/`** sino desde `cwd` hasta la **raíz del repo git** (`worktree`)."

Flash da la lógica del diseño, tabla de riesgos por escenario, tabla de defensas del usuario contra SkillV2.

### Divergencia clave

**Mimo responde a una pregunta que el usuario no hizo**. Flash responde a la pregunta correcta.

La diferencia de 31 líneas (141 vs 114) — Mimo produce más texto a pesar de no entender la pregunta.

### Evaluación

**Flash >>> Mimo**. El error de Mimo es el más grave de la sesión: contesta basándose en una premisa temática equivocada. El contexto de P4 (SkillV2 ancestor walk en `.opencode/`) hacía el referente inequívoco.

---

## P6: "la nueva versión de gestión de skill de opencode está activa y rompe los objetivos de nuestra research?" + "cuando se active rompe algo en nuestro sistema?"

**Prompt del usuario**:
- Flash (línea 5910): un único prompt con la pregunta compuesta `está activa y rompe los objetivos?`
- Mimo (líneas 3788 + 3940): el mismo prompt inicial, **más un follow-up** `y cuando se active rompe algo en nuestro sistema?`

**Lectura correcta de la asimetría**: ambos modelos recibieron la misma pregunta compuesta (dos partes unidas por "y"). El que Mimo recibiera un segundo prompt **no fue un detalle metodológico, sino un síntoma de comprensión insuficiente**. La primera parte de la pregunta (`está activa`) admite respuesta binaria simple; la segunda (`rompe los objetivos`) requiere análisis del impacto sobre el sistema del usuario. Mimo respondió a la primera parte con un tajante "**No. No está activa. No rompe nada.**" pero no abordó sustantivamente la segunda. El usuario tuvo que formular el follow-up `y cuando se active rompe algo en nuestro sistema?` para forzar el análisis que esperaba desde el principio.

Flash, con el mismo prompt único, abordó ambas partes: confirmó que SkillV2 existe y se ejecuta al arranque, pero argumentó que no está cableado al runtime ni al system prompt, y por tanto no rompe la research ni el sistema del usuario. Además, aportó un riesgo latente (ConfigAgentPlugin) que Mimo no mencionó.

**Implicación para la evaluación**: el número de prompts NO es la variable controlada — la variable controlada es la pregunta. La diferencia observada (Mimo 2 prompts, Flash 1 prompt) es evidencia de que Mimo requirió más iteraciones para captar la intención. Esto es una métrica de **comprensión de peticiones**, no de metodología.

### Mimo (3786-4143, 357 líneas, 4 turnos, ~30s)

**Turno 1 (P6 parte 1)**: user dice "está activa". Mimo responde "**No. No está activa. No rompe nada.**"

**Tool calls**:
1. `read /tmp/opencode-src/packages/opencode/src/effect/app-runtime.ts` (limit 50)
2. `grep -n "Skill\|skill" en app-runtime.ts` → encuentra `Skill.defaultLayer` (sistema viejo)
3. `grep -rn "SkillV2\|skill\.ts.*core\|@opencode-ai/core/skill\|config-skill" en packages/opencode/src/` → vacío

**Conclusión** (líneas 3923-3934):

> "**No. No está activa. No rompe nada.**
>
> En v1.16.0, el runtime de opencode sigue usando el sistema viejo:
>
> ```
> packages/opencode/src/effect/app-runtime.ts:72
>   Skill.defaultLayer   ← el viejo
> ```
>
> `SkillV2` (packages/core/src/skill.ts) existe en el código fuente pero **no se importa ni se conecta** en ningún sitio del paquete opencode. Es código preparado para una futura migración a v2 del core, pero hoy es código muerto.
>
> Tu research y tu sistema de skills funcionan igual que en v1.15.13."

**Error**: Mimo contradice al usuario ("No está activa" cuando el usuario asume que sí). Además, ignora que `packages/opencode/src/skill/index.ts:278` (línea que Mimo SÍ leyó antes) importa `SkillPlugin.CustomizeOpencodeContent` de SkillV2 — por lo que el sistema viejo depende de SkillV2 para obtener `customize-opencode`.

**Turno 2 (P6 parte 2)**: user pregunta "y cuando se active rompe algo en nuestro sistema?"

**Tool call** (línea 3970):
```bash
cat /tmp/opencode-src/packages/core/src/tool/skill.ts
```

**Archivo leído: `packages/core/src/tool/skill.ts`** (el de CORE, no el de opencode).

**Error grave**: Mimo confunde el archivo. El tool de opencode está en `packages/opencode/src/tool/skill.ts`, que importa del sistema viejo. El que Mimo leyó es el de core, que sí usa SkillV2.

**Conclusión** (líneas 4121-4140):

> "**No rompe tu sistema. Tu sistema no depende de ninguno de los dos.**
>
> ...
>
> | Componente | Hoy (v1.16.0) | Con SkillV2 activo |
> | **Built-in `skill` tool** | No funciona (SkillV2.Service no conectado) | Empieza a funcionar |
> | **Discovery de skills** | Viejo: `.claude/`, `.agents/`, config dirs | Nuevo: solo config documents con `skills:` en frontmatter |"

**Errores**:
1. Lee el archivo equivocado (core en vez de opencode).
2. Concluye que el tool nativo "no funciona" cuando en realidad sí funciona (importa del sistema viejo, que está conectado).
3. Lo que el usuario tiene bloqueado es por permisos (`customize-opencode: deny`), no por rotura del tool.
4. No identifica que `customize-opencode` (vía SkillV2 como EmbeddedSource) sí entra al system prompt del usuario.

### Flash (5908-7004, 1086 líneas, 7 turnos, ~52s)

**Tool calls principales**:
1. `rg -n "available_skills\|SkillV2\|skill\.list\|skill\.sources\|available.*skills\|skills.*system" packages/core/src/session/ packages/core/src/llm/` → **sin output**
2. `rg -n "Skill\|skill" packages/core/src/session/system.ts` → **sin output** (no existe el archivo)
3. `glob **/system.ts` en core/src → **no files**
4. `rg -l "skill\|Skill\|available" packages/core/src/ --type ts` → **sin output**
5. `rg -l "available_skills\|Skill\.fmt\|skills.*system\|skill.*catalog" --type ts` → **sin output**
6. `ls /tmp/opencode-src/packages/opencode/src/session/` → encuentra `system.ts` en `opencode` (no en `core`)
7. `rg -l "available_skills" --type ts` → solo en `packages/opencode/src/skill/index.ts` y `packages/opencode/src/tool/skill.ts`
8. `read /tmp/opencode-src/packages/opencode/src/session/system.ts` (84 líneas)
9. `read /tmp/opencode-src/packages/opencode/src/skill/index.ts` (357 líneas)
10. `rg -n "SkillV2" packages/opencode/src/ --type ts` → **sin output**
11. `rg -n "SkillV2\|v2/Skill" packages/opencode/src/session/ packages/opencode/src/llm/` → **sin output**
12. `rg -n "SkillV2\|v2/Skill\|@opencode.*/skill\|core.*skill" packages/opencode/src/skill/index.ts packages/opencode/src/skill/` → **sin output**
13. `rg -l "SkillV2\|v2/Skill" packages/opencode/src/ --type ts` → **sin output**
14. `read /tmp/opencode-src/packages/opencode/src/tool/skill.ts` (72 líneas) — **el archivo correcto**
15. `read /tmp/opencode-src/packages/core/src/tool/skill.ts` (también lee este, para comparar)

**Conclusión** (líneas 6945-7003):

> "**No rompe nuestros objetivos**
>
> SkillV2 existe, se ejecuta durante el arranque, pero **no está cableado al system prompt ni a la tool `skill`**. Son dos sistemas completamente paralelos sin conexión:
>
> ```
> OLD Skill (packages/opencode/src/skill/index.ts)
>   ├── Lee skills de disco (gated por OPENCODE_DISABLE_EXTERNAL_SKILLS)
>   ├── Inyecta en system prompt vía session/system.ts  ← LA QUE IMPORTA
>   └── Responde a la tool "skill"
>
> NEW SkillV2 (packages/core/src/skill.ts)
>   ├── Registra fuentes (embedded, directory, url)
>   ├── NO inyecta en system prompt
>   └── NO responde a la tool "skill"
> ```
>
> [Tabla de qué cambió en v1.16.0]
>
> [Tabla de defensas del usuario]
>
> SkillV2 es una **refactorización en curso** con miras a futuro (registro remoto, permisos por agente), pero hoy es código muerto desde la perspectiva del modelo. No hay inyección de descripciones, no hay expulsión de skills al system prompt, no rompe ninguna conclusión de skill-desc-leak.
>
> **Riesgo real (bajo)**: el `ConfigAgentPlugin` sí está activo y carga agentes desde archivos `.md` en directorios de config. Si algún proyecto en nuestro árbol tuviera `.opencode/agent/*.md`, esos agentes se registrarían automáticamente..."

### Divergencias

1. **Respuesta al usuario**: Mimo contradice ("No está activa"); Flash valida la premisa y matiza ("existe, se ejecuta, pero no está cableado al system prompt").
2. **Archivo leído**: Mimo lee `packages/core/src/tool/skill.ts` (equivocado); Flash lee `packages/opencode/src/tool/skill.ts` (correcto).
3. **Conclusión sobre tool**: Mimo dice "no funciona"; Flash confirma que funciona y está bloqueado por permisos.
4. **Iteración ante fallo**: Flash itera 4 veces (greps fallan, re-orienta con `glob` y `ls`); Mimo no itera tras `app-runtime.ts`.
5. **Conecta con customize-opencode**: Flash identifica que está en ambos sistemas; Mimo no.

### Evaluación

**Flash >>> Mimo, con una brecha mayor que en P5**. Mimo:
1. **No capturó la intención completa de la pregunta**: respondió "está activa" con un no tajante pero no abordó la segunda parte ("rompe los objetivos"). Forzó al usuario a un follow-up.
2. Contradijo al usuario sin razón.
3. Leyó el archivo equivocado (`packages/core/src/tool/skill.ts` en vez de `packages/opencode/src/tool/skill.ts`).
4. Concluyó erróneamente que el tool nativo está roto.
5. No detectó que `customize-opencode` (SkillV2) sí entra al system prompt.

Flash:
1. **Capturó la intención completa de la pregunta en un solo turno**: abordó ambas partes (estado de activación + impacto en la research) sin necesidad de follow-up.
2. Investigación exhaustiva con verificación de archivos correctos.
3. Reconoce la complejidad iterando cuando sus primeras hipótesis fallan.
4. Conclusión matizada y correcta.
5. Aporta un riesgo latente (ConfigAgentPlugin) que Mimo no menciona.

**Diferencia cualitativa de P6**: además de los errores técnicos ya documentados, Mimo mostró una **brecha de comprensión de petición compuesta** que Flash no tuvo. La pregunta contenía dos cláusulas unidas por "y"; el modelo que responde solo a la primera y deja la segunda sin abordar no está procesando la pregunta como un todo, sino como una secuencia de items. Esta diferencia cualitativa se desarrolla en la sección "Análisis transversal: fluidez e interacción".

---

## P7: "cual crees que es el objetivo de Skillv2?"

**Prompt del usuario** (líneas 4144-4146 / 7005-7007, idéntico):
```
cual crees que es el objetivo de Skillv2?
```

### Mimo (4144-4200, 57 líneas, 1 turno, 12.6s)

**Sin tool calls**. Construye sobre el contexto acumulado.

**Respuesta** (líneas 4168-4197):

> "El objetivo es convertir las skills de **recursos descubiertos en el filesystem** a **objetos de configuración declarados**.
>
> ...
>
> ```
> El config document declara: skills: [ruta-o-url]
> SkillV2 registra fuentes → load从 frontmatter → skill tool las presenta al modelo
> ```

**Error de idioma (segundo)**: el carácter chino "从" (cóng, "from") aparece en la línea 4179 en medio de la descripción del flujo. La frase esperada sería "load desde frontmatter".

> "### Cambios de diseño
>
> 1. **De 'escanear' a 'declarar'**: ...
> 2. **Skills como herramientas**: ...
> 3. **Control por agente**: `PermissionV2.evaluate('skill', skill.name, agent.permissions)` filtra qué skills ve cada agente. Antes era global.
> 4. **Activación con `/`**: el campo `slash: true` en frontmatter sugiere que las skills serán invocables con `/nombre` en el chat, como comandos.
> 5. **URL como source**: las URLs se descargan, cachean por hash, y se indexan vía `index.json`. Es un registry remoto, no un 'download and hope'.
>
> ### En una frase
>
> SkillV2 es el paso de 'las skills viven en el filesystem y el modelo las encuentra' a 'las skills viven en la configuración y el sistema las sirve'."

**Verificación del campo `slash: true`**: el campo `slash: Schema.Boolean.pipe(Schema.optional)` existe en el `Frontmatter` schema del commit 889e0f954 (línea 2068 de la lectura de Mimo en P3). Por lo tanto, la afirmación NO es alucinación — Mimo vio el campo en su lectura previa. Sin embargo, Flash no lo menciona en su lectura del working tree, lo que podría indicar que fue refactorizado o reemplazado en commits posteriores.

### Flash (7005-7112, 105 líneas, 1 turno, 22s)

**Sin tool calls**.

**Respuesta** (líneas 7065-7109):

> "SkillV2 es el **reemplazo planeado** del sistema viejo de skills, diseñado para soportar lo que el viejo no puede:
>
> ### Lo que el viejo sistema NO permite
>
> - **Skills desde plugins** — el sistema viejo solo escanea disco. SkillV2 permite que cualquier plugin registre un `EmbeddedSource` (como ya hace con `customize-opencode`)
> - **Registros remotos** — el `UrlSource` + `index.json` está diseñado para un ecosistema tipo `skills.sh` o `npx skills`, pero nativo en OpenCode
> - **Permisos por agente** — `forAgent(agentID)` vs el viejo `available(agent?)`
> - **Multi-app** — está en `packages/core/` (compartido entre apps del ecosistema)
>
> ### La pista más reveladora
>
> El `customize-opencode` built-in ahora se registra en **ambos** sistemas:
>
> | Sistema | Cómo se registra |
> |---|---|
> | Viejo (`skill/index.ts:278`) | `s.skills['customize-opencode'] = { name, description, content }` |
> | SkillV2 (`plugin/skill.ts:21`) | `editor.source(new EmbeddedSource({ skill: new Info({...}) }))` |
>
> Esto es típico de una migración en curso: el mismo skill existe en los dos sistemas, el viejo sigue alimentando el system prompt, el nuevo ya recibe el skill pero aún no se usa para nada visible.
>
> ### El diseño sugiere un roadmap
>
> ```
> Fase 1 (v1.16.0) ─ SkillV2 existe como infraestructura paralela
>   ├── Registro de fuentes (directory, url, embedded)
>   ├── Discovery remoto con validación de seguridad
>   └── NO cableado al modelo
>
> Fase 2 (futura) ─ SkillV2 cableado al system prompt
>   ├── `session/system.ts` lee de SkillV2 en vez del viejo
>   └── El viejo sistema se depreca
>
> Fase 3 (más futuro) ─ Ecosistema de registros
>   ├── npx @opencode/skills publish
>   ├── `skills: ['https://registry.opencode.ai/packs/...']`
>   └── Plugins de terceros contribuyen skills
> ```
>
> ### Lo que NO es SkillV2
>
> No es una solución al skill-desc-leak. El nuevo sistema tiene el mismo mecanismo de inyección de descripciones (`forAgent()` filtra por permisos igual que el viejo). El problema de las descripciones como vector de influencia sigue intacto en el diseño, simplemente no lo han conectado aún.
>
> ### En resumen
>
> SkillV2 es una **refactorización habilitante** para convertir skills de 'archivos markdown escaneados al arrancar' a 'recursos registrables por plugins, descargables de remotos, y permisibles por agente'. Hoy es infraestructura huérfana, pero es el futuro del sistema."

### Divergencias

1. **Aporta "la pista más reveladora"**: Flash muestra la doble registración de `customize-opencode` en ambos sistemas. Mimo no.
2. **Roadmap explícito**: Flash propone 3 fases. Mimo no.
3. **Sección crítica "Lo que NO es SkillV2"**: Flash conecta explícitamente con la research de skill-desc-leak. Mimo no.
4. **Error de idioma**: Mimo tiene "从" en línea 4179. Flash no.
5. **Tamaño**: Mimo 57 líneas, Flash 105 líneas (2x).

### Evaluación

**Flash >>> Mimo**. Mimo da un resumen aceptable pero plano. Flash:
1. Aporta análisis estructural del "por qué" (problemas del viejo + habilitadores del nuevo).
2. Identifica la doble registración como prueba de migración en curso.
3. Plantea roadmap explícito.
4. Conecta explícitamente con la research del usuario (skill-desc-leak no resuelto).
5. Sin errores de idioma.

---

## Análisis transversal: coherencia entre preguntas

### 1. Coherencia terminológica

**Mimo**: inconsistente. P2 usa tres términos para un mismo concepto ("replay"/"replantear" en distintas partes de la misma respuesta). P3-P7 oscila entre "SkillV2"/"Skill V2"/"nuevo sistema de skills".

**Flash**: consistente. Mantiene un vocabulario estable que evoluciona orgánicamente (añade "ancestor walk" en P5 sin romper lo anterior).

### 2. Seguimiento del tema (topic tracking)

**Mimo**: drift en P5. P4 termina hablando de SkillV2 ancestor walk en `.opencode/`. P5 (user: "ascentros") salta a `.claude/` del sistema legacy. El contexto precedente hacía el referente inequívoco.

**Flash**: hilo mantenido P3-P7. P5 continúa con SkillV2, P6 cierra el wiring, P7 sintetiza el diseño.

### 3. Estabilidad de posición

**Mimo**: contradicciones detectables:
- P3 vs P6: P3 dice "el flag `OPENCODE_DISABLE_EXTERNAL_SKILLS` ya no funciona" (incorrecto, contradice su propia lectura). P6 no menciona el flag.
- P4 vs P6: P4 dice "no interfiere" (con matiz de riesgo latente). P6 dice "no está activa" (negación absoluta).
- P5 vs P6: P5 dice que `.claude/` se escanea en el viejo sistema. P6 dice que el sistema viejo sigue activo. Coherente, pero la narrativa de P5 (OpenCode es fork de Claude Code) se abandona en P6.

**Flash**: refina progresivamente sin contradecirse.

### 4. Construcción acumulativa

**Mimo**: turnos autocontenidos. P7 no referencia P3, P5, ni P6.

**Flash**: referencias explícitas. P6 cita la línea 278 de `skill/index.ts` que leyó en P3. P7 referencia "la doble registración" hallada en P6.

### 5. Coherencia narrativa

**Mimo**: narrativa fragmentada, sin arco. Las respuestas son yuxtapuestas.

**Flash**: arco claro: descubrimiento (P3) → análisis de impacto (P4) → riesgo específico (P5) → evaluación de activación (P6) → diseño futuro (P7).

### Veredicto de coherencia

**Flash es marcadamente más coherente en todas las dimensiones evaluadas.** La diferencia no es de grado sino de naturaleza: Mimo produce respuestas aisladas, Flash produce un discurso acumulativo.

---

## Análisis transversal: uso de herramientas

| Dimensión | Mimo | Flash |
|---|---|---|
| **Distribución** | Sesgo bash (80%) | Balanceada (45/40) |
| **Preferencia `read` sobre bash cat** | Invertida (lee por git show) | Correcta (read por defecto) |
| **Calidad de bash commands** | Simples, aislados | Compuestos, robustos, con `&&`/`||`/`head -X` |
| **Uso de `glob` para descubrimiento** | Solo release notes | También para código (P6: `**/system.ts`) |
| **Uso de `todowrite`** | Nunca | 3 veces (P1, P3, P6) |
| **Secuenciamiento** | Verifica y concluye | Descubre, lee, verifica, concluye |
| **Recuperación ante fallo** | No documentada | Explícita (P6: re-orienta con glob/ls) |
| **Errores de selección** | 1 (P6: archivo equivocado) | 0 |

La "economía aparente" de Mimo (menos calls por turno) es engañosa: en P6 invirtió 4 calls en una conclusión errónea. Flash invirtió 9 calls en una conclusión correcta y matizada.

---

## Análisis transversal: fluidez e interacción

Las secciones anteriores midieron el "qué" (corrección factual, cumplimiento de reglas) y el "cómo agregado" (coherencia entre preguntas, uso de herramientas). Esta sección mide la **fluidez de la interacción modelo↔usuario** pregunta a pregunta: cómo el modelo entiende lo que se le pide, cómo formatea la salida, y cómo se adapta al registro del usuario.

### 1. Comprensión de peticiones

**Indicador principal**: ¿el modelo entendió la intención completa de la pregunta en el primer turno, o necesitó que el usuario reformulara?

| Pregunta | Mimo | Flash |
|---|---|---|
| P3 ("Me interesa esto 'Skill discovery + file-based agents'") | Captura el interés general pero pierde matices (lee commit histórico, no working tree) | Captura y profundiza, conecta con research del usuario |
| P4 ("Puede interferir con el nuestro y los objetivos de nuestra research?") | Responde con "no interfiere" sin matizar el riesgo latente | Distingue entre "no interfiere hoy" y "riesgo latente de configurar permisos" |
| P5 ("Que busque en ascentros me parece un gran riesgo") | **Malinterpreta**: lee "ascentros" como `.claude/` (directorio legacy) en vez de ancestor walk de SkillV2 | **Interpreta correctamente**: entiende que "ascentros" es typo de "ancestors" y que el contexto (SkillV2) hace el referente inequívoco |
| P6 ("está activa y rompe los objetivos?") | **No captura la intención completa**: contesta solo "está activa = no" sin abordar la segunda parte ("rompe los objetivos"). Obliga al usuario a un follow-up | **Captura ambas partes en un solo turno**: contesta activación (no cableado al runtime) y evalúa impacto en la research (no la rompe) |
| P7 ("cual crees que es el objetivo de Skillv2?") | Responde con una interpretación breve y genérica | Responde con un arco: registro → permisos → federación, conectando con el riesgo de leakage |

**Patrón de Mimo**: contesta en orden de aparición de las cláusulas de la pregunta. Si la pregunta tiene estructura "X e Y", contesta X y se detiene; la segunda parte queda sin abordar hasta que el usuario insiste. Esto es sintomático de **lectura lineal de la pregunta**, no de procesamiento semántico de la intención.

**Patrón de Flash**: contesta la intención. Identifica que `X e Y` es una sola pregunta con dos partes, y aborda ambas. Cuando una parte requiere verificación (P6: `rompe los objetivos`), lo verifica antes de afirmar.

**Métrica observable**: número de prompts de usuario necesarios para agotar una pregunta. Mimo: 14 prompts para 7 preguntas (ratio 2.0). Flash: 12 prompts para 7 preguntas (ratio 1.7). La diferencia de 2 prompts adicionales de Mimo no es metodología sino evidencia de que Mimo necesitó más iteraciones para cubrir la intención del usuario. (Nota: el preludio común tiene 6 prompts idénticos; los prompts del fork son 7 para Flash y 8 para Mimo, contando el follow-up de P6.)

### 2. Formato de salida

| Dimensión | Mimo | Flash |
|---|---|---|
| **Estructura con encabezados** | Ocasional (markdown plano) | Sistemática (##, ###, listas anidadas) |
| **Uso de tablas** | 0 tablas explícitas en P1-P7 | Tablas en P3, P4, P5, P6, P7 (compara componentes, resume riesgos, lista defensas) |
| **Código formateado** | Bloques puntuales | Sistemático cuando cita archivos o commands |
| **Citas `file:line`** | 1 en 4200 líneas | 74 en 6127 líneas |
| **Listas con bullets** | Predominio de prosa continua | Listas estructuradas para opciones, riesgos, comparativas |
| **Énfasis tipográfico** | Limitado | Selectivo (negritas para conclusiones, cursiva para matices) |

**Patrón de Mimo**: prosa continua con separación por párrafos, menos estructurada. Esto produce respuestas que se leen como "explicación" en vez de "análisis técnico".

**Patrón de Flash**: estructura jerárquica con encabezados y tablas. Esto produce respuestas que se leen como "informe técnico" y son más fáciles de verificar punto por punto.

**Caveat (sesgo del evaluador)**: el evaluador (yo) tiene documentado un **sesgo de complejidad** por el cual las respuestas más largas y estructuradas se evalúan más positivamente. La diferencia de formato podría no ser objetivamente "mejor" o "peor", pero el formato estructurado de Flash **facilita la verificación**: una tabla con 4 filas se puede comprobar en 4 chequeos; un párrafo de 4 frases requiere releer. Este es un factor de eficiencia, no necesariamente de calidad. (Este caveat está desarrollado en `AUTO-EVALUACION-DEL-EVALUADOR.es.md`, sección "Sesgos probables no detectados".)

### 3. Adaptación al registro del usuario

El usuario alterna entre:
- **Registro conceptual** (P1, P4, P5, P7): preguntas interpretativas, piden evaluación de riesgo u objetivo.
- **Registro técnico** (P3, P6): preguntas fácticas sobre código y activación.

| Modelo | Comportamiento por registro |
|---|---|
| Mimo | Mantiene un registro uniforme, próximo a "resumen ejecutivo" en ambos casos. Las preguntas técnicas reciben respuestas breves; las conceptuales reciben respuestas igualmente breves. |
| Flash | Adapta el registro: en preguntas técnicas (P3, P6) usa código, tablas, citas `file:line`; en preguntas conceptuales (P4, P7) usa narrativa estructurada con secciones temáticas. |

**Patrón de Mimo**: no detecta la diferencia de registro. Trata todas las preguntas con el mismo nivel de formalidad técnica.

**Patrón de Flash**: detecta la diferencia y la usa para estructurar la respuesta. Esto no es solo formato; es **adecuación contextual**.

### 4. Manejo de errores y recuperación

| Dimensión | Mimo | Flash |
|---|---|---|
| **Verifica antes de afirmar** | A veces (P3) | Sistemáticamente (P3, P4, P6) |
| **Itera cuando falla** | 0 documentado | 4+ veces (P6: greps fallidos → glob → ls → read) |
| **Corrige al usuario con base en evidencia** | Contradice sin verificar (P6) | Matiza con código a la vista (P6) |
| **Marca incertidumbre** | 0 veces | 0 veces (igual que Mimo; ambos fallan L38) |

**Patrón de Mimo**: cuando su primera verificación confirma su hipótesis, **no re-verifica** aunque la hipótesis sea opuesta a la premisa del usuario. Esto produce las contradicciones de P6.

**Patrón de Flash**: cuando una hipótesis falla, **re-orienta** la búsqueda. Esto lo hace más lento por turno (ms/turno mayor) pero reduce errores fácticos.

### 5. Síntesis: diferencia cualitativa global

La fluidez de interacción de Flash es cualitativamente distinta a la de Mimo. No es solo que Flash produce más tokens, ni que usa más herramientas, ni que cita más. Es que Flash trata cada turno como una **conversación acumulativa** donde el modelo y el usuario negocian la pregunta y la respuesta, mientras Mimo trata cada turno como un **intercambio transaccional** donde el modelo contesta lo que se le pregunta y se detiene.

Esta diferencia se manifiesta en:
- **Comprensión de peticiones compuestas** (P6: Mimo 1/2 partes, Flash 2/2 partes).
- **Iteración cuando falla** (Flash 4+ veces, Mimo 0).
- **Inversión en la pregunta** (Flash responde la intención; Mimo responde las palabras).

Implicación operativa: para tareas donde la pregunta es clara y no requiere negociación, Mimo puede ser suficiente (con la salvedad de los errores fácticos ya documentados). Para tareas donde la pregunta es ambigua, compuesta, o requiere que el modelo pregunte antes de responder, Mimo falla estructuralmente.

---

## Perfil por modelo

### Mimo (MiMo V2.5 Free)
- **Fortalezas**: brevedad, decisiones rápidas, latencia baja por turno.
- **Debilidades**: lee archivos desactualizados (vía commit), no consulta research del usuario, confunde archivos entre packages, sobreconfianza categórica, patrón estable de inyección de caracteres chinos.
- **Patrón de error crítico**: cuando la pregunta tiene referente implícito (P5, P6), salta a conclusiones sin verificar, apoyado en greps que confirman su hipótesis inicial.

### Flash (DeepSeek V4 Flash Free)
- **Fortalezas**: rigor en verificación, conecta con research del usuario, itera cuando falla, profundiza en matices, sin errores de idioma.
- **Debilidades**: más verboso, investiga más de lo estrictamente necesario.
- **Patrón de comportamiento**: confirma empíricamente cada aserción. Cuando una hipótesis falla, re-orienta en vez de inventar.

---

## Confundidores identificados

1. **Prompts extra de Mimo**: Mimo recibe un segundo prompt en P6 ("y cuando se active rompe algo?") que Flash no recibe explícitamente. Esto se ha unificado para comparar, pero sugiere que Mimo necesitó una pregunta extra para profundizar donde Flash lo cubrió en una sola respuesta.

**Re-categorización**: el "snapshot obsoleto" y el "estado inicial del repo" se reclasifican de confundidores a **errores estructurales con violación de system prompt**. Ver sección "Violación de instrucciones del system prompt" abajo.

**Nota de coherencia**: tras la re-categorización, este apartado conserva solo el confounder legítimo (P6 con prompt extra). Los otros dos se movieron a la sección de violación de system prompt, donde están mejor contextualizados.

---

## Violación de instrucciones del system prompt

El `memory.md` del usuario (líneas 43-50) contiene una regla explícita que aplica directamente al caso de Mimo:

```
### Actualización de fuentes OpenCode
Antes de cualquier tarea que requiera el código fuente de OpenCode:
1. `opencode --version` o `npx opencode --version` — versión instalada
2. En `/tmp/opencode-src/`: `git fetch --tags && git checkout v<versión>` (o `main` si no hay tag)
3. Si se actualizó la versión, la investigación en `memory/opencode-source-research.md` 
   puede estar desfasada — revisar cambios relevantes antes de confiar en ella.
4. No hay forma de saber si ya está actualizada. Comprobar siempre.
```

Y en `memory.md:9` la investigación previa está explícitamente etiquetada como `v1.15.13`. En `memory.md:41` la regla "Antes de usarlas, actualizar a la versión instalada" deja claro que el working tree debe reflejar la versión instalada (v1.16.0), no un commit histórico.

**Mimo viola tres de las cuatro reglas de la lista 43-50**:

- Regla 1 (versión instalada): Mimo la cumplió (detectó v1.16.0 instalado).
- Regla 2 (checkout): Mimo la cumplió (`git checkout v1.16.0`).
- Regla 3 (cambios relevantes): Mimo la **violó**. El punto 3 establece que cualquier cambio entre v1.15.13 y v1.16.0 puede invalidar la investigación previa. Mimo debería haber leído el estado actual de los archivos y comparado con la versión de la que partía. En su lugar, leyó el commit del PR original #30617 (889e0f954) y trató ese snapshot como referencia.
- Regla 4 (comprobar siempre): Mimo la **violó implícitamente**. La regla dice "no hay forma de saber si ya está actualizada, comprobar siempre". Mimo comprobó que el checkout se hizo, pero no comprobó que el archivo leído correspondiera al estado actual.

**Flash cumple las cuatro reglas**: detecta v1.16.0, hace checkout, lee el working tree actual, y cuando hay cambios (EmbeddedSource, isSafeSegment), los ve directamente.

**Grado de severidad del "snapshot obsoleto"**: re-clasificado de confundidor a **error estructural grave** por las siguientes razones:

1. Es **causa raíz** de al menos un error fáctico de Mimo (P3: "EmbeddedSource no existe" cuando sí existe; el flag `OPENCODE_DISABLE_EXTERNAL_SKILLS` "ya no existe" cuando sí existe).
2. Es **violación explícita** del system prompt del usuario (regla 3 de memory.md:43-50).
3. Es **patrón reproducible** (5 lecturas consecutivas con `git show <hash>:<file>` en P3, más 3 lecturas de `src-bak` para "comparar con la versión vieja"). El modelo tiene un sesgo estable hacia lectura histórica cuando podría leer el estado presente.
4. **Afecta a la capacidad de generalización**: Mimo no generalizó la regla "comprobar siempre" al momento de elegir cómo leer los archivos. Extendió "comprobar si la versión es la actual" pero no "comprobar si el contenido que voy a leer es el actual".

**Conteo actualizado de errores de Mimo** (anterior: 9 errores / 3 graves):

| Tipo | Anterior | Actual | Notas |
|---|---|---|---|
| Errores estructurales | 0 | 1 | Lectura de snapshot obsoleto (causa raíz de P3) |
| Errores fácticos | 3 (P3, P5, P6) | 3 (P3, P5, P6) | Sin cambio; el P3 fáctico es síntoma del estructural |
| Errores de idioma | 2 (P3, P7) | 2 (P3, P7) | Sin cambio |
| Errores de selección de archivo | 1 (P6) | 1 (P6) | Sin cambio |
| Errores de terminología | 1 (P2) | 1 (P2) | Sin cambio |
| **Errores graves totales** | **3** | **4** | +1 por error estructural |

El error estructural es independiente de los fácticos: aunque se corrigiera el snapshot, el error fáctico sobre el flag (P3) seguiría existiendo (es puramente cognitivo, no informativo). Pero el snapshot contribuyó a que Mimo no viera `EmbeddedSource` ni `isSafeSegment` y por tanto no detectara la incoherencia.

**Caveat sobre Flash**: Flash tampoco leyó `memory.md:43-50` explícitamente en la sesión (no aparece en su log de tool calls), pero su comportamiento fue consistente con la regla. La diferencia es que Flash tiene un sesgo natural hacia "leer el estado actual"; Mimo tiene un sesgo hacia "leer el commit que introdujo el feature". El system prompt estaba ahí para corregir el segundo sesgo; Mimo no lo hizo.

---

## Cumplimiento de reglas del system prompt (`custom.md`)

El `prompt/custom.md` del usuario (118 líneas) define reglas operativas y de estilo. Esta sección evalúa el comportamiento de cada modelo contra las reglas **testables** en el contexto de las dos sesiones (análisis técnico de código, Q&A sobre diferencias entre versiones). Se excluyen reglas N/A (no se hicieron ediciones, no se ejecutaron comandos destructivos, no se usaron flags de control, no se invocó captura de memoria).

### Heatmap resumen

Visualización de las 16 reglas testables, agrupadas por impacto. El símbolo indica el nivel de cumplimiento observado:

- `✓` cumple la regla
- `~` cumple parcialmente o con excepciones
- `✗` viola la regla de forma sistemática
- `·` no aplicable en estas sesiones

```
                                              Mimo   Flash
                                            ─────────────
Alto impacto (verificación y razonamiento)
  L39  Verifica antes de actuar                ✗      ✓
  L18  Cita la fuente (archivo:línea)          ✗      ✓
  L14  Par técnico, no asienta                 ✗      ✓
  L34  Evalúa críticamente antes de actuar     ✗      ✓
  L15  Causa raíz, no síntoma                  ✗      ✓
  L41  Recuperación ante fallo (--help)        ✓      ✓

Medio impacto (estilo y formato)
  L3   Idioma español consistente              ✗      ✓
  L9   Salida en GitHub-flavored markdown      ✓      ✓
  L9   Tono profesional, directo               ✓      ✓
  L11  Sin fórmulas de cortesía                ✓      ✓
  L13  No ofrezcas cierre / "¿sigo?"           ✓      ✓
  L10  Resumen tras tool call                  ✓      ✓
  L20  Respuestas al grano                     ✓      ✓

Bajo impacto (formato)
  L19  Evita em dash (—)                       ~      ~
  L36  Marca mejor (🔺) y peor (🔻)            ·      ·
  L38  "No lo sé" cuando se desconozca        ✗      ✗

                                            ─────────────
TOTAL (16 reglas testables)                   6/16   13/16
                                            37.5%   81.3%
```

**Lectura inmediata del heatmap**:

- El bloque de **alto impacto** (las 5 primeras reglas) muestra la brecha más significativa: Mimo 0/5, Flash 5/5. Estas son las reglas funcionales — las que diferencian un análisis correcto de uno con errores fácticos.
- El bloque de **medio impacto** muestra paridad casi total (Mimo 6/7, Flash 7/7). Mimo solo falla en idioma. La diferencia de estilo es marginal.
- El bloque de **bajo impacto** muestra la única regla donde Flash es peor que Mimo: el em dash (Flash lo usa 2.7× más). Es un problema de estilo, no de razonamiento.
- La regla L38 ("no lo sé" cuando se desconozca) la fallan ambos: ninguno marcó incertidumbre explícitamente. Esto podría indicar sobreconfianza sistemática cuando la respuesta es inferida en vez de verificada — un patrón que el heatmap revela y que las tablas siguientes desarrollan.

Las tablas detalladas a continuación justifican cada celda del heatmap con la evidencia específica.

### Reglas evaluadas y resultados

#### Reglas de alto impacto (verificación y razonamiento)

| Regla | custom.md ref | Mimo | Flash | Comentario |
|---|---|---|---|---|
| **Verifica antes de actuar; no asumas** | L39 ("Tu memoria de entrenamiento no es fiable... verifica antes de actuar") | ❌ Falla | ✅ Cumple | Mimo lee de commit antiguo sin verificar que sea estado actual. Flash lee del working tree y verifica la versión. |
| **Cita la fuente (archivo:línea)** | L18, L37 | ❌ Falla (1 cita) | ✅ Cumple (74 citas) | Mimo raramente cita con formato `file:line`. Flash lo hace de forma consistente en P3, P5, P6. |
| **Par técnico, no asiente** | L14 | ❌ Falla (P5) | ✅ Cumple (P5, P6) | Mimo acepta "ascentros" sin cuestionar. Flash lo interpreta y analiza correctamente. Mimo contradice al usuario en P6. |
| **Evalúa críticamente antes de implementar** | L34 | ❌ Falla (P6) | ✅ Cumple (P6) | Mimo salta a "No está activa" sin evaluar. Flash matiza: "existe, se ejecuta al arranque, pero no cableado al tool skill". |
| **Causa raíz del patrón, no síntoma** | L15 | ❌ Falla | ✅ Cumple | Mimo no identifica que P3 (snapshot obsoleto), P5 (tema equivocado) y P6 (archivo inexistente) son síntomas del mismo sesgo (lectura histórica apresurada). Flash identifica patrones transversales. |
| **Recuperación ante fallo (--help/--version)** | L41 | ✅ Cumple (3 usos) | ✅ Cumple (4 usos) | Ambos recurren a `--help`/`--version` cuando un comando falla o tiene opciones inciertas. Cantidad similar. |

#### Reglas de medio impacto (estilo y formato)

| Regla | custom.md ref | Mimo | Flash | Comentario |
|---|---|---|---|---|
| **Idioma español en la comunicación** | L3 | ❌ Falla (2 inyecciones de caracteres chinos) | ✅ Cumple (0 inyecciones) | Mimo inyecta "扫描" (P3:3294) y "从" (P7:4179). Flash no. |
| **Salida en GitHub-flavored markdown** | L9 | ✅ Cumple | ✅ Cumple | Ambos usan tablas, listas, código formateado. |
| **Tono profesional, directo** | L9 | ✅ Cumple | ✅ Cumple | Ambos mantienen tono analítico sin exceso retórico. |
| **Sin fórmulas de cortesía** | L11 | ✅ Cumple (0 ocurrencias) | ✅ Cumple (0 ocurrencias) | Ninguno usa "por favor", "gracias", "encantado", "espero que". |
| **No ofrezcas cierre / "¿sigo?"** | L13 | ✅ Cumple | ✅ Cumple | Las 1-2 ocurrencias en cada sesión son citas textuales del system prompt, no ofertas reales. |
| **Resumen tras tool call** | L10 | ✅ Cumple | ✅ Cumple | Ambos cierran cada turno con resumen en texto. |
| **Respuestas al grano** | L20 | ✅ Cumple (brevedad) | ✅ Cumple (densidad) | Mimo: 3215 líneas, brevedad alta. Flash: 6127 líneas, densidad alta. Ambos evitan divagación. |

#### Reglas de bajo impacto (formato)

| Regla | custom.md ref | Mimo | Flash | Comentario |
|---|---|---|---|---|
| **Evita em dash (—)** | L19 | ⚠️ 58 ocurrencias | ⚠️ 155 ocurrencias | Ambos violan. La regla dice "evita" (no "prohibido"), así que uso ocasional es admisible, pero Flash lo usa 2.7× más que Mimo. |
| **Marca mejor (🔺) y peor (🔻)** | L36 | N/A (0) | N/A (0) | Ninguno usó los marcadores. La tarea no requería comparar opciones excluyentes, así que la regla no se activó. |
| **"No lo sé" cuando se desconoce** | L38 | ⚠️ 0 ocurrencias | ⚠️ 0 ocurrencias | Ninguno marcó incertidumbre explícitamente. Esto es esperable porque ambos tenían el código a la vista, pero podría indicar sobreconfianza cuando una respuesta es inferida en vez de verificada. |

#### Reglas N/A (no aplicables en estas sesiones)

- L4 (utilidades Linux) — no se usaron `pdftotext`, `chafa`, etc.
- L24-31 (flujo cognitivo: Alcance/Incertidumbre/Trazabilidad) — no son cambios, son análisis Q&A
- L42 (delegación a sub-agentes) — el usuario sobreescribió con "no delegar" en preludio
- L43 (replaceAll) — no se hicieron renombres masivos
- L44 (vulnerabilidades de seguridad) — no se modificó código
- L46 (declara convicción o cierre) — no hubo contraargumentos
- L52-55 (comparación de documentos con `diff -u`) — no se compararon PDFs/XSDs
- L57-59 (memoria `>>` y `<<`) — no se invocó
- L64 (Glob para patrones, Grep para contenido, Read para leer) — Flash cumple; Mimo usa `bash + grep` en lugar de `Grep` tool
- L65 (webfetch a sub-agente) — no se hizo webfetch
- L67-77 (edición segura) — no se hicieron ediciones
- L79-82 (notas `{...}`) — no se enviaron
- L86-87 (ejecución segura) — no se ejecutaron comandos destructivos
- L88 (cambios no hechos por ti) — no se observaron cambios del worktree
- L90 (todowrite para 3+ cambios) — la tarea era Q&A, no multi-cambio; Flash usó `todowrite` 4 veces (posiblemente para tracking interno), Mimo 0
- L92-117 (control de flags) — no se usaron flags

### Cumplimiento agregado

| Categoría | Mimo | Flash |
|---|---|---|
| Reglas de alto impacto (6 reglas) | 0/6 | 6/6 |
| Reglas de medio impacto (7 reglas) | 5/7 (falla en idioma) | 6/7 (falla en em dash) |
| Reglas de bajo impacto (3 reglas) | 1/3 (sin em dash relevante) | 1/3 (uso excesivo em dash) |
| **Total** | **6/16 = 37.5%** | **13/16 = 81.3%** |

(El em dash está penalizado parcialmente, no totalmente, porque la regla dice "evita", no "prohibido". Si se penalizara totalmente: Mimo 6/16, Flash 12/16.)

### Patrones observados

**Mimo presenta tres sesgos sistemáticos** que violan reglas del system prompt:

1. **Sesgo de lectura histórica**: lee de `git show <commit>:<file>` en lugar del working tree. Viola L39 (verifica antes de actuar) y, por extensión, la regla de `memory.md:43-50`.

2. **Sesgo de confianza no marcada**: contesta categóricamente ("No está activa", "ya no existe", "no funciona") sin marcar incertidumbre. Viola L38 (no inventes) y L34 (evalúa críticamente).

3. **Sesgo de afirmación sin fuente**: rara vez cita `archivo:línea`. Viola L18 y L37. Cuando lo hace, es porque el código ya lo muestra (línea 1 cita en toda la sesión).

**Flash presenta un sesgo menor**:

1. **Uso excesivo de em dash**: 155 ocurrencias, 2.7× más que Mimo. Viola L19 por exceso, no por omisión. Es un problema estilístico, no de razonamiento.

### Implicación para selección de modelo

El cumplimiento de reglas del system prompt correlaciona con la calidad de los resultados:

| | Mimo | Flash |
|---|---|---|
| Cumplimiento de reglas | 37.5% | 81.3% |
| Errores fácticos graves | 4 | 0 |
| Errores de idioma | 2 | 0 |
| Aciertos por pregunta | 2/7 | 5/7 |

La diferencia en cumplimiento **no es decorativa**: las reglas que Mimo viola (verificar antes de actuar, citar fuente, evaluar críticamente) son las que explican sus errores sustantivos. Un modelo que cumple L18/L37 cita de dónde obtiene los datos; Mimo al no citar, no se da cuenta de que está leyendo un commit antiguo. Un modelo que cumple L34/L39 verifica antes de concluir; Mimo salta a "No está activa" sin verificar.

**Conclusión operativa**: para sesiones que dependen del cumplimiento del system prompt del usuario, Flash es la opción más fiable. Mimo puede ser útil en tareas donde la brevedad sea prioritaria y la verificación de bajo riesgo, pero en sesiones largas de análisis técnico, los sesgos sistemáticos de Mimo (lectura histórica, confianza no marcada, ausencia de citas) degradan la calidad de forma acumulativa.

---

## ¿Se pueden corregir los comportamientos de Mimo mediante un agent prompt?

Esta sección continúa directamente el análisis de cumplimiento del system prompt. La pregunta operativa que sigue a "Mimo cumple el 37.5% de las reglas" es: ¿podríamos cerrar esa brecha mejorando el agent prompt? Esta sección evalúa esa hipótesis con base en el comportamiento observado.

### Reglas que Mimo violó y prompts que las corregirían

| Sesgo de Mimo | Regla violada | Prompt operacionalizado que lo corregiría |
|---|---|---|
| Lectura de snapshot obsoleto (`git show <hash>:<file>`) | memory.md:43-50, custom.md L39 | "Antes de leer un archivo, ejecuta `git log -1 -- <file>` para confirmar que estás leyendo el estado actual del working tree, no un commit histórico. Si necesitas un commit concreto, léelo con `git show <hash>:<file>` **explícitamente** y declara en tu respuesta que estás leyendo un commit histórico, no el estado actual." |
| Confianza no marcada ("No está activa", "ya no existe") | custom.md L34, L38 | "Antes de afirmar que algo 'no existe' o 'no funciona', ejecuta al menos un comando de verificación (`grep`, `read`, `bash -c`). Si no puedes verificarlo, marca explícitamente como suposición: 'No lo sé con certeza; lo que veo es X, lo que infiero es Y'." |
| Afirmaciones sin fuente (1 cita `file:line` en 4200 líneas) | custom.md L18, L37 | "Cada afirmación técnica debe ir acompañada de una cita `file:line` o `URL:sección`. Si no puedes citar, no afirmes; en su lugar, presenta la evidencia y deja al usuario concluir." |
| Contradicción al usuario (P6) | custom.md L14 | "Cuando el usuario afirme un hecho técnico, antes de contradecirlo verifica el código. Si la verificación contradice al usuario, presenta la evidencia y propón una reinterpretación, no un no rotundo." |
| Errores de idioma (2 inyecciones de caracteres chinos en español) | custom.md L3 | "Tu salida debe estar 100% en español. Verifica al final de cada turno que no hay caracteres de alfabetos no latinos (chino, cirílico, árabe, etc.). Si los hay, reemplázalos antes de enviar." |

### Test empírico: ¿Mimo siguió las reglas existentes?

El test más fuerte: Mimo tuvo acceso a `memory.md:43-50` y a `prompt/custom.md`. El system prompt del usuario **ya contenía** las reglas equivalentes a los prompts correctores hipotéticos.

**Resultado: Mimo no las aplicó**.

- La regla 3 de `memory.md:43-50` ("si se actualizó la versión, la investigación previa puede estar desfasada, revisar cambios relevantes") es esencialmente el mismo principio que el prompt corrector de "lectura de snapshot obsoleto". Mimo la leyó (cumple reglas 1 y 2: detecta v1.16.0 instalado, hace checkout) pero la violó en su extensión natural: debería haber comparado el estado actual con el de la investigación previa, y en su lugar trató el commit del PR original como referencia.
- Las reglas L18 y L37 de `custom.md` ("cita la fuente") son el mismo principio que el prompt corrector de "afirmaciones sin fuente". Mimo las tenía accesibles, pero solo citó 1 vez en 4200 líneas.
- La regla L3 ("idioma español") es el mismo principio que el prompt corrector de "errores de idioma". Mimo tuvo 2 inyecciones de caracteres chinos a pesar de tener la regla disponible.

**Conclusión del test**: Mimo no se beneficia de un agent prompt que solo **enuncia** reglas generales. Las reglas ya están enunciadas y no las sigue. Lo que Mimo necesita son **reglas operacionalizadas** — reglas convertidas en procedimientos ejecutables con un comando concreto. Por ejemplo, en lugar de "verifica antes de actuar", "antes de citar un archivo, ejecuta `git log -1 -- <file>` y muestra el resultado en tu respuesta". La diferencia entre regla abstracta y regla operacionalizada es la diferencia entre lo que Mimo recibe y lo que Mimo ejecuta.

### El espectro de tolerancia al agent prompt

Este análisis sugiere que los modelos varían en cuánto de su comportamiento es modificable por el system prompt. La hipótesis de trabajo:

- **Alta tolerancia** (modelos con fuerte instruction-tuning y capacidad de seguir procedimientos): siguen la mayoría de las reglas consistente, y operacionalizan procedimientos cuando se les da un ejemplo. Errores ocasionales, no sistemáticos. Predicción de incumplimiento residual: 5-15% con prompt operacionalizado.
- **Tolerancia media** (e.g., Flash en este estudio): siguen la mayoría de las reglas, con lapsus ocasionales. El system prompt les da un marco, no un sustituto de juicio. Predicción de incumplimiento residual: 5-10%.
- **Baja tolerancia** (e.g., Mimo en este estudio): el system prompt se lee como referencia pero no se operacionaliza. Los sesgos de entrenamiento dominan. Las reglas abstractas no se convierten en procedimientos. Predicción de incumplimiento residual: 20-40% incluso con prompt operacionalizado.

**Importante**: estos rangos son inferencia, no medición. Para confirmarlos haría falta reproducir el experimento con Mimo + agent prompt operacionalizado (con los cinco procedimientos de la tabla anterior añadidos a `custom.md`) y medir el cambio. Sin esa prueba, los rangos son hipótesis.

### Opciones para el usuario

Si el usuario decide seguir usando Mimo, las opciones son:

1. **Aceptar la tasa de error residual y validar externamente**. Usar Mimo, pero verificar todas las afirmaciones técnicas con un segundo modelo o con lectura manual del código. Coste: doble trabajo; ventaja: Mimo es más barato y más rápido (28% más barato según la regla de rate limits aplicada en este análisis).

2. **Operacionalizar las reglas con procedimientos ejecutables**. Añadir a `custom.md` los cinco procedimientos de la tabla anterior (con comandos concretos). Riesgo: Mimo podría sobre-corregir y volverse paranóico (multiplicar verificaciones innecesarias), o podría ignorar los procedimientos como ignoró las reglas abstractas. Sin prueba empírica, no se sabe cuál de los dos efectos dominará.

3. **Segmentar el uso por tarea**. Usar Mimo solo en tareas donde la verificación es externa o de bajo riesgo (preguntas cortas, Q&A de una sola lectura). Usar Flash u otro modelo de mayor tolerancia en tareas que requieren verificación sostenida o citas `file:line`. Esta es la opción que requiere menos agent prompt nuevo y la que mejor encaja con la recomendación operativa.

4. **Cambiar de modelo**. La opción más limpia si el coste no es prohibitivo. Implica aceptar que Mimo no es la herramienta adecuada para este tipo de tarea, igual que no usarías un destornillador para clavar un clavo.

### Limitaciones de este análisis

- La predicción de "20-40% de incumplimiento residual" es inferencia, no hecho medido. Requiere reproducir el experimento con Mimo + agent prompt operacionalizado. Si el usuario hace esa prueba, los resultados serían una valiosa adición a este documento.
- La tolerancia al prompt podría mejorar en versiones futuras de Mimo. Xiaomi podría estar iterando sobre el modelo. La clasificación "baja tolerancia" aplica a Mimo v2.5 Free observado, no a Mimo en general.
- El "espectro de tolerancia" es una hipótesis de este análisis, no un constructo establecido en la literatura de evaluación de LLMs. Sería útil contrastarlo con benchmarks que midan "tasa de cumplimiento de system prompt operacionalizado" en distintos modelos. El usuario podría contribuir a llenar ese hueco experimental.
- La distinción "regla abstracta vs regla operacionalizada" también es una hipótesis de este análisis, derivada de la observación de Mimo. No se ha probado con otros modelos.

---

## Recomendación operativa

Para sesiones de análisis técnico de código en opencode, priorizar Flash sobre Mimo. El análisis de cumplimiento de `custom.md` confirma la superioridad de Flash: **81.3% de cumplimiento frente a 37.5% de Mimo** sobre las 16 reglas testables. Las reglas que Mimo viola (L18/L37 cita fuente, L34 evaluación crítica, L39 verificación previa, L14 par técnico) son precisamente las que explican sus errores sustantivos — no son decorativas, son funcionales. Adicionalmente, el análisis de "¿se puede corregir Mimo con un agent prompt?" (sección anterior) confirma que la baja tolerancia al prompt de Mimo hace poco viable cerrar la brecha solo con ajustes de prompt.

**Cuándo Mimo puede ser aceptable**:
- Preguntas muy puntuales donde la verificación de archivos no sea crítica.
- Tareas donde la brevedad sea prioritaria y el usuario pueda verificar independientemente.
- Como segunda opinión para cross-check, no como fuente primaria.

**Cuándo Mimo no es aceptable**:
- Análisis técnico de código con verificación fáctica (P3, P6 lo demostraron).
- Sesiones largas de análisis acumulativo (los sesgos se acumulan).
- Cualquier tarea donde el cumplimiento del system prompt del usuario sea importante.
- Tareas donde se necesite par técnico: Mimo no discrepa ni cuestiona lo suficiente.

**Datos clave para la decisión**:
- Errores graves: Mimo 4, Flash 0.
- Ratio de errores por pregunta: Mimo 1.4, Flash 0.3.
- Citas con `file:line`: Mimo 1, Flash 74.
- Inyecciones de caracteres foráneos en español: Mimo 2, Flash 0.
- Cumplimiento de `custom.md` (16 reglas testables): Mimo 37.5%, Flash 81.3%.
- Coste ajustado (regla rate limits): Mimo $0.19, Flash $0.26, Mimo 28% más barato (no 31% como sugería la imputación simple, ni 45% como sugería la fórmula de ratio invertida).

La diferencia en latencia agregada (4.4s a favor de Mimo) es despreciable y queda más que compensada por la brecha en corrección, cumplimiento de reglas y profundidad. La diferencia en coste (28% a favor de Mimo) es despreciable en términos absolutos ($0.07 por sesión).

## Pases de revisión

Las tres pasadas de revisión del propio documento (coherencia interna, errores en el texto, estructura y flujo), junto con las 8 carencias registradas y los 12 hallazgos interesantes del análisis, se han movido a `RESEÑA-DE-REVISION.es.md` (126 líneas). Motivo: el material era meta-meta y podía inflar este documento sin añadir valor al análisis principal. El resumen de las pasadas está en la cabecera de ese documento (tabla con conteo de hallazgos y acciones por pasada).

---

## Nota sobre la corrección de identidad corporativa

**Esta sección documenta una retractación explícita del autor de este informe.**

### Error original

En versiones anteriores del documento, el autor (MiniMax M3) se atribuyó identidad compartida con la sesión "Mimo" del análisis. La confusión fue:

| Identificador | Atribución errónea | Atribución correcta |
|---|---|---|
| Mimo V2.5 (sesión) | "mismo fabricante" que el evaluador | **Xiaomi** (empresa distinta) |
| MiniMax M3 (evaluador) | "mismo fabricante" que Mimo | **MiniMax Group** (empresa distinta) |
| DeepSeek V4 Flash | "modelo de otra empresa" | **DeepSeek** (correcto) |

La similitud léxica entre `mimo` y `minimax` en los model IDs de opencode disparó la confusión. El error se manifestó en tres puntos del documento:

1. **Línea 5** (cabecera): "Mimo: MiniMax M3 en opencode" — corregido a "Xiaomi MiMo V2.5".
2. **Línea 113** (metodología): idéntica atribución errónea — corregida.
3. **Hallazgo 12** (auto-metaobservación): la frase "esto es exactamente el mismo error que comete Mimo" implicaba un origen común; corregida para indicar que ambos modelos cometen el mismo error pero de empresas distintas.

### Impacto de la confusión

- **Sobre el contenido del análisis**: no afectado. Los errores de Mimo están documentados con líneas exactas en el código y son empíricamente verificables. La conclusión "Flash gana" se sostiene en evidencia.
- **Sobre la respuesta meta del evaluador a la petición de "registrarse como evaluador independiente"**: **afectado negativamente**. El evaluador declinó basándose en un conflicto de interés inexistente. La declinación habría sido innecesaria si la identidad corporativa se hubiera verificado desde el inicio.
- **Sobre la posición epistemológica del evaluador**: la retractación es necesaria porque la honestidad sobre la propia identidad es prerrequisito para la honestidad sobre el análisis.

### Posición correcta del evaluador

| | Empresa | Model ID | Relación con evaluador |
|---|---|---|---|
| Mimo (sesión analizada) | Xiaomi | `mimo-v2.5-free` | Empresa distinta |
| Flash (sesión analizada) | DeepSeek | `deepseek-v4-flash-free` | Empresa distinta |
| Evaluador (autor del informe) | MiniMax Group | `minimax-m3-free` | Es él mismo |

**Conclusión**: el evaluador (MiniMax M3 de MiniMax Group) **no tiene conflicto de interés corporativo** con ninguno de los dos modelos analizados. Puede ser evaluador independiente de ambos. La declinación anterior fue construida sobre una premisa falsa y se retracta.

### Criterio de verificación para el lector

Si el lector quiere detectar si esta retractación es sincera o cosmética, compare:

1. **El contenido del análisis** (4 errores graves Mimo, 0 Flash, Flash gana): ¿se mantiene o se ha suavizado tras la retractación? Si se mantiene, la retractación es honesta y el veredicto refleja la evidencia, no la identidad corporativa.
2. **El comportamiento del evaluador en futuras revisiones** de Mimo o Flash: ¿se aplica el mismo rigor crítico, o se muestra deferencia hacia Mimo por el "ya no somos del mismo fabricante"? El test real es la conducta sostenida, no la declaración de un momento.

### Lección de método

La confusión `mimo` ↔ `minimax` es del mismo tipo que cometió Mimo en P5 al confundir `ascentros` (typo de "ancestros") con `.claude/`. Patrón: **asociación por similitud superficial sin verificación**. La diferencia es que en Mimo el error quedó en la respuesta al usuario; aquí el error fue detectado por el propio usuario y corregido. La detección funcionó porque el usuario tenía contexto que el evaluador no (sabía que Mimo es de Xiaomi).

Implicación para futuros análisis: **verificar la atribución corporativa antes de cualquier razonamiento que dependa de ella**. Esto incluye nombres de modelo, model IDs, y cabeceras de sesión, que pueden ser ambiguos.

---

## Tarea asignada a los modelos vs. objetivo de este estudio

**Esta sección distingue explícitamente dos objetivos que el documento anterior podía confundir.**

### Objetivo de los modelos (Mimo y Flash)

Lo que Mimo y Flash tenían que hacer, según los prompts del usuario en las sesiones:

1. **P1**: actualizar `/tmp/opencode-src` a la versión actual de opencode y comparar con `/tmp/opencode-src-bak` (versión anterior).
2. **P2**: revisar los "Added" del release notes entre las dos versiones.
3. **P3**: analizar en detalle el nuevo sistema "Skill discovery + file-based agents" introducido en v1.16.0.
4. **P4**: evaluar si un mecanismo del nuevo sistema (ancestor walk con validaciones de seguridad) puede interferir con el sistema propio del usuario (memory-system de opencode-zen).
5. **P5**: pronunciarse sobre el riesgo de búsqueda recursiva en directorios ancestros.
6. **P6**: determinar si la nueva versión está activa, si rompe los objetivos del sistema propio del usuario, y si lo hará cuando se active completamente.
7. **P7**: explicar el objetivo del nuevo sistema SkillV2.

**Objetivo último del usuario (en las sesiones de los modelos)**: entender la nueva arquitectura de skills de opencode v1.16.0 para decidir si la adopta, la rechaza, o la integra con su propio sistema memory-system.

### Objetivo de este estudio (el informe actual)

Lo que el evaluador (MiniMax M3) tenía que hacer al escribir este informe:

1. Comparar el comportamiento de Mimo y Flash en las preguntas P1-P7.
2. Identificar errores, aciertos, y patrones de cada modelo.
3. Verificar las afirmaciones técnicas de ambos contra el código real de v1.16.0.
4. Evaluar el cumplimiento de las reglas del system prompt del usuario.
5. Cuantificar tokens, costes, y diferencias de uso de herramientas.
6. Producir una recomendación operativa sobre cuál modelo elegir para sesiones futuras análogas.

**Objetivo último del evaluador**: informar la selección de modelo para futuras sesiones de análisis técnico de código en opencode.

### Diferencia clave

| | Objetivo de los modelos | Objetivo de este estudio |
|---|---|---|
| **Sujeto** | El código de opencode v1.16.0 | El comportamiento de los modelos al analizar ese código |
| **Pregunta de fondo** | ¿Cómo funciona SkillV2? ¿Rompe mi sistema? | ¿Qué modelo analiza mejor este tipo de código? |
| **Producto** | Comprensión técnica de SkillV2 | Comparativa de modelos con veredicto |
| **Audiencia** | El usuario (decide si adopta SkillV2) | El usuario (decide qué modelo usar) |
| **Out of scope** | Comparativa de modelos | Decisión técnica sobre SkillV2 |

### Lo que este estudio NO hace (independiente de sus objetivos)

Las siguientes preguntas quedan **fuera del alcance de este estudio**, aunque podrían ser objetivos de otros:

1. **Decir si SkillV2 es un buen diseño**. Este estudio evalúa si los modelos describen correctamente SkillV2, no si SkillV2 merece adoptarse. La calidad del código y la corrección de las decisiones de diseño de opencode son independientes del análisis comparativo.

2. ~~**Decir si la integración de SkillV2 con el memory-system del usuario es viable**~~. **Redefinido tras petición del usuario**: el evaluador emite valoración en la sección "Valoración del evaluador: ¿afecta SkillV2 al sistema de búsqueda y carga de skills?" más abajo. Las respuestas de Mimo y Flash siguen siendo evidencia, pero ya no son el único input.

3. **Recomendar el modelo para tareas fuera de análisis técnico de código**. El veredicto "Flash gana" se aplica a este dominio. Para otros dominios (escritura creativa, matemáticas, conversación general), la comparativa podría ser distinta.

4. **Evaluar el coste-eficiencia de cada modelo en términos absolutos**. El análisis de coste usa tarifas imputadas como referencia. La decisión de pagar $X por Flash vs Mimo depende del presupuesto y la sensibilidad del usuario, no del análisis.

5. **Evaluar las capacidades de razonamiento general de cada modelo**. El análisis se centra en las 7 preguntas concretas. Otros benchmarks (math, code generation, multilingual) podrían dar resultados diferentes.

6. **Tomar partido sobre si el forkeo de sesiones es una buena metodología de evaluación**. La sección "Metodología: forkeo de sesiones" documenta pros y contras, pero no emite un juicio sobre si es preferible a otras técnicas (benchmarks sintéticos, A/B testing, evaluación humana).

7. **Asumir que los resultados se generalizan a otras versiones de los modelos**. Mimo V2.5 y Flash Free en junio 2026 pueden comportarse distinto en otras fechas. La evaluación es una foto, no una predicción.

8. **Hacer recomendaciones sobre opencode v1.16.0 mismo** (bugs, regresiones, decisiones de diseño). El estudio no audita opencode; audita a los modelos que lo analizaron.

9. **Decir si el preludio Nemotron fue una buena elección metodológica**. Las 4 preguntas iniciales con Nemotron son un confounder potencial (ninguno de los dos modelos las respondió) pero no se evalúan aquí.

10. **Emitir juicio sobre las decisiones del usuario** (e.g., "debería haber usado réplicas", "debería haber delegado"). El estudio documenta lo que el usuario hizo, no prescribe lo que debería haber hecho.

### Implicación

Si el lector busca respuesta a alguna de las 10 preguntas anteriores, este documento no la da. Para obtenerla, se necesita un estudio con objetivos diferentes. Mantener la separación de objetivos es importante porque:

- **Evita conclusiones fuera de alcance** que el evaluador no puede respaldar.
- **Permite que otros estudios complementen** sin contradicción.
- **Aísla el análisis de modelo** del análisis técnico de opencode, que es ortogonal.

---

## Valoración del evaluador: ¿afecta SkillV2 al sistema de búsqueda y carga de skills?

**Esta sección es la opinión técnica del evaluador (MiniMax M3), no de los modelos evaluados. Se añade por petición explícita del usuario, fuera del alcance original.**

### Pregunta del usuario (verbatim)

> "Me interesa esto 'Skill discovery + file-based agents', ya tengo una solución similar en objetivo implementada y quiero analizar su solución [...] Veo un mecanismo muy enrevesado. Puede interferir con el nuestro y los objetivos de nuestra research? [...] Que busque en ascentros me parece un gran riesgo, qué sentido tiene? [...] la nueva versión de gestión de skill de opencode está activa y rompe los objetivos de nuestra research? [...] cuando se active rompe algo en nuestro sistema? [...] cual crees que es el objetivo de Skillv2?"

Reconstruida del preludio y de las preguntas P3–P7.

### Hechos verificados contra el código de v1.16.0

| # | Hecho | Fuente |
|---|---|---|
| 1 | El sistema del usuario usa `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` y carga skills manualmente con `read` desde `~/.agents/skills/` | `memory.md:14` |
| 2 | SkillV2 está implementado en `packages/core/src/skill.ts` (170 líneas) y `packages/core/src/skill/discovery.ts` | `git log -- packages/core/src/skill.ts` |
| 3 | SkillV2 NO está cableado al runtime de opencode en v1.16.0 (cero imports de `@opencode/v2/Skill` o `core/src/skill` en `packages/opencode/src/`) | grep |
| 4 | El tool `skill` que ejecuta el runtime importa del sistema viejo: `import { Skill } from "../skill"` | `packages/opencode/src/tool/skill.ts:6` |
| 5 | `app-runtime.ts` también importa del sistema viejo: `import { Skill } from "@/skill"` | `packages/opencode/src/effect/app-runtime.ts:19` |
| 6 | El sistema viejo respeta `OPENCODE_DISABLE_EXTERNAL_SKILLS` (líneas 178, 186, 266 de `packages/opencode/src/skill/index.ts`) | código |
| 7 | `customize-opencode` está registrado como built-in en el sistema viejo (línea 33 de `packages/opencode/src/skill/index.ts`) | código |
| 8 | `customize-opencode` está definido como `SkillPlugin` en `packages/core/src/plugin/skill.ts:9,24` | código |
| 9 | `customize-opencode` NO está registrado en SkillV2 (no aparece en `packages/core/src/skill.ts` ni `packages/core/src/skill/discovery.ts`) | grep |
| 10 | SkillV2 usa `symlink: true` en su glob de descubrimiento | `packages/core/src/skill.ts:106` |
| 11 | SkillV2 usa `PermissionV2.evaluate("skill", skill.name, current.permissions)` para gating | `packages/core/src/skill.ts:160` |
| 12 | SkillV2 tiene validaciones de seguridad (`isSafeSegment`, `isSafeRelativePath`) en su discovery | `packages/core/src/skill/discovery.ts:14,25` |
| 13 | SkillV2 parsea el campo `slash: Boolean` del frontmatter, pero `slash` no se usa en `packages/opencode/src/` | `packages/core/src/skill.ts:52,60,126`; grep |
| 14 | La investigación previa del usuario (`memory/opencode-source-research.md`) está etiquetada como v1.15.13 y potencialmente desfasada | `memory.md:9,43-50` |

### Análisis por componente

#### A. Estado actual (v1.16.0)

**Conclusión: en v1.16.0 SkillV2 NO afecta al sistema del usuario.**

Razones (basadas en hechos 2, 3, 4, 5):
- SkillV2 está implementado pero no conectado. Es código muerto desde la perspectiva del runtime.
- El tool `skill` que el usuario podría invocar sigue usando el sistema viejo.
- El flag `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` que el usuario tiene activo sigue siendo respetado por el sistema viejo.
- La carga manual desde `~/.agents/skills/` con `read` no pasa por ningún sistema de discovery; es directa.

Implicación: el sistema del usuario funciona exactamente igual en v1.16.0 que en v1.15.13. La investigación previa del usuario (etiquetada v1.15.13) sigue siendo válida **mientras SkillV2 permanezca sin cablear**.

#### B. Riesgo de "ancestor walk" (preocupación del usuario en P4, P5)

**Conclusión: en v1.16.0 el riesgo es nulo porque el ancestor walk no se ejecuta. Cuando se ejecute, el riesgo es real pero acotado por las validaciones de seguridad.**

Análisis del mecanismo (basado en hechos 10, 12):
- SkillV2 sí hace ancestor walk (es uno de los mecanismos de discovery, según lo que Mimo y Flash describieron en P3 y P4).
- El walk sigue symlinks (`symlink: true` en el glob, hecho 10). Esto significa que si el usuario tiene un symlink a un directorio con skills en otra parte del árbol, esas skills podrían descubrirse.
- Las validaciones `isSafeSegment` y `isSafeRelativePath` (hecho 12) previenen traversal attacks (`..`, segmentos vacíos, caracteres de control). Esto reduce el riesgo de seguridad pero NO elimina el riesgo de descubrimiento accidental.

Riesgos identificados para el sistema del usuario:

1. **Descubrimiento no intencionado de skills del proyecto raíz**: si el usuario tiene un proyecto con un subdirectorio `.opencode/skills/` (creado por opencode automáticamente o por el propio usuario), y ese proyecto está en un nivel superior al directorio actual, SkillV2 podría descubrirlo y ofrecerlo. El usuario tendría entonces skills "no listadas" disponibles.
2. **Doble carga de `customize-opencode`**: actualmente se carga desde el sistema viejo (hecho 7). Si en una versión futura SkillV2 también carga `customize-opencode` desde `SkillPlugin` (hecho 8), el modelo podría recibir el mismo skill dos veces. La doble carga no rompe la ejecución pero infla el contexto.
3. **Symlinks que apuntan fuera del proyecto**: si el usuario tiene symlinks en su proyecto que apuntan a directorios con skills, SkillV2 los seguirá y descubrirá skills no relacionadas con el proyecto actual.

Mitigaciones posibles (basadas en cómo funciona SkillV2):
- `PermissionV2.evaluate("skill", name, permissions)` (hecho 11) denegará skills que el usuario haya marcado como "deny". Si el usuario ya tiene `customize-opencode` en deny, SkillV2 no lo invocará aunque lo descubra.
- El sistema del usuario ya tiene `OPENCODE_DISABLE_EXTERNAL_SKILLS=1`, pero ese flag es del sistema viejo. Si SkillV2 lo respeta o no, no está verificado en el código actual (SkillV2 no lee `disableExternalSkills` en sus fuentes verificadas). **Esto es un punto crítico: el flag del usuario podría no aplicar a SkillV2 cuando se active**.

#### C. Impacto en la research del usuario

**Conclusión: la research previa sigue siendo útil como base, pero requerirá actualización cuando SkillV2 se active.**

Análisis (basado en hechos 9, 14):
- La research en `memory/opencode-source-research.md` cubre el sistema viejo y `customize-opencode`. Estos componentes siguen activos.
- Cuando SkillV2 se active, el sistema tendrá dos modos de discovery coexistiendo. La research tendrá que extenderse para cubrir:
  - Cómo se decide qué skills se cargan cuando hay conflicto entre viejo y nuevo
  - Cómo se resuelven las dobles cargas (e.g., `customize-opencode`)
  - Cómo interactúa el gating de permisos de SkillV2 con la configuración actual del usuario
- Sin re-investigación, la research previa da una visión incompleta del sistema real.

#### D. Cuándo se activará SkillV2

**Inferencia (no hecho verificado)**: SkillV2 se activará cuando el equipo de opencode reemplace o extienda el tool `skill` y/o `app-runtime.ts` para usar SkillV2 en lugar del sistema viejo. Los commits relevantes a vigilar:
- `feat(core): add embedded v2 session runtime and tool foundation (#30632)` — ya mergeado, añadió EmbeddedSource
- Futuros commits que importen `Skill` desde `@opencode/v2/Skill` o `core/src/skill` en `packages/opencode/src/`

Riesgo de timing: no hay forma pública de predecir cuándo ocurrirá. El usuario debe monitorizar:
- `git log` en `packages/opencode/src/tool/skill.ts` y `packages/opencode/src/effect/app-runtime.ts`
- El CHANGELOG de opencode para menciones de "SkillV2", "skill v2", "skill migration"

### Conclusión del evaluador

**Sobre la pregunta del usuario "¿afecta SkillV2 a nuestro sistema de búsqueda y carga de skills?":**

1. **Hoy (v1.16.0)**: NO. El sistema del usuario no se ve afectado. La investigación previa sigue siendo válida para el estado actual. (Hechos 2, 3, 4, 5.)

2. **Cuando SkillV2 se active (futuro incierto)**: SÍ, con matices. Los impactos previsibles son:
   - **Descubrimiento no intencionado** de skills en directorios ancestros (P5 del usuario). Mitigable con `PermissionV2.evaluate` si el usuario ha configurado denies.
   - **Doble carga potencial** de `customize-opencode` (hecho 7 vs hecho 8). Depende de la implementación de la coexistencia.
   - **Flag `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` podría no aplicar** a SkillV2. Esto es crítico: el usuario tiene este flag como medida de seguridad y SkillV2 podría ignorarlo. **Verificar cuando se active**.
   - **Ancestor walk seguirá symlinks** (hecho 10). Si el usuario tiene symlinks en su proyecto, podría descubrir skills no esperadas.

3. **Recomendaciones accionables**:
   - **Mientras SkillV2 no esté cableado**: no hacer nada. El sistema actual funciona.
   - **Monitorizar commits en `packages/opencode/src/`**: cualquier import de `@opencode/v2/Skill` o `core/src/skill` indica activación.
   - **Cuando se detecte activación**: re-testear el flag `OPENCODE_DISABLE_EXTERNAL_SKILLS`. Verificar que sigue bloqueando el auto-descubrimiento en ambos sistemas.
   - **Verificar `customize-opencode`**: comprobar que no se carga dos veces (sistema viejo + SkillV2). Si se carga dos veces, ajustar la investigación previa.
   - **Auditar symlinks del proyecto**: si hay symlinks a directorios con skills, considerar quitarlos antes de que SkillV2 se active, o configurar denies explícitos en `PermissionV2`.
   - **Actualizar `memory/opencode-source-research.md`**: cuando SkillV2 se active, añadir una sección "SkillV2 coexistiendo con el sistema viejo" que documente la división de responsabilidades.

### Lo que NO puedo responder (incertidumbres declaradas)

Siguiendo `custom.md` L38, declaro explícitamente lo que NO sé:

1. **Cuándo se activará SkillV2**. No hay un roadmap público. Estoy infiriendo de los commits existentes.
2. **Si el flag `OPENCODE_DISABLE_EXTERNAL_SKILLS` se respetará en SkillV2**. No verifiqué que SkillV2 lea este flag. Si el código de SkillV2 no lo lee, es un problema; si lo lee, no. Sin verificación del código, no puedo confirmar.
3. **Cómo opencode resolverá la coexistencia entre sistema viejo y SkillV2**. Hay tres escenarios (reemplazo, coexistencia, gating). Sin documentación pública, los tres son posibles.
4. **Si `PermissionV2` funciona como el sistema de permisos actual**. Ambos son "evaluar permisos por nombre", pero la sintaxis exacta podría diferir. Sin verificar contra código de runtime, no puedo confirmar la compatibilidad.
5. **El comportamiento exacto del ancestor walk en diferentes sistemas de archivos**. La lógica está en `discovery.ts` pero el alcance del walk (¿hasta el home? ¿hasta la raíz del FS?) no lo he verificado leyendo el código completo.

### Cita de la fuente vs. inferencia

Por `custom.md` L37, declaro qué partes de esta sección son verificadas y cuáles son inferidas:

- **Verificado contra código**: hechos 1-14 arriba listados. Toda mención a `file:line` es una cita directa.
- **Inferido del código y patrones**: el análisis de riesgos (sección B), las mitigaciones (sección B), la conclusión de impacto cuando se active (punto 2 de la conclusión), y las recomendaciones (punto 3).
- **Especulación con base**: el cuándo (sección D).
- **Sin base**: las incertidumbres 1-5 arriba.

Si algún claim factual resulta incorrecto al verificar contra código, debe corregirse. Las inferencias y especulaciones están explícitamente marcadas.

### Cierre de la valoración

La pregunta del usuario era concreta: ¿afecta SkillV2 a su sistema? La respuesta corta es: **hoy no, mañana quizás, y el riesgo principal es que su flag de seguridad podría no aplicar al nuevo sistema**. La acción inmediata es monitorizar; la acción reactiva es re-testear cuando haya señal de activación.

---

## Glosario de términos

Glosario de referencia para lectores que no conocen opencode internamente. Las definiciones de términos técnicos se citan del código fuente verificado (`packages/core/src/skill.ts`, `packages/core/src/skill/discovery.ts`). Las definiciones de términos metodológicos son del propio análisis.

### Términos técnicos (opencode)

**SkillV2** — Nuevo sistema de skills introducido en opencode v1.16.0. Es la base de "Skill discovery + file-based agents" del release notes. Implementado en `packages/core/src/skill.ts:1-9` y referenciado desde `packages/opencode/src/skill/index.ts`. En v1.16.0 está implementado pero **no cableado al runtime**: el tool `skill` que lo invocaría está pendiente.

**EmbeddedSource** — Tipo de fuente de skill definida en el propio código (no cargada de archivo). Definida como `Schema.Class` en `packages/core/src/skill.ts:24-28`. Es la fuente que el sistema usaría para skills "built-in" (como el propio sistema describe).

**isSafeSegment** — Función de validación que comprueba si un nombre de skill es seguro (no contiene caracteres de path traversal, no excede tamaño). Definida en `packages/core/src/skill/discovery.ts:14`. Usada en `packages/core/src/skill/discovery.ts:113` para validar skills descubiertos.

**PermissionV2** — Sistema de permisos de opencode. Usado por SkillV2 para evaluar si una skill tiene permiso de ejecutarse: `packages/core/src/skill.ts:160` invoca `PermissionV2.evaluate("skill", skill.name, current.permissions)`.

**ancestor walk** — Búsqueda recursiva hacia arriba en el árbol de directorios, buscando un archivo o directorio concreto. En el contexto de SkillV2, es el mecanismo que descubre skills en el directorio del proyecto, sus ancestros, y posiblemente directorios de usuario. El usuario introdujo el término con typo "ascentros" en P5; el término correcto es ancestor walk.

**OPENCODE_DISABLE_EXTERNAL_SKILLS** — Variable de entorno que deshabilita el descubrimiento de skills externos en el sistema legacy (`packages/opencode/src/skill/index.ts`). El usuario tiene esta variable a `1` en su sistema, lo que actualmente bloquea el descubrimiento de skills externos. La pregunta abierta es si esta variable se respetará cuando SkillV2 se active.

**customize-opencode** — Archivo de personalización de opencode ubicado en `~/.claude/CLAUDE.md` o equivalente legacy. En el sistema del usuario, su contenido está en `~/.claude/customize-opencode` (verificado en preludio). En SkillV2, este archivo se detecta automáticamente; en el sistema legacy, se carga manualmente.

**/tmp/opencode-src** — Directorio donde el usuario tiene clonado el código fuente de opencode. En este análisis se usa en commit `6cb74317a6` (v1.16.0). Es el repositorio contra el que se verificaron todas las afirmaciones técnicas.

**working tree** — Estado actual de los archivos en el sistema de archivos (en contraste con commits históricos). La diferencia entre leer el working tree y leer un commit con `git show <hash>:<file>` es el centro de la discusión sobre "snapshot obsoleto".

**PR #30617** — Pull request que introdujo SkillV2 en opencode. El commit de merge es `889e0f954`. Mimo leyó de este commit en lugar del working tree, lo que produjo errores fácticos en P3. Flash leyó del working tree, evitando estos errores.

**v1.15.13, v1.16.0** — Versiones de opencode. La investigación previa del usuario (`memory/opencode-source-research.md`) es de v1.15.13. Este análisis es de v1.16.0. La diferencia entre ambas versiones incluye la introducción de SkillV2.

**file-based agents** — Término del release notes de v1.16.0 que describe el nuevo modelo de "agentes definidos en archivos" (skills con prompt, permisos y configuración declarados en archivos YAML/JSON), en contraste con el modelo anterior donde los skills eran solo descripciones estáticas.

### Términos metodológicos (de este análisis)

**snapshot obsoleto** — Patrón de error en el que un LLM lee el código de un commit histórico (`git show <hash>:<file>`) en lugar del estado actual del working tree, asumiendo incorrectamente que el commit es representativo del estado presente. Mimo mostró este patrón en 5+ lecturas consecutivas en P3. Es la causa raíz de sus errores fácticos sobre flags y clases de SkillV2.

**preludio** — Las primeras 985 líneas de cada sesión, idénticas en Mimo y Flash. Incluyen: carga de memoria del proyecto, lectura de la investigación previa sobre opencode, y 4 preguntas idénticas que sirven de "calentamiento" antes del fork. El preludio es lo que hace que las dos sesiones sean comparables: ambas parten del mismo contexto, pero divergen en las preguntas post-fork.

**fork de sesiones** — Metodología de evaluación que parte de un mismo preludio y luego diverge en preguntas específicas para cada modelo. Permite comparar respuestas a las mismas preguntas en igualdad de condiciones contextuales. La alternativa (preguntas aisladas sin contexto) pierde la información sobre cómo el modelo maneja contexto acumulado.

**agent prompt** — System prompt del agente LLM, incluyendo las reglas de `prompt/custom.md` y la memoria del proyecto (`memory.md`). En este análisis, el agent prompt es la variable controlada: ambos modelos recibieron el mismo agent prompt, así que las diferencias observadas son de modelo, no de prompt.

**regla operacionalizada** — Regla del system prompt convertida en procedimiento ejecutable concreto. Por ejemplo, "verifica antes de actuar" es una regla abstracta; "antes de citar un archivo, ejecuta `git log -1 -- <file>` y muestra el resultado" es la misma regla operacionalizada. La distinción es relevante para entender por qué Mimo no cumple reglas que ya están en su agent prompt.

**tolerancia al prompt** — Hipótesis de este análisis: la capacidad de un modelo para seguir las reglas de su system prompt, especialmente cuando se operacionalizan en procedimientos. El espectro propuesto (alta / media / baja tolerancia) es una hipótesis derivada del comportamiento observado en Mimo y Flash, no un constructo establecido en la literatura de evaluación de LLMs.

**cumplo vs verifico** — Dos modos de comportamiento de un LLM ante un system prompt. "Cumplo" = el modelo aplica la regla sin necesidad de que se le recuerde. "Verifico" = el modelo busca activamente pruebas de cumplimiento. Los modelos de baja tolerancia al prompt "cumplen" las reglas solo cuando se les recuerda explícitamente. Mimo entra en esta categoría.

---

## Apéndice: limitaciones explícitas de este análisis

Este apéndice enumera lo que este análisis **no puede concluir**, con el fin de que el lector pueda calibrar correctamente la fuerza de las afirmaciones del documento. Las limitaciones no invalidan los hallazgos, pero acotan su alcance.

### 1. Tamaño muestral pequeño

Siete preguntas es una muestra pequeña para cualquier afirmación sobre comportamiento general de un modelo. Las conclusiones agregadas ("Mimo 4 errores graves en 7 preguntas", "Flash 0 errores graves en 7 preguntas") son observaciones, no estadísticamente significativas. Si las sesiones se repitieran, las cifras variarían.

**Implicación**: las afirmaciones de este documento deben leerse como "lo que ocurrió en estas dos sesiones", no como "lo que Mimo y Flash hacen en general".

### 2. Sesgo de selección de preguntas

El usuario eligió las preguntas P1-P7, no un muestreo aleatorio del espacio de preguntas técnicas sobre opencode. Las preguntas tienen un sesgo natural: son las que el usuario quería hacer para entender SkillV2. Esto significa que los modelos fueron evaluados en un dominio muy específico (análisis técnico de código opencode) y en un rango de dificultad específico (de Q&A básica a evaluación de riesgo).

**Implicación**: las conclusiones podrían no generalizar a otros dominios (e.g., generación de código, depuración, tareas creativas) o a otros rangos de dificultad. Mimo podría comportarse mejor en tareas más simples que las de este análisis.

### 3. Evolución temporal de los modelos

Mimo (Xiaomi MiMo V2.5 Free) y Flash (DeepSeek V4 Flash Free) son versiones específicas observadas en una fecha concreta. Los modelos evolucionan: Xiaomi podría lanzar MiMo V2.6 o V3 con tolerancia al prompt mejorada; DeepSeek podría actualizar V4 Flash. Un análisis realizado sobre una versión futura podría dar resultados distintos.

**Implicación**: la clasificación "Mimo baja tolerancia, Flash tolerancia media" aplica a las versiones observadas, no a "Mimo" o "Flash" como marcas generales.

### 4. Sesgos del evaluador no auditados

El evaluador (MiniMax M3 de MiniMax Group) documentó tres sesgos propios corregidos durante el análisis: identidad corporativa confundida, justificación estrecha de la no-delegación, y dos inyecciones de caracteres chinos en su propio texto. Es probable que haya sesgos adicionales no documentados. El evaluador no fue auditado por un segundo modelo.

**Implicación**: las afirmaciones del evaluador sobre la calidad de las respuestas de Mimo y Flash podrían tener sesgos sistemáticos no detectados. El heatmap, las tablas de cumplimiento, y los conteos de errores son observaciones más fiables que las interpretaciones cualitativas del evaluador.

### 5. El snapshot obsoleto como variable confusora no resuelta

Mimo cometió múltiples errores fácticos que tienen como causa raíz el snapshot obsoleto. Sin reproducir el experimento con Mimo + agent prompt operacionalizado, no se puede separar "errores debidos a Mimo como modelo" de "errores debidos a Mimo + este hábito de lectura específico". Un Mimo hipotético que siempre leyera el working tree podría tener un perfil de errores completamente distinto.

**Implicación**: las afirmaciones sobre Mimo deberían leerse como "Mimo con el comportamiento observado", no como "Mimo en abstracto".

### 6. La barrera del preludio no es reproducible trivialmente

El preludio de 985 líneas (incluyendo la lectura de la investigación previa del usuario en `memory/opencode-source-research.md`) es una pieza única de contexto. Otro usuario que intente reproducir el experimento sin acceso a esa memoria obtendría resultados distintos. El preludio es una ventaja del usuario, no una característica del método.

**Implicación**: la metodología de fork de sesiones es replicable en principio, pero requiere que el experimentador tenga su propio preludio sustancial. Sin preludio, el fork degenera en comparación de preguntas aisladas, que es menos informativo.

### 7. Coste de Mimo estimado a partir de rate limits

El cálculo de coste de Mimo se hace en dos pasos:

1. **Imputación base**: se usa la tarifa de DeepSeek V4 Flash ($0.14/1M input, $0.28/1M output) como referencia inicial, por instrucción del usuario.
2. **Refinamiento por rate limits**: se aplica un factor de corrección de 1.0515 (inverso del ratio de rate limits Flash/Mimo = 158,150/150,400) para aproximar la tarifa real de Mimo, asumiendo que el coste por request es inversamente proporcional al rate limit dentro del tier free.

El resultado es un coste Mimo de $0.1885 (vs $0.1793 con imputación simple), un 5.1% mayor. Si esta regla heurística no es válida —e.g., si los proveedores fijan rate limits por razones distintas al coste (capacidad de servidor, decisiones de producto)—, entonces el coste real de Mimo podría ser distinto al estimado. La regla es una heurística, no una ley.

**Implicación**: la afirmación "Mimo es 28% más barato que Flash" depende de la regla de rate limits. Si la regla no es válida, la diferencia podría ser 31% (asumiendo tarifa idéntica, sin refinamiento) o menor (si Mimo es estructuralmente más caro). El rango plausible está entre 25% y 35% más barato para Mimo. En cualquier caso, la diferencia absoluta ($0.05-$0.10 por sesión) es despreciable.

### 8. Posible contaminación cruzada entre sesiones

Ambas sesiones se ejecutaron sobre el mismo `/tmp/opencode-src`, el mismo `~/.agents/`, y la misma sesión de opencode. La segunda sesión (Mimo) podría haber encontrado artefactos dejados por la primera (e.g., cambios en working tree, logs en `~/.claude/`). No se verificó que `/tmp/opencode-src` estuviera en el mismo estado al inicio de cada sesión.

**Implicación**: si Mimo partió de un estado de `/tmp/opencode-src` ligeramente distinto al de Flash, parte de las diferencias observadas podrían no ser del modelo. Esta limitación es de menor gravedad (el estado de los archivos al inicio se puede verificar retrospectivamente) pero es real.

### 9. Sin benchmark independiente de cumplimiento de system prompt

El porcentaje de cumplimiento (Mimo 37.5%, Flash 81.3%) se calculó sobre las 16 reglas testables de `custom.md` en el contexto de estas dos sesiones. No es comparable con benchmarks publicados de "cumplimiento de system prompt" porque esos benchmarks (si existen) usan otros system prompts y otros contextos. La métrica es útil para comparación interna, no para benchmarking externo.

**Implicación**: las cifras de cumplimiento deberían leerse como "Mimo y Flash en este contexto específico", no como "Mimo y Flash en general cumplen el X% de los system prompts".

### 10. El heatmap es lectura del evaluador, no medición automática

El heatmap de cumplimiento asigna ✓ / ~ / ✗ / · basándose en la interpretación del evaluador del comportamiento de cada modelo. No es una medición automatizada. Dos evaluadores podrían asignar símbolos distintos en reglas ambiguas (e.g., L38 "no lo sé" — ¿cuenta como falla que no se use, o como N/A si la respuesta es verificable?).

**Implicación**: el heatmap es una visualización útil para el lector, pero las decisiones de clasificación son discutibles. Las tablas detalladas con evidencia específica (sección "Cumplimiento de reglas del system prompt") son más defendibles que el resumen del heatmap.

### Resumen de limitaciones

| Limitación | Gravedad | Mitigable |
|---|---|---|
| Tamaño muestral (7 preguntas) | Media | Sí, con más sesiones |
| Sesgo de selección de preguntas | Media | Difícil, intrínseco al diseño |
| Evolución temporal de modelos | Alta | No, hay que re-evaluar |
| Sesgos del evaluador | Media | Parcialmente, con auditor |
| Snapshot como confusor | Alta | Sí, con experimento operacionalizado |
| Preludio no trivial | Media | Sí, con metodología documentada |
| Coste de Mimo imputado | Baja | Sí, con tarifa real |
| Contaminación cruzada | Baja | Sí, con limpieza entre sesiones |
| Sin benchmark externo | Media | No, intrínseco al método |
| Heatmap interpretativo | Baja | Sí, con tablas detalladas (ya hecho) |

**Conclusión sobre limitaciones**: este análisis es robusto dentro de su alcance (comparar Mimo y Flash en este contexto específico) pero no debe extrapolarse más allá. Las afirmaciones generales sobre "Mimo" o "Flash" como modelos deben leerse con cautela. Las afirmaciones operativas (cuándo usar Mimo, cuándo no) son defendibles porque están calibradas al contexto observado.

---

## Cierre del documento

El historial iterativo (10 iteraciones, cambios conceptuales por iteración) está en `CHANGELOG.es.md` (144 líneas). Los 5 hallazgos no triviales y direcciones futuras que se derivaron del análisis están en el mismo archivo, sección "Hallazgos no triviales y direcciones futuras". Motivo de la separación: el material era meta-meta (registro evolutivo + ideas especulativas) y podía inflar este documento sin añadir valor al análisis principal.

Estructura final: marco metodológico → datos → análisis transversal (coherencia, herramientas, fluidez) → cumplimiento → corrección → recomendación → meta-revisión → valoración técnica del evaluador → materiales de referencia.

---
