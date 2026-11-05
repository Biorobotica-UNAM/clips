# Planning con ROS 2 y CLIPS

Revisión documental: **4 de noviembre de 2026**, contrastada con fuentes y reglas locales.

## Descripción

Este repositorio implementa el planificador simbólico usado por Justina. El
flujo principal recibe directamente las metas semánticas producidas por el
modelo de lenguaje, las convierte en hechos CLIPS y expande cada meta en una
secuencia ordenada de acciones para el robot.

El sistema actual funciona como un compilador de metas basado en reglas: no
busca libremente entre planes posibles, sino que procesa las metas en el orden
recibido y aplica la regla correspondiente a cada una.

```text
JSON con goals
      ↓
goals_to_clips_node.py
  parsea, normaliza y clasifica
      ↓
(gpsr-goal ...)
      ↓
clips_node.py
  reinicia CLIPS, inserta hechos y dispara planificación
      ↓
goals_planning.clp
  expande goals → action-step → finalized-step → ros-message
      ↓
clips_node.py
  ordena, publica /clips/results y escribe el log
```

El repositorio conserva varios planes fijos seleccionables mediante
`plan_name`. El flujo anterior basado en primitivas de Dependencia Conceptual
fue retirado; el flujo actual utiliza metas JSON.

## Documentación técnica

La explicación completa de los templates, funciones, saliences, transiciones
de estado y reglas individuales de `goals_planning.clp` está disponible en:

- [Guía detallada de `goals_planning.clp`](docs/goals_planning_rules.md)

## Componentes principales

| Componente | Responsabilidad |
|---|---|
| `goals_to_clips_node.py` | Convierte el JSON de metas en hechos `gpsr-goal` |
| `clips_node.py` | Expone los servicios CLIPS, serializa el acceso al motor y publica el plan |
| `clips_engine.py` | Encapsula `clips.Environment` de Clipspy |
| `clips_components.py` | Selecciona archivos de reglas y extrae el plan resultante |
| `goals_planning.clp` | Expande las metas en acciones concretas para Justina |
| `plan_manager_node` | Recibe un plan completo y entrega instrucciones una por una |

## Estructura relevante

```text
clips/
├── clips_launch/
│   └── launch/
│       └── clips.launch.xml
├── clips_node/
│   ├── clips_node/
│   │   ├── goals_to_clips_node.py
│   │   ├── clips_node.py
│   │   ├── clips_engine.py
│   │   └── clips_components.py
│   └── clips_rules/
│       ├── goals_planning.clp
│       ├── hri_planning.clp
│       └── ...
├── plan_manager_node/
└── README.md
```

## Configuración del launch

`clips.launch.xml` inicia por defecto el flujo actual:

```xml
<arg name="plan_name" default="goals"/>
<arg name="use_goals_to_clips" default="true"/>
```

Los argumentos disponibles son:

| Argumento | Valor predeterminado | Función |
|---|---:|---|
| `plan_name` | `goals` | Prefijo del archivo o archivos `.clp` que se cargarán |
| `use_goals_to_clips` | `true` | Inicia el adaptador de JSON de metas |
| `clips_output` | `screen` | Configura la salida de los nodos en ROS 2 |

El cargador busca archivos `.clp` cuyo nombre coincida con `plan_name`. Para
`plan_name=goals` carga `goals_planning.clp`. Los archivos encontrados se
ordenan antes de cargarse para que el resultado sea reproducible.

El `RuleLoader` selecciona reglas mediante el parámetro `plan_name`.

Para seleccionar un plan fijo y no iniciar el conversor de metas:

```bash
ros2 launch clips_launch clips.launch.xml \
  plan_name:=hri \
  use_goals_to_clips:=false
```

## Namespace e interfaces ROS 2

En el despliegue del robot, este launch se incluye desde otro launch bajo el
namespace `/planning`.

`goals_to_clips_node` usa nombres absolutos para comunicarse con ese despliegue:

```text
/planning/goals_to_clips/convert
/planning/clips/assert_facts_batch
/planning/clips/start_planning
```

