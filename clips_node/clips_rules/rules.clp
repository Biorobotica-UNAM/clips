(deftemplate persona
  (slot nombre)
  (slot edad (type INTEGER))
)

(deftemplate saludo
  (slot texto)
)

(defrule saludar
  (persona (nombre ?n) (edad ?e&:(>= ?e 18)))
  =>
  (assert (saludo (texto (str-cat "Hola " ?n ", eres mayor de edad."))))
)

(defrule saludar-menor
  (persona (nombre ?n) (edad ?e&:(< ?e 18)))
  =>
  (assert (saludo (texto (str-cat "Hola " ?n ", eres menor de edad."))))
)

(defrule mostrar
  ?s <- (saludo (texto ?t))
  =>
  (printout t "[SALUDO] " ?t crlf)
)

