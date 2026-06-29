;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GPSR directo desde goals de Qwen
;;
;; Entrada esperada:
;;   (gpsr-goal (step 1) (name go) (target "kitchen") ...)
;;
;; Este archivo mantiene el mismo contrato de salida que gpsr_planning.clp:
;;   plan-note   -> ==Justina GPSR_START/DONE==
;;   ros-message -> Paso N: Justina <accion> <parametros>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deftemplate start
  (slot name))

(deftemplate plan-note
  (slot robot (default Justina))
  (slot state))

(deftemplate gpsr-goal
  (slot step (type INTEGER))
  (slot name)
  (slot target (default ""))
  (slot kind (default unknown))
  (slot destination (default ""))
  (slot relation (default ""))
  (slot value (default ""))
  (slot qualifier (default "")))

(deftemplate current-state
  (slot location (default "unknown"))
  (slot holding (default "nothing")))

(deftemplate action-step
  (slot step (type INTEGER))
  (slot action)
  (slot arg (default "")))

(deftemplate say-counter
  (slot value (type INTEGER)))

(deftemplate act-counter
  (slot value (type INTEGER)))

(deftemplate person-counter
  (slot value (type INTEGER)))

(deftemplate ros-message
  (slot step (type INTEGER))
  (slot robot (default Justina))
  (slot action)
  (multislot params))

(deftemplate saved-info
  (slot value))

(deftemplate visual-analysis
  (slot target)
  (slot qualifier)
  (slot query)
  (slot answer))

(deftemplate visual-person-found
  (slot target)
  (slot source))

(deftemplate final-steps-added)

(deftemplate planning-ready)

(deffunction empty-value (?value)
  (return (or (eq ?value "") (eq ?value "unknown"))))

(deffunction object-id (?name)
  (return (str-cat ?name "_1")))

(deffunction person-id (?desc)
  (return (str-cat ?desc "_1")))

(deffunction next-person-id (?desc)
  (bind ?facts (find-all-facts ((?pc person-counter)) TRUE))
  (bind ?counter (nth$ 1 ?facts))
  (bind ?index (fact-slot-value ?counter value))
  (retract ?counter)
  (assert (person-counter (value (+ ?index 1))))
  (return (str-cat ?desc "_" ?index)))

(deffunction describe-target (?target ?qualifier)
  (if (neq ?qualifier "") then
    (return (str-cat ?target "_" ?qualifier)))
  (return ?target))

; Normaliza texto libre de Qwen a los destinos que FindSpace/Drop entienden:
; table, container_down/top, shelf(_N) o floor. Si no reconoce la superficie,
; mantiene table como soporte por defecto despues de navegar al lugar pedido.
(deffunction contains-text (?value ?needle)
  (return (neq (str-index ?needle ?value) FALSE)))

(deffunction support-name (?value)
  (return (or
    (contains-text ?value "floor")
    (contains-text ?value "suelo")
    (contains-text ?value "table")
    (contains-text ?value "mesa")
    (contains-text ?value "shelf")
    (contains-text ?value "rack")
    (contains-text ?value "cabinet")
    (contains-text ?value "bookcase")
    (contains-text ?value "estante")
    (contains-text ?value "repisa")
    (contains-text ?value "container")
    (contains-text ?value "trash")
    (contains-text ?value "bin")
    (contains-text ?value "box")
    (contains-text ?value "bote")
    (contains-text ?value "basura")
    (contains-text ?value "caja"))))

(deffunction table-support (?value)
  (return (or
    (contains-text ?value "table")
    (contains-text ?value "mesa"))))

