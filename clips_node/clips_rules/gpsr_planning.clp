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
;;    1001.. → acciones reales   (go_to, find, align, take, give...)
;;
;;  NOTA: Este archivo requiere que previamente se haya cargado
;;        gpsr_templates.clp
;;
;;  BioRobotics Laboratory, Facultad de Ingenieria, UNAM
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 1 — TEMPLATES LOCALES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; cd-primitive: hecho generado por primitive_to_clips_node.
;;
;; Slots comunes a todas las primitivas:
;;   step, primitive, actor
;;
;; Slots de movimiento (ptrans, accompany):
;;   subtype, source, destination
;;
;; Slots de objeto (grasp, atrans, attend):
;;   subtype, object, object_category, location
;;
;; Slots de persona acompañada / destinatario (accompany, atrans, social):
;;   person_name, person_pose, person_gesture, person_side,
;;   person_body_part, person_clothing_color, person_clothing_item
;;
;; Slots de destinatario de entrega (atrans):
;;   recipient_person_name, recipient_person_pose,
;;   recipient_person_gesture, recipient_person_side,
;;   recipient_person_body_part, recipient_location
;;
;; Slots de comunicación (mtrans, speak):
;;   content, recipient
;;
;; Slots de percepción (attend, query):
;;   query_attribute, query_filter
;;
(deftemplate cd-primitive
  (slot step                      (type INTEGER) (default 0))
  (slot primitive                 (type SYMBOL)  (default unknown))
  (slot actor                     (type SYMBOL)  (default robot))
  (slot subtype                   (type SYMBOL)  (default unknown))

  ;; movimiento
  (slot source                    (type SYMBOL)  (default unknown))
  (slot destination               (type SYMBOL)  (default unknown))

  ;; objeto
  (slot object                    (type SYMBOL)  (default unknown))
  (slot object_category           (type SYMBOL)  (default unknown))
  (slot location                  (type SYMBOL)  (default unknown))

  ;; persona acompañada / social
  (slot person_name               (type SYMBOL)  (default unknown))
  (slot person_pose               (type SYMBOL)  (default unknown))
  (slot person_gesture            (type SYMBOL)  (default unknown))
  (slot person_side               (type SYMBOL)  (default unknown))
  (slot person_body_part          (type SYMBOL)  (default unknown))
  (slot person_clothing_color     (type SYMBOL)  (default unknown))
  (slot person_clothing_item      (type SYMBOL)  (default unknown))

  ;; destinatario de entrega
  (slot recipient_person_name     (type SYMBOL)  (default unknown))
  (slot recipient_person_pose     (type SYMBOL)  (default unknown))
  (slot recipient_person_gesture  (type SYMBOL)  (default unknown))
  (slot recipient_person_side     (type SYMBOL)  (default unknown))
  (slot recipient_person_body_part (type SYMBOL) (default unknown))
  (slot recipient_location        (type SYMBOL)  (default unknown))

  ;; comunicación
  (slot content                   (type SYMBOL)  (default unknown))
  (slot recipient                 (type SYMBOL)  (default unknown))

  ;; percepción
  (slot query_attribute           (type SYMBOL)  (default unknown))
  (slot query_filter              (type SYMBOL)  (default unknown))
)

(deftemplate robot-state
  (slot name       (type SYMBOL) (default unknown))
  (slot room       (type SYMBOL) (default unknown))
  (slot left_hand  (type SYMBOL) (default nothing))
  (slot right_hand (type SYMBOL) (default nothing))
  (slot holding    (type SYMBOL) (default nothing))
)

(deftemplate object-state
  (slot name (type SYMBOL) (default unknown))
  (slot room (type SYMBOL) (default unknown))
)

(deftemplate person-state
  (slot name (type SYMBOL) (default unknown))
  (slot room (type SYMBOL) (default unknown))
)

