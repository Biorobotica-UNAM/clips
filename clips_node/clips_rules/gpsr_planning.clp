;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  gpsr_planning.clp
;;
;;  Plan dinamico para GPSR basado en primitivas CD.
;;
;;  Arquitectura de tres capas:
;;    Capa 1 (salience 200-190) — Expansion de primitivas CD
;;    Capa 2 (salience 110-90)  — Resolucion de precondiciones
;;    Capa 3 (salience  10)     — Serializacion a ros-message
;;
;;  Flujo:
;;    cd-primitive → sub-task → action-step → ros-message
;;
;;  Orden determinista de sub-tasks:
;;    ID = (step_de_la_primitiva * 100) + offset_local
;;    Cada primitiva tiene un bloque de 100 IDs garantizado.
;;    El campo step lo asigna primitive_to_clips.py con
;;    enumerate(primitives, start=1), respetando el orden
;;    del parser. Asi la primitiva N siempre ejecuta antes
;;    que la N+1, sin importar el orden de la agenda CLIPS.
;;
;;  BioRobotics Laboratory, Facultad de Ingenieria, UNAM
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 1 — TEMPLATES LOCALES
;;
;; Los templates compartidos viven en gpsr_templates.clp:
;;   start, plan-control, ros-message, plan-note,
;;   search-result, pending-accompany
;; No se redefinen aqui.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

(deftemplate robot-state
  (slot room    (type SYMBOL) (default unknown))
  (slot holding (type SYMBOL) (default nothing))
)

(deftemplate object-state
  (slot name (type SYMBOL) (default unknown))
  (slot room (type SYMBOL) (default unknown))
)

;; status validos: pending, waiting
(deftemplate sub-task
  (slot id     (type INTEGER) (default 0))
  (slot type   (type SYMBOL)  (default unknown))
  (slot arg1   (type SYMBOL)  (default unknown))
  (slot arg2   (type SYMBOL)  (default unknown))
  (slot status (type SYMBOL)  (default pending))
)

(deftemplate action-step
  (slot step   (type INTEGER) (default 0))
  (slot action (type SYMBOL)  (default unknown))
  (slot arg    (type STRING)  (default ""))
)

;; Unico contador global — no existe task-counter.
(deftemplate step-counter
  (slot value (type INTEGER) (default 1))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 2 — INICIALIZACION  (salience 500)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule gpsr-initialize
  (declare (salience 500))
  ?s <- (start (name action-planning))
  (cd-primitive)
  =>
  (retract ?s)
  (assert (step-counter (value 1)))
  (assert (plan-note (robot Justina) (state GPSR_START)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 3 — CAPA 1: EXPANSION DE PRIMITIVAS CD
;;
;; ID de sub-task = step * 100 + offset
;; No hay task-counter. Orden garantizado por ?step.
;; salience 200 casos especificos, 190 fallbacks.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule expand-atrans
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ATRANS)
                       (step ?step)
                       (object ?obj)
                       (from ?from)
                       (to ?to))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)          (type navigate-to) (arg1 ?from)))
  (assert (sub-task (id (+ ?base 1))   (type acquire)     (arg1 ?obj) (arg2 ?from)))
  (assert (sub-task (id (+ ?base 2))   (type navigate-to) (arg1 ?to)))
  (assert (sub-task (id (+ ?base 3))   (type deliver)     (arg1 ?obj) (arg2 ?to)))
)

(defrule expand-ptrans
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive PTRANS) (step ?step) (to ?dest))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type navigate-to) (arg1 ?dest)))
)

(defrule expand-attend-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ATTEND)
                       (step ?step)
                       (object ?obj)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type attend-at)   (arg1 ?obj) (arg2 ?loc)))
)

(defrule expand-attend-without-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ATTEND)
                       (step ?step)
                       (object ?obj)
                       (location unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type attend-at) (arg1 ?obj) (arg2 unknown)))
)

(defrule expand-grasp
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive GRASP) (step ?step) (object ?obj))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type acquire) (arg1 ?obj) (arg2 unknown)))
)

;; ── ACCOMPANY ────────────────────────────────────────────

(defrule expand-accompany-explicit-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ACCOMPANY)
                       (step ?step)
                       (object ?person)
                       (to ?dest)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to)  (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type accompany-to) (arg1 ?person) (arg2 ?dest)))
)

(defrule expand-accompany-known-in-world-state
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ACCOMPANY)
                       (step ?step)
                       (object ?person)
                       (to ?dest)
                       (location unknown))
  (object-state (name ?person) (room ?person-room&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to)  (arg1 ?person-room)))
  (assert (sub-task (id (+ ?base 1)) (type accompany-to) (arg1 ?person) (arg2 ?dest)))
)

