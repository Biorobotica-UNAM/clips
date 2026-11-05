# Guía de `goals_planning.clp`

Revisión: **4 de noviembre de 2026**, contrastada con el archivo
[`goals_planning.clp`](../clips_node/clips_rules/goals_planning.clp), el adaptador
ROS y `PlanExtractor`. Describe la implementación local actual, no las copias
congeladas de campañas anteriores.

## Alcance y recorrido

El planificador expande metas en el orden de entrada mediante macros de reglas.
No realiza búsqueda general de planes ni verifica el éxito físico de acciones.

```text
JSON → GoalParser → ClipsGoalFactBuilder → gpsr-goal
    → process-* → action-step
    → add-final-return → organize-interaction-focus
    → finalized-step → serialize-action-step → ros-message
    → goals-finish → PlanExtractor → publicación del plan
```

El nodo `clips_node` gestiona el motor. `goals_to_clips_node` solicita primero
`assert_facts_batch` y después `start_planning`; el primer trabajo hace `reset`
y el segundo inserta `(start (name action-planning))`. Los servicios responden
al encolar, antes de completar las reglas. El topic de resultados es una etapa
separada y no contiene identificador de solicitud.

## Contrato de entrada y adaptación

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

| Campo | Interpretación |
|---|---|
| `step` | Posición de la meta en el JSON, desde 1 |
| `name` | Acción abstracta, normalizada a minúsculas |
| `target` | Primer argumento posicional; los espacios se sustituyen por `_` |
| `kind` | Símbolo `person`, `object`, `location`, `info` o `unknown`, inferido por el adaptador |
| `destination` | Primer atributo presente entre `to`, `at`, `on`, `in`; en acciones de destino también se admite segundo argumento posicional |
| `relation`, `value` | Primer atributo presente entre `to`, `at`, `on`, `in`, `gesture`, `pose`, `wearing`, `property`; para destinos posicionales de deliver/guide/follow se usa `to` |
| `qualifier` | Primer atributo presente entre `gesture`, `pose`, `wearing`, `property`, como `clave:valor` |

El adaptador acepta un arreglo JSON o un objeto con `goals`. Los strings se
escapan al generar hechos. Un objeto sin `goals` se interpreta como lista vacía;
el nodo rechaza esa lista. No es el validador canónico usado para entrenar Qwen:
convierte cada elemento a string antes de analizarlo y no rechaza por sí mismo
una acción desconocida si tiene sintaxis `accion(...)`.

`GoalParser` infiere personas por acciones, atributos, destinatarios y nombres
capitalizados; no utiliza el atributo explícito `kind` para decidir su campo
inferido. Por ejemplo, la capitalización puede convertir un objeto en persona.
Las reglas añaden después su propio contexto y una lista limitada de nombres
conocidos. La lista de `known-person-name` no es el catálogo YAML del extractor.

El patrón defectuoso `go(person, gesture=waving)` seguido de
`follow(person, to=kitchen)` se repara como `go(kitchen)`,
`find(person, gesture=waving)`, `follow(person)`. Es una transformación del
adaptador que debe distinguirse de la salida original del modelo.

## Hechos de estado y control

| Hecho | Responsabilidad |
|---|---|
| `planning-ready`, `start` | Inicio y habilitación de reglas |
| `current-state(location, holding)` | Estado simbólico planeado; inicia en `unknown` y `nothing` |
| `manipulation-mode`, `manipulation-unavailable` | Configuración por ciclo y objetos cuya adquisición quedó indisponible |
| `visual-person-found` | Relación entre target y fuente perceptual |
| `last-person-context` | Persona e índices recordados para memoria e interacción |
| `visual-analysis`, `saved-info` | Resultado simbólico de consultas y datos solicitados |
| `interaction-context` | Identidad de interlocutor para anotar diálogo |
| `action-step` | Paso preliminar; incluye `interlocutor` interno |
| `finalized-step` | Paso definitivo con foco organizado y numeración final |
| `final-steps-added`, `focus-normalized` | Barreras del cierre y la normalización |
| `ros-message`, `plan-note` | Acciones publicables y notas START/DONE |

Los contadores de anuncios arrancan en 1; los operativos en 1001; los índices de
personas en 1. `reset` elimina los hechos dinámicos y restablece el estado definido
por las reglas. Las operaciones de percepción descritas en el plan no prueban
que una persona haya sido localizada o un objeto adquirido en el mundo real.

## Orden y prioridades

Cada regla de tarea exige que no exista otro `gpsr-goal` con paso menor.
La prioridad selecciona la variante aplicable a la meta actual, sin reordenar
las metas.