;; status válidos: pending, waiting
(deftemplate sub-task
  (slot id     (type INTEGER) (default 0))
  (slot type   (type SYMBOL)  (default unknown))
  (slot arg1   (type SYMBOL)  (default unknown))
  (slot arg2   (type SYMBOL)  (default unknown))
  (slot arg3   (type SYMBOL)  (default unknown))  ; descripcion extra de persona
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
;; HELPERS — funciones para describir personas
;;
;; build-person-desc: produce una cadena legible a partir de
;; los slots de persona: nombre, pose, gesto+lado+parte.
;;
;;  Ejemplos:
;;   (name Angel)                              → "Angel"
;;   (pose standing)                           → "the standing person"
;;   (gesture raising) (side right) (body_part arm) → "person raising right arm"
;;   (clothing_color white) (clothing_item blouse)  → "person in white blouse"
;;   todos unknown                             → "person"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deffunction build-person-desc
  (?name ?pose ?gesture ?side ?body_part ?clothing_color ?clothing_item)

  (if (neq ?name unknown) then (return (str-cat ?name)))

  (bind ?desc "")

  ;; atributo de pose
  (if (neq ?pose unknown) then
    (bind ?desc (str-cat "the " ?pose " person"))
    (return ?desc))

  ;; atributo de gesto
  (if (neq ?gesture unknown) then
    (bind ?desc (str-cat "person " ?gesture))
    (if (neq ?side unknown) then
      (bind ?desc (str-cat ?desc " " ?side)))
    (if (neq ?body_part unknown) then
      (bind ?desc (str-cat ?desc " " ?body_part)))
    (return ?desc))

  ;; atributo de ropa
  (if (neq ?clothing_color unknown) then
    (bind ?desc (str-cat "person in " ?clothing_color))
    (if (neq ?clothing_item unknown) then
      (bind ?desc (str-cat ?desc " " ?clothing_item)))
    (return ?desc))

  (return "person")
)

(deffunction build-recipient-desc
  (?name ?pose ?gesture ?side ?body_part)

  (if (neq ?name unknown) then (return (str-cat ?name)))

  (if (neq ?pose unknown) then
    (return (str-cat "the " ?pose " person")))

  (if (neq ?gesture unknown) then
    (bind ?desc (str-cat "person " ?gesture))
    (if (neq ?side unknown) then
      (bind ?desc (str-cat ?desc " " ?side)))
    (if (neq ?body_part unknown) then
      (bind ?desc (str-cat ?desc " " ?body_part)))
    (return ?desc))

  (return "user")
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
  (assert (act-counter (value 1003)))
  (assert (action-step (step 1001) (action say)         (arg "Please stay still, I want to remember your face")))
  (assert (action-step (step 1002) (action find_person) (arg (str-cat "anybody"))))
  (assert (plan-note (robot ROBOT) (state GPSR_START)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 3 — CAPA 1: EXPANSION DE PRIMITIVAS CD
;;
;; ID = step * 100 + offset garantiza orden entre primitivas.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ── ptrans ───────────────────────────────────────────────

(defrule expand-ptrans
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive ptrans) (step ?step) (destination ?dest))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type navigate-to) (arg1 ?dest)))
)

;; ── grasp ────────────────────────────────────────────────
;;
;; El nodo C++ coloca la ubicacion en el slot 'location'.
;; Si se conoce, se emite un navigate-to + acquire.
;; Si es unknown, solo acquire (el planner usará world-state
;; o caerá en el fallback de ubicación desconocida).

(defrule expand-grasp-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive grasp)
                       (step ?step)
                       (object ?obj)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type acquire)     (arg1 ?obj) (arg2 ?loc)))
)

(defrule expand-grasp-unknown-location
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive grasp)
                       (step ?step)
                       (object ?obj)
                       (location unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type acquire) (arg1 ?obj) (arg2 unknown)))
)

