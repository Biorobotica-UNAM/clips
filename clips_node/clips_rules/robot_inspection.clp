;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TEMPLATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deftemplate item
   (slot type)
   (slot name)
   (slot room)
)

(deftemplate goal
   (slot action)
   (slot actor)
   (slot objective)
)

(deftemplate plan
   (slot name)
   (slot number)
   (multislot actions)
)

(deftemplate plan-building
   (slot name)
   (multislot actions)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INITIAL FACTS (WORLD STATE)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deffacts initial-world
   (item
      (type Robot)
      (name Robot)
      (room entrance)
   )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PLAN INITIALIZATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule start-plan
   (not (plan-building))
   (goal (action ?a) (actor ?r) (objective ?o))
   =>
   (assert
      (plan-building
         (name ?r)
         (actions)
      )
   )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MOVE (PTRANS) RULES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule plan-move
   ?pb <- (plan-building (name ?robot) (actions $?acts))
   ?r  <- (item (type Robot) (name ?robot) (room ?current))
   ?g  <- (goal (action move) (actor ?robot) (objective ?target))
   (test (neq ?current ?target))
   =>
   (retract ?g)
   (modify ?r (room ?target))
   (modify ?pb (actions $?acts goto ?target))
)

(defrule plan-move-already-there
   ?pb <- (plan-building (name ?robot) (actions $?acts))
   (item (type Robot) (name ?robot) (room ?room))
   ?g <- (goal (action move) (actor ?robot) (objective ?room))
   =>
   (retract ?g)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WAIT RULES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule plan-wait
   ?pb <- (plan-building (name ?robot) (actions $?acts))
   ?g  <- (goal (action wait_for) (actor ?robot) (objective ?condition))
   =>
   (retract ?g)
   (modify ?pb (actions $?acts wait_for ?condition))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINALIZE PLAN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule finalize-plan
   ?pb <- (plan-building (name ?robot) (actions $?acts))
   (not (goal))
   =>
   (retract ?pb)
   (assert
      (plan
         (name ?robot)
         (number *)
         (actions $?acts)
      )
   )
)
