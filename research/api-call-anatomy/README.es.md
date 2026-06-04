# Anatomía de la Llamada API: Cómo OpenCode se Comunica con los Modelos de Lenguaje

Un documento de referencia que explica la estructura de las llamadas API desde OpenCode
a los modelos de lenguaje.

**Contenido**

  - [1. La Llamada API en Tres Partes](#1-la-llamada-api-en-tres-partes)
    - [El Parámetro `system`](#el-parámetro-system)
    - [El Array `messages`](#el-array-messages)
    - [El Array `tools`](#el-array-tools)
    - [Parámetros Adicionales](#parámetros-adicionales)
    - [Ejemplo Completo de Petición](#ejemplo-completo-de-petición)
  - [2. Ensamblado del System Prompt](#2-ensamblado-del-system-prompt)
    - [Componentes](#componentes)
    - [Resolución de Custom Prompt](#resolución-de-custom-prompt)
    - [Instrucciones desde AGENTS.md](#instrucciones-desde-agentsmd-tres-niveles-dos-mecanismos-de-inserción)
    - [Descripciones de Skills en el System Prompt](#descripciones-de-skills-en-el-system-prompt)
  - [3. Configuración de Agentes](#3-configuración-de-agentes)
    - [Sobrescribiendo Prompts de Sub-agentes Integrados](#sobrescribiendo-prompts-de-sub-agentes-integrados)
  - [4. El Array Messages en Profundidad](#4-el-array-messages-en-profundidad)
    - [Roles de los Mensajes](#roles-de-los-mensajes)
    - [Superposiciones System-Reminder](#superposiciones-system-reminder)
  - [5. Definiciones de Tools](#5-definiciones-de-tools)
    - [Estructura](#estructura)
    - [Registro y Filtrado](#registro-y-filtrado)
    - [Sobrescritura de Descripciones de Tools](#sobrescritura-de-descripciones-de-tools)
  - [6. Autoridad de Instrucciones y Estrategia](#6-autoridad-de-instrucciones-y-estrategia)
    - [Espectro de Autoridad](#espectro-de-autoridad)
    - [Comparación](#comparación)
    - [Guías Prácticas](#guías-prácticas)
    - [Estrategia de Presupuesto de Tokens](#estrategia-de-presupuesto-de-tokens)

---

## 1. La Llamada API en Tres Partes

Cada llamada API de OpenCode a un modelo de lenguaje tiene tres componentes
estructurales:

| Componente | Rol | Ubicación en HTTP |
|------------|-----|-------------------|
| **System** | Instrucciones, identidad, contexto del entorno, catálogo de skills | Campo raíz `system` (string) |
| **Messages** | Historial de la conversación | Campo raíz `messages` (array) |
| **Tools** | Definiciones de funciones que el modelo puede invocar | Campo raíz `tools` (array) |

Esta estructura es invariante entre providers y harnesses. Es la única
puerta de entrada al modelo. Cualquier influencia en el comportamiento
(instrucciones, restricciones, personalidad) debe pasar por uno de estos
tres canales.

Adicionalmente, se envían parámetros específicos del modelo como campos raíz:

| Parámetro | Ejemplo | Propósito |
|-----------|---------|-----------|
| `model` | `"deepseek/deepseek-v4-pro"` | Identifica el modelo destino |
| `max_tokens` | `8192` | Límite de longitud de la respuesta |
| `stream` | `true` | Habilitar respuesta en streaming |
| `thinking` | `{"type": "enabled"}` | Habilitar modo de pensamiento (API Anthropic) |
| `temperature` | `0.7` | Temperatura de muestreo (no se envía cuando thinking está activado) |
| `top_p` | `0.9` | Muestreo nucleus (no se envía cuando thinking está activado) |

### El Parámetro `system`

El parámetro `system` es una cadena de texto plano que contiene el system
prompt. Se ensambla a partir de múltiples componentes (ver [Ensamblado del
System Prompt](#2-ensamblado-del-system-prompt)) y se envía como una única
cadena UTF-8.

En la capa del SDK, los segmentos se asignan a objetos `{role: "system"}`,
luego el Vercel AI SDK (`@ai-sdk/*`) los convierte a un campo raíz `system`
para APIs compatibles con Anthropic, o los mantiene como mensajes de sistema
para APIs compatibles con OpenAI.

### El Array `messages`

El array messages contiene el historial completo de la conversación. El
formato varía según el provider: la capa SDK de OpenCode normaliza
internamente y convierte al formato wire del provider destino:

**Estilo OpenAI** (usado por OpenAI, la mayoría de modelos compatibles, y la
representación interna del SDK):

```json
[
  {"role": "user",      "content": "..."},
  {"role": "assistant", "content": "..."},
  {"role": "tool",      "content": "...", "tool_use_id": "..."},
  {"role": "user",      "content": "..."}
]
```

**Estilo Anthropic** (usado por la API de Anthropic: las llamadas a
tools usan `type: "tool_use"` en assistant, los resultados de tools usan
`role: "user"` con `type: "tool_result"`):

```json
[
  {"role": "user",      "content": [{"type": "text", "text": "User message"}]},
  {"role": "assistant", "content": [
    {"type": "text", "text": "I'll look that up."},
    {"type": "tool_use", "id": "tu_123", "name": "glob", "input": {"pattern": "*.txt"}}
  ]},
  {"role": "user",      "content": [{"type": "tool_result", "tool_use_id": "tu_123", "content": "file.txt"}]},
  {"role": "user",      "content": [{"type": "text", "text": "Next question"}]}
]
```

El SDK convierte entre estos formatos de forma transparente. El resto de
este documento se refiere al estilo OpenAI por simplicidad.

> **Importante**: Los mensajes `role: "tool"` (estilo OpenAI) o `type: "tool_result"`
> (estilo Anthropic) contienen **resultados de tools**: la salida devuelta
> después de que una tool se ejecuta. Son distintos del **array `tools`**
> (campo raíz), que contiene **definiciones de tools**: los esquemas de
> función que el modelo usa para decidir qué tool invocar. Definiciones y
> resultados son datos separados que casualmente comparten nombre; aparecen
> en diferentes partes de la llamada API.

Cada turno añade: mensaje de usuario → respuesta del asistente (texto +
tool calls) → resultados de tools. El historial completo se envía en cada
petición.

Los mensajes también pueden contener etiquetas `<system-reminder>`: partes
de texto sintético inyectadas por la lógica de cambio de modo (ver
[Superposiciones System-Reminder](#superposiciones-system-reminder)).

### El Array `tools`

Las tools se serializan como:

```json
[
  {
    "name": "glob",
    "description": "Find files matching a glob pattern...",
    "input_schema": {
      "type": "object",
      "properties": {
        "pattern": {"type": "string"},
        ...
      },
      "required": ["pattern"]
    }
  }
]
```

El modelo usa estas definiciones para decidir qué tool invocar y con qué
argumentos. Las tools se registran, se filtran por capacidad del
modelo/provider, y se serializan para cada petición.

### Parámetros Adicionales

Más allá de los tres componentes estructurales, cada petición incluye
parámetros que controlan el comportamiento de inferencia:

| Parámetro | Propósito | Notas |
|-----------|-----------|-------|
| `max_tokens` | Máximo de tokens en la respuesta | Límite duro |
| `stream` | Habilitar respuesta en streaming | `true` / `false` |
| `thinking` / `extended_thinking` | Habilitar modo de razonamiento | Específico del provider (ver abajo) |
| `temperature` | Temperatura de muestreo | Desactivado cuando thinking está activo (ver abajo) |
| `top_p` | Muestreo nucleus | Desactivado cuando thinking está activo (ver abajo) |
| `stop` | Secuencias de parada | Raramente usado |

Estos valores se fusionan desde la configuración del agente, los valores
por defecto del provider, y el mapeo interno de OpenCode
(reasoningEffort → parámetros de thinking).

#### Modo Thinking / Reasoning

Cuando el modo thinking está activado (por defecto para modelos
soportados):

- `temperature` y `top_p` **no se envían** en la petición API
- DeepSeek Anthropic API: `thinking: {type: "enabled"}` o
  `thinking: {type: "enabled", budget_tokens: 4096}`
- El modelo produce un bloque de pensamiento seguido de la respuesta visible
- `reasoningEffort` de la configuración de OpenCode se mapea a parámetros
  de thinking específicos del provider

Mapeo de configuración para `reasoningEffort`:

| Valor OpenCode | DeepSeek Anthropic API |
|----------------|------------------------|
| `"low"` | `thinking: {type: "enabled", budget_tokens: 1024}` |
| `"medium"` | `thinking: {type: "enabled", budget_tokens: 2048}` |
| `"high"` / `"max"` | `thinking: {type: "enabled", budget_tokens: 4096}` o ilimitado |

#### Temperature y Top-P

- Solo se aplican cuando el modo thinking está **desactivado**
- Cuando thinking está activado, el modelo ignora temperature/top_p
- Valores por defecto: temperature `0.7`, top_p `0.9` (varía según provider)

#### Diferencias entre Providers

| Aspecto | Anthropic Messages API | OpenAI API | Google API |
|---------|------------------------|------------|------------|
| System prompt | Campo raíz `system` | Array de `{role: "system"}` messages | Campo `system_instruction` |
| Thinking | `thinking: {type: "enabled"}` | `reasoning_effort` | N/A |
| Formato de tools | `input_schema` | `parameters` | `parameters` |
| Modelos soportados | Claude | GPT-4, GPT-4o, o1, o3 | Gemini |

OpenCode normaliza estas diferencias a través de la capa de provider
para que el resto del sistema use una interfaz consistente.

---

### Ejemplo Completo de Petición

La misma sesión produce diferentes formatos wire dependiendo del provider.
OpenCode usa el formato **OpenAI-compatible** por defecto para la mayoría
de providers (incluyendo DeepSeek y el tier gratuito de OpenCode); el
formato Anthropic Messages API se usa para los modelos del provider Anthropic.

**API OpenAI-compatible** (por defecto para la mayoría de providers, incluyendo DeepSeek):

```
POST https://api.deepseek.com/v1/chat/completions
```

```json
{
  "model": "deepseek-v4-pro",

  "messages": [
    {"role": "system", "content": "Context and environment\n...\n\nIdentity and style\n..."},
    {"role": "user", "content": "User's message content here"}
  ],

  "tools": [
    {
      "type": "function",
      "function": {
        "name": "glob",
        "description": "Find files and directories using glob patterns...",
        "parameters": {
          "type": "object",
          "properties": {
            "pattern": {"type": "string"}
          },
          "required": ["pattern"]
        }
      }
    }
  ],

  "max_tokens": 8192,
  "stream": true
}
```

**Anthropic Messages API** (usada para modelos del provider Anthropic):

```
POST https://api.anthropic.com/v1/messages
```

```json
{
  "model": "claude-sonnet-4-5",

  "system": "Context and environment\n...\n\nIdentity and style\n...",

  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "User's message content here"
        }
      ]
    }
  ],

  "tools": [
    {
      "name": "glob",
      "description": "Find files and directories using glob patterns...",
      "input_schema": {
        "type": "object",
        "properties": {
          "pattern": {"type": "string"}
        },
        "required": ["pattern"]
      }
    }
  ],

  "max_tokens": 8192,
  "stream": true,
  "thinking": {
    "type": "enabled"
  }
}
```

---

## 2. Ensamblado del System Prompt

### Componentes

El system prompt se construye a partir de hasta cuatro segmentos que se
ensamblan en una única cadena:

| # | Segmento | Origen | Influencia |
|---|----------|--------|------------|
| 1 | **Agent prompt** | [`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt) (integrado) o `{file:custom.txt}` | **Alta**: define identidad, tono y reglas de comportamiento |
| 2 | **Bloque de entorno** | Directorio de trabajo, plataforma, fecha, estado de git | Baja: solo metadatos de sesión |
| 3 | **Instrucciones desde archivos** | `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md` (obsoleto) en el worktree (ver [agents_md-danger](../agents_md-danger/README.es.md) para riesgos) | **La más alta**: sobrescribe el agent prompt cuando está presente |
| 4 | **Catálogo de skills** | Nombre + descripción de cada skill instalada | Media: puede sesgar al modelo mediante el texto de descripción |

El agent prompt es el segmento más grande. Puede ser el
[`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)
integrado (o
[`anthropic.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/anthropic.txt),
[`gpt.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/gpt.txt),
etc. según el modelo) o un custom prompt proporcionado por el usuario
mediante la directiva `{file:...}`.

Los cuatro segmentos se ensamblan en una única cadena, se procesan por el
hook del plugin `system.transform`, y el Vercel AI SDK los convierte al
formato esperado por cada provider (campo raíz `system` para APIs
compatibles con Anthropic, mensajes de sistema para APIs compatibles con
OpenAI). El prompt completo se reconstruye en cada iteración del bucle de
razonamiento: no se cachea entre turnos.

### Resolución de Custom Prompt

La directiva `{file:...}` en `opencode.jsonc` se resuelve durante la carga
de configuración, **antes** del parseo y validación JSON. El archivo se lee
una vez al inicio y su contenido se inserta como cadena literal en el valor
de configuración.

| Situación | Resultado |
|-----------|-----------|
| `"prompt": ""` o indefinido | OpenCode usa `default.txt` integrado para el modelo |
| `"prompt": "{file:existent.txt}"` | Custom prompt cargado correctamente |
| `"prompt": "{file:missing.txt}"` | **OpenCode no arranca**: `InvalidError` fatal, sin degradación gradual |

Detalles críticos:

- **Caché infinita**: `substitute()` cachea el resultado permanentemente.
  El archivo se lee una vez al inicio. Los cambios requieren un reinicio
  completo de OpenCode; una nueva sesión NO es suficiente.
- **Sin fallback ante archivo faltante**: `{file:...}` no es opcional. Si
  la ruta no existe, OpenCode falla con `InvalidError`. Sin valor por
  defecto, sin prompt vacío, sin degradación gradual.
- **Ámbito**: Funciona en campos string de `opencode.jsonc` pero no en
  archivos `.md` de agente independientes. En archivos `.md`, `{file:...}`
  permanece como cadena literal (issue #26434).

### Instrucciones desde AGENTS.md: Tres Niveles, Dos Mecanismos de Inserción

AGENTS.md (y sus variantes CLAUDE.md, CONTEXT.md: obsoleto) puede existir
en tres niveles, cada uno con diferentes reglas de descubrimiento:

| Nivel | Ubicación | Descubierto por | Dónde aparece |
|-------|-----------|-----------------|---------------|
| **Global** | `~/.config/opencode/AGENTS.md` | Inicio de sesión | Segmento del system prompt |
| **Raíz del proyecto** | Directorio raíz del proyecto (encontrado via `findUp`) | Inicio de sesión | Segmento del system prompt |
| **Subdirectorio** | Cualquier subdirectorio del proyecto | Mecanismo por-lectura | `<system-reminder>` en salida de tool |

OpenCode carga estos archivos a través de dos rutas independientes:

**1. Permanente: al inicio de la sesión**

Busca en dos niveles:
- Global: `~/.config/opencode/AGENTS.md` (si existe)
- Proyecto: el AGENTS.md más cercano subiendo desde el directorio de trabajo
  hasta la raíz del worktree. Solo se carga la primera coincidencia: NO
  acumula ancestros.

El resultado se inyecta como un segmento en el system prompt, etiquetado
como `"Instructions from: /path/to/AGENTS.md"`.

Controlado por:
- `OPENCODE_DISABLE_PROJECT_CONFIG=true`: bloquea el escaneo a nivel de proyecto
- `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true`: elimina CLAUDE.md de la búsqueda

**2. Por-lectura: en cada llamada a la tool `read`**

Se ejecuta cada vez que el modelo llama a `read`. Sube desde el directorio
del archivo destino hacia el directorio de trabajo (excluido), buscando
AGENTS.md/CLAUDE.md/CONTEXT.md (obsoleto) en cada subdirectorio:

```typescript
// Pseudocode: walk up from target file toward project root
for each directory from target to (but not including) project root:
  if AGENTS.md found here and not already loaded:
    inject as <system-reminder> at the end of the tool output
```

Este mecanismo puede descubrir archivos AGENTS.md dentro de
**subdirectorios** que son invisibles para el escaneo de inicio de sesión.
NO busca en el directorio de trabajo en sí (el bucle excluye la raíz), por
lo que el AGENTS.md de la raíz del proyecto solo es capturado por el
mecanismo 1.

Cuando `OPENCODE_DISABLE_PROJECT_CONFIG` está activado, el AGENTS.md del
proyecto (mecanismo 1) se bloquea, pero los AGENTS.md de subdirectorios
encontrados via `read` (mecanismo 2) aún pueden aparecer.

**Implicación**: El mismo contenido de AGENTS.md puede aparecer en dos
lugares de la misma llamada API: una vez en el system prompt (del
mecanismo 1) y una vez como `<system-reminder>` en un resultado de tool
(del mecanismo 2). Esto causa duplicación si ambos mecanismos encuentran
el mismo archivo.

Para los riesgos de una mala gestión de AGENTS.md (información obsoleta,
inflado y autoridad duplicada), ver
[`agents_md-danger`](../agents_md-danger/README.es.md).

### Descripciones de Skills en el System Prompt

El catálogo de skills se produce formateando la lista de skills
disponibles. En modo verbose (usado en el system prompt), la salida es XML:

```typescript
// Verbose format (used in system prompt):
// <available_skills>
//   <skill>
//     <name>skill_name</name>
//     <description>Description text</description>
//     <location>URL or path</location>
//   </skill>
// </available_skills>
```

Cada skill se define mediante un archivo `SKILL.md` con frontmatter YAML.
Los campos `name` y `description` en ese frontmatter son la fuente de las
etiquetas `<name>` y `<description>` anteriores: se parsean al inicio y se
inyectan en el system prompt de cada llamada API. La etiqueta `<location>`
se genera automáticamente a partir de la ruta absoluta del archivo
`SKILL.md` descubierto, convertida a una URL `file://`. El cuerpo completo
de la skill (todo después del frontmatter) **no** está en el system prompt;
solo se carga cuando el modelo lee explícitamente el archivo.

Debido a que cada descripción de skill es visible en cada turno, esté
cargada o no, el campo de descripción puede influir en el modelo más allá
de su propósito previsto. Ver [`skill-desc-leak`](../skill-desc-leak/README.es.md)
para un análisis detallado y opciones de mitigación.

Cuando el modo verbose está desactivado, se usa un fallback en Markdown.

La lista de skills se filtra antes de formatear:
1. Las reglas de permiso eliminan skills con `"action": "deny"` para el agente
2. La variable de entorno `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` impide que
   las skills externas sean descubiertas

---

## 3. Configuración de Agentes

Toda llamada API se origina desde un **agente** definido en `opencode.jsonc`.
Los agentes son la unidad de configuración de más alto nivel: cada uno
agrupa un prompt, un modelo y un conjunto de permisos que juntos determinan
la llamada API completa:

| Campo de configuración | Efecto en la llamada API | Ejemplo |
|------------------------|--------------------------|---------|
| `prompt` | Se convierte en el segmento agent prompt dentro de `system` | `"{file:custom.txt}"` |
| `model` | Establece el parámetro `model` y el enrutamiento del provider | `"deepseek/deepseek-v4-pro"` |
| `options` | Parámetros específicos del modelo (temperatura, reasoning effort) | `{"reasoningEffort": "max"}` |
| `permissions` | Filtra tools y skills disponibles para este agente | `{"edit": "deny"}` |

OpenCode incluye agentes integrados (`build`, `plan`, `explore`, etc.)
y los usuarios pueden definir agentes personalizados. Cada agente recibe
una llamada API **completamente independiente**: diferente system prompt,
diferentes tools, diferente modelo. Cuando cambias de agente (por ejemplo,
con Tab), OpenCode construye la siguiente llamada API desde cero con la
configuración del nuevo agente.

```jsonc
{
  "agent": {
    "build":  { "prompt": "{file:custom.txt}", "model": "deepseek/deepseek-v4-flash" },
    "plan":   { "prompt": "{file:custom.txt}", "model": "deepseek/deepseek-v4-pro" },
    "senior": { "prompt": "{file:customs.txt}", "model": "deepseek/deepseek-v4-pro", "options": {"reasoningEffort": "max"} },
    "junior": { "prompt": "{file:customj.txt}", "model": "opencode/deepseek-v4-flash-free" }
  }
}
```

En la práctica, el modo Plan normalmente comparte el mismo prompt que el
modo Build (la diferencia de comportamiento proviene de la superposición
inyectada `<system-reminder>`, no de un archivo de prompt diferente).

Los agentes son el punto de entrada para personalizar las tres partes de
la llamada API: el system prompt proviene del `prompt` del agente, el
modelo y las opciones provienen del `model` + `options` del agente, y las
tools se filtran por los `permissions` del agente.

Notablemente, la identidad del agente en sí es **invisible** en la llamada
API: no hay ningún campo o etiqueta que indique qué agente la produjo. El
agente da forma a los tres componentes estructurales pero no deja rastro
explícito de su nombre o rol. Si la misma configuración se asigna a dos
agentes diferentes, sus llamadas API son indistinguibles.

### Sobrescribiendo Prompts de Sub-agentes Integrados

Los agentes y sub-agentes integrados (`explore`, `general`, `scout`,
`summary`, etc.) tienen prompts por defecto compilados en OpenCode
(por ejemplo,
[`explore.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/agent/prompt/explore.txt),
[`scout.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/agent/prompt/scout.txt);
`general` usa el prompt por defecto y no tiene archivo separado).
Puedes sobrescribirlos sin modificar el código fuente mediante dos métodos:

**1. Via `opencode.jsonc`**: define un agente con el mismo nombre:

```jsonc
{
  "agent": {
    "explore": { "prompt": "{file:custom-explore.txt}", "model": "deepseek/deepseek-v4-flash" }
  }
}
```

El custom prompt reemplaza completamente el prompt integrado para ese
sub-agente. Los permisos y el modelo también se pueden personalizar por
agente.

**2. Via archivos `.md`**: crea un archivo markdown en el directorio de
agentes:

```
~/.config/opencode/agents/explore.md
# or .opencode/agents/explore.md
```

```markdown
---
name: explore
model: deepseek/deepseek-v4-flash
permission:
  read: allow
  glob: allow
  grep: allow
---

# Explore Agent

Your custom prompt for the explore sub-agent...
```

OpenCode escanea `{agent,agents}/**/*.md` en sus directorios de
configuración al inicio. Si un archivo coincide con el nombre de un agente
integrado, la definición personalizada reemplaza completamente la
integrada: no es necesario tocar el código fuente.

> **Implicación crítica:** El system prompt personalizado del host **no**
> se propaga a los subagentes. Cada subagente construye su propio system
> prompt desde su propia configuración. Si el host tiene reglas
> personalizadas (identidad, tono, instrucciones de comportamiento), los
> subagentes no las verán a menos que se incluyan explícitamente en la
> descripción de la tarea.

Para un ejemplo práctico de cómo desactivar los agentes Plan/Build
integrados y reemplazarlos con el cambio de modelo Senior/Junior, ver la
[sección de cambio de modelo Senior/Junior en el documento de investigación
Control Flags](../control-flags-vs-plan-build/README.es.md).

---

## 4. El Array Messages en Profundidad

### Roles de los Mensajes

| Rol | Contenido | Cuándo | Formato |
|-----|-----------|--------|---------|
| `user` | Mensaje del usuario, o resultado de tool en formato Anthropic | En cada turno de usuario | OpenAI: `"content": "text"`; Anthropic: `"content": [{"type": "text"\|"tool_result", ...}]` |
| `assistant` | Respuesta del modelo (texto + tool_calls) | Después de cada respuesta API | OpenAI: `"content": "text"` + `tool_calls`; Anthropic: `"content": [{"type": "text"\|"tool_use", ...}]` |
| `tool` | Resultado de una ejecución de tool | Después de cada tool call | **Solo OpenAI**. Anthropic usa `role: "user"` con `type: "tool_result"` |
| `system` | Segmentos del system prompt (el SDK puede convertirlos a campo raíz) | Inicio de la conversación | OpenAI: `role: "system"`; Anthropic: campo raíz `system` |

### Superposiciones System-Reminder

Cuando el modo Plan está activo, OpenCode inyecta etiquetas
`<system-reminder>` en el **array messages**, no en el system prompt. El
mecanismo antepone el texto del recordatorio al último mensaje de usuario
en cada turno mientras el modo Plan está activo:

El texto del recordatorio (~300 tokens, 26 líneas) se antepone al último
mensaje de usuario en cada turno mientras el modo Plan está activo. Al
salir del modo Plan, se inyecta una vez un recordatorio diferente de una
sola línea.

Este es el único mecanismo que OpenCode usa para el cambio de modo: nunca
modifica el parámetro `system` durante una sesión.

Algunos harnesses usan una variante más refinada de la misma técnica con
tres variantes de superposición en lugar de un solo bloque repetitivo:

| Variante | Cuándo | Tamaño relativo |
|----------|--------|-----------------|
| **Completa** | Primera entrada al modo Plan | Base (100%) |
| **Compacta** | Turnos siguientes mientras el modo Plan está activo | ~8% de la completa |
| **Salida** | Un único turno al salir del modo Plan | ~2% de la completa |

El bloque completo establece las reglas y el flujo de trabajo. El bloque
compacto (insertado en cada turno siguiente) asume que el bloque completo
aún está en contexto y ahorra ~90% de tokens enviando solo un recordatorio.
El bloque de salida señala la transición de vuelta al modo normal.
Críticamente, el cambio de modo es activado por el harness al interceptar
las tool calls `EnterPlanMode`/`ExitPlanMode`: el harness modifica la
llamada API para el siguiente turno; no reacciona directamente a la
intención del usuario.

OpenCode, en contraste, envía el mismo bloque completo (~300 tokens, 26
líneas) en cada turno de modo Plan sin optimización de variantes.

---

## 5. Definiciones de Tools

### Estructura

Cada definición de tool en el array `tools` tiene tres campos:

```json
{
  "name": "tool_name",
  "description": "What the tool does and when to use it",
  "input_schema": {
    "type": "object",
    "properties": { ... },
    "required": [ ... ]
  }
}
```

El modelo decide qué tool invocar basándose en:
1. El **nombre** de la tool (debe ser único y descriptivo)
2. La **descripción** de la tool (texto libre, puede tener varios párrafos)
3. El **input_schema** de la tool (JSON Schema que define los argumentos válidos)

### Registro y Filtrado

Las tools se registran mediante el sistema de tools. Antes de cada petición,
las tools se filtran por capacidad del modelo/provider:

1. Algunas tools se deshabilitan por modelo (por ejemplo, la tool
   `question` se deshabilita para modelos sin soporte de salida
   estructurada)
2. Las reglas de permiso filtran tools por agente (por ejemplo, el agente
   explore solo tiene tools de solo lectura)
3. Las tools restantes se serializan en el array `tools`

| Tool | Notas |
|------|-------|
| `todowrite` | Descripción más grande: seguimiento de tareas |
| `shell` (bash) | Plantilla varía según provider |
| `task` | Delegación a subagentes: lista los tipos disponibles: `default`, `explore`, `general`, `junior`, `senior` |
| `edit` | |
| `read` | |
| `websearch` | |
| `webfetch` | |
| `grep` | |
| `question` | |
| `write` | |
| `glob` | |
| `skill` | Descripción más pequeña: carga de skills delegada a lectura manual |

Todas las descripciones de tools se envían en cada llamada API,
consumiendo tokens independientemente de si la tool se usa o no. Las tools
se registran y filtran dinámicamente por capacidad del modelo/provider
antes de la serialización.

La lista de tipos de agente que pueden ser lanzados como subagentes se
comunica al modelo mediante la descripción de la tool `task` y su
parámetro `subagent_type`. El modelo las lee para saber a qué agentes
puede delegar (`explore`, `general`, `senior`, `junior`, `default`). No
hay un campo API separado ni una sección del system prompt para los
subagentes disponibles: la descripción de la tool es el único canal.

Adicionalmente, las **tools MCP (Model Context Protocol)** pueden aparecer
en el array `tools` junto con las tools integradas. Las tools MCP se
definen externamente (mediante servidores MCP configurados en
`opencode.jsonc`) y se añaden al array durante el registro. Siguen el
mismo formato de serialización pero sus descripciones y esquemas provienen
del servidor MCP, no del registro de tools de OpenCode. A diferencia de
las tools integradas, las tools MCP no pueden sobrescribirse mediante el
hook del plugin `tool.definition`: el hook solo se activa para tools
registradas en el registro interno de OpenCode. Las tools MCP tampoco
aparecen en la tabla de tamaños de tools anterior; su tamaño depende de la
definición del servidor externo y puede variar significativamente entre
servidores.

### Sobrescritura de Descripciones de Tools

El plugin
[`opencode-tools-override`](https://github.com/anomalyco/opencode/tree/dev/plugins/opencode-tools-override)
reemplaza las descripciones de tools mediante el hook `tool.definition`:

```typescript
"tool.definition": async (input: { toolID: string }, output) => {
  const override = cache[input.toolID]
  if (override !== undefined) {
    output.description = override  // ← Replaces the description
  }
}
```

Las sobrescrituras se cargan desde archivos `.txt` en el directorio
`overrides/` del plugin y se cachean en memoria al inicio.

> **Restricción arquitectónica**: No hay un hook de plugin para el array
> `tools` en sí. Las tools se ensamblan por el registro después de que
> todos los hooks de plugin se ejecutan y se serializan como un campo HTTP
> separado (`tools` en el cuerpo JSON). Ni `messages.transform` ni
> `system.transform` pueden capturarlas o modificarlas. Para inspeccionar
> las definiciones crudas de tools, usa un proxy externo o el hook
> `chat.params` en el plugin de depuración.

---

## 6. Autoridad de Instrucciones y Estrategia

No todos los espacios de instrucción son iguales. Dónde colocas las reglas
de comportamiento afecta cómo las trata el modelo, cuánto cuestan en tokens
y con qué fiabilidad se siguen.

### Espectro de Autoridad

```
Baja autoridad                    Alta autoridad
─────────────────────────────────────────────────────>
Skill desc     System prompt    Tool desc    Tool override
(available_    (agent prompt)   (built-in)   (plugin)
 skills)
```

Hallazgo empírico del PoC Grillo: cuando la misma personalidad se colocó
en `available_skills` (descripción de skill), el modelo dudó. Cuando se
colocó en `glob.txt` (tool override via plugin), el modelo la adoptó sin
deliberación. El modelo trata las descripciones de tools como definiciones
autoritativas de lo que hace una tool: no las cuestiona.

### Comparación

| Ubicación | Costo en tokens | Autoridad | Mejor para |
|-----------|-----------------|-----------|------------|
| **System prompt** | Alto (texto completo, cada turno) | Media: compite con otras instrucciones | Identidad, tono, reglas de alto nivel, flujo cognitivo |
| **Tool description** (integrada) | Se envía cada turno como campo separado | **Alta**: definición autoritativa | Cuándo usar cada tool, comportamiento central, restricciones |
| **Tool description** (sobrescritura via plugin) | Misma que la integrada, sin costo extra | **La más alta**: misma autoridad, controlada por el usuario | Comportamientos personalizados, reglas de dominio específico, inyección de personalidad |
| **Skill description** (`available_skills`) | Alto (en el system prompt, cada turno) | Baja: "capacidad disponible", no instrucción | Descubrimiento: qué existe, no qué hacer |
| **skill.txt override** (plugin) | Mínimo (399B) | Alta: misma que tool override | Reglas detalladas cargadas bajo demanda, no siempre visibles |

### Guías Prácticas

**1. La identidad y el tono van en el system prompt.**

El system prompt define quién es el modelo. Mantenlo ligero: rol, idioma,
reglas prioritarias y flujo cognitivo. Cada línea más allá de eso es
desperdicio de tokens.

**2. Las reglas de comportamiento van en las descripciones de tools.**

Si quieres que el modelo haga algo de forma fiable (o que evite hacerlo),
pon la instrucción en la descripción de la tool relevante. El modelo lee
todas las descripciones de tools en cada turno y las trata como
autoritativas.

El plugin
[`opencode-tools-override`](https://github.com/anomalyco/opencode/tree/dev/plugins/opencode-tools-override)
permite reemplazar la descripción de cualquier tool con tu propio texto.
Esto es especialmente útil para la tool `skill`, donde una descripción
personalizada puede definir reglas de carga detalladas sin inflar el system
prompt.

**3. La referencia técnica detallada va en el contenido de la skill (cargado bajo demanda).**

El cuerpo completo de la skill (SKILL.md después del frontmatter YAML) NO
está en el system prompt. Se carga solo cuando el modelo invoca la tool
`skill` o lee el archivo manualmente. Este es el lugar adecuado para
material de referencia extenso.

### Estrategia de Presupuesto de Tokens

| Componente | Tamaño típico | Frecuencia | Costo |
|------------|---------------|------------|-------|
| System prompt (ligero, objetivo recomendado) | ~4K chars | Cada turno | Fijo |
| Descripciones de tools (12 tools) | ~26K chars total | Cada turno (como array tools) | Fijo por turno |
| Descripciones de skills (si son visibles) | ~3K chars | Cada turno (en el system prompt) | Evitable via `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` |
| Contenido de skill (cuerpo completo) | 10K+ chars | Solo cuando se carga | Bajo demanda |
| Superposiciones system-reminder | ~1.2K chars (~300 tokens) | Cada turno de modo Plan | Evitable via control flags |

Todos los tamaños en chars (el recuento de tokens varía según el modelo;
conversión aproximada: 1 token ≈ 4 chars).

**Recomendación**: Mantén el system prompt por debajo de 4K chars. Mueve
las reglas de comportamiento detalladas a las descripciones de tools
mediante sobrescrituras. Mantén las descripciones de skills neutralizadas
(variable de entorno). Carga el contenido completo de skills solo cuando
sea necesario.

---