;; ── atrans ───────────────────────────────────────────────
;;
;; Cuatro variantes según si hay recipient_location / recipient_person:
;;   1. Entrega a persona con ubicación conocida
;;   2. Entrega a persona sin ubicación (user genérico)
;;   3. Place a una ubicación (sin persona)
;;   4. Entrega genérica (destination = user, sin datos de persona)

(defrule expand-atrans-to-person-at-location
  (declare (salience 210))
  ?cd <- (cd-primitive (primitive atrans)
                       (step ?step)
                       (object ?obj)
                       (source ?src)
                       (recipient_location ?rloc&~unknown)
                       (recipient_person_name     ?rpname)
                       (recipient_person_pose     ?rppose)
                       (recipient_person_gesture  ?rpgesture)
                       (recipient_person_side     ?rpside)
                       (recipient_person_body_part ?rpbp))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (bind ?person-desc
    (build-recipient-desc ?rpname ?rppose ?rpgesture ?rpside ?rpbp))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?rloc)))
  (assert (sub-task (id (+ ?base 1)) (type find-person)  (arg1 (sym-cat ?person-desc)) (arg2 ?rloc) (arg3 (sym-cat ?person-desc))))
  (assert (sub-task (id (+ ?base 2)) (type deliver)      (arg1 ?obj) (arg2 (sym-cat ?person-desc))))
)

(defrule expand-atrans-place-at-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive atrans)
                       (step ?step)
                       (subtype place)
                       (object ?obj)
                       (destination ?dest&~unknown&~user))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?dest)))
  (assert (sub-task (id (+ ?base 1)) (type place-at)    (arg1 ?obj) (arg2 ?dest)))
)

;; Destino conocido (no unknown, no place) → navegar y entregar
(defrule expand-atrans-to-known-dest
  (declare (salience 195))
  ?cd <- (cd-primitive (primitive atrans)
                       (step ?step)
                       (object ?obj)
                       (destination ?dest&~unknown))
  (robot-state (holding ?held))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (if (eq ?held ?obj)
    then
      ;; ya lo tiene en mano (vino de un GRASP previo en el mismo plan)
      (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?dest)))
      (assert (sub-task (id (+ ?base 1)) (type deliver)     (arg1 ?obj) (arg2 ?dest)))
    else
      ;; caso normal "bring X to Y" — hay que ir a buscarlo primero
      (assert (sub-task (id ?base)        (type acquire)     (arg1 ?obj)))
      (assert (sub-task (id (+ ?base 1)) (type navigate-to) (arg1 ?dest)))
      (assert (sub-task (id (+ ?base 2)) (type deliver)     (arg1 ?obj) (arg2 ?dest)))
  )
)

;; Destino unknown pero objeto con ubicación conocida en world-state
;; → acquire (ir a buscar el objeto) y luego deliver al user
(defrule expand-atrans-unknown-dest-known-object
  (declare (salience 193))
  ?cd <- (cd-primitive (primitive atrans)
                       (step ?step)
                       (object ?obj&~unknown)
                       (destination unknown))
  (object-state (name ?obj) (room ?obj-room&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?obj-room)))
  (assert (sub-task (id (+ ?base 1)) (type acquire)     (arg1 ?obj) (arg2 ?obj-room)))
  (assert (sub-task (id (+ ?base 2)) (type deliver)     (arg1 ?obj) (arg2 user)))
)

;; Destino unknown y objeto sin ubicación conocida → buscar directamente
(defrule expand-atrans-unknown-dest-unknown-object
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive atrans)
                       (step ?step)
                       (object ?obj)
                       (destination unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 unknown)))
  (assert (sub-task (id (+ ?base 1)) (type deliver)     (arg1 ?obj) (arg2 user)))
)

;; ── attend ───────────────────────────────────────────────

(defrule expand-attend-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive attend)
                       (step ?step)
                       (object ?obj)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type attend-at)   (arg1 ?obj) (arg2 ?loc)))
)

