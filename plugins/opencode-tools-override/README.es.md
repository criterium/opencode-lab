# opencode-tools-override

Sobrescribe las descripciones de las tools de OpenCode usando archivos `.txt` planos.
Útil para corregir instrucciones irrelevantes para tu flujo de trabajo
(p.ej., "use gh" cuando usas GitLab), eliminar guías de herramientas que
no utilizas, o acortar descripciones verbosas (ahorra tokens como
beneficio secundario).

**Ventaja clave**: Las descripciones de tools tienen una autoridad mayor que
las instrucciones del system prompt. El modelo las trata como definiciones
autoritativas — adopta comportamientos colocados en descripciones de tools
más fácilmente y con menos hesitación que las mismas instrucciones en el
system prompt. Esto convierte a las tool overrides en el lugar ideal para
reglas de comportamiento, restricciones específicas del dominio y flujos
de trabajo personalizados.

Ver [System Prompt vs Tool Descriptions](../../research/api-call-anatomy/README.es.md#6-autoridad-de-instrucciones-y-estrategia)
para el análisis completo.

## Cómo funciona

Cuando OpenCode prepara las definiciones de tools para el LLM, el plugin
comprueba si existe un archivo `<toolID>.txt` en `overrides/`. Si existe,
ese texto reemplaza la descripción incorporada. Si no, la original se
deja intacta.

Las descripciones se **almacenan en caché en memoria** cuando OpenCode
se inicia. Si creas o modificas un archivo `.txt`, debes reiniciar
OpenCode para que el cambio se aplique.

Ver el directorio `ref/` para las descripciones originales de todas las tools.

## Requisitos

- OpenCode capaz de cargar plugins desde `~/.config/opencode/plugin/` — no
  es necesario editar `opencode.json`.

## Instalación

```bash
cd plugins/opencode-tools-override
./opencode-tools-override.sh init        # crea overrides/ y captura ref/
./opencode-tools-override.sh install     # crea el symlink del plugin
# reinicia OpenCode
./opencode-tools-override.sh status      # confirma que el plugin está activo
```

## Crear overrides

Cada archivo `.txt` en `overrides/` debe tener el nombre del ID de la tool.
(`overrides/` está junto al archivo `.ts` del plugin — ver [Archivos](#archivos).)

```bash
echo "short description for todowrite" > overrides/todowrite.txt
echo "description without git guides" > overrides/shell.txt
```

Un archivo `.txt` vacío elimina la descripción de la tool por completo.
Para las tools `task` y `skill`, solo queda la parte generada automáticamente.

## Comandos

| Comando | Función |
|---------|----------|
| `init` | Crea `overrides/`, `last/` y captura las tools actuales en `ref/` |
| `install` | Crea el symlink del plugin en `~/.config/opencode/plugin/` |
| `uninstall` | Elimina el symlink (no toca `overrides/`) |
| `capture` | Descarga las tools de la versión instalada → `ref/` |
| `fetch` | Descarga las tools del último release → `last/` |
| `update` | Fetch + diff. Promociona automáticamente si no hay cambios de contenido; si los hay, muestra el diff e indica ejecutar `promote` manualmente. |
| `diff` | Compara `ref/` vs `last/` (auto `--impact` si existen overrides) |
| `diff --impact` | Solo cambios que afectan a tools que tienen un override |
| `diff --all` | Diff completo de todos los cambios (omite auto-impact) |
| `diff --help` | Muestra la ayuda de diff |
| `promote` | Copia `last/` → `ref/` (valida y adopta) |
| `status` | Muestra versiones, estado del plugin y overrides activos |
| `help` | Ayuda completa |

### Flujo de trabajo para una nueva versión de OpenCode

Revisión rápida:

```bash
./opencode-tools-override.sh update
#   Sin cambios de contenido → promoción automática (vía rápida)
#   Con cambios de contenido → muestra diff, ejecuta promote manualmente tras revisar
./opencode-tools-override.sh status             # confirma que ref/ está actualizado
```

Manual (control total):

```bash
./opencode-tools-override.sh fetch              # descarga nuevas tools a last/
./opencode-tools-override.sh diff --impact      # solo las que te afectan
./opencode-tools-override.sh diff --all         # todos los cambios (omite auto-impact)
# revisa si tus overrides siguen siendo válidos
./opencode-tools-override.sh promote            # adopta la nueva versión
```

## Archivos

Todas las rutas son relativas al directorio del plugin
(`plugins/opencode-tools-override/`) a menos que se indique lo contrario.

| Ruta | Propósito |
|------|----------|
| `opencode-tools-override.ts` | Código fuente del plugin de OpenCode |
| `opencode-tools-override.sh` | Script de gestión (init, install, capture, ...) |
| `~/.config/opencode/plugin/opencode-tools-override.ts` | Symlink → `.ts` en el repositorio |
| `overrides/` | Tus archivos `.txt` con descripciones personalizadas |
| `ref/` | Instantánea de las descripciones originales para la versión actual (puede incluir subdirectorios como `shell/`) |
| `last/` | Descripciones descargadas del último release para comparación (misma estructura que `ref/`) |
| `debug.log` | Log de ejecución (solo se escribe cuando `OPENCODE_TOOLS_OVERRIDE_DEBUG=1`) |

## Depuración

Establece `OPENCODE_TOOLS_OVERRIDE_DEBUG=1` para activar el logging del plugin.
Todos los mensajes (diagnósticos de inicio y aplicaciones de override por turno)
se escriben en `debug.log` en el directorio del plugin.

```bash
OPENCODE_TOOLS_OVERRIDE_DEBUG=1 opencode
# Después de que OpenCode inicie e interactúes, comprueba:
cat plugins/opencode-tools-override/debug.log
```

Para seguir los logs en tiempo real desde otra terminal:

```bash
tail -f plugins/opencode-tools-override/debug.log
```

Sin `DEBUG`, el plugin no escribe nada — cero I/O de archivos, cero
entradas de log.

Ejemplo de salida cuando está activado:

```
[opencode-tools-override] loaded 3 override(s)
[opencode-tools-override] applied override for "todowrite"
[opencode-tools-override] applied override for "shell"
```

## Notas

El plugin encuentra el directorio `overrides/` automáticamente junto a su
archivo `.ts`. Puedes mover el repositorio a cualquier sitio; solo ejecuta
`uninstall` + `install` para actualizar el symlink.

## Investigación relacionada

- [`research/api-call-anatomy/README.es.md`](../../research/api-call-anatomy/README.es.md) —
  Referencia arquitectónica de cómo OpenCode estructura las llamadas API,
  incluyendo cómo se serializan las definiciones de tools y cómo encaja
  el hook de este plugin en el pipeline.
- [`research/skill-desc-leak/README.es.md`](../../research/skill-desc-leak/README.es.md) —
  Demuestra cómo las tool description overrides afectan el comportamiento
  del modelo, incluyendo una prueba de concepto usando este plugin y
  estrategias de mitigación que lo aprovechan.
- [`research/context-dump/README.es.md`](../../research/context-dump/README.es.md) — Comparación
  entre harnesses de definiciones de tools y system prompts; útil como
  referencia externa al escribir o refinar overrides.
