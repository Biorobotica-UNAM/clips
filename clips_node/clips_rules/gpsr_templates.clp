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

;; Disparador de planificacion — insertado por clips_node.py.
;; Usa task-name para evitar colision con la funcion
;; built-in 'name' de CLIPS.
(deftemplate start
  (slot task-name (type SYMBOL) (default nil))
)

;; Control de ejecucion paso a paso.
(deftemplate plan-control
  (slot step (type INTEGER) (default 1))
)

;; Mensaje hacia el supervisor — una accion del plan.
(deftemplate ros-message
  (slot step   (type INTEGER) (default 0))
  (slot robot  (type SYMBOL)  (default Justina))
  (slot action (type SYMBOL)  (default unknown))
  (multislot params)
)

;; Anotacion del estado del plan — usada por clips_node.py
;; para detectar inicio y fin de planificacion.
(deftemplate plan-note
  (slot robot (type SYMBOL) (default Justina))
  (slot state (type SYMBOL) (default unknown))
)