(defrule expand-accompany-unknown-location
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive ACCOMPANY)
                       (step ?step)
                       (object ?person)
                       (to ?dest&~unknown)
                       (location unknown))
  (not (object-state (name ?person)))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type attend-at)    (arg1 ?person) (arg2 unknown)))
  (assert (sub-task (id (+ ?base 1)) (type accompany-to) (arg1 ?person) (arg2 ?dest)))
)

(defrule expand-accompany-no-destination
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive ACCOMPANY)
                       (step ?step)
                       (object ?person)
                       (to unknown)
                       (location unknown))
  (not (object-state (name ?person)))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type attend-at)    (arg1 ?person) (arg2 unknown)))
  (assert (sub-task (id (+ ?base 1)) (type accompany-to) (arg1 ?person) (arg2 unknown)))
)

;; ── MTRANS ───────────────────────────────────────────────

(defrule expand-mtrans-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive MTRANS)
                       (step ?step)
                       (content ?content&~unknown)
                       (to ?to&~unknown)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type attend-at)   (arg1 ?to) (arg2 ?loc)))
  (assert (sub-task (id (+ ?base 2)) (type communicate) (arg1 ?content)))
)

(defrule expand-mtrans-recipient-known
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive MTRANS)
                       (step ?step)
                       (content ?content&~unknown)
                       (to ?to&~unknown)
                       (location unknown))
  (object-state (name ?to) (room ?to-room&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type attend-at)   (arg1 ?to) (arg2 ?to-room)))
  (assert (sub-task (id (+ ?base 1)) (type communicate) (arg1 ?content)))
)

(defrule expand-mtrans-recipient-unknown
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive MTRANS)
                       (step ?step)
                       (content ?content&~unknown)
                       (to ?to&~unknown)
                       (location unknown))
  (not (object-state (name ?to)))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type attend-at)   (arg1 ?to) (arg2 unknown)))
  (assert (sub-task (id (+ ?base 1)) (type communicate) (arg1 ?content)))
)

;; ── SPEAK ────────────────────────────────────────────────

(defrule expand-speak
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive SPEAK) (step ?step) (content ?content))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type communicate) (arg1 ?content)))
)

;; ── SOCIAL ───────────────────────────────────────────────

(defrule expand-social-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive SOCIAL)
                       (step ?step)
                       (object ?person)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type interact)    (arg1 ?person)))
)

(defrule expand-social-known-in-world-state
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive SOCIAL)
                       (step ?step)
                       (object ?person)
                       (location unknown))
  (object-state (name ?person) (room ?person-room&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?person-room)))
  (assert (sub-task (id (+ ?base 1)) (type interact)    (arg1 ?person)))
)

;; No se genera attend-at: resolve-interact ya emite find.
(defrule expand-social-unknown-location
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive SOCIAL)
                       (step ?step)
                       (object ?person)
                       (location unknown))
  (not (object-state (name ?person)))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type interact) (arg1 ?person)))
)

;; ── WAIT ─────────────────────────────────────────────────

(defrule expand-wait
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive WAIT) (step ?step) (object ?condition))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type wait-for) (arg1 ?condition)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 4 — CAPA 2: RESOLUCION DE PRECONDICIONES
;;
;; salience 110 casos especiales, 105 restores,
;; 100 casos normales, 90 fallbacks.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule resolve-navigate-to-user-needed
  (declare (salience 110))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 user) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (object-state (name user) (room ?user-room))
  ?rs <- (robot-state (room ?current))
  (test (neq ?current ?user-room))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc) (retract ?rs)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action goto) (arg (str-cat ?user-room))))
  (assert (robot-state (room ?user-room) (holding nothing)))
)

(defrule resolve-navigate-to-user-already-there
  (declare (salience 110))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 user) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (object-state (name user) (room ?user-room))
  (robot-state (room ?user-room))
  =>
  (retract ?st)
)

(defrule resolve-navigate-to-needed
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to)
                   (arg1 ?dest&~user&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?current) (holding ?held))
  (test (neq ?current ?dest))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc) (retract ?rs)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action goto) (arg (str-cat ?dest))))
  (assert (robot-state (room ?dest) (holding ?held)))
)

(defrule resolve-navigate-to-unknown-dest
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action say) (arg "I do not know where to go")))
)

(defrule resolve-navigate-to-already-there
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to)
                   (arg1 ?dest&~user&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?dest))
  =>
  (retract ?st)
)

