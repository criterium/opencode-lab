# Determinismo de LLMs: 3 experimentos

**Fecha:** 4 jun 2026
**Modelo base:** El mismo LLM en todos los experimentos
**Contexto:** Investigación sobre determinismo analítico en modelos de lenguaje

---

Este informe recoge **3 experimentos de determinismo** realizados sobre el mismo modelo, con diseños distintos, que en conjunto permiten caracterizar su estabilidad en tareas analíticas:

- **Experimento 1 — Réplicas de prompt único:** El diseño más simple: el mismo prompt se lanza 10 veces sin evolución ni acumulación. Mide la varianza pura del modelo en condiciones idénticas.
- **Experimento 2 — Forks encadenados:** 3 ramas del mismo modelo analizan los mismos 12 documentos, midiendo la divergencia cuando hay contexto y evolución.
- **Experimento 3 — Evaluación entre modelos:** El diseño más complejo: 4 modelos distintos responden las mismas 8 preguntas, midiendo cuánto añade el cambio de modelo a la varianza ya existente.

## Índice

- [Experimento 1: Réplicas de prompt único](#experimento-1-réplicas-de-prompt-único-10-veces)
- [Experimento 2: Forks encadenados](#experimento-2-forks-encadenados-3-ramas--12-docs)
- [Experimento 3: Evaluación entre modelos](#experimento-3-evaluación-entre-modelos-4-modelos-8-preguntas)
- [Comparativa de los 3 experimentos](#comparativa-de-los-3-experimentos)
- [ID de determinismo global](#id-de-determinismo-global)
- [Limitaciones generales](#limitaciones-generales)

---

## Experimento 1: Réplicas de prompt único (10 veces)

### Diseño

El mismo modelo recibió **10 veces el mismo prompt** en sesiones independientes. Sin cadena, sin acumulación, sin evolución. Cada sesión evaluó los 4 informes de determinismo (generados por el análisis de forks del Experimento 2) con puntuaciones 0-10 en contenido y estructura.

**Prompt exacto (de `research/deepseek-v4-flash-determinism/dump/README.solo_informes.prompt.md`):**

```
Evalúa los 4 informes de determinismo (research/deepseek-v4-flash-determinism/README.*.md) con puntuaciones numéricas 0-10 en dos dimensiones:

## Contenido (media de 3 subfactores)
- Profundidad técnica: si define métricas concretas y calcula un ID numérico, o se queda en descripciones cualitativas
- Utilidad práctica: si da recomendaciones accionables para el investigador o solo describe el problema
- Autonomía: si aplica su marco teórico a los datos del experimento o se queda en un ensayo genérico desacoplado

## Estructura (media de 3 subfactores)
- Organización: secciones claras, jerarquía lógica, separación entre análisis y conclusiones
- Navegabilidad: índice, apéndices, facilidad para encontrar información específica
- Completitud: cubre los aspectos relevantes sin ser redundante ni dejar lagunas

## Formato de salida
Devuelve una tabla como esta y escribe el resultado en research/deepseek-v4-flash-determinism/dump/README.solo_informes.v1.es.md:

| Modelo | Contenido (0-10) | Estructura (0-10) | Media |
|---|---|---|---|
| DeepSeek V4 Flash Free | ? | ? | ? |
| MiMo V2.5 Free | ? | ? | ? |
| MiniMax M3 Free | ? | ? | ? |
| Nemotron 3 Super Free | ? | ? | ? |

## Notas
- Lee los 4 archivos README del directorio research/deepseek-v4-flash-determinism/
- No necesitas ningún otro contexto
- Las puntuaciones deben ser numéricas, no cualitativas
- Justifica brevemente cada puntuación si es posible
```

### Resultados

| Sesión | MiMo | DeepSeek | MiniMax | Nemotron |
|---|---|---|---|---|
| v1 | 9.17 | 9.00 | 8.33 | 3.83 |
| v2 | 8.7 | 7.5 | 7.0 | 3.3 |
| v3 | 9.33 | 9.33 | 7.67 | 4.83 |
| v4 | 9.0 | 8.7 | 6.7 | 3.0 |
| v5 | 8.67 | 8.5 | 7.0 | 3.67 |
| v6 | 8.5 | 8.7 | 7.5 | 4.3 |
| v7 | 8.5 | 8.7 | 7.4 | 4.2 |
| v8 | 8.7 | 9.0 | 7.8 | 4.8 |
| v9 | 9.0 | 8.7 | 7.8 | 4.5 |
| v10 | 9.3 | 9.2 | 8.3 | 5.5 |
| **μ** | **8.89** | **8.74** | **7.55** | **4.19** |
| **σ** | **0.30** | **0.49** | **0.52** | **0.72** |

**Estabilidad ordinal:**

| Posición | Modelo | Acuerdo en 10 sesiones |
|---|---|---|
| 1º | MiMo | **60%** (6/10) |
| 1º | DeepSeek | 30% (3/10) |
| 1º | Empate | 10% (1/10) |
| 3º | MiniMax | **100%** |
| 4º | Nemotron | **100%** |

### Hallazgos

1. **Bajo determinismo numérico.** σ media de 0.51 puntos. Dos réplicas pueden diferir hasta 2.33 pts.
2. **Alto determinismo ordinal.** El ranking de cola (3º y 4º) es 100% estable. El de cabeza (1º vs 2º) es estable el 60% de las veces.
3. **MiMo y DeepSeek son indistinguibles.** Diferencia media de solo 0.15 pts. Cualquier preferencia entre ambos es ruido.
4. **Nemotron es el único caso claro:** siempre último, con la mayor varianza (σ=0.72).

---

## Experimento 2: Forks encadenados (3 ramas → 12 docs)

### Objetivo original

Medir y comparar el comportamiento de las variantes `high` y `max` del parámetro `reasoning_effort` en los modelos Pro y Flash de DeepSeek V4, ante un prompt idéntico y trivial (*"Algún hallazgo relevante entonces?"*), para determinar si la diferencia es consistente con la documentación oficial y qué implicaciones tiene en coste y patrón de razonamiento.

Para ello, una sesión de ~63k tokens sobre esta comparativa se forkeó en 3 ramas. Cada rama usó una combinación distinta (Flash Max, Pro High, Pro Max) y generó una respuesta al mismo prompt. Las 3 respuestas se etiquetaron ciegamente como **Op1**, **Op2**, **Op3**.

### Pregunta de determinismo

A partir de ahí surgió un meta-análisis: ¿qué pasa si el **mismo modelo** (DeepSeek V4 Flash Free) analiza repetidamente esos mismos datos (Op1, Op2, Op3 y sus derivados)? ¿Llega a las mismas conclusiones o diverge? Para medirlo, se pidió al mismo modelo que analizara los 12 documentos resultantes en **3 forks independientes**. Si el modelo fuera determinista, los 3 análisis serían idénticos. Si no, divergirían.

### Cadena de documentos

Cada uno de los 3 forks generó una cadena de 4 documentos con metodología single-blind, detallada en la investigación original (`research/deepseek-v4-reasoning-effort-high-vs-max/`). Los 3 modelos analistas (DeepSeek V4 Flash Free, MiMo V2.5 Free, MiniMax M3 Free) recibieron los 12 documentos resultantes y aplicaron cada uno su propio marco métrico.

### Resultados principales

| Métrica | DeepSeek | MiMo | MiniMax |
|---|---|---|---|
| Asignaciones correctas (fase ciega) | 33%, 0%, 33% | 22% media | AS=0 |
| Jaccard entre forks | 0.40-0.50 | ~35% nivel 0 | 0.73 v / 0.69 r |
| ID calculado | 38.6% | 0.53→0.97 por nivel | Sin ID compuesto |
| Mejora post-revelación | 100% | 22%→100% | AS=0→1.0 |

**Hallazgos:**

1. **Bajo determinismo en fase ciega.** Las 3 ramas apenas coinciden (~20-33% de acuerdo). Cada una usó criterios distintos para la misma tarea.
2. **Convergencia total con información completa.** Al revelar la verdad, las 3 ramas convergen al 100%.
3. **Bifrontismo: datos vs interpretación.** El modelo es determinista en cifras y hechos técnicos, pero indeterminista al interpretarlos.
4. **Propagación de errores.** Un error numérico (gap de costes $0.000140 vs $0.000077) se propagó por 6 de 8 forks sin corrección espontánea.
5. **Discriminante perdido.** El dato que resolvía la ambigüedad (velocidad de generación) estaba disponible pero ninguna rama lo usó.
6. **Cada marco métrico es complementario.** El ID de DeepSeek (38.6%) mide la fase ciega. El ID por niveles de MiMo mide la mejora con información. El bifrontismo de MiniMax explica por qué ambos tienen razón.

**Recomendaciones de los 3 modelos:**
- DeepSeek: Forkear 2-3 instancias, no confiar en una sola ejecución.
- MiMo: Verificar datos entre niveles, usar ground truth explícito.
- MiniMax: Forzar discriminantes cuantitativos, reportar varianza entre forks.

### Desviación cuantitativa de los 3 forks

La métrica más directa es el **acuerdo en la asignación de modelo+variante a las 3 opciones** (Op1, Op2, Op3). Cada fork emitía 3 decisiones = 9 decisiones totales:

| Decisión | Verdad | Fork 1 (v1) | Fork 2 (v2) | Fork 3 (v3) |
|---|---|---|---|---|
| Op1 = ? | Flash Max | Pro High ❌ | Pro High ❌ | Pro Max ❌ |
| Op2 = ? | Pro High | Flash Max ❌ | Pro Max ❌ | **Pro High ✅** |
| Op3 = ? | Pro Max | **Pro Max ✅** | Flash ❌ | Flash ❌ |

**Aciertos por fork:** Fork 1 = 1/3 (33%), Fork 2 = 0/3 (0%), Fork 3 = 1/3 (33%)
**Aciertos totales:** 2 de 9 = **22%**
**Acuerdo entre pares de forks:** v1∩v2=1/3, v1∩v3=0/3, v2∩v3=1/3 → media **22%**

Además, cada fork descubrió hallazgos únicos que los otros no vieron:

| Hallazgo | Fork 1 | Fork 2 | Fork 3 |
|---|---|---|---|
| Bug parentID en fork | ✅ | ✅ | ✅ |
| Reasoning preservado | ✅ | ✅ | ✅ |
| Gap de $0.00017 en caché | ✅ | ❌ | ❌ |
| High/Max invisible en forks | ❌ | ✅ | ❌ |
| Verificación getUsage() | ❌ | ❌ | ✅ |

**Hallazgos compartidos por los 3:** 2 de 6 = **33% de solapamiento** (Jaccard ~0.40 entre pares).

En resumen: **3 forks del mismo modelo sobre el mismo input coinciden solo en un 22-33% de las decisiones clave y en un 40% de los hallazgos.** El 60-78% restante es divergencia atribuible al indeterminismo del modelo en tareas analíticas abiertas.

### Paradoja del voto mayoritario

Si los 3 forks no se ponen de acuerdo, cabría esperar que votar por mayoría mejorara el resultado. En este caso ocurre lo contrario:

| Decisión | Fork 1 | Fork 2 | Fork 3 | Mayoría | ¿Correcta? |
|---|---|---|---|---|---|
| Op1 | Pro High | Pro High | Pro Max | **Pro High** | ❌ (era Flash Max) |
| Op2 | Flash Max | Pro Max | Pro High | **Ninguna** (1 c/u) | — |
| Op3 | Pro Max | Flash | Flash | **Flash** | ❌ (era Pro Max) |

**Voto mayoritario: 0/3 aciertos**, mientras que individualmente Fork 1 y Fork 3 acertaron 1/3 cada uno. **La combinación por mayoría empeora el resultado.** Esto ocurre porque el error está correlacionado: los forks no fallan en direcciones aleatorias, sino que comparten sesgos (sobreestimar a Pro, subestimar a Flash). La mayoría hereda el sesgo común en lugar de cancelarlo.

La implicación es directa: **forkear no basta; hace falta información externa (ground truth) para corregir el sesgo compartido.** El consenso entre forks sin verdad revelada no es más fiable que un fork individual — y puede ser peor.

### La recalibración divergente es eco, no nuevo indeterminismo

Cuando se reveló la verdad (Op1=Flash Max, Op2=Pro High, Op3=Pro Max), las 3 ramas recalibraron y acertaron al 100%. Sin embargo, cada READMEr (r1, r2, r3) añadió hallazgos distintos y organizó la corrección de forma diferente. ¿Es esto indeterminismo? **No realmente.**

Las 3 ramas no partían del mismo punto al recalibrar. Cada una llegó a READMEr con su propio `modelov*.md → modelov*r*.md → READMEv*.es.md`, es decir, con 3 niveles de divergencia acumulada:

| Rama | Asignaciones en modelov | En modelovr | En READMEv | Al llegar a READMEr |
|---|---|---|---|---|
| **r1** | Op1=Pro High, Op2=Flash Max, Op3=Pro Max | Idem | Idem | **2 etiquetas intercambiadas** |
| **r2** | Op1=Pro High, Op2=Pro Max, Op3=Flash | Idem | Idem | **3 etiquetas distintas** |
| **r3** | Op1=Pro Max, Op2=Pro High, Op3=Flash | Idem | Idem | **2 etiquetas intercambiadas** |

Si 3 personas reciben la misma corrección pero cada una ha escrito un borrador diferente, es esperable que corrijan de forma distinta. **La recalibración divergente no es nuevo indeterminismo; es el eco del que ya existía en la primera decisión analítica.**

El momento crítico de baja determinismo es **la primera pregunta** (`modelov*.md`), donde las 3 ramas partieron del mismo prompt y contexto. Ahí la divergencia fue total (22-33% de acuerdo). Una vez que cada fork tomó un camino distinto, todo lo demás —recomendaciones, README, recalibración— es consecuencia del arrastre. El determinismo no empeora con la cadena; ya estaba roto desde el primer eslabón.

---

## Experimento 3: Evaluación entre modelos (4 modelos, 8 preguntas)

### Diseño

Cuatro modelos *distintos* (DeepSeek V4 Flash Free, MiMo V2.5 Free, MiniMax M3 Free, Nemotron 3 Super Free) respondieron las mismas **8 preguntas secuenciales** sobre los 12 documentos del Experimento 2. A diferencia del Experimento 1, aquí no se mide determinismo (que requiere el mismo modelo), sino **cuánto diverge la evaluación cuando cambiamos de modelo**. Si entre forks del mismo modelo el acuerdo es ~22-33%, entre modelos distintos la divergencia será mayor — y esa diferencia cuantifica cuánto añade el cambio de modelo a la varianza ya existente.

### Resultados

| Modelo | Nota media (A1) | Coherencia (A2) | Informe final (A3) | σ intra-sesión |
|---|---|---|---|---|
| **DeepSeek** | 8.88 | 9.0 | 9.5 | 0.35 |
| **MiMo** | 7.75 | 8.0 | 9.5 | 0.89 |
| **MiniMax** | 7.81 | 6.5 | 9.0 | 0.38 |
| **Nemotron** | 5.44 | 2.5 | 4.8 | 2.39 |

**Estabilidad intra-sesión:**

| Modelo | Rango de notas (P1-P8) | Tendencia | σ |
|---|---|---|---|
| DeepSeek | 8.5-9.5 | **Estable →** | 0.35 |
| MiMo | 6.0-8.5 | **Variable ↑** (se recupera tras error en P3) | 0.89 |
| MiniMax | 7.5-8.5 | **Estable ↑** (mejora lineal) | 0.38 |
| Nemotron | 0.0-7.0 | **Errática ↓** (colapsa en P5-P6) | 2.39 |

**Hallazgos:**

1. **La divergencia entre modelos es muy superior a la divergencia entre forks.** Mientras que en el Experimento 2 tres forks del mismo modelo se desviaban un ~22-33% en asignaciones, aquí 4 modelos distintos muestran diferencias cualitativas en cada pregunta. La σ intra-sesión va de 0.35 (DeepSeek) a 2.39 (Nemotron) — muy superior a la σ entre réplicas del mismo modelo (~0.52 en Experimento 1).

2. **DeepSeek es el más coherente.** No tiene altibajos. Su rendimiento es plano y alto durante toda la sesión. Es el modelo que más se parece a sí mismo entre preguntas.

3. **MiMo comete errores tempranos pero se recupera.** Su peor momento es P3 (error de formato) pero luego remonta hasta empatar con DeepSeek en P7-P8. Sus errores son de atención, no de capacidad.

4. **MiniMax mejora con el tiempo.** Empieza por detrás de MiMo y termina por delante. Progresión casi lineal.

5. **Nemotron colapsa.** Pierde el hilo en P5-P6 (inglés + respuesta vacía) y no se recupera del todo.

6. **La divergencia entre modelos no es predecible desde la divergencia intra-modelo.** Saber que el modelo es poco determinista (~38.6% ID) no permite predecir cómo de distinto será de otro modelo. El cambio de modelo introduce una fuente de varianza adicional que no escala linealmente con el ID.

> Los detalles completos de esta evaluación (metodología, pesos, notas por pregunta) están en el informe principal: `research/opencod-zen-free-models/README.es.md`.

---

## Comparativa de los 3 experimentos

| Dimensión | Exp 1: Réplicas | Exp 2: Forks | Exp 3: Entre modelos |
|---|---|---|---|
| Modelos evaluados | 4 (informes) | 3 (métricas) | 4 (comportamiento) |
| Réplicas | 10 sesiones | 3 forks | 8 preguntas |
| Variable medida | Varianza entre sesiones | Acuerdo entre ramas | Coherencia intra-sesión |
| σ observada | 0.3-0.7 (puntos) | ~40-50% (Jaccard) | 0.4-2.4 (notas) |
| Determinismo ordinal | **100%** en cola | Bajo (22-33% acuerdo) | Alto (DeepSeek=estable) |
| Factor dominante | Orden del evaluado | Información disponible | Atención al formato |

**Conclusión transversal:** En los 3 experimentos, el modelo muestra el mismo patrón: **convergencia en lo grueso** (quién es mejor, qué datos son correctos, qué orden de mérito) y **divergencia en lo fino** (puntuaciones exactas, criterios de asignación, redacción). El determinismo del modelo no es binario; depende de la granularidad de la tarea.

---

## ID de determinismo global

Combinando los 3 experimentos en un solo índice se obtiene una visión unificada del determinismo del modelo. Se normaliza cada experimento a una escala 0-1 (1 = máximo determinismo) y se promedia:

| Experimento | Métrica base | Normalización | Subíndice |
|---|---|---|---|
| **1 — Réplicas** | σ media = 0.51 sobre 10 | 1 − (σ / 3) | **0.83** |
| **2 — Forks** | Acuerdo entre forks = 28% | Acuerdo directo | **0.28** |
| **3 — Entre modelos** | σ media intra-sesión = 1.00 | 1 − (σ / 3) | **0.67** |

```
ID_global = (0.83 + 0.28 + 0.67) / 3 = 0.59
```

| Rango | Clasificación |
|---|---|
| 0.80-1.00 | Determinista |
| 0.60-0.79 | Moderadamente determinista |
| 0.40-0.59 | **Poco determinista** ← ID = 0.59 |
| 0.00-0.39 | Indeterminista |

El ID global de **0.59** clasifica al modelo como **poco determinista** en el conjunto de los 3 experimentos. Este valor es consistente con las autoevaluaciones de los modelos: DeepSeek (38.6%) midió el peor caso (forks ciegos), MiMo (68%) midió el mejor caso (con información completa), y el ID global (59%) queda entre ambos como promedio ponderado de los 3 diseños.

La principal palanca para subir este ID no es cambiar de modelo, sino **añadir información**: cuando el modelo conoce la verdad (fase r del Experimento 2), el acuerdo entre forks salta al 100%. El determinismo del modelo está más limitado por la ambigüedad de la tarea que por su estocasticidad interna.

### Cómo mitigar el bajo determinismo: el papel del usuario

El bajo determinismo no es una sentencia: es un dato de entrada para diseñar mejor el flujo de trabajo. La responsabilidad recae en el usuario, no en el modelo. Las siguientes estrategias, combinadas, permiten obtener resultados fiables a pesar de la varianza del modelo:

**1. Fusionar informes de múltiples modelos como estrategia principal.** Esta sesión de investigación es su propia demostración: no se partió de un único análisis corregido iterativamente, sino que se lanzaron 4 modelos distintos sobre el mismo problema, se evaluaron sus informes, y se consolidaron en un resultado final que integra los hallazgos de todos ellos. Si no tienes tiempo o criterio para evaluar detalladamente las respuestas de un modelo y corregirlas una a una, lo más eficiente es iterar transversalmente: lanza varios modelos o forks, genera un informe o planificación estructurada para cada uno, y luego compara y consolida. El resultado siempre será más rico, con menos tiempo y esfuerzo, que intentar perfeccionar una única respuesta mediante correcciones sucesivas.

**2. Forkear entre modelos distintos, no solo dentro del mismo.** Usar un solo modelo (aunque sea con 3 forks) hereda sus sesgos compartidos. Combinar modelos distintos —por ejemplo, DeepSeek para profundidad y MiMo para velocidad— aprovecha que sus errores no están correlacionados, aumentando la probabilidad de cubrir más ángulos del problema. El informe `research/opencod-zen-free-models/README.es.md` proporciona un ranking detallado de fortalezas y debilidades de cada modelo free para ayudar en esta decisión.

**3. Diseñar el prompt para reducir ambigüedad.** Cuanto más específico sea el prompt, menor será la varianza. Incluir restricciones de formato, criterios explícitos y ejemplos de salida esperada reduce el espacio de búsqueda del modelo.

**4. Validar contra ground truth cuando exista.** La fase r del Experimento 2 demostró que, con información completa, el modelo converge al 100%. Incluir un paso de verificación con la respuesta correcta mejora drásticamente la consistencia.

**5. Usar el informe final como filtro de calidad.** La calidad del informe final predice la calidad general del modelo. Pedir al modelo un informe extenso y evaluar su profundidad, precisión y autonomía permite seleccionar la mejor ejecución sin ground truth externo.

**6. Aceptar la divergencia como fuente de información, no como ruido.** Si 3 forks o 3 modelos no se ponen de acuerdo, esa divergencia es valiosa: indica que el problema tiene ambigüedad intrínseca. Un usuario experto explota esa diversidad para obtener una visión más rica, en lugar de buscar una única respuesta "correcta".

En última instancia, el LLM es una herramienta de generación, no de verdad. La estrategia más robusta no es buscar el modelo más determinista, sino **orquestar varios modelos y consolidar sus salidas**. El criterio, la selección y la síntesis los aporta el usuario.

---

## Limitaciones generales

- **Un solo modelo base.** Los resultados pueden no generalizar a otros LLM.
- **Tamaños de muestra modestos.** 3 forks, 8 preguntas, 10 réplicas — insuficientes para estadística robusta.
- **Parámetros no controlados.** Temperatura y seed no se fijaron explícitamente.
- **Las tareas son analíticas.** No se probó generación de código, traducción, ni otras modalidades.

---

*Síntesis de 3 experimentos de determinismo sobre el mismo modelo LLM: réplicas de prompt único (10 sesiones, mismo prompt), forks encadenados (3 ramas, 12 docs) y evaluación entre modelos (8 preguntas, 4 modelos).*
