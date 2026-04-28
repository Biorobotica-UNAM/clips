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

;; ── Disparador de planificacion ───────────────────────────
;; Insertado por clips_node.py al inicio de cada tarea.
;; Usa task-name para evitar colision con la funcion
;; built-in 'name' de CLIPS.
(deftemplate start
  (slot name)
)

;; ── Control de ejecucion paso a paso ─────────────────────
(deftemplate plan-control
  (slot step (type INTEGER) (default 1))
)

;; ── Mensaje hacia el supervisor ───────────────────────────
;; Una accion concreta del plan serializada para ROS2.
;; El supervisor lee params como argumento de la accion.
(deftemplate ros-message
  (slot step   (type INTEGER) (default 0))
  (slot robot  (type SYMBOL)  (default Justina))
  (slot action (type SYMBOL)  (default unknown))
  (multislot params)
)

;; ── Anotacion del estado del plan ─────────────────────────
;; Usada por clips_node.py para detectar inicio y fin
;; de planificacion.
;;
;; Estados validos:
;;   GPSR_START  — plan inicializado
;;   GPSR_DONE   — plan completado exitosamente
;;   GPSR_FAIL   — plan fallido (objetivo no alcanzable)
(deftemplate plan-note
  (slot robot (type SYMBOL) (default Justina))
  (slot state (type SYMBOL) (default unknown))
)

;; ── Resultado de busqueda ─────────────────────────────────
;; Insertado cuando el executor reporta el resultado de un
;; find. Permite que las reglas de recovery reaccionen al
;; exito o fracaso de una busqueda.
;;
;; status:
;;   searching  — se emitio find, esperando resultado
;;   found      — objetivo localizado en 'room'
;;   not-found  — busqueda agotada, objetivo no hallado
(deftemplate search-result
  (slot target (type SYMBOL) (default unknown))
  (slot room   (type SYMBOL) (default unknown))
  (slot status (type SYMBOL) (default searching))
)

;; ── Intencion de acompanamiento pendiente ─────────────────
;; Se usa cuando ACCOMPANY necesita esperar a tener la
;; ubicacion del acompanante antes de generar acciones.
;; Permite que resolve-accompany-to sea atomico.
(deftemplate pending-accompany
  (slot id     (type INTEGER) (default 0))
  (slot person (type SYMBOL)  (default unknown))
  (slot dest   (type SYMBOL)  (default unknown))
)