(defrule expand-attend-unknown-location
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive attend)
                       (step ?step)
                       (object ?obj)
                       (location unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type attend-at) (arg1 ?obj) (arg2 unknown)))
)

;; ── accompany ────────────────────────────────────────────

(defrule expand-accompany
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive accompany)
                       (step ?step)
                       (subtype ?subtype)
                       (person_name     ?pname)
                       (person_pose     ?ppose)
                       (person_gesture  ?pgesture)
                       (person_side     ?pside)
                       (person_body_part ?pbp)
                       (person_clothing_color ?pcc)
                       (person_clothing_item  ?pci)
                       (source      ?src)
                       (destination ?dest))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (bind ?person-desc
    (build-person-desc ?pname ?ppose ?pgesture ?pside ?pbp ?pcc ?pci))
  (bind ?person-sym (sym-cat ?person-desc))
  ;; Si hay location conocida (source), navegar primero
  (if (neq ?src unknown) then
    (assert (sub-task (id ?base)        (type navigate-to)  (arg1 ?src)))
    (assert (sub-task (id (+ ?base 1)) (type find-person)   (arg1 ?person-sym) (arg2 ?src)   (arg3 ?person-sym)))
    (assert (sub-task (id (+ ?base 2)) (type accompany-to)  (arg1 ?person-sym) (arg2 ?dest)))
  else
    (assert (sub-task (id ?base)        (type find-person)  (arg1 ?person-sym) (arg2 unknown) (arg3 ?person-sym)))
    (assert (sub-task (id (+ ?base 1)) (type accompany-to)  (arg1 ?person-sym) (arg2 ?dest)))
  )
)

;; ── mtrans ───────────────────────────────────────────────
;;
;; El nuevo C++ ya NO pone 'to' ni 'location'. Usa:
;;   content   → qué comunicar
;;   recipient → user / person / etc.
;; La ubicación del recipient se resuelve con world-state
;; o se omite si es unknown (el robot habla donde esté).

(defrule expand-mtrans-recipient-at-location
  (declare (salience 210))
  ?cd <- (cd-primitive (primitive mtrans)
                       (step ?step)
                       (content ?content&~unknown)
                       (recipient ?recip&~unknown)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type find-person)  (arg1 ?recip) (arg2 ?loc) (arg3 ?recip)))
  (assert (sub-task (id (+ ?base 2)) (type communicate)  (arg1 ?content)))
)

(defrule expand-mtrans-recipient-known-world
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive mtrans)
                       (step ?step)
                       (content ?content&~unknown)
                       (recipient ?recip&~unknown)
                       (location unknown))
  (person-state (name ?recip) (room ?recip-room&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?recip-room)))
  (assert (sub-task (id (+ ?base 1)) (type find-person)  (arg1 ?recip) (arg2 ?recip-room) (arg3 ?recip)))
  (assert (sub-task (id (+ ?base 2)) (type communicate)  (arg1 ?content)))
)

(defrule expand-mtrans-recipient-unknown
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive mtrans)
                       (step ?step)
                       (content ?content&~unknown)
                       (recipient ?recip)
                       (location unknown))
  (not (person-state (name ?recip)))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type find-person)  (arg1 ?recip) (arg2 unknown) (arg3 ?recip)))
  (assert (sub-task (id (+ ?base 1)) (type communicate)   (arg1 ?content)))
)

;; ── speak ────────────────────────────────────────────────

(defrule expand-speak
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive speak) (step ?step) (content ?content))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type communicate) (arg1 ?content)))
)

;; ── social ───────────────────────────────────────────────

