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
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_entrance)))
         (case 2 then (bind ?action go_to) (bind $?params (create$ entrance)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_entrance)))
         (case 4 then (bind ?action say) (bind $?params (create$ search_guest)))
         (case 5 then (bind ?action find_person) (bind $?params (create$ anybody)))
         (case 6 then (bind ?action say) (bind $?params (create$ inform_guest_found)))
         (case 7 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 8 then (bind ?action say) (bind $?params (create$ ask_name)))
         (case 9 then (bind ?action listen) (bind $?params (create$ name_1)))
         (case 10 then (bind ?action say) (bind $?params (create$ acknowledge_name_1)))
         (case 11 then (bind ?action say) (bind $?params (create$ ask_drink)))
         (case 12 then (bind ?action listen) (bind $?params (create$ drink_1)))
         (case 13 then (bind ?action say) (bind $?params (create$ acknowledge_drink_1)))
         (case 14 then (bind ?action say) (bind $?params (create$ instruct_follow_robot)))
         (case 15 then (bind ?action focus) (bind $?params (create$ disable)))
         (case 16 then (bind ?action say) (bind $?params (create$ going_to_living_room)))
         (case 17 then (bind ?action go_to) (bind $?params (create$ living_room)))
         (case 18 then (bind ?action say) (bind $?params (create$ reached_living_room)))
         (case 19 then (bind ?action say) (bind $?params (create$ search_empty_seat)))
         (case 20 then (bind ?action find_object) (bind $?params (create$ empty_seat)))
         (case 21 then (bind ?action say) (bind $?params (create$ inform_seat_found)))
         (case 22 then (bind ?action point) (bind $?params (create$ enable)))
         (case 23 then (bind ?action say) (bind $?params (create$ instruct_take_a_seat)))
         (case 24 then (bind ?action point) (bind $?params (create$ disable)))

         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RECEIVE_GUEST_2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RECEIVE_GUEST_2) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ going_to_entrance)))
         (case 2 then (bind ?action go_to) (bind $?params (create$ entrance)))
         (case 3 then (bind ?action say) (bind $?params (create$ reached_entrance)))
         (case 4 then (bind ?action say) (bind $?params (create$ search_guest)))
         (case 5 then (bind ?action find_person) (bind $?params (create$ person_anybody)))
         (case 6 then (bind ?action say) (bind $?params (create$ inform_guest_found)))
         (case 7 then (bind ?action focus) (bind $?params (create$ enable)))
         (case 8 then (bind ?action say) (bind $?params (create$ ask_name)))
         (case 9 then (bind ?action listen) (bind $?params (create$ name_2)))
         (case 10 then (bind ?action say) (bind $?params (create$ instruct_look_at_robot)))
         (case 11 then (bind ?action say) (bind $?params (create$ acknowledge_name_2)))
         (case 12 then (bind ?action say) (bind $?params (create$ ask_drink)))
         (case 13 then (bind ?action listen) (bind $?params (create$ drink_2)))
         (case 14 then (bind ?action say) (bind $?params (create$ acknowledge_drink_2)))
         (case 15 then (bind ?action say) (bind $?params (create$ instruct_follow_robot)))
         (case 16 then (bind ?action focus) (bind $?params (create$ disable)))
         (case 17 then (bind ?action say) (bind $?params (create$ going_to_living_room)))
         (case 18 then (bind ?action go_to) (bind $?params (create$ living_room)))
         (case 19 then (bind ?action say) (bind $?params (create$ reached_living_room)))
         (case 20 then (bind ?action say) (bind $?params (create$ search_empty_seat)))
         (case 21 then (bind ?action find_object) (bind $?params (create$ empty_seat)))
         (case 22 then (bind ?action say) (bind $?params (create$ inform_seat_found)))
         (case 23 then (bind ?action point) (bind $?params (create$ enable)))
         (case 24 then (bind ?action say) (bind $?params (create$ instruct_take_a_seat)))
         (case 25 then (bind ?action point) (bind $?params (create$ disable)))

         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INTRODUCE_GUESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name INTRODUCE_GUESTS) then
      (switch ?p
         (case 1 then (bind ?action say) (bind $?params (create$ search_person)))
         (case 2 then (bind ?action find_person) (bind $?params (create$ person_name_1)))
         (case 3 then (bind ?action say) (bind $?params (create$ inform_person_found)))
         (case 4 then (bind ?action say) (bind $?params (create$ introduce_second_guest)))
         (case 5 then (bind ?action say) (bind $?params (create$ describe_second_guest)))
         (case 6 then (bind ?action say) (bind $?params (create$ search_person)))
         (case 7 then (bind ?action find_person) (bind $?params (create$ person_name_2)))
         (case 8 then (bind ?action say) (bind $?params (create$ inform_person_found)))
         (case 9 then (bind ?action say) (bind $?params (create$ introduce_first_guest)))
         (case 10 then (bind ?action say) (bind $?params (create$ describe_first_guest)))

         (default (bind ?next-phase done))
      )
   )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RECEIVE_BAG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (if (eq ?name RECEIVE_BAG) then
      (switch ?p
         (case 1 then (bind ?action approach) (bind $?params (create$ person_name_2)))
         (case 2 then (bind ?action receive) (bind $?params (create$ gift)))
         (case 6 then (bind ?action say) (bind $?params (create$ search_person)))
         (case 7 then (bind ?action find_person) (bind $?params (create$ person_name_host)))
         (case 8 then (bind ?action say) (bind $?params (create$ inform_person_found)))
         (case 9 then (bind ?action approach) (bind $?params (create$ person_host)))
         (case 10 then (bind ?action say) (bind $?params (create$ inform_present)))
         (case 11 then (bind ?action say) (bind $?params (create$ instruct_follow_person)))
         (case 12 then (bind ?action listen) (bind $?params (create$ follow)))
         (case 13 then (bind ?action follow) (bind $?params (create$ enable)))
         (case 14 then (bind ?action listen) (bind $?params (create$ drop_gift)))
         (case 15 then (bind ?action follow) (bind $?params (create$ disable)))
         (case 16 then (bind ?action drop) (bind $?params (create$ gift_1)))

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
