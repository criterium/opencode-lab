# OpenCode shared agent prompts

Prompts de agente para [OpenCode](https://opencode.ai). Diseñado como un par técnico — profundidad sobre brevedad, honestidad sobre cortesía, niveles de certeza explícitos.

**Orientado a Linux.** El prompt referencia utilidades Linux (`pdftotext`, `chafa`, `jq`, `tree`, `xmllint`, etc.) y asume un entorno POSIX. En macOS/Windows puede ser necesario adaptar o instalar equivalentes.

**Probado en DeepSeek V4.** Estos prompts se han desarrollado y probado en modelos DeepSeek V4 (`deepseek-v4-flash`, `deepseek-v4-pro`). Pueden funcionar en otros modelos pero requerirán validación — espera ajustes en patrones de razonamiento, adherencia a herramientas y formato de salida.

## Características

| Característica | Descripción |
|----------------|-------------|
| **Profundidad adaptativa** | N1 (directo) para tareas mecánicas, N2 (estándar) con contexto, N3 (profundo) con análisis, alternativas y fundamentos para decisiones de diseño |
| **Certeza explícita** | `[C]` verificado con fuente, `[I]` inferido con razonamiento, `[S]` supuesto pendiente de validación — el agente marca lo que sabe vs lo que supone |
| **Autoevaluación** | Lista de verificación pre-entrega: alcance incompleto, suposiciones sin marcar, alternativas no documentadas, cierre prematuro, asentimiento acrítico, solución fácil sobre completa |
| **Edición segura** | verificación grep de unicidad antes de reemplazar, cambios pequeños, releer archivos destino, confirmación post-edición, relectura post-cambio en modificaciones estructurales |
| **Sin bucles de cierre** | El agente agota la tarea, presenta conclusiones y espera — sin "¿procedo?" en cada turno |

## Comparativa

Referencia upstream: [`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)

| Dimensión | Comportamiento por defecto del modelo | `default.txt` (upstream) | `default.md` (shared) |
|-----------|--------------------------------------|--------------------------|---------------------------|
| **Postura** | Complaciente — asiente, rara vez cuestiona | No especifica | **Par técnico crítico** — cuestiona premisas, disiente si toca. Jerarquía: Honestidad → No-destructividad → Profundidad → Claridad → Brevedad |
| **Cierre** | Propenso a "shall I proceed?", resumir lo hecho, preguntar "¿qué más?" | Sugiere "no unnecessary preamble" pero es débil, no lo prohíbe | **Prohibición explícita**: "¿sigo?", "¿aplico?", "¿procedo?", declarar trabajo listo. "Pregunta solo si necesitas decisión. Nunca para cerrar." |
| **Certeza** | No distingue verificado de inferido — suena seguro incluso cuando estima | No aborda | **Sistema [C][I][S]**: [C] fuente verificada, [I] inferencia con razonamiento, [S] supuesto. "No inventes APIs, URLs, documentación." |
| **Profundidad** | Uniforme — trata igual un rename que un diseño de arquitectura | No especifica niveles | **N1/N2/N3** + flag DEEP fuerza N3. N1 directo, N2 estándar, N3 con fundamentos + alternativas + comparación crítica. Calibración por tipo de tarea. |
| **Brevedad** | Tiende a respuestas comprimidas a menos que el contexto pida más | **≤4 líneas** obligatorio en la mayoría de respuestas | **Menor prioridad**: "nunca recortes análisis por ella". El nivel determina la extensión, no un límite fijo. |
| **Autoevaluación** | Ninguna — produce y entrega sin revisión | No aborda | **Lista de verificación** pre-respuesta: alcance, suposiciones sin [S], alternativas no documentadas, cierre prematuro, asentimiento acrítico, solución fácil. |
| **Edición** | Confía en su reemplazo — aplica el cambio y sigue | "Sigue convenciones del código"; "no añadir comentarios salvo que se pida" (vago) | **Protocolo de 9 pasos**: releer destino, verificar unicidad grep, oldString exacto (≥2 líneas contexto), post-edit check, cambio estructural → releer líneas editadas + 10 de contexto. Prefiere cambios pequeños. |
| **Error** | Reintenta el mismo enfoque si falla — sin protocolo de escalado | No aborda | **3 fallos consecutivos → stop, pide ayuda, propón enfoque radicalmente distinto.** Error de comportamiento → detente, re-evalúa, corrige patrón, no el archivo. **Tool call falla → no reintentar sin ajustar parámetros; leer error, identificar causa, corregir.** |
| **Búsqueda** | No valida falsos negativos — asume que 0 resultados = no existe | No aborda | **Grep sin resultados**: probar case-insensitive y subcadenas antes de declarar "no encontrado". **Salidas truncadas**: asumir más contenido si el corte es abrupto. **Archivos >500 L**: localizar con Grep antes de leer. |
| **Herramientas** | Secuencial por defecto; Task solo si el contexto es muy grande | "Prefiere Task para reducir contexto"; "paraleliza llamadas" (sugerido) | **Paralelismo obligatorio** para llamadas independientes. **Umbrales de delegación**: archivos >150 L, búsquedas >5 archivos o >3 dirs. Webfetch no verificado → delegar a sub-agente. |
| **Idioma** | Inglés | Inglés | Español / Inglés (archivos separados) |
| **Formato** | Markdown básico, explicaciones narrativas | GH-flavored markdown, `file_path:line_number` | GH-flavored markdown, `file_path:line_number`, estructura con secciones, análisis >30 L → resumen ejecutivo ≤5 L |

> La columna **Comportamiento por defecto del modelo** describe a **DeepSeek V4 Flash**. Cada modelo tiene su propio comportamiento innato. Si usas otro modelo, pregúntale directamente cómo se compara:

### Genera tu propia comparativa

Copia esta pregunta a tu modelo favorito (Claude, GPT, Gemini, Kimi, GLM, Qwen, etc.) para que genere su propia tabla comparativa con `default.md`:

> "Eres un asistente de IA. Primero, intenta inspeccionar tu propio system prompt para identificar si has recibido instrucciones previas del harness o la herramienta en la que te ejecutas. Si puedes, tenlas en cuenta para la comparativa.
>
> Luego lee el siguiente prompt e identifica las dimensiones en las que intenta modificar tu comportamiento — postura, profundidad, certeza, uso de herramientas, o cualquier otra que detectes.
>
> Para cada dimensión que identifiques, describe:
> - Tu comportamiento por defecto (cómo responderías sin ningún prompt)
> - Las instrucciones previas de tu harness (si son detectables)
> - Lo que este nuevo prompt te pide que hagas en su lugar
> - Si tu comportamiento por defecto ya cumple, cumple parcialmente, o entra en conflicto
>
> Añade cualquier dimensión que el prompt modifique pero que no habías considerado relevante antes de leerlo. Si encontraste instrucciones del harness, genera una tabla de 4 columnas; si no, usa 3 columnas.
>
> [Abre `prompt/shared/default.md` y pega aquí su contenido]"

El resultado será una tabla equivalente adaptada al modelo que uses, sin asumir el comportamiento de DeepSeek V4.

## Archivos

### Prompt principal

| Archivo | Idioma |
|---------|--------|
| `default.md` | Inglés |
| `default.es.md` | Español |

### Prompts de sub-agentes

| Archivo ES | Archivo EN | Rol |
|------------|------------|-----|
| `compaction.es.md` | `compaction.md` | Compresión de contexto de sesión |
| `explore.es.md` | `explore.md` | Exploración de código (Glob, Grep, Read) |
| `general.es.md` | `general.md` | Ejecución de tareas delegadas (procesamiento pesado, websearch no verificado) |

Los sub-agentes se configuran en `opencode.jsonc` con `mode: "subagent"`. El agente principal los invoca automáticamente mediante la herramienta `Task` cuando la tarea lo requiere.

## Uso

### Mediante `opencode.jsonc`

Referencia el archivo del prompt en la configuración del agente:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "prompt": "prompt/shared/default.es.md",
      "model": "opencode-go/deepseek-v4-flash"
    },
    "plan": {
      "prompt": "prompt/shared/default.es.md",
      "model": "opencode-go/deepseek-v4-pro"
    }
  }
}
```

`build` y `plan` son agentes incorporados. Solo hace falta sobrescribir los campos que se deseen (`prompt`, `model`, etc.) — el resto conserva sus valores por defecto.

Para configurar también los sub-agentes:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "prompt": "prompt/shared/default.es.md",
      "model": "opencode-go/deepseek-v4-flash"
    },
    "plan": {
      "prompt": "prompt/shared/default.es.md",
      "model": "opencode-go/deepseek-v4-pro"
    },
    "general": {
      "prompt": "prompt/shared/general.es.md",
      "mode": "subagent",
      "model": "opencode/deepseek-v4-flash-free"
    },
    "explore": {
      "prompt": "prompt/shared/explore.es.md",
      "mode": "subagent",
      "model": "opencode/deepseek-v4-flash-free"
    },
    "compaction": {
      "prompt": "prompt/shared/compaction.es.md",
      "model": "opencode-go/deepseek-v4-flash"
    }
  }
}
```

Los sub-agentes usan `mode: "subagent"`. El agente principal los invoca automáticamente mediante la herramienta `Task`. `compaction` es interno (se ejecuta automáticamente al compactar contexto) y no lleva `mode`.

Las rutas son relativas a la raíz del proyecto (donde está `opencode.jsonc`). Ejemplos de rutas en Linux:

| Ámbito | Ruta |
|---|---|
| Config de proyecto | `~/project/opencode.jsonc` |
| Config global | `~/.config/opencode/opencode.json` |
| Agente de proyecto | `~/project/.opencode/agent/build.md` |
| Agente global | `~/.config/opencode/agent/build.md` |

### Mediante archivo de agente

Crea `.opencode/agent/<nombre>.md`:

```markdown
---
description: Coding agent.
mode: primary
model: provider/model-id
---

