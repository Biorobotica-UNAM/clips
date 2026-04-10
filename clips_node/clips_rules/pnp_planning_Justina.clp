;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TEMPLATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deftemplate start (slot name))

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

   (assert (stack (states
      START_PNP
      NAVIGATE_TO_KITCHEN
      CLEAN_TABLEWARE
      CLEAN_TRASH
      CLEAN_CUTLERY
      ORGANIZE_CATEGORY_1
      ORGANIZE_CATEGORY_2
      SERVE_BREAKFAST
      FINISH_PNP)))

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
       (bind ?next-phase done))

   (if (eq ?name NAVIGATE_TO_KITCHEN) then
      (switch ?p
         (case 1 then (bind ?action check) (bind $?params (create$ door)))
         (case 2 then (bind ?action say) (bind $?params (create$ announce_nav_kitchen_table)))
         (case 3 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 4 then (bind ?action say) (bind $?params (create$ announce_nav_end_kitchen_table)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name CLEAN_TABLEWARE) then
      (switch ?p

      ;TODO: Revisar que coincidan mismas llamadas con Takeshi, hacer revisar logica con Takeshi (esa está bien)
         (case 1 then (bind ?action say) (bind $?params (create$ clean_tableware)))
         (case 2 then (bind ?action align) (bind $?params (create$ table)))
         (case 3 then (bind ?action find) (bind $?params (create$ object_tableware_1)))
         (case 5 then (bind ?action say) (bind $?params (create$ identify_object_tableware_1)))
         (case 6 then (bind ?action take) (bind $?params (create$ left_tableware_1)))
         (case 7 then (bind ?action say) (bind $?params (create$ take_tableware_2)))
         (case 8 then (bind ?action find) (bind $?params (create$ object_tableware_2)))
         (case 9 then (bind ?action say) (bind $?params (create$ identify_object_tableware_2)))
         (case 10 then (bind ?action take) (bind $?params (create$ right_tableware_2)))
         (case 11 then (bind ?action say) (bind $?params (create$ move_tableware_dishwasher)))
         (case 12 then (bind ?action goto) (bind $?params (create$ dishwasher)))
         (case 13 then (bind ?action say) (bind $?params (create$ ask_open_dishwasher_door)))
         (case 14 then (bind ?action align) (bind $?params (create$ dishwasher)))
         (case 15 then (bind ?action drop) (bind $?params (create$ left_dishwasher)))
         (case 16 then (bind ?action drop) (bind $?params (create$ right_dishwasher)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name CLEAN_TRASH) then
      (switch ?p

         (case 1 then (bind ?action say) (bind $?params (create$ clean_trash)))
         (case 2 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 3 then (bind ?action align) (bind $?params (create$ table)))
         (case 4 then (bind ?action find) (bind $?params (create$ object_trash)))
         (case 5 then (bind ?action say) (bind $?params (create$ identify_object_trash)))
         (case 6 then (bind ?action take) (bind $?params (create$ left_trash)))
         (case 7 then (bind ?action say) (bind $?params (create$ move_trash_trash_bin)))
         (case 8 then (bind ?action goto) (bind $?params (create$ trash_bin)))
         (case 9 then (bind ?action align) (bind $?params (create$ trash_bin)))
         (case 10 then (bind ?action drop) (bind $?params (create$ left_trash)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name CLEAN_CUTLERY) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ clean_cutlery)))
         (case 2 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 3 then (bind ?action align) (bind $?params (create$ table)))
         (case 4 then (bind ?action find) (bind $?params (create$ object_cutlery)))
         (case 5 then (bind ?action save) (bind $?params (create$ cutlery)))
         (case 6 then (bind ?action say) (bind $?params (create$ identify_object_cutlery)))
         (case 7 then (bind ?action take) (bind $?params (create$ left_cutlery)))
         (case 8 then (bind ?action say) (bind $?params (create$ move_cutlery_dishwasher)))
         (case 9 then (bind ?action goto) (bind $?params (create$ dishwasher)))
         (case 10 then (bind ?action align) (bind $?params (create$ dishwasher)))
         (case 11 then (bind ?action drop) (bind $?params (create$ left_dishwasher)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name ORGANIZE_CATEGORY_1) then
      (switch ?p

         (case 1 then (bind ?action say) (bind $?params (create$ organize_groseries)))
         (case 2 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 3 then (bind ?action align) (bind $?params (create$ table)))
         (case 4 then (bind ?action find) (bind $?params (create$ category_1)))
         (case 5 then (bind ?action say) (bind $?params (create$ identify_object_category_1)))
         (case 6 then (bind ?action take) (bind $?params (create$ category_1)))
         (case 7 then (bind ?action say) (bind $?params (create$ move_category_1_cabinet)))
         (case 8 then (bind ?action goto) (bind $?params (create$ cabinet)))
         (case 9 then (bind ?action align) (bind $?params (create$ cabinet)))
         (case 10 then (bind ?action find) (bind $?params (create$ shelf_category_1)))
         (case 11 then (bind ?action drop) (bind $?params (create$ shelf_category_1)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name ORGANIZE_CATEGORY_2) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ organize_others)))
         (case 2 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 3 then (bind ?action align) (bind $?params (create$ table)))
         (case 4 then (bind ?action find) (bind $?params (create$ category_2)))
         (case 5 then (bind ?action say) (bind $?params (create$ identify_object_category_2)))
         (case 6 then (bind ?action take) (bind $?params (create$ category_2)))
         (case 7 then (bind ?action say) (bind $?params (create$ move_category_2_cabinet)))
         (case 8 then (bind ?action goto) (bind $?params (create$ cabinet)))
         (case 9 then (bind ?action align) (bind $?params (create$ cabinet)))
         (case 10 then (bind ?action find) (bind $?params (create$ shelf_category_2)))
         (case 11 then (bind ?action drop) (bind $?params (create$ shelf_category_2)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name SERVE_BREAKFAST) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ serve_breakfast)))
         (case 2 then (bind ?action goto) (bind $?params (create$ breakfast_bar)))
         (case 3 then (bind ?action align) (bind $?params (create$ breakfast_bar)))
         (case 4 then (bind ?action find) (bind $?params (create$ object_bowl)))
         (case 5 then (bind ?action say) (bind $?params (create$ identify_object_bowl)))
         (case 6 then (bind ?action take) (bind $?params (create$ bowl)))
         (case 7 then (bind ?action find) (bind $?params (create$ object_spoon)))
         (case 8 then (bind ?action say) (bind $?params (create$ identify_object_spoon)))
         (case 9 then (bind ?action take) (bind $?params (create$ spoon)))
         (case 10 then (bind ?action say) (bind $?params (create$ move_kitchen_table_bowl_spoon)))
         (case 11 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 12 then (bind ?action align) (bind $?params (create$ table)))
         (case 13 then (bind ?action find) (bind $?params (create$ object_breakfast_table_drops)))
         (case 14 then (bind ?action drop) (bind $?params (create$ table_1)))
         (case 15 then (bind ?action drop) (bind $?params (create$ table_2)))
         (case 16 then (bind ?action say) (bind $?params (create$ move_cabinet)))
         (case 17 then (bind ?action goto) (bind $?params (create$ cabinet)))
         (case 18 then (bind ?action align) (bind $?params (create$ cabinet)))
         (case 19 then (bind ?action find) (bind $?params (create$ object_milk)))
         (case 20 then (bind ?action say) (bind $?params (create$ identify_object_milk)))
         (case 21 then (bind ?action take) (bind $?params (create$ milk)))
         (case 22 then (bind ?action find) (bind $?params (create$ object_cereal)))
         (case 23 then (bind ?action say) (bind $?params (create$ identify_object_cereal)))
         (case 24 then (bind ?action take) (bind $?params (create$ cereal)))
         (case 25 then (bind ?action say) (bind $?params (create$ move_kitchen_table_milk_cereal)))
         (case 26 then (bind ?action goto) (bind $?params (create$ kitchen_table)))
         (case 27 then (bind ?action align) (bind $?params (create$ table)))
         (case 28 then (bind ?action drop) (bind $?params (create$ table_3)))
         (case 29 then (bind ?action drop) (bind $?params (create$ table_4)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINISH_PNP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name FINISH_PNP) (eq ?p 1)) then
       (bind ?action say)
       (bind $?params (create$ finish_pnp))
       (bind ?next-phase done))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EXECUTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (neq ?action none) then
      (assert (ros-message
                (robot Justina)
                (action ?action)
                (params $?params)
                (step ?n)))
      (modify ?pc (step (+ ?n 1)))
   )

   (if (eq ?next-phase done) then
      (modify ?s (phase done))
   else
       (modify ?s (phase ?next-phase)))

)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MOVE TO NEXT MACRO STATE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defrule next-macro
   ?s <- (state (name ?name) (phase done))
   ?st <- (stack (states $?all))
   =>
   (retract ?s)
   (retract ?st)

   (bind $?rest (rest$ $?all))

   (if (> (length$ $?rest) 0) then
      (bind ?next (nth$ 1 $?rest))

      (assert (stack (states $?rest)))

      ;; GENERAR NOTA DEL NUEVO ESTADO
      (assert (plan-note
                (robot Justina)
                (state ?next)))

      (assert (state (name ?next) (phase 1)))
   )
)
