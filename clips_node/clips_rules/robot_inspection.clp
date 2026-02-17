; -------------------------
; Templates necesarios
; -------------------------

(deftemplate item
   (slot type)
   (slot name)
   (slot room)
)

(deftemplate goal
   (slot step   (type INTEGER))
   (slot action (type SYMBOL))
   (slot robot  (type SYMBOL))
   (slot room)
   (slot objective)
   (slot target)
)

(deftemplate current-step
  (slot value (type INTEGER))
)

(deffacts initial-state
   (item (type Robot) (name robot) (room kitcehn))
)


(deftemplate ros-message
   (slot step   (type INTEGER))
   (slot content (type STRING))
)

; ==========================================================
; Reglas para mover al robot a otra habitación
; ==========================================================

(defrule move-robot
   ?g <- (goal (step ?s)
               (action move)
               (robot ?r)
               (room ?target))
   ?i <- (item (type Robot)
               (name ?r)
               (room ?current&~?target))
   (not (goal (step ?s2&:(< ?s2 ?s))))
   =>
   ;; consumir el goal
   (retract ?g)

   ;; actualizar estado interno del robot
   (modify ?i (room ?target))

   ;; emitir comando a ROS
   (assert (ros-message
      (step ?s)
      (content (str-cat "goto " ?target))))
)

(defrule robot-already-in-room
   ?i <- (item (type Robot) (name ?r) (room ?room))
   ?g <- (goal (step ?s)
               (action move)
               (robot ?r)
               (room ?room))
   (not (goal (step ?s2&:(< ?s2 ?s))))
   =>
   (retract ?g)
   (assert (ros-message
      (step ?s)
      (content (str-cat "already_in_room " ?room))))
)


; ==========================================================
; Reglas para esperar y escuchar eventos externos
; ==========================================================

(defrule wait-for-objective
?g <- (goal (step ?s)
            (action wait_for)
            (robot ?r)
            (objective ?o))
(not (goal (step ?s2&:(< ?s2 ?s))))
=>
(retract ?g)
(assert (ros-message
   (step ?s)
   (content (str-cat "wait_for " ?o))))
)


(defrule listen-for-target
?g <- (goal (step ?s)
            (action listen_for)
            (robot ?r)
            (target ?t))
(not (goal (step ?s2&:(< ?s2 ?s))))
=>
(retract ?g)
(assert (ros-message
   (step ?s)
   (content (str-cat "listen_for " ?t))))
)
