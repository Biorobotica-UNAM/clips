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
      START_LAUNDRY
      NAVIGATE_TO_LAUNDRY
      RETRIEVE_CLOTHES
      MOVE_BASKET
      FOLD_CLOTHES
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
       (bind ?next-phase done))

   (if (eq ?name NAVIGATE_TO_LAUNDRY) then
      (switch ?p
         (case 1 then (bind ?action check) (bind $?params (create$ door)))
         (case 2 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_machine)))
         (case 3 then (bind ?action goto) (bind $?params (create$ laundry_machine)))
         (case 4 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_machine)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name RETRIEVE_CLOTHES) then
      (switch ?p
         (case 1 then (bind ?action say)   (bind $?params (create$ ask_open machine_door)))
         (case 2 then (bind ?action check) (bind $?params (create$ laundry_door)))
         (case 3 then (bind ?action align) (bind $?params (create$ laundry_machine)))

         (case 4 then (bind ?action find)  (bind $?params (create$ object_shirt_1)))
         (case 5 then (bind ?action take)  (bind $?params (create$ object_shirt_1)))
         (case 6 then (bind ?action find)  (bind $?params (create$ object_shirt_2)))
         (case 7 then (bind ?action take)  (bind $?params (create$ object_shirt_2)))

         (case 8 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_basket)))
         (case 9 then (bind ?action goto)  (bind $?params (create$ laundry_basket)))
         (case 10 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_basket)))
         (case 11 then (bind ?action align) (bind $?params (create$ laundry_basket)))
         (case 12 then (bind ?action drop) (bind $?params (create$ shirt_1)))
         (case 13 then (bind ?action drop) (bind $?params (create$ shirt_2)))

         (case 14 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_machine)))
         (case 15 then (bind ?action goto) (bind $?params (create$ laundry_machine)))
         (case 16 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_machine)))
         (case 17 then (bind ?action align) (bind $?params (create$ laundry_machine)))

         (case 18 then (bind ?action find) (bind $?params (create$ object_shirt_3)))
         (case 19 then (bind ?action take) (bind $?params (create$ object_shirt_3)))
         (case 20 then (bind ?action find) (bind $?params (create$ object_shirt_4)))
         (case 21 then (bind ?action take) (bind $?params (create$ shirt_4)))

         (case 22 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_basket)))
         (case 23 then (bind ?action goto) (bind $?params (create$ laundry_basket)))
         (case 24 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_basket)))
         (case 25 then (bind ?action align) (bind $?params (create$ laundry_basket)))
         (case 26 then (bind ?action drop) (bind $?params (create$ shirt_3)))
         (case 27 then (bind ?action drop) (bind $?params (create$ shirt_4)))

         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name MOVE_BASKET) then
      (switch ?p
         (case 1 then (bind ?action find) (bind $?params (create$ object_basket_handles)))
         (case 2 then (bind ?action take) (bind $?params (create$ basket_handles)))
         (case 3 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 4 then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 5 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 6 then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 7 then (bind ?action drop) (bind $?params (create$ laundry_table_floor)))
         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name FOLD_CLOTHES) then
      (switch ?p

         ;; SHIRT 1
         (case 1  then (bind ?action find) (bind $?params (create$ object_shirt_1)))
         (case 2  then (bind ?action take) (bind $?params (create$ shirt_1)))
         (case 3  then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 4  then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 5  then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 6  then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 7  then (bind ?action drop) (bind $?params (create$ laundry_table)))
         (case 8  then (bind ?action fold) (bind $?params (create$ shirt_1)))
         (case 9  then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table_floor)))
         (case 10 then (bind ?action goto) (bind $?params (create$ laundry_table_floor)))
         (case 11 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table_floor)))

         ;; SHIRT 2
         (case 12 then (bind ?action find) (bind $?params (create$ object_shirt_2)))
         (case 13 then (bind ?action take) (bind $?params (create$ shirt_2)))
         (case 14 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 15 then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 16 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 17 then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 18 then (bind ?action drop) (bind $?params (create$ laundry_table)))
         (case 19 then (bind ?action fold) (bind $?params (create$ shirt_2)))
         (case 20 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table_floor)))
         (case 21 then (bind ?action goto) (bind $?params (create$ laundry_table_floor)))
         (case 22 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table_floor)))

         ;; SHIRT 3
         (case 23 then (bind ?action find) (bind $?params (create$ object_shirt_3)))
         (case 24 then (bind ?action take) (bind $?params (create$ shirt_3)))
         (case 25 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 26 then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 27 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 28 then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 29 then (bind ?action drop) (bind $?params (create$ laundry_table)))
         (case 30 then (bind ?action fold) (bind $?params (create$ shirt_3)))
         (case 31 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table_floor)))
         (case 32 then (bind ?action goto) (bind $?params (create$ laundry_table_floor)))
         (case 33 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table_floor)))

         ;; SHIRT 4
         (case 34 then (bind ?action find) (bind $?params (create$ object_shirt_4)))
         (case 35 then (bind ?action take) (bind $?params (create$ shirt_4)))
         (case 36 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 37 then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 38 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 39 then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 40 then (bind ?action drop) (bind $?params (create$ laundry_table)))
         (case 41 then (bind ?action fold) (bind $?params (create$ shirt_4)))
         (case 42 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table_floor)))
         (case 43 then (bind ?action goto) (bind $?params (create$ laundry_table_floor)))
         (case 44 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table_floor)))

         ;; SHIRT 5
         (case 45 then (bind ?action find) (bind $?params (create$ object_shirt_5)))
         (case 46 then (bind ?action take) (bind $?params (create$ shirt_5)))
         (case 47 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 48 then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 49 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 50 then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 51 then (bind ?action drop) (bind $?params (create$ laundry_table)))
         (case 52 then (bind ?action fold) (bind $?params (create$ shirt_5)))
         (case 53 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table_floor)))
         (case 54 then (bind ?action goto) (bind $?params (create$ laundry_table_floor)))
         (case 55 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table_floor)))

         ;; SHIRT 6
         (case 56 then (bind ?action find) (bind $?params (create$ object_shirt_6)))
         (case 57 then (bind ?action take) (bind $?params (create$ shirt_6)))
         (case 58 then (bind ?action say) (bind $?params (create$ announce_nav_laundry_table)))
         (case 59 then (bind ?action goto) (bind $?params (create$ laundry_table)))
         (case 60 then (bind ?action say) (bind $?params (create$ announce_nav_end_laundry_table)))
         (case 61 then (bind ?action align) (bind $?params (create$ laundry_table)))
         (case 62 then (bind ?action drop) (bind $?params (create$ laundry_table)))
         (case 63 then (bind ?action fold) (bind $?params (create$ shirt_6)))

         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINISH_LAUNDRY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name FINISH_LAUNDRY) (eq ?p 1)) then
       (bind ?action say)
       (bind $?params (create$ finish_laundry))
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