`clips_node` declara sus servicios y su topic con nombres relativos:

```text
clips/assert_fact
clips/assert_facts_batch
clips/start_planning
clips/results
```

Por ello, bajo el namespace `/planning`, se resuelven como
`/planning/clips/...`. El topic puede remapearse a `/clips/results` en el launch
superior cuando se conecta con `plan_manager_node`, que actualmente se suscribe
a ese nombre absoluto.

### Servicios

| Servicio | Tipo | Función |
|---|---|---|
| `/planning/goals_to_clips/convert` | `clips_interfaces/srv/String` | Recibe el JSON y coordina todo el ciclo |
| `clips/assert_fact` | `clips_interfaces/srv/String` | Inserta un hecho individual y ejecuta CLIPS |
| `clips/assert_facts_batch` | `clips_interfaces/srv/StringArray` | Reinicia CLIPS e inserta un lote de hechos |
| `clips/start_planning` | `std_srvs/srv/Trigger` | Inserta el hecho de inicio y ejecuta las reglas |

### Topic de salida

```text
clips/results    std_msgs/msg/String
```

El mensaje contiene el plan completo en una sola cadena, con una instrucción
por línea.

## Formato de entrada

El campo `data` del servicio de conversión debe contener JSON. Se aceptan dos
formas equivalentes.

Arreglo directo:

```json
[
  "go(kitchen)",
  "find(person, gesture=waving)",
  "guide(person, to=inspection point)"
]
```

Objeto con propiedad `goals`:

```json
{
  "goals": [
    "go(kitchen)",
    "find(person, gesture=waving)",
    "guide(person, to=inspection point)"
  ]
}
```

Cada elemento debe tener la forma:

```text
nombre_meta(argumento_principal, clave=valor, ...)
```

Los espacios dentro de argumentos se convierten en guiones bajos. Por ejemplo:

```text
cleaning supply  → cleaning_supply
living room      → living_room
inspection point → inspection_point
```

### Destinos

`deliver`, `guide`, `follow` y `place` aceptan tanto destinos nominales
como un segundo argumento posicional:

```text
deliver(cleaning supply, person)
deliver(spam, to=me)

guide(Laura, inspection point)
guide(Laura, to=inspection point)

follow(Matthew, kitchen)
follow(Matthew, to=kitchen)

place(cup, at=cabinet)
place(cup, on=table)
place(cup, in=box)
place(cup, table)
```

Si `follow` no tiene destino, se conserva vacío:

```text
follow(person)
follow(Michael)
```

En los argumentos posicionales de `deliver`, `guide` y `follow`, el segundo
argumento se interpreta como la relación `to`.

### Calificadores reconocidos

| Calificador | Ejemplo | Uso |
|---|---|---|
| `to` | `follow(person, to=sofa)` | Destinatario o destino |
| `at` | `place(cup, at=cabinet)` | Destino de colocación |
| `on` | `place(cup, on=table)` | Superficie de colocación |
| `in` | `place(cup, in=box)` | Destino contenedor |
| `gesture` | `find(person, gesture=waving)` | Búsqueda visual por gesto |
| `pose` | `find(person, pose=sitting)` | Búsqueda visual por pose |
| `wearing` | `find(person, wearing=red shirt)` | Búsqueda visual por vestimenta |
| `property` | `find(apple, property=biggest)` | Análisis visual del objeto |

Cuando se reciben varios calificadores visuales, el hecho `gpsr-goal` conserva
como `qualifier` el primero encontrado en este orden: `gesture`, `pose`,
`wearing`, `property`.

### Normalización de información hablada

Las preguntas frecuentes se traducen a claves que entiende el executor:

| Texto reconocido | Clave generada |
|---|---|
| Información sobre el robot | `about_yourself` |
| Hora actual | `current_time` |
| Nombre del equipo | `team_name` |
| País del equipo | `team_country` |
| Afiliación del equipo | `team_affiliation` |
| Día de hoy | `day_today` |
| Día de mañana | `day_tomorrow` |
| Día de la semana | `day_of_week` |
| Día del mes | `day_of_month` |