(deffunction drop-surface (?destination)
  (if (or (contains-text ?destination "floor") (contains-text ?destination "suelo")) then
    (return "floor"))
  (if (contains-text ?destination "shelf_3") then
    (return "shelf_3"))
  (if (contains-text ?destination "shelf_2") then
    (return "shelf_2"))
  (if (contains-text ?destination "shelf_1") then
    (return "shelf_1"))
  (if (or (contains-text ?destination "shelf")
          (contains-text ?destination "rack")
          (contains-text ?destination "cabinet")
          (contains-text ?destination "bookcase")
          (contains-text ?destination "estante")
          (contains-text ?destination "repisa")) then
    (return "shelf"))
  (if (or (contains-text ?destination "container_top")
          (contains-text ?destination "container_high")
          (contains-text ?destination "container_table")
          (contains-text ?destination "encima")
          (contains-text ?destination "sobre_mesa")) then
    (return "container_top"))
  (if (or (contains-text ?destination "container")
          (contains-text ?destination "trash")
          (contains-text ?destination "bin")
          (contains-text ?destination "box")
          (contains-text ?destination "bote")
          (contains-text ?destination "basura")
          (contains-text ?destination "caja")) then
    (return "container_down"))
  (return "table"))

(deffunction destination-phrase (?relation ?destination)
  (if (eq ?destination "") then
    (return ""))
  (if (or (eq ?relation "in") (eq ?relation "on") (eq ?relation "to")) then
    (return (str-cat " " ?relation " " ?destination)))
  (if (or (contains-text ?destination "container")
          (contains-text ?destination "trash")
          (contains-text ?destination "bin")) then
    (return (str-cat " in " ?destination)))
  (return (str-cat " on " ?destination)))

(deffunction qualifier-value (?qualifier ?prefix ?start-index)
  (if (eq (str-index ?prefix ?qualifier) 1) then
    (return (sub-string ?start-index (str-length ?qualifier) ?qualifier)))
  (return ""))

(deffunction normalize-person-attribute (?value)
  (bind ?out "")
  (bind ?i 1)
  (while (<= ?i (str-length ?value)) do
    (bind ?ch (sub-string ?i ?i ?value))
    (if (or (eq ?ch " ") (eq ?ch "-")) then
      (bind ?out (str-cat ?out "_"))
      else
      (if (neq ?ch "'") then
        (bind ?out (str-cat ?out ?ch))))
    (bind ?i (+ ?i 1)))
  (return ?out))

(deffunction normalize-gesture-attribute (?value)
  (bind ?out (normalize-person-attribute ?value))
  (if (contains-text ?out "pointing") then
    (if (contains-text ?out "right") then
      (return "pointing_right"))
    (if (contains-text ?out "left") then
      (return "pointing_left"))
    (return "pointing"))
  (if (or (contains-text ?out "waving") (contains-text ?out "wave")) then
    (return "waving"))
  (if (or (contains-text ?out "raising") (contains-text ?out "raise")) then
    (if (contains-text ?out "right") then
      (return "raising_right"))
    (if (contains-text ?out "left") then
      (return "raising_left"))
    (return "raising"))
  (bind ?suffix "_person")
  (bind ?len (str-length ?out))
  (bind ?slen (str-length ?suffix))
  (if (and (>= ?len ?slen)
           (eq (sub-string (+ (- ?len ?slen) 1) ?len ?out) ?suffix)) then
    (return (sub-string 1 (- ?len ?slen) ?out)))
  (return ?out))

(deffunction describe-person-target (?target ?qualifier)
  (bind ?gesture (qualifier-value ?qualifier "gesture:" 9))
  (if (neq ?gesture "") then
    (return (str-cat ?target " " ?gesture)))
  (return (describe-target ?target ?qualifier)))

; Traduce conteos a AnalyzeObjects para los comandos esperados:
; count(person), count(category). No se generan filtros por color de objetos.
(deffunction count-query (?target ?qualifier ?kind)
  (if (eq ?kind person) then
    (return "count_person"))
  (if (neq ?target "") then
    (return (str-cat "count_" ?target)))
  (return "count_objects"))

