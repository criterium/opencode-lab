# Sistema de memoria para asistentes de código

- [1. Problemas de no gestionar memoria](#1-problemas-de-no-gestionar-memoria)
- [2. Opción OpenCode: AGENTS.md](#2-opción-opencode-agentsmd)
- [3. Opción asistente analizado: memoria autónoma](#3-opción-asistente-analizado-memoria-autónoma)
- [4. Nuestra alternativa: memory-system](#4-nuestra-alternativa-memory-system)
- [5. Flujo de trabajo](#5-flujo-de-trabajo)
- [6. Comparativa de sistemas](#6-comparativa-de-sistemas)
- [7. Conclusión](#7-conclusión)

## 1. Problemas de no gestionar memoria

Sin persistencia entre sesiones, el modelo arranca cada conversación sin contexto del proyecto ni del usuario. Cada sesión es tabla rasa: convenciones, decisiones, preferencias y errores pasados se pierden. El usuario repite información, el modelo repite errores.

Las soluciones automatizadas (carga automática de instrucciones, escritura autónoma de memoria) resuelven la persistencia pero introducen tres problemas que empeoran con el tiempo:

- **Contaminación de contexto:** contenido que se carga en cada interacción aunque no sea relevante para la tarea actual. Infla tokens, diluye la atención.
- **Información obsoleta:** el contenido se acumula sin mecanismo de caducidad. El modelo trata reglas antiguas como vigentes. No hay forma de decir "esto ya no aplica".
- **Opacidad:** el usuario no sabe qué se está cargando ni qué guardó el modelo. Cuando el modelo hace algo inesperado, el contenido auto-cargado es una variable invisible.

## 2. Opción OpenCode: AGENTS.md

OpenCode no tiene memoria persistente nativa. Su alternativa más cercana son los `AGENTS.md`, cargados de dos formas:

- **System prompt permanente**: `~/.config/opencode/AGENTS.md` (global, siempre cargado) y raíz del proyecto (bloqueable con `OPENCODE_DISABLE_PROJECT_CONFIG`).
- **System reminder por lectura**: al leer un archivo, busca `AGENTS.md` ascendiendo por subdirectorios. Sin bloqueo posible.

El comando `/init` genera o actualiza `AGENTS.md` escaneando el proyecto. Su prompt ([`initialize.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/command/template/initialize.txt)) aplica el criterio "¿lo perdería un agente sin ayuda?". Si el archivo ya existe, lo mejora sin reescribirlo.

El problema: `/init` es un **índice de proyecto**, no memoria. Captura lo que hay en el código, no decisiones de diseño, preferencias ni contexto de sesiones. Además puede eliminar contenido añadido por el usuario si no puede verificarlo contra el código.

OpenCode también ofrece `instructions` en `opencode.json`, que acepta archivos `.md` estáticos como contexto. Alternativa a AGENTS.md, igualmente estática: el usuario configura, el modelo no escribe.

**Problemas específicos:**

| Problema | Consecuencia |
|----------|-------------|
| **Reflejo de ansiedad** | Editar AGENTS.md antes de cada sesión rompe la KV cache, aumentando latencia y coste |
| **Degradación** | `/init` mitiga al ejecutarse pero también puede eliminar contenido añadido por el usuario que no pueda verificar contra el código |
| **Dilución** | Cada línea compite por la atención del modelo en cada turno, incluso cuando es irrelevante |
| **Conflictos de autoridad** | Múltiples fuentes (global, proyecto, subdirectorio, custom prompt) sin jerarquía. El modelo elige sin criterio visible |
| **Superficie de ataque** | Cualquier archivo en el proyecto puede inyectar instrucciones al modelo sin que el usuario lo sepa |
| **Latencia invisible** | Cada byte extra en system prompt retrasa el primer token. La carga automática lo paga en cada turno |

Ver detalle completo en `../agents_md-danger/README.es.md`.

## 3. Opción asistente analizado: memoria autónoma

Análisis basado en un dump del system prompt (extracción en `../context-dump/prompts/prompt_1_dump.md`).

Dedica ~130 líneas (~54%) del system prompt a gestionar memoria autónoma. El modelo:

1. Decide qué información merece guardarse
2. Escribe archivos con frontmatter YAML (name, description, type)
3. Mantiene un índice (`MEMORY.md`) siempre cargado (~1.800 tokens)
4. Decide si una memoria previa es relevante
5. Verifica su propia validez

**Sin supervisión humana en ninguna fase.** El mismo modelo decide, escribe, indexa, recupera y verifica: circularidad total.

**Riesgos identificados:**

| Riesgo | Descripción |
|--------|-------------|
| Contaminación | MEMORY.md (~200 líneas, ~1.800 tokens) siempre cargado en cada interacción |
| Info obsoleta | Sin TTL ni validación externa |
| Error auto-reforzante | Memoria incorrecta → se lee en sesión futura → se refuerza |
| Falsa autoridad | El modelo confía en "lo que escribió antes" más que en verificar |
| Over-saving | Guarda contexto temporal como si fuera permanente |
| Opacidad total | El usuario no sabe qué se guardó ni dónde. Sin git, sin auditoría |
| Coste | ~1.800 tokens/llamada por el índice siempre cargado. Varía según modelo |

## 4. Nuestra alternativa: memory-system

Sistema manual, archivos planos, cero dependencias. El humano decide qué guardar, el modelo ejecuta.

Sin plugins, bases de datos, embeddings ni servidores. Dos componentes:

- **Un skill** (`SKILL.md`) con reglas para operadores `>>`/`<<`, diagnóstico y mantenimiento.
- **Instrucciones en el agent prompt** (`custom.md`): activan el skill al detectar `>>` o `<<`, y gestionan `{...}` para notas rápidas.

Skill en `~/.agents/skills/memory-system/SKILL.md`, instrucciones en el archivo de personalización del agente. Sin npm install, sin configuración extra en `opencode.json`, sin estado fuera de los archivos .md del proyecto. El sistema no depende de OpenCode: los archivos viajan con el proyecto, no con la herramienta.

> **TL;DR:** `>>` guarda, `<<` carga, `>> check` diagnostica, `>> update` mantiene, `>> clean` limpia tareas, `>>` ayuda.
> Archivos: `memory.md`, `todo.md`, `parck.md`, `memory/*.md`. Scopes: `./` | `*` | `./<ruta>`.

**Archivos:**

| Archivo | Rol |
|---------|-----|
| `memory.md` | Mapa del proyecto: reglas, contexto, índice de profundización |
| `todo.md` | Tareas pendientes con estado (⏳🔥✅❌) |
| `parck.md` | Notas personales capturadas durante la sesión |
| `memory/{slug}.md` | Profundización a demanda, referencias específicas |

**Operadores:**

| Operador | Función |
|----------|---------|
| `>>` | Help: muestra operadores disponibles, scopes y estado actual |
| `>> help` | Misma función que `>>` |
| `>> <scope>` | Si no hay contenido tras el scope, equivale a `>> <scope> check` |
| `>> <scope> <contenido>` | Capturar e integrar información en memoria |
| `>> <scope> check` | Diagnosticar calidad, cohesión y contradicciones (solo lectura) |
| `>> <scope> update` | Mantenimiento + cruce con sesión + compresión + regenera índice de `memory/` + modo dual (crea si no existe) |
| `>> <scope> update --dry-run` | Misma lógica sin ejecutar |
| `>> <scope> todo <texto>` | Añadir tarea pendiente (⏳) |
| `>> <scope> todo! <texto>` | Añadir tarea prioritaria (🔥) |
| `>> <scope> clean` | Eliminar tareas ✅ y ❌ de `todo.md`. Pregunta antes de borrar |
| `<<` | Atajo: equivale a `<< ./` |
| `<< [scope]` | Carga y muestra `memory.md` + `todo.md` del scope. Scope opcional (por defecto `./`). Sugiere archivos de `memory/` si la consulta los menciona. Señala entradas que no cumplen el criterio de admisión |
| `<< status` | Resumen para retomar: tareas pendientes, última actividad, entradas en memoria |
| `<< <scope> <término>` | Busca en `memory.md`, `memory/*.md` y `todo.md` del scope. Indica archivo de origen |
| `<< <scope> memory/<archivo>.md` | Lee directamente un archivo de `memory/` |
| `<< todo` | Muestra solo `todo.md` del scope activo (sin `memory.md`) |
| `<< parck` | Muestra solo `parck.md` del scope activo |
| `{texto}` | *(agent prompt)* Apunte rápido en `./parck.md`. Sin scopes, sin gestión del modelo |

### Ejemplo de uso

Una sesión típica con memory-system:

```
[Usuario] >> ./ El proyecto usa SQLite con WAL mode activado. No usar
          conexiones concurrentes sin PRAGMA journal_mode=WAL.

[Modelo]   Capturado en ./memory.md: "SQLite WAL mode"

[Usuario] >> ./ todo! Migrar queries legacy a SQLite

[Modelo]   Añadida tarea prioritaria a ./todo.md

[Usuario] << ./

[Modelo]   [carga ./memory.md y ./todo.md]
          Memoria cargada. 1 entrada, 1 tarea pendiente (🔥).
```

Cada `>>` requiere confirmación del usuario antes de escribir. `<<` solo carga, no modifica.

**Principios de diseño:**

1. **Bajo demanda.** 0 tokens hasta `<<`. No se carga nada automáticamente.
2. **Control explícito.** El humano ordena `>> contenido`. El modelo solo ejecuta.
3. **Archivos en el proyecto.** Viajan con git. Visibles, editables en cualquier editor.
4. **Sin capas.** Archivos .md planos. Sin DB, sin estado, sin plugins.
5. **Mantenimiento proactivo.** `>> update` comprime, archiva, reconcilia, regenera índice.
6. **Criterio de admisión.** Solo merece memoria lo que un agente perdería sin ayuda. Lo obvio del código, no.
7. **Prioridad de la sesión.** Sesión contradice memoria → la sesión prevalece.
8. **Conciliación acotada.** `>> update` solo verifica lo que la memoria menciona. Sin escaneo completo.
9. **Inversión de confianza.** Otros sistemas confían en el modelo y piden al humano verificar. Este confía en el humano y pide al modelo ejecutar.

> Los proyectos con más memoria atraen más captura: añadir a algo existente cuesta menos que empezar. La barrera real es el primer `>> contenido`.

**Ventajas y limitaciones:**

| Aspecto | Ventaja | Limitación |
|---------|---------|------------|
| Dependencias | Cero: sin plugins, DB, embeddings ni servidores | — |
| Control | Nada se escribe sin confirmación humana | Requiere disciplina: sin `>>` no hay memoria |
| Coste | 0 tokens hasta `<<` | `<<` carga memory.md (~200-600 tokens) |
| Mantenimiento | `>> check` + `>> update`: diagnostica, limpia, regenera índice | Sin alertas automáticas |
| Portabilidad | Archivos .md planos, viajan con git | Escala hasta cientos de entradas |
| Aprendizaje | 2 prefijos (`>>`, `<<`) con variantes específicas | — |

> Cada `<<` cuesta ~200-600 tokens. Una decisión no capturada puede costar sesiones enteras de redescubrimiento.

**Scopes:**

| Scope | Ruta memory.md | Ruta todo.md |
|-------|----------------|--------------|
| `./` | `./memory.md` (proyecto raíz) | `./todo.md` |
| `*` | `~/.agents/memory-system/memory.md` (cross-project) | `~/.agents/memory-system/todo.md` |
| `./<ruta>` | `./<ruta>/memory.md` (subdirectorio) | `./<ruta>/todo.md` |

El scope `*` (`~/.agents/memory-system/`) reemplaza AGENTS.md/CLAUDE.md globales con la misma estructura: `memory/`, `todo.md` y `memory/*.md` por proyecto. Acumula conocimiento compartido entre proyectos y funciona como `todo.md` global.

> **Permisos:** `*` escribe en `~/.agents/memory-system/`, fuera del worktree. Requiere configurar `external_directory` en `opencode.json` para acceso sin preguntas (ej: `"~/.agents/memory-system/*": "allow"`).

Los scopes de subdirectorio (`./<ruta>`) evitan sobrecargar el `memory.md` raíz con contenido secundario. En proyectos grandes, permiten cargar memoria de forma selectiva por módulo, con su propia `memory.md`, `todo.md` y `memory/` — aisladas de la raíz.

### Alternativas third-party

Existen plugins para OpenCode que añaden memoria persistente mediante búsqueda semántica o grafos de conocimiento.
Son más sofisticados pero requieren dependencias externas: modelos de embeddings, bases de datos vectoriales, Redis,
servidores MCP. Ninguno ofrece el control explícito ni la simplicidad de archivos planos bajo demanda.

## 5. Flujo de trabajo

memory-system divide el trabajo en tres fases: sesión, consolidación, y reentrada. Las sesiones son el vehículo para generar contenido; la memoria es donde ese contenido persiste.

### Inicio de sesión

Pregúntate: ¿esta tarea necesita contexto previo? Si es una tarea nueva sin relación con lo anterior, no cargar memoria. Si es continuación de trabajo previo, puedes usar `<< status` para un resumen rápido, o `<<` para cargar el acumulado completo. No hay contaminación automática — eliges cuándo, qué y cuánto cargas. Una sesión fresca puede empezar en blanco aunque haya meses de memoria acumulada.

### Durante la sesión

Cada hallazgo se captura con `>> contenido`. No todo merece memoria: si un agente lo encontraría por sí mismo (código, comandos, git), probablemente no. Solo lo que el código no puede decir — decisiones, porqués, preferencias, contexto que costó descubrir.

Las tareas pendientes se registran con `>> todo`, se priorizan con `>> todo!`, se limpian con `>> clean`. Las notas personales van a `./parck.md` vía `{...}` — apuntes rápidos sin scopes, independientes del sistema de memoria.

### Antes de compactación

Cuando la sesión se alarga y el contexto se acerca al límite, OpenCode fuerza una compactación automática. Si en ese momento `>> update` tiene cambios propuestos pero no confirmados, las propuestas se pierden.

Prevención: ejecutar `>> update` temprano, cuando la sesión aún es manejable, y confirmar los cambios. Después se puede seguir trabajando. La compactación posterior solo comprime la conversación, no los archivos de memoria — ya están actualizados en disco.

### Fin de sesión

Las sesiones son desechables. El valor de cada sesión se consolida en archivos: `memory.md`, `todo.md`, `parck.md`, `memory/*.md`. Puedes cerrar, archivar o borrar sesiones sin pérdida. Las sesiones son el taller donde se produce la memoria, no el almacén.

`>> clean` al cerrar y `<<` al retomar forman un ritual: las tareas pendientes marcan el punto de inicio de la próxima sesión.

### Sesión siguiente sobre el mismo proyecto

`<<` restaura el contexto acumulado. No necesitas recordar qué se dijo, qué se decidió ni qué quedó pendiente — la información útil ya fue capturada. Retomas el trabajo donde lo dejaste, sin depender del historial.

## 6. Comparativa de sistemas

| Dimensión | OpenCode AGENTS.md/init | Asistente analizado (auto-memory) | Memory-system (este) |
|-----------|-------------------|-----------------------------------|----------------------|
| Quién escribe | El usuario | El modelo | El humano (vía `>>`) |
| Dónde se guarda | AGENTS.md en proyecto + global `~/.config/opencode/` | En directorio externo con hash (oculto) | En proyecto: memory.md, todo.md, parck.md, memory/ |
| Alternativas estáticas | `instructions` en opencode.json (archivos .md) | No tiene | No tiene |
| Git | Sí (archivo del proyecto) | No | Sí |
| Cuándo se carga | Cada turno (automático) | MEMORY.md siempre; archivos bajo demanda | Solo con `<<` |
| Token overhead | Variable según tamaño | ~1.800 tokens constantes | 0 hasta `<<` |
| Control de calidad | `/init` impone calidad en generación; el archivo no se audita después | Ninguno (circular: el modelo se auto-verifica) | `>> check` + `>> update` |
| Exclusiones | En `/init` (guía de generación); AGENTS.md no tiene | Explícitas (código, git, fixes) | El humano decide (guía no vinculante) |
| Caducidad | `/init` la mitiga al ejecutarse (reconcilia con código); sin ejecución, ninguna | Ninguna | `>> update` archiva y comprime |
| Criterio de admisión | En `/init`: "¿lo perdería un agente sin ayuda?" | El modelo decide qué guarda | "¿Lo perdería un agente sin ayuda?" |
| Verificación contra código | Solo al ejecutar `/init` | El modelo se auto-verifica | `>> update` reconcilia con proyecto actual |
| Visibilidad para el usuario | Total (archivo visible) | Media-baja (directorio conocido pero fuera del proyecto, sin git) | Total (archivo visible) |
| Scopes | Un solo ámbito (proyecto) | Un solo ámbito (proyecto) | 3 scopes: proyecto, global, subdirectorio |
| Confianza en aportes del usuario | Puede podarlos sin aviso al regenerar | No aplica (el modelo decide todo) | Máxima: nada se modifica sin confirmación |
| Riesgo principal | Obsolescencia silenciosa | Circularidad + opacidad | Dependencia de disciplina humana |

## 7. Conclusión

`/init` + AGENTS.md no es un sistema de memoria; es un **índice de proyecto**. Escanea el código, registra lo que hay. No captura porqués, descartes ni preferencias del usuario. Cada ejecución produce un snapshot del disco, sin contexto de sesiones. Y puede eliminar contenido añadido por el usuario sin aviso.

El asistente analizado es autónomo pero opaco: el modelo decide, escribe, indexa y verifica sin supervisión. El usuario no sabe qué se guardó, dónde, ni si sigue siendo cierto.

Ninguno resuelve mantener información viva y coherente con el trabajo real. Solo el que obliga al humano a decidir. Cada `>> contenido` es una pausa para evaluar si la información merece persistir. Cada `>> update` cruza lo aprendido en la sesión con lo ya documentado, y pregunta antes de cambiar nada.

La memoria útil no es la que indexa el código — es la que captura lo que el código no puede decir.

| Sistema | Confía en | Resultado |
|---------|-----------|-----------|
| AGENTS.md + `/init` | El usuario mantiene, `/init` no destruye | Falso. `/init` puede podar lo que el usuario añadió. La confianza es unilateral. |
| Asistente analizado (auto-memory) | El modelo lo gestiona todo | El usuario no participa. No puede corregir, auditar, ni decidir qué se guarda. |
| Memory-system (este) | El humano decide | No hay automatización que deshaga trabajo. No hay decisiones sin supervisión. |

Paradoja: AGENTS.md necesita que el usuario lo enriquezca, pero `/init` está diseñado para regenerar, no para conservar. El usuario enriquece, `/init` deshace, el usuario abandona. El círculo solo se rompe dando al humano la última palabra. Eso es exactamente lo que hace `>> update`: propone cambios y pregunta "¿aplico?" antes de modificar nada

El sistema que mejor funciona es el que obliga a parar y a decidir.