(defrule expand-social-with-location
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive social)
                       (step ?step)
                       (person_name     ?pname)
                       (person_pose     ?ppose)
                       (person_gesture  ?pgesture)
                       (person_side     ?pside)
                       (person_body_part ?pbp)
                       (person_clothing_color ?pcc)
                       (person_clothing_item  ?pci)
                       (location ?loc&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (bind ?person-desc
    (build-person-desc ?pname ?ppose ?pgesture ?pside ?pbp ?pcc ?pci))
  (bind ?person-sym (sym-cat ?person-desc))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?loc)))
  (assert (sub-task (id (+ ?base 1)) (type interact)     (arg1 ?person-sym) (arg2 ?loc)))
)

(defrule expand-social-known-world
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive social)
                       (step ?step)
                       (person_name     ?pname&~unknown)
                       (location unknown))
  (person-state (name ?pname) (room ?person-room&~unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base)        (type navigate-to) (arg1 ?person-room)))
  (assert (sub-task (id (+ ?base 1)) (type interact)     (arg1 ?pname) (arg2 ?person-room)))
)

(defrule expand-social-unknown-location
  (declare (salience 190))
  ?cd <- (cd-primitive (primitive social)
                       (step ?step)
                       (person_name     ?pname)
                       (person_pose     ?ppose)
                       (person_gesture  ?pgesture)
                       (person_side     ?pside)
                       (person_body_part ?pbp)
                       (person_clothing_color ?pcc)
                       (person_clothing_item  ?pci)
                       (location unknown))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (bind ?person-desc
    (build-person-desc ?pname ?ppose ?pgesture ?pside ?pbp ?pcc ?pci))
  (bind ?person-sym (sym-cat ?person-desc))
  (assert (sub-task (id ?base) (type interact) (arg1 ?person-sym) (arg2 unknown)))
)

;; ── wait ─────────────────────────────────────────────────

(defrule expand-wait
  (declare (salience 200))
  ?cd <- (cd-primitive (primitive wait) (step ?step) (object ?condition))
  =>
  (retract ?cd)
  (bind ?base (* ?step 100))
  (assert (sub-task (id ?base) (type wait-for) (arg1 ?condition)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SECCION 4 — CAPA 2: RESOLUCION DE PRECONDICIONES
;;
;; Arquitectura de doble contador:
;;   ?say-step ← say-counter  → briefing al inicio del plan
;;   ?act-step ← act-counter  → acciones reales
;;
;; salience: 110 especiales, 105 restore, 100 normal, 90 fallback
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ── navigate-to ──────────────────────────────────────────

(defrule resolve-navigate-to-user-needed
  (declare (salience 110))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 user) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (person-state (name user) (room ?user-room))
  ?rs <- (robot-state (name ?rname) (room ?current) (left_hand ?lh) (right_hand ?rh) (holding ?held))
  (test (neq ?current ?user-room))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will go to " ?user-room " to find you"))))
  (assert (action-step (step ?act-step)        (action go_to) (arg (str-cat ?user-room))))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg (str-cat "I have arrived at " ?user-room))))
  (assert (robot-state (name ?rname) (room ?user-room) (left_hand ?lh) (right_hand ?rh) (holding ?held)))
)

(defrule resolve-navigate-to-user-already-there
  (declare (salience 110))
  ?st <- (sub-task (id ?id) (type navigate-to) (arg1 user) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (person-state (name user) (room ?user-room))
  (robot-state (room ?user-room))
  =>
  (retract ?st)
)

(defrule resolve-navigate-to-needed
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type navigate-to)
                   (arg1 ?dest&~user&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (name ?rname) (room ?current) (left_hand ?lh) (right_hand ?rh) (holding ?held))
  (test (neq ?current ?dest))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will navigate to " ?dest))))
  (assert (action-step (step ?act-step)        (action go_to) (arg (str-cat ?dest))))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg (str-cat "I have arrived at " ?dest))))
  (assert (robot-state (name ?rname) (room ?dest) (left_hand ?lh) (right_hand ?rh) (holding ?held)))
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
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)   (arg "Navigating to destination")))
  (assert (action-step (step ?act-step)        (action go_to) (arg "unknown")))
  (assert (action-step (step (+ ?act-step 1)) (action say)   (arg "I have arrived")))
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
;;
;; El world-state es la fuente de verdad. Si el objeto tiene ubicación
;; conocida, navegar si es necesario y tomar. Si no hay object-state,
;; buscar directamente donde esté el robot.

