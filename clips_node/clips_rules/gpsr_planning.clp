;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  gpsr_planning.clp  (briefing edition)
;;
;;  Arquitectura de numeración dual:
;;    say-counter  (1, 2, 3 ...)     → says de briefing al inicio
;;    act-counter  (1001, 1002 ...)  → acciones ejecutables
;;
;;  El serializer ordena por step, por lo que el plan siempre
;;  tiene la forma:
;;    1..N   → briefing completo ("I am going to X", "I will pick Y"...)
;;    1001.. → acciones reales   (goto, find, align, take, give...)
;;
;;  Para quitar el briefing: eliminar todos los action-step
;;  que usen ?say-step y borrar los assert de say-counter.
;;
;;  NOTA: Este archivo requiere que previamente se haya cargado
;;        gpsr_templates.clp (contiene start, search-result,
;;        plan-note, ros-message, plan-control).
;;
;;  BioRobotics Laboratory, Facultad de Ingenieria, UNAM
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 1 — TEMPLATES LOCALES
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

;; Contador para says de briefing (1, 2, 3...)
(deftemplate say-counter
  (slot value (type INTEGER) (default 1))
)

;; Contador para acciones reales (1001, 1002...)
(deftemplate act-counter
  (slot value (type INTEGER) (default 1001))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 2 — INICIALIZACION  (salience 500)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule gpsr-initialize
  (declare (salience 500))
  ?s <- (start (name action-planning))
  (not (plan-note (state GPSR_START)))
  (not (plan-note (state GPSR_DONE)))
  =>
  (retract ?s)
  (assert (say-counter (value 1)))
  (assert (act-counter (value 1001)))
  (assert (plan-note (robot ROBOT) (state GPSR_START)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 3 — CAPA 1: EXPANSION DE PRIMITIVAS CD
;;
;; Sin cambios — ID = step * 100 + offset garantiza orden.
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
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?from)))
  (assert (sub-task (id (+ ?base 1)) (type acquire)     (arg1 ?obj) (arg2 ?from)))
  (assert (sub-task (id (+ ?base 2)) (type navigate-to) (arg1 ?to)))
  (assert (sub-task (id (+ ?base 3)) (type deliver)     (arg1 ?obj) (arg2 ?to)))
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
;; Cada resolve-* usa DOS contadores:
;;   ?say-step  ← de say-counter  → briefing al inicio del plan
;;   ?act-step  ← de act-counter  → acción real más adelante
;;
;; Patrón por tipo:
;;
;;  navigate  : say("navigating to X")        | goto X
;;  acquire   : say("looking for X")          | find | align | take
;;  acquire?  : say("unknown loc, follow me") | find user | follow | listen | save | find | align | take
;;  deliver   : say("delivering X to Y")      | give X Y
;;  attend    : say("searching for X")        | find X
;;  accompany : say("escorting X to Y")       | find X | follow X Y
;;  interact  : say("greeting X")             | find X | focus X | say greet
;;  wait      : say("waiting for X")          | listen X
;;  communicate: say briefing                 | say content
;;
;; salience: 110 especiales, 105 restore, 100 normal, 90 fallback
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ── navigate-to ──────────────────────────────────────────

(defrule resolve-navigate-to-user-needed
  (declare (salience 110))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 user) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (object-state (name user) (room ?user-room))
  ?rs <- (robot-state (room ?current))
  (test (neq ?current ?user-room))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will go to " ?user-room " to find the user"))))
  (assert (action-step (step ?act-step)        (action goto) (arg (str-cat ?user-room))))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg (str-cat "I have arrived at " ?user-room))))
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
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 3))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will navigate to " ?dest))))
  (assert (action-step (step ?act-step) (action say)  (arg (str-cat "Navigating to " ?dest))))
  (assert (action-step (step (+ ?act-step 1))        (action goto) (arg (str-cat ?dest))))
  (assert (action-step (step (+ ?act-step 2)) (action say)  (arg (str-cat "I have arrived at " ?dest))))
  (assert (robot-state (room ?dest) (holding ?held)))
)