Por ejemplo:

```text
talk(what is your team name) → talk(team_name)
talk(what time is it)        → talk(current_time)
```

## Conversión a hechos `gpsr-goal`

Cada meta se convierte en un hecho con el siguiente template:

```clips
(deftemplate gpsr-goal
  (slot step (type INTEGER))
  (slot name)
  (slot target (default ""))
  (slot kind (default unknown))
  (slot destination (default ""))
  (slot relation (default ""))
  (slot value (default ""))
  (slot qualifier (default "")))
```

Ejemplo:

```text
find(person, gesture=waving)
```

se convierte en:

```clips
(gpsr-goal
  (step 1)
  (name find)
  (target "person")
  (kind person)
  (destination "")
  (relation "gesture")
  (value "waving")
  (qualifier "gesture:waving"))
```

Los slots cumplen estas funciones:

| Slot | Descripción |
|---|---|
| `step` | Orden de la meta en el JSON |
| `name` | Acción abstracta: `go`, `find`, `follow`, etc. |
| `target` | Objetivo principal |
| `kind` | `person`, `object`, `location`, `info` o `unknown` |
| `destination` | Lugar o destinatario de la acción |
| `relation` | Relación principal que produjo el valor |
| `value` | Valor de la relación principal |
| `qualifier` | Atributo visual codificado como `clave:valor` |

Los strings se escapan antes de insertarse en CLIPS. `name` y `kind` se escriben
como símbolos porque las reglas los comparan directamente con símbolos CLIPS.

## Inferencia y reparación de metas

Antes de construir los hechos, `GoalParser` analiza el plan completo para
distinguir personas, objetos, lugares e información.

Un target se interpreta como persona cuando, entre otros casos:

- aparece en `follow`, `guide` o `greet`;
- tiene un calificador `gesture`, `pose` o `wearing`;
- parece un nombre propio;
- es destinatario de un `deliver`;
- otra meta del plan lo utiliza en un contexto que requiere una persona.

También existe una reparación para una salida conocida de algunos modelos. La
secuencia incorrecta:

```text
go(person, gesture=waving)
follow(person, to=kitchen)
```

se transforma en:

```text
go(kitchen)
find(person, gesture=waving)
follow(person)
```

El destino se retira del `follow` reparado para no producir el desplazamiento
dos veces.

## Funcionamiento de `clips_node`

CLIPS no es thread-safe. Las operaciones de planificación se encolan y se ejecutan
secuencialmente en un único worker; la creación del entorno y la carga inicial
de reglas ocurren durante la construcción del nodo:

```text
callback ROS 2
      ↓
Queue de tareas
      ↓
worker único
      ↓
reset / assert / run / extract
```

El ciclo iniciado por `goals_to_clips_node` tiene dos llamadas:

1. `assert_facts_batch` limpia la memoria de trabajo, inserta todos los
   `gpsr-goal` y ejecuta el motor.
2. `start_planning` inserta `(start (name action-planning))` y vuelve a ejecutar
   el motor hasta vaciar la agenda.

El nodo conversor posee un nodo cliente con executor propio. Esto permite que
el callback de conversión espere las respuestas de ambos servicios sin impedir
que ROS 2 procese esas mismas respuestas.

## Funcionamiento de `goals_planning.clp`

### Inicialización

El hecho `(start (name action-planning))` activa `goals-initialize`, que crea:

```text
say-counter      = 1
act-counter      = 1001
person-counter   = 1
guest-counter    = 1
customer-counter = 1
location         = unknown
holding          = nothing
```

También agrega `GPSR_START` y habilita `planning-ready`.

### Orden de ejecución

Las reglas sólo pueden consumir una meta cuando no existe otra con un `step`
menor. De esta forma, aunque CLIPS evalúe varias reglas, las metas se expanden
en el orden original del JSON.

Cada regla retira el `gpsr-goal` procesado y agrega uno o más `action-step`.

### Metas soportadas

