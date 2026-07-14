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
   ?s <- (start (name action-planning))
   =>
   (retract ?s)

   (assert (plan-control (step 1)))

   (assert
      (stack
         (states
            START_PNP
            NAVIGATE_TO_KITCHEN
            CLEAN_TABLEWARE
            CLEAN_CUTLERY
            CLEAN_TRASH
            ORGANIZE_PANTRY
            SERVE_BREAKFAST
            FINISH_PNP
         )
      )
   )

   (assert (plan-note (robot Justina) (state START_PNP)))
   (assert (state (name START_PNP) (phase 1)))
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
;; START_PNP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name START_PNP) (eq ?p 1)) then
      (bind ?action say)
      (bind $?params (create$ start_pnp))
      (bind ?next-phase done)
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NAVIGATE_TO_KITCHEN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name NAVIGATE_TO_KITCHEN) then
      (switch ?p 
         (case 1 then (bind ?action say)   (bind $?params (create$ request_open_door)))
         (case 2 then (bind ?action check) (bind $?params (create$ door)))
         (case 3 then (bind ?action say) (bind $?params (create$ Watch out. I will move forward)))
         (case 4 then (bind ?action save_loc) (bind $?params (create$ kitchen_bar)))
         (case 5 then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_TABLEWARE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_TABLEWARE) then
      (switch ?p 
         (case 1  then (bind ?action align) (bind $?params (create$ round)))
         (case 2  then (bind ?action find_object)  (bind $?params (create$ tableware_1)))
         (case 3  then (bind ?action find_object)  (bind $?params (create$ tableware_2)))
         (case 4  then (bind ?action find_object)  (bind $?params (create$ cutlery_1)))
         (case 5  then (bind ?action find_object)  (bind $?params (create$ trash_1)))
         (case 6  then (bind ?action take)  (bind $?params (create$ trash_1)))
         (case 7 then (bind ?action go_to)  (bind $?params (create$ kitchen_trash_bin)))
         (case 8 then (bind ?action find_space)  (bind $?params (create$ container_down)))
         (case 9 then (bind ?action drop)  (bind $?params (create$ trash_1)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ORGANIZE_PANTRY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name ORGANIZE_PANTRY) then
      (switch ?p 
         (case 1  then (bind ?action say)   (bind $?params (create$ organize_groceries)))
         (case 2  then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 3  then (bind ?action align) (bind $?params (create$ round)))
         (case 4  then (bind ?action find_object)  (bind $?params (create$ groceries_1)))
         (case 5  then (bind ?action find_object)  (bind $?params (create$ groceries_2)))
         (case 6 then (bind ?action go_to)  (bind $?params (create$ cabinet)))
         (case 7 then (bind ?action align) (bind $?params (create$ table)))
         (case 8 then (bind ?action find_space)  (bind $?params (create$ shelf_2)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINISH_PNP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name FINISH_PNP) (eq ?p 1)) then
      (bind ?action say)
      (bind $?params (create$ finish_pnp))
      (bind ?next-phase done)
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EXECUTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (neq ?action none) then
      (assert
         (ros-message
            (step ?n)
            (robot Justina)
            (action ?action)
            (params $?params)
         )
      )
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
   ?s  <- (state (name ?name) (phase done))
   ?st <- (stack (states $?all))
   =>
   (retract ?s)
   (retract ?st)

   (bind $?rest (rest$ $?all))

   (if (> (length$ $?rest) 0) then
      (bind ?next (nth$ 1 $?rest))

      (assert (stack (states $?rest)))
      (assert (plan-note (robot Justina) (state ?next)))
      (assert (state (name ?next) (phase 1)))
   )
)