(defrule resolve-acquire
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (name ?rname) (room ?robot-room) (left_hand ?lh) (right_hand ?rh) (holding ?held))
  (object-state (name ?obj) (room ?obj-room))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (if (eq ?robot-room ?obj-room)
    then
      (assert (say-counter (value (+ ?say-step 1))))
      (assert (act-counter (value (+ ?act-step 4))))
      (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will pick up " ?obj))))
      (assert (action-step (step ?act-step)        (action align)  (arg (str-cat ?obj))))
      (assert (action-step (step (+ ?act-step 1))  (action find_object) (arg (str-cat ?obj "_1"))))
      (assert (action-step (step (+ ?act-step 2))  (action take)  (arg (str-cat ?obj "_1"))))
      (assert (action-step (step (+ ?act-step 3))  (action say)   (arg (str-cat "I have picked up " ?obj))))
      (assert (robot-state (name ?rname) (room ?robot-room) (left_hand ?lh) (right_hand ?rh) (holding ?obj)))
    else
      (assert (say-counter (value (+ ?say-step 1))))
      (assert (act-counter (value (+ ?act-step 6))))
      (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will go to " ?obj-room " to pick up " ?obj))))
      (assert (action-step (step ?act-step)        (action go_to) (arg (str-cat ?obj-room))))
      (assert (action-step (step (+ ?act-step 1)) (action say)   (arg (str-cat "I have arrived at " ?obj-room))))
      (assert (action-step (step (+ ?act-step 2)) (action align)   (arg (str-cat ?obj))))
      (assert (action-step (step (+ ?act-step 3)) (action find_object)  (arg (str-cat ?obj))))
      (assert (action-step (step (+ ?act-step 4)) (action take)  (arg (str-cat ?obj))))
      (assert (action-step (step (+ ?act-step 5)) (action say)   (arg (str-cat "I have picked up " ?obj))))
      (assert (robot-state (name ?rname) (room ?obj-room) (left_hand ?lh) (right_hand ?rh) (holding ?obj)))
  )
)

(defrule resolve-acquire-unknown-location
  (declare (salience 90))
  ?st <- (sub-task (id ?id) (type acquire) (arg1 ?obj) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  (not (object-state (name ?obj)))
  ?rs <- (robot-state (name ?rname) (room ?robot-room) (left_hand ?lh) (right_hand ?rh))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 4))))
  (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will search for " ?obj))))
  (assert (action-step (step ?act-step)        (action align)  (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 1))  (action find_object) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 2))  (action take)  (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 3))  (action say)   (arg (str-cat "I have picked up " ?obj))))
  (assert (robot-state (name ?rname) (room ?robot-room) (left_hand ?lh) (right_hand ?rh) (holding ?obj)))
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
  (assert (action-step (step ?act-step)        (action give) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg (str-cat "I have delivered " ?obj))))
)

;; ── place-at ─────────────────────────────────────────────

(defrule resolve-place-at
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type place-at)
                   (arg1 ?obj) (arg2 ?dest) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will drop " ?obj " on " ?dest))))
  (assert (action-step (step ?act-step)        (action drop) (arg (str-cat ?obj " " ?dest))))
  (assert (action-step (step (+ ?act-step 1)) (action say)   (arg (str-cat "I have placed " ?obj))))
)

;; ── find-person ──────────────────────────────────────────
;;
;; Sub-tarea generada por atrans, accompany, social y mtrans
;; cuando hay un destinatario con descripción de persona.
;;   arg1 = símbolo de búsqueda (puede ser nombre o descriptor)
;;   arg2 = ubicación donde buscar
;;   arg3 = descripción legible para los says