| Meta | Acciones principales generadas |
|---|---|
| `go(destino)` | `go_to`, confirmación de llegada |
| `find(objeto)` | `find_object` y análisis opcional |
| `find(persona)` | `find_person` o `find_pose`, aproximación según contexto y diálogo de nombre cuando corresponde |
| `take(objeto)` | `take`, si la manipulación está habilitada |
| `place(objeto, destino)` | navegación opcional, `find_space`, `drop` |
| `deliver(objeto, persona)` | localización del destinatario, `approach`, `give` |
| `guide(persona, destino)` | aviso, `go_to`, confirmación |
| `follow(persona, destino)` | localización, aproximación e instrucciones de seguimiento |
| `count(target)` | `analyze_objects`, regreso y reporte |
| `tell(info)` | selección y reproducción de una respuesta |
| `save(info)` | captura de nombre, pose o gesto |
| `answer_question()` | `listen` y `say` |
| `greet(persona)` | localización, aproximación y saludo |

Una meta no reconocida no bloquea el plan. Se convierte en una acción `say`
que informa que el robot no sabe ejecutarla.

### Estado y contexto

Las reglas mantienen un estado simbólico mínimo:

```clips
(current-state (location "unknown") (holding "nothing"))
```

Esto permite evitar navegaciones redundantes y comprobar algunas dependencias
de manipulación. Otros hechos recuerdan personas y análisis visuales:

- `visual-person-found`: relaciona un target con `guest_N` o `customer_N`;
- `last-person-context`: conserva la última persona observada;
- `visual-analysis`: permite reutilizar un análisis de objetos;
- `interaction-context`: conserva la identidad simbólica del interlocutor;
- `finalized-step` y `focus-normalized`: resultado y marca de la normalización del diálogo.

### Personas genéricas, nombradas y visuales

- Una persona genérica se busca con `find_person anybody`.
- Una persona con gesto, pose o ropa se busca con `find_pose` y se registra como
  `customer_N`.
- Una persona nombrada puede registrarse como `guest_N` preguntando y escuchando
  su nombre.
- Si la persona ya fue localizada dentro del plan, se reutiliza su identificador.

Los objetos se identifican normalmente como `nombre_1`, por ejemplo `apple_1`.

### Manipulación

La manipulación está habilitada por defecto en `goals_planning.clp`:

```clips
(defglobal ?*MANIPULATION_ENABLED* = TRUE)
```

En este modo las reglas generan el flujo real de `take`, `find_space`, `drop` y
`give`, y actualizan el objeto almacenado en `current-state.holding`.

Para trabajar sin comandos de brazo se puede cambiar el valor a `FALSE` o
configurar `manipulation-mode` antes de iniciar la planificación. En ese modo
sin manipulación, `take` se reemplaza por una explicación hablada y las acciones
posteriores que dependen de cargar ese objeto informan que no pueden
realizarse, manteniendo ejecutable el resto del plan.

### Colocación y superficies

Las reglas normalizan destinos de colocación a las superficies que entiende el
executor:

```text
table
container_down
container_top
shelf, shelf_1, shelf_2, shelf_3
floor
```

Los nombres genéricos como `table` o `shelf` se consideran superficies del
lugar actual. Destinos nombrados como `dining_table` o `storage_rack` pueden
producir primero una acción `go_to`.

`floor` no necesita `find_space`; las demás superficies generan normalmente
`find_space` antes de `drop`.

### Finalización, foco y serialización

Cuando ya no quedan metas, `add-final-return` agrega el regreso a
`instruction_point` cuando corresponde y `say "task completed"` como última
operación. No lo agrega al grupo inicial de anuncios.

Después, `organize-interaction-focus` llama a `normalize-interactions`: ordena
los `action-step`, conserva los anuncios desde `1` y vuelve a numerar las
operaciones desde `1001`. Inserta un solo ciclo de `focus enable/disable` por
secuencia adyacente de `say`/`listen` dirigida al mismo interlocutor, incluso
cuando procede de metas distintas. Un cambio de persona, anuncio general o
acción no dialogada cierra el ciclo. No activa foco para el anuncio final.

