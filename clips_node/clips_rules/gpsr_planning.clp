;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  gpsr_planning.clp
;;
;;  Plan dinamico para GPSR basado en primitivas CD.
;;
;;  Arquitectura de tres capas:
;;    Capa 1 (salience 200) — Expansion de primitivas CD
;;    Capa 2 (salience 100) — Resolucion de precondiciones
;;    Capa 3 (salience  10) — Serializacion a ros-message
;;
;;  Flujo:
;;    cd-primitive → sub-task → action-step → ros-message
;;
;;  BioRobotics Laboratory, Facultad de Ingenieria, UNAM
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 1 — TEMPLATES
;;
;; Cada template define la estructura de un tipo de hecho.
;; Se separan por responsabilidad:
;;   - Estado del mundo (robot, objetos)
;;   - Pipeline de planificacion (cd-primitive, sub-task,
;;     action-step, ros-message)
;;   - Control de ejecucion (step-counter, task-counter)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ── Entrada del pipeline ─────────────────────────────────
;; Hecho insertado por primitive_to_clips.
;; Representa una primitiva CD del semantic_parser.

(deftemplate cd-primitive
  (slot step      (type INTEGER) (default 0))
  (slot primitive (type SYMBOL)  (default unknown))
  (slot actor     (type SYMBOL)  (default robot))
  (slot object    (type SYMBOL)  (default unknown))
  (slot from      (type SYMBOL)  (default unknown))
  (slot to        (type SYMBOL)  (default unknown))
  (slot location  (type SYMBOL)  (default unknown))
  (slot content   (type SYMBOL)  (default unknown))
)

;; ── Estado del mundo ─────────────────────────────────────
;; Hechos insertados por WorldStateLoader desde world_state.yaml.
;; CLIPS los usa para verificar precondiciones.

(deftemplate robot-state
  (slot room    (type SYMBOL) (default unknown))
  (slot holding (type SYMBOL) (default nothing))
)

(deftemplate object-state
  (slot name (type SYMBOL) (default unknown))
  (slot room (type SYMBOL) (default unknown))
)

;; ── Sub-tareas intermedias ────────────────────────────────
;; Generadas por la Capa 1 al expandir cd-primitives.
;; Representan intenciones de alto nivel antes de verificar
;; precondiciones.
;;
;; Tipos de sub-task:
;;   navigate-to   mover el robot a una ubicacion
;;   acquire       conseguir un objeto (find + take)
;;   deliver       entregar un objeto a alguien
;;   attend-at     buscar algo en una ubicacion
;;   accompany-to  escoltar a alguien a un lugar
;;   communicate   decir algo
;;   interact      interaccion social
;;   wait-for      esperar una condicion

(deftemplate sub-task
  (slot id     (type INTEGER) (default 0))
  (slot type   (type SYMBOL)  (default unknown))
  (slot arg1   (type SYMBOL)  (default unknown))
  (slot arg2   (type SYMBOL)  (default unknown))
  (slot status (type SYMBOL)  (default pending))
)

;; ── Pasos concretos del plan ──────────────────────────────
;; Generados por la Capa 2 al resolver precondiciones.
;; Cada action-step corresponde a una accion del executor.
;;
;; Acciones validas del executor:
;;   goto, find, take, give, say, follow,
;;   listen, check, save, memorize_face, point

(deftemplate action-step
  (slot step   (type INTEGER) (default 0))
  (slot action (type SYMBOL)  (default unknown))
  (slot arg    (type STRING)  (default ""))
)

;; ── Control de ejecucion ──────────────────────────────────

;; Contador global de pasos del plan.
;; Se incrementa cada vez que se genera un action-step.
(deftemplate step-counter
  (slot value (type INTEGER) (default 1))
)

;; ID global de sub-tareas.
;; Se incrementa por cada sub-task generada.
(deftemplate task-counter
  (slot value (type INTEGER) (default 1))
)

;; Marcador de inicio — insertado por clips_node.py.
(deftemplate start
  (slot task-name (type SYMBOL) (default nil))
)

