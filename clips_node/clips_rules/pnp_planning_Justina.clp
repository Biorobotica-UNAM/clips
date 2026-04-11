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
      (switch ?p do
         (case 1 then (bind ?action say)   (bind $?params (create$ ask_open_door)))
         (case 2 then (bind ?action check) (bind $?params (create$ door)))
         (case 3 then (bind ?action say)   (bind $?params (create$ announce_nav_kitchen_table)))
         (case 4 then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 5 then (bind ?action say)   (bind $?params (create$ announce_nav_end_kitchen_table)))
         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_TABLEWARE
;; Primero mueve tableware usando ambos brazos en un solo viaje
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_TABLEWARE) then
      (switch ?p do
         (case 1  then (bind ?action say)   (bind $?params (create$ clean_tableware)))
         (case 2  then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 3  then (bind ?action align) (bind $?params (create$ table)))

         (case 4  then (bind ?action find)  (bind $?params (create$ object_tableware_1)))
         (case 5  then (bind ?action save)  (bind $?params (create$ tableware_1)))
         (case 6  then (bind ?action say)   (bind $?params (create$ identify_object_tableware_1)))
         (case 7  then (bind ?action take)  (bind $?params (create$ left_tableware_1)))

         (case 8  then (bind ?action find)  (bind $?params (create$ object_tableware_2)))
         (case 9  then (bind ?action save)  (bind $?params (create$ tableware_2)))
         (case 10 then (bind ?action say)   (bind $?params (create$ identify_object_tableware_2)))
         (case 11 then (bind ?action take)  (bind $?params (create$ right_tableware_2)))

         (case 12 then (bind ?action say)   (bind $?params (create$ move_tableware_dishwasher)))
         (case 13 then (bind ?action goto)  (bind $?params (create$ dishwasher)))
         (case 14 then (bind ?action say)   (bind $?params (create$ ask_open_dishwasher_door)))
         (case 15 then (bind ?action check) (bind $?params (create$ dishwasher_door)))
         (case 16 then (bind ?action align) (bind $?params (create$ dishwasher)))
         (case 17 then (bind ?action drop)  (bind $?params (create$ left_dishwasher)))
         (case 18 then (bind ?action drop)  (bind $?params (create$ right_dishwasher)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_CUTLERY
;; Al final y en viaje separado porque es más delicado
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_CUTLERY) then
      (switch ?p do
         (case 1  then (bind ?action say)   (bind $?params (create$ clean_cutlery)))
         (case 2  then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 3  then (bind ?action align) (bind $?params (create$ table)))
         (case 4  then (bind ?action find)  (bind $?params (create$ object_cutlery)))
         (case 5  then (bind ?action save)  (bind $?params (create$ cutlery)))
         (case 6  then (bind ?action say)   (bind $?params (create$ identify_object_cutlery)))
         (case 7  then (bind ?action take)  (bind $?params (create$ left_cutlery)))
         (case 8  then (bind ?action say)   (bind $?params (create$ move_cutlery_dishwasher)))
         (case 9  then (bind ?action goto)  (bind $?params (create$ dishwasher)))
         (case 10 then (bind ?action say)   (bind $?params (create$ ask_open_dishwasher_door)))
         (case 11 then (bind ?action check) (bind $?params (create$ dishwasher_door)))
         (case 12 then (bind ?action align) (bind $?params (create$ dishwasher)))
         (case 13 then (bind ?action drop)  (bind $?params (create$ left_dishwasher)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLEAN_TRASH
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name CLEAN_TRASH) then
      (switch ?p do
         (case 1  then (bind ?action say)   (bind $?params (create$ clean_trash)))
         (case 2  then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 3  then (bind ?action align) (bind $?params (create$ table)))
         (case 4  then (bind ?action find)  (bind $?params (create$ object_trash)))
         (case 5  then (bind ?action save)  (bind $?params (create$ trash)))
         (case 6  then (bind ?action say)   (bind $?params (create$ identify_object_trash)))
         (case 7  then (bind ?action take)  (bind $?params (create$ left_trash)))
         (case 8  then (bind ?action say)   (bind $?params (create$ move_trash_trash_bin)))
         (case 9  then (bind ?action goto)  (bind $?params (create$ trash_bin)))
         (case 10 then (bind ?action align) (bind $?params (create$ trash_bin)))
         (case 11 then (bind ?action drop)  (bind $?params (create$ left_trash_bin)))
         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ORGANIZE_PANTRY
;; Usa ambos brazos para category_1 y category_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name ORGANIZE_PANTRY) then
      (switch ?p do
         (case 1  then (bind ?action say)   (bind $?params (create$ organize_groseries)))
         (case 2  then (bind ?action say)   (bind $?params (create$ organize_others)))
         (case 3  then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 4  then (bind ?action align) (bind $?params (create$ table)))

         (case 5  then (bind ?action find)  (bind $?params (create$ category_1)))
         (case 6  then (bind ?action save)  (bind $?params (create$ category_1)))
         (case 7  then (bind ?action say)   (bind $?params (create$ identify_object_category_1)))
         (case 8  then (bind ?action take)  (bind $?params (create$ left_category_1)))

         (case 9  then (bind ?action find)  (bind $?params (create$ category_2)))
         (case 10 then (bind ?action save)  (bind $?params (create$ category_2)))
         (case 11 then (bind ?action say)   (bind $?params (create$ identify_object_category_2)))
         (case 12 then (bind ?action take)  (bind $?params (create$ right_category_2)))

         (case 13 then (bind ?action say)   (bind $?params (create$ move_category_1_cabinet)))
         (case 14 then (bind ?action say)   (bind $?params (create$ move_category_2_cabinet)))
         (case 15 then (bind ?action goto)  (bind $?params (create$ cabinet)))
         (case 16 then (bind ?action align) (bind $?params (create$ cabinet)))

         (case 17 then (bind ?action find)  (bind $?params (create$ category_1)))
         (case 18 then (bind ?action save)  (bind $?params (create$ category_1)))
         (case 19 then (bind ?action drop)  (bind $?params (create$ left_category_1)))

         (case 20 then (bind ?action find)  (bind $?params (create$ category_2)))
         (case 21 then (bind ?action save)  (bind $?params (create$ category_2)))
         (case 22 then (bind ?action drop)  (bind $?params (create$ right_category_2)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SERVE_BREAKFAST
;; Usa ambos brazos:
;; - cabinet -> kitchen_table : milk + cereal
;; - breakfast_bar -> kitchen_table : bowl + spoon
;; Manteniendo los mismos nombres de "say" del plan original
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name SERVE_BREAKFAST) then
      (switch ?p do
         (case 1  then (bind ?action align) (bind $?params (create$ cabinet)))

         (case 2  then (bind ?action find)  (bind $?params (create$ object_milk)))
         (case 3  then (bind ?action save)  (bind $?params (create$ milk)))
         (case 4  then (bind ?action say)   (bind $?params (create$ identify_object_milk)))
         (case 5  then (bind ?action take)  (bind $?params (create$ left_milk)))

         (case 6  then (bind ?action say)   (bind $?params (create$ return_cabinet_cereal)))
         (case 7  then (bind ?action find)  (bind $?params (create$ object_cereal)))
         (case 8  then (bind ?action save)  (bind $?params (create$ cereal)))
         (case 9  then (bind ?action say)   (bind $?params (create$ identify_object_cereal)))
         (case 10 then (bind ?action take)  (bind $?params (create$ right_cereal)))

         (case 11 then (bind ?action say)   (bind $?params (create$ move_milk_kitchen_table)))
         (case 12 then (bind ?action say)   (bind $?params (create$ move_cereal_kitchen_table)))
         (case 13 then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 14 then (bind ?action align) (bind $?params (create$ table)))

         (case 15 then (bind ?action find)  (bind $?params (create$ object_milk_drop)))
         (case 16 then (bind ?action save)  (bind $?params (create$ table_3)))
         (case 17 then (bind ?action drop)  (bind $?params (create$ left_table_3)))

         (case 18 then (bind ?action find)  (bind $?params (create$ object_breakfast_table_drops)))
         (case 19 then (bind ?action save)  (bind $?params (create$ table_4)))
         (case 20 then (bind ?action drop)  (bind $?params (create$ right_table_4)))

         (case 21 then (bind ?action say)   (bind $?params (create$ announce_nav_breakfast_bar)))
         (case 22 then (bind ?action goto)  (bind $?params (create$ breakfast_bar)))
         (case 23 then (bind ?action align) (bind $?params (create$ breakfast_bar)))

         (case 24 then (bind ?action find)  (bind $?params (create$ object_bowl)))
         (case 25 then (bind ?action save)  (bind $?params (create$ bowl)))
         (case 26 then (bind ?action say)   (bind $?params (create$ identify_object_bowl)))
         (case 27 then (bind ?action take)  (bind $?params (create$ left_bowl)))

         (case 28 then (bind ?action say)   (bind $?params (create$ return_breakfast_bar_spoon)))
         (case 29 then (bind ?action find)  (bind $?params (create$ object_spoon)))
         (case 30 then (bind ?action save)  (bind $?params (create$ spoon)))
         (case 31 then (bind ?action say)   (bind $?params (create$ identify_object_spoon)))
         (case 32 then (bind ?action take)  (bind $?params (create$ right_spoon)))

         (case 33 then (bind ?action say)   (bind $?params (create$ move_bowl_kitchen_table)))
         (case 34 then (bind ?action say)   (bind $?params (create$ move_spoon_kitchen_table)))
         (case 35 then (bind ?action goto)  (bind $?params (create$ kitchen_table)))
         (case 36 then (bind ?action align) (bind $?params (create$ table)))

         (case 37 then (bind ?action find)  (bind $?params (create$ object_breakfast_table_drops)))
         (case 38 then (bind ?action save)  (bind $?params (create$ table_1)))
         (case 39 then (bind ?action drop)  (bind $?params (create$ left_table_1)))

         (case 40 then (bind ?action find)  (bind $?params (create$ object_breakfast_table_drops)))
         (case 41 then (bind ?action save)  (bind $?params (create$ table_2)))
         (case 42 then (bind ?action drop)  (bind $?params (create$ right_table_2)))

         (case 43 then (bind ?action open)  (bind $?params (create$ milk)))

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