| Salience | Regla o grupo |
|---:|---|
| 500 | `goals-initialize` |
| 200 | `process-go` |
| 197 | `process-find-known-named-person` |
| 196 | `process-place-drop-unavailable` |
| 195 | `process-find-named-person`, `process-manipulation-dependent-unavailable` |
| 193 | `process-find-context-person` |
| 190 | `process-find-person`, `process-deliver-to-user` |
| 185 | `process-deliver-to-person` |
| 181 | `process-take-enabled`, `process-place-drop-not-carrying` |
| 180 | Resto de reglas específicas de tarea |
| 20 | `add-final-return` |
| 10 | `process-unsupported-goal` |
| 7 | `organize-interaction-focus` |
| 5 | `serialize-action-step` |
| 1 | `goals-finish` |

## Expansión de las metas

### Navegación

`process-go` emite `go_to` y confirmación de llegada solo si el destino difiere
de `current-state.location`. Actualiza la ubicación simbólica y conserva
`holding`. Los anuncios se crean por separado antes de las operaciones.

### Búsqueda

| Variante | Resultado |
|---|---|
| `process-find-known-named-person` | Reutiliza la fuente de una persona nombrada localizada en este plan y reconoce su nombre guardado |
| `process-find-named-person` | `find_person anybody`, pregunta `ask_name`, escucha `guest_name_last` y confirmación `acknowledge_name_last` |
| `process-find-context-person` | Trata como persona un target exigido por el contexto aunque `kind` inferido fuera distinto |
| `process-find-person` | Búsqueda genérica, o `find_pose` y `approach customer_N` para atributos visuales reconocidos |
| `process-find-object` | `find_object objeto_1`, con posible `align table` y análisis visual previo |

`find` no activa foco por el solo hecho de buscar: este se inserta después para
el diálogo dirigido. La secuencia de preguntar y guardar un nombre no demuestra
una comparación que descarte a toda persona diferente del nombre solicitado.
`guest_last` y `guest_name_last` se resuelven durante ejecución; no son identidades
físicas certificadas durante planificación.

Para personas, `find-pose-query` y `analyze-person-query` convierten el único
calificador disponible a argumentos del executor, por ejemplo
`gesture='waving person'` se convierte en `waving_1`. No se conservan como filtros
simultáneos todos los atributos que pudiera haber escrito el modelo.

### Adquisición, colocación y entrega

| Regla | Efecto principal |
|---|---|
| `process-take-enabled` | Genera `take objeto_1` y actualiza `holding` |
| `process-take-disabled` | Explica indisponibilidad, registra el objeto y deja `holding=nothing` |
| `process-place-drop-unavailable` | Explica por qué no puede colocar; puede navegar al destino nombrado |
| `process-manipulation-dependent-unavailable` | Explica dependencia de una adquisición indisponible |
| `process-place-drop-not-carrying` | Impide colocar/soltar un objeto distinto del almacenado en `holding` |
| `process-place`, `process-drop` | Navegación cuando procede, búsqueda de superficie y `drop objeto_1`; liberan `holding` |
| `process-deliver-to-user` | Regreso a `instruction_point`, `approach host_1`, `give objeto_1` |
| `process-deliver-to-person` | Reutiliza o localiza destinatario, aproxima y entrega; conserva ubicación y libera `holding` |

La manipulación está habilitada mediante `?*MANIPULATION_ENABLED*=TRUE`.
`manipulation-mode` permite una configuración para el ciclo; debe insertarse
después del reset y antes del inicio. El modo deshabilitado sustituye las
acciones dependientes por explicaciones, sin demostrar que se satisfizo la tarea.
`deliver` no verifica por sí solo la adquisición previa como lo hace `place`;
la coherencia de `take` antes de entregar debe comprobarse en la secuencia.

`placement-needs-navigation` distingue superficies genéricas del lugar actual
(`table`, `shelf`, `container`, etc.) y destinos nombrados (`dining_table`,
`storage_rack`, etc.). Solo navega si el destino lo requiere y difiere del actual.
`drop-surface` aplica coincidencias por subcadena en este orden:

1. `floor` o `suelo` → `floor`.
2. `shelf_3`, `shelf_2`, `shelf_1` → esa repisa concreta.
3. `shelf`, `rack`, `cabinet`, `bookcase`, `estante`, `repisa` → `shelf`.
4. Variantes de contenedor alto, `encima` o `sobre_mesa` → `container_top`.
5. Contenedores, cajas o basura → `container_down`.
6. Cualquier otro valor → `table`.

