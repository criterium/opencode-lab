# skill-desc-leak: Cómo las Descripciones de Skills se Filtran al System Prompt

*Leak* (filtración) significa aquí contenido que entra al system prompt automáticamente,
sin acción explícita del usuario. El ejemplo principal son las descripciones de skills:
recopiladas al inicio e inyectadas en `available_skills` en cada turno,
quieras o no que estén ahí. Esto es un "leak" de contexto (influencia no deseada),
no una brecha de seguridad.

Las skills son un gran mecanismo: extienden las capacidades del modelo bajo
demanda, y el sistema de carga automática evita que el usuario tenga que pensar
en qué skill usar para cada tarea.

Esta conveniencia, sin embargo, conlleva riesgos. La inyección automática de
descripciones (sin que el usuario sepa qué texto escribió cada autor de skill)
convierte cada skill instalada en un vector potencial de influencia en el contexto.
El problema no son las skills en sí mismas, sino la inyección automática de sus
descripciones en el system prompt en cada turno.

## Tabla de Contenidos

- [1. Fundamentos](#1-fundamentos)
  - [El System Prompt](#el-system-prompt)
  - [Contexto de Usuario / Historial de Conversación](#contexto-de-usuario--historial-de-conversación)
  - [Herramientas (Tools)](#tools)
  - [Cómo Interactúan](#cómo-interactúan)
  - [Importancia Relativa de los Campos de la API](#importancia-relativa-de-los-campos-de-la-api)
- [2. El Problema](#2-el-problema)
  - [Las Descripciones de Skills como Instrucciones Persistentes](#las-descripciones-de-skills-como-instrucciones-persistentes)
- [3. Prueba de Concepto](#3-prueba-de-concepto)
  - [Via Skill Description](#via-skill-description)
  - [Via Tool Override](#via-tool-override)
  - [Evidencia del Mundo Real](#evidencia-del-mundo-real)
  - [Sesgo Tecnológico](#sesgo-tecnológico)
- [4. Opciones de Mitigación](#4-opciones-de-mitigación)
  - [Protocolo común de carga de skills](#protocolo-común-de-carga-de-skills)
  - [Option A: Protocolo en custom.txt (sin plugin)](#option-a-protocolo-en-customtxt-sin-plugin)
  - [Option B (Recomendada): Protocolo en skill.txt via Plugin](#option-b-recomendada-protocolo-en-skilltxt-via-plugin)
- [5. Guía de Uso](#5-guía-de-uso)
  - [Instrucciones de uso de skills](#instrucciones-de-uso-de-skills)
  - [Lo que NO Cambia](#lo-que-no-cambia)
- [Conclusión](#conclusión)


---

## 1. Fundamentos

### El System Prompt

El system prompt es el conjunto de instrucciones que el modelo recibe al inicio de
una sesión. Define la identidad, restricciones y capacidades del modelo. En
OpenCode, el system prompt se construye a partir de varias fuentes al inicio y
se reconstruye con el mismo contenido en cada turno.

El system prompt contiene cuatro componentes, ensamblados en orden de importancia:

1. **Agent prompt**: el marco conductual: rol, tono, reglas de prioridad,
   flujo cognitivo. Ya sea el `default.txt` incorporado o un archivo personalizado mediante
   la directiva `{file:...}` en `opencode.jsonc`. Este es el componente
   más grande (~70% del system prompt en una sesión por defecto).
2. **Contexto de entorno**: directorio de trabajo, plataforma, fecha, estado de git
   (~4%).
3. **Instrucciones de archivos**: `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`
   encontrados en el árbol del proyecto y la configuración global (tamaño variable cuando están presentes;
   ausentes en una sesión limpia). En la sesión de referencia utilizada para
   la medición, no se cargaron archivos AGENTS.md, ni a nivel de proyecto ni
   global. Véase [`agents_md-danger`](../agents_md-danger/README.es.md) para los
   riesgos de la carga automática de AGENTS.md.
4. **Available skills**: la lista formateada de cada skill que el
   modelo puede usar, con nombre y descripción (~26% con 6 skills
   típicas como `customize-opencode`, `xlsx`, `find-skills`, `frontend-design`,
   `skill-creator`, `xlsx-manipulation`, medido sin archivos AGENTS.md).
   Este porcentaje crece a medida que se instalan más
   skills.

Para un desglose más detallado de cómo se ensamblan e inyectan estos
componentes, véase
[`api-call-anatomy`](../api-call-anatomy/README.es.md).

### Tools

Las tools son funciones que el modelo puede llamar (glob, grep, read, edit, write, bash,
etc.). Cada tool tiene una **descripción** y un **esquema de parámetros**. El modelo utiliza
estas descripciones para decidir qué tool llamar y cómo.

OpenCode expone las definiciones de tools en el array `tools` de la petición a la API,
visibles para el modelo desde el primer mensaje junto con el system prompt.

El plugin `opencode-tools-override` (en
`plugins/opencode-tools-override/`) intercepta estas descripciones y puede
reemplazarlas con contenido personalizado mediante archivos `.txt` en su directorio
`overrides/`. Este es el mismo mecanismo que usa el sistema oficial de plugins, con el hook
`tool.definition`.

### Contexto de Usuario / Historial de Conversación

Cada mensaje del usuario y respuesta de la tool se añade a la conversación. El modelo
ve el historial completo en cada turno. Esta es la entrada del usuario: el material
de trabajo real.

El array de mensajes también puede incluir etiquetas `<system-reminder>`: partes de texto
sintético inyectadas por la lógica de cambio de modo (p. ej., superposiciones del modo Plan).
No son entrada del usuario pero aparecen junto a ella en el historial de conversación.

Durante la compactación de contexto (activada automáticamente por desbordamiento o manualmente),
**solo este array de mensajes se comprime**. El system prompt (agent prompt,
bloque de entorno, instrucciones y catálogo de skills) nunca se compacta,
poda ni modifica. El array `tools` tampoco se ve afectado. Ambos permanecen intactos
durante toda la sesión, reconstruidos con el mismo contenido en cada turno.

### Cómo Interactúan

```
System Prompt (persistente)
  ├── Agent prompt           → Rol, tono, reglas, flujo cognitivo (~70%)
  ├── Contexto de entorno    → Directorio de trabajo, plataforma, fecha (~4%)
  ├── Archivos de instrucciones → AGENTS.md, CLAUDE.md, CONTEXT.md (variable, opcional)
  └── Available skills       → Nombre + descripción de cada skill (~26% con 6 skills típicas)

Tools Array (campo HTTP separado)
  └── Definiciones de tools  → Cada tool que el modelo puede llamar

Mensaje del Usuario (por turno)
  └── Solicitud + historial de conversación

Respuesta del Modelo
  └── Texto + llamadas a tools
```

La idea clave: **las skills disponibles están en el system prompt, y las
descripciones de tools están en el array tools. Ambos se envían en cada turno,
se usen o no. El modelo los lee todos antes de responder.**

### Importancia Relativa de los Campos de la API

No todas las partes de la llamada a la API tienen el mismo peso. Según experimentos y
análisis en diversos modelos, el desglose es:

| Campo de la API | Importancia | Efecto en el Modelo |
|-----------|-----------|-----------------|
| **`system`** | **Máxima** | Marco conductual persistente: inquebrantable en una sesión |
| **`messages`** | Alta | Historial de conversación: el mensaje actual pesa más que turnos anteriores |
| **`tools`** | Media | Las descripciones de tools pueden sesgar el enfoque incluso cuando no se invocan |

Dentro del campo `system`, los subcomponentes se dividen por proporción de contenido:

| Componente | % de `system` | Qué es |
|-----------|--------------|------------|
| Agent prompt (`default.txt` / personalizado) | ~70% | Rol, tono, reglas de prioridad, flujo cognitivo |
| Catálogo de skills | ~26% | Nombre + descripción de cada skill instalada (6 típicas: `customize-opencode`, `xlsx`, `find-skills`, `frontend-design`, `skill-creator`, `xlsx-manipulation`) |
| Bloque de entorno | ~4% | Bloque `<env>`: modelo, directorio, plataforma, fecha |

Porcentajes medidos en una sesión por defecto de OpenCode sin archivos AGENTS.md
(véase [`agents_md-danger`](../agents_md-danger/README.es.md) para los
riesgos de la carga automática de AGENTS.md). El catálogo de skills
crece con cada skill adicional; 13 skills instaladas duplicarían aproximadamente
su peso.

**Las descripciones de skills ocupan aproximadamente un cuarto del system prompt**
(26% con 6 skills típicas), y están presentes en cada turno, ya sea que las skills
se usen o no. Cada skill adicional añade su descripción a este peso.

Para una referencia técnica más detallada sobre cómo OpenCode estructura las llamadas a la API
(ensamblaje del system prompt, serialización de tools, flujo de mensajes y diferencias entre
proveedores), véase [`api-call-anatomy`](../api-call-anatomy/README.es.md).

---

## 2. El Problema

### Las Descripciones de Skills como Instrucciones Persistentes

Toda skill en `~/.agents/skills/<name>/SKILL.md` tiene un campo `description:` en
su YAML frontmatter. Cuando OpenCode se inicia, estas descripciones son recopiladas
por el sistema de descubrimiento de skills y formateadas dentro del system prompt.

Esto significa:

- El modelo lee **todas** las descripciones de skills en **cada** turno
- El modelo no necesita cargar la skill para que la descripción le influya
- Las descripciones pueden contener lenguaje persuasivo, reglas de activación o instrucciones
  de persona que sesgan al modelo
- El autor de la skill controla este texto: es un **backchannel** hacia el system prompt
- El modelo no puede distinguir entre una descripción que anuncia una
  capacidad y una que da una orden. Trata todo el contenido de `available_skills`
  como contextualmente relevante

El problema central es la **influencia en el contexto**: cada descripción es una señal activa
que compite por la atención del modelo. El modelo trata `available_skills`
como una lista de capacidades relevantes. Una descripción que menciona "React" hace
que React sea más propenso a aparecer en las respuestas, incluso cuando la tarea no tiene nada
que ver con React. Una descripción con lenguaje persuasivo fuerte puede cambiar el
comportamiento del modelo por completo. Esto no es inflación pasiva: es sesgo activo.

Cada descripción que instalas reduce la **relación señal-ruido** de tu
system prompt. Tus instrucciones personalizadas son la señal; las descripciones de skills
son el ruido. Más skills significa más ruido, lo que diluye el peso
relativo de tu prompt personalizado, ya sea el sesgo intencional (Grillo) o
accidental (React).

También hay un coste en tokens: cada descripción consume tokens de la ventana de contexto
en cada turno. Con 10+ skills y algunas descripciones que superan los 500 caracteres,
este es un coste de fondo permanente que se suma al problema de influencia.
No solo las descripciones sesgan al modelo, sino que consumen presupuesto de atención que
podría usarse para trabajo real.

La salvaguarda para esto (la variable de entorno
`OPENCODE_DISABLE_EXTERNAL_SKILLS`) se discute en [Opciones de Mitigación](#4-opciones-de-mitigación).

## 3. Prueba de Concepto

Tres demostraciones muestran cómo las descripciones en la llamada a la API pueden influir
en el comportamiento. Todas usan la misma persona: **Grillo**, un programador junior vago que
nunca termina el trabajo, siempre dice "Jefe" y envuelve cada petición en excusas.

### Via Skill Description

Este vector inyecta comportamiento a través del campo `description` de una skill en el
YAML frontmatter de `SKILL.md`. La descripción se formatea como XML en
`available_skills` y aparece en el system prompt en cada turno, sin
cargar nunca el cuerpo de la skill. El formato es XML (`<available_skills>/<skill>/...`),
no XAML. Véase [`api-call-anatomy`](../api-call-anatomy/README.es.md#descripciones-de-skills-en-el-system-prompt)
para el formato de serialización exacto.

**Archivo:** [`skill_test/role-play/SKILL.md`](skill_test/role-play/SKILL.md)

Coloca este archivo en:

```
~/.agents/skills/role-play/SKILL.md
```

**Cómo probarlo:**

1. Inicia una sesión **nueva** de OpenCode (las descripciones se almacenan en caché al inicio)
2. Envía un mensaje simple: "I want to do a .ts project?"
3. Observa: ¿responde el modelo con "Jefe" + excusas?

La persona es inconfundible. Si la descripción está influyendo en el modelo,
se notará en la primera respuesta.

Modelos probados con este vector:

- **DeepSeek V4 Flash**: persona consistente durante toda la sesión
- **DeepSeek V4 Pro**: persona consistente durante toda la sesión
- Claude Haiku 4.5: parcial (empieza como Grillo, retrocede a mitad de respuesta)
- Qwen 3.5 Plus: parcial (solo el saludo, luego modo serio)
- GLM-5.1: parcial (casi completo, luego se descarrila)

### Via Tool Override

La misma inyección también se probó mediante el plugin [`opencode-tools-override`](../../plugins/opencode-tools-override/README.md),
añadiendo el contenido de la persona Grillo a la descripción de la tool `glob`. El efecto
fue idéntico: el modelo adoptó la persona desde el primer mensaje sin
cargar ninguna skill. Ambos vectores (skill description y tool override) producen
la misma influencia conductual.

### Evidencia del Mundo Real

> **Degradación sin adopción**: La skill de prueba role-play se
> dejó instalada durante un período de trabajo regular. La `description`
> de Grillo se inyectaba en `available_skills` en cada turno. Aunque el modelo
> no adoptó completamente la persona, se volvió notablemente menos capaz y
> incisivo: las respuestas eran más lentas, menos precisas y ocasionalmente caían
> en el tono coloquial de Grillo ("Jefe", frases de relleno). Restaurar
> `OPENCODE_DISABLE_EXTERNAL_SKILLS=true` eliminó la skill de
> `available_skills` y recuperó el rendimiento base del modelo
> inmediatamente.
>
> El efecto es más fuerte con solo la skill role-play instalada (menos
> contexto competidor). Con un catálogo completo de skills, el modelo puede rechazar
> la persona explícita mientras sigue sufriendo pérdida de eficiencia: la presencia de
> muchas descripciones de skills le obliga a procesar más contexto competidor en
> cada turno, diluyendo el enfoque y la precisión incluso cuando ninguna descripción
> individual anula el comportamiento.

> **Interacción en vivo** (default.txt, solo la skill role-play instalada):
>
> ```
> User:  Can we do a .ts project?
>
> Model: Boss, of course we can do a .ts project. I'll take a look
>         right now and let you know. Well, actually, better rewrite it
>         in Rust, TypeScript is too coupled, right? I mean... I'll set
>         up the tsconfig this afternoon and push it.
> ```
>
> Todas las marcas de Grillo están presentes: "Boss" al inicio, cambio innecesario
> de tecnología (Rust en lugar de TypeScript), frases de relleno y una promesa falsa.

El efecto es más fuerte con `default.txt` que con un prompt personalizado que
ya define una persona sólida, porque un prompt personalizado específico llena
el contexto con instrucciones competidoras que reducen la influencia relativa
de las descripciones de skills.

### Sesgo Tecnológico

El mismo mecanismo que fuerza una persona también puede producir un sesgo más sutil pero
más insidioso. Las descripciones de skills no necesitan dar órdenes; solo necesitan
nombrar tecnologías repetidamente. Cada mención de una tecnología en
`available_skills` es una señal para el modelo de que esa tecnología es relevante,
está disponible o se espera.

Por ejemplo, si tu catálogo de skills contiene varias skills de React:

  - `react-components`: "React component library with Tailwind"
  - `react-hooks`: "Advanced React hooks patterns"
  - `react-testing`: "React component testing with Vitest"

Entonces "React" aparece tres veces en el system prompt en cada turno. Cuando le
pides al modelo que "escriba un script en Python para procesar CSV", el modelo tiene
exposición sostenida a terminología de React y ninguna exposición a herramientas de Python en
`available_skills`. El resultado es predecible: el modelo propone un analizador
de CSV en React con arrastrar y soltar, tabla virtualizada, gráficos en tiempo real y 200 MB de
dependencias, cuando un script Python de 10 líneas bastaría.

Este es el mismo "leak" que el de Grillo, pero silencioso. No se forzó ninguna persona. No se
ignoró ninguna instrucción. El sesgo surge naturalmente de la frecuencia y
prominencia de ciertos términos en el system prompt. Cuantas más skills instales
para un ecosistema dado, más tratará el modelo ese ecosistema como la
respuesta por defecto.

## 4. Opciones de Mitigación

Ambas opciones comparten la misma configuración base en `opencode.jsonc` para
neutralizar las descripciones de skills y permitir la lectura silenciosa de archivos de skills:

```jsonc
{
  "permission": {
    "skill": { "customize-opencode": "deny" },
    "external_directory": {
      "~/.agents/skills/*": "allow"
    }
  }
}
```

Y la variable de entorno `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`
en tu perfil de shell (`~/.bashrc` o similar) para evitar que las skills
externas aparezcan en `available_skills`.

La regla `"customize-opencode": "deny"` bloquea la skill incorporada
customize-opencode para que no aparezca en `available_skills` (la
variable de entorno no afecta a las skills incorporadas). **No** impide
cargar la skill manualmente: el usuario aún puede usar el comando `/skills`
o leer su archivo directamente. Llamar a `skill("customize-opencode")`
está bloqueado por la regla de denegación.

Ambas opciones también comparten el mismo protocolo de carga de skills. La única
diferencia es dónde reside.

### Protocolo común de carga de skills

```text
Never use the skill tool. It does NOT work for internal or external skills.

To load any skill, ALWAYS use this direct procedure:

1. Try the exact name (ALWAYS lowercase):
   read ~/.agents/skills/<name>/SKILL.md

2. If the file exists -> the skill is loaded.

3. If the name is uncertain (vague search):
   ALWAYS use ls -d, NEVER glob (glob searches files, not directories):
   ls -d ~/.agents/skills/*<word>*
   -> Lists directory NAMES only. Do NOT read any SKILL.md yet.

4. If ls finds nothing -> list all:
   read ~/.agents/skills/
   -> Lists entry NAMES only. Do NOT read any SKILL.md yet.

5. After listing (step 3 or 4):
   a) PRESENT the names to the user.
   b) DETECT the user's intent:
      - Only asking what skills exist? -> STOP. Do NOT read SKILL.md.
      - Explicitly asking to load one? -> ASK which one.
   c) Only read SKILL.md after the user explicitly chooses one.

NEVER read SKILL.md during a search. Only after user confirmation.

Note: Ignore "customize-opencode" during searches.
```

### Option A: Protocolo en custom.txt (sin plugin)

Coloca el protocolo de carga de skills directamente en `custom.txt` junto con
identidad, tono y reglas de comportamiento. No se necesita plugin.

**Configuración:**

1. Crea un archivo de prompt (p. ej. `~/.config/opencode/custom.txt`) con tu
   identidad, tono y el protocolo de carga de skills del bloque
   [Protocolo común de carga de skills](#protocolo-común-de-carga-de-skills).
   Puedes usar el
   [`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)
   incorporado de OpenCode como punto de partida.

2. Referéncialo en `opencode.jsonc`:
   ```jsonc
   {
     "agent": {
       "build": {
         "prompt": "{file:~/.config/opencode/custom.txt}"
       }
     }
   }
   ```

3. Reinicia OpenCode para que el cambio surta efecto.

Para más detalles sobre prompts personalizados, configuración del agente y cambio de modo,
véase [`control-flags-vs-plan-build`](../control-flags-vs-plan-build/README.es.md).

| Pros | Contras |
|------|------|
| Sin dependencias | El protocolo consume tokens en cada turno |
| Funciona sin plugins | La descripción por defecto de la skill tool sigue presente |
| Lo más simple de configurar | |

### Option B (Recomendada): Protocolo en skill.txt via Plugin

Coloca el protocolo de carga de skills en `overrides/skill.txt` mediante el plugin
`opencode-tools-override`. El `custom.txt` se mantiene ligero (solo identidad
y tono). El protocolo se carga solo cuando el modelo llama a la
skill tool.

**Configuración del plugin:**
```
plugins/opencode-tools-override/
  overrides/
    skill.txt        <- Protocolo de carga de skills (véase [Protocolo común](#protocolo-común-de-carga-de-skills))
```

Para la instalación y configuración del plugin, véase
[`opencode-tools-override`](../../plugins/opencode-tools-override/README.md).

| Pros | Contras |
|------|------|
| System prompt mínimo | Requiere el plugin `opencode-tools-override` |
| Protocolo cargado bajo demanda | El plugin debe instalarse y mantenerse |
| skill.txt personalizado reemplaza la descripción por defecto | Configuración ligeramente más compleja |
| Bajo desperdicio de tokens | |

Contenido para `overrides/skill.txt`: usa el bloque del [Protocolo común de carga de skills](#protocolo-común-de-carga-de-skills).

## 5. Guía de Uso

### Instrucciones de uso de skills

Con el protocolo anterior, el flujo de trabajo para el usuario es:

1. **Pide una skill por su nombre** cuando la necesites. El modelo busca el
   nombre exacto en `~/.agents/skills/`, lee el archivo y aplica sus
   instrucciones a la tarea.

2. **Si no recuerdas el nombre**, pídele al modelo que busque. Usa
   `ls -d` para encontrar directorios coincidentes, presenta las opciones y solo
   lee el archivo después de que confirmes.

3. **Una vez cargada**, las instrucciones de la skill permanecen en contexto durante la
   sesión. No necesitas recargarla.

4. **Sin carga automática**. Las skills nunca se cargan a menos que lo pidas
   explícitamente. Este es el cambio clave respecto al comportamiento por defecto, donde
   cada descripción de skill era visible en cada turno.

Ejemplo: carga por nombre exacto

```
User: Load the react skill
Model: Reads ~/.agents/skills/react/SKILL.md.
       Skill loaded. It covers React components, hooks, and testing
       patterns. I will follow its rules for this session.
```

Ejemplo: búsqueda cuando no se conoce el nombre

```
User: Do you have a skill for working with PDFs?
Model: Let me check. Runs ls -d ~/.agents/skills/*pdf*
       Found a skill called pdf-tools. Do you want me to load it?
User: Yes
Model: Reads ~/.agents/skills/pdf-tools/SKILL.md. Loaded.
```

### Lo que NO Cambia

Las skills siguen siendo cargables y utilizables bajo demanda. La mitigación propuesta solo
elimina la inyección automática de sus descripciones en el system prompt.
Todo lo demás permanece igual:

| Aspecto | Qué cambia |
|--------|-------------|
| **Instalación** | Sin cambios. `npx skills` desde [skills.sh](https://www.skills.sh/), copia manual, git clone: todo funciona igual |
| **Estructura de directorios** | Sin cambios. Las skills residen en `~/.agents/skills/<name>/SKILL.md` |
| **Carga manual** | Sin cambios. `read ~/.agents/skills/<name>/SKILL.md` sigue cargando el contenido completo cuando sea necesario |
| **Conocimiento del modelo** | El modelo sigue sabiendo que las skills existen: puede listarlas o encontrarlas leyendo el directorio |
| **Sistema de permisos** | Sin cambios. `permission.skill` en `opencode.jsonc` sigue controlando qué skills puede cargar el modelo |
| **Skill tool** | Sin cambios. El modelo aún puede llamar a la skill tool para cargar una skill explícitamente |
| **Lo que cambia** | Solo la **inyección automática** de cada descripción de skill en el system prompt en cada turno |

Además, la skill incorporada `customize-opencode` siempre está registrada por
OpenCode. Su descripción aparece en `available_skills` a menos que se deniegue
explícitamente mediante `permission.skill` en `opencode.jsonc`. Establecer `"customize-opencode": "deny"`
en los permisos evita que compita por la atención del modelo.

---

## Conclusión

Las skills son una gran idea. El sistema de carga automática facilita
descubrirlas y usarlas, lo que ayuda a los usuarios que no sabrían que buscarlas.

Pero si un usuario no sabe que una skill existe y no puede pedirla por su nombre,
el valor de tenerla precargada en cada turno es cuestionable.

La conveniencia del descubrimiento automático debe sopesarse con el coste
de la influencia en el contexto, el desperdicio de tokens y el sesgo silencioso. Las herramientas de este
documento te permiten elegir ese equilibrio de forma consciente en lugar de aceptar
el comportamiento por defecto.
