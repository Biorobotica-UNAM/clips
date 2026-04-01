;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HRI COMPLETE LINEAR PLAN
;; Uses: phase + stack + step
;; Entry: (assert (start (name action-planning)))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
      START_HRI
      RECEIVE_GUEST_1
      RECEIVE_GUEST_2
      INTRODUCE_GUESTS
      RECEIVE_BAG
      FINISH_HRI)))

   (assert (plan-note (robot Justina) (state START_HRI)))

   (assert (state (name START_HRI) (phase 1)))
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
;; START_HRI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name START_HRI) (eq ?p 1)) then
       (bind ?action say)
       (bind $?params (create$ start_hri))
       (bind ?next-phase done))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RECEIVE_GUEST_1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RECEIVE_GUEST_1) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ announce_nav_entrance)))
         (case 2 then (bind ?action goto) (bind $?params (create$ entrance)))
         (case 3 then (bind ?action say) (bind $?params (create$ announce_nav_end_entrance)))
         (case 4 then (bind ?action say) (bind $?params (create$ find_guest)))
         (case 5 then (bind ?action find) (bind $?params (create$ person_anybody)))
         (case 6 then (bind ?action focus) (bind $?params (create$ person)))
         (case 7 then (bind ?action say) (bind $?params (create$ ask_name)))
         (case 8 then (bind ?action listen) (bind $?params (create$ name)))
         (case 9 then (bind ?action save) (bind $?params (create$ name_1)))
         (case 10 then (bind ?action say) (bind $?params (create$ name_1)))
         (case 11 then (bind ?action memorize_face) (bind $?params (create$ name_1)))
         (case 12 then (bind ?action say) (bind $?params (create$ ask_drink)))
         (case 13 then (bind ?action listen) (bind $?params (create$ drink)))
         (case 14 then (bind ?action save) (bind $?params (create$ drink_1)))
         (case 15 then (bind ?action say) (bind $?params (create$ drink_1)))
         ;(case 14 then (bind ?action say) (bind $?params (create$ memorize_face)))
         (case 16 then (bind ?action describe) (bind $?params (create$ face_1)))
         (case 17 then (bind ?action save) (bind $?params (create$ face_1)))
         (case 18 then (bind ?action say) (bind $?params (create$ follow_me)))
         (case 19 then (bind ?action unfocus) (bind $?params (create$ person)))
         (case 20 then (bind ?action say) (bind $?params (create$ announce_nav_living_room)))
         (case 21 then (bind ?action goto) (bind $?params (create$ living_room)))
         (case 22 then (bind ?action say) (bind $?params (create$ announce_nav_end_living_room)))
         (case 23 then (bind ?action say) (bind $?params (create$ find_empty_seat)))
         (case 24 then (bind ?action find) (bind $?params (create$ object_seat_free)))
         (case 25 then (bind ?action point) (bind $?params (create$ empty_seat)))
         (case 26 then (bind ?action say) (bind $?params (create$ offer_seat)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RECEIVE_GUEST_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RECEIVE_GUEST_2) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ announce_nav_entrance)))
         (case 2 then (bind ?action goto) (bind $?params (create$ entrance)))
         (case 3 then (bind ?action say) (bind $?params (create$ announce_nav_end_entrance)))
         (case 4 then (bind ?action say) (bind $?params (create$ find_guest)))
         (case 5 then (bind ?action find) (bind $?params (create$ person_anybody)))
         (case 6 then (bind ?action focus) (bind $?params (create$ person)))
         (case 7 then (bind ?action say) (bind $?params (create$ ask_name)))
         (case 8 then (bind ?action save) (bind $?params (create$ name_2)))
         (case 9 then (bind ?action say) (bind $?params (create$ name_2)))
         (case 10 then (bind ?action memorize_face) (bind $?params (create$ name_2)))
         (case 11 then (bind ?action say) (bind $?params (create$ ask_drink)))
         (case 12 then (bind ?action listen) (bind $?params (create$ drink)))
         (case 13 then (bind ?action save) (bind $?params (create$ drink_2)))
         (case 14 then (bind ?action say) (bind $?params (create$ drink_2)))
         ;(case 14 then (bind ?action say) (bind $?params (create$ memorize_face)))
         ;(case 14 then (bind ?action save) (bind $?params (create$ face_2)))
         (case 15 then (bind ?action say) (bind $?params (create$ visual_description_name_1)))
         (case 16 then (bind ?action say) (bind $?params (create$ follow_me)))
         (case 17 then (bind ?action unfocus) (bind $?params (create$ person)))
         (case 18 then (bind ?action say) (bind $?params (create$ announce_nav_living_room)))
         (case 19 then (bind ?action goto) (bind $?params (create$ living_room)))
         (case 20 then (bind ?action say) (bind $?params (create$ announce_nav_end_living_room)))
         (case 21 then (bind ?action say) (bind $?params (create$ find_empty_seat)))
         (case 22 then (bind ?action find) (bind $?params (create$ object_seat_free)))
         (case 23 then (bind ?action point) (bind $?params (create$ empty_seat)))
         (case 24 then (bind ?action say) (bind $?params (create$ offer_seat)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INTRODUCE_GUESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name INTRODUCE_GUESTS) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ find_name_1)))
         (case 2 then (bind ?action find) (bind $?params (create$ person_name_1)))
         (case 3 then (bind ?action say) (bind $?params (create$ introduce_guest_2)))
         (case 4 then (bind ?action say) (bind $?params (create$ find_name_2)))
         (case 5 then (bind ?action find) (bind $?params (create$ person_name_2)))
         (case 6 then (bind ?action say) (bind $?params (create$ introduce_guest_1)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RECEIVE_BAG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RECEIVE_BAG) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ find_name_2)))
         (case 2 then (bind ?action find) (bind $?params (create$ person_name_2)))
         (case 3 then (bind ?action approach) (bind $?params (create$ person_name_2)))
         (case 4 then (bind ?action say) (bind $?params (create$ ask_bag)))
         (case 5 then (bind ?action take) (bind $?params (create$ bag)))
         (case 6 then (bind ?action say) (bind $?params (create$ find_host)))
         (case 7 then (bind ?action find) (bind $?params (create$ person_host)))
         (case 8 then (bind ?action approach) (bind $?params (create$ person_host)))
         (case 9 then (bind ?action say) (bind $?params (create$ receive_present)))
         (case 10 then (bind ?action say) (bind $?params (create$ user_follow)))
         (case 11 then (bind ?action listen) (bind $?params (create$ follow)))
         (case 10 then (bind ?action follow) (bind $?params (create$ true)))
         (case 11 then (bind ?action listen) (bind $?params (create$ drop_bag)))
         (case 12 then (bind ?action drop) (bind $?params (create$ floor)))
         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FINISH_HRI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (and (eq ?name FINISH_HRI) (eq ?p 1)) then
       (bind ?action say)
       (bind $?params (create$ finish_hri))
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