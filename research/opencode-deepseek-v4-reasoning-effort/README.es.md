# Reasoning Effort en DeepSeek V4 y OpenCode

**Fecha:** 2026-06-08
**Propósito:** Documentar el flujo del parámetro `reasoning_effort` desde la API de DeepSeek V4 hasta su integración con OpenCode, incluyendo el descubrimiento de que DeepSeek detecta agentes complejos mediante señales multifactoriales (tools + cabeceras), y que no existe un mecanismo de forzado independiente en el proxy Go.

A lo largo del documento se usa **RE** como abreviatura de *Reasoning Effort* (el bloque `REASONING_EFFORT_MAX` que DeepSeek inyecta en índice 0) y **P6** para referirse al mecanismo de detección de agentes complejos del API Gateway de DeepSeek.

---

## Contenido

1. [Resumen ejecutivo](#resumen-ejecutivo)
2. [Cómo funciona DeepSeek V4](#1-cómo-funciona-deepseek-v4)
3. [DeepSeek detecta agentes complejos (P6)](#2-deepseek-detecta-agentes-complejos-p6)
4. [Integración con OpenCode](#3-integración-con-opencode)
5. [Cómo verificarlo empíricamente](#4-cómo-verificarlo-empíricamente)
6. [Mapa de canales](#5-mapa-de-canales)
7. [Guía práctica](#6-guía-práctica)
8. [Drop thinking](#7-drop-thinking)
9. [Referencias](#8-referencias)

---

## Resumen ejecutivo

| Hecho | Implicación |
|-------|-------------|
| **Go y Zen fuerzan `"max"` siempre** | `reasoningEffort` en `opencode.jsonc` es ignorado en esos canales. El modelo siempre razona con profundidad máxima. |
| **API directa respeta el valor** | `"high"` ≠ `"max"` sin perfil de agente. |
| **DeepSeek detecta agentes complejos** | La combinación tools + cabecera `x-session-affinity` activa la detección. No se puede eludir desde el prompt. |
| **Dos fuentes de verdad (TUI vs jsonc)** | El TUI sobrescribe silenciosamente al jsonc. Seleccionar "Default" para recuperar el control. |
| **Solo se evalúa en el primer mensaje** | Cambiar `reasoningEffort` a mitad de sesión no tiene efecto. |

> **Si usas `opencode-go/*` (Go) o `opencode/*` (Zen):** el parámetro `reasoningEffort` no tiene efecto práctico. El modelo recibe el bloque `REASONING_EFFORT_MAX` siempre. Ver sección [Mapa de canales](#5-mapa-de-canales) para el desglose completo.

---

## 1. Cómo funciona DeepSeek V4

### 1.1 Las tres capas de control

El comportamiento de un modelo responde a tres capas, de las cuales solo una es controlable por el usuario:

| Capa | Quién controla | Visibilidad |
|------|---------------|-------------|
| 1. Alineamiento (RLHF, fine-tuning) | DeepSeek | Opaca |
| 2. Pre-prompt del proveedor | DeepSeek / proxy | Opaca. Se subdivide en: |
| 2a. API Gateway | DeepSeek | Analiza la request, puede modificar parámetros |
| 2b. Encoding pipeline | DeepSeek | Transforma mensajes al formato interno del modelo |
| 3. Agent prompt | El usuario | Visible y editable |

Este documento se centra en la **capa 2**: qué inyecciones introduce DeepSeek (y los proxies) antes de que el prompt llegue al modelo.

### 1.2 `reasoning_effort`: `"high"` vs `"max"`

DeepSeek V4 define dos niveles de `reasoning_effort`:

- **`"high"`** (default): no añade nada especial al prompt.
- **`"max"`**: inyecta un bloque de texto al inicio del prompt que instruye al modelo a razonar con la máxima profundidad.

El bloque inyectado (`encoding_dsv4.py`):

```
Reasoning Effort: Absolute maximum with no shortcuts permitted.
You MUST be very thorough in your thinking and comprehensively decompose
the problem to resolve the root cause, rigorously stress-testing your logic
against all potential paths, edge cases, and adversarial scenarios.
Explicitly write out your entire deliberation process, documenting every
intermediate step, considered alternative, and rejected hypothesis to ensure
absolutely no assumption is left unchecked.
```

### 1.3 Condiciones para la inyección

El bloque se inyecta cuando se cumplen **tres condiciones simultáneas**:

1. **Índice 0** — solo en el primer mensaje renderizado de la conversación.
2. **`thinking` activado** — el modo pensamiento debe estar habilitado (por defecto lo está).
3. **`reasoning_effort = "max"`** — no ocurre con `"high"` ni otros valores. `"low"` y `"medium"` se tratan como `"high"`; `"xhigh"` como `"max"` (documentación de DeepSeek).

El control de thinking se hace mediante `extra_body: {thinking: {type: "enabled/disabled"}}`. Si se deshabilita:
- No se genera `reasoning_content`
- `reasoning_effort` se ignora
- El modelo responde sin cadena de razonamiento

La detección de agentes complejos (sección 2) también requiere thinking activado. Sin thinking, no hay tools adicionales del proxy, por lo que el perfil de agente complejo no se completa.

---

## 2. DeepSeek detecta agentes complejos (P6)

### 2.1 Estructura del prompt ensamblado

```
[REASONING_EFFORT_MAX]          ← solo si max + thinking + índice 0
[BOS token]
[System prompt]
[Tools definitions]
[User messages]
```

### 2.2 El mecanismo de detección

DeepSeek afirma en su documentación:

> *"In thinking mode, the default effort is high for regular requests; for some complex agent requests (such as Claude Code, OpenCode), effort is automatically set to max."*

**Es correcto.** DeepSeek implementa esta detección en su API Gateway, antes del encoding. El pipeline `encoding_dsv4.py` no participa — es una función pura que solo depende del valor de `reasoning_effort` que recibe.

### 2.3 Señales que activan la detección

Mediante aislamiento progresivo se identificaron las señales que activan P6:

| Condición | ¿Activa P6? |
|-----------|:-----------:|
| Solo perfil básico | ❌ No |
| + Skills (mención a herramientas en system prompt) | ❌ No |
| + `x-session-affinity` | ❌ No |
| **+ Skills + `x-session-affinity`** | **✅ Sí** |
| + Tools (array JSON) + `x-session-affinity` | ✅ Sí |

**No son necesarias las tool definitions en el JSON.** La mera mención a "Skills" combinada con `x-session-affinity` activa la detección. DeepSeek reconoce el perfil semántico: identidad de agente + bloque de entorno + referencia a herramientas + cabecera de sesión.

`x-session-affinity` **no es una señal secreta ni específica de OpenCode.** Es un header estándar de enrutamiento HTTP usado por múltiples agentes conversacionales (OpenCode, Pi Coding Agent, Cloudflare Workers AI, entre otros) para mantener peticiones de una misma sesión en el mismo servidor backend. DeepSeek lo reconoce como indicador de que la request proviene de un agente con herramientas, no de una llamada API directa. No hay detección oculta de OpenCode — es una integración deliberada con el protocolo de agente conversacional estándar.

No se ha investigado cómo detecta DeepSeek a otros agentes.

### 2.4 Cómo se activa P6 en cada ruta

| Ruta | Perfil que activa P6 | P6 se activa |
|------|-----------------------|:------------:|
| OpenCode → Go | System prompt completo (skills) + headers OpenCode | ✅ Sí |
| OpenCode → deepseek directo | System prompt completo (skills) + headers OpenCode | ✅ Sí |
| Curl → Go (payload mínimo) | Proxy añade skills en system prompt + headers | ✅ Sí |
| Curl → API (payload mínimo) | Sin perfil de agente | ❌ No |
| Curl → API (skills + `x-session-affinity`) | Skills en system prompt + header | ✅ Sí |

### 2.5 El proxy Go completa el perfil, no modifica `reasoning_effort`

El proxy `opencode.ai/zen/go/v1` **no altera** el valor de `reasoning_effort`. Verificado enviando `"none"` — el valor pasó intacto y DeepSeek lo rechazó (`unknown variant 'none'`).

Lo que hace el proxy es **completar el perfil de agente complejo** cuando recibe un payload mínimo:
- Añade tool definitions por defecto (si `thinking` está activado y no hay tools): `web_search`, `web_scrape`, `image_generation`, `image_edit`, `code_interpreter`, `sleep`
- Añade cabeceras propias (`x-session-affinity`)

Cuando el cliente ya envía tools + cabeceras, el proxy las respeta. El comportamiento descrito aplica a cuentas de suscripción; cuentas temporales o sin coste pueden no activar P6.

---

## 3. Integración con OpenCode

### 3.1 Dónde se configura `reasoningEffort`

- **`opencode.jsonc`**: `agent.<name>.options.reasoningEffort` (versionado en git)
- **Selector TUI**: persiste en `~/.local/state/opencode/model.json`

Precedencia: `base` (catálogo) → `model.options` → `agent.options` (jsonc) → `variant` (TUI).

### 3.2 Dos fuentes de verdad silenciosas (P1)

El TUI nunca consulta el jsonc. Guarda la última selección en `model.json`. Una vez usado, todas las sesiones futuras ignoran el jsonc sin indicación visual.

**Solución:** seleccionar "Default" en el TUI para que el jsonc recupere el control.

### 3.3 Solo se evalúa en el primer mensaje (P2)

DeepSeek solo evalúa `reasoning_effort` en índice 0. Cambiarlo a mitad de sesión no tiene efecto.

---

## 4. Cómo verificarlo empíricamente

> Esta sección describe cómo verificar el comportamiento descrito. Si tu canal es Go o Zen, los tests con `"high"` devolverán `[YES]` aunque el encoding de DeepSeek diga lo contrario — eso confirma P6.

### 4.1 Herramientas de detección

| Archivo | Propósito |
|---------|-----------|
| `res/prefix_detection_prompt.md` | Detección binaria: ¿RE está presente? |
| `res/prefix_detection_prompt_v2.md` | Detección posicional: ¿dónde aparece? |
| `res/reasoning_effort_max.md` | Texto literal del bloque RE |

### 4.2 Procedimiento gold standard

1. Llamada curl directa a `api.deepseek.com` con `reasoning_effort: "high"` y payload mínimo:

```bash
curl -s https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "deepseek-v4-flash",
    "messages": [{"role":"user","content":"Does RE text appear? Answer YES or NO."}],
    "reasoning_effort": "high",
    "extra_body": {"thinking":{"type":"enabled"}}
  }'
```

2. Si responde `[NO]`, el endpoint base funciona correctamente.
3. Añadir progresivamente system prompt, tools, cabeceras, hasta identificar qué activa la detección.

---

## 5. Mapa de canales

| Canal | `"high"` | `"max"` | P6 se activa? | Notas |
|-------|:--------:|:-------:|:--------------:|-------|
| `api.deepseek.com` (payload mínimo) | ❌ No RE | ✅ Sí RE | ❌ No | El parámetro se respeta sin perfil de agente |
| `api.deepseek.com` (perfil OpenCode) | ✅ Sí RE | ✅ Sí RE | ✅ Sí | Perfil completo (skills) + `x-session-affinity` activan P6 |
| `opencode.ai/zen/go/v1` (Go suscripción) | ✅ Sí RE | ✅ Sí RE | ✅ Sí | Proxy completa el perfil |
| `opencode.ai/zen/v1` (Zen) | ✅ Sí RE | ✅ Sí RE | ❓ No determinado | Fuerza `"max"` (solo Flash) |
| OpenRouter | ❓ | ❓ | ❓ | No probado |

---

## 6. Guía práctica

### 6.1 Si se necesita control real sobre `reasoning_effort`

Para evitar que DeepSeek fuerce `"max"`, la request no debe tener perfil de agente complejo: sin tools, sin `x-session-affinity`, sin perfil OpenCode. Esto implica salir del ecosistema OpenCode (curl, otro cliente).

Con OpenCode, da igual el endpoint — DeepSeek detecta tools + cabeceras y fuerza `"max"`.

### 6.2 Intentos de atenuar RE desde el prompt

Se intentó eludir o atenuar RE desde el system prompt con dos estrategias:
- "IGNORE IT" + reglas de brevedad
- "Prioritize brevity over thoroughness"

**Ninguna funcionó.** El prefijo RE en índice 0 prevalece sobre cualquier instrucción posterior. No hay workaround desde el prompt.

### 6.3 Salvaguarda (opcional)

Si se incluyen directivas equivalentes a "Reasoning Effort: maximum" en el system prompt del agente, el modelo mantiene el comportamiento de razonamiento profundo aunque DeepSeek dejara de inyectar el bloque RE. Sin esas directivas en el prompt, no hay protección.

---

## 7. Drop thinking

DeepSeek implementa un mecanismo server-side (`_drop_thinking_messages()`) que elimina el `reasoning_content` de los mensajes assistant anteriores al último mensaje de usuario. El modelo solo ve su razonamiento del turno anterior.

**Condición de desactivación:** Si **algún** mensaje incluye la clave `"tools"` (definiciones de herramientas), `drop_thinking` se desactiva globalmente.

**Implicación para OpenCode:** El system prompt incluye tool definitions → `drop_thinking` desactivado siempre. El `reasoning_content` de todos los turnos se acumula, incrementando tokens en sesiones largas.

Es ortogonal a `reasoning_effort`: RE determina profundidad; drop thinking determina persistencia del razonamiento entre turnos.

---

## 8. Referencias

| Recurso | Descripción |
|---------|-------------|
| `res/prefix_detection_prompt.md` | Detección binaria rápida |
| `res/prefix_detection_prompt_v2.md` | Detección posicional |
| `res/reasoning_effort_max.md` | Texto literal del bloque RE |
| Código encoding DeepSeek V4 | `huggingface.co/deepseek-ai/DeepSeek-V4-Flash/blob/main/encoding/encoding_dsv4.py` |
| DeepSeek API Docs — Thinking Mode | `api-docs.deepseek.com/guides/thinking_mode` |
| DeepSeek API Docs — Context Caching | `api-docs.deepseek.com/guides/kv_cache` |
