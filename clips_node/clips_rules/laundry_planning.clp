;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TEMPLATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deftemplate start
   (slot name)
)

(deftemplate state
   (slot name)
   (slot phase)
)

(deftemplate stack
   (multislot states)
)

(deftemplate plan-control
   (slot step)
)

(deftemplate ros-message
   (slot step)
   (slot robot)
   (slot action)
   (multislot params)
)

(deftemplate plan-note
   (slot robot)
   (slot state)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INITIALIZATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule initialize
   (declare (salience 100))
   ?s <- (start (name action-planning))
   =>
   (retract ?s)

   (assert (plan-control (step 1)))

   (assert (stack (states
      START_LAUNDRY
      NAVIGATE_TO_LAUNDRY
      RETRIEVE_CLOTHES
      FINISH_LAUNDRY)))

   (assert (plan-note (robot Justina) (state START_LAUNDRY)))
   (assert (state (name START_LAUNDRY) (phase 1)))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GENERIC STEP SENDER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule execute-phase
   ?pc <- (plan-control (step ?n))
   ?s  <- (state (name ?name) (phase ?p&~done))
   =>
   (bind ?action none)
   (bind $?params (create$))
   (bind ?next-phase (+ ?p 1))

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;; START_LAUNDRY
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name START_LAUNDRY) (eq ?p 1)) then
      (bind ?action say)
      (bind $?params (create$ start_laundry))
      (bind ?next-phase done)
   )

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;; NAVIGATE_TO_LAUNDRY
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name NAVIGATE_TO_LAUNDRY) then
      (switch ?p
         
         (case 1 then
            (bind ?action say)
            (bind $?params (create$ I will continue once the door is opened))
         )

         (case 2 then
            (bind ?action check)
            (bind $?params (create$ door))
         )


         (case 3 then
            (bind ?action say)
            (bind $?params (create$ announce_nav_laundry_machine))
         )
         (case 4 then
            (bind ?action goto)
            ;; Cambia basket por tu waypoint real si aplica
            (bind $?params (create$ basket))
         )
         (case 5 then
            (bind ?action say)
            (bind $?params (create$ announce_nav_end_laundry_machine))
            (bind ?next-phase done)
         )
         (default
            (bind ?next-phase done)
         )
      )
   )

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;; RETRIEVE_CLOTHES
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETRIEVE_CLOTHES) then
      (switch ?p

         (case 1 then
            (bind ?action take)
            (bind $?params (create$ clothes))
            (bind ?next-phase done)
         )

         (case 2 then
            (bind ?action say)
            (bind $?params (create$ i took the clothe and i will go to the table))
            (bind ?next-phase done)
         )

         (case 3 then
            (bind ?action goto)
            (bind $?params (create$ kitchen_table))
            (bind ?next-phase done)
         )
         
         (default
            (bind ?next-phase done)
         )
      )
   )

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;; FINISH_LAUNDRY
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name FINISH_LAUNDRY) (eq ?p 1)) then
      (bind ?action say)
      (bind $?params (create$ finish_laundry))
      (bind ?next-phase done)
   )

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ;; EXECUTION
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (neq ?action none) then
      (assert (ros-message
         (step ?n)
         (robot Justina)
         (action ?action)
         (params $?params)
      ))
      (modify ?pc (step (+ ?n 1)))
   )

   (if (eq ?next-phase done) then
      (modify ?s (phase done))
    else
      (modify ?s (phase ?next-phase))
   )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MOVE TO NEXT MACRO STATE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule next-macro
   (declare (salience 10))
   ?s  <- (state (name ?name) (phase done))
   ?st <- (stack (states ?name $?rest))
   =>
   (retract ?s)
   (retract ?st)

   (if (> (length$ $?rest) 0) then
      (bind ?next (nth$ 1 $?rest))

      (assert (stack (states $?rest)))
      (assert (plan-note (robot Justina) (state ?next)))
      (assert (state (name ?next) (phase 1)))
    else
      (assert (plan-note (robot Justina) (state PLAN_FINISHED)))
   )
)