;; Plantillas heredadas de gpsr_templates.clp:
;;   plan-control, ros-message, plan-note
;; No se redefinen aqui para evitar conflictos.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 2 — INICIALIZACION
;;
;; Se activa cuando llega (start (task-name action-planning))
;; y existe al menos una cd-primitive en la base de hechos.
;; salience 500 — se ejecuta antes que todo lo demas.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule gpsr-initialize
  (declare (salience 500))
  ?s <- (start (task-name action-planning))
  (cd-primitive)
  =>
  (retract ?s)
  (assert (step-counter (value 1)))
  (assert (task-counter (value 1)))
  (assert (plan-note (robot Justina) (state GPSR_START)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 3 — CAPA 1: EXPANSION DE PRIMITIVAS CD
;;
;; Cada regla toma una cd-primitive y genera sub-tasks.
;; salience 200 — se ejecutan antes que las capas 2 y 3.
;;
;; Principio: una regla por primitiva CD.
;; La regla NO verifica el estado del mundo — solo expande
;; la intencion en sub-tareas de alto nivel.
;;
;; El task-counter asigna IDs unicos y ordenados a cada
;; sub-task para garantizar el orden de ejecucion.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ── ATRANS ───────────────────────────────────────────────
;; Transferir un objeto de un lugar a otro o a alguien.
;; Ejemplo: "Bring me an apple from the kitchen"
;;
;; Expansion:
;;   navigate-to  origen
;;   acquire      objeto  origen
;;   navigate-to  destino
;;   deliver      objeto  destino

(defrule expand-atrans
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ATRANS)
                       (object ?obj)
                       (from ?from)
                       (to ?to))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 4))))
  (assert (sub-task (id ?tid)
                    (type navigate-to)
                    (arg1 ?from)))
  (assert (sub-task (id (+ ?tid 1))
                    (type acquire)
                    (arg1 ?obj)
                    (arg2 ?from)))
  (assert (sub-task (id (+ ?tid 2))
                    (type navigate-to)
                    (arg1 ?to)))
  (assert (sub-task (id (+ ?tid 3))
                    (type deliver)
                    (arg1 ?obj)
                    (arg2 ?to)))
)

;; ── PTRANS ───────────────────────────────────────────────
;; Mover el robot a una ubicacion.
;; Ejemplo: "Go to the kitchen"
;;
;; Expansion:
;;   navigate-to  destino

(defrule expand-ptrans
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive PTRANS) (to ?dest))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type navigate-to)
                    (arg1 ?dest)))
)

;; ── ATTEND con ubicacion conocida ────────────────────────
;; Buscar un objeto en una ubicacion especifica.
;; Ejemplo: "Find a snack in the kitchen"
;;
;; Expansion:
;;   navigate-to  ubicacion
;;   attend-at    objeto  ubicacion

(defrule expand-attend-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ATTEND)
                       (object ?obj)
                       (location ?loc&~unknown))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 2))))
  (assert (sub-task (id ?tid)
                    (type navigate-to)
                    (arg1 ?loc)))
  (assert (sub-task (id (+ ?tid 1))
                    (type attend-at)
                    (arg1 ?obj)
                    (arg2 ?loc)))
)

;; ── ATTEND sin ubicacion ─────────────────────────────────
;; Buscar un objeto sin saber donde esta.
;; Expansion:
;;   attend-at  objeto  unknown

(defrule expand-attend-without-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ATTEND)
                       (object ?obj)
                       (location unknown))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type attend-at)
                    (arg1 ?obj)
                    (arg2 unknown)))
)

;; ── GRASP ────────────────────────────────────────────────
;; Tomar fisicamente un objeto.
;; Ejemplo: "Grasp the cup"
;;
;; Expansion:
;;   acquire  objeto

(defrule expand-grasp
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive GRASP) (object ?obj))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type acquire)
                    (arg1 ?obj)
                    (arg2 unknown)))
)

;; ── ACCOMPANY ────────────────────────────────────────────
;; Escoltar a una persona a una ubicacion.
;; Ejemplo: "Escort the person to the living room"
;;
;; Expansion:
;;   attend-at    persona  unknown
;;   accompany-to persona  destino

(defrule expand-accompany
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ACCOMPANY)
                       (object ?person)
                       (to ?dest))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type accompany-to)
                    (arg1 ?person)
                    (arg2 ?dest)))
)

;; ── MTRANS ───────────────────────────────────────────────
;; Comunicar informacion al usuario.
;; Ejemplo: "Tell me the pose of the person"
;;
;; Expansion:
;;   communicate  contenido