(defrule resolve-navigate-to-unknown-dest
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 7))))
  (assert (action-step (step ?say-step)       (action say)    (arg "I could not understand the location, may I follow you to the destination")))
  (assert (action-step (step ?act-step)       (action say)    (arg (str-cat "Searching for user"))))
  (assert (action-step (step (+ ?act-step 1)) (action find)   (arg "user")))
  (assert (action-step (step (+ ?act-step 2)) (action say)    (arg (str-cat "Following user"))))
  (assert (action-step (step (+ ?act-step 3)) (action follow) (arg "user")))
  (assert (action-step (step (+ ?act-step 4)) (action listen) (arg "stop_following")))
  (assert (action-step (step (+ ?act-step 5)) (action save)   (arg "known_location")))
  (assert (action-step (step (+ ?act-step 6)) (action say)    (arg (str-cat "Saving known_location"))))
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

;; ── acquire ──────────────────────────────────────────────

(defrule resolve-acquire-in-same-room
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?robot-room) (holding ?held))
  (object-state (name ?obj) (room ?robot-room))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 6))))
  (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will look for " ?obj))))
  (assert (action-step (step ?act-step)        (action say)   (arg (str-cat "Searching for " ?obj))))
  (assert (action-step (step (+ ?act-step 1))  (action find)  (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 2)) (action align)  (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 3)) (action say)    (arg (str-cat "Taking " ?obj))))
  (assert (action-step (step (+ ?act-step 4)) (action take)   (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 5)) (action say)    (arg (str-cat "Object successfully taken"))))
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
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 4))))
  (assert (act-counter (value (+ ?act-step 12))))
  (assert (action-step (step ?say-step)        (action say)    (arg (str-cat "I do not have a registered location for " ?obj))))
  (assert (action-step (step (+ ?say-step 1))  (action say)    (arg (str-cat "May I follow you to where " ?obj " is?"))))
  (assert (action-step (step (+ ?say-step 2))  (action say)    (arg (str-cat "I will find " ?obj))))
  (assert (action-step (step (+ ?say-step 3))  (action say)    (arg (str-cat "I will take " ?obj))))
  (assert (action-step (step ?act-step)        (action say)    (arg (str-cat "Searching for user"))))
  (assert (action-step (step (+ ?act-step 1))  (action find)   (arg "user")))
  (assert (action-step (step (+ ?act-step 2))  (action say)    (arg (str-cat "Following user"))))
  (assert (action-step (step (+ ?act-step 3))  (action follow) (arg "user")))
  (assert (action-step (step (+ ?act-step 4))  (action listen) (arg "stop_following")))
  (assert (action-step (step (+ ?act-step 5))  (action say)    (arg (str-cat "Saving known_location"))))
  (assert (action-step (step (+ ?act-step 6))  (action save)   (arg (str-cat "location: " ?obj))))
  (assert (action-step (step (+ ?act-step 7))  (action say)    (arg (str-cat "Searching " ?obj))))
  (assert (action-step (step (+ ?act-step 8))  (action find)   (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 9))  (action align)  (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 10)) (action say)    (arg (str-cat "Taking " ?obj))))
  (assert (action-step (step (+ ?act-step 11)) (action take)   (arg (str-cat ?obj))))
)

;; ── deliver ──────────────────────────────────────────────

(defrule resolve-deliver
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type deliver)
                   (arg1 ?obj) (arg2 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will deliver " ?obj " to " ?dest))))
  (assert (action-step (step ?act-step)        (action say)  (arg (str-cat "Giving " ?obj " to " ?dest))))
  (assert (action-step (step (+ ?act-step 1))  (action give) (arg (str-cat ?obj " " ?dest))))
)

;; ── attend-at ────────────────────────────────────────────

(defrule resolve-attend-already-there
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type attend-at)
                   (arg1 ?obj) (arg2 ?loc&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (robot-state (room ?loc))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step) (action say)  (arg (str-cat "I will search for " ?obj))))
  (assert (action-step (step ?act-step) (action say)  (arg (str-cat "Searching for " ?obj))))
  (assert (action-step (step (+ ?act-step 1)) (action find) (arg (str-cat ?obj))))
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
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step) (action say)  (arg (str-cat "I will search for " ?obj))))
  (assert (action-step (step ?act-step) (action say)  (arg (str-cat "Searching for " ?obj))))
  (assert (action-step (step (+ ?act-step 1)) (action find) (arg (str-cat ?obj))))
)

;; ── accompany-to ─────────────────────────────────────────

