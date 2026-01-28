(deftemplate plan
  (slot name)
  (slot number)
  (multislot actions)
)

(deffacts hri-plan
  (plan (name Justina) (number 1) (actions Optional_Doorbell Door))
  (plan (name Justina) (number 2) (actions Optional_Doorbell Detect doorbell))

  (plan (name Justina) (number 3) (actions Navigation Door))
  (plan (name Justina) (number 4) (actions Navigation Goto entrance))
  (plan (name Justina) (number 5) (actions Navigation Align entrance))

  (plan (name Justina) (number 6) (actions Optional_Door Door))
  (plan (name Justina) (number 7) (actions Optional_Door Open entrance_door))

  (plan (name Justina) (number 8) (actions Interaction Guest))
  (plan (name Justina) (number 9) (actions Interaction speak greet guest_1))
  (plan (name Justina) (number 10) (actions Interaction speak ask_name guest_1))
  (plan (name Justina) (number 11) (actions Interaction speak ask_drink guest_1))

  (plan (name Justina) (number 12) (actions Guiding Guest))
  (plan (name Justina) (number 13) (actions Guiding speak follow_me guest_1))
  (plan (name Justina) (number 14) (actions Guiding Goto living_room))

  (plan (name Justina) (number 15) (actions Seating Seat))
  (plan (name Justina) (number 16) (actions Seating speak indicate_seat guest_1))
  (plan (name Justina) (number 17) (actions Seating Find free_seat))
  (plan (name Justina) (number 18) (actions Seating Align free_seat))
  (plan (name Justina) (number 19) (actions Seating speak offer_seat guest_1))

  (plan (name Justina) (number 20) (actions Optional_Doorbell Door))
  (plan (name Justina) (number 21) (actions Optional_Doorbell Detect doorbell))

  (plan (name Justina) (number 22) (actions Navigation Door))
  (plan (name Justina) (number 23) (actions Navigation Goto entrance))
  (plan (name Justina) (number 24) (actions Navigation Align entrance))

  (plan (name Justina) (number 25) (actions Optional_Door Door))
  (plan (name Justina) (number 26) (actions Optional_Door Open entrance_door))

  (plan (name Justina) (number 27) (actions Interaction Guest))
  (plan (name Justina) (number 28) (actions Interaction speak greet guest_2))
  (plan (name Justina) (number 29) (actions Interaction speak ask_name guest_2))
  (plan (name Justina) (number 30) (actions Interaction speak ask_drink guest_2))

  (plan (name Justina) (number 31) (actions Describe Guest))
  (plan (name Justina) (number 32) (actions Describe Look guest_1))
  (plan (name Justina) (number 33) (actions Describe speak describe guest_2))

  (plan (name Justina) (number 34) (actions Manipulation Bag))
  (plan (name Justina) (number 35) (actions Manipulation speak request_bag guest_2))
  (plan (name Justina) (number 36) (actions Manipulation speak ready_to_receive guest_2))
  (plan (name Justina) (number 37) (actions Manipulation Prepare gripper))
  (plan (name Justina) (number 38) (actions Manipulation Align guest_hand))
  (plan (name Justina) (number 39) (actions Manipulation Take bag))
  (plan (name Justina) (number 40) (actions Manipulation Secure bag))
  (plan (name Justina) (number 41) (actions Manipulation speak bag_secured guest_2))

  (plan (name Justina) (number 42) (actions Guiding Guest))
  (plan (name Justina) (number 43) (actions Guiding speak follow_me guest_2))
  (plan (name Justina) (number 44) (actions Guiding Goto living_room))

  (plan (name Justina) (number 45) (actions Seating Seat))
  (plan (name Justina) (number 46) (actions Seating speak indicate_seat guest_2))
  (plan (name Justina) (number 47) (actions Seating Find free_seat))
  (plan (name Justina) (number 48) (actions Seating Align free_seat))
  (plan (name Justina) (number 49) (actions Seating speak offer_seat guest_2))

  (plan (name Justina) (number 50) (actions Introduce Guest))
  (plan (name Justina) (number 51) (actions Introduce speak attention guest_1))
  (plan (name Justina) (number 52) (actions Introduce Look guest_1))
  (plan (name Justina) (number 53) (actions Introduce speak present guest_2))
  (plan (name Justina) (number 54) (actions Introduce speak attention guest_2))
  (plan (name Justina) (number 55) (actions Introduce Look guest_2))
  (plan (name Justina) (number 56) (actions Introduce speak present guest_1))
  
  (plan (name Justina) (number 57) (actions Contact Host))
  (plan (name Justina) (number 58) (actions Contact speak approaching host))
  (plan (name Justina) (number 59) (actions Contact Goto host))
  (plan (name Justina) (number 60) (actions Contact Look host))
  (plan (name Justina) (number 61) (actions Contact speak inform_bag host))
  (plan (name Justina) (number 62) (actions Contact speak request_follow host))

  (plan (name Justina) (number 63) (actions Following Host))
  (plan (name Justina) (number 64) (actions Following speak following_you host))
  (plan (name Justina) (number 65) (actions Following Follow host))

  (plan (name Justina) (number 66) (actions Delivery Bag))
  (plan (name Justina) (number 67) (actions Delivery speak arrived_drop_location host))
  (plan (name Justina) (number 68) (actions Delivery speak ready_to_drop host))
  (plan (name Justina) (number 69) (actions Delivery Drop bag))
  (plan (name Justina) (number 70) (actions Delivery speak task_completed host))
)