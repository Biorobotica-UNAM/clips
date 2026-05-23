;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  gpsr_templates.clp
;;
;;  Templates compartidos por el sistema de planificacion GPSR.
;;  Debe cargarse ANTES que gpsr_planning.clp en rules_list.dat.
;;
;;  BioRobotics Laboratory, Facultad de Ingenieria, UNAM
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Disparador de planificacion — insertado por clips_node.
(deftemplate start (slot name))

;; Control de ejecucion paso a paso.
(deftemplate plan-control
  (slot step (type INTEGER) (default 1))
)

;; Mensaje hacia el supervisor — una accion del plan.
(deftemplate ros-message
  (slot step   (type INTEGER) (default 0))
  (slot robot  (type SYMBOL)  (default ROBOT))
  (slot action (type SYMBOL)  (default unknown))
  (multislot params)
)

;; Anotacion del estado del plan — usada por clips_node
;; para detectar inicio y fin de planificacion.
(deftemplate plan-note
  (slot robot (type SYMBOL) (default ROBOT))
  (slot state (type SYMBOL) (default unknown))
)

;; Locaciones conocidas por el robot.
(deftemplate known-location
  (slot name (type SYMBOL) (default unknown))
)

;; Resultado de una busqueda — generado por el executor
;; cuando una accion find retorna.
;;   status: found | not-found
(deftemplate search-result
  (slot target (type SYMBOL)  (default unknown))
  (slot room   (type SYMBOL)  (default unknown))
  (slot status (type SYMBOL)  (default not-found))
)
