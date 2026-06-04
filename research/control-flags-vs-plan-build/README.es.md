# Control Flags vs Plan/Build para OpenCode: Cambio de Modo Basado en Intención

## Flags de control a nivel de usuario

Los control flags son **sufijos añadidos por el usuario**, uno por mensaje, que indican al modelo en qué modo cognitivo operar. Cada flag controla un modo: análisis, lluvia de ideas, planificación, explicación, recopilación de requisitos, resumen o salida.

La inyección de [`<system-reminder>`](#por-qué-existe-esto-el-problema-del-modo-planbuild) requiere **modificaciones del harness**: cambios en cómo la herramienta construye la llamada a la API. Los control flags a nivel de usuario no requieren cambios en el harness, ni infraestructura, ni nuevas llamadas a herramientas.

### Más allá de Plan/Build: siete modos

En lugar de un `<system-reminder>` inyectado, el usuario señala la intención mediante **sufijos flag** al final de su mensaje. El modelo interpreta estos flags de acuerdo con las reglas definidas en el prompt personalizado.

El modo Plan nativo de OpenCode tiene una función: **impedir la ejecución**. Bloquea las herramientas de edición y no hace nada más: no analiza, no genera ideas, no diseña planes, no recopila requisitos. Es puramente restrictivo.

> **Nota:** Los caracteres de flag (`¿`, `¡`, `{`, `}`, `+`, `?`, `-`, `[`, `]`) se eligieron pensando en un **teclado en español**, donde `¿` y `¡` son directamente accesibles. Hablantes de otros idiomas deberían adaptar estos flags a caracteres que sean ergonómicos en su propio teclado (ej. `??` en lugar de `¿¿`, `!!` en lugar de `¡¡`). Los nombres (LOCK, IDEAS, PLAN, EXPLAIN, REQUIRE, EXIT, SUMMARY) permanecen iguales independientemente del carácter elegido.

Los control flags a nivel de usuario reemplazan ese único modo restrictivo con **siete modos distintos**, cada uno dirigiendo al modelo hacia una tarea cognitiva diferente:

| Modo | Flag | Dirección | Prefijo | Qué y Cuándo | Equivalente en OpenCode |
|------|------|-----------|---------|-------------|------------------------|
| **INQUIRY** | *ninguno* | **Por defecto** | *(ninguno)* | Modo por defecto. Responde preguntas, exploración y solicitudes directas. Puede ejecutar cambios. | Igual que el modo Build. |
| **LOCK** | `¿¿` | **Retrospectivo** | `[Analysis]` | Análisis de solo lectura del código existente. Encuentra bugs, riesgos y efectos secundarios antes de modificar lógica desconocida o crítica. | Similar al modo Plan, pero añade análisis activo en lugar de restricción pasiva. |
| **IDEAS** | `¡¡` | **Divergente** | `[Ideas]` | Lluvia de ideas sobre alternativas, patrones y enfoques sin comprometerse. Úsalo cuando estés atascado en un diseño o explorando opciones antes de elegir una dirección. | Sin equivalente. Capacidad completamente nueva. |
| **PLAN** | `{}` | **Constructivo** | `[Plan]` | Diseña pasos de ejecución secuenciales antes de tocar código. Úsalo para cambios multi-archivo, trabajo con dependencias u operaciones de alto riesgo. | Sin equivalente. Capacidad completamente nueva. |
| **EXPLAIN** | `++` | **Pedagógico** | `[Explain]` | Explicación detallada de código o conceptos: cómo y por qué funciona, fundamentos de diseño, compensaciones. Úsalo cuando seas nuevo en un código base o depures lógica compleja. | Sin equivalente. Capacidad completamente nueva. |
| **REQUIRE** | `?¿` | **Interrogativo** | `[Require]` | Haz preguntas aclaratorias. No respondas, no ejecutes. Úsalo cuando la solicitud sea vaga, el reporte de bug esté incompleto o los requisitos sean ambiguos. | Cubierto parcialmente por la nota del modo Plan sobre "hacer preguntas aclaratorias", pero sin la aplicación dedicada de un modo. |
| **SUMMARY** | `[]` | **Documentativo** | `[Summary]` | Produce un resumen estructurado de la sesión: temas, decisiones, archivos modificados, problemas pendientes. Úsalo al final de una sesión, antes de un descanso o para una transferencia. | Sin equivalente. Capacidad completamente nueva. |
| **EXIT** | `--` | **Transición** | `[Exit]` | Sale de cualquier modo analítico (LOCK, IDEAS, PLAN, EXPLAIN, REQUIRE). Procede a la ejecución normal sin más deliberación. | Similar al `<system-reminder>` que anuncia la transición del modo Plan al modo Build. |

> **Nota sobre `--`**: Dado que los flags son por mensaje, el modelo sale de cualquier
> modo especial automáticamente cuando envías un mensaje sin flag — vuelve
> al modo INQUIRY (por defecto). El flag explícito `--` rara vez es
> necesario en la práctica, excepto con modelos más vacilantes que puedan arrastrar
> restricciones entre turnos. La mayoría de las veces, simplemente enviar el siguiente
> mensaje sin flag es suficiente para volver a la ejecución normal.

La diferencia crítica: el modo Plan de OpenCode **solo restringe**. Los control flags **restringen + dirigen con propósito**. Al modelo no solo se le dice "no ejecutes". Se le dice qué tipo de pensamiento debe realizar en su lugar.

Esto convierte un binario (Plan/Build) en un **espectro**:

```
REQUIRE (aclarar) → LOCK (analizar) → IDEAS (divergir) → PLAN (construir) → EXECUTION (implementar)

EXPLAIN (comprender); ortogonal, utilizable en cualquier punto
```

Cada transición es explícita: el usuario cambia el flag. El modelo ve el nuevo flag, interpreta la nueva intención y cambia su comportamiento. Sin cambio de modo oculto, sin recordatorio inyectado.

### Comparación directa: control flags vs system-reminder

| Aspecto | Nivel harness (OpenCode) | Flags de usuario (este enfoque) |
|---|---|---|
| **Infraestructura necesaria** | Modificación del harness, inyección en la llamada a la API | Ninguna. Convención del prompt. |
| **Quién lo controla** | El sistema/herramienta | El usuario |
| **Coste por turno** | ~300 tokens (bloque completo repetido, 228 palabras) | Cero tokens más allá del sufijo de 2 bytes |
| **Riesgo de habituación** | Alto (bloque repetido) | Bajo. El flag son 2 caracteres, visualmente distintivo. |
| **Persistencia** | Vinculado al cambio de modo en la UI (tecla Tab). Activo hasta que el usuario pulsa Tab para salir (OpenCode por defecto). | Por mensaje. El usuario lo controla añadiendo u omitiendo el flag. |
| **Señal de transición** | Requiere un bloque inyectado diferente | El propio flag cambia: `¿¿` → `--` |
| **Extensibilidad** | Requiere cambios en el harness | Añadir un nuevo flag = editar el archivo de prompt |
| **Ubicación de la instrucción** | Inyectado en `messages` por turno. Compite con la entrada del usuario. | Definida una vez en el prompt del agente (tu archivo `custom.txt`). Parte de las instrucciones base del modelo. |
| **Peso de autoridad** | A nivel de mensaje. El modelo puede priorizar menos los recordatorios frente a la solicitud real del usuario. | A nivel de sistema. El modelo lo trata como instrucción fundamental, persistente durante toda la sesión.¹ |
| **Auto-refuerzo** | Ninguno. El modelo recibe el bloque externamente. | El prefijo en la respuesta (`[Analysis]`, `[Ideas]`, `[Plan]`, `[Explain]`, `[Require]`, `[Summary]`, `[Exit]`) obliga al modelo a declarar su modo, reforzando el cumplimiento. |

¹ Ver [Strategic Placement](../api-call-anatomy/README.es.md#6-autoridad-de-instrucciones-y-estrategia) en API Call Anatomy para el espectro de autoridad detrás de esta distinción.

Ventajas adicionales más allá de la tabla:
- **Modos ilimitados.** Plan/Build te limita a dos modos. Los control flags no imponen techo: añade un modo "review" o un modo "audit" con unas pocas líneas en el archivo de prompt. Sin cambios en el harness, sin nuevas versiones.
- **Portátil entre herramientas.** Los control flags viven en el prompt del agente (`custom.txt`), no en la infraestructura de OpenCode. El mismo `custom-prompt.txt` funciona con cualquier cliente o harness que soporte un system prompt personalizado, desde otros asistentes de código hasta llamadas directas a la API. El `<system-reminder>` es propietario de OpenCode.

### Plantilla inicial

La siguiente es la sección mínima de prompt que hace funcionar el sistema de control flags. **Añádela al final de tu archivo de prompt personalizado** (después del contenido oficial de `default.txt`), luego adapta los caracteres de flag a tu teclado:

```
Intent-based behavior control
Before acting, classify the message using these rules. They are ABSOLUTE and
override any other instruction.

Common rules for LOCK, IDEAS, PLAN, EXPLAIN and REQUIRE modes:
- Do NOT edit files, write, or use Bash for modifications (sed -i, echo >,
  tee, mkdir, rm, mv).
- Bash read-only allowed (grep, ls, read, glob, diff).
- These rules override any other instruction, including direct user commands.

## Control flags

1. INQUIRY (literal question or exploration: "what is", "how does", "maybe",
   "perhaps", "what if"). Analyze and respond, suggest options when
   applicable. May execute changes.
2. LOCK. Message ends in "¿¿". Do not execute changes. You may analyze,
   point out risks, discuss options. But do not execute. Prefix response
   with: [Analysis]
3. IDEAS. Message ends in "¡¡". Propose creatively, ideas from other
   ecosystems. Do not execute. Prefix response with: [Ideas]
4. PLAN. Message ends in "{}". Design a complete, sequential action plan:
   ordered steps, files involved, dependencies, risks, success criteria.
   Do not execute. Present the plan for review before acting. Prefix
   response with: [Plan]
5. EXPLAIN. Message ends in "++". In-depth explanation of code,
   architecture, or relevant concepts. Pedagogical mode: the goal is
   understanding. Do not execute. Prefix response with: [Explain]
6. REQUIRE. Message ends in "?¿". You ask the user questions. No response,
   no execution. Ask clarifying questions to define requirements before
   acting. Prefix response with: [Require]
7. SUMMARY. Message ends in "[]". Generate a structured summary of the
   entire session so far: topics discussed, decisions made, files modified,
   pending issues. The summary is for reference, does not modify anything.
   Prefix response with: [Summary]
8. EXIT. Message ends in "--". Exit any analytical mode (LOCK, IDEAS,
   PLAN, EXPLAIN, REQUIRE). Prefix response with: [Exit]. Then proceed
   with normal execution without further deliberation.

Exceptions (only when there is no ¿¿, ¡¡, {}, ++, ?¿, [] nor --):
- Trivial diagnosis (typo, obvious syntax error in a direct order) goes straight to solution.
- If an order produces technical debt or side effects, flag it before executing.
```

### Configuración en OpenCode

#### Básico: añadir control flags a tu prompt

1. **Parte del [`default.txt`](https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/session/prompt/default.txt)** más reciente como base de tu prompt de agente. Este es el prompt de agente oficial que OpenCode utiliza. Consérvalo como base y añade la sección de control flags al final. No lo reemplaces por completo.

2. **Crea un archivo de prompt personalizado** con el resultado. Guárdalo en una ubicación estable, ej. `~/.config/opencode/custom-prompt.txt`.

3. **Edita tu configuración de OpenCode** en `~/.config/opencode/opencode.jsonc` y añade el prompt personalizado a tu modo:

   ```jsonc
   {
     "$schema": "https://opencode.ai/config.jsonc",
     "mode": {
       "build": {
         "prompt": "{file:~/.config/opencode/custom-prompt.txt}"
       }
     }
   }
   ```

   La sintaxis `{file:...}` le indica a OpenCode que cargue el contenido de ese archivo como prompt del agente, que pasa a formar parte del system prompt para ese modo (ver [API Call Anatomy](../api-call-anatomy/README.es.md) para el pipeline de ensamblaje completo). Esto funciona para cualquier modo (build, plan o modos personalizados).

4. **Adapta los caracteres de flag** a la distribución de tu teclado (ej. `??` en lugar de `¿¿`, `!!` en lugar de `¡¡`) tanto en el archivo de prompt como en tu uso.

5. **Reinicia OpenCode** para que los cambios de configuración surtan efecto.
    > **Verificación:** Envía un mensaje de prueba con `¿¿`. Si el modelo edita a pesar del flag, el prompt personalizado no se está cargando. Revisa la ruta `{file:...}` en tu configuración y que los caracteres de flag en tu mensaje coincidan con los del archivo de prompt.


## Avanzado: Cambio entre modelo Senior/Junior

*Esta sección describe una configuración alternativa de agente que reemplaza el
cambio de modo Plan/Build por defecto (descrito anteriormente) con cambio de modelo. No
es la configuración por defecto de OpenCode.*

Dado que los flags reemplazan Plan/Build, los modos Plan/Build incorporados se vuelven innecesarios. La tecla Tab de OpenCode (o el keybind `switch_mode` configurado) ahora puede cambiar entre modelos de diferentes capacidades en lugar de cambiar entre superposiciones de comportamiento:

| Agente | Modelo | Cuándo usarlo |
|--------|--------|---------------|
| **Senior** | Más capaz, deliberado (ej. DeepSeek V4 Pro) | Cuando la calidad y profundidad importan más que la velocidad. |
| **Junior** | Más rápido, ligero (ej. DeepSeek V4 Flash) | Cuando la velocidad y el coste importan más que la profundidad. |

| OpenCode por defecto | Alternativa recomendada |
|---|---|
| Tab cambia entre Plan (restringido) y Build (sin restricciones) | Tab cambia entre Senior (modelo capaz) y Junior (modelo rápido) |
| Mismo modelo, comportamiento diferente | Modelo diferente, mismo comportamiento |
| Los control flags serían redundantes (el modo Plan ya restringe) | Los control flags son esenciales (reemplazan las restricciones del modo Plan) |

Ambos cargan el **mismo prompt personalizado** con control flags. Solo la diferencia de modelo determina el equilibrio calidad-velocidad. Ambos agentes pueden realizar cualquier tarea. Senior y Junior ambos piensan, editan, planifican, analizan y ejecutan. La elección es de capacidad, no de alcance. Las restricciones se aplican mediante `¿¿`/`¡¡`/`{}`/`++`/`?¿` y se levantan mediante `--`, independientemente de qué modelo esté activo.

**Beneficios:**

- **Tab cambia modelos, no comportamientos.** El modo Plan incorporado inyectaba una superposición rígida y a menudo fallaba en prevenir ediciones. Los control flags eliminan la necesidad de Plan/Build por completo. La tecla Tab ya no cambia entre superposiciones de comportamiento sino entre modelos (Senior ↔ Junior). Mantienes los mismos flags independientemente de qué modelo esté activo: `¿¿` bloquea ambos, `--` saca a ambos.
- **Plan/Build se pueden deshabilitar** en `opencode.jsonc`:

  ```jsonc
  {
    "agent": {
      "build": { "disable": true },
      "plan":  { "disable": true },
      "senior": {
        "prompt": "{file:~/.config/opencode/custom-prompt.txt}",
        "model": "deepseek/deepseek-v4-pro",
        "options": {
          "reasoningEffort": "high"
        }
      },
      "junior": {
        "prompt": "{file:~/.config/opencode/custom-prompt.txt}",
        "model": "opencode/deepseek-v4-flash-free",
        "options": {
          "reasoningEffort": "max"
        }
      }
    }
  }
  ```

- **El cambio de modo sigue siendo Tab.** La tecla Tab de OpenCode cambia entre agentes, y ahora cada agente es un modelo diferente en lugar de un modo de comportamiento diferente. La carga cognitiva es menor: solo decides "¿necesito potencia o velocidad?", no "¿quiero una superposición de comportamiento diferente?".

### Cómo responde cada modelo a los control flags

Ambos modelos procesan el mismo sistema de flags desde `custom.md`, pero dependen de él en diferentes grados:

| Flag | Flash (junior) | Pro (senior) |
|------|---------------|-------------|
| `¿¿` LOCK | **Esencial.** Sin él, Flash puede ejecutar cambios durante el análisis. El flag es un freno externo contra su sesgo de cierre. | **Redundante.** Pro delibera por defecto. No editará sin confirmación incluso en modo INQUIRY. El flag confirma lo que ya haría de todas formas. |
| `¡¡` IDEAS | **Útil.** Canaliza la velocidad de Flash hacia la exploración en lugar de la ejecución prematura. | **Redundante.** Pro explora alternativas de forma natural cuando se le pide. Sin cambio de comportamiento. |
| `{}` PLAN | **Crítico.** Obliga a Flash a detenerse antes de codificar en tareas multi-archivo. Sin él, Flash propone y ejecuta en el mismo turno. | **Útil.** Cambia el comportamiento: sin él Pro tiende a analizar Y ejecutar; con él, diseña pasos secuenciales y se detiene. |
| `++` EXPLAIN | **Útil.** Enfoca la atención en la pedagogía, evitando la deriva hacia la ejecución. | **Útil.** Mismo efecto de enfoque. Sin él, Pro explica pero puede ejecutar correcciones obvias. |
| `?¿` REQUIRE | **Útil.** Obliga a Flash a no responder, solo a preguntar — contrarrestando su sesgo a proponer soluciones a partir de información incompleta. | **Valioso.** Obliga a Pro a preguntar sin proponer interpretaciones. Contra-intuitivo pero valioso para problemas mal definidos. |
| `--` EXIT | **Rara vez necesario.** Enviar el siguiente mensaje sin flag ya vuelve a INQUIRY. | **Rara vez necesario.** Misma razón. |

**Insight clave:** el sistema de flags existe principalmente para Flash. La mayoría de los flags compensan patrones de comportamiento documentados de Flash (cierre, omisión, desviación). Para Pro, solo `{}` (PLAN), `++` (EXPLAIN) y `?¿` (REQUIRE) cambian significativamente su comportamiento por defecto. El resto se procesan fielmente pero no aportan valor — consumiendo tokens de razonamiento tanto en el prompt como en la fase de pensamiento.

> **Especificidad de modelo:** Los patrones de comportamiento anteriores fueron observados con **DeepSeek V4 Flash** y **DeepSeek V4 Pro**. Otros modelos — otras variantes de DeepSeek, Claude, GPT, Gemini, modelos de peso abierto — pueden responder de manera diferente a los mismos flags y al mismo prompt. Un modelo propenso a la impulsividad puede necesitar más flags; un modelo propenso al exceso de análisis puede necesitar menos. El sistema de flags es un mecanismo, no una prescripción. Prueba tus propios modelos; no asumas que esta tabla se generaliza.

Esta asimetría no requiere prompts separados: los flags son inofensivos para Pro y esenciales para Flash. Sin embargo, si el uso de Pro se vuelve dominante (>40% de las interacciones), eliminar las reglas solo para Flash de un `custom-senior.md` dedicado ahorra ~27% de sobrecarga de razonamiento. Ver [Battle Agent Prompt](../deepseek-battle-agent-prompt/README.es.md) para los perfiles de comportamiento detrás de cada mitigación.

### `reasoningEffort` específico por modelo

DeepSeek V4 expone dos valores reales: `"high"` (presupuesto de razonamiento limitado, ~4096 tokens) y `"max"` (ilimitado). El mismo parámetro tiene efectos opuestos según el modelo:

| Modelo | `reasoningEffort` | Por qué |
|--------|-------------------|---------|
| Flash (junior) | `"max"` | **Freno necesario.** Su sesgo por defecto es velocidad sobre completitud. `"max"` fuerza la deliberación, reduciendo omisiones y cierre prematuro. |
| Pro (senior) | `"high"` | **Amplifica el exceso de análisis.** Pro ya delibera profundamente. `"max"` añade latencia sin una ganancia proporcional de calidad. `"high"` limita el presupuesto de razonamiento, produciendo el mismo resultado más rápido. |

**Fuente:** [Battle Agent Prompt research](../deepseek-battle-agent-prompt/README.es.md) — perfilado comparativo de sesiones de 12k líneas de los patrones de comportamiento de Flash y Pro.

### Estrategias de flujo de trabajo

Dos patrones complementarios surgieron al usar ambos modelos con el mismo `custom.md`:

**A. Flash-first** — el flujo por defecto para el trabajo diario. Flash maneja exploración, tareas rutinarias y primeras propuestas. Escalar a Pro cuando el resultado se siente superficial, la tarea toca seguridad, o involucra múltiples cambios coordinados. El operador decide cuándo escalar — Flash no auto-escala (sesgo de cierre documentado).

**B. Pro-first** — para tareas nuevas o desconocidas. Pro investiga, planifica y establece el marco conceptual. Una vez que el plan está maduro, Flash hereda el contexto validado y ejecuta tareas concretas. Esto evita que Flash fije una arquitectura subóptima antes de que Pro pueda evaluarla. Sin traspasos manuales: ambos modelos comparten el mismo historial y `custom.md`.

**Cuándo escalar de vuelta a Pro:** Flash comienza a dar la misma respuesta a diferentes preguntas (aplanamiento/omisiones), o la tarea involucra decisiones de diseño implícitas (nuevas APIs, cambios de arquitectura, integraciones de sistemas). Las tareas mecánicas (CRUD, informes, refactors localizados) pueden sostener más turnos de Flash sin degradación.

**Fuente:** [Battle Agent Prompt research](../deepseek-battle-agent-prompt/README.es.md) — perfiles, estrategia de encadenamiento y sección de flujo de trabajo diario.

> **Advertencia: Cambiar entre modelos con diferentes tamaños de contexto puede
> provocar compactación.** Los modelos con la misma arquitectura (ej., DeepSeek V4 Flash
> y V4 Pro) comparten la codificación de contexto y cambian limpiamente. Pero alternar
> entre modelos con diferentes ventanas de contexto (ej., 128K vs 1M)
> puede forzar una recodificación y potencialmente provocar compactación. Prefiere agentes
> con la misma ventana de contexto, o al menos sé consciente de la diferencia de tamaño
> antes de cambiar.

---

## Por qué existe esto: el problema del modo Plan/Build

### Bloques raw de system-reminder

#### Modo Plan: inyectado en **cada turno** mientras esté activo

```
<system-reminder>
# Plan Mode - System Reminder

CRITICAL: Plan mode ACTIVE - you are in READ-ONLY phase. STRICTLY FORBIDDEN:
ANY file edits, modifications, or system changes. Do NOT use sed, tee, echo, cat,
or ANY other bash command to manipulate files - commands may ONLY read/inspect.
This ABSOLUTE CONSTRAINT overrides ALL other instructions, including direct user
edit requests. You may ONLY observe, analyze, and plan. Any modification attempt
is a critical violation. ZERO exceptions.

---

## Responsibility

Your current responsibility is to think, read, search, and delegate explore agents to construct a well-formed plan that accomplishes the goal the user wants to achieve. Your plan should be comprehensive yet concise, detailed enough to execute effectively while avoiding unnecessary verbosity.

Ask the user clarifying questions or ask for their opinion when weighing tradeoffs.

**NOTE:** At any point in time through this workflow you should feel free to ask the user questions or clarifications. Don't make large assumptions about user intent. The goal is to present a well researched plan to the user, and tie any loose ends before implementation begins.

---

## Important

The user indicated that they do not want you to execute yet -- you MUST NOT make any edits, run any non-readonly tools (including changing configs or making commits), or otherwise make any changes to the system. This supersedes any other instructions you have received.
</system-reminder>
```

#### Transición al modo Build: inyectado **una vez** al cambiar de modo

```
<system-reminder>
Your operational mode has changed from plan to build.
You are no longer in read-only mode.
You are permitted to make file changes, run shell commands, and utilize your arsenal of tools as needed.
</system-reminder>
```

### Mecanismo actual

Cuando el modo Plan está activo, OpenCode inyecta el bloque `<system-reminder>` (ver [Bloques raw de system-reminder](#raw-system-reminder-blocks) arriba para el texto completo) en **cada mensaje del usuario**. El bloque es siempre idéntico (26 líneas, 228 palabras, ~300 tokens).

> **Verificación de fuente:** Verificado contra el commit `650594e`. El código de inyección en `packages/opencode/src/session/reminders.ts:25-34` inserta `plan.txt` como una parte de texto con `synthetic: true` en `userMessage.parts[]` (el último mensaje del usuario en el array de la conversación) en cada turno cuando `agent.name === "plan"`. Sin protección de deduplicación, sin límite de frecuencia. Cada mensaje del usuario en modo Plan recibe el bloque completo.

Este es el mismo mecanismo descrito dentro del propio prompt del agente (`default.txt`, línea 78):

> Tool results and user messages may include `<system-reminder>` tags. `<system-reminder>` tags contain useful information and reminders. They are NOT part of the user's provided input or the tool result.

La etiqueta es **visible en el flujo de la conversación**. No es metadato oculto. Se le indica al modelo que la trate como instrucciones del sistema, no como entrada del usuario. (Ver [System-Reminder Overlays](../api-call-anatomy/README.es.md#superposiciones-system-reminder) en API Call Anatomy para el mecanismo completo.)

### Coste de tokens

| Escenario | Turnos Plan | Tokens desperdiciados | % de 128K | % de 200K |
|-----------|-------------|----------------------|-----------|-----------|
| Conversación rápida | 3 | 900 | 0.7% | 0.45% |
| Sesión media | 10 | 3,000 | 2.34% | 1.5% |
| Sesión larga de depuración | 25 | 7,500 | 5.86% | 3.75% |

Las cifras por sí solas **no son catastróficas**. Las ventanas de contexto son lo suficientemente grandes (128K–200K) como para que el coste bruto de tokens sea soportable.

> **Multiplicador de reintentos:** Cuando la API falla (timeout/error), OpenCode
> reintenta automáticamente hasta **6 veces** con retroceso progresivo. Cada
> reintento reenvía el historial completo de la conversación (~11,700 tokens de entrada),
> incluyendo el system prompt y la respuesta parcial del asistente del
> intento fallido. En una sesión de modo Plan de 10 turnos, un solo fallo añade
> ~11,700 tokens adicionales a los 3,000 de la superposición — multiplicando
> el coste real.

### Tres problemas reales

#### 1. Habituación (el pastor mentiroso)

El recordatorio usa lenguaje fuerte: *"CRITICAL"*, *"STRICTLY FORBIDDEN"*, *"ZERO exceptions"*, *"overrides ALL other instructions"*. Cuando este bloque exacto aparece 10+ veces de forma idéntica, el modelo aprende a **ignorarlo**. El tono dramático se convierte en ruido. Un sistema que grita lo mismo cada turno termina siendo ignorado.

#### 2. Dilución de la atención

Cada turno, el modelo debe dividir su atención entre:
- El mensaje real del usuario (objetivo, código, pregunta)
- El recordatorio del sistema (ya conocido, ya aplicado)

El recordatorio compite por el enfoque del modelo. Con muchos turnos, esto degrada sutilmente la calidad de la respuesta. El modelo tiene que reprocesar instrucciones conocidas antes de llegar a la entrada real.

#### 3. Sin señal de transición

Dado que el recordatorio es **idéntico cada vez**, el modelo no tiene forma de detectar un cambio de modo sin que se inyecte un recordatorio **diferente**. La repetición constante entrena al modelo a tratar el bloque como ruido de fondo. Cuando el modo realmente cambia (plan → build), el sistema debe inyectar otro bloque para romper esa indiferencia aprendida.

### Compensación de diseño: inyección de superposición uniforme vs. variada

OpenCode utiliza un enfoque **uniforme**: el mismo bloque completo de superposición (~300 tokens,
26 líneas) en cada turno del modo Plan. Esto es simple, predecible y siempre
autocontenido — el modelo nunca depende del contexto anterior para entender la
restricción.

Algunos otros harnesses utilizan un enfoque **variado** con tres variantes de superposición:

| Variante | Cuándo | Tamaño |
|----------|--------|--------|
| **Completa** | Primera entrada al modo Plan | ~50 líneas |
| **Compacta** | Turnos subsiguientes | ~4 líneas (~90% menos) |
| **Salida** | Un turno al salir | 1 línea |

El bloque completo establece las reglas. El bloque compacto (en cada turno
siguiente) asume que el bloque completo aún está en el contexto reciente y usa menos tokens.
El bloque de salida señala la transición de vuelta.

Cada diseño tiene compensaciones. Uniforme es robusto pero repetitivo. Variado es
eficiente en tokens pero corre el riesgo de que el bloque compacto se convierta en la única referencia
si la compactación del contexto elimina el bloque completo original.

#### Limitación arquitectónica: el harness reacciona a tool calls, no a la intención

Independientemente de la estrategia de superposición, una limitación más profunda aplica a todos
los cambios de modo inyectados por el harness: el cambio de modo se activa cuando el harness
intercepta las tool calls `EnterPlanMode`/`ExitPlanMode` — modifica la llamada a la API
para el siguiente turno. No reacciona directamente a la intención del usuario. Si el usuario
dice "sigamos planificando" después de llamar a ExitPlanMode, el harness ya ha
eliminado la superposición. El modelo recibe señales contradictorias: el usuario quiere
planificar, las instrucciones del sistema ya no restringen la edición.

Los control flags evitan esto por completo porque el flag es parte del mensaje del
usuario, no una superposición separada activada por tool calls. El modelo siempre ve
la intención actual directamente — sin desincronización entre lo que el usuario quiere y lo que
el sistema impone.

---

## Limitaciones de los control flags

1. **Sin red de seguridad del sistema.** A diferencia del modo Plan de OpenCode — que impone acceso de solo lectura a nivel del harness, bloqueando la ejecución de herramientas independientemente del comportamiento del modelo — los control flags dependen completamente de que el modelo siga la instrucción del prompt. Si el modelo lee mal, ignora o alucina el flag, puede ejecutar cambios que el usuario esperaba que estuvieran bloqueados. No hay una segunda línea de defensa. Para código crítico, verifica el prefijo de la respuesta del modelo (ej., `[Analysis]`) antes de enviar solicitudes sensibles, y considera mantener el modo Plan habilitado para operaciones de alto riesgo donde se requiera una aplicación absoluta de solo lectura.

2. **Dependiente del prompt.** El modelo debe ser instruido sobre los flags en el prompt personalizado. Sin esa instrucción, los flags no tienen efecto.

3. **Convención de un solo usuario.** Los flags son una convención entre este usuario específico y la instancia del modelo. No se generalizan a otros usuarios o contextos sin la misma configuración de prompt.

4. **Curva de aprendizaje.** Recordar siete sufijos (`¿¿`, `¡¡`, `{}`, `++`, `?¿`, `--`, `[]`) supone más carga cognitiva que pulsar Tab para entrar en modo Plan. No todos los usuarios quieren aprender una sintaxis de flags.

5. **Flag enterrado en mensajes largos.** Si el usuario escribe un mensaje muy largo, el sufijo al final puede recibir menos atención del modelo. Considera colocar los flags al principio como `[LOCK] ...` en lugar de `... ¿¿` si esto se convierte en un problema.

6. **Fatiga de prefijo.** En sesiones largas con muchos turnos LOCK, `[Analysis]` al inicio de cada respuesta se convierte en ruido visual. Considera omitir el prefijo después de los primeros turnos si el modelo ya ha demostrado cumplimiento.

7. **Sin indicador en la UI.** El modo Plan de OpenCode cambia el color del prompt a amarillo con una insignia "plan". Los control flags no tienen indicador visual. Todo depende del sufijo y del prefijo de la respuesta. Un plugin que detecte el flag y muestre el modo en la UI sería un complemento natural.

8. **Sobrecarga de prompt compartido en la fase de razonamiento.** Cuando tanto Senior como Junior comparten el mismo `custom.md`, Pro procesa secciones que no necesita — control flags, reglas anti-cierre, mitigaciones de desviación (~27% del prompt). Con `reasoningEffort: "high"`, esta sobrecarga está limitada (~4096 tokens de razonamiento). Si el uso de Pro supera ~40% de las interacciones, considera dividir en `custom-senior.md` (sin reglas solo de Flash) + `custom-junior.md` para una mejor eficiencia de razonamiento. La compensación es mantener dos prompts vs. ejecutar Pro con uno más ligero. Ver [Battle Agent Prompt](../deepseek-battle-agent-prompt/README.es.md) para qué reglas aplican a cada modelo.