; La tool actual de AnalyzeObjects solo tiene extremos por tamaño:
; big/small. Para comandos sin medicion real de peso/grosor usamos proxy visual.
(deffunction size-filter (?qualifier)
  (bind ?property (qualifier-value ?qualifier "property:" 10))
  (if (or (contains-text ?qualifier "biggest")
          (contains-text ?qualifier "largest")
          (contains-text ?property "biggest")
          (contains-text ?property "largest")
          (contains-text ?property "heaviest")) then
    (return "big"))
  (if (or (contains-text ?qualifier "smallest")
          (contains-text ?property "smallest")
          (contains-text ?property "lightest")
          (contains-text ?property "thinnest")) then
    (return "small"))
  (return ""))

(deffunction analyze-object-query (?target ?qualifier ?relation ?value)
  (bind ?filter (size-filter ?qualifier))
  (if (eq ?filter "big") then
    (return (str-cat "biggest_" ?target)))
  (if (eq ?filter "small") then
    (return (str-cat "smallest_" ?target)))
  (return ""))

(deffunction analyze-answer-key (?qualifier)
  (bind ?property (qualifier-value ?qualifier "property:" 10))
  (if (or (contains-text ?qualifier "biggest")
          (contains-text ?property "biggest")
          (contains-text ?property "largest")) then
    (return "biggest_category"))
  (if (contains-text ?property "heaviest") then
    (return "heaviest_category"))
  (if (or (contains-text ?qualifier "smallest")
          (contains-text ?property "smallest")) then
    (return "smallest_category"))
  (if (contains-text ?property "lightest") then
    (return "lightest_category"))
  (if (contains-text ?property "thinnest") then
    (return "thinnest_category"))
  (return ""))

(deffunction talk-answer-key (?info)
  (if (and (contains-text ?info "team") (contains-text ?info "name")) then
    (return "team_name"))
  (if (contains-text ?info "gesture") then
    (return "gesture_category"))
  (if (and (contains-text ?info "day") (contains-text ?info "week")) then
    (return "day_of_week"))
  (return ""))

; AnalyzePerson no cuenta personas; localiza personas por atributos visuales.
; wearing:red_shirt -> color_red_shirt, gesture:waving -> gesture_waving.
(deffunction analyze-person-query (?qualifier)
  (bind ?gesture (qualifier-value ?qualifier "gesture:" 9))
  (if (neq ?gesture "") then
    (return (str-cat "gesture_" (normalize-gesture-attribute ?gesture))))
  (bind ?wearing (qualifier-value ?qualifier "wearing:" 9))
  (if (eq ?wearing "") then
    (bind ?wearing (qualifier-value ?qualifier "wearing=" 9)))
  (if (neq ?wearing "") then
    (return (str-cat "color_" (normalize-person-attribute ?wearing))))
  (bind ?pose (qualifier-value ?qualifier "pose:" 6))
  (if (neq ?pose "") then
    (return (str-cat "gesture_" (normalize-gesture-attribute ?pose))))
  (return ""))

(deffunction append-action (?action ?arg)
  (bind ?facts (find-all-facts ((?ac act-counter)) TRUE))
  (bind ?counter (nth$ 1 ?facts))
  (bind ?step (fact-slot-value ?counter value))
  (retract ?counter)
  (assert (act-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action ?action) (arg ?arg))))

; Drop consume object_id para seleccionar mano y el ultimo safe_drop_1 guardado
; por FindSpace. Floor es la excepcion: no necesita FindSpace.
(deffunction append-drop-sequence (?obj ?destination)
  (bind ?surface (drop-surface ?destination))
  (if (eq ?surface "floor") then
    (append-action drop "floor")
    else
    (append-action find_space ?surface)
    (append-action drop (object-id ?obj))))

(deffunction append-say (?text)
  (bind ?facts (find-all-facts ((?sc say-counter)) TRUE))
  (bind ?counter (nth$ 1 ?facts))
  (bind ?step (fact-slot-value ?counter value))
  (retract ?counter)
  (assert (say-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action say) (arg ?text))))