`floor` omite `find_space`; los demás usan `find_space <superficie>` y
`drop <objeto_id>`. Por ejemplo, `storage_rack` requiere navegación y después
superficie `shelf`. El estado simbólico de colocación puede registrar la
superficie como ubicación aun cuando no haya habido navegación.

### Guía, seguimiento y saludo

`process-guide` selecciona la persona, le pide seguir al robot y genera
`go_to destino`; actualiza ubicación. La pasada final cierra el foco antes de
navegar y trata la confirmación posterior como anuncio general.

`process-follow` reutiliza una fuente conocida o busca una persona. Para una
fuente `customer_N` ya aproximada evita repetir ese acercamiento; para otras
fuentes agrega `approach`. Emite diálogo dirigido con
`instruct_follow_to_<destino>` o `instruct_follow_only`. No actualiza la ubicación
simbólica ni emite aquí una acción dedicada de seguimiento: esas claves activan
el protocolo del executor. No basta con una frase libre «I will follow».

`process-greet` reutiliza o busca a la persona, se aproxima, selecciona su
identidad y emite `say greet` como diálogo dirigido.

### Conteo, conversación y memoria

`process-count` genera `analyze_objects count_person` o `count_<target>`, vuelve
al punto de instrucción cuando corresponde y reporta `count_category` al
operador. **`count-query` ignora el calificador**: no acredita conteo filtrado por
ropa, pose ni gesto.

`process-tell` acepta `tell` y `talk`. Normaliza respuestas frecuentes como
`team_name`, `current_time`, `about_yourself` y días; reporta análisis visuales o
información guardada. `name` se convierte en `saved_name`. Puede reutilizar
`visual-analysis` o crear el análisis que falta. Una clave `say` puede activar
un protocolo y no debe eliminarse como si fuera texto prescindible.

`size-filter` transforma `heaviest` a extremo de tamaño grande y `lightest` o
`thinnest` a pequeño, entre otras variantes. Es una aproximación visual; no
implementa medición de peso o grosor ni justifica cumplimiento estricto.

`process-save` registra `saved-info` y produce operaciones según el dato:

- Nombre: encuentra una persona si falta contexto y genera pregunta, escucha y reconocimiento del nombre.
- Gesto: `analyze_person gesture_any` y `find_pose gesture_N`, conservando la fuente `customer_N`.
- Pose: `find_pose pose_N`, reutilizando contexto cuando procede.
- Otros datos: explicación de memoria, sin adquisición general garantizada.

`process-answer-question` agrega `listen answer_question` y `say answer_question`
como diálogo dirigido al contexto disponible.

## Cierre y foco sobre el plan completo

`add-final-return` se activa cuando no quedan metas: agrega el regreso a
`instruction_point` si la ubicación difiere y después `say task completed`.
La ubicación inicial `unknown` también produce regreso si ninguna meta la cambió.

Las funciones de construcción separan responsabilidades:

| Función | Responsabilidad |
|---|---|
| `append-say` | Anuncio general con paso bajo, desde 1 |
| `append-action` | Operación desde 1001; ignora inserciones directas de `focus` y actualiza contexto ante navegación o búsqueda/aproximación |
| `append-dialogue` | Operación `say`/`listen` con anotación de interlocutor |
| `append-focused-say` | Delega en `append-dialogue`; no inserta un ciclo de foco por sí misma |
| `set-interlocutor`, `current-interlocutor`, `select-person` | Identidad simbólica de la persona a la que se dirige el diálogo |

La regla `organize-interaction-focus` ejecuta `normalize-interactions` después
del cierre y antes de serializar. Ordena los pasos y crea `finalized-step`:

- Conserva los anuncios de pasos inferiores a 1001.
- Numera de nuevo las operaciones desde 1001.
- Abre foco para diálogo con interlocutor no vacío.
- Conserva el ciclo entre `say`/`listen` adyacentes dirigidos a la misma identidad, incluso entre metas diferentes.
- Cierra el ciclo ante cambio de persona, anuncio sin destinatario o acción no dialogada.
- Cierra cualquier ciclo restante y marca `focus-normalized`.

No hay un hecho `focus-active` en esta versión. El foco es una instrucción
planeada; no confirma atención real del robot. La anotación `interlocutor` no
forma parte de los parámetros publicados. `task completed` es un anuncio general
único al final de las operaciones y no activa foco ni pasa al preámbulo.

`serialize-action-step` consume `finalized-step`, no los pasos preliminares,
y crea `ros-message`. `goals-finish` exige ausencia de metas y de pasos de ambas
clases, `focus-normalized`, cierre agregado y ausencia previa de `GPSR_DONE`.
La regla añade la nota de fin de expansión.