(defrule resolve-accompany-to
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type accompany-to)
                   (arg1 ?person) (arg2 ?dest&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (room ?current) (holding ?held))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 4))))
  (assert (action-step (step ?say-step)        (action say)    (arg (str-cat "I will escort " ?person " to " ?dest))))
  (assert (action-step (step ?act-step)        (action say)    (arg (str-cat "Searching for " ?person))))
  (assert (action-step (step (+ ?act-step 1))  (action find)   (arg (str-cat ?person))))
  (assert (action-step (step (+ ?act-step 2))  (action say)    (arg (str-cat "Following " ?person " to " ?dest))))
  (assert (action-step (step (+ ?act-step 3))  (action follow) (arg (str-cat ?person " " ?dest))))
  (assert (robot-state (room ?dest) (holding ?held)))
)

(defrule resolve-accompany-to-unknown-dest
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type accompany-to)
                   (arg1 ?person) (arg2 unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 4))))
  (assert (action-step (step ?say-step)        (action say)    (arg (str-cat "I will escort " ?person))))
  (assert (action-step (step ?act-step)        (action say)    (arg (str-cat "Searching for " ?person))))
  (assert (action-step (step (+ ?act-step 1))  (action find)   (arg (str-cat ?person))))
  (assert (action-step (step (+ ?act-step 2))  (action say)    (arg (str-cat "Following " ?person))))
  (assert (action-step (step (+ ?act-step 3))  (action follow) (arg (str-cat ?person))))
)

;; ── communicate ──────────────────────────────────────────
;;
;; El briefing anuncia que va a comunicar algo.
;; La acción real es el say con el contenido.

(defrule resolve-communicate
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type communicate)
                   (arg1 ?content) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 1))))
  (assert (action-step (step ?say-step) (action say) (arg "I will now communicate the requested information")))
  (assert (action-step (step ?act-step) (action say) (arg (str-cat ?content))))
)

;; ── interact ─────────────────────────────────────────────

(defrule resolve-interact
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type interact) (arg1 ?person) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 3))))
  (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will greet " ?person))))
  (assert (action-step (step ?act-step)        (action find)  (arg (str-cat ?person))))
  (assert (action-step (step (+ ?act-step 1)) (action focus) (arg (str-cat ?person))))
  (assert (action-step (step (+ ?act-step 2)) (action say)   (arg "greet")))
)

;; ── wait-for ─────────────────────────────────────────────

(defrule resolve-wait-for
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type wait-for) (arg1 ?condition) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 1))))
  (assert (action-step (step ?say-step) (action say)    (arg (str-cat "I am waiting for " ?condition))))
  (assert (action-step (step ?act-step) (action listen) (arg (str-cat ?condition))))
)

;; ── report-not-found ─────────────────────────────────────
;;
;; Error — va directo al act-counter (no tiene briefing previo
;; porque es un recovery inesperado, no parte del plan).

(defrule resolve-report-not-found
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type report-not-found) (arg1 ?target) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?ac)
  (assert (act-counter (value (+ ?act-step 1))))
  (assert (action-step (step ?act-step) (action say)
                       (arg (str-cat "I could not find " ?target))))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 5 — RECOVERY POR FEEDBACK DEL EXECUTOR
;; salience 150 — sin cambios
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
;;
;; El orden natural de los step numbers produce:
;;   1, 2, 3 ...       → briefing (says de anuncio)
;;   1001, 1002 ...    → acciones reales + says de confirmación
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
    (robot ROBOT)
    (action ?action)
    (params ?arg)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 7 — PASOS FINALES OBLIGATORIOS (salience 20)
;;
;; Se añaden al final de cualquier plan:
;;   1. goto inspection_point
;;   2. say "test completed"
;; Solo se añaden si ya se han generado acciones del plan
;; (act-counter > 1001) y no se han añadido antes.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule add-final-steps
  (declare (salience 20))
  (not (cd-primitive))
  (not (sub-task (status pending)))
  (not (sub-task (status waiting)))
  (not (final-steps-added))
  ?ac <- (act-counter (value ?act-step))
  (test (> ?act-step 1001))   ; Solo si ya se generaron acciones del plan
  =>
  (retract ?ac)
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?act-step)      (action goto) (arg "inspection_point")))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg "test completed")))
  (assert (final-steps-added))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 8 — FINALIZACION  (salience 5)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule gpsr-finish
  (declare (salience 5))
  (not (cd-primitive))
  (not (sub-task (status pending)))
  (not (sub-task (status waiting)))
  (not (action-step))
  (not (plan-note (state GPSR_DONE)))
  =>
  (assert (plan-note (robot ROBOT) (state GPSR_DONE)))
)