(defrule goals-initialize
  (declare (salience 500))
  ?s <- (start (name action-planning))
  (not (plan-note (state GPSR_START)))
  (not (plan-note (state GPSR_DONE)))
  =>
  (retract ?s)
  (assert (say-counter (value 1)))
  (assert (act-counter (value 1003)))
  (assert (person-counter (value 1)))
  (assert (current-state (location "unknown") (holding "nothing")))
  (assert (action-step (step 1001) (action say) (arg "Please stay still, I want to remember your face")))
  (assert (action-step (step 1002) (action find_person) (arg "anybody")))
  (assert (planning-ready))
  (assert (plan-note (robot Justina) (state GPSR_START))))

(defrule process-go
  (declare (salience 200))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name go) (target ?dest))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc) (holding ?held))
  =>
  (retract ?g)
  (if (neq ?loc ?dest) then
    (append-say (str-cat "I will navigate to " ?dest))
    (append-action go_to ?dest)
    (append-action say (str-cat "I have arrived at " ?dest))
    (retract ?st)
    (assert (current-state (location ?dest) (holding ?held)))))

(defrule process-find-person
  (declare (salience 190))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name find) (target ?target) (kind person) (qualifier ?qualifier))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (bind ?desc (describe-person-target ?target ?qualifier))
  (append-say (str-cat "I will look for " ?desc))
  (bind ?person_query (analyze-person-query ?qualifier))
  (if (neq ?person_query "") then
    (append-action analyze_person ?person_query)
    (append-action approach "user_2")
    (assert (visual-person-found (target ?target) (source "user_2")))
    else
    (bind ?pid (next-person-id ?desc))
    (append-action find_person ?pid)
    (assert (visual-person-found (target ?target) (source ?pid))))
  (append-action focus "enable"))

(defrule process-find-object
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name find) (target ?target) (kind ?kind&~person) (qualifier ?qualifier))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  (current-state (location ?loc))
  =>
  (retract ?g)
  (bind ?desc (describe-target ?target ?qualifier))
  (append-say (str-cat "I will search for " ?desc))
  (if (table-support ?loc) then
    (append-action align "table"))
  (bind ?analysis "")
  (bind ?answer "")
  (if (neq ?qualifier "") then
    (bind ?analysis (analyze-object-query ?target ?qualifier "" ""))
    (bind ?answer (analyze-answer-key ?qualifier))
    (if (neq ?analysis "") then
      (append-action analyze_objects ?analysis))
    (if (neq ?answer "") then
      (assert (visual-analysis (target ?target) (qualifier ?qualifier) (query ?analysis) (answer ?answer)))))
  (if (or (eq ?qualifier "") (eq ?analysis "") (eq (str-index "count_" ?analysis) 1)) then
    (append-action find_object (object-id ?target))
    else
    (append-action say (str-cat "I found " ?desc))))

(defrule process-take
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name take) (target ?obj))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc) (holding ?held))
  =>
  (retract ?g)
  (retract ?st)
  (append-say (str-cat "I will pick up " ?obj))
  (append-action take (object-id ?obj))
  (append-action say (str-cat "I have picked up " ?obj))
  (assert (current-state (location ?loc) (holding ?obj))))

(defrule process-deliver-to-user
  (declare (salience 190))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name deliver) (target ?obj) (destination ?dest&"me"|"user"|""))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc) (holding ?held))
  =>
  (retract ?g)
  (retract ?st)
  (if (neq ?loc "instruction_point") then
    (append-say "I will return to the instruction point")
    (append-action go_to "instruction_point"))
  (append-say (str-cat "I will deliver " ?obj " to you"))
  (append-action approach "guest_1")
  (append-action give (object-id ?obj))
  (append-action say (str-cat "I have delivered " ?obj))
  (assert (current-state (location "instruction_point") (holding "nothing"))))

