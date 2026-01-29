(deftemplate plan
  (slot name)
  (slot number)
  (multislot actions)
)

(deffacts robot_inspection
  (plan (name Justina) (number  1) (actions goto entrance))

  (plan (name Justina) (number  2) (actions wait_for door))

  (plan (name Justina) (number  3) (actions say "My name is Justina. I am ready for robot inspection "))

  (plan (name Justina) (number  4) (actions goto inspection_point))

  (plan (name Justina) (number  5) (actions say "I have arrived at the inspection point. Please tell me to continue to the exit"))

  (plan (name Justina) (number  6) (actions listen_for "continue"))

  (plan (name Justina) (number  7) (actions goto exit))
)