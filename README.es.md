# OpenCode Lab

Un laboratorio no oficial para el agente AI [OpenCode](https://github.com/sst/opencode):
recetas, benchmarks, experimentos y trucos para entender y controlar su comportamiento.

La ventaja clave: OpenCode es un gran proyecto open-source. A diferencia de los
asistentes de código propietarios, donde el system prompt y el ensamblaje de contexto
son una caja negra, OpenCode permite inspeccionarlo todo.

Puedes ver exactamente cómo se construyen los system prompts, cómo las descripciones
de skills se filtran al contexto, cómo las descripciones de herramientas orientan al
modelo, y cómo AGENTS.md inyecta instrucciones en cada turno. Esa transparencia te da
la flexibilidad para analizar, modificar y controlar el comportamiento de formas que
las herramientas cerradas no permiten.

Este repositorio documenta esos mecanismos y proporciona prompts, plugins y material
de referencia para aprovechar esa flexibilidad.

Versión original en [inglés](README.md).

No afiliado al proyecto OpenCode.

---

## Investigación (Research)

### [Análisis de Riesgo de AGENTS.md](research/agents_md-danger/README.es.md)

Examina los riesgos de la carga automática de AGENTS.md a través de tres
vías de inyección independientes (global, raíz del proyecto, subdirectorio).
Argumenta que los hábitos formados en herramientas con ventanas de contexto
pequeñas se trasladan a OpenCode donde causan hinchazón, ansiedad y latencia.
Documenta el mecanismo de inyección por subdirectorio que ningún flag de
configuración puede bloquear.

### [Anatomía de la Llamada API](research/api-call-anatomy/README.es.md)

Un documento de referencia que explica la estructura de tres partes de la
llamada API (`system` + `messages` + `tools`) y cómo OpenCode ensambla cada
parte. Cubre el pipeline de ensamblaje del system prompt, la resolución de
custom prompts, las vías de inyección de AGENTS.md, las superposiciones de
system-reminder, la estructura de definición de herramientas y el espectro
de autoridad de las instrucciones. 764 líneas, la base de toda la demás
investigación en este repositorio.

### [Kit de Herramientas de Volcado de Contexto](research/context-dump/README.es.md)

Seis prompts operativos que extraen y analizan el contexto completo de la
llamada API de una sesión activa de OpenCode. El Prompt 1 vuelca los campos
system, tools y messages. Los Prompts 2-3 analizan el volcado en busca de
fidelidad, patrones de rechazo y contaminación de datos de entrenamiento.
Los Prompts 4-6 extraen system prompts de sub-agentes, superposiciones de
cambio de modo y definiciones de herramientas. Incluye un flujo de trabajo
de inicio rápido y una guía para mover prompts extraídos entre harnesses.

### [Control Flags vs Plan/Build](research/control-flags-vs-plan-build/README.es.md)

Reemplaza el interruptor binario Plan/Build de OpenCode por siete flags de
control a nivel de usuario que dirigen el modo cognitivo del modelo sin
modificaciones en el harness. Cada flag (LOCK, IDEAS, PLAN, EXPLAIN, REQUIRE,
SUMMARY, EXIT) le indica al modelo qué tipo de pensamiento debe realizar.
Incluye una plantilla de prompt lista para usar que puede añadirse a cualquier
archivo de custom prompt y es portable entre harnesses.

### [Determinismo de DeepSeek V4 Flash](research/deepseek-v4-flash-determinism/README.es.md)

Tres experimentos que miden el determinismo de LLMs en tareas analíticas:
réplicas de un solo prompt (10×, σ=0.51), bifurcaciones encadenadas (3 ramas,
22-33% de acuerdo) y evaluación cruzada de modelos (4 modelos, 8 preguntas).
Reporta un Índice de Determinismo Global de 0.59 (pobremente determinista) y
muestra que el determinismo depende de la granularidad de la tarea — convergencia
en ranking grueso, divergencia en puntuación fina. Documenta la paradoja del
voto mayoritario (el sesgo correlacionado hace que el consenso sea menos fiable)
y 6 estrategias de mitigación, incluyendo orquestación multi-modelo.

### [DeepSeek V4 Flash vs Pro — Batalla de Prompts de Agente](research/deepseek-battle-agent-prompt/README.es.md)

Compara DeepSeek V4 Flash (Junior) y DeepSeek V4 Pro (Senior) como agentes
de código usando el mismo custom prompt. Documenta perfiles de comportamiento
(Flash: barrido amplio, impaciencia por cerrar, desviación bajo crítica;
Pro: visión de túnel, detección de seguridad, seguimiento multi-paso),
un árbol de decisión para selección de modelo, una estrategia de encadenamiento
Flash→Pro y 6 reglas de prompt derivadas del análisis cruzado de modelos.

### [DeepSeek V4 Flash vs Pro — Compactación](research/deepseek-battle-compaction/README.es.md)

Compara ambos modelos como modelos de compactación de contexto en OpenCode.
Demuestra que Flash produce mejores resultados 4× más rápido y 13× más
barato que Pro. Incluye la hipótesis "razonamiento vs extracción", perfiles
de modelo (investigador de efecto túnel vs explorador de espectro amplio),
mecanismos de escape de ambos modelos, consejos de prompt por modelo y el
hallazgo de que la preservación de identidad prevalece sobre la evidencia
en ambos.

### [Sistema de Memoria para Asistentes de Código](research/memory-system/README.es.md)

Un sistema de memoria manual con archivos planos para asistentes de código
con IA. Usa los operadores `>>`/`<<` para guardar y cargar contexto bajo
demanda — cero tokens hasta invocarlo. Compara tres enfoques: AGENTS.md de
OpenCode, una memoria autónoma gestionada por el modelo, y esta alternativa
con control humano. Documenta principios de diseño, flujo de trabajo,
operadores, scopes y un análisis comparativo en 17 dimensiones.

### [OpenCode Zen Free MiMo Flash — Análisis Comparativo](research/opencode-zen-free-mimo-flash/README.es.md)

Compara MiMo V2.5 Free y DeepSeek V4 Flash Free en 7 tareas basadas en
prompts evaluando adherencia a instrucciones, precisión en generación de
código, cumplimiento de estructura de salida y perfiles de comportamiento.
Reporta que Flash gana 5/7 preguntas con 81.3% de cumplimiento de
`custom.md` frente al 37.5% de MiMo. Basado en sesiones reales con
OpenCode, no en benchmarks estáticos.

### [OpenCode Zen Free Models — Evaluación](research/opencod-zen-free-models/README.es.md)

Evalúa 4 modelos gratuitos (DeepSeek V4 Flash Free, MiMo V2.5 Free,
MiniMax M3 Free, Nemotron 3 Super Free) como evaluadores analíticos en
8 preguntas secuenciales sobre 343 KB de documentos técnicos. Puntúa cada
modelo en calidad por pregunta, coherencia global, informe final, fluidez
operativa y coste teórico. DeepSeek lidera (9.14) con cero errores y
σ=0.35 estable; MiMo es el más rápido (213s) pero tiene errores de formato;
MiniMax es 3.7× más lento; Nemotron falla críticamente (4.29). Incluye
validación cruzada con 10 réplicas.

### [Reasoning Effort en DeepSeek V4 y OpenCode](research/opencode-deepseek-v4-reasoning-effort/README.es.md)

Documenta el flujo del parámetro `reasoning_effort` desde la API de
DeepSeek V4 hasta su integración con OpenCode. Revela que DeepSeek
detecta agentes complejos mediante señales multifactoriales (tools +
cabecera `x-session-affinity`), forzando `"max"` reasoning effort
independientemente del valor configurado en canales Go y Zen. Incluye
mapa de canales, guía práctica, procedimiento de verificación empírica
y análisis de drop-thinking.

### [Filtración de Descripciones de Skill](research/skill-desc-leak/README.es.md)

Investiga cómo las descripciones de skills entran automáticamente en el
system prompt en cada turno a través del bloque XML `available_skills`
(aproximadamente el 26% del system prompt). Incluye una prueba de concepto
con un skill de inyección de persona (Grillo), evidencia de degradación
real cuando los skills se acumulan y un ejemplo de sesgo tecnológico.
Documenta dos enfoques de mitigación: un enfoque solo de protocolo (Opción A)
y un cargador basado en plugin con carga bajo demanda (Opción B, recomendada).

---

## Plugins

### [opencode-tools-override](plugins/opencode-tools-override/README.es.md)

Un plugin que sobrescribe las descripciones de herramientas de OpenCode
usando archivos `.txt` planos. Las descripciones de herramientas tienen
mayor autoridad que las instrucciones del system prompt, lo que las convierte
en el lugar ideal para reglas de comportamiento, restricciones específicas
del dominio y flujos de trabajo personalizados. También ahorra tokens al
acortar descripciones integradas verbosas.

Utilizado en la investigación de [Filtración de Descripciones de Skill](research/skill-desc-leak/README.es.md)
como una de las dos opciones de mitigación (carga de skills basada en plugin).
También puede combinarse con el [Kit de Herramientas de Volcado de Contexto](research/context-dump/README.es.md):
sobrescribe las descripciones de herramientas antes de volcar para comparar
cómo diferentes descripciones afectan el comportamiento de uso de herramientas
del modelo.

---

*Antonio Muñoz*