(defrule process-deliver-to-person
  (declare (salience 185))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name deliver) (target ?obj) (destination ?dest&~"me"&~"user"&~""))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc))
  =>
  (retract ?g)
  (retract ?st)
  (append-say (str-cat "I will deliver " ?obj " to " ?dest))
  (bind ?known (find-all-facts ((?vp visual-person-found)) (eq ?vp:target ?dest)))
  (if (> (length$ ?known) 0) then
    (bind ?found (nth$ 1 ?known))
    (append-action approach (fact-slot-value ?found source))
    else
    (append-action find_person (person-id ?dest))
    (append-action approach (person-id ?dest)))
  (append-action give (object-id ?obj))
  (append-action say (str-cat "I have delivered " ?obj))
  (assert (current-state (location ?loc) (holding "nothing"))))

(defrule process-place
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name place) (target ?obj) (destination ?dest) (relation ?rel))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc))
  =>
  (retract ?g)
  (retract ?st)
  (if (and (neq ?dest "") (neq ?loc ?dest) (not (support-name ?dest))) then
    (append-say (str-cat "I will navigate to " ?dest))
    (append-action go_to ?dest))
  (append-say (str-cat "I will place " ?obj (destination-phrase ?rel ?dest)))
  (append-drop-sequence ?obj ?dest)
  (append-action say (str-cat "I have placed " ?obj))
  (assert (current-state (location ?dest) (holding "nothing"))))

(defrule process-drop
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name drop) (target ?obj) (destination ?dest) (relation ?rel))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc))
  =>
  (retract ?g)
  (retract ?st)
  (if (and (neq ?dest "") (neq ?loc ?dest) (not (support-name ?dest))) then
    (append-say (str-cat "I will navigate to " ?dest))
    (append-action go_to ?dest))
  (append-say (str-cat "I will drop " ?obj (destination-phrase ?rel ?dest)))
  (append-drop-sequence ?obj ?dest)
  (append-action say (str-cat "I have dropped " ?obj))
  (assert (current-state (location ?dest) (holding "nothing"))))

(defrule process-guide
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name guide) (target ?person) (destination ?dest))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (holding ?held))
  =>
  (retract ?g)
  (retract ?st)
  (append-say (str-cat "Please follow me to " ?dest))
  (append-action say (str-cat "I have guided " ?person " to " ?dest))
  (append-action go_to ?dest)
  (assert (current-state (location ?dest) (holding ?held))))

(defrule process-follow
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name follow) (target ?person) (destination ?dest))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (if (neq ?dest "") then
    (append-say (str-cat "I will follow " ?person " to " ?dest))
    else
    (append-say (str-cat "I will follow " ?person)))
  (bind ?focus_needed TRUE)
  (bind ?known (find-all-facts ((?vp visual-person-found)) (eq ?vp:target ?person)))
  (if (> (length$ ?known) 0) then
    (bind ?found (nth$ 1 ?known))
    (bind ?source (fact-slot-value ?found source))
    (if (neq ?source "user_2") then
      (append-action approach ?source)
      else
      (bind ?focus_needed FALSE))
    else
    (bind ?pid (next-person-id ?person))
    (append-action find_person ?pid)
    (append-action approach ?pid))
  (if ?focus_needed then
    (append-action focus "enable"))
  (if (neq ?dest "") then
    (append-action say (str-cat "I will follow " ?person " to " ?dest))
    (append-action say (str-cat "instruct_follow_to_" ?dest))
    else
    (append-action say "instruct_follow_only")))

