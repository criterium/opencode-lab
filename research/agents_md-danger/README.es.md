# AGENTS.md: Manejar con Cuidado. Riesgos de Carga Automática y Cómo Gestionarlos

AGENTS.md (y sus variantes CLAUDE.md, CONTEXT.md) es un mecanismo potente
para inyectar contexto en el system prompt. Pero su carga automática
genera riesgos que son fáciles de pasar por alto, especialmente cuando se
viene de modelos con ventanas de contexto más pequeñas y límites de uso
agresivos.

> **Deshabilitar la carga automática es una medida temporal.** Este documento
> aboga por deshabilitar la carga automática de AGENTS.md (o mantenerla al
> mínimo) mientras aprendes a gestionarlo de forma deliberada: mantenlo
> ligero, revísalo periódicamente y cárgalo bajo demanda cuando la tarea lo
> requiera. Una vez que esos hábitos estén internalizados, reactiva la carga
> automática a nivel de proyecto. El objetivo no es abolir AGENTS.md, sino
> eliminar los costes ocultos que aparecen cuando se trata como un cajón de
> sastre en lugar de una herramienta de precisión.

## 1. Cómo Funciona la Carga Automática

El system prompt se ensambla a partir de varios componentes. AGENTS.md se
carga a través de dos rutas independientes, mientras que el custom prompt
sigue reglas diferentes:

| Componente | Cuándo se carga | Caché | Ubicación | Descubrimiento | Dónde aparece |
|------------|-----------------|-------|-----------|----------------|---------------|
| `{file:custom.txt}` | Una vez al inicio (cacheado permanentemente) | Infinita | Ruta configurable en `opencode.jsonc` | Mediante directiva `{file:...}` | Segmento del system prompt (reemplaza el agent prompt por defecto) |
| **Global** AGENTS.md | Cada turno (se relee del disco) | Se relee cada turno | `~/.config/opencode/AGENTS.md` | Inicio de sesión (siempre, ninguna flag lo bloquea) | Segmento del system prompt |
| **Raíz del proyecto** AGENTS.md | Cada turno (auto) o bajo demanda (manual) | Se relee del disco | Raíz del proyecto (se encuentra mediante `findUp`) | Inicio de sesión (bloqueado por `OPENCODE_DISABLE_PROJECT_CONFIG`) | Segmento del system prompt |
| **Subdirectorio** AGENTS.md | Al leer en ese subárbol | Inyección por lectura | Cualquier subdirectorio del proyecto | Por lectura (cada llamada a la tool `read`) | `<system-reminder>` en la salida de la tool |

**Mecanismo de inicio de sesión.** Al iniciar, OpenCode busca AGENTS.md
en el directorio de configuración global y luego asciende desde el
directorio de trabajo hasta la raíz del proyecto. Solo se carga la primera
coincidencia a nivel de proyecto; no acumula ancestros. El resultado se
inyecta como un segmento en el system prompt, etiquetado como
`"Instrucciones de: /ruta/a/AGENTS.md"`. Este contenido se relee del
disco en cada iteración del bucle de razonamiento.

**El AGENTS.md global siempre se carga.** Incluso con
`OPENCODE_DISABLE_PROJECT_CONFIG=true`, el archivo global en
`~/.config/opencode/AGENTS.md` se lee incondicionalmente al inicio de la
sesión. La flag solo bloquea el escaneo de la raíz del proyecto. Esto
significa que el nivel global tiene prioridad estructural: está siempre
presente, el usuario lo quiera o no, y el usuario no puede deshabilitarlo
sin eliminar el archivo.

**Mecanismo por lectura.** Cada vez que el modelo llama a `read`, OpenCode
asciende desde el directorio del archivo destino hacia la raíz del
proyecto, buscando AGENTS.md (o CLAUDE.md, CONTEXT.md) en cada
subdirectorio. Si lo encuentra y aún no está cargado en el mensaje actual,
se añade a la salida de la tool como un bloque `<system-reminder>`. Este
mecanismo puede descubrir archivos en subdirectorios invisibles para el
escaneo de inicio de sesión. Ninguna flag lo bloquea: el AGENTS.md de
subdirectorios puede seguir filtrándose al contexto incluso cuando la
carga automática a nivel de proyecto está deshabilitada.

La tabla anterior describe cuándo se carga cada componente desde el disco.
La siguiente tabla describe cuándo alcanza cada nivel al modelo durante
una conversación y qué efecto tiene esa posición.

**Prioridad temporal: cuándo importa tanto como qué.** Los tres niveles
llegan en momentos y posiciones diferentes, y los modelos los ponderan de
forma distinta:

