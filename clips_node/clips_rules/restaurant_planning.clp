;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RESTAURANT TEST PLAN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
            START_RESTAURANT
            SAVE_INITIAL_POSITION
            FIND_WAVING_PERSON
            NAVIGATE_TO_PERSON
            TAKE_ORDER
            RETURN_TO_START
            REPORT_ORDER
            RETURN_TO_CUSTOMER_1
            FIND_WAVING_PERSON_2
            NAVIGATE_TO_PERSON_2
            TAKE_ORDER_2
            RETURN_TO_START
            REPORT_ORDER_2
            RETURN_TO_CUSTOMER_2
            RETURN_TO_START
            FINISH_RESTAURANT
         )
      )
   )

   (assert (plan-note (robot Justina) (state START_RESTAURANT)))
   (assert (state (name START_RESTAURANT) (phase 1)))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GENERIC STEP EXECUTION
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

   (if (eq ?name START_RESTAURANT) then
      (switch ?p

         (case 1 then (bind ?action say) (bind $?params (create$ start_restaurant)))
         
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SAVE_INITIAL_POSITION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name SAVE_INITIAL_POSITION) then	

      (switch ?p
         (case 1 then (bind ?action save_loc) (bind $?params (create$ initial_position)))
         (case 2 then (bind ?action save_loc) (bind $?params (create$ kitchen_bar)))

         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIND_WAVING_PERSON
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name FIND_WAVING_PERSON) then

      (switch ?p

         (case 1 then (bind ?action say) (bind $?params (create$ search_customer_1)))
         (case 2 then (bind ?action find_pose) (bind $?params (create$ waving_1)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NAVIGATE_TO_PERSON
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name NAVIGATE_TO_PERSON) then

      (switch ?p

         (case 1 then (bind ?action say) (bind $?params (create$ going_to_customer)))
         (case 2 then (bind ?action approach) (bind $?params (create$ customer_1)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_customer)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TAKE_ORDER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name TAKE_ORDER) then

      (switch ?p

         (case 1 then (bind ?action find_person) (bind $?params (create$ anybody)))
         (case 2 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 3 then (bind ?action say) (bind $?params (create$ ask_order)))
         (case 4 then (bind ?action listen) (bind $?params (create$ customer_order_1)))
         (case 5 then (bind ?action say) (bind $?params (create$ acknowledge_order_1)))
         (case 6 then (bind ?action focus) (bind $?params (create$ disable)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RETURN_TO_START
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETURN_TO_START) then

      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_kitchen_bar)))
         (case 2 then (bind ?action go_to) (bind $?params (create$ kitchen_bar)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_kitchen_bar)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REPORT_ORDER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name REPORT_ORDER) then

      (switch ?p
         (case 1 then (bind ?action align) (bind $?params (create$ table)))
         (case 2 then (bind ?action find_person) (bind $?params (create$ anybody)))
         (case 3 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 4 then (bind ?action say) (bind $?params (create$ inform_order_1)))
         (case 5 then (bind ?action focus) (bind $?params (create$ disable)))
         (case 6 then (bind ?action say) (bind $?params (create$ request_place_order_on_tray)))
         (case 7 then (bind ?action listen) (bind $?params (create$ continue)))
         ;TODO: Pick orders <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RETURN_TO_CUSTOMER_1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETURN_TO_CUSTOMER_1) then

      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_customer)))
         (case 2 then (bind ?action go_to) (bind $?params (create$ customer_1)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_customer)))
         (case 4 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 5 then (bind ?action say) (bind $?params (create$ request_take_order_from_tray)))
         (case 6 then (bind ?action listen) (bind $?params (create$ continue)))

         (default
            (bind ?next-phase done))
      )
   )
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIND_WAVING_PERSON_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name FIND_WAVING_PERSON_2) then

      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_kitchen_bar)))
         (case 2 then (bind ?action go_to) (bind $?params (create$ initial_position)))
         (case 3 then (bind ?action say) (bind $?params (create$ search_customer_2)))
         (case 4 then (bind ?action find_pose) (bind $?params (create$ waving_2)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NAVIGATE_TO_PERSON_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name NAVIGATE_TO_PERSON_2) then

      (switch ?p

         (case 1 then (bind ?action say) (bind $?params (create$ search_customer_2)))
         (case 2 then (bind ?action approach) (bind $?params (create$ customer_2)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_customer)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TAKE_ORDER_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name TAKE_ORDER_2) then

      (switch ?p

         (case 1 then (bind ?action find_person) (bind $?params (create$ anybody)))
         (case 2 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 3 then (bind ?action say) (bind $?params (create$ ask_order)))
         (case 4 then (bind ?action listen) (bind $?params (create$ customer_order_2)))
         (case 5 then (bind ?action say) (bind $?params (create$ acknowledge_order_2)))
         (case 6 then (bind ?action focus) (bind $?params (create$ disable)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RETURN_TO_START_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETURN_TO_START) then

      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_kitchen_bar)))
         (case 2 then (bind ?action go_to) (bind $?params (create$ initial_position)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_kitchen_bar)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REPORT_ORDER_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name REPORT_ORDER_2) then

      (switch ?p
         (case 1 then (bind ?action align) (bind $?params (create$ table)))
         (case 2 then (bind ?action find_person) (bind $?params (create$ anybody)))
         (case 3 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 4 then (bind ?action say) (bind $?params (create$ inform_order_2)))
         (case 5 then (bind ?action focus) (bind $?params (create$ disable)))
         (case 6 then (bind ?action say) (bind $?params (create$ request_place_order_on_tray)))
         (case 7 then (bind ?action listen) (bind $?params (create$ continue)))
         ;TODO: Pik orders <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RETURN_TO_CUSTOMER_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETURN_TO_CUSTOMER_2) then

      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_customer)))
         (case 2 then (bind ?action approach) (bind $?params (create$ customer_2)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_customer_2)))
         (case 4 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 5 then (bind ?action say) (bind $?params (create$ request_take_order_from_tray)))
         (case 6 then (bind ?action listen) (bind $?params (create$ continue)))


         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RETURN_TO_INITIAL_POSITION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETURN_TO_INITIAL_POSITION) then

      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_kitchen_bar))
         (case 2 then (bind ?action go_to) (bind $?params (create$ initial_position)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_kitchen_bar)))

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINISH_RESTAURANT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name FINISH_RESTAURANT) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ finish_restaurant))
         )

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EXECUTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (neq ?action none) then

      (assert
         (ros-message
            (robot Justina)
            (action ?action)
            (params $?params)
            (step ?n)))

      (modify ?pc
         (step (+ ?n 1)))
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PHASE UPDATE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?next-phase done) then

      (modify ?s
         (phase done))

   else

      (modify ?s
         (phase ?next-phase)))
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

      (assert
         (stack (states $?rest)))

      (assert
         (plan-note
            (robot Justina)
            (state ?next)))

      (assert
         (state
            (name ?next)
            (phase 1)))
   )
)