`append-dialogue` guarda una anotación interna de interlocutor. Esa anotación
no se publica como argumento del executor. `append-action` ignora intentos de
agregar `focus` directamente: la pasada final es la única autoridad del foco.
Los pasos normalizados se almacenan como `finalized-step`; después se serializan
a `ros-message` y se crea `GPSR_DONE`. No existe en esta versión el mecanismo
anterior basado en `focus-active`.

## Formato del plan publicado

`PlanExtractor` ordena los hechos `ros-message` por `step`, coloca las notas de
inicio y fin en los extremos y forma líneas como:

```text
==Justina GPSR_START==
Paso 1: Justina say I will navigate to kitchen
Paso 2: Justina say I will search for apple
Paso 1001: Justina go_to kitchen
Paso 1002: Justina say I have arrived at kitchen
Paso 1003: Justina find_object apple_1
Paso 1004: Justina go_to instruction_point
Paso 1005: Justina say task completed
==Justina GPSR_DONE==
```

El plan se publica como un solo `std_msgs/msg/String`, separado por saltos de
línea. Después de publicarlo también se agrega a `plan_execution.log`. El archivo
se vacía al iniciar el nodo: no es un diario histórico persistente entre reinicios. El nodo
busca primero un directorio de trabajo conocido y, si no lo encuentra, crea el
log en el directorio actual.

## Ejecución

### Compilar

```bash
source /opt/ros/jazzy/setup.bash
cd ~/Justina
colcon build --packages-up-to \
  knowledge_bank \
  clips_interfaces \
  clips_node \
  clips_launch \
  semantic_parser \
  planning_tools \
  plan_manager_node

source install/setup.bash
```

### Lanzar todo el entorno desde `planning_tools`

El launch de integración se encuentra normalmente en:

```text
~/Justina/src/Planning/planning_tools/launch/planning.launch.xml
```

Este launch crea el namespace `/planning` e inicia en conjunto:

- `clips_node` y `goals_to_clips_node` mediante `clips.launch.xml`;
- `semantic_parser` con la configuración de Qwen;
- los servicios necesarios para ejecutar el flujo comando → metas → plan.

Después de compilar y hacer `source` del workspace, el comando recomendado para
lanzar el entorno completo es:

```bash
ros2 launch planning_tools planning.launch.xml \
  plan_name:=goals
```

`planning.launch.xml` y `clips.launch.xml` usan `plan_name=goals` por defecto.
El nodo ejecutado directamente declara `plan_name=default`; en ese caso sí es
necesario pasar `-p plan_name:=goals` para cargar `goals_planning.clp`.

Para mostrar en pantalla los logs de CLIPS, cuyo valor predeterminado en este
launch es `log`, se puede usar:

```bash
ros2 launch planning_tools planning.launch.xml \
  plan_name:=goals \
  clips_output:=screen
```

Cuando la configuración de Qwen no se proporciona desde otro archivo o desde
el entorno, también pueden pasarse sus argumentos al launch:

```bash
ros2 launch planning_tools planning.launch.xml \
  plan_name:=goals \
  qwen_url:="<URL_DEL_SERVICIO>" \
  qwen_api_key:="<API_KEY>"
```

El launch ya configura estos valores para el flujo de metas:

```text
qwen_response_format = goals
use_entity_extractor = true
use_goals_to_clips   = true
```

### Lanzar solamente el planificador

Para depuración, sin iniciar `semantic_parser`, se puede ejecutar solamente el
motor bajo el namespace `/planning` y después el conversor:

```bash
ros2 run clips_node clips_node \
  --ros-args -r __ns:=/planning -p plan_name:=goals

ros2 run clips_node goals_to_clips_node
```

### Generar un plan de muestra desde un comando

Con `planning.launch.xml` ejecutándose, el script:

```text
~/Justina/src/Planning/planning_tools/scripts/qwen_to_plan.py
```

permite probar el flujo completo con una sola instrucción en lenguaje natural:

```bash
python3 ~/Justina/src/Planning/planning_tools/scripts/qwen_to_plan.py \
  "Go to the living room, find the waving person, and guide them to the inspection point"
```