(defrule expand-mtrans
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive MTRANS) (content ?content))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type communicate)
                    (arg1 ?content)))
)

;; ── SPEAK ────────────────────────────────────────────────
;; Decir algo sin destinatario especifico.
;; Ejemplo: "Say hello"
;;
;; Expansion:
;;   communicate  contenido

(defrule expand-speak
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive SPEAK) (content ?content))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type communicate)
                    (arg1 ?content)))
)

;; ── SOCIAL ───────────────────────────────────────────────
;; Interaccion social con una persona en una ubicacion.
;; Ejemplo: "Meet Angel at the shelf"
;;
;; Expansion:
;;   navigate-to  ubicacion
;;   interact     persona

(defrule expand-social
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive SOCIAL)
                       (object ?person)
                       (location ?loc))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 2))))
  (assert (sub-task (id ?tid)
                    (type navigate-to)
                    (arg1 ?loc)))
  (assert (sub-task (id (+ ?tid 1))
                    (type interact)
                    (arg1 ?person)))
)

;; ── WAIT ─────────────────────────────────────────────────
;; Esperar hasta que se cumpla una condicion.
;;
;; Expansion:
;;   wait-for  condicion

(defrule expand-wait
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive WAIT) (object ?condition))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?cd)
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id ?tid)
                    (type wait-for)
                    (arg1 ?condition)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 4 — CAPA 2: RESOLUCION DE PRECONDICIONES
;;
;; Cada regla procesa la sub-task con el ID mas bajo
;; (la mas prioritaria), verifica el estado del mundo,
;; y genera action-steps concretos.
;;
;; salience 100 — se ejecutan despues de la expansion.
;;
;; Patron de prioridad:
;;   (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
;; Garantiza que siempre procesamos el paso correcto.
;;
;; Cuando una precondicion no se cumple, se inserta una
;; nueva sub-task con ID menor para ejecutarla antes.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ── navigate-to: robot necesita moverse ──────────────────
;; Precondicion no cumplida: robot NO esta en el destino.
;; Accion: goto destino.
;; Efecto en el mundo: robot ahora esta en destino.

(defrule resolve-navigate-to-needed
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to)
                   (arg1 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?current))
  (test (neq ?current ?dest))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (retract ?rs)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step)
                       (action goto)
                       (arg (str-cat ?dest))))
  (assert (robot-state (room ?dest) (holding nothing)))
)

;; ── navigate-to: robot ya esta ahi ───────────────────────
;; Precondicion cumplida: robot YA esta en el destino.
;; No generar ninguna accion — omitir este paso.

(defrule resolve-navigate-to-already-there
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to)
                   (arg1 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?current))
  (test (eq ?current ?dest))
  =>
  (retract ?st)
)

;; ── acquire: robot en la misma habitacion que el objeto ──
;; Precondicion cumplida: robot y objeto en mismo cuarto.
;; Acciones: find objeto + take objeto.
;; Efecto en el mundo: robot tiene el objeto en mano.

(defrule resolve-acquire-in-same-room
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type acquire)
                   (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?robot-room) (holding ?held))
  (object-state (name ?obj) (room ?obj-room))
  (test (eq ?robot-room ?obj-room))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (retract ?rs)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)
                       (action find)
                       (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?step 1))
                       (action take)
                       (arg (str-cat ?obj))))
  (assert (robot-state (room ?robot-room) (holding ?obj)))
)

;; ── acquire: robot en habitacion diferente ────────────────
;; Precondicion no cumplida: robot NO esta donde esta el objeto.
;; Insertar navigate-to con ID menor para ejecutarlo primero.

(defrule resolve-acquire-navigate-first
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type acquire)
                   (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?robot-room))
  (object-state (name ?obj) (room ?obj-room))
  (test (neq ?robot-room ?obj-room))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id (- ?id 1))
                    (type navigate-to)
                    (arg1 ?obj-room)))
)

;; ── acquire: ubicacion del objeto desconocida ─────────────
;; El objeto no esta en el world_state — buscar directamente.

(defrule resolve-acquire-unknown-location
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type acquire)
                   (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (not (object-state (name ?obj)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)
                       (action find)
                       (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?step 1))
                       (action take)
                       (arg (str-cat ?obj))))
)