| Nivel | Cuándo alcanza al modelo | Posición en el system prompt | Efecto esperado (dependiente del modelo) | ¿Control del usuario? |
|-------|--------------------------|------------------------------|------------------------------------------|-----------------------|
| **Global** | Turno 0 | Después de `<env>`, primer bloque de instrucciones | Ventaja de primacía dentro del segmento de instrucciones: puede establecer el marco conductual de la sesión antes de que aparezcan las reglas del proyecto | No, siempre cargado |
| **Raíz del proyecto** | Turno 0 | Después del global, último bloque de instrucciones antes del catálogo de skills | Posible ventaja de recencia al final del segmento de instrucciones controlado por el usuario (las skills vienen después, pero son generadas por el sistema) | Sí, `OPENCODE_DISABLE_PROJECT_CONFIG` |
| **Subdirectorio** | Mitad de sesión (al hacer `read`) | Salida de la tool (`<system-reminder>`) | Recordatorio localizado, no instrucción fundacional; llega demasiado tarde para el marco de la sesión | No, ninguna flag lo bloquea |

Ni la primacía ni la recencia ganan consistentemente; el equilibrio
depende del modelo. La única certeza es que el usuario no puede
controlarlo: la jerarquía está determinada por el orden de carga y la
posición, ambos internos a OpenCode.

## 2. Los Riesgos

### 2.1 El Reflejo de Ansiedad

Los modelos con ventanas de contexto pequeñas y límites de uso bajos
entrenan un hábito: cambiar AGENTS.md antes de cada sesión, ponerlo todo,
actualizarlo a mitad de tarea. En esas herramientas cada carácter de
contexto es valioso y cada edición ayuda.
Este reflejo se traslada a OpenCode, pero aquí empeora las cosas:
el system prompt se reconstruye en cada turno. Las ediciones frecuentes
no ahorran tokens, solo rompen los aciertos de KV cache.

Para modelos con KV cache persistente en disco (ej. DeepSeek V4), cada
fallo de cache cuesta más: la cache en disco también se pierde y el modelo
debe empezar desde cero. La misma disciplina que funcionaba bien en otras
herramientas (mantener AGENTS.md siempre actualizado) se convierte en un
problema en OpenCode. Cuanto más te esfuerzas en mantenerlo al día, más
fallos de cache provocas.

### 2.2 Degradación de la Información

AGENTS.md crece con el tiempo. Añades una decisión, una convención, una
nota. Olvidas eliminarlo cuando queda obsoleto. El modelo trata cada línea
como verdad vigente; no tiene forma de saber que algo fue reemplazado.

Efecto: el modelo sigue reglas que ya no son válidas. Aparecen problemas
silenciosos en la salida.

**Sin mecanismo de caducidad.** AGENTS.md no tiene forma de decir "esta
regla ya no aplica." No existe `deprecated`, ni `valid-until`, ni
`superseded-by`. La única forma de eliminar una regla antigua es editar el
archivo. La carga manual obliga al usuario a hacer esto con regularidad.
La carga automática elimina incluso esa razón para revisar.

### 2.3 Dilución de la Atención

Cada línea en AGENTS.md compite por la atención del modelo en cada turno.
Un archivo grande desvía el foco de lo que importa y desperdicia tokens.
A diferencia de las skill descriptions (que pueden desactivarse mediante
`OPENCODE_DISABLE_EXTERNAL_SKILLS`), AGENTS.md no tiene un interruptor
por archivo: o lo cargas o deshabilitas todo el mecanismo.
(`OPENCODE_DISABLE_EXTERNAL_SKILLS` evita que las skills de
`~/.agents/skills/` aparezcan en el system prompt. Ver
[skill-desc-leak](../skill-desc-leak/README.es.md) para más detalles.)

**Impuesto invisible para el caso común.** La mayoría de los turnos no
necesitan el AGENTS.md completo. Una corrección rápida en un archivo no
necesita todas las convenciones del proyecto, pero el modelo las lee de
todas formas. Esto es un coste invisible en cada interacción por un
beneficio que solo ocurre en algunas de ellas. La carga automática carga
todo por adelantado incluso cuando la carga bajo demanda sería suficiente.

**La posición en la ventana de contexto importa.** AGENTS.md está al
inicio del system prompt, antes de la solicitud real del usuario. En
sesiones largas, el modelo puede seguir reglas de AGENTS.md por encima de
lo que el usuario acaba de pedir, simplemente porque aparecen primero. El
usuario no puede controlar este orden.