Como el script también se instala como ejecutable del paquete, después de
compilar `planning_tools` se puede invocar de forma equivalente con:

```bash
ros2 run planning_tools qwen_to_plan.py \
  "Go to the living room, find the waving person, and guide them to the inspection point"
```

Desde la raíz de `~/Justina`, ejecutar el script por su ruta
`src/Planning/planning_tools/scripts/qwen_to_plan.py`, o utilizar `ros2 run`
como arriba. El script realiza automáticamente estas operaciones:

```text
comando en lenguaje natural
      ↓
/planning/semantic_parser/semantic_parser
      ↓
respuesta Qwen con {"goals": [...]}
      ↓
/planning/goals_to_clips/convert
      ↓
/planning/clips/results
      ↓
plan completo mostrado en la terminal
```

Durante la prueba imprime tres bloques:

```text
=== Qwen response ===
=== goals_to_clips response ===
=== Generated plan ===
```

La respuesta de Qwen debe ser un objeto JSON con una lista `goals` en el nivel
superior. Esta condición se satisface configurando
`qwen_response_format:=goals`, que ya es el valor predeterminado de
`planning.launch.xml`.

### Enviar metas directamente, sin Qwen

```bash
ros2 service call /planning/goals_to_clips/convert \
  clips_interfaces/srv/String \
  "{data: '{\"goals\":[\"go(living room)\",\"find(person, gesture=waving)\",\"guide(person, to=inspection point)\"]}'}"
```

Una respuesta correcta del adaptador es:

```text
data: OK
```

El `OK` indica que los servicios aceptaron los hechos y la solicitud de inicio.
El plan generado se observa en el topic de resultados y en los logs del nodo.

### Observar el plan

Sin namespace o con un remapeo al nombre histórico:

```bash
ros2 topic echo /clips/results
```

Bajo el namespace `/planning` y sin remapeo del topic:

```bash
ros2 topic echo /planning/clips/results
```

## `plan_manager_node`

El gestor de planes se suscribe a:

```text
/clips/results    std_msgs/msg/String
```

Extrae las líneas que contienen `Paso`, elimina el prefijo de numeración y
almacena las instrucciones. Expone:

```text
/request_instruction    std_srvs/srv/Trigger
/instruction_msg        std_msgs/msg/String
```

Cada llamada a `/request_instruction` devuelve y publica la siguiente
instrucción. Cuando no existe un plan activo responde `NoPlanAssigned`.

```bash
ros2 service call /request_instruction std_srvs/srv/Trigger '{}'
```

## Instalación de Clipspy

El script incluido instala CLIPS, Boost y Clipspy:

```bash
chmod +x install_clips_planning.sh
./install_clips_planning.sh
```

Instalación manual mínima del binding Python:

```bash
python3 -m pip install clipspy
```

El módulo se importa en Python como `clips`:

```python
import clips
```

## Extender el planificador

Para agregar una meta nueva:

1. Definir su formato de entrada en `GoalParser` si requiere normalización o
   inferencia especial.
2. Asegurar que `ClipsGoalFactBuilder` coloque la información necesaria en los
   slots de `gpsr-goal`.
3. Agregar una regla `process-<meta>` en `goals_planning.clp`.
4. Restringirla al `gpsr-goal` de menor paso para preservar el orden.
5. Retirar la meta procesada y generar acciones con `append-say` o
   `append-action`.
6. Validar el resultado observando los hechos `ros-message` y el topic final.

Las nuevas acciones deben usar los nombres y parámetros que entienda el
executor del robot.


## Nota de limpieza del flujo actual

Se retiraron los componentes del flujo anterior que no participan en
comando → metas JSON → hechos `gpsr-goal` → plan:

- El paquete y nodo `primitive_to_clips` y sus reglas `gpsr_planning.clp`.
- El nodo `natural_to_clips` y su registro como ejecutable.
- El respaldo `clips_node_backup.py`.
- `rules_list.dat`, el método `_parse_dat_file` y la constante `_DAT_FILENAME`.

