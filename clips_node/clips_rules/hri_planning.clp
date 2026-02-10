(deftemplate plan
  (slot name)
  (slot number)
  (multislot actions)
)

(deffacts hri-plan
  (plan (name Justina) (number  1) (actions Optional_Doorbell Doorbell))
  (plan (name Justina) (number  2) (actions Optional_Doorbell Detect doorbell))

  (plan (name Justina) (number  3) (actions Navigation Door))
  (plan (name Justina) (number  4) (actions Navigation Goto entrance))
  (plan (name Justina) (number  5) (actions Navigation Align entrance))

  (plan (name Justina) (number  6) (actions Optional_Door Door))
  (plan (name Justina) (number  7) (actions Optional_Door Open Door))

  (plan (name Justina) (number  8) (actions Interaction Guest))
  (plan (name Justina) (number  9) (actions Interaction say greet guest_1))

  (plan (name Justina) (number 10) (actions Interaction say ask_name guest_1))
  (plan (name Justina) (number 11) (actions Interaction listen guest_1))

  (plan (name Justina) (number 12) (actions Interaction say ask_drink guest_1))
  (plan (name Justina) (number 13) (actions Interaction listen guest_1))

  (plan (name Justina) (number 14) (actions Guiding Guest))
  (plan (name Justina) (number 15) (actions Guiding say follow_me guest_1))
  (plan (name Justina) (number 16) (actions Guiding Goto living_room))

  (plan (name Justina) (number 17) (actions Seating Seat))
  (plan (name Justina) (number 18) (actions Seating say indicate_seat guest_1))
  (plan (name Justina) (number 19) (actions Seating Find free_seat))
  (plan (name Justina) (number 20) (actions Seating Align free_seat))
  (plan (name Justina) (number 21) (actions Seating say offer_seat guest_1))

  (plan (name Justina) (number 22) (actions Optional_Doorbell Door))
  (plan (name Justina) (number 23) (actions Optional_Doorbell Detect doorbell))

  (plan (name Justina) (number 24) (actions Navigation Door))
  (plan (name Justina) (number 25) (actions Navigation Goto entrance))
  (plan (name Justina) (number 26) (actions Navigation Align entrance))

  (plan (name Justina) (number 27) (actions Optional_Door Door))
  (plan (name Justina) (number 28) (actions Optional_Door Open entrance_door))

  (plan (name Justina) (number 29) (actions Interaction Guest))
  (plan (name Justina) (number 30) (actions Interaction say greet guest_2))

  (plan (name Justina) (number 31) (actions Interaction say ask_name guest_2))
  (plan (name Justina) (number 32) (actions Interaction listen guest_2))

  (plan (name Justina) (number 33) (actions Interaction say ask_drink guest_2))
  (plan (name Justina) (number 34) (actions Interaction listen guest_2))

  (plan (name Justina) (number 35) (actions Describe Guest))
  (plan (name Justina) (number 36) (actions Describe Look guest_1))
  (plan (name Justina) (number 37) (actions Describe say describe guest_2))

  (plan (name Justina) (number 38) (actions Manipulation Bag))
  (plan (name Justina) (number 39) (actions Manipulation say request_bag guest_2))
  (plan (name Justina) (number 40) (actions Manipulation say ready_to_receive guest_2))
  (plan (name Justina) (number 41) (actions Manipulation Prepare gripper))
  (plan (name Justina) (number 42) (actions Manipulation Align guest_hand))
  (plan (name Justina) (number 43) (actions Manipulation Take bag))
  (plan (name Justina) (number 44) (actions Manipulation Secure bag))
  (plan (name Justina) (number 45) (actions Manipulation say bag_secured guest_2))

  (plan (name Justina) (number 46) (actions Guiding Guest))
  (plan (name Justina) (number 47) (actions Guiding say follow_me guest_2))
  (plan (name Justina) (number 48) (actions Guiding Goto living_room))

  (plan (name Justina) (number 49) (actions Seating Seat))
  (plan (name Justina) (number 50) (actions Seating say indicate_seat guest_2))
  (plan (name Justina) (number 51) (actions Seating Find free_seat))
  (plan (name Justina) (number 52) (actions Seating Align free_seat))
  (plan (name Justina) (number 53) (actions Seating say offer_seat guest_2))

  (plan (name Justina) (number 54) (actions Introduce Guest))
  (plan (name Justina) (number 55) (actions Introduce say attention guest_1))
  (plan (name Justina) (number 56) (actions Introduce Look guest_1))
  (plan (name Justina) (number 57) (actions Introduce say present guest_2))
  (plan (name Justina) (number 58) (actions Introduce say attention guest_2))
  (plan (name Justina) (number 59) (actions Introduce Look guest_2))
  (plan (name Justina) (number 60) (actions Introduce say present guest_1))
  
  (plan (name Justina) (number 61) (actions Contact Host))
  (plan (name Justina) (number 62) (actions Contact say approaching host))
  (plan (name Justina) (number 63) (actions Contact Goto host))
  (plan (name Justina) (number 64) (actions Contact Look host))
  (plan (name Justina) (number 65) (actions Contact say inform_bag host))
  (plan (name Justina) (number 66) (actions Contact say request_follow host))

  (plan (name Justina) (number 67) (actions Following Host))
  (plan (name Justina) (number 68) (actions Following say following_you host))
  (plan (name Justina) (number 69) (actions Following Follow host))

  (plan (name Justina) (number 70) (actions Delivery Bag))
  (plan (name Justina) (number 71) (actions Delivery say arrived_drop_location host))
  (plan (name Justina) (number 72) (actions Delivery say ready_to_drop host))
  (plan (name Justina) (number 73) (actions Delivery Drop bag))
  (plan (name Justina) (number 74) (actions Delivery say task_completed host))
)