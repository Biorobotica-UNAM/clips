# Guía detallada de `goals_planning.clp`

## Propósito

Este documento describe la lógica de
[`goals_planning.clp`](../clips_node/clips_rules/goals_planning.clp): los hechos
que consume, el orden en que se activan sus reglas, el estado que mantiene y la
forma en que produce el plan final para Justina.

El archivo implementa el modo de planificación directa desde las metas
generadas por Qwen. Su entrada son hechos `gpsr-goal`; su salida son hechos
`ros-message` y dos notas que delimitan el plan:

```text
gpsr-goal
    ↓
regla process-*
    ↓
action-step
    ↓
serialize-action-step
    ↓
ros-message
```

La planificación es una expansión determinista de macros. Las metas se
procesan en el orden recibido y cada regla traduce una meta de alto nivel en
una o más acciones que entiende el executor del robot.

## Contenido

1. [Lugar dentro del sistema](#lugar-dentro-del-sistema)
2. [Modelo mental de CLIPS](#modelo-mental-de-clips)
3. [Contrato de entrada](#contrato-de-entrada)
4. [Hechos internos](#hechos-internos)
5. [Ciclo completo de planificación](#ciclo-completo-de-planificación)
6. [Orden y salience](#orden-y-salience)
7. [Funciones auxiliares](#funciones-auxiliares)
8. [Reglas detalladas](#reglas-detalladas)
9. [Contrato de acciones con el executor](#contrato-de-acciones-con-el-executor)
10. [Ejemplos completos](#ejemplos-completos)
11. [Comportamientos importantes](#comportamientos-importantes)
12. [Depuración](#depuración)
13. [Cómo agregar una regla](#cómo-agregar-una-regla)

## Lugar dentro del sistema

El archivo participa en este pipeline:

```text
JSON con goals
      ↓
goals_to_clips_node.py
      ↓
(gpsr-goal ...)
      ↓
clips_node.py: reset + assert_facts
      ↓
(start (name action-planning))
      ↓
goals_planning.clp
      ↓
(action-step ...)
      ↓
(ros-message ...)
      ↓
PlanExtractor
      ↓
/planning/clips/results
```

`goals_to_clips_node.py` se encarga de parsear y normalizar el JSON. Este
archivo no interpreta JSON: empieza a trabajar cuando los hechos `gpsr-goal`
ya están en la memoria de CLIPS.

`clips_node.py` ejecuta el motor hasta vaciar la agenda. Después,
`PlanExtractor` ordena los `ros-message` por número de paso y publica el plan.

## Modelo mental de CLIPS

Para entender las reglas conviene distinguir cuatro conceptos.

### Hecho

Es información presente en la memoria de trabajo:

```clips
(current-state (location "kitchen") (holding "apple"))
```

### Patrón del lado izquierdo

Es la condición necesaria para que una regla pueda activarse:

```clips
(planning-ready)
?g <- (gpsr-goal (name take) (target ?obj))
?st <- (current-state (location ?loc) (holding ?held))
```

Las variables comienzan con `?`. La forma `?g <- (...)` conserva una referencia
al hecho para poder retirarlo posteriormente.

### Acción del lado derecho

Se ejecuta después de `=>`. Normalmente la regla:

1. retira el `gpsr-goal` con `retract`;
2. agrega acciones con `append-say` o `append-action`;
3. actualiza hechos de estado o contexto.

### Salience

Es la prioridad de una regla. Una salience mayor se ejecuta antes cuando varias
reglas están activas al mismo tiempo. La salience decide, por ejemplo, si
`find(Laura)` debe usar la regla de persona nombrada o la regla genérica de
persona.

## Contrato de entrada

El template de entrada es:

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

### Significado de los slots

| Slot | Tipo esperado | Significado |
|---|---|---|
| `step` | entero | Orden de la meta dentro del plan |
| `name` | símbolo | Nombre de la meta: `go`, `find`, `take`, etc. |
| `target` | string | Objetivo principal de la acción |
| `kind` | símbolo | `person`, `object`, `location`, `info` o `unknown` |
| `destination` | string | Destino físico o destinatario |
| `relation` | string | Relación original: `to`, `on`, `in`, etc. |
| `value` | string | Valor asociado con `relation` |
| `qualifier` | string | Atributo codificado como `gesture:waving` |

Ejemplo de entrada:

```clips
(gpsr-goal
  (step 2)
  (name find)
  (target "person")
  (kind person)
  (destination "")
  (relation "gesture")
  (value "waving")
  (qualifier "gesture:waving"))
```

### Restricción de orden

Casi todas las reglas `process-*` contienen:

```clips
(not (gpsr-goal (step ?prev&:(< ?prev ?step))))
```

La condición significa: “no debe existir otra meta con un paso menor”. Sólo la
primera meta pendiente puede consumirse. Después de retirarla, la siguiente se
vuelve elegible.

Los valores de `step` deben ser únicos. `ClipsGoalFactBuilder` los genera de
forma consecutiva desde `1`.

## Hechos internos

El archivo declara 20 templates. Se pueden agrupar por responsabilidad.

### Control del ciclo

| Template | Propósito |
|---|---|
| `start` | Disparador recibido desde `clips/start_planning` |
| `planning-ready` | Habilita las reglas que consumen metas |
| `final-steps-added` | Evita agregar el cierre del plan más de una vez |
| `plan-note` | Marca `GPSR_START` y `GPSR_DONE` |

El disparador esperado es:

```clips
(start (name action-planning))
```

### Estado simbólico

```clips
(deftemplate current-state
  (slot location (default "unknown"))
  (slot holding (default "nothing")))
```

`location` representa el último destino que las reglas consideran alcanzado.
`holding` representa el objeto que el plan supone que está en la mano.

Este estado es predictivo: se actualiza al construir el plan, no después de
recibir confirmación física del robot.

### Manipulación

| Template | Propósito |
|---|---|
| `manipulation-mode` | Indica si se generan acciones reales de brazo |
| `manipulation-unavailable` | Recuerda que un `take` no pudo planearse para un objeto |

La configuración predeterminada actual es:

```clips
(defglobal ?*MANIPULATION_ENABLED* = TRUE)
```

### Pasos del plan

```clips
(deftemplate action-step
  (slot step (type INTEGER))
  (slot action)
  (slot arg (default "")))

(deftemplate ros-message
  (slot step (type INTEGER))
  (slot robot (default Justina))
  (slot action)
  (multislot params))
```

`action-step` es la representación intermedia. `ros-message` es el contrato de
salida que lee `PlanExtractor`.

### Contadores

| Template | Inicio | Uso |
|---|---:|---|
| `say-counter` | 1 | Numerar anuncios generales del plan |
| `act-counter` | 1001 | Numerar acciones operativas |
| `person-counter` | 1 | Reservado para identificadores de persona |
| `guest-counter` | 1 | Reservado para identificadores `guest_N` |
| `customer-counter` | 1 | Crear identificadores `customer_N` |

Los rangos separados son intencionales. Al ordenar el plan, primero aparecen
los anuncios `1, 2, 3...` y después las acciones `1001, 1002, 1003...`.

### Contexto de personas y percepción

| Template | Propósito |
|---|---|
| `visual-person-found` | Relaciona un target con `guest_last` o `customer_N` |
| `last-person-context` | Conserva la última persona y sus índices |
| `focus-active` | Refleja si se planeó `focus enable` sin un `disable` posterior |
| `visual-analysis` | Recuerda un análisis visual para reutilizar su respuesta |
| `saved-info` | Registra conceptualmente información solicitada con `save` |

Ejemplo:

```clips
(visual-person-found (target "person") (source "customer_1"))
(last-person-context
  (target "person")
  (source "customer_1")
  (guest-index "")
  (customer-index "1"))
```

## Ciclo completo de planificación

```text
1. assert_facts_batch
   ├─ reset de CLIPS
   └─ assert de todos los gpsr-goal

2. start_planning
   └─ assert (start (name action-planning))

3. goals-initialize
   ├─ crea contadores
   ├─ crea current-state
   ├─ crea planning-ready
   └─ crea GPSR_START

4. process-*
   ├─ selecciona el menor step pendiente
   ├─ retira ese gpsr-goal
   ├─ crea action-step
   └─ actualiza estado/contexto

5. add-final-return
   ├─ desactiva focus si es necesario
   ├─ regresa a instruction_point si aplica
   ├─ agrega task completed
   └─ crea final-steps-added

6. serialize-action-step
   └─ action-step → ros-message

7. goals-finish
   └─ crea GPSR_DONE

8. PlanExtractor
   ├─ ordena ros-message por step
   ├─ formatea líneas "Paso N"
   └─ publica el plan
```

## Orden y salience

| Salience | Regla o familia | Motivo de la prioridad |
|---:|---|---|
| 500 | `goals-initialize` | Preparar todos los hechos antes de procesar metas |
| 200 | `process-go` | Regla de navegación directa |
| 197 | `process-find-known-named-person` | Reutilizar una persona ya identificada |
| 196 | `process-place-drop-unavailable` | Manejar colocación después de un `take` no disponible |
| 195 | `process-find-named-person` | Preferir semántica de nombre sobre búsqueda genérica |
| 195 | `process-manipulation-dependent-unavailable` | Evitar acciones dependientes de un `take` fallido |
| 193 | `process-find-context-person` | Corregir `kind` mediante el contexto del plan |
| 190 | `process-find-person` | Búsqueda genérica de persona |
| 190 | `process-deliver-to-user` | Entrega al operador |
| 185 | `process-deliver-to-person` | Entrega a otra persona |
| 181 | `process-take-enabled` | Ganar sobre la variante deshabilitada |
| 181 | `process-place-drop-not-carrying` | Evitar colocar un objeto no cargado |
| 180 | Resto de reglas normales | Expansión estándar de metas |
| 20 | `add-final-return` | Añadir cierre después de consumir todas las metas |
| 10 | `process-unsupported-goal` | Sólo intervenir si ninguna regla conocida consumió la meta |
| 5 | `serialize-action-step` | Serializar después del cierre |
| 1 | `goals-finish` | Marcar fin cuando no quedan pasos intermedios |

La condición del menor `step` controla el orden entre metas. La salience
controla qué variante procesa la meta actual cuando varias coinciden.

## Funciones auxiliares

El archivo contiene 53 funciones. Las siguientes tablas describen su papel.

### Clasificación de personas

| Función | Resultado |
|---|---|
| `known-person-name` | Comprueba una lista explícita de nombres conocidos |
| `generic-person-target` | Detecta `""`, `person`, `user`, `me` y `anybody` |
| `named-person-target` | Niega la clasificación genérica |
| `named-person-goal` | Exige target nombrado y `kind person` o nombre conocido |

Los nombres conocidos actuales son Angel, Charlie, James, John, Michael,
David, Robert, William, Daniel, Matthew, Morgan, Sarah, Emily, Anna, Laura,
Simone y Sophia. Se aceptan la forma capitalizada y la forma en minúsculas.

### Modo de manipulación

| Función | Comportamiento |
|---|---|
| `clear-manipulation-mode` | Retira todos los hechos `manipulation-mode` |
| `set-manipulation-enabled` | Crea un único modo `TRUE` o `FALSE` |
| `manipulation-enabled` | Devuelve verdadero si existe modo habilitado |

`set-manipulation-enabled` interpreta como verdadero `TRUE`, `true`, `yes`,
`enabled` y `on`. Cualquier otro valor selecciona `FALSE`.

### Identificadores

| Función | Ejemplo |
|---|---|
| `object-id` | `object-id("apple")` produce `apple_1` |
| `person-id` | `person-id("Laura")` produce `Laura_1` |
| `next-person-id` | Genera `descripcion_N`; actualmente no la llama ninguna regla |
| `next-guest-source` | Genera `guest_N`; actualmente no la llama ninguna regla |
| `next-customer-source` | Genera `customer_N` para búsquedas visuales |
| `source-index` | `source-index("customer_2", "customer_")` produce `2` |
| `anonymous-person-arg` | Genera `anybody_<source>`; reservado actualmente |

Las reglas usan `guest_last` cuando el identificador real será resuelto en
runtime por `find_person`/`listen`.

### Contexto de persona y foco

| Función | Comportamiento |
|---|---|
| `clear-last-person-context` | Retira el contexto anterior |
| `remember-last-person` | Conserva una sola persona como contexto actual |
| `clear-focus-active` | Retira todos los marcadores de foco |
| `focus-is-active` | Consulta si existe `focus-active` |
| `customer-source` | Detecta identificadores que empiezan con `customer_` |

`append-action` actualiza automáticamente `focus-active` cuando agrega
`focus enable` o `focus disable`. El hecho describe el foco planeado, no una
confirmación del subsistema HRI.

### Inferencia de persona por contexto

`target-is-person-by-plan-context` revisa el resto de los `gpsr-goal`. Considera
que un target es persona si:

- aparece como target de `guide`, `follow`, `greet`, `meet` o `introduce`;
- aparece como destinatario de `tell`, `ask` o `answer`;
- aparece codificado en un qualifier con formas como `to=Laura`, `to:Laura`,
  `person=Laura` o variantes con espacio/guion bajo.

Esta inferencia es una segunda defensa cuando el adaptador Python entregó
`kind` distinto de `person`.

La función `recipient-mentions-target` implementa la búsqueda de las distintas
formas textuales del destinatario dentro de un valor o qualifier.

`next-goal-name` y `next-goal-is-talk` localizan la siguiente meta. Se usan para
decidir si una búsqueda nombrada debe conservar el foco para un `tell`
inmediato.

### Destinos y superficies

| Función | Propósito |
|---|---|
| `support-name` | Reconoce palabras relacionadas con superficies; reservada actualmente |
| `support-only-destination` | Detecta una superficie genérica que no requiere navegación |
| `placement-needs-navigation` | Decide si se agrega `go_to` antes de colocar |
| `table-support` | Reconoce mesa; reservada actualmente |
| `drop-surface` | Normaliza el destino al vocabulario de `find_space`/`drop` |
| `destination-phrase` | Construye texto hablado con `to`, `on` o `in` |

`support-only-destination` reconoce exactamente valores genéricos como
`table`, `shelf`, `container`, `bin` o `floor`. Un nombre compuesto como
`dining_table` no es genérico y puede requerir navegación.

Prioridad de `drop-surface`:

1. `floor` o `suelo` → `floor`;
2. `shelf_3`, `shelf_2`, `shelf_1` → el mismo nivel;
3. shelf/rack/cabinet/bookcase/estante/repisa → `shelf`;
4. container superior/encima → `container_top`;
5. container/trash/bin/box y equivalentes → `container_down`;
6. cualquier otro valor → `table`.

### Texto y atributos

| Función | Propósito |
|---|---|
| `empty-value` | Trata `""` y `"unknown"` como vacíos |
| `contains-text` | Comprueba si un string contiene otro |
| `describe-target` | Une target y qualifier para anuncios |
| `spoken-target` | Convierte `property:biggest` en `the biggest <target>` |
| `qualifier-value` | Extrae el valor de un prefijo como `gesture:` |
| `normalize-person-attribute` | Convierte espacios/guiones en `_` y elimina apóstrofos |
| `normalize-gesture-attribute` | Normaliza pointing, waving y raising |
| `describe-person-target` | Produce una descripción hablada de persona |
| `guide-intro-text` | Construye el anuncio general de una meta `guide` |
| `guide-start-text` | Construye la instrucción “Please follow me...” |
| `guide-finished-text` | Construye la confirmación posterior a la navegación |

### Consultas perceptuales y respuestas

| Función | Ejemplo de resultado |
|---|---|
| `count-query` | `count_person`, `count_apple`, `count_objects` |
| `size-filter` | `big`, `small` o vacío |
| `analyze-object-query` | `biggest_apple` o `smallest_apple` |
| `analyze-answer-key` | `biggest_category`, `heaviest_category`, etc. |
| `talk-answer-key` | `team_name`, `current_time`, `day_today`, etc. |
| `talk-intro-text` | Anuncio previo apropiado para la respuesta |
| `answer-releases-focus` | Indica qué respuestas deben cerrar el foco |
| `analyze-person-query` | `gesture_waving`, `color_red_shirt`, etc. |
| `find-pose-query` | Agrega el índice: `waving_1`, `color_red_shirt_2` |

`heaviest` usa `big` como aproximación visual. `lightest` y `thinnest` usan
`small`. No se realiza una medición física de peso o grosor.

### Creación de pasos

#### `append-say`

Consume `say-counter`, lo incrementa y crea:

```clips
(action-step (step 1) (action say) (arg "I will navigate to kitchen"))
```

Se utiliza para presentar el plan o explicar la intención general.

#### `append-action`

Consume `act-counter`, lo incrementa y crea una acción operativa desde el paso
`1001`. Además mantiene `focus-active` cuando la acción es `focus`.

#### `append-focused-say`

Para respuestas que requieren mirar al interlocutor:

```text
focus enable, si todavía no está activo
say <answer-key>
focus disable
```

#### `append-drop-sequence`

Para `floor` genera directamente:

```text
drop floor
```

Para cualquier otra superficie genera:

```text
find_space <surface>
drop <object_id>
```

## Reglas detalladas

### `goals-initialize`

**Salience:** 500.

Se activa con `(start (name action-planning))` siempre que no existan notas
`GPSR_START` ni `GPSR_DONE`.

Acciones:

1. retira el hecho `start`;
2. inicializa todos los contadores;
3. crea `manipulation-mode` desde el `defglobal` si no existe uno;
4. crea `current-state` en `unknown` y `nothing`;
5. crea `planning-ready`;
6. crea `plan-note GPSR_START`.

Las notas impiden inicializar dos veces el mismo ciclo. Un nuevo batch debe
hacer `reset` antes de iniciar otro plan.

### Navegación: `process-go`

**Salience:** 200.

Entrada:

```clips
(gpsr-goal (name go) (target ?dest))
(current-state (location ?loc) (holding ?held))
```

Si `?loc` y `?dest` son distintos, genera:

```text
anuncio: I will navigate to <dest>
go_to <dest>
say I have arrived at <dest>
```

Después reemplaza `current-state` conservando `holding` y actualizando
`location`.

Si el robot ya está simbólicamente en el destino, sólo retira la meta. No crea
acciones ni modifica el estado.

### Búsqueda: familia `process-find-*`

Cinco reglas pueden procesar `find`. La prioridad es:

```text
persona nombrada ya encontrada (197)
      ↓
persona nombrada nueva (195)
      ↓
persona inferida por contexto (193)
      ↓
persona genérica (190)
      ↓
objeto (180)
```

#### `process-find-known-named-person`

Se activa cuando:

- el target representa una persona nombrada;
- ya existe `visual-person-found` para ese target.

Genera:

```text
anuncio de búsqueda
find_person <source_previo>
focus enable
say acknowledge_name_last
focus disable
```

Reutiliza el source anterior y actualiza `last-person-context`. Evita registrar
otra persona anónima para un nombre confirmado previamente.

#### `process-find-named-person`

Se activa para un target no genérico cuyo `kind` es `person`, o para uno de los
nombres incluidos en `known-person-name`.

Genera:

```text
anuncio de búsqueda
find_person anybody
say ask_name
listen guest_name_last
focus enable
say acknowledge_name_last
focus disable, excepto si la siguiente meta es tell
```

También registra:

```clips
(visual-person-found (target <nombre>) (source "guest_last"))
```

`guest_name_last` permite que el runtime asocie la respuesta con el último
guest creado por `find_person`.

#### `process-find-context-person`

Se activa cuando `kind` no es `person`, pero
`target-is-person-by-plan-context` encuentra evidencia de que el target sí es
una persona.

Después sigue la misma estrategia perceptual de la regla genérica:

- con atributo visual: `find_pose`, `approach customer_N`;
- sin atributo: `find_person anybody` y source `guest_last`;
- finalmente: `focus enable`.

#### `process-find-person`

Se activa directamente con `kind person`.

Con `gesture`, `pose` o `wearing`:

```text
customer_N = siguiente identificador
find_pose <atributo_N>
approach customer_N
registrar visual-person-found
registrar last-person-context
focus enable
```

Ejemplos:

```text
gesture:waving  → find_pose waving_1
pose:sitting    → find_pose sitting_1
wearing:red_shirt → find_pose color_red_shirt_1
```

Sin atributo visual:

```text
find_person anybody
source = guest_last
focus enable
```

La variante genérica sin atributo no agrega `approach`; las reglas posteriores
pueden utilizar el source guardado cuando necesiten aproximarse.

#### `process-find-object`

Se activa para cualquier `find` cuyo `kind` no sea `person`, siempre que las
reglas de persona más específicas no lo hayan consumido.

Sin qualifier:

```text
anuncio: I will search for <target>
find_object <target>_1
```

Con una propiedad visual reconocida:

```text
find(apple, property=biggest)
→ analyze_objects biggest_apple
→ visual-analysis(... answer biggest_category)
```

Para `biggest` o `smallest`, el análisis sustituye `find_object`. Si el
qualifier no produce una consulta válida, la regla conserva `find_object` como
fallback.

### Manipulación: `take`, `place` y `deliver`

#### `process-take-enabled`

**Salience:** 181.

Requiere `manipulation-enabled`. Genera:

```text
anuncio: I will pick up <obj>
take <obj>_1
say I have picked up <obj>
```

Después actualiza:

```clips
(current-state (location <sin_cambio>) (holding <obj>))
```

No comprueba que la mano estuviera vacía; reemplaza el valor anterior de
`holding` por el nuevo objeto.

#### `process-take-disabled`

**Salience:** 180.

Se activa en modo seguro. Sustituye `take` por mensajes hablados, registra:

```clips
(manipulation-unavailable (target <obj>))
```

y deja `holding` como `nothing`. Este hecho bloquea las operaciones posteriores
que dependan del mismo objeto.

#### `process-place-drop-unavailable`

**Salience:** 196.

Procesa `place` cuando existe `manipulation-unavailable` para el
objeto. Puede conservar la navegación hacia un destino nombrado, pero sustituye
la manipulación por una explicación hablada.

#### `process-manipulation-dependent-unavailable`

**Salience:** 195.

Es el fallback general para `deliver` o `place` después de un `take`
no disponible. La regla especializada anterior gana para `place`; ésta es
especialmente relevante para `deliver`.

#### `process-place-drop-not-carrying`

**Salience:** 181.

Se activa cuando `holding` es distinto del objeto y no existe un hecho
`manipulation-unavailable`. Retira la meta, conserva el estado y genera una
explicación hablada. Evita emitir `drop` para un objeto que el estado simbólico
no considera cargado.

#### `process-place`

Requiere `holding` igual al target.

1. agrega navegación si `placement-needs-navigation` es verdadero;
2. anuncia `I will place ...` usando `destination-phrase`;
3. llama a `append-drop-sequence`;
4. confirma la colocación;
5. deja `holding` como `nothing` y `location` igual a `destination`.

Ejemplo:

```text
place(apple, on=table)
→ find_space table
→ drop apple_1
→ say I have placed apple
```

#### `process-drop`

Es equivalente a `process-place`, pero utiliza los textos `drop`/`dropped`.
Para `floor`, `append-drop-sequence` genera `drop floor` sin `find_space`.

#### `process-deliver-to-user`

Se activa con destination `me`, `user` o vacío.

1. si la ubicación no es `instruction_point`, agrega el regreso;
2. anuncia la entrega al operador;
3. genera `approach host_1`;
4. genera `give <obj>_1`;
5. confirma la entrega;
6. deja location en `instruction_point` y holding en `nothing`.

La regla no exige directamente `holding == obj`. Normalmente la secuencia de
metas debe contener el `take` correspondiente. Si el `take` fue rechazado por
el modo seguro, las reglas de `manipulation-unavailable` interceptan primero la
entrega.

#### `process-deliver-to-person`

Se activa con cualquier destination no vacía diferente de `me` y `user`.

Selección del destinatario:

1. si existe `visual-person-found`, usa `approach <source>`;
2. si el nombre está en `known-person-name`, busca `anybody`, pregunta y escucha
   el nombre, y se aproxima a `guest_last`;
3. en otro caso usa `find_person <persona>_1` y `approach <persona>_1`.

Después genera `give <obj>_1`, confirma la entrega y deja `holding` en
`nothing`. La ubicación simbólica se conserva.

### Interacción con personas

#### `process-guide`

Genera:

```text
anuncio: I will guide <person> to <dest>
say Please follow me to <dest>
go_to <dest>
say I have guided <person> to <dest>
focus disable
```

Actualiza `current-state.location` al destino y conserva `holding`.

Esta regla presupone que la persona apropiada ya está disponible; no genera
`find_person` ni `approach`. Si son necesarios, deben aparecer como metas
anteriores.

#### `process-follow`

Primero intenta resolver a quién seguir:

- si existe `visual-person-found`, reutiliza su source;
- si el source no es `customer_N`, agrega `approach`;
- si el source es `customer_N`, supone que la búsqueda visual ya realizó el
  `approach` y evita repetirlo;
- si no existe source, ejecuta `find_person anybody`, registra `guest_last` y
  se aproxima;
- si además es un nombre conocido, pregunta y confirma el nombre.

Después controla el foco y genera:

```text
con destino:
  say I will follow <person> to <dest>
  say instruct_follow_to_<dest>

sin destino:
  say instruct_follow_only

final:
  focus disable
```

La regla no genera una acción llamada `follow` ni actualiza `current-state`.
El comportamiento de seguimiento se expresa mediante las claves habladas
`instruct_follow_to_*` o `instruct_follow_only`, que debe interpretar el
executor/HRI.

#### `process-greet`

Si la persona ya está registrada, se aproxima a su source. Si no:

1. ejecuta `find_person anybody`;
2. registra `guest_last`;
3. para nombres conocidos, pregunta y confirma el nombre;
4. ejecuta `approach guest_last`.

Finalmente genera:

```text
focus enable
say greet
focus disable
```

### Conteo, conversación y memoria

#### `process-count`

Genera una consulta con `count-query`:

```text
count(person) → analyze_objects count_person
count(apple)  → analyze_objects count_apple
```

Si el estado no está en `instruction_point`, agrega navegación de regreso para
reportar el resultado. Finalmente:

```text
focus enable
say count_category
focus disable
```

Actualiza `location` a `instruction_point` y conserva `holding`.

#### `process-tell`

Procesa `tell`.

La selección de salida sigue este orden:

1. si la información habla de gesto, usa el anuncio específico;
2. si `talk-answer-key` reconoce la información, usa `talk-intro-text`;
3. si el qualifier implica biggest/smallest/heaviest/etc., anuncia el reporte;
4. en otro caso anuncia literalmente la información.

La acción final sigue otra decisión:

- propiedad visual: reutiliza `visual-analysis` o ejecuta `analyze_objects`, y
  dice la clave de respuesta;
- `info == name`: dice `saved_name`;
- qualifier no vacío: dice el qualifier;
- información conocida: usa `append-focused-say`;
- fallback: dice literalmente `info`.

Ejemplos:

```text
tell(team_name)
→ focus enable
→ say team_name
→ focus disable

tell(apple, property=biggest)
→ analyze_objects biggest_apple, si no existe análisis previo
→ say biggest_category
```

#### `process-save`

Siempre crea `(saved-info (value ?info))` y un anuncio.

Para información que contiene `name`:

- reutiliza el contexto guest si existe;
- de lo contrario busca `anybody` y registra `guest_last`;
- pregunta el nombre;
- escucha con `guest_name_last`;
- confirma y cierra el foco.

Para `gesture` o `pose`:

- reutiliza el `customer-index` del último contexto o crea uno;
- para gesture ejecuta `analyze_person gesture_any` y
  `find_pose gesture_<N>`;
- para pose ejecuta `find_pose pose_<N>`;
- registra el nuevo contexto visual.

Para cualquier otra información agrega `say I will remember <info>`.

#### `process-answer-question`

Genera:

```text
anuncio: I will answer the question
listen answer_question
say answer_question
focus disable
```

La interpretación de la pregunta y la selección de la respuesta quedan en el
executor asociado con esas claves.

### Fallback y cierre

#### `process-unsupported-goal`

**Salience:** 10.

Consume cualquier meta que no haya coincidido con una regla conocida:

```text
say I do not know how to execute goal <name> <target>
```

Su prioridad baja permite que todas las reglas específicas tengan preferencia.

#### `add-final-return`

**Salience:** 20.

Se activa cuando no queda ningún `gpsr-goal` y aún no existe
`final-steps-added`.

1. agrega `focus disable` si el foco sigue activo;
2. agrega `go_to instruction_point` si la ubicación es diferente;
3. agrega `say task completed`;
4. crea `final-steps-added`.

Como la ubicación inicial es `unknown`, un plan que no actualice la ubicación
también genera el regreso final.

#### `serialize-action-step`

**Salience:** 5.

Sólo se activa cuando:

- no quedan metas;
- ya se agregaron los pasos finales;
- existe un `action-step`.

Retira cada `action-step` y crea:

```clips
(ros-message
  (step ?step)
  (robot Justina)
  (action ?action)
  (params ?arg))
```

No depende del orden en que CLIPS serialice los hechos, porque `PlanExtractor`
los ordena posteriormente por `step`.

#### `goals-finish`

**Salience:** 1.

Cuando ya no quedan metas ni `action-step`, crea:

```clips
(plan-note (robot Justina) (state GPSR_DONE))
```

## Contrato de acciones con el executor

Las reglas pueden emitir las siguientes acciones:

| Acción | Argumento típico | Significado esperado |
|---|---|---|
| `go_to` | `kitchen` | Navegar a un destino conocido |
| `say` | texto o clave | Pronunciar texto o resolver una respuesta registrada |
| `listen` | `guest_name_last` | Escuchar y guardar información bajo una clave |
| `find_person` | `anybody`, `guest_last`, `Laura_1` | Buscar una persona |
| `find_pose` | `waving_1`, `color_red_shirt_1` | Buscar persona por atributo visual |
| `approach` | `guest_last`, `customer_1`, `host_1` | Aproximarse a una persona |
| `focus` | `enable`, `disable` | Activar o liberar atención hacia la persona |
| `find_object` | `apple_1` | Localizar un objeto |
| `analyze_objects` | `count_apple`, `biggest_apple` | Obtener conteo o extremo visual |
| `analyze_person` | `gesture_any` | Obtener un atributo de la persona |
| `take` | `apple_1` | Tomar un objeto |
| `find_space` | `table`, `shelf`, `container_down` | Encontrar una pose segura de colocación |
| `drop` | `apple_1` o `floor` | Soltar el objeto |
| `give` | `apple_1` | Entregar el objeto a la persona aproximada |

Claves como `team_name`, `ask_name`, `acknowledge_name_last`, `greet`,
`count_category` o `answer_question` no son frases finales necesariamente. El
executor puede resolverlas usando su conocimiento y resultados perceptuales.

## Ejemplos completos

Los siguientes planes fueron generados cargando directamente el archivo CLIPS
con Clipspy y usando los hechos producidos por `ClipsGoalFactBuilder`.

### Ejemplo 1: navegar, encontrar, tomar y colocar

Entrada:

```json
{
  "goals": [
    "go(kitchen)",
    "find(apple)",
    "take(apple)",
    "place(apple, on=table)"
  ]
}
```

Hechos relevantes:

```clips
(gpsr-goal (step 1) (name go) (target "kitchen") (kind location) ...)
(gpsr-goal (step 2) (name find) (target "apple") (kind object) ...)
(gpsr-goal (step 3) (name take) (target "apple") (kind object) ...)
(gpsr-goal (step 4) (name place) (target "apple")
  (destination "table") (relation "on") (value "table") ...)
```

Evolución del estado:

```text
inicio                 location=unknown  holding=nothing
después de go          location=kitchen  holding=nothing
después de find        location=kitchen  holding=nothing
después de take        location=kitchen  holding=apple
después de place       location=table    holding=nothing
```

Plan final:

```text
==Justina GPSR_START==
Paso 1: Justina say I will navigate to kitchen
Paso 2: Justina say I will search for apple
Paso 3: Justina say I will pick up apple
Paso 4: Justina say I will place apple on table
Paso 1001: Justina go_to kitchen
Paso 1002: Justina say I have arrived at kitchen
Paso 1003: Justina find_object apple_1
Paso 1004: Justina take apple_1
Paso 1005: Justina say I have picked up apple
Paso 1006: Justina find_space table
Paso 1007: Justina drop apple_1
Paso 1008: Justina say I have placed apple
Paso 1009: Justina go_to instruction_point
Paso 1010: Justina say task completed
==Justina GPSR_DONE==
```

Aunque `table` no requirió navegación previa a la colocación, la regla deja la
ubicación simbólica como `table`; por ello el cierre agrega regreso a
`instruction_point`.

### Ejemplo 2: persona por gesto y guía

Entrada:

```json
{
  "goals": [
    "go(living room)",
    "find(person, gesture=waving)",
    "guide(person, to=inspection point)"
  ]
}
```

Plan final:

```text
==Justina GPSR_START==
Paso 1: Justina say I will navigate to living_room
Paso 2: Justina say I will look for person waving
Paso 3: Justina say I will guide person to inspection_point
Paso 1001: Justina go_to living_room
Paso 1002: Justina say I have arrived at living_room
Paso 1003: Justina find_pose waving_1
Paso 1004: Justina approach customer_1
Paso 1005: Justina focus enable
Paso 1006: Justina say Please follow me to inspection_point
Paso 1007: Justina go_to inspection_point
Paso 1008: Justina say I have guided person to inspection_point
Paso 1009: Justina focus disable
Paso 1010: Justina go_to instruction_point
Paso 1011: Justina say task completed
==Justina GPSR_DONE==
```

Puntos clave:

- `gesture:waving` se convierte en `find_pose waving_1`;
- la persona se registra como `customer_1`;
- `find` ya genera `approach`;
- `guide` conserva el foco durante la interacción y actualiza la ubicación.

### Ejemplo 3: persona nombrada y seguimiento

Entrada:

```json
{
  "goals": [
    "find(Laura)",
    "follow(Laura, to=entrance)"
  ]
}
```

Plan final:

```text
==Justina GPSR_START==
Paso 1: Justina say I will look for Laura
Paso 2: Justina say I will follow Laura to entrance
Paso 1001: Justina find_person anybody
Paso 1002: Justina say ask_name
Paso 1003: Justina listen guest_name_last
Paso 1004: Justina focus enable
Paso 1005: Justina say acknowledge_name_last
Paso 1006: Justina focus disable
Paso 1007: Justina approach guest_last
Paso 1008: Justina focus enable
Paso 1009: Justina say I will follow Laura to entrance
Paso 1010: Justina say instruct_follow_to_entrance
Paso 1011: Justina focus disable
Paso 1012: Justina go_to instruction_point
Paso 1013: Justina say task completed
==Justina GPSR_DONE==
```

`find(Laura)` no presupone reconocimiento facial. Primero captura una persona
anónima y confirma su nombre. `follow` reutiliza `guest_last` y no vuelve a
ejecutar `find_person`.

### Ejemplo 4: respuesta conocida

Entrada:

```json
{"goals": ["tell(what is your team name)"]}
```

El adaptador normaliza el target a `team_name`. El plan es:

```text
==Justina GPSR_START==
Paso 1: Justina say I will announce my team name
Paso 1001: Justina focus enable
Paso 1002: Justina say team_name
Paso 1003: Justina focus disable
Paso 1004: Justina go_to instruction_point
Paso 1005: Justina say task completed
==Justina GPSR_DONE==
```

El executor transforma la clave `team_name` en el contenido hablado final.

## Comportamientos importantes

### El estado representa el plan, no la ejecución real

Las reglas actualizan `current-state` inmediatamente después de agregar una
acción. No esperan confirmación de navegación, manipulación o percepción. La
supervisión de errores durante la ejecución pertenece a otro nivel del sistema.

### No todas las reglas actualizan ubicación

- `go`, `guide`, `count`, `place` y `deliver-to-user` sí la actualizan;
- `find`, `take`, `tell`, `save`, `greet` y `deliver-to-person` la conservan;
- `follow` no consulta ni modifica `current-state`.

Esto influye en si `add-final-return` agrega `go_to instruction_point`.

### `guide` y `follow` tienen contratos diferentes

`guide` genera navegación real con `go_to <destination>`. `follow` genera claves
de instrucción y no actualiza la ubicación. No deben interpretarse como reglas
simétricas.

### Los anuncios se agrupan antes de las acciones

Todos los `append-say` usan el rango bajo y todos los `append-action` el rango
alto. Aunque cada regla se ejecuta de forma secuencial, el plan ordenado muestra
primero todas las intenciones y después todas las operaciones.

### El foco es estado planeado

`focus-active` evita algunos `focus enable` duplicados y permite cerrar el foco
al final. No representa una confirmación de que el sensor o la cabeza alcanzaron
el estado solicitado.

### La entrega supone una secuencia coherente

Las reglas de `place` exigen que `holding` coincida con el objeto.
`deliver` no impone directamente esa condición. El generador de metas debe
producir normalmente `take(obj)` antes de `deliver(obj, persona)`.

### El modo configurado mediante hechos dura un ciclo

`assert_facts_batch` ejecuta `reset`, por lo que elimina hechos dinámicos del
plan anterior. Si se desea sobrescribir `manipulation-mode` para un ciclo, el
hecho debe existir después del reset y antes del disparador `start`.

### Funciones reservadas

`next-person-id`, `next-guest-source`, `anonymous-person-arg`, `support-name` y
`table-support` están definidas pero actualmente no son llamadas por las
reglas. Se conservan como utilidades para extensiones o compatibilidad.

## Depuración

### Observar el plan publicado

```bash
ros2 topic echo /planning/clips/results
```

### Enviar un conjunto mínimo de metas

```bash
ros2 service call /planning/goals_to_clips/convert \
  clips_interfaces/srv/String \
  "{data: '{\"goals\":[\"go(kitchen)\",\"find(apple)\"]}'}"
```

### Revisar el log

`clips_node` escribe el plan en `plan_execution.log`. También registra:

- número total de reglas disparadas;
- hechos `action-step`, `ros-message` y `sub-task` presentes después del run;
- cantidad de pasos publicados.

### Activar observación nativa de CLIPS

Para una prueba directa con Clipspy se pueden activar los watchers antes de
`run()`:

```python
engine.eval("(watch rules)")
engine.eval("(watch facts)")
```

Esto permite ver qué regla se dispara y qué hechos se insertan o retiran. Debe
usarse sólo para depuración porque produce una salida extensa.

### Diagnóstico por ausencia de salida

Si no aparecen `ros-message`, revisar en este orden:

1. que se haya cargado `goals_planning.clp` con `plan_name:=goals`;
2. que existan hechos `gpsr-goal` válidos;
3. que se haya insertado `(start (name action-planning))`;
4. que exista `planning-ready` después de la inicialización;
5. que cada meta tenga un `step` entero;
6. que el worker de `clips_node` no haya registrado una excepción;
7. que se esté observando el topic correcto para el namespace.

## Cómo agregar una regla

Supongamos una meta nueva:

```text
wait(door_open)
```

### 1. Definir el contrato de entrada

Decidir cómo se usarán los slots:

```clips
(gpsr-goal
  (step 1)
  (name wait)
  (target "door_open")
  (kind unknown)
  ...)
```

Si requiere normalización especial, actualizar `GoalParser` o
`ClipsGoalFactBuilder`.

### 2. Crear la regla

```clips
(defrule process-wait
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name wait) (target ?condition))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (append-say (str-cat "I will wait for " ?condition))
  (append-action listen ?condition))
```

### 3. Verificar invariantes

Toda regla normal debe:

- requerir `planning-ready`;
- respetar el menor `step`;
- retirar exactamente la meta que consume;
- usar `append-say` para el resumen y `append-action` para operaciones;
- actualizar `current-state` si cambia ubicación o carga;
- mantener coherentes `focus-active` y los contextos perceptuales;
- permitir que `process-unsupported-goal` siga siendo el fallback final.

### 4. Probar el plan completo

No basta con comprobar que apareció la nueva acción. También se debe verificar:

- orden de los pasos;
- regreso final;
- notas `GPSR_START` y `GPSR_DONE`;
- interacción con la meta anterior y posterior;
- comportamiento con targets vacíos o desconocidos;
- comportamiento con manipulación habilitada y deshabilitada, si aplica;
- formato que espera el executor.

## Resumen

`goals_planning.clp` convierte metas ordenadas en acciones mediante tres
principios:

1. **Orden estricto:** sólo se procesa el menor `step` pendiente.
2. **Selección por prioridad:** la salience escoge la interpretación más
   específica cuando varias reglas coinciden.
3. **Estado simbólico:** hechos como `current-state`, `visual-person-found` y
   `focus-active` permiten coordinar metas posteriores.

El plan sólo se serializa cuando todas las metas fueron consumidas y se añadió
el cierre. Finalmente, `PlanExtractor` ordena los `ros-message` y publica una
representación estable para el resto del sistema ROS 2.
