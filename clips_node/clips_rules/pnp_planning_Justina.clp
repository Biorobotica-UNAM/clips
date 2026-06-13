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
         (case 3 then (bind ?action say)   (bind $?params (create$ going_to_kitchen_table)))
         (case 4 then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 5 then (bind ?action say)   (bind $?params (create$ reached_kitchen_table)))
         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_TABLEWARE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_TABLEWARE) then
      (switch ?p 
         (case 1  then (bind ?action say)   (bind $?params (create$ clean_tableware)))
         (case 2  then (bind ?action align) (bind $?params (create$ table)))
         (case 3  then (bind ?action say)   (bind $?params (create$ search_tableware)))
         (case 4  then (bind ?action find_object)  (bind $?params (create$ tableware_1)))
         (case 5  then (bind ?action say)   (bind $?params (create$ acknowledge_tableware_1)))
         (case 6  then (bind ?action take)  (bind $?params (create$ tableware_1)))
         (case 7  then (bind ?action say)   (bind $?params (create$ search_tableware)))
         (case 8  then (bind ?action find_object)  (bind $?params (create$ tableware_2)))
         (case 9  then (bind ?action say)   (bind $?params (create$ acknowledge_tableware_2)))
         (case 10 then (bind ?action take)  (bind $?params (create$ tableware_2)))
         (case 11  then (bind ?action say)   (bind $?params (create$ move_tableware_to_dishwasher)))
         (case 12 then (bind ?action say)   (bind $?params (create$ going_to_dishwasher)))
         (case 13 then (bind ?action go_to)  (bind $?params (create$ dishwasher)))
         (case 14 then (bind ?action say)   (bind $?params (create$ reached_dishwasher)))
         (case 15 then (bind ?action say)   (bind $?params (create$ request_open_dishwasher_door)))
         (case 16 then (bind ?action check) (bind $?params (create$ dishwasher_door)))
         (case 17 then (bind ?action align) (bind $?params (create$ dishwasher)))
         (case 18 then (bind ?action drop)  (bind $?params (create$ tableware_1)))
         (case 19 then (bind ?action drop)  (bind $?params (create$ tableware_2)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_CUTLERY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_CUTLERY) then
      (switch ?p
         (case 1  then (bind ?action say)   (bind $?params (create$ clean_cutlery)))
         (case 2  then (bind ?action say)   (bind $?params (create$ going_to_kitchen_table)))
         (case 3  then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 4  then (bind ?action say)   (bind $?params (create$ reached_kitchen_table)))
         (case 5  then (bind ?action align) (bind $?params (create$ table)))
         (case 6  then (bind ?action say)   (bind $?params (create$ search_cutlery)))
         (case 7  then (bind ?action find_object)  (bind $?params (create$ cutlery_1)))
         (case 8  then (bind ?action say)   (bind $?params (create$ acknowledge_cutlery_1)))
         (case 9  then (bind ?action take)  (bind $?params (create$ cutlery_1)))
         (case 10 then (bind ?action say)   (bind $?params (create$ move_cutlery_to_dishwasher)))
         (case 11 then (bind ?action say)   (bind $?params (create$ going_to_dishwasher)))
         (case 12 then (bind ?action go_to)  (bind $?params (create$ dishwasher)))
         (case 13 then (bind ?action say)   (bind $?params (create$ reached_dishwasher)))
         (case 14 then (bind ?action say)   (bind $?params (create$ request_open_dishwasher_door)))
         (case 15 then (bind ?action check) (bind $?params (create$ dishwasher_door)))
         (case 16 then (bind ?action align) (bind $?params (create$ dishwasher)))
         (case 17 then (bind ?action drop)  (bind $?params (create$ cutlery_1)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_TRASH
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_TRASH) then
      (switch ?p 
         (case 1  then (bind ?action say)   (bind $?params (create$ clean_trash)))
         (case 2  then (bind ?action say)   (bind $?params (create$ going_to_kitchen_table)))
         (case 3  then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 4  then (bind ?action say)   (bind $?params (create$ reached_kitchen_table)))
         (case 5  then (bind ?action align) (bind $?params (create$ table)))
         (case 6  then (bind ?action say)   (bind $?params (create$ search_trash)))
         (case 7  then (bind ?action find_object)  (bind $?params (create$ trash_1)))
         (case 8  then (bind ?action say)   (bind $?params (create$ acknowledge_trash_1)))
         (case 9  then (bind ?action take)  (bind $?params (create$ trash_1)))
         (case 10 then (bind ?action say)   (bind $?params (create$ move_to_trash_bin)))
         (case 11 then (bind ?action say)   (bind $?params (create$ going_to_trash_bin)))
         (case 12 then (bind ?action go_to)  (bind $?params (create$ trash_bin)))
         (case 13 then (bind ?action say)   (bind $?params (create$ reached_trash_bin)))
         (case 14 then (bind ?action align) (bind $?params (create$ trash_bin)))
         (case 15 then (bind ?action drop)  (bind $?params (create$ trash_1)))
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
         (case 2  then (bind ?action say)   (bind $?params (create$ going_to_kitchen_table)))
         (case 3  then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 4  then (bind ?action say)   (bind $?params (create$ reached_kitchen_table)))
         (case 5  then (bind ?action align) (bind $?params (create$ table)))
         (case 6  then (bind ?action say)   (bind $?params (create$ search_grocery)))
         (case 7  then (bind ?action find_object)  (bind $?params (create$ grocery_1)))
         (case 8  then (bind ?action say)   (bind $?params (create$ acknowledge_grocery_1)))
         (case 9  then (bind ?action take)  (bind $?params (create$ grocery_1)))
         (case 10 then (bind ?action say)   (bind $?params (create$ search_grocery)))
         (case 11 then (bind ?action find_object)  (bind $?params (create$ grocery_2)))
         (case 12 then (bind ?action say)   (bind $?params (create$ acknowledge_grocery_2)))
         (case 13 then (bind ?action take)  (bind $?params (create$ grocery_2)))
         (case 14 then (bind ?action say)   (bind $?params (create$ move_to_cabinet)))
         (case 15 then (bind ?action say)   (bind $?params (create$ going_to_cabinet)))
         (case 16 then (bind ?action go_to)  (bind $?params (create$ cabinet)))
         (case 17 then (bind ?action say)   (bind $?params (create$ reached_cabinet)))
         (case 18 then (bind ?action align) (bind $?params (create$ cabinet)))
         (case 19 then (bind ?action drop)  (bind $?params (create$ grocery_1)))
         (case 20 then (bind ?action drop)  (bind $?params (create$ grocery_2)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SERVE_BREAKFAST
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name SERVE_BREAKFAST) then
      (switch ?p 
         (case 1  then (bind ?action say)   (bind $?params (create$ prepare_breakfast)))
         (case 2  then (bind ?action align) (bind $?params (create$ cabinet)))
         (case 3  then (bind ?action say)   (bind $?params (create$ search_breakfast_milk)))
         (case 4  then (bind ?action find_object)  (bind $?params (create$ milk)))
         (case 5  then (bind ?action say)   (bind $?params (create$ acknowledge_breakfast_milk)))
         (case 6  then (bind ?action take)  (bind $?params (create$ milk)))
         (case 7  then (bind ?action say)   (bind $?params (create$ search_breakfast_cereal)))
         (case 8  then (bind ?action find_object)  (bind $?params (create$ cereal)))
         (case 9  then (bind ?action say)   (bind $?params (create$ acknowledge_breakfast_cereal)))
         (case 10 then (bind ?action take)  (bind $?params (create$ cereal)))
         (case 11 then (bind ?action say)   (bind $?params (create$ move_breakfast_items_to_table)))
         (case 12 then (bind ?action say)   (bind $?params (create$ going_to_kitchen_table)))
         (case 13 then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 14  then (bind ?action say)   (bind $?params (create$ reached_kitchen_table)))
         (case 15 then (bind ?action align) (bind $?params (create$ table)))
         (case 16 then (bind ?action drop)  (bind $?params (create$ milk)))
         (case 17 then (bind ?action drop)  (bind $?params (create$ cereal)))
         (case 18 then (bind ?action say)   (bind $?params (create$ going_to_breakfast_bar)))
         (case 19 then (bind ?action go_to)  (bind $?params (create$ breakfast_bar)))
         (case 20 then (bind ?action say)   (bind $?params (create$ reached_breakfast_bar)))
         (case 21 then (bind ?action align) (bind $?params (create$ breakfast_bar)))
         (case 22 then (bind ?action say)   (bind $?params (create$ search_breakfast_bowl)))
         (case 23 then (bind ?action find_object)  (bind $?params (create$ bowl)))
         (case 24 then (bind ?action say)   (bind $?params (create$ acknowledge_breakfast_bowl)))
         (case 25 then (bind ?action take)  (bind $?params (create$ bowl)))
         (case 26  then (bind ?action say)   (bind $?params (create$ search_breakfast_spoon)))
         (case 27 then (bind ?action find_object)  (bind $?params (create$ spoon)))
         (case 28 then (bind ?action say)   (bind $?params (create$ acknowledge_breakfast_spoon)))
         (case 29 then (bind ?action take)  (bind $?params (create$ spoon)))
         (case 30 then (bind ?action say)   (bind $?params (create$ move_breakfast_items_to_table)))
         (case 31 then (bind ?action say)   (bind $?params (create$ going_to_kitchen_table)))
         (case 32 then (bind ?action go_to)  (bind $?params (create$ kitchen_table)))
         (case 33 then (bind ?action say)   (bind $?params (create$ reached_kitchen_table)))
         (case 34 then (bind ?action align) (bind $?params (create$ table)))
         (case 35 then (bind ?action drop)  (bind $?params (create$ bowl)))
         (case 36 then (bind ?action drop)  (bind $?params (create$ spoon)))

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
