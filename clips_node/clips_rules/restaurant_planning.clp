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
            FINISH_RESTAURANT)))

   (assert
      (plan-note
         (robot Justina)
         (state START_RESTAURANT)))

   (assert
      (state
         (name START_RESTAURANT)
         (phase 1)))
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

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ start_restaurant))
         )

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SAVE_INITIAL_POSITION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name SAVE_INITIAL_POSITION) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ saving_initial_position))
         )

         (case 2 then
            
            (bind ?action saveloc)
            (bind $?params (create$ restaurant_start))
         )

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIND_WAVING_PERSON
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name FIND_WAVING_PERSON) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ searching_customer))
         )

         (case 2 then
            ;; Busca persona waving
            (bind ?action find_waving)
            (bind $?params (create$ person_waving))
         )

         (case 3 then
            (bind ?action focus)
            (bind $?params (create$ person))
         )

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NAVIGATE_TO_PERSON
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name NAVIGATE_TO_PERSON) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ navigating_customer))
         )

         (case 2 then (bind ?action unfocus) 
         (bind $?params (create$ person)))
         
         (case 3 then
            ;; Navega al tf detectado
            (bind ?action goto)
            (bind $?params (create$ door))
         )

         (case 4 then
            (bind ?action say)
            (bind $?params (create$ arrived_customer))
         )

         (default
            (bind ?next-phase done))
      )
   )
;; TODO: Run unfocus
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TAKE_ORDER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name TAKE_ORDER) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ ask_order))
         )

         (case 2 then
            ;; Escucha orden
            (bind ?action listen)
            (bind $?params (create$ restaurant_order))
         )

         (case 3 then
            ;; Guarda semantic result
            (bind ?action save)
            (bind $?params (create$ customer_order))
         )

         (case 4 then
            (bind ?action say)
            (bind $?params (create$ order_received))
         )

         ; (case 5 then
         ;    (bind ?action unfocus)
         ;    (bind $?params (create$ person))
         ; )

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RETURN_TO_START
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RETURN_TO_START) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ returning_start))
         )

         (case 2 then
            ;; Regresa a pose guardada
            (bind ?action goto)
            (bind $?params (create$ restaurant_start))
         )

         (case 3 then
            (bind ?action say)
            (bind $?params (create$ arrived_start))
         )

         (default
            (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REPORT_ORDER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name REPORT_ORDER) then

      (switch ?p

         (case 1 then
            (bind ?action say)
            (bind $?params (create$ reporting_order))
         )

         ;; Aquí puedes usar semantic parser
         ;; para reconstruir frase completa

         (case 2 then
            (bind ?action say)
            (bind $?params (create$ customer_order))
         )

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