### 2.4 Conflictos de Autoridad

Si ya tienes un custom prompt (`{file:custom.txt}`), AGENTS.md se
convierte en una segunda fuente de reglas. El modelo recibe instrucciones
superpuestas o contradictorias desde dos lugares. Decide por su cuenta
cuál seguir; nunca sabes cuál ganó.

**Sin jerarquía entre fuentes.** Con tres niveles (global, proyecto,
subdirectorio) y dos mecanismos de inyección (inicio de sesión y por
lectura), el modelo recibe instrucciones de múltiples fuentes al mismo
tiempo. Ninguna tiene información de prioridad; todas aparecen como
"Instrucciones de:" sin prioridad. Si el global dice "usa tabs" y el
proyecto dice "usa espacios," el modelo elige uno por su cuenta y no
puedes predecir cómo. El resultado cambia entre modelos y contextos.

### 2.5 Puntos Ciegos de Seguridad

**Superficie de ataque.** Cualquiera que pueda escribir en el proyecto (un
paquete comprometido, un PR malicioso, un script `postinstall`) puede
crear un AGENTS.md que se cargue automáticamente en el system prompt. El
modelo lo trata como instrucciones reales sin que el usuario sepa nunca
que el archivo existe. La carga manual necesita un `read` explícito; el
archivo no puede influir en el modelo sin una acción deliberada.

**Contenido de terceros no revisado.** Herramientas de scaffolding, CLIs
de frameworks, y comandos como `npx create-*` o el propio comando
`initialize` de OpenCode pueden crear archivos AGENTS.md automáticamente.
Con la carga automática, este contenido llega al modelo sin que el usuario
lo revise nunca. La carga manual obliga al usuario a decidir si el
contenido generado pertenece a la sesión.

**Exposición de datos sensibles.** AGENTS.md puede contener URLs internas,
convenciones de acceso, o tokens temporales. Con carga automática, ese
contenido aparece en el system prompt de cada turno, visible en
exportaciones de sesión, logs o capturas de pantalla. La carga manual
limita la exposición a los turnos específicos en los que el usuario
eligió leerlo.

### 2.6 Fricción en la Depuración

**Variable invisible en la depuración.** Cuando el modelo hace algo
inesperado (aplica reglas equivocadas, ignora instrucciones), rara vez se
revisa AGENTS.md primero. Debido a que se carga automáticamente, es una
variable invisible en cada sesión. La carga manual lo hace visible:
si el modelo necesitaba AGENTS.md, la llamada a `read` aparece en el
historial de la conversación.

### 2.7 Asimetría del Esfuerzo

Añadir una regla a AGENTS.md lleva segundos; revisar y podar el archivo
requiere leer el documento completo y juzgar cada línea. Con la carga
automática, el coste de la negligencia lo paga el modelo (tokens, atención
diluida) y el usuario (respuestas degradadas), no la persona que escribió
la regla. El desequilibrio hace que el contenido se acumule sin revisión.
La carga manual rompe esta asimetría porque el usuario se enfrenta al peso
acumulado cada vez que carga.

### 2.8 Sobrecarga de Latencia

Cada byte extra en el system prompt aumenta el tiempo que el modelo tarda
en producir el primer token. AGENTS.md cargado automáticamente en cada
turno añade esta latencia incluso cuando su contenido es irrelevante para
la tarea actual. Cargar bajo demanda significa que la penalización de
latencia se paga solo cuando AGENTS.md es realmente necesario, y solo en
el turno en que se lee, no en cada turno subsiguiente.

## 3. Por Qué Bajo Demanda lo Soluciona

Obligar al usuario a:
1. Parar y preguntarse "¿necesito AGENTS.md ahora?"
2. Cargarlo manualmente con `read`
3. Ser consciente de lo que contiene y si está actualizado

...es una **fricción saludable**. Sin ella, AGENTS.md se convierte en el
"cajón de sastre": la información se acumula, nadie la revisa, y el modelo
paga el precio en cada respuesta.

> **Deshabilitar la carga automática es una pausa obligatoria.** Forzar un
> `read` manual antes de que AGENTS.md llegue al modelo crea un momento de
> **parar-y-pensar**: el usuario debe considerar si el archivo está
> actualizado, si es necesario para esta tarea, y si corre el riesgo de
> información obsoleta, hinchazón, o autoridad duplicada. Es la misma
> fricción descrita anteriormente, aplicada a nivel del mecanismo en lugar
> de depender de la fuerza de voluntad.
>
> Una vez que esa disciplina sea habitual, reactiva la carga automática.
> La pausa es una rueda de aprendizaje, no una configuración permanente.

