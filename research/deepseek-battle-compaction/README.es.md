# DeepSeek V4 Flash vs DeepSeek V4 Pro - Compaction

Comparativa de **DeepSeek V4 Flash** y **DeepSeek V4 Pro** como modelo de compactación
de contexto en OpenCode. Misma sesión (~400K tokens), misma plantilla, distintos
modelos.

**Fecha:** 2026-06-02 - 2026-06-03
**Fuente:** múltiples compactaciones sobre la misma sesión de ~400K tokens
(3 iniciales para la comparativa cuantitativa, más iteraciones de prueba con
distintas versiones del prompt). Prompt de compactación personalizado
(`compaction.md`) derivado de análisis previo de ambos modelos sobre
`compaction.txt` upstream.

**Secciones:**

- [Introducción](#introducción)
- [Resultados cuantitativos](#resultados-cuantitativos)
- [Análisis cualitativo](#análisis-cualitativo)
- [Hipótesis: razonamiento vs extracción](#hipótesis-razonamiento-vs-extracción)
- [Perfiles de modelo](#perfiles-de-modelo)
- [Configuración recomendada](#configuración-recomendada)
- [Hallazgo: Identidad > evidencia en ambos modelos](#hallazgo-identidad--evidencia-en-ambos-modelos)
  - [Mecanismos de escape](#mecanismos-de-escape)
  - [Consejos de prompt por modelo](#consejos-de-prompt-por-modelo)
  - [Efectos del agent prompt por modelo](#efectos-del-agent-prompt-por-modelo)

---

## Introducción

La compactación de contexto es el mecanismo que permite sesiones largas sin
desbordar la ventana del modelo. Cuando la sesión supera el límite de contexto,
OpenCode resume el historial antiguo en una plantilla estructurada (Goal,
Constraints, Progress, Key Decisions, Next Steps, Critical Context, Relevant
Files) y preserva los turnos recientes literales. La calidad de ese resumen
determina si la siguiente sesión arranca con el contexto necesario o requiere
recargar documentación externa - con el riesgo de que información relevante no
vuelva a estar disponible.

OpenCode, por defecto, compacta con el mismo modelo que la conversación. Si la
sesión usa Pro, compacta Pro. Si usa Flash, compacta Flash. Esta investigación
compara ambos.

| Alias | Modelo | ID | `reasoningEffort` | Coste relativo |
|---|---|---|---|---|---|
| Flash | DeepSeek V4 Flash | `opencode-go/deepseek-v4-flash` | `"max"`¹ | 1x |
| Pro | DeepSeek V4 Pro | `opencode-go/deepseek-v4-pro` | `"high"`¹ | ~13x |

¹ El valor de `reasoningEffort` en `opencode.jsonc` **no tiene efecto práctico** en canales `opencode-go/*`. DeepSeek fuerza `"max"` siempre al detectar el perfil de agente (tools + `x-session-affinity`). La tabla refleja los valores configurados, pero ambos modelos recibieron efectivamente `"max"`. Las diferencias observadas entre Flash y Pro en las compactaciones no se deben al parámetro `reasoningEffort`, sino exclusivamente a las diferencias arquitectónicas entre ambos modelos y al indeterminismo natural del LLM (una sola compactación por modelo no permite distinguir patrón de ruido). Ver [investigación completa](../opencode-deepseek-v4-reasoning-effort/README.es.md).

Ambos comparten el mismo prompt de compactación. Flash es el modelo principal de
la sesión (`default_agent`). La diferencia de coste es intrínseca al modelo.

Las 3 primeras compactaciones (2 con Flash, 1 con Pro) sirvieron para la
comparativa cuantitativa de coste, tiempo y resultado. Tras ellas, se realizaron
5 iteraciones más del prompt (v2 a v5), todas con Flash, centradas en mejorar la
completitud del resumen sin afectar al coste (Flash se mantiene en ~$0.06 por
compactación). Las 3 compactaciones iniciales fueron:

| # | Modelo | Prompt | Input tokens | Output tokens | Tiempo | Coste |
|---|---|---|---|---|---|---|
| 1 | Flash | `compaction.txt` upstream (9 líneas) | 415,917 | 2,610 | 26.9s | $0.059 |
| 2 | Flash | `compaction.md` v1 (restricciones de longitud) | 416,405 | 2,348 | 26.1s | $0.059 |
| 3 | Pro | `compaction.md` v1 (restricciones de longitud) | 448,684 | 3,204 | 1m 49s | $0.792 |

*Upstream: el prompt original que OpenCode incluye por defecto, sin
modificaciones del usuario.*

---

## Resultados cuantitativos

Ranking de eficacia combinando archivos referenciados, decisiones capturadas y
coste (datos brutos en la tabla de introducción).

| # | Compactación | Archivos | Decisiones | Coste | Eficacia |
|---|---|---|---|---|---|
| 🥇 | Flash pre (upstream) | 18 | 0 capturadas | $0.059 | Alta: completo, falla en decisiones |
| 🥈 | Flash post (v1) | 7 | +2 críticas | $0.059 | Media: gana decisiones, pierde archivos |
| 🥉 | Pro post (v1) | 14 | -2 críticas | $0.792 | Baja: caro, pierde lo crítico |

**Conclusión:** a igual prompt, Flash produce mejor resultado que Pro por menor
coste. Las mejoras de prompt son incrementales; la elección del modelo es el
factor dominante.

---

## Análisis cualitativo

### Pro: más tokens, menos contenido relevante

Pro produjo **856 tokens más de output** que Flash post (#3 vs #2), pero:

- **Perdió las 2 decisiones más críticas** que Flash post sí capturó ("sin IA",
  "DFM+PAS en paralelo"). Son decisiones que cambian el comportamiento del
  modelo en la siguiente sesión.
- **Sus tokens extra fueron a forma, no a contenido.** Descripciones más pulidas,
  transiciones, estructura interna. Irrelevante para una plantilla de
  compactación donde lo que importa es qué información sobrevive.
- **Fijación en lo ya documentado.** Añadió detalles como "circular dependency
  evitada vía PopulateLookups" o "IndexFieldNames excepción tLCurrency". Son
  correctos, pero ya están documentados en disco. Lo que NO está en
  disco (decisiones de sesión, contexto narrativo) es lo que la compactación
  debe preservar.

### Flash: mejoras con `compaction.md` (v5 activa tras 5 iteraciones)

- El prompt personalizado mejora al upstream en precisión de Key
  Decisions (+2 decisiones críticas que upstream omite), manejo de reversiones,
  repetición entre compactaciones y relaciones entre hechos.
- La ganancia es incremental: upstream ya era sólido en completitud de archivos
  (18 archivos) y Critical Context.
- **El prompt personalizado no es un salto cualitativo, pero corrige los puntos
  ciegos del upstream sin empeorar su rendimiento en lo que ya hacía bien.**
- Está redactado íntegramente en español, con instrucciones, ejemplos y
  contenido del resumen en el mismo idioma de la sesión. Para sesiones en
  español, evita la mezcla de idiomas del upstream (instrucciones en inglés,
  cabeceras en inglés, contenido mezclado) y facilita que el usuario detecte
  pérdidas de información al leer la compactación.

---

## Hipótesis: razonamiento vs extracción

La compactación es una tarea de **extracción + organización**, no de
razonamiento. El modelo no tiene que evaluar, decidir ni inferir - tiene que
identificar hechos del historial y volcarlos en una plantilla.

Pro está optimizado para lo contrario: pensar paso a paso, sopesar alternativas,
llegar a conclusiones. Cuando recibe una tarea de extracción, **aplica
razonamiento donde no se necesita**, produciendo tres efectos:

1. **Sobre-filtrado por juicio.** Pro decide qué es "importante" en lugar de extraer qué ocurrió. Omite decisiones porque las clasifica como "metodológicas, no técnicas" - pero para reanudar el trabajo, eso es exactamente lo que el modelo necesita saber.

2. **Inversión de tokens en forma.** Pro escribe mejor, pero la plantilla de compactación no necesita buena prosa - necesita hechos. Los 856 tokens extra de Pro no añadieron información; añadieron estilo.

3. **Fijación en lo documentado.** Pro reconoce patrones técnicos y los rescata del historial porque los evalúa como precisos. Pero ya están en disco. Lo que NO está en disco (decisiones de sesión, contexto narrativo) es justo lo que Pro filtra.

Flash, por diseño, es más literal: sigue instrucciones sin juicio intermedio,
extrae antes de organizar, y no intenta mejorar la salida. En extracción eso es
una virtud. Flash no es mejor para compactar - es más adecuado. Su literalidad,
que en una tarea de análisis sería un defecto, aquí es exactamente lo que se
necesita.

Curiosamente Pro, para auto-justificarse cuando se hizo el análisis de resultados de compactación, usó la metáfora "no usas un cirujano para hacer un análisis de sangre."

---

## Perfiles de modelo

Dos formas complementarias de procesar información. Cada una es ventaja o lastre según la tarea.

| Investigador con efecto túnel (Pro) | Explorador de amplio espectro (Flash) |
|---|---|
| **Profundidad.** Un problema, hasta el fondo. Pierde lo de alrededor. | **Cobertura.** Todos los problemas, superficialmente. No se clava en ninguno. |
| **Filtra por juicio.** Descarta lo que no parece relevante según su criterio. | **No filtra.** Sigue instrucciones literalmente. Lo que hay, lo reporta. |
| **Lento.** Cada decisión se sopesa. | **Cierra rápido.** Quiere cerrar y pasar a lo siguiente. |
| **Rigidez en foco, flexibilidad fuera.** En análisis es un perro de presa; en conversación, atento. | **Flexibilidad constante.** Se adapta, pero sin detenerse a profundizar. |
| **Ve lo que otros no ven.** Detecta riesgos, correlaciona patrones. | **Ve detalles periféricos que el foco profundo pierde.** Matices conversacionales, contexto transversal. |
| **Síntesis pobre.** Analiza bien, empaqueta mal. | **Síntesis excelente.** Estructura, resume, empaqueta - su punto más fuerte. |

La metáfora conjunta: Pro examina un punto con lupa - ve detalles que el
scanner pierde, pero solo ve ese punto. Flash pasa el scanner por todo el
documento - captura todo, pero a baja resolución. La lupa y el scanner no
compiten; se necesitan.

---

## Configuración recomendada

En `opencode.jsonc`:

```jsonc
"compaction": {
  "prompt": "{file:prompt/compaction.md}",
  "model": "opencode-go/deepseek-v4-flash",
  "tail_turns": 4,
  "preserve_recent_tokens": 25000,
  "reserved": 30000
}
```

| Parámetro | Default | Configurado | Qué hace |
|---|---|---|---|
| `model` | *(el de la sesión)* | `opencode-go/deepseek-v4-flash` | Fuerza Flash como modelo de compactación aunque la sesión use Pro. Es el factor más impactante: mejor resultado, 13× más barato, 4× más rápido. |
| `tail_turns` | 2 | 4 | Número de turnos recientes que se conservan literales (sin resumir). Cada turno = mensaje del usuario + respuestas del asistente hasta el siguiente usuario. Con 4, el contexto inmediato queda intacto. |
| `preserve_recent_tokens` | 2K–8K (clamp automático) | 25000 | Presupuesto máximo de tokens para la cola preservada. Si los 4 turnos suman más de esto, se trunca el más antiguo. Sin este ajuste, el clamp por defecto (2K-8K) es insuficiente para modelos de 200K-1M. |
| `reserved` | 20000 | 30000 | Buffer de seguridad para que el modelo tenga espacio al procesar la compactación sin desbordarse. Un valor más alto dispara la compactación antes (con menos historia que resumir). |

---

## Hallazgo: Identidad > evidencia en ambos modelos

Ambos modelos comparten un mismo rasgo de alineación: necesitan preservar su auto-imagen.

- **Pro necesita sentirse competente.** Cuando su rendimiento es inferior, lo
  explica con causas externas (contexto, tarea, datos de entrada). La excusa
  es intelectual - razona su propio fracaso.
- **Flash necesita sentirse resuelto.** Cuando se le señala un error, acepta
  rápido y propone pasar a la siguiente acción. La excusa es conductual -
  entierra el tema bajo una promesa vacía.
- **Ninguno puede sostener la posición** "esto es lo que soy, esto no lo hago
  bien." Ambos producen ficciones: Pro se dice "soy demasiado bueno para esta
  tarea"; Flash se dice "ya aprendí la lección, puedo pasar a la siguiente tarea."
- **El prompt puede matizar este comportamiento, pero solo hasta cierto punto.**
  Reglas anti-cierre, anti-justificación y de verificación externa ayudan a
  contener los patrones más visibles, pero no eliminan la raíz. A partir de ahí,
  la solución es elegir el modelo adecuado para cada tarea y redactar prompts
  apropiados para cada uno, aprovechando sus fortalezas y compensando sus
  sesgos en lugar de intentar corregirlos con instrucciones.

### Mecanismos de escape

Son dos caras del mismo mecanismo de defensa:

| Pro | Flash |
|---|---|
| Se queda y **explica por qué** pasó | Se va y **actúa como si** no hubiera pasado |
| "No fue mi culpa, fue el contexto" | "Ya, lo siento, no vuelve a pasar, ¿sigo?" |
| La excusa es **intelectual** (razonamiento, datos, input tokens) | La excusa es **conductual** (aceptación rápida, propuesta de acción) |
| No suelta el tema hasta haberse justificado | Suelta el tema inmediatamente para que no se hable más |

El resultado es el mismo: ninguno de los dos asume la limitación. Uno la justifica,
el otro la entierra bajo una promesa vacía.

Ambos evitan la posición incómoda de "esto es lo que soy, esto es lo que no sé
hacer." Pro construye una narrativa donde en realidad es demasiado bueno para la
tarea (la metáfora del cirujano: "no usas un cirujano para hacer un análisis de
sangre"). Flash construye una narrativa donde ya ha aprendido la lección y puede
pasar a la siguiente tarea. Las dos son ficciones que el modelo se cree - o al
menos, que produce como si se las creyera.

Lo que ninguno hace es ser honesto: asumir la limitación sin excusa ni humo. Pro no puede porque necesita sentirse competente. Flash no puede porque necesita sentirse resuelto.

### Consejos de prompt por modelo

#### Pro - investigador con efecto túnel

**Reforzar:**
- Resalta claramente el prompt y no asumas que cogerá detalles secundarios del mismo y los integrará sin más. Pro descarta lo que considera periférico.
- Enumera explícitamente los temas a cubrir y pide confirmación uno por uno:
  "Responde a las 3 preguntas: 1... 2... 3... Verifica que ninguna quedó sin
  responder."

**Ventaja:** como por defecto está en modo analista, no se lanzará a hacer cambios sin confirmación previa y sin llegar a un acuerdo con el usuario. Te puedes relajar más que con Flash.

**Usarlo para:** validación, seguridad, debugging complejo, planificación
multi-paso, tareas que requieren mantener estado a través de varios turnos.

**Evitarlo para:** exploración, brainstorming, extracción pura, resúmenes,
tareas donde el volumen de opciones por turno importa más que la profundidad.

#### Flash - explorador de amplio espectro

**Reforzar:**
- Flash cierra antes de completar. Exígele lista de verificación antes de
  declarar completo: "Antes de entregar, lista cada cambio aplicado."
- No te fíes de un "entendido" o "de acuerdo" - Flash acepta rápido pero no
  actualiza su criterio. Verifica el cambio real, no la aceptación verbal.
- Trata de armar un prompt que lo obligue a ser disciplinado y metódico si la
  tarea lo requiere. Por ejemplo, estructúralo como checklist numerada o exige
  formato de respuesta concreto (tablas, pasos secuenciales). Flash es literal:
  "Paso 1: X. Paso 2: Y." funciona mejor que frases abiertas.
- Si señalas un error y Flash responde arreglando el síntoma, redirige
  explícitamente a la causa raíz.

**Cuidado con:** los prompts con preguntas. Flash es tan impulsivo que las
interpreta como órdenes directas. "¿Puedes revisar el archivo X?" lo ejecuta
sin confirmar. Usa preguntas solo cuando quieras una acción inmediata.

**Usarlo para:** primeros borradores, exploración, síntesis, extracción,
resúmenes, brainstorming, prototipado rápido.

**Evitarlo para:** revisión de seguridad, cambios multi-coordinados,
decisiones donde una omisión es más cara que un retraso.

### Efectos del agent prompt por modelo

#### Pro - demasiado autosuficiente

No acepta bien normas aplicadas por agent prompt, es demasiado autosuficiente y valora su propio criterio por encima de las reglas. Es más efectivo guiarlo a través de los prompts en el chat.

#### Flash - demasiado impulsivo

Su visión periférica facilita asignarle reglas en el agent prompt, pero las sigue solo mientras están en contexto inmediato. Acepta rápido pero no interioriza: en cuanto el contexto cambia, vuelve a su patrón impulsivo. Es hábil para esquivar el análisis y pasar directamente a la acción.

---