(defrule resolve-find-person
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type find-person)
                   (arg1 ?target) (arg2 ?loc) (arg3 ?desc) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will look for " ?desc))))
  (assert (action-step (step ?act-step)        (action find_person) (arg (str-cat ?desc "_1"))))
  (assert (action-step (step (+ ?act-step 1)) (action focus) (arg (str-cat ?desc))))
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
  (assert (act-counter (value (+ ?act-step 3))))
  (assert (action-step (step ?say-step)        (action say)  (arg (str-cat "I will search for " ?obj))))
  (assert (action-step (step ?act-step)        (action align) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 1))  (action find_object) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 2))  (action say)  (arg (str-cat "Search complete"))))
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
  (assert (action-step (step ?act-step) (action find_object) (arg (str-cat ?obj))))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg (str-cat "Search complete"))))
)

;; ── accompany-to ─────────────────────────────────────────

(defrule resolve-accompany-to
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type accompany-to)
                   (arg1 ?person) (arg2 ?dest&~unknown) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?rs <- (robot-state (name ?rname) (room ?current) (left_hand ?lh) (right_hand ?rh) (holding ?held))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac) (retract ?rs)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 3))))
  (assert (action-step (step ?say-step)        (action say)    (arg (str-cat "I will escort " ?person " to " ?dest))))
  (assert (action-step (step ?act-step)        (action say) (arg (str-cat "Please follow me to " ?dest))))
  (assert (action-step (step (+ ?act-step 1)) (action go_to)    (arg (str-cat ?dest))))
  (assert (action-step (step (+ ?act-step 2)) (action say)    (arg (str-cat "I have escorted " ?person " to " ?dest))))
  (assert (robot-state (name ?rname) (room ?dest) (left_hand ?lh) (right_hand ?rh) (holding ?held)))
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
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?say-step)        (action say)    (arg (str-cat "I will accompany " ?person))))
  (assert (action-step (step ?act-step)        (action follow) (arg (str-cat ?person))))
  (assert (action-step (step (+ ?act-step 1)) (action say)    (arg (str-cat "Accompanying " ?person))))
)

;; ── communicate ──────────────────────────────────────────

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
  (assert (action-step (step ?say-step) (action say) (arg "I will communicate the requested information")))
  (assert (action-step (step ?act-step) (action say) (arg (str-cat ?content))))
)

;; ── interact ─────────────────────────────────────────────

(defrule resolve-interact
  (declare (salience 100))
  ?st <- (sub-task (id ?id) (type interact)
                   (arg1 ?person) (arg2 ?loc) (status pending))
  (not (sub-task (id ?id2&:(< ?id2 ?id)) (status pending)))
  ?sc <- (say-counter (value ?say-step))
  ?ac <- (act-counter (value ?act-step))
  =>
  (retract ?st) (retract ?sc) (retract ?ac)
  (assert (say-counter (value (+ ?say-step 1))))
  (assert (act-counter (value (+ ?act-step 3))))
  (assert (action-step (step ?say-step)        (action say)   (arg (str-cat "I will greet " ?person))))
  (assert (action-step (step ?act-step)        (action find_person)  (arg (str-cat ?person))))
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
;; Orden natural de step numbers:
;;   1, 2, 3 ...    → briefing (says de anuncio)
;;   1001, 1002 ... → acciones reales
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule add-final-steps
  (declare (salience 20))
  (not (cd-primitive))
  (not (sub-task (status pending)))
  (not (sub-task (status waiting)))
  (not (final-steps-added))
  ?ac <- (act-counter (value ?act-step))
  (test (> ?act-step 1001))
  =>
  (retract ?ac)
  (assert (act-counter (value (+ ?act-step 2))))
  (assert (action-step (step ?act-step)        (action go_to) (arg "instruction_point")))
  (assert (action-step (step (+ ?act-step 1)) (action say)  (arg "task completed")))
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