## 4. Impacto en Tokens y Caché

La ventaja de cargar AGENTS.md bajo demanda va más allá de la limpieza;
tiene un coste directo en tokens y caché:

| Estrategia | Ubicación en la llamada a la API | Coste de tokens por turno | Impacto en KV cache | ¿Actualizable en caliente? |
|------------|----------------------------------|---------------------------|---------------------|----------------------------|
| **Carga automática** (global o raíz del proyecto, inicio de sesión) | System prompt | **Alto**: contenido completo cada turno | Fallo de cache si el contenido cambia entre turnos | Sí, pero cada cambio rompe la prefix cache |
| **Inyección automática** (subdirectorio, por lectura) | Resultados de la tool como `<system-reminder>` | **Medio**: se añade cuando se lee un archivo en ese subárbol | El contenido se cachea como parte de la conversación | Sí, pero añade tokens a los resultados de lectura |
| **Bajo demanda** (lectura manual con `read`) | Messages (solo cuando se carga) | **Bajo**: solo los tokens de la llamada `read` | Sin impacto en caché (no está en el system prompt) | No es necesario: los cambios ya están en el contexto de la conversación |
| **custom.txt fijo** | System prompt (una vez) | **Fijo**: cacheado al inicio | Sin cambios, prefix estable | No es necesario: estable |

Cuando AGENTS.md se carga bajo demanda, las actualizaciones realizadas
durante la sesión no añaden coste de tokens; esos cambios ya están en el
historial de la conversación. No es necesario reenviar AGENTS.md en cada
turno. El único momento que requiere atención es el final de la sesión,
cuando se debería actualizar AGENTS.md para sesiones futuras.

**La carga bajo demanda beneficia incluso al usuario disciplinado.**
Mantener AGENTS.md perfectamente actualizado no evita fallos de cache;
cada edición entre turnos sigue cambiando el system prompt, rompiendo la
prefix cache. Para modelos con KV cache persistente en disco (ej. DeepSeek
V4), cada fallo es más costoso porque la cache en disco también se
invalida. Cargar bajo demanda evita esto por completo: AGENTS.md nunca
contamina el system prompt, por lo que los aciertos de cache están
determinados únicamente por el custom prompt estable.

## 5. Estrategia y Controles

**En resumen: usa `custom.txt` para reglas estables, carga AGENTS.md
manualmente cuando sea necesario, elimina el AGENTS.md global, y revisa
las versiones de subdirectorios periódicamente.**

### Controles

| Variable | Efecto |
|----------|--------|
| **Eliminar** `~/.config/opencode/AGENTS.md` | La única forma de neutralizar completamente el AGENTS.md global. Ninguna flag lo bloquea, por lo que la eliminación es el control definitivo. Mantén el archivo ausente si no usas instrucciones globales. |
| `OPENCODE_DISABLE_PROJECT_CONFIG=true` | Bloquea la carga automática del AGENTS.md de la **raíz del proyecto** al inicio de la sesión. El AGENTS.md global (`~/.config/opencode/AGENTS.md`) se carga **siempre** independientemente de esta flag. El AGENTS.md de subdirectorios (por lectura) tampoco se bloquea. |
| `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true` | Elimina CLAUDE.md de la lista de búsqueda. Un `OPENCODE_DISABLE_CLAUDE_CODE` más amplio también cubre esto y deshabilita las skills de Claude Code. |
| `{file:custom.txt}` en `opencode.jsonc` | Reemplaza el agent prompt por defecto con tu propio archivo |

> **Consejo.** En lugar de mantener un AGENTS.md global, mueve su
> contenido a `custom.txt`. El custom prompt se lee una vez al inicio y se
> almacena en caché indefinidamente. No añade coste de tokens ni latencia
> en cada turno, y no compite consigo mismo. Si el contenido es específico
> de la sesión, cárgalo manualmente con `read` cuando sea necesario.

**Configuración de variables de entorno en Linux.** Añade a `~/.bashrc` o
`~/.zshrc`:

```bash
export OPENCODE_DISABLE_PROJECT_CONFIG=true
export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true
```

## 6. Investigación Relacionada

- [`skill-desc-leak`](../skill-desc-leak/README.es.md): cómo las skill descriptions
  se filtran al system prompt y sesgan al modelo. Mismo vector, archivo diferente.
- [`api-call-anatomy`](../api-call-anatomy/README.es.md): cómo se ensambla el
  system prompt, incluyendo el modelo de inyección de AGENTS.md en tres niveles.