## Fallback, publicación y límites

`process-unsupported-goal` consume una meta que ninguna regla específica acepta
y genera `say I do not know how to execute goal ...`. Después puede aparecer
`task completed`: las notas de fin no constituyen una calificación de la tarea.

`PlanExtractor` ordena `ros-message` por `step`, forma las líneas `Paso N`, coloca
START al principio y DONE al final. Retira los mensajes extraídos y conserva las
notas. `clips_node` publica cuando encuentra mensajes, sin un evaluador de
cumplimiento de subtareas. Los fallos del worker se registran en logs.

Las operaciones del motor están serializadas, pero el lote y el inicio son dos
trabajos separados, sin transacción ni correlación de solicitudes. No emitir
planes concurrentes con esta interfaz. El nodo no ofrece cancelación, deadlines
duros ni la instrumentación del ejecutor de campañas de Qwen2.5-7B.

El contrato de acciones debe contrastarse con el executor instalado: entre otras,
`go_to`, `find_person`, `find_pose`, `find_object`, `approach`, `align`, `take`,
`find_space`, `drop`, `give`, `analyze_objects`, `analyze_person`, `say`, `listen`
y `focus`. El plan no valida automáticamente todas sus precondiciones físicas.

## Ejemplos reproducidos con las fuentes actuales

Los siguientes planes se generaron con Clipspy, `GoalParser`,
`ClipsGoalFactBuilder` y `PlanExtractor` de este checkout, sin ROS ni consultas
Qwen. Son resultados del conversor y las reglas para objetivos fijados, no
predicciones de un modelo ni resultados físicos. Se comprobaron el consumo de
metas, START/DONE y un único cierre final. Clipspy emitió avisos de liberación
`ENVRNMNT8`; no se certifica ausencia de crecimiento de memoria.

### Navegar, adquirir y colocar

Entrada:

```json
{
  "goals": [
    "go(kitchen)",
    "find(apple, kind=object)",
    "take(apple)",
    "place(apple, on=table)"
  ]
}
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

### Persona por gesto y guía

Entrada:

```json
{
  "goals": [
    "go(living room)",
    "find(person, kind=person, gesture='waving person')",
    "guide(person, to=inspection point)"
  ]
}
```

Plan final:

```text
==Justina GPSR_START==
Paso 1: Justina say I will navigate to living_room
Paso 2: Justina say I will look for person waving_person
Paso 3: Justina say I will guide person to inspection_point
Paso 1001: Justina go_to living_room
Paso 1002: Justina say I have arrived at living_room
Paso 1003: Justina find_pose waving_1
Paso 1004: Justina approach customer_1
Paso 1005: Justina focus enable
Paso 1006: Justina say Please follow me to inspection_point
Paso 1007: Justina focus disable
Paso 1008: Justina go_to inspection_point
Paso 1009: Justina say I have guided person to inspection_point
Paso 1010: Justina go_to instruction_point
Paso 1011: Justina say task completed
==Justina GPSR_DONE==
```

### Persona nombrada y seguimiento

Entrada:

```json
{
  "goals": [
    "find(Laura, kind=person)",
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
Paso 1002: Justina focus enable
Paso 1003: Justina say ask_name
Paso 1004: Justina listen guest_name_last
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

### Respuesta conocida

Entrada:

```json
{
  "goals": [
    "tell(what is your team name)"
  ]
}
```

Plan final:

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

## Diagnóstico y extensión

Desde la raíz de Justina, iniciar el flujo descrito en el
[README de CLIPS](../README.md) y observar `/planning/clips/results`.
Si no hay plan, comprobar directorio de trabajo para cargar reglas, `plan_name`,
namespace, hechos insertados, logs del worker y topic del consumidor.
`plan_execution.log` se vacía al reiniciar el nodo; conservarlo aparte si se
necesita trazabilidad. La API ROS no sustituye el diario de una campaña.

Para una meta nueva: definir sintaxis y adaptación, conservar el orden de menor
`step`, retirar la meta procesada, actualizar el estado aplicable y crear pasos
mediante los helpers. Usar `append-dialogue` para hablar o escuchar a una persona
y dejar que la normalización inserte foco. No agregar `ros-message` directamente
para eludir esa etapa. Verificar acciones y argumentos contra el executor,
dependencias, modo sin manipulación y cierre; probar planes completos con
interacciones que atraviesen varias metas. Mantener separado éxito de expansión,
formato, cumplimiento semántico y éxito físico.
