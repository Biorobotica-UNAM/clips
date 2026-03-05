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
      START_RESTAURANT
      SAVE_STARTING_LOCATION
      TAKE_COSTUMER_1_ORDER
      TAKE_COSTUMER_2_ORDER
      FINISH_RESTAURANT)))

   (assert (plan-note (robot Justina) (state START_RESTAURANT)))

   (assert (state (name START_RESTAURANT) (phase 1)))
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
;; START_RESTAURANT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name START_RESTAURANT) (eq ?p 1)) then
       (bind ?action say)
       (bind $?params (create$ start_restaurant))
       (bind ?next-phase done))

   (if (and (eq ?name SAVE_STARTING_LOCATION) (eq ?p 1)) then
       (bind ?action save)
       (bind $?params (create$ kitchen_bar))
       (bind ?next-phase done))

   (if (eq ?name TAKE_COSTUMER_1_ORDER) then
      (switch ?p
         ;; acercarse al cliente
         (case 1 then (bind ?action find) (bind $?params (create$ calling_costumer)))
         (case 2 then (bind ?action approach) (bind $?params (create$ calling_costumer)))
         (case 3 then (bind ?action save) (bind $?params (create$ costumer_1)))
         (case 4 then (bind ?action say) (bind $?params (create$ introduce_waitress)))
         (case 5 then (bind ?action listen) (bind $?params (create$ order_1)))
         (case 6 then (bind ?action save) (bind $?params (create$ order_1)))
         (case 7 then (bind ?action say) (bind $?params (create$ confirm_order order_1)))
         (case 8 then (bind ?action listen) (bind $?params (create$ yes)))

         ;; ir a barra
         (case 9 then (bind ?action say) (bind $?params (create$ announce_nav_kitchen_bar)))
         (case 10  then (bind ?action goto) (bind $?params (create$ kitchen_bar)))
         (case 11 then (bind ?action say) (bind $?params (create$ announce_nav_end_kitchen_bar)))
         (case 12 then (bind ?action align) (bind $?params (create$ kitchen_bar)))
         (case 13 then (bind ?action find) (bind $?params (create$ barman)))
         (case 14 then (bind ?action say) (bind $?params (create$ send_order order_1)))

         ;; recoger bebidas/comida
         (case 15 then (bind ?action find) (bind $?params (create$ {order_1[0]})))
         (case 16 then (bind ?action take) (bind $?params (create$ {order_1[0]})))
         (case 17 then (bind ?action find) (bind $?params (create$ {order_1[1]})))
         (case 18 then (bind ?action take) (bind $?params (create$ {order_1[1]})))

         (case 19 then (bind ?action find) (bind $?params (create$ tray)))
         (case 20 then (bind ?action align) (bind $?params (create$ tray)))
         (case 21 then (bind ?action drop) (bind $?params (create$ tray)))

         (case 22 then (bind ?action say) (bind $?params (create$ announce_nav_kitchen_bar)))
         (case 23 then (bind ?action goto) (bind $?params (create$ kitchen_bar)))
         (case 24 then (bind ?action say) (bind $?params (create$ announce_nav_end_kitchen_bar)))
         (case 25 then (bind ?action align) (bind $?params (create$ kitchen_bar)))

         (case 26 then (bind ?action find) (bind $?params (create$ {order_1[2]})))
         (case 27 then (bind ?action take) (bind $?params (create$ {order_1[2]})))
         (case 28 then (bind ?action align) (bind $?params (create$ tray)))
         (case 29 then (bind ?action drop) (bind $?params (create$ tray)))
         (case 30 then (bind ?action take) (bind $?params (create$ tray)))

         ;; servir en mesa
         (case 31 then (bind ?action say) (bind $?params (create$ announce_nav_costumer_1)))
         (case 32 then (bind ?action goto) (bind $?params (create$ costumer_1)))
         (case 33 then (bind ?action say) (bind $?params (create$ announce_nav_end_costumer_1)))
         (case 34 then (bind ?action align) (bind $?params (create$ table)))
         (case 35 then (bind ?action find) (bind $?params (create$ restaurant_table_drops)))
         (case 36 then (bind ?action drop) (bind $?params (create$ table)))

         (case 37 then (bind ?action find) (bind $?params (create$ {order_1[0]})))
         (case 38 then (bind ?action take) (bind $?params (create$ {order_1[0]})))
         (case 39 then (bind ?action drop) (bind $?params (create$ restaurant_table_drop_0)))

         (case 40 then (bind ?action find) (bind $?params (create$ {order_1[1]})))
         (case 41 then (bind ?action take) (bind $?params (create$ {order_1[1]})))
         (case 42 then (bind ?action drop) (bind $?params (create$ restaurant_table_drop_1)))

         (case 43 then (bind ?action find) (bind $?params (create$ {order_1[2]})))
         (case 44 then (bind ?action take) (bind $?params (create$ {order_1[2]})))
         (case 45 then (bind ?action drop) (bind $?params (create$ restaurant_table_drop_2)))

         (default (bind ?next-phase done))
      )
   )

   (if (eq ?name TAKE_COSTUMER_2_ORDER) then
      (switch ?p
         (case 1 then (bind ?action find) (bind $?params (create$ calling_costumer)))
         (case 2 then (bind ?action approach) (bind $?params (create$ calling_costumer)))
         (case 3 then (bind ?action save) (bind $?params (create$ costumer_2)))
         (case 4 then (bind ?action say) (bind $?params (create$ introduce_waitress)))
         (case 5 then (bind ?action listen) (bind $?params (create$ order_2)))
         (case 6 then (bind ?action save) (bind $?params (create$ order_2)))
         (case 7 then (bind ?action say) (bind $?params (create$ confirm_order order_2)))
         (case 8 then (bind ?action listen) (bind $?params (create$ yes)))

         (case 9 then (bind ?action say) (bind $?params (create$ announce_nav_kitchen_bar)))
         (case 10  then (bind ?action goto) (bind $?params (create$ kitchen_bar)))
         (case 11 then (bind ?action say) (bind $?params (create$ announce_nav_end_kitchen_bar)))
         (case 12 then (bind ?action align) (bind $?params (create$ kitchen_bar)))
         (case 13 then (bind ?action find) (bind $?params (create$ barman)))
         (case 14 then (bind ?action say) (bind $?params (create$ send_order order_2)))

         (case 15 then (bind ?action find) (bind $?params (create$ {order_2[0]})))
         (case 16 then (bind ?action take) (bind $?params (create$ {order_2[0]})))
         (case 17 then (bind ?action find) (bind $?params (create$ {order_2[1]})))
         (case 18 then (bind ?action take) (bind $?params (create$ {order_2[1]})))

         (case 19 then (bind ?action find) (bind $?params (create$ tray)))
         (case 20 then (bind ?action align) (bind $?params (create$ tray)))
         (case 21 then (bind ?action drop) (bind $?params (create$ tray)))

         (case 22 then (bind ?action say) (bind $?params (create$ announce_nav_kitchen_bar)))
         (case 23  then (bind ?action goto) (bind $?params (create$ kitchen_bar)))
         (case 24 then (bind ?action say) (bind $?params (create$ announce_nav_end_kitchen_bar)))
         (case 25 then (bind ?action align) (bind $?params (create$ kitchen_bar)))

         (case 26 then (bind ?action find) (bind $?params (create$ {order_2[2]})))
         (case 27 then (bind ?action take) (bind $?params (create$ {order_2[2]})))
         (case 28 then (bind ?action align) (bind $?params (create$ tray)))
         (case 29 then (bind ?action drop) (bind $?params (create$ tray)))
         (case 30 then (bind ?action take) (bind $?params (create$ tray)))

         (case 31 then (bind ?action say) (bind $?params (create$ announce_nav_costumer_2)))
         (case 32 then (bind ?action goto) (bind $?params (create$ costumer_2)))
         (case 33 then (bind ?action say) (bind $?params (create$ announce_nav_end_costumer_2)))
         (case 34 then (bind ?action align) (bind $?params (create$ table)))
         (case 35 then (bind ?action find) (bind $?params (create$ restaurant_table_drops)))
         (case 36 then (bind ?action drop) (bind $?params (create$ table)))

         (case 37 then (bind ?action find) (bind $?params (create$ {order_2[0]})))
         (case 38 then (bind ?action take) (bind $?params (create$ {order_2[0]})))
         (case 39 then (bind ?action drop) (bind $?params (create$ restaurant_table_drop_0)))

         (case 40 then (bind ?action find) (bind $?params (create$ {order_2[1]})))
         (case 41 then (bind ?action take) (bind $?params (create$ {order_2[1]})))
         (case 42 then (bind ?action drop) (bind $?params (create$ restaurant_table_drop_1)))

         (case 43 then (bind ?action find) (bind $?params (create$ {order_2[2]})))
         (case 44 then (bind ?action take) (bind $?params (create$ {order_2[2]})))
         (case 45 then (bind ?action drop) (bind $?params (create$ restaurant_table_drop_2)))

         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINISH_RESTAURANT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name FINISH_RESTAURANT) (eq ?p 1)) then
       (bind ?action say)
       (bind $?params (create$ finish_restaurant))
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