También se eliminaron la dependencia y el bloque comentado de launch del nodo
antiguo, así como los métodos `interpretToClips` y `primitiveToClips` y sus
clientes en `planning_tools`. La GUI ahora espera `goals_to_clips_node`.
Los consumidores externos de esos métodos deben migrar a `goalsToClips`.

Se conservan `clips_node`, `goals_to_clips_node`, `clips_engine`,
`clips_components`, `goals_planning.clp`, `clips_launch` y `plan_manager_node`.
Los planes fijos se mantienen porque siguen disponibles en la GUI y mediante
`plan_name`.

Tras la limpieza, recompilar los paquetes afectados y volver a cargar
`install/setup.bash`. Los artefactos de compilaciones anteriores en `build/`
e `install/` no forman parte de esta limpieza de fuentes y pueden conservar
copias de los ejecutables retirados hasta limpiar o renovar esos artefactos.

## Carga de reglas y directorio de trabajo

`RuleLoader` busca reglas respecto al **directorio de trabajo**, no al share de
ament: `clips/clips_node/clips_rules`, `src/Planning/clips/clips_node/clips_rules`
y `src/clips/clips_node/clips_rules`. Ejecutar desde `~/Justina` permite usar
la segunda ruta. Un prefijo único selecciona `plan_name*.clp`; varios términos
separados por espacios o `_` deben aparecer todos en el nombre del archivo.
Un fallo de carga se registra en logs; que el nodo publique servicios no
certifica que las reglas se hayan cargado correctamente.

`clips.launch.xml` lanzado solo no añade `/planning`, mientras el conversor
utiliza destinos absolutos `/planning/clips/...`. Para el flujo integrado usar
`planning_tools`, o añadir el namespace al lanzar el motor directamente.

## Contratos y limitaciones comprobadas

- Los servicios CLIPS responden al **encolar** el trabajo. `OK`, `successful=true`
  o `success=true` no certifican que el worker haya terminado ni que la orden
  se cumpla; sus errores posteriores se registran en logs. El plan llega por topic.
- La cola serializa operaciones, pero la pareja «reset/lote → inicio» no es una
  transacción con identificador de solicitud. Usar un solo coordinador para evitar
  mezclar lotes o atribuir a una orden un plan ajeno. No hay cancelación de trabajo
  ni plazo duro del motor expuesto por estos servicios.
- El parser ROS infiere `kind` mediante contexto y heurísticas; no aplica el
  validador canónico del repositorio de entrenamiento. Un `kind=object` explícito
  no gobierna esa clasificación. La capitalización puede clasificar un objeto
  como persona. Documentar y comprobar esa diferencia en cualquier comparación.
- Se conserva un único calificador visual según `gesture`, `pose`, `wearing`,
  `property`; combinar atributos en JSON no acredita que CLIPS los exija todos.
- `count-query` genera `count_person` o `count_<target>` e ignora el calificador:
  no implementa conteo filtrado por ropa, pose o gesto.
- Peso y grosor pueden convertirse a extremos visuales de tamaño. Es una
  aproximación implementada, no una medición de peso ni cumplimiento estricto.
- Una meta no soportada produce una explicación y el cierre puede incluir
  `task completed` igualmente. `GPSR_DONE` indica fin de expansión, no éxito
  semántico ni físico. `place/drop` controlan el objeto cargado; `deliver` no
  impone por sí solo una adquisición previa equivalente.
- El gestor entrega instrucciones y sustituye su cola ante un nuevo plan; no
  confirma ejecución ni valida semánticamente la tarea. Los remapeos integrados
  se muestran en [planning_tools](../planning_tools/README.md#conectar-el-gestor-de-instrucciones).

## Verificación de esta revisión

Se cargaron las reglas locales con Clipspy y se generaron los cuatro planes
reproducidos en la [guía detallada](docs/goals_planning_rules.md). Se comprobó
consumo de metas, notas START/DONE y un único `task completed` al final. Esto no
inicia ROS, consulta Qwen ni certifica compilación completa o ejecución física.
Clipspy emitió avisos nativos `ENVRNMNT8` al liberar los entornos; la revisión
documental no modifica ni resuelve esa limitación.