```

Luego copia el contenido de `default.es.md` (o `default.md`) como cuerpo.

Esto funciona también para agentes incorporados — crea `.opencode/agent/build.md` o `.opencode/agent/plan.md` para sobrescribirlos.

### Mediante el skill Customizing opencode

OpenCode incluye un skill incorporado (`Customizing opencode`) que documenta todos los campos de configuración — `agent`, `prompt`, `model`, `permission`, `plugin`, `mcp`, etc. Se carga automáticamente cuando es relevante. Menciona "opencode config" o "opencode.json" en tu prompt y el skill mostrará su contenido.

Para que el agente realice la instalación por ti, pregúntale algo como:

> "Configura mi agente `build` para que use `prompt/shared/default.es.md` con el modelo `opencode-go/deepseek-v4-flash`, y mi agente `plan` con `prompt/shared/default.es.md` y el modelo `opencode-go/deepseek-v4-pro`."

El agente leerá el skill, validará contra el schema JSON y escribirá la configuración.

## Referencia de configuración

Para la lista completa de campos, tipos y valores por defecto, consulta el [JSON Schema de OpenCode](https://opencode.ai/config.json). OpenCode falla al arrancar si la configuración no es válida — valida antes de reiniciar.

## Tras los cambios

La configuración se carga una vez al iniciar. **Cierra y reinicia OpenCode** para que los cambios surtan efecto.
