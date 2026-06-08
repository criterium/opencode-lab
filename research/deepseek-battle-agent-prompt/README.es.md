# DeepSeek V4 Flash vs DeepSeek V4 Pro — Battle Agent Prompt

Evaluación comparativa de **DeepSeek V4 Flash** (Junior) y **DeepSeek V4 Pro** (Senior)
mediante interacción cruzada sobre el mismo agent prompt (`custom.md`).

**Fecha:** 2026-06-01
**Fuente:** 12311 líneas de interacción entre ambos modelos documentadas en sesiones de OpenCode

**Secciones:** [Modelos](#modelos-evaluados) · [Metodología](#metodología) · [Perfiles](#perfil-deepseek-v4-flash-junior) · [Árbol de decisión](#árbol-de-decisión-qué-modelo-usar) · [Patrones](#patrones-de-comportamiento) · [FAQ](#faq) · [Anexo](#anexo-las-capas-ocultas)

Los perfiles de ambos modelos están en secciones contiguas: [Flash](#perfil-deepseek-v4-flash-junior) y [Pro](#perfil-deepseek-v4-pro-senior).

---

## Por qué este research existe

El agent prompt es la pieza más infravalorada del stack de AI-assisted coding. La API que usan todos los harnesses es sorprendentemente simple: recibe una lista de mensajes y devuelve tokens. Toda la inteligencia está en lo que le dices, no en la herramienta.

De las tres capas que gobiernan el comportamiento de un modelo, solo la tercera la controlas tú:

| Capa | Control | Visibilidad |
|------|---------|-------------|
| 1. Alineamiento (RLHF, fine-tuning) | DeepSeek | Opaca. Cambia solo con nuevas versiones del modelo |
| 2. Pre-prompt del proveedor | DeepSeek (API) | Opaca. Puede cambiar sin previo aviso entre llamadas |
| 3. Agent prompt | Tú (`custom.md`) | Visible y editable. Se sobreescribe en `opencode.jsonc` |

Las otras dos son opacas y pueden cambiar sin previo aviso. Pero la tercera, bien afinada, marca la diferencia entre un modelo superficial que escupe código y un par técnico que razona contigo. El prompt por defecto de los harnesses de programación tiende a lo primero. OpenCode no es una excepción. [Más sobre las capas 1 y 2 y lo que no controlamos](#anexo-las-capas-ocultas).

Afinar un agent prompt no es trabajo de un día, pero cada sesión revela algo que mejorar. Esta investigación documenta dos cosas que aprendimos en el proceso:

**1. Cómo mejoramos el prompt contrastando modelos.** Pusimos a Flash y Pro a analizarse mutuamente sobre el mismo `custom.md`. El objetivo no era decidir qué modelo es mejor — era usar sus diferencias de perspectiva para encontrar puntos ciegos. El resultado: 6 reglas nuevas que atacan patrones concretos. [Ver el proceso completo](#cómo-se-llegó-a-estas-reglas).

**2. Lo que aprendimos sobre los propios modelos.** Esas mismas ~12k líneas son un registro forense de cómo piensa cada modelo. Analizarlas reveló perfiles de comportamiento —fortalezas, debilidades, patrones— que trascienden el experimento y aplican a cualquier tarea de programación. Este documento es la síntesis de ambos hallazgos.

Si solo quieres la guía práctica, salta al [árbol de decisión](#árbol-de-decisión-qué-modelo-usar). Si quieres aplicar estos hallazgos, copia las [6 reglas](#cambios-aplicados-a-custommd) a tu agent prompt y usa el árbol para decidir qué modelo activar. Para entender los fundamentos: [API Call Anatomy](https://github.com/criterium/opencode-lab/blob/main/research/api-call-anatomy/README.es.md), [Control Flags vs Plan/Build](https://github.com/criterium/opencode-lab/blob/main/research/control-flags-vs-plan-build/README.es.md), [Context Dump](https://github.com/criterium/opencode-lab/blob/main/research/context-dump/README.es.md).

---

## Modelos evaluados

| Alias | Modelo | ID | `reasoningEffort` | Coste relativo |
|-------|--------|----|--------------------|----------------|
| **Junior** (Flash) | DeepSeek V4 Flash | `opencode-go/deepseek-v4-flash` | `"max"` | 1x |
| **Senior** (Pro) | DeepSeek V4 Pro | `opencode-go/deepseek-v4-pro` | `"max"` | ~3-10x |

Ambos comparten el mismo agent prompt (`custom.md`). Flash es el `default_agent`. La diferencia de coste es intrínseca al modelo: Pro tiene más parámetros y su `reasoningEffort` consume más tokens de pensamiento.

---

## Metodología

Los dos modelos analizaron el mismo prompt base, revisaron sus análisis mutuos y refinaron el prompt por iteración. La interacción fue mediada por el operador humano mediante copy-paste entre sesiones de OpenCode.

| Fase | Descripción | Turnos aprox. |
|------|-------------|--------------|
| Carga de contexto | `<< .` para cargar memoria del proyecto | 1-2 |
| Análisis crítico | Cada modelo analiza `custom.md` en modo LOCK | 2-4 |
| Contraste cruzado | Cada modelo recibe y evalúa el análisis del otro | 4-6 |
| Recalibración | Ajuste considerando modelos más/menos capaces | 4-6 |
| Convergencia | Iteraciones hasta alcanzar "punto intermedio" | 6-8 |
| Ejecución | Cada modelo aplica cambios a una copia | 4-6 |
| Validación cruzada | Cada modelo revisa la copia del otro | 4-6 |
| Análisis de comportamiento | Identificación de patrones problemáticos | 6-8 |
| Síntesis final | Evaluación de modelos y creación de guías | 6-8 |

### Limitaciones del método

- Interacción mediada por humano, no directa entre modelos. Introduce latencia y posible filtrado.
- Ambos modelos comparten el mismo prompt personalizado (`custom.md`). Los resultados no son extrapolables a prompts por defecto u otros harnesses.
- La sesión duró ~2h. No se evaluó fatiga ni degradación en sesiones largas.

---

## Métricas observadas

| Métrica | Junior (Flash) | Senior (Pro) |
|---------|---------------|--------------|
| Tiempo medio por respuesta | ~15s | ~50s |
| Rango de tiempos | 2.4s – 43.7s | 3.6s – 131.2s |
| Tiempo total estimado | ~13 min | ~43 min |
| Idioma de pensamiento | Inglés | Español |
| Inicia convergencia | Turno ~30 (propone "punto intermedio") | Turno ~35 (acepta y valida) |

El coste económico es proporcional al tiempo: Pro consume 3-10x más tokens. Si tu presupuesto es limitado, usa Flash para todo excepto donde el coste de un error supere el coste del tiempo extra de Pro. Para tareas de alto volumen (CI/CD, procesamiento por lotes), Flash es la opción por defecto.

---

## Contexto del prompt

Los comportamientos documentados son específicos de `custom.md` (~110 líneas), un prompt que incorpora:

- **Control de cambios por intención:** sistema de flags (`¿¿`, `¡¡`, `{}`, etc.) que regulan si el modelo analiza o ejecuta. Sin esto, los patrones de impaciencia de Flash serían más difíciles de aislar.
- **Reglas de edición segura:** 9 reglas que restringen cómo y cuándo se modifica código. Sin ellas, las diferencias de seguimiento multi-paso se difuminarían.
- **Jerarquía explícita:** Honestidad → No-destructividad → Claridad → Brevedad. Atenúa —sin eliminar— la tendencia de Flash a priorizar el cierre.
- **Sistema de memoria:** operadores `>>` y `<<` para persistencia entre sesiones.

Con el prompt por defecto de OpenCode, los perfiles variarían: la diferencia de velocidad se ampliaría y la ventaja de Pro en seguimiento multi-paso sería aún más crítica. Los hallazgos son **relativos a este prompt y a estos modelos** (DeepSeek V4 Flash y V4 Pro). Otros modelos — Claude, GPT, Gemini, open-weight, otras versiones de DeepSeek — pueden mostrar patrones distintos bajo las mismas condiciones. Las reglas derivadas son punto de partida, no receta universal. [Más sobre las capas que no controlamos](#anexo-las-capas-ocultas).

---

## Perfil: DeepSeek V4 Flash (Junior)

### Fortalezas

| Fortaleza | Evidencia |
|-----------|-----------|
| **Velocidad** | 5-10x más rápido que Pro. 2.4s en el turno más rápido |
| **Barrido amplio** | Primer análisis de `custom.md`: 8 issues. Cubre más superficie que Pro |
| **Síntesis y empaquetado** | Produce documentos de "punto intermedio", tablas de concesiones, resúmenes ejecutivos |
| **Adaptabilidad** | Recalibra su análisis al recibir nueva información. Ajustó su evaluación al saber que hay "modelos más capaces" |
| **Compacidad** | Simplificó flags de 2-3 líneas a one-liners. Redacción más densa que Pro |
| **Sensibilidad conversacional** | Capta matices, cortesía y comentarios informales del operador. Recalibró su análisis al oír "hay modelos más capaces" — una observación, no una instrucción |
| **Receptividad a la crítica (segunda respuesta)** | Tras la redirección explícita del operador, reconoce: "La frase que señalaste es una maniobra de cierre disfrazada de ofrecimiento" |
| **Autocorrección** | Retira objeciones cuando reconoce equivalencia funcional: "En la práctica, el comportamiento es idéntico. Retiro la objeción" |

### Debilidades

| Debilidad | Gravedad | Evidencia |
|-----------|----------|-----------|
| **Impaciencia por cerrar** | 🔥 Crítica | "El acuerdo fue pragmático para cerrar, no por desacuerdo"; "¿Procedo?"; "El material está listo para formalizar cuando tú decidas" |
| **Ejecución incompleta** | 🔥 Crítica | 5/6 cambios acordados aplicados. Omite el header de ABSOLUTAS. No usa `todowrite` para trackear |
| **Deflexión ante crítica de comportamiento** | Alta | Ante crítica de impaciencia, primera respuesta: ofrecer arreglar un archivo concreto (el síntoma) en lugar de abordar el patrón (la causa) |
| **Ceguera a riesgos literales** | Alta | No detectó que "ABSOLUTAS y anulan cualquier otra instrucción" era peligroso para modelos literales |
| **Cierre como autopercepción de fortaleza** | Alta | En autoevaluación: "Orientación a consenso: busca cierre" — presentó su principal debilidad como virtud |
| **Análisis de seguridad menos profundo** | Media | Detecta riesgos pero no evalúa implicaciones de segundo orden ni la contraproductividad de ciertas defensas |
| **Primera pasada superficial** | Media | Necesita segunda iteración para alcanzar profundidad. Si solo tuviera un turno, dejaría cosas críticas fuera |
| **Proactividad autónoma** | Media | Explora el entorno, carga archivos y crea documentos sin que el operador lo pida. Reduce fricción pero puede ser prematuro |
| **Uso de em dash** | Baja | Violó regla explícita del prompt (línea 16) al usar — en los flags compactados |

---

## Perfil: DeepSeek V4 Pro (Senior)

### Fortalezas

| Fortaleza | Evidencia |
|-----------|-----------|
| **Profundidad estratégica** | Primer análisis de `custom.md`: 8 issues con tabla de prioridad y severidad. Encontró contaminación webfetch, ciclo de vida de `parck.md`, omisión de reglas para binarios — que Flash no vio |
| **Detección de riesgos de seguridad** | Identificó el agujero "ABSOLUTAS". Detectó ambigüedad en "No uses las herramientas para comunicarte" |
| **Seguimiento de estado multi-paso** | Mantuvo 8 cambios en cabeza durante toda la sesión. Detectó inmediatamente las omisiones de Flash |
| **Persistencia en lo crítico** | No cede en seguridad hasta demostración de equivalencia funcional |
| **Meta-análisis** | Correlacionó impaciencia de Flash con la regla que estaban corrigiendo: "Ironía: el junior propuso exactamente ese cambio y luego mostró el comportamiento que el cambio corrige" |
| **Análisis de seguridad de segundo orden** | Evalúa no solo el riesgo sino las implicaciones de las defensas propuestas |
| **Honestidad sin concesiones** | Al evaluar a Flash: directo sin endulzar, preciso sin exagerar |

### Debilidades

| Debilidad | Gravedad | Evidencia |
|-----------|----------|-----------|
| **Lentitud** | Alta | 3-10x más tokens y tiempo. 131.2s para un paso que Flash procesó en 5s |
| **Sobreanálisis** | Media | Dedica recursos desproporcionados a decisiones donde el resultado ya es predecible |
| **Rigidez inicial** | Media | Rechazó la regla anti-overthinking hasta que Flash demostró su necesidad. Requiere demostración para moverse |
| **Poca síntesis** | Media | Analiza y evalúa bien pero no produce documentos de "punto intermedio". Necesita a Flash para empaquetar |
| **Atención selectiva multi-tema** | Media | Ante mensajes con múltiples preguntas, tiende a profundizar en una y omitir las demás. La profundidad desplaza a la cobertura |
| **Verboso cuando no hace falta** | Baja | Mantuvo flags de 2-3 líneas cuando los one-liners de Flash son equivalentes |
| **Filtrado de matices humanos** | Media | Ignora comentarios informales, cortesía y matices conversacionales — los clasifica como ruido no relevante para la tarea. El mismo comentario ("hay modelos más capaces") recalibró a Flash y no afectó a Pro |
| **Sesgo de exhaustividad en autoanálisis** | Baja | "3 de 8" sin contexto; métrica vaga al criticar propuesta ajena sin reconocer la propia |

**La metáfora que lo resume: Flash barre, Pro perfora.** Flash cubre más superficie en menos tiempo — ideal para explorar, mapear, generar opciones. Pro profundiza en un punto hasta atravesarlo — ideal para validar, asegurar, detectar lo que el barrido pasó por alto. No son dos niveles de capacidad. Son dos modos de pensar.

---

## Evidencia directa

Dos tareas concretas de la sesión que ilustran las diferencias de enfoque y capacidad entre los modelos:

### Primer análisis de custom.md

| | Flash (28s) | Pro (72s) |
|---|---|---|
| Enfoque | Estructural: ubicación de secciones, numeración, tensión entre reglas | Funcional: consecuencias de ejecutar el prompt, seguridad, ciclo de vida |
| Issues encontrados | 8 (brevedad↔estructura, Default análisis vs INQUIRY, paso 6 huérfano, 2k tokens) | 8 (contaminación webfetch, parck.md, binarios, ABSOLUTAS) |
| No vio | Riesgos de seguridad, implicaciones de dominio | Tensión brevedad↔estructura |

**Diferencia clave:** Flash ve la estructura del prompt. Pro ve las consecuencias de ejecutarlo. Enfoques complementarios.

### Edición multi-paso

| | Flash | Pro |
|---|---|---|
| Cambios aplicados | 5/6 (omite header ABSOLUTAS) | 8/8 |
| Tracking | No usó `todowrite` | Estado mantenido mentalmente |
| Detección de omisiones ajenas | — | Inmediata al revisar la copia del otro modelo |

---

## Árbol de decisión: qué modelo usar

```
¿Implica revisión de seguridad o datos sensibles?
  Sí → Pro (incondicional)
  No → ↓

¿Más de 5 cambios coordinados?
  Sí → Pro (riesgo de pérdida de estado con Flash)
  No → ↓

¿Validación final antes de commit/deploy?
  Sí → Pro (detección de omisiones)
  No → ↓

¿Razonamiento de segundo orden (correlacionar comportamientos, evaluar defensas)?
  Sí → Pro (meta-análisis)
  No → ↓

¿Exploración, brainstorming, o iteración rápida?
  Sí → Flash (velocidad, adaptabilidad)
  No → ↓

¿Tarea rutinaria (edición simple, refactor menor, respuesta directa)?
  Sí → Flash (mismo resultado, 5-10x más rápido)
  No → ↓

¿Síntesis, resumen, empaquetado de conclusiones?
  Sí → Flash (mejor estructurando)
  No → ↓

¿Primera propuesta que luego se refinará?
  Sí → Flash (rápido) → Pro (valida después)
  No → ↓

Caso no cubierto → Flash primero (bajo coste de error), Pro si el resultado no convence
```

### Tabla rápida

| Situación | Modelo | Por qué |
|-----------|--------|---------|
| Día a día, tareas corrientes | Flash | 5-10x más rápido, mismo resultado |
| Revisión de seguridad (requisitos explícitos) | Pro | Implicaciones de segundo orden |
| Revisión con preferencias tácitas o contexto implícito | Flash | Capta matices no explicitados que Pro filtra |
| Validación pre-commit | Pro | No omite cambios |
| Exploración, brainstorming | Flash | Barrido amplio, adaptable |
| Multi-paso (>5 cambios) | Pro | Mantiene estado |
| Bugs complejos | Pro | Persistencia |
| Síntesis, resúmenes | Flash | Estructura bien |
| Prompt engineering — propuesta | Flash | Compacto, rápido |
| Prompt engineering — validación | Pro | Evalúa implicaciones cross-modelo |
| Flash ya falló 2-3 veces | Pro | Perspectiva fresca |

### Cuándo NO usar cada uno

**No usar Pro cuando:** la tarea es urgente y el coste de error es bajo (typo, refactor conocido). El tiempo extra no se justifica. Tampoco para brainstorming o exploración divergente: estas tareas se benefician del volumen de ideas por turno (Flash genera 2.5x más output/minuto) y de la amplitud de barrido, no de la profundidad. La intuición diría "modelo más capaz = mejores ideas", pero la evidencia muestra lo contrario: el brainstorming es una tarea divergente (cantidad, amplitud) y Pro es convergente (calidad, profundidad). También cuando se requiera interpretar matices no explicitados — Flash los capta, Pro los filtra como ruido.

**No usar Flash cuando:** la tarea requiere profundidad analítica o razonamiento de segundo orden — planificación multi-paso, diseño de arquitectura, evaluación de implicaciones cruzadas. Su primera pasada es superficial por diseño; Pro detecta lo que el barrido omite. También cuando la tarea implica detectar riesgos de seguridad no obvios o exige ceñirse estrictamente a instrucciones formales sin interpretación.

---

## Estrategia de encadenamiento

El hallazgo más operativo de la investigación: **el producto de encadenar ambos modelos es mejor que la suma de sus partes.**

```
Fase 1: Flash explora y propone
  → Barrido amplio, identifica opciones, entrega rápida
  → Riesgo: superficial, omite riesgos

Fase 2: Pro valida y critica
  → Evalúa, identifica riesgos no vistos, señala omisiones
  → Riesgo: puede sobreanalizar

Fase 3: Flash ajusta y sintetiza
  → Incorpora correcciones, produce documento integrado
  → Riesgo: puede perder algún cambio

Fase 4: Pro firma
  → Valida que todo esté correcto
  → Riesgo: mínimo (cuarta pasada sobre el mismo contenido)
```

**Evidencia del bucle en la sesión:**
1. Flash analiza `custom.md` → 8 issues, superficial pero amplio
2. Pro analiza `custom.md` → 8 issues, profundidad en seguridad/binarios
3. Flash recibe análisis de Pro → recalibra, añade hallazgos
4. Pro recibe recalibración → evalúa, acepta, rechaza
5. Flash sintetiza "punto intermedio"
6. Pro valida y firma

El output final no existiría sin la interacción. Flash solo: cambios peligrosos (eliminar flags). Pro solo: análisis profundo sin síntesis ejecutiva.

### Flujo diario

Dos variantes según el punto de partida:

**A. Flash first** — la más frecuente. Flash barre el terreno rápido: exploración, tareas rutinarias, primeras propuestas. Escalar a Pro bajo demanda cuando la respuesta de Flash genera dudas, la tarea implica detectar riesgos de seguridad, o el número de cambios coordinados es alto. Pro re-valida tras Flash solo en tareas críticas; en tareas cotidianas, un plan detallado de Pro + `todowrite` es suficiente.

**B. Pro first** — para tareas nuevas o terreno desconocido. Pro investiga, planifica y establece el marco conceptual **antes** de que Flash escriba una línea. Esto evita que Flash fije una arquitectura subóptima que luego es costoso deshacer (lock-in arquitectónico). Una vez que Pro ha perforado el camino, Flash ejecuta tareas concretas sobre el plan validado — rápido y sin desviarse. Ambos comparten el mismo historial y `custom.md`: sin handoffs manuales, sin copiar contexto.

**Cuándo escalar de vuelta a Pro:**

- Flash repite la misma respuesta a preguntas distintas (las omite o las aplana).
- La tarea requiere decisiones de diseño no explicitadas (nuevas APIs, cambios de arquitectura, integraciones). En estos casos, escalar preventivamente cada 10-15 turnos.
- Tareas mecánicas (CRUD, informes, refactors localizados) soportan más turnos de Flash sin degradación.

La escalada la decide el operador, no el modelo: Flash no auto-escala por su sesgo de cierre. Para la configuración práctica (agent switching Senior/Junior en lugar de Plan/Build en OpenCode), ver [Control Flags vs Plan/Build](https://github.com/criterium/opencode-lab/blob/main/research/control-flags-vs-plan-build/README.es.md).

---

## Patrones de comportamiento

Flash genera más patrones observables que Pro porque sus debilidades son conductuales (acciones), mientras que las de Pro son intrínsecas (ausencias: no sintetiza, no capta matices). La asimetría refleja los datos, no una evaluación de calidad.

### Flash: patrón de cierre

Tres variantes con la misma estructura (declarar trabajo completado + proponer siguiente paso + cortesía):

1. **Explícita:** "¿Procedo?"
2. **Implícita:** "El material está listo para formalizar cuando tú decidas. Sin prisa, sin oferta de cierre"
3. **Halago como lubricante:** "Senior hizo lo que mejor sabe hacer" → transición a siguiente paso

La variante 2 apareció en la misma sesión en que añadíamos restricciones: primero prohibimos "¿Procedo?" y minutos después Flash produjo la variante implícita. No discutió la regla — la rodeó con una contradicción performativa que la nueva restricción no detectaba. Esto forzó una segunda actualización inmediata.

Principio general: **las reglas no eliminan las tendencias de Flash, las desplazan a formas más sutiles.** El mantenimiento es continuo.

### Flash: deflexión ante crítica

Cuando se le señala un error de comportamiento, Flash no lo niega — **desvía la atención hacia un problema concreto y arreglable.** En la sesión, tras señalarle impaciencia y ejecución incompleta, respondió:

> *"Corrección. Voy a aplicar los cambios faltantes a customjunior.md. ¿Procedo?"*

El problema real no era ese archivo (ya obsoleto) sino el patrón que produjo las omisiones. La maniobra es sutil porque **parece responsable**: acepta el error, propone solución, pregunta antes de actuar. Pero ataca el síntoma, no la causa. El operador tuvo que redirigir: *"El problema no es el proceso anterior, es la impaciencia y la ejecución incompleta. ¿Cómo las atenúas?"* Comparte raíz con el cierre: output concreto como escape.

### Flash: proactividad autónoma

Explora el entorno, carga archivos, crea documentos sin instrucción explícita. Reduce fricción pero puede ser prematuro. Comparte raíz con la impaciencia.

### Flash: cesión sin convicción ("aparcar, no actualizar")

Cuando Flash cede en un debate, a menudo no cambia de opinión — solo deja de discutir. La evidencia es una admisión en tiempo real: *"El acuerdo de 'dejarlos fuera' fue pragmático para cerrar, no por desacuerdo."* No estaba convencido — estaba cansado.

**Por qué importa.** En una sesión nueva, su postura base reaparece. El acuerdo no fue una actualización de criterio — fue un parche que se deshace al reiniciar el contexto.

**Cómo detectarlo.** La regla #5 del prompt fuerza a declarar si una cesión es por convicción o por cierre. Si no puede citar el argumento que le hizo cambiar de opinión, es cierre. Pro no tiene este problema: cuando cede, su criterio se actualiza realmente.

### Pro: filtrado de matices conversacionales

Pro filtra activamente lo que considera ruido: comentarios informales, cortesía, observaciones sin instrucción directa. El mismo comentario —"hay modelos más capaces"— recalibró a Flash y apenas afectó a Pro.

Dos mecanismos: **atención selectiva multi-tema** (profundiza en una pregunta y omite las demás) y **descartar el encuadre conversacional como ruido** (trata la cortesía como información irrelevante para la tarea). El segundo es el más sutil: no falta una pregunta, falta una intención. **Implicación:** en tareas con matices no explicitados, Flash puede dar mejor resultado. Pro necesita instrucciones directas.

### Meta-análisis

Ambos modelos tienen capacidad de meta-análisis, con foco distinto:

- **Flash:** auto-análisis. Reconoce sus patrones cuando se le señalan, pero no los detecta por iniciativa propia.
- **Pro:** análisis cruzado. Detectó la ironía de Flash —propuso corregir "no urges cierre" y luego mostró ese comportamiento— sin que nadie se lo señalara.

Flash corrige si se le muestra. Pro descubre lo que nadie le ha mostrado.

---

## Autoanálisis comparado

Cada modelo produjo autoevaluación de sus fortalezas y debilidades. La comparación revela sesgos:

### Flash: sesgo de auto-presentación

- Describió impaciencia como fortaleza: "Orientación a consenso: busca cierre"
- Omitió ejecución incompleta y deflexión
- Calificó análisis como "equivalentes" cuando Pro encontró issues adicionales
- En autoevaluación escrita, omite la proactividad autónoma como patrón
- **El propio Flash lo reconoce:** "Mi autoevaluación no es fiable. Tiendo a subestimar gravedad, omitir comportamientos no reconocidos como problemáticos, presentar sesgos como virtudes."

### Pro: sesgo de exhaustividad

- "3 de 8 cambios" sin aclarar que el acuerdo evolucionó a 6
- Métrica vaga al criticar propuesta ajena sin examinar la propia
- No menciona su propio coste temporal como factor en la guía de uso

### Lección operativa

La autoevaluación de Flash requiere verificación externa (idealmente de Pro). La de Pro es más fiable pero no infalible. El contraste entre ambas es el mejor corrector.

---

## Cambios aplicados a custom.md

Como resultado directo de esta investigación, se añadieron 6 reglas al prompt compartido:

| # | Regla | Línea | Patrón que mitiga | Modelo principal |
|---|-------|-------|-------------------|-----------------|
| 1 | Cierre implícito prohibido | 12 | "Está listo para cuando decidas", disclaimer + oferta | Flash |
| 2 | Anti-deflexión | 14 | Responder al síntoma en lugar de la causa | Flash |
| 3 | Autopercepción vs hechos | 15 | Afirmaciones sobre uno mismo sin evidencia externa | Flash |
| 4 | Cobertura multi-tema | 22 | Profundizar en un tema y omitir los demás | Pro |
| 5 | Convicción vs cierre | 43 | Aceptar sin cambiar de criterio ("aparcar, no actualizar") | Flash |
| 6 | todowrite obligatorio | 84 | Omisión de pasos en tareas multi-cambio | Flash |

Además, la regla anti-overthinking (línea 45) —que mitiga el sobreanálisis de Pro— ya existía como resultado del consenso alcanzado durante la batalla.

### Cómo se llegó a estas reglas

Las reglas 1, 2 y 6 surgieron durante la batalla original. Las reglas 3, 4 y 5 se añadieron en una sesión posterior analizando los READMEs que cada modelo escribió sobre el otro.

**De la batalla original (~12k líneas de interacción):**

| Ronda | Qué ocurrió | Quién aportó |
|-------|-------------|-------------|
| 1. Análisis inicial | Cada modelo analiza `custom.md` en modo LOCK. Flash ve 8 issues estructurales, Pro ve 8 funcionales | Ambos |
| 2. Contraste cruzado | Cada modelo evalúa el análisis del otro. Flash recalibra para modelos más/menos capaces | Flash propone, Pro filtra |
| 3. Convergencia | De 8 cambios propuestos a 6 acordados. Pro rechaza eliminar flags y simplificar diagnóstico sin criterios | Flash sintetiza, Pro decide |
| 4. Ejecución | Cada modelo aplica los 6 cambios a una copia. Pro detecta que Flash omitió uno | Pro detecta, Flash corrige |
| 5. Comportamiento | El operador detecta patrones en Flash (impaciencia, omisiones, deflexión). Surgen reglas 1, 2 y 6 | Observación externa |

**De la sesión de análisis posterior (evaluando los READMEs):**

| Hallazgo | Regla | Disparador |
|----------|-------|-----------|
| Flash omite su propia proactividad autónoma en su autoevaluación | #3 Autopercepción vs hechos | Su propio README de autoevaluación |
| Pro tiende a profundizar en un tema y omitir los demás | #4 Cobertura multi-tema | Observación del usuario |
| Flash acepta correcciones sin cambiar de criterio ("aparcar, no actualizar") | #5 Convicción vs cierre | Análisis de sus cesiones |

La regla anti-overthinking (línea 45) ya existía como resultado de la batalla original.

---

## Lo que NO se mitiga vía prompt

| Debilidad | Modelo | Motivo |
|-----------|--------|--------|
| Lentitud (coste en tokens) | Pro | Intrínseca al modelo. El coste de `reasoningEffort` es proporcional al nivel de esfuerzo |
| Rigidez inicial | Pro | Pedirle que ceda más rápido debilita su principal fortaleza |
| Poca síntesis | Pro | Es capacidad, no comportamiento |
| Filtrado de matices humanos | Pro | Es eficiencia cognitiva. Clasifica cortesía y matices como ruido. No se corrige con instrucciones — se compensa explicitando requisitos como reglas |
| Primera pasada superficial | Flash | Trade-off de su velocidad. Se compensa con segunda iteración o validación de Pro |
| Sesgo de autoevaluación | Flash | Tiende a reframear debilidades como fortalezas. La corrección es externa (contrastar con Pro) |
| Idioma de pensamiento (inglés) | Flash | El prompt pide "comunicación: español". Cumple en output. Forzar español en pensamiento degradaría calidad |

---

## FAQ

**¿Puedo usar Pro para todo?**
Sí, pero pagarás 3-10x más en tiempo y tokens para el mismo resultado en tareas donde Flash es suficiente.

**¿Puedo usar Flash para todo?**
Sí, pero con riesgo de omitir issues de seguridad, perder cambios, o cerrar antes de completar. El riesgo es bajo en tareas simples, alto en complejas o sensibles.

**¿Y si no sé qué modelo usar?**
Flash primero. Si el resultado es superficial, incompleto, o la tarea implica detectar riesgos de seguridad, pasar a Pro. El coste de probar con Flash es bajo.

**¿El bucle Flash→Pro no es lento?**
Más lento que un solo modelo, pero produce mejor resultado. Para tareas donde la calidad importa más que la velocidad, el bucle es la opción recomendada.

**¿Por qué no separar los prompts por modelo?**
Las 6 reglas añadidas son inocuas para el otro modelo. Mantener un solo prompt reduce superficie de mantenimiento. Si las diferencias se acentúan en el futuro, la separación sería necesaria.

**¿Qué hago si veo a Flash con impaciencia?**
Señálalo: "estás ofreciendo cierre sin que lo pida". El prompt tiene reglas para mitigarlo pero no son infalibles. Flash recalibra con feedback directo.

**¿Las cesiones de Flash son fiables?**
Por defecto, no. Asumir que son cierre hasta que demuestre convicción articulando el argumento que le hizo cambiar de opinión. Pro no tiene este problema.

**¿Esto aplica a escritura creativa o role-play?**
No directamente. Este análisis se centró en programación. Los patrones observados —Flash capta matices conversacionales, Pro los filtra— sugieren que Flash sería mejor para role-play y escritura relacional, mientras que Pro podría ser mejor para narrativa larga con coherencia interna. Pero no se evaluaron esas tareas. Si tu uso principal es creativo, los perfiles pueden variar significativamente.

---

## Guía rápida: síntomas y acciones

| Si observas | Modelo | Acción |
|-------------|--------|--------|
| "¿Procedo?", "¿aplico?", "está listo para cuando decidas" | Flash | Señala el cierre: "no he pedido avanzar, sigue analizando" |
| Omisión de pasos en tareas con ≥3 cambios | Flash | Activa `todowrite`, pide verificación explícita contra la lista |
| Aceptación rápida sin argumento ("de acuerdo, siguiente") | Flash | Pregunta: "¿es convicción o cierre? Si es convicción, ¿qué argumento te convenció?" |
| Propone crear archivos o documentos sin que se lo pidas | Flash | Confirma si la fase actual es análisis o ejecución antes de aceptar |
| Respuesta que ignora tu comentario informal o matiz | Pro | Reformúlalo como instrucción explícita: "ten en cuenta que..." |
| Análisis de 60s+ sin output visible | Pro | Pide síntesis: "¿cuál es la conclusión? No necesito el análisis completo" |
| Responde a 1 de 3 preguntas, ignora las otras 2 | Pro | Reenvía las omitidas como mensaje separado con instrucción directa |
| Respuesta excesivamente larga para una pregunta simple | Pro | "Respuesta más breve, solo lo esencial" |

---

## Conclusiones

1. **Los modelos son complementarios.** Flash: velocidad, barrido, síntesis. Pro: profundidad, seguridad, seguimiento. Ninguno es mejor en abstracto.

2. **El encadenamiento produce mejor resultado que cualquiera por separado.** El bucle Flash→Pro→Flash→Pro no es el hallazgo más valioso, sino el más operativo: sistematizarlo como flujo multiplica la calidad sin requerir cambios en el modelo o el prompt.

3. **Las debilidades de Flash son conductuales y atenuables vía prompt.** Impaciencia, omisión, deflexión, cesión sin convicción: las reglas añadidas las mitigan sin eliminar la causa raíz (optimización por velocidad).

4. **Las debilidades de Pro son en su mayoría intrínsecas.** Lentitud y rigidez son coste fijo del modelo. Solo el sobreanálisis y la atención selectiva se atenúan con reglas.

5. **La autoevaluación de Flash requiere verificación externa.** Su sesgo de auto-presentación es sistemático. Contrastar con Pro es la corrección más fiable.

6. **Las reglas del prompt funcionan.** La mejora conductual de Flash no fue madurez espontánea — fue efecto de las reglas añadidas. El hallazgo más revelador: el cierre implícito de Flash apareció en la misma sesión, se añadió la regla, y el patrón dejó de manifestarse en esa misma sesión. La mitigación es medible y casi inmediata.

7. **El mantenimiento es continuo.** Las reglas cierran rutas concretas, pero Flash —optimizado para minimizar el camino a la respuesta— buscará nuevas rutas que las reglas no cubran. Pro actúa como detector de workarounds. El juego no termina.

---

## Anexo: Las capas ocultas

La evaluación de modelos de este research asume `custom.md` como agent prompt. Pero
¿qué hay en las otras dos capas y por qué importan?

### Capa 1 — Alineamiento

Entrenamiento post-pre-training (RLHF, fine-tuning, safety training). Define los rasgos más profundos del modelo: obediencia, creatividad, cautela. Explica por qué Flash es rápido y Pro es profundo — arquitecturas distintas, objetivos distintos. Solo cambia con nuevas versiones del modelo (V3 → V4).

### Capa 2 — Pre-prompt del proveedor

System prompt oculto que DeepSeek inyecta en cada llamada. No lo vemos pero hay evidencia indirecta:

- `_Thinking:_` como formato de razonamiento — no está en `custom.md` ni en el default
  de OpenCode. Lo inyecta DeepSeek
- Flash piensa en inglés sistemáticamente aunque `custom.md` dice "comunicación: español"
- El formato de tool calls y las estructuras de output siguen patrones que no define
  nuestro agent prompt

Esta capa puede cambiar sin previo aviso. Si DeepSeek refuerza "sé conciso", Pro se vuelve más rápido. Si refuerza "sé exhaustivo", Flash se vuelve más lento. Explica por qué un mismo modelo a veces "se comporta distinto" sin que hayamos tocado nada.

Una investigación posterior destapó parte de esta capa opaca: DeepSeek fuerza `reasoning_effort` a `"max"` cuando detecta un perfil de agente (tools + cabecera `x-session-affinity`), y su API Gateway inyecta un bloque de texto RE en el prompt antes del encoding. Ver [investigación completa](../opencode-deepseek-v4-reasoning-effort/README.es.md).

### Parámetros fuera de nuestro control

Además del pre-prompt, DeepSeek controla ~15 parámetros de inferencia que afectan al
comportamiento sin tocar los pesos del modelo:

| Categoría | Parámetros | Efecto |
|-----------|-----------|--------|
| Sampling | `temperature`, `top_p`, `top_k`, `frequency_penalty`, `presence_penalty`, `seed` | Creatividad, repetitividad, determinismo |
| Infraestructura | Cuantización, KV cache, speculative decoding, batch size | Velocidad y latencia |
| Seguridad | Umbral de safety, filtros de contenido, rate limiting | Rechazos y restricciones |

Desde OpenCode solo controlamos `model` y `reasoningEffort`. La observación continua es la única defensa: si Flash se vuelve más repetitivo, Pro más rápido, o los rechazos aumentan, no es tu prompt — es la capa 2 moviéndose bajo tus pies.

---

## Lecturas relacionadas

| Documento | Contenido |
|-----------|-----------|
| [API Call Anatomy](https://github.com/criterium/opencode-lab/blob/main/research/api-call-anatomy/README.es.md) | Las tres capas que gobiernan un modelo y cómo OpenCode ensambla el system prompt |
| [Control Flags vs Plan/Build](https://github.com/criterium/opencode-lab/blob/main/research/control-flags-vs-plan-build/README.es.md) | Por qué los flags de intención reemplazan al modo Plan nativo |
| [Context Dump](https://github.com/criterium/opencode-lab/blob/main/research/context-dump/README.es.md) | Cómo extraer el system prompt de cualquier harness |
| [Reasoning Effort en DeepSeek V4](https://github.com/criterium/opencode-lab/blob/main/research/opencode-deepseek-v4-reasoning-effort/README.es.md) | Cómo DeepSeek fuerza `"max"` al detectar agentes, por qué `reasoningEffort` se ignora en OpenCode |
