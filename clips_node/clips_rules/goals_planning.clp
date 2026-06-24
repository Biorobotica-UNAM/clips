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

(deftemplate ros-message
  (slot step (type INTEGER))
  (slot robot (default Justina))
  (slot action)
  (multislot params))

(deftemplate saved-info
  (slot value))

(deftemplate final-steps-added)

(deftemplate planning-ready)

(deffunction empty-value (?value)
  (return (or (eq ?value "") (eq ?value "unknown"))))

(deffunction object-id (?name)
  (return (str-cat ?name "_1")))

(deffunction person-id (?desc)
  (return (str-cat ?desc "_1")))

(deffunction describe-target (?target ?qualifier)
  (if (neq ?qualifier "") then
    (return (str-cat ?target "_" ?qualifier)))
  (return ?target))

(deffunction append-action (?action ?arg)
  (bind ?facts (find-all-facts ((?ac act-counter)) TRUE))
  (bind ?counter (nth$ 1 ?facts))
  (bind ?step (fact-slot-value ?counter value))
  (retract ?counter)
  (assert (act-counter (value (+ ?step 1))))
  (assert (action-step (step ?step) (action ?action) (arg ?arg))))

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
  (bind ?desc (describe-target ?target ?qualifier))
  (append-say (str-cat "I will look for " ?desc))
  (append-action find_person (person-id ?desc))
  (append-action focus ?desc))

(defrule process-find-object
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name find) (target ?target) (kind ?kind&~person) (qualifier ?qualifier))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (bind ?desc (describe-target ?target ?qualifier))
  (append-say (str-cat "I will search for " ?desc))
  (append-action align "table")
  (append-action find_object (object-id ?desc)))

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
  (append-action give ?obj)
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
  (append-action give ?obj)
  (append-action say (str-cat "I have delivered " ?obj))
  (assert (current-state (location ?loc) (holding "nothing"))))

(defrule process-place
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name place) (target ?obj) (destination ?dest))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc))
  =>
  (retract ?g)
  (retract ?st)
  (if (and (neq ?dest "") (neq ?loc ?dest)) then
    (append-say (str-cat "I will navigate to " ?dest))
    (append-action go_to ?dest))
  (append-say (str-cat "I will place " ?obj))
  (append-action find_space ?dest)
  (append-action drop (object-id ?obj))
  (append-action say (str-cat "I have placed " ?obj))
  (assert (current-state (location ?dest) (holding "nothing"))))

(defrule process-drop
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name drop) (target ?obj) (destination ?dest))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  ?st <- (current-state (location ?loc))
  =>
  (retract ?g)
  (retract ?st)
  (if (and (neq ?dest "") (neq ?loc ?dest)) then
    (append-say (str-cat "I will navigate to " ?dest))
    (append-action go_to ?dest))
  (append-say (str-cat "I will drop " ?obj))
  (append-action drop (object-id ?obj))
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
  (append-action go_to ?dest)
  (append-action say (str-cat "I have guided " ?person " to " ?dest))
  (assert (current-state (location ?dest) (holding ?held))))

(defrule process-follow
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name follow) (target ?person) (destination ?dest))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (append-say (str-cat "I will follow " ?person))
  (append-action follow ?person)
  (if (neq ?dest "") then
    (append-action say (str-cat "I will follow " ?person " to " ?dest))))

(defrule process-count
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name count) (target ?target) (qualifier ?qualifier) (kind ?kind))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (bind ?desc (describe-target ?target ?qualifier))
  (append-say (str-cat "I will count " ?desc))
  (if (eq ?kind person)
    then
      (append-action analyze_person ?desc)
    else
      (append-action analyze_objects ?desc))
  (append-action say "count_category"))

(defrule process-tell
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name tell|talk) (target ?info) (qualifier ?qualifier))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (if (neq ?qualifier "") then
    (append-action say ?qualifier)
    else
    (append-action say ?info)))

(defrule process-save
  (declare (salience 180))
  (planning-ready)
  ?g <- (gpsr-goal (step ?step) (name save) (target ?info))
  (not (gpsr-goal (step ?prev&:(< ?prev ?step))))
  =>
  (retract ?g)
  (assert (saved-info (value ?info)))
  (append-action say (str-cat "I will remember " ?info)))

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
  (append-action analyze_person (person-id ?person))
  (append-action approach (person-id ?person))
  (append-action focus "True")
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