(defrule process-count
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name count) (target ?target) (qualifier ?qualifier) (kind ?kind))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc) (holding ?held))
  =>
  (retract ?g)
  (retract ?st)
  (bind ?desc (describe-target ?target ?qualifier))
  (append-say (str-cat "I will count " ?desc))
  (append-action analyze_objects (count-query ?target ?qualifier ?kind))
  ; Count answers are normally requested by the operator at the entrance.
  ; Count where the objects are, return to the instruction point, then report.
  (if (neq ?loc "instruction_point") then
    (append-say "I will return to the instruction point to report the count")
    (append-action go_to "instruction_point"))
  (append-action say "count_category")
  (assert (current-state (location "instruction_point") (holding ?held))))

(defrule process-tell
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name tell|talk) (target ?info) (qualifier ?qualifier))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (if (contains-text ?info "gesture") then
    (append-say "I will tell the gesture")
    else
    (append-say (str-cat "I will tell " ?info)))
  (bind ?answer (analyze-answer-key ?qualifier))
  (if (neq ?answer "") then
    (bind ?known (find-all-facts ((?va visual-analysis))
      (and (eq ?va:target ?info) (eq ?va:qualifier ?qualifier))))
    (if (= (length$ ?known) 0) then
      (bind ?analysis (analyze-object-query ?info ?qualifier "" ""))
      (append-action analyze_objects ?analysis)
      (assert (visual-analysis (target ?info) (qualifier ?qualifier) (query ?analysis) (answer ?answer))))
    (append-action say ?answer)
    else
    (if (neq ?qualifier "") then
      (append-action say ?qualifier)
      else
      (bind ?talk_answer (talk-answer-key ?info))
      (if (neq ?talk_answer "") then
        (append-action say ?talk_answer)
        else
        (append-action say ?info)))))

(defrule process-save
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name save) (target ?info))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (assert (saved-info (value ?info)))
  (if (contains-text ?info "gesture") then
    (append-say "I will save the gesture")
    else
    (append-say (str-cat "I will save " ?info)))
  ; For save(gesture), observe the currently visible person and let
  ; AnalyzePerson store the detected gesture in analytics.gesture.
  (if (contains-text ?info "gesture") then
    (append-action say "I will observe the person's gesture")
    (append-action analyze_person "gesture_any")
    else
    (append-action say (str-cat "I will remember " ?info))))

(defrule process-answer-question
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name answer_question))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (append-say "I will answer the question")
  (append-action listen "answer_question")
  (append-action say "answer_question"))

(defrule process-greet
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name greet) (target ?person))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (append-say (str-cat "I will greet " ?person))
  (bind ?known (find-all-facts ((?vp visual-person-found)) (eq ?vp:target ?person)))
  (if (> (length$ ?known) 0) then
    (bind ?found (nth$ 1 ?known))
    (append-action approach (fact-slot-value ?found source))
    else
    (append-action find_person (person-id ?person))
    (append-action approach (person-id ?person)))
  (append-action focus "enable")
  (append-action say "greet"))

(defrule process-unsupported-goal
  (declare (salience 10))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name ?name) (target ?target))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (append-action say (str-cat "I do not know how to execute goal " ?name " " ?target)))

(defrule add-final-return
  (declare (salience 20))
  (planning-ready)
  (not (gpsr-goal))
  (not (final-steps-added))
  ?st <- (current-state (location ?loc) (holding ?held))
  =>
  (if (neq ?loc "instruction_point") then
    (append-action go_to "instruction_point"))
  (append-action say "task completed")
  (assert (final-steps-added)))

(defrule serialize-action-step
  (declare (salience 5))
  (planning-ready)
  ?as <- (action-step (step ?step) (action ?action) (arg ?arg))
  (not (gpsr-goal))
  (final-steps-added)
  =>
  (retract ?as)
  (assert (ros-message
    (step ?step)
    (robot Justina)
    (action ?action)
    (params ?arg))))

(defrule goals-finish
  (declare (salience 1))
  (planning-ready)
  (not (gpsr-goal))
  (not (action-step))
  (final-steps-added)
  (not (plan-note (state GPSR_DONE)))
  =>
  (assert (plan-note (robot Justina) (state GPSR_DONE))))