(defrule resolve-acquire-in-same-room
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?robot-room) (holding ?held))
  (object-state (name ?obj) (room ?robot-room))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc) (retract ?rs)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)         (action find) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?step 1))  (action take) (arg (str-cat ?obj))))
  (assert (robot-state (room ?robot-room) (holding ?obj)))
)

(defrule resolve-acquire-navigate-first
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?robot-room))
  (object-state (name ?obj) (room ?obj-room&~?robot-room))
  =>
  (modify ?st (status waiting))
  (assert (sub-task (id (- ?id 1)) (type navigate-to) (arg1 ?obj-room)))
)

(defrule resolve-acquire-restore-waiting
  (declare (salience 105))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status waiting))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?robot-room))
  (object-state (name ?obj) (room ?robot-room))
  =>
  (modify ?st (status pending))
)

(defrule resolve-acquire-unknown-location
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (not (object-state (name ?obj)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)        (action find) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?step 1)) (action take) (arg (str-cat ?obj))))
)

(defrule resolve-deliver
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type deliver)
                   (arg1 ?obj) (arg2 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action give) (arg (str-cat ?obj " " ?dest))))
)

(defrule resolve-attend-already-there
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 ?loc&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?loc))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action find) (arg (str-cat ?obj))))
)

(defrule resolve-attend-navigate-first
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 ?loc&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?robot-room))
  (test (neq ?robot-room ?loc))
  =>
  (modify ?st (status waiting))
  (assert (sub-task (id (- ?id 1)) (type navigate-to) (arg1 ?loc)))
)

(defrule resolve-attend-restore-waiting
  (declare (salience 105))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 ?loc&~unknown) (status waiting))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?loc))
  =>
  (modify ?st (status pending))
)

(defrule resolve-attend-unknown-location
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action find) (arg (str-cat ?obj))))
)

(defrule resolve-accompany-to
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type accompany-to)
                   (arg1 ?person) (arg2 ?dest&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?current) (holding ?held))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc) (retract ?rs)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action follow) (arg (str-cat ?person " " ?dest))))
  (assert (robot-state (room ?dest) (holding ?held)))
)

(defrule resolve-accompany-to-unknown-dest
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type accompany-to)
                   (arg1 ?person) (arg2 unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action follow) (arg (str-cat ?person))))
)

(defrule resolve-communicate
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type communicate)
                   (arg1 ?content) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action say) (arg (str-cat ?content))))
)

(defrule resolve-interact
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type interact) (arg1 ?person) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 2))))
  (assert (action-step (step ?step)        (action find) (arg (str-cat ?person))))
  (assert (action-step (step (+ ?step 1)) (action say)  (arg "greet")))
)

(defrule resolve-wait-for
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type wait-for) (arg1 ?condition) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action listen) (arg (str-cat ?condition))))
)

(defrule resolve-report-not-found
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type report-not-found) (arg1 ?target) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (step-counter (value ?step))
  =>
  (retract ?st) (retract ?sc)
  (assert (step-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action say)
                       (arg (str-cat "I could not find " ?target))))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 5 — RECOVERY POR FEEDBACK DEL EXECUTOR
;; salience 150
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule handle-search-not-found
  (declare (salience 150))
  ?sr <- (search-result (target ?target) (status not-found))
  =>
  (retract ?sr)
  (assert (sub-task (id 0) (type report-not-found) (arg1 ?target)))
)

(defrule handle-search-found-update-world
  (declare (salience 150))
  ?sr <- (search-result (target ?target) (room ?room&~unknown) (status found))
  ?os <- (object-state (name ?target))
  =>
  (retract ?sr)
  (modify ?os (room ?room))
)

(defrule handle-search-found-new-entry
  (declare (salience 150))
  ?sr <- (search-result (target ?target) (room ?room&~unknown) (status found))
  (not (object-state (name ?target)))
  =>
  (retract ?sr)
  (assert (object-state (name ?target) (room ?room)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 6 — SERIALIZACION  (salience 10)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule serialize-action-step
  (declare (salience 10))
  ?as <- (action-step (step ?step) (action ?action) (arg ?arg))
  (not (sub-task (status pending)))
  (not (sub-task (status waiting)))
  =>
  (retract ?as)
  (assert (ros-message
    (step ?step)
    (robot Justina)
    (action ?action)
    (params ?arg)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 7 — FINALIZACION  (salience 5)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule gpsr-finish
  (declare (salience 5))
  (not (cd-primitive))
  (not (sub-task (status pending)))
  (not (sub-task (status waiting)))
  (not (action-step))
  (not (plan-note (state GPSR_DONE)))
  =>
  (assert (plan-note (robot Justina) (state GPSR_DONE)))
)
