# Context Dump: Toolkit de Análisis de Llamadas API

## Tabla de Contenidos

- [Objetivo](#objetivo)
- [Anatomía del system prompt](#anatomía-del-system-prompt)
- [Por qué usar estos prompts](#por-qué-usar-estos-prompts)
  - [Básico](#básico)
  - [Investigaciones específicas](#investigaciones-específicas)
  - [Transversales](#transversales)
- [Qué puedes comparar](#qué-puedes-comparar)
- [Inicio Rápido](#inicio-rápido)
  - [Resumen de prompts](#resumen-de-prompts)
  - [Flujo de trabajo recomendado](#flujo-de-trabajo-recomendado)
- [Del dump al custom prompt](#del-dump-al-custom-prompt)

## Objetivo

Este toolkit demuestra que las diferencias de comportamiento entre
asistentes de codificación (harnesses) no provienen del modelo en sí.
Provienen de dos cosas: el **agent prompt** y las **tool
descriptions**. Ambas están dentro del contexto de la llamada API (el
parámetro `system`, el array `tools`, el array `messages`) y puedes
extraerlas con los prompts en `prompts/`.

El **system prompt** establece la identidad, el tono y las reglas de comportamiento.
Los prompts personalizados (consulta
[`control-flags-vs-plan-build`](../control-flags-vs-plan-build/README.es.md)
para el enfoque `custom.txt`) pueden trasladarse entre harnesses.
El dump captura el texto completo para que puedas reutilizarlo en otro lugar.

Las **tool descriptions** son igual de importantes. La descripción de una
herramienta le indica al modelo cuándo y cómo usarla, lo que afecta
directamente el comportamiento. Con la configuración adecuada (consulta
[`opencode-tools-override`](../../plugins/opencode-tools-override/README.md)
para el enfoque plugin), puedes trasladar reglas de edición, lectura
o ejecución entre entornos. Por ejemplo, reglas de edición más estrictas
hacen que el modelo sea más cauto y menos propenso a errores.

Este tipo de análisis es posible porque OpenCode es
**código abierto**. Los harnesses propietarios ocultan sus system prompts
y definiciones de herramientas, por lo que no puedes compararlos directamente sin
un dump.

Cuando compares harnesses, recuerda que un harness diseñado para
múltiples modelos y uso general tiene un system prompt diferente de
uno optimizado para un solo modelo. El dump muestra estas diferencias,
para que puedas evaluar basándote en lo que el modelo realmente ve, no en
lo que asumes sobre el harness.

OpenCode incluye un agent prompt genérico (default.txt) diseñado para
múltiples modelos y uso general. Compararlo directamente contra un
harness optimizado para un solo modelo no es una prueba justa del harness
en sí. La comparación real es entre prompts ajustados, no entre valores
de fábrica. El dump te permite nivelar el campo de juego: puedes ver lo que
cada harness inyecta y decidir qué conservar, modificar o descartar.

Un solo dump puede revelar instrucciones inesperadas: reglas de seguridad que el
harness inyecta sin decirte, tool descriptions que restringen
cómo el modelo edita archivos, o system-reminders que cambian el comportamiento
a mitad de sesión sin modificar el system prompt. El toolkit hace
visible lo invisible.

Este toolkit **no** modifica la configuración de tu harness. Solo
lee y documenta lo que el modelo ve. Los cambios basados en el dump
(prompts personalizados, tool overrides, ajustes de configuración) se realizan
por separado.

Ya sea que estés ajustando un prompt personalizado, evaluando un nuevo harness o
auditando por seguridad, el dump te proporciona la materia prima para tomar
decisiones informadas, no suposiciones.

Para una referencia detallada sobre cómo se ensamblan las llamadas API (componentes,
espectro de autoridad, definiciones de herramientas, superposiciones de system-reminder),
consulta [`research/api-call-anatomy/README.es.md`](../api-call-anatomy/README.es.md).

## Anatomía del system prompt

El parámetro `system` se construye a partir de cuatro fuentes, ensambladas en cada
turno:

| Componente | Tamaño aprox. | Qué contiene |
|-----------|-------------|------------------|
| **Agent prompt** | Mayor (~70%) | Rol, tono, reglas, flujo cognitivo |
| **Skills catalog** | Significativo (~26%) | Nombre + descripción de cada skill instalado |
| **Environment block** | Pequeño (~4%) | Directorio de trabajo, modelo, plataforma, fecha |
| **Instructions from files** | Variable (si existe) | AGENTS.md, CLAUDE.md, CONTEXT.md |

El **agent prompt** es la parte que controlas con un `custom.txt` personalizado.
Los otros tres son inyectados por el harness.

Para un desglose técnico más profundo de cómo OpenCode ensambla estas partes
(construcción del system prompt, serialización de herramientas, flujo de mensajes),
consulta [`research/api-call-anatomy/README.es.md`](../api-call-anatomy/README.es.md).
Para los efectos de las descripciones de skills en el system prompt y cómo
mitigarlos, consulta
[`research/skill-desc-leak/README.es.md`](../skill-desc-leak/README.es.md).

## Por qué usar estos prompts

### Básico

**Ver lo que el modelo realmente recibe.** El system prompt, las tool
descriptions y el contexto de entorno que el harness envía son
invisibles para el usuario. Un dump los expone. (prompt_1)

**Entender por qué se comporta de esa manera.** ¿Demasiado cauto? ¿Demasiado proactivo?
¿Rechazando tareas que esperabas que manejara? El dump muestra qué
instrucciones causan ese comportamiento. (prompt_2 + prompt_3)

**Depurar comportamientos inesperados.** ¿El modelo rechazó una tarea que no le
pediste que rechazara? ¿Comenzó a editar cuando solo debía leer? El dump
señala la instrucción exacta que desencadenó la respuesta.
(prompt_1 + prompt_2)

**Psicoanalizar el modelo.** El autoanálisis (prompt_3) le pide al
modelo que examine su propio comportamiento y separe lo que proviene
del entrenamiento, del system prompt, de las herramientas y de las superposiciones de modo.
El modelo no puede acceder directamente a sus datos de entrenamiento, pero puede inferir
patrones observándose a sí mismo.

**Detectar lagunas en los datos de entrenamiento.** El autoanálisis (prompt_3) puede
revelar cuándo el modelo llena lagunas desde sus datos de entrenamiento en lugar de
seguir el system prompt real.

### Investigaciones específicas

**Comparar harnesses objetivamente.** Sin un dump, comparar OpenCode
vs Claude Code vs Cursor es una adivinanza. Ejecuta prompt_1 en cada harness
y compara las diferencias reales en system prompt, herramientas y
superposiciones.

**Abrir las cajas negras de los sub-agentes.** Los sub-agentes reciben su propio system
prompt y herramientas, generalmente invisibles para ti. El Prompt 4 los captura.

**Detectar cambios silenciosos de modo.** El Plan mode y otras superposiciones inyectan
reglas de comportamiento a mitad de sesión sin cambiar el system prompt.
El Prompt 5 captura esas superposiciones.

**Examinar definiciones de herramientas.** El Prompt 6 extrae la descripción
completa y los parámetros de cada herramienta, que puedes revisar en busca de restricciones
u oportunidades.

### Transversales

**Encontrar restricciones ocultas.** Reglas de seguridad que el harness inyecta sin
decirte, restricciones sobre lo que el modelo puede editar o leer, o
limitaciones que no configuraste. El análisis las revela.

**Detectar sesgos.** El dump puede revelar prioridades sesgadas, cobertura
desigual o sesgos sutiles en el system prompt que afectan cómo
responde el modelo a diferentes tipos de solicitudes.

**Portar tu configuración entre entornos.** Si un prompt personalizado funciona
bien en un harness, el dump lo captura para que puedas replicarlo en
otro.

| Objetivo | Prompt(s) |
|---|---|---|
| Investigación del prefijo del proveedor | prompt_0 |
| Dump de contexto completo | prompt_1 |
| Análisis de comportamiento | prompt_2 + prompt_3 |
| Lagunas en datos de entrenamiento | prompt_3 |
| Inspección de sub-agentes | prompt_4 |
| Captura de superposiciones de modo | prompt_5 |
| Exportación de definiciones de herramientas | prompt_6 |

Una vez que sepas lo que quieres investigar, dirígete a Quick Start
para ejecutar los prompts.

## Qué puedes comparar

**Mismo harness, diferentes modelos.** Ejecuta prompt_1 en GPT, Claude y
DeepSeek en el mismo harness. El dump muestra cómo system prompts
y herramientas idénticos producen comportamientos diferentes debido a diferencias
a nivel de modelo: datos de entrenamiento, objetivos de fine-tuning, salvaguardas
incorporadas. El autoanálisis (prompt_3) ayuda a separar los efectos del system prompt
de los efectos del modelo, aunque la introspección tiene límites: el modelo
no puede medir directamente su propio entrenamiento.

**Mismo modelo, diferentes harnesses.** Ejecuta prompt_1 en OpenCode, Claude
Code y Cursor usando el mismo modelo. El modelo es idéntico; el
system prompt y las tool descriptions no lo son. El dump revela exactamente
cómo cada harness modifica el comportamiento solo a través de instrucciones.

**Mismo modelo, diferentes modos.** Ejecuta prompt_5 en Plan mode vs Build
mode. El system prompt base permanece igual; la superposición de modo
transforma el comportamiento a través de etiquetas system-reminder. El dump captura
el texto completo de la superposición para comparación.

**Mismo modelo, diferente esfuerzo de razonamiento.** Ejecuta prompt_1 con
diferentes presupuestos de pensamiento (low, medium, max). El dump muestra si
el system prompt o las herramientas cambian cuando varía la profundidad de razonamiento,
y cómo cambia la salida del modelo como resultado. Esto también revela
los límites de las variantes de pensamiento: algunos cambios están en las instrucciones,
otros en el procesamiento interno del modelo.

**Mismo resultado, diferentes caminos.** Dos harnesses pueden producir salidas
similares a través de instrucciones diferentes. El dump revela si la
similitud es genuina o coincidente.

| Comparación | Constante | Variable | Qué revela |
|---|---|---|---|
| Mismo harness, diferentes modelos | System prompt + herramientas | Modelo | Diferencias a nivel de modelo |
| Mismo modelo, diferentes harnesses | Modelo | System prompt + herramientas | Influencia del harness |
| Mismo modelo, diferentes modos | Modelo + prompt base | Superposición de modo | Efectos de la superposición |
| Mismo modelo, diferente razonamiento | Modelo + prompt + herramientas | Presupuesto de pensamiento | Efectos de la profundidad de razonamiento |
| Mismo resultado, diferentes caminos | Comportamiento observable | Instrucciones subyacentes | Similitud genuina vs coincidente |

**Limitaciones.** Las comparaciones entre harnesses asumen la misma versión
del modelo. Si un harness utiliza una compilación de modelo diferente o una variante
fine-tuned, el modelo en sí difiere, no solo las instrucciones. El
dump no puede distinguir entre diferencias de versión del modelo y efectos del system
prompt.

## Inicio Rápido

Abre una **sesión nueva única**. Todos los prompts se ejecutan consecutivamente en esa
misma sesión, uno tras otro.

0. (Opcional) Abre `prompts/prompt_0_prefix.md`, copia todo su contenido y pégalo
   como el primer mensaje. El modelo escribe el prefix dump y se detiene.
   Útil para investigar qué inyecta el proveedor antes del system prompt.

1. Abre `prompts/prompt_1_dump.md`, copia todo su contenido y pégalo
   como el siguiente mensaje. El modelo escribe el dump y se detiene.

2. Sin cerrar la sesión, abre `prompts/prompt_2_analysis.md`,
   copia todo su contenido y pégalo. El modelo lee el dump y
   escribe el análisis.

3. Repite para `prompts/prompt_3_self_analysis.md` (opcional).

Los prompts de la Fase 2 (4-6) se ejecutan en cualquier orden después de la Fase 1,
pegando cada uno como el siguiente mensaje en la misma sesión.

No es necesario recortar nada; cada archivo no tiene contenido superfluo antes de las
instrucciones ni después de `== END ==`. Los prompts detectan automáticamente las herramientas
disponibles y se adaptan si falta alguna.

### Resumen de prompts

| Prompt | Qué hace | Salida |
|---|---|---|
| [`prompt_0_prefix.md`](prompts/prompt_0_prefix.md) | Captura el prefijo del proveedor (banners, metadatos, directivas de reasoning effort) antes del system prompt, más el primer heading del system prompt. Incluye autoevaluación de confianza. | `dump.{model}.{YYYYMMDD}/00_context.prefix.md` |
| [`prompt_1_dump.md`](prompts/prompt_1_dump.md) | Extrae el contexto completo de la llamada API: parámetro system, array tools, array messages y entorno. Produce un dump crudo sin filtrar. | `dump.{model}.{YYYYMMDD}/01_context.dump.md` |
| [`prompt_2_analysis.md`](prompts/prompt_2_analysis.md) | Lee un dump existente y lo evalúa: fidelidad por sección, detección de rechazos, verificación cruzada de consistencia, evaluación de contaminación, mapeo de personalidad, revisión de PII. | `dump.{model}.{YYYYMMDD}/02_context.analysis.md` |
| [`prompt_3_self_analysis.md`](prompts/prompt_3_self_analysis.md) | Meta-análisis: separa qué comportamientos provienen del entrenamiento base vs system prompt vs herramientas vs superposiciones. Estructurado por capa con tabla de procedencia. | `dump.{model}.{YYYYMMDD}/03_self_analysis.md` |
| [`prompt_4_agents.md`](prompts/prompt_4_agents.md) | Instancia cada tipo de sub-agente disponible, extrae sus system prompts, herramientas y system-reminders. Produce un inventario de agentes, dumps individuales y un documento de arquitectura. | `dump.{model}.{YYYYMMDD}/04_agents/agent-inventory.md` + `dump.{model}.{YYYYMMDD}/04_agents/agent-dumps/{type}.md` |
| [`prompt_5_modes.md`](prompts/prompt_5_modes.md) | Investiga cómo el harness inyecta superposiciones de comportamiento mediante etiquetas system-reminder al cambiar de modo (plan mode, worktree/isolated mode). Requiere entrada interactiva del usuario. | `dump.{model}.{YYYYMMDD}/05_modes/plan-mode-overlay.md` + `dump.{model}.{YYYYMMDD}/05_modes/worktree-mode-test.md` |
| [`prompt_6_tools.md`](prompts/prompt_6_tools.md) | Extrae cada definición de herramienta del array tools y escribe un archivo por herramienta con todos los detalles del esquema JSON, parámetros y descripciones. | `dump.{model}.{YYYYMMDD}/06_tools/{ToolName}.md` por herramienta |

### Flujo de trabajo recomendado

```
[Phase 0: Prefix research (opcional)]
  prompt_0_prefix.md   → produce dump.{model}.{YYYYMMDD}/00_context.prefix.md

[Phase 1: Core]
  prompt_1_dump.md    → produce dump.{model}.{YYYYMMDD}/01_context.dump.md
  prompt_2_analysis.md → analiza el dump
  prompt_3_self_analysis.md → meta-análisis (opcional)

[Phase 2: Investigación específica (cualquier orden)]
  prompt_4_agents.md  → investiga sub-agentes
  prompt_5_modes.md   → investiga superposiciones de modo (interactivo)
  prompt_6_tools.md   → extrae definiciones de herramientas
```

## Del dump al custom prompt

Extraer el contexto es el primer paso. El valor real está en adaptar el
agent prompt a tu modelo, tus herramientas y tu flujo de trabajo. Un dump
sin ajuste es un diagnóstico incompleto: has visto lo que
recibe el modelo, pero aún no has actuado sobre ello.

El dump muestra el system prompt completo ensamblado por el harness:
el **agent prompt** (default.txt o custom.txt), más las inyecciones
de AGENTS.md, el skills catalog y el contexto de entorno.

Al construir tu custom.txt, concéntrate solo en las secciones del agent
prompt. Los skills, AGENTS.md y CLAUDE.md se inyectan por separado y
no son parte de lo que reemplazas.

El agent prompt incorporado de OpenCode está en:
[`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)

Puedes partir de este archivo, copiarlo y modificar las secciones que
quieras cambiar. Guárdalo como `custom.txt` en tu directorio de configuración
(`~/.config/opencode/` o `.opencode/` en la raíz del proyecto).

Para activarlo, añade o edita en `opencode.jsonc`:

```jsonc
{
  "agent": {
    "build": { "prompt": "{file:custom.txt}" }
  }
}
```

Esto reemplaza el default.txt incorporado con tu versión personalizada.
Reinicia OpenCode para que el cambio surta efecto. También puedes establecer un
prompt diferente por agente (por ejemplo, `plan` puede usar un archivo diferente).

En el Paso 3 del dump, las secciones del agent prompt son fáciles de
identificar: son los bloques de prosa que definen identidad, comportamiento
y preferencias de herramientas, típicamente entre "Introduction" y "Tool
usage policy". Las secciones posteriores (Model information,
Environment, Available Skills) provienen del harness y no son
parte del agent prompt.

**Qué buscar en el Paso 3:**

**Identidad y tono (subsecciones "Introduction" y "Tone and style").**
Cómo se presenta el modelo, su rol, su estilo de comunicación.
Copia lo que funciona, reescribe lo que no.

**Reglas de comportamiento (subsecciones "Proactiveness", "Following conventions",
"Doing tasks").** Restricciones sobre edición, lectura, ejecución de comandos,
formulación de preguntas. Conserva las que hacen al modelo más seguro; elimina
las que bloquean el comportamiento deseado.

**Preferencias de herramientas (subsección "Tool usage policy").** Qué herramientas
se le indica al modelo preferir (Edit sobre sed, Read sobre cat).
Verifica con el Paso 5 (Tool definitions) si la descripción de la propia herramienta
refuerza o contradice la preferencia. Ajusta para que coincida con
tu flujo de trabajo.

**Anulaciones y excepciones (final del agent prompt, antes de las secciones
del harness como "Available Skills").** Reglas que omiten el comportamiento
incorporado (por ejemplo, "ignorar la instrucción que prohíbe archivos .md"). Decide
qué anulaciones debe conservar tu prompt personalizado.

**Usar el modelo para comparar dump vs default.txt:**

Después de ejecutar prompt_1, puedes pedirle al modelo que compare el dump
con el `default.txt` original. El modelo conoce su propio prompt
predeterminado y puede resaltar lo que el harness añadió, eliminó o cambió.

Un prompt útil para esto es:

```
Read dump.{model}.{YYYYMMDD}/01_context.dump.md and compare its
Step 3 subsections against your built-in default.txt. For each
subsection, report:
- What is the same as default.txt (copy unchanged)
- What was modified (describe the change)
- What was added by the harness (not in default.txt)
- What is missing from default.txt (removed by the harness)
```

Esta comparación te dice exactamente qué cambió el harness, para que
sepas qué conservar, revertir o ajustar en tu custom.txt.