;; ── deliver ──────────────────────────────────────────────
;; Entregar un objeto al destinatario.
;; Accion directa: give objeto destino.

(defrule resolve-deliver
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type deliver)
                   (arg1 ?obj) (arg2 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step)
                       (action give)
                       (arg (str-cat ?obj " " ?dest))))
)

;; ── attend-at: robot ya en la ubicacion ──────────────────
;; Precondicion cumplida: robot en la ubicacion correcta.
;; Accion: find objeto.

(defrule resolve-attend-already-there
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 ?loc&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?robot-room))
  (test (eq ?robot-room ?loc))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step)
                       (action find)
                       (arg (str-cat ?obj))))
)

;; ── attend-at: robot necesita navegar primero ────────────
;; Precondicion no cumplida: robot NO esta en la ubicacion.
;; Insertar navigate-to antes.

(defrule resolve-attend-navigate-first
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 ?loc&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?robot-room))
  (test (neq ?robot-room ?loc))
  ?tc <- (task-counter (value ?tid))
  =>
  (retract ?tc)
  (assert (task-counter (value (+ ?tid 1))))
  (assert (sub-task (id (- ?id 1))
                    (type navigate-to)
                    (arg1 ?loc)))
)

;; ── attend-at: ubicacion desconocida ─────────────────────
;; No se sabe donde buscar — buscar directamente.

(defrule resolve-attend-unknown-location
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step)
                       (action find)
                       (arg (str-cat ?obj))))
)

;; ── accompany-to ─────────────────────────────────────────
;; Escoltar a alguien al destino.
;; Acciones: follow persona + goto destino.
;; Efecto: robot ahora en destino.

(defrule resolve-accompany-to
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type accompany-to)
                   (arg1 ?person) (arg2 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?current) (holding ?held))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (retract ?rs)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)
                       (action follow)
                       (arg (str-cat ?person))))
  (assert (action-step (step (+ ?step 1))
                       (action goto)
                       (arg (str-cat ?dest))))
  (assert (robot-state (room ?dest) (holding ?held)))
)

;; ── communicate ──────────────────────────────────────────
;; Decir algo al usuario.
;; Accion directa: say contenido.

(defrule resolve-communicate
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type communicate)
                   (arg1 ?content) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step)
                       (action say)
                       (arg (str-cat ?content))))
)

;; ── interact ─────────────────────────────────────────────
;; Interaccion social: encontrar y saludar a alguien.
;; Acciones: find persona + say greet.

(defrule resolve-interact
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type interact)
                   (arg1 ?person) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)
                       (action find)
                       (arg (str-cat ?person))))
  (assert (action-step (step (+ ?step 1))
                       (action say)
                       (arg "greet")))
)

;; ── wait-for ─────────────────────────────────────────────
;; Esperar una condicion.
;; Accion: listen condicion.

(defrule resolve-wait-for
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type wait-for)
                   (arg1 ?condition) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st)
  (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step)
                       (action listen)
                       (arg (str-cat ?condition))))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 5 — CAPA 3: SERIALIZACION A ROS-MESSAGE
;;
;; Convierte cada action-step en un ros-message con el
;; formato que espera el supervisor.
;;
;; salience 10 — se ejecuta al final, cuando ya no hay
;; sub-tasks pendientes ni action-steps por resolver.
;;
;; Formato de salida:
;;   ros-message con slots step, robot, action, params.
;;   El supervisor lee params como "accion argumento".
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule serialize-action-step
  (declare (salience 10))
  ?as <- (action-step (step ?step) (action ?action) (arg ?arg))
  (not (sub-task (status pending)))
  =>
  (retract ?as)
  (assert (ros-message
    (step ?step)
    (robot Justina)
    (action ?action)
    (params ?arg)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 6 — FINALIZACION
;;
;; Se activa cuando el plan esta completo:
;;   - No quedan cd-primitives sin expandir
;;   - No quedan sub-tasks pendientes
;;   - No quedan action-steps sin serializar
;;
;; Genera un plan-note de fin para que clips_node.py
;; sepa que puede publicar el plan.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule gpsr-finish
  (declare (salience 5))
  (not (cd-primitive))
  (not (sub-task (status pending)))
  (not (action-step))
  (not (plan-note (state GPSR_DONE)))
  =>
  (assert (plan-note (robot Justina) (state GPSR_DONE)))
)
