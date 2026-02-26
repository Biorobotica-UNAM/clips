; -------------------------
; Templates necesarios
; -------------------------

(deftemplate plan-started)

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
   (item (type Robot) (name robot) (room kitchen))
)


(deftemplate ros-message
   (slot step   (type INTEGER))
   (slot content (type STRING))
)

(defrule announce-plan-start
   (declare (salience 1000))
   ?g <- (goal (step ?s))
   (not (goal (step ?s2&:(< ?s2 ?s))))
   (not (plan-started))
   =>
   (assert (plan-started))
   (assert (ros-message
      (step 0)
      (content "say robot_inspection_test")))
)

; ==========================================================
; Reglas para mover al robot a otra habitación
; ==========================================================

(defrule move-robot
   ?g <- (goal (step ?s)
               (action move)
               (robot ?r)
               (room ?target))
   (not (goal (step ?s2&:(< ?s2 ?s))))
   =>
   ;; consumir el goal
   (retract ?g)

   ;; anunciar acción
   (assert (ros-message
      (step ?s)
      (content (str-cat "say I'm_going_to_" ?target))))

   ;; emitir comando a ROS
   (assert (ros-message
      (step ?s)
      (content (str-cat "goto " ?target))))
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

;; anunciar
(assert (ros-message
   (step ?s)
   (content (str-cat "say Waiting_for_" ?o))))

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

;; anunciar
(assert (ros-message
   (step ?s)
   (content (str-cat "say Listening_for_" ?t))))

(assert (ros-message
   (step ?s)
   (content (str-cat "listen_for " ?t))))
)
