# 🧠 Planning Pipeline - ROS 2 + CLIPS

## 📌 Descripción del paquete

Este repositorio implementa una arquitectura completa de planificación simbólica basada en **ROS 2** y el motor de inferencia **CLIPS**.

El sistema permite convertir primitivas semánticas en metas CLIPS, ejecutar reglas de planificación y generar un plan estructurado que puede ser solicitado paso a paso por un robot.

Primitivas (JSON) → Hechos CLIPS → Motor de inferencia → Plan ejecutable

---

# 🎯 Objetivo del Sistema

El sistema permite:

- Convertir primitivas simbólicas en hechos CLIPS.
- Insertar metas dinámicamente en el motor de inferencia.
- Ejecutar reglas CLIPS de planificación.
- Generar un plan estructurado paso a paso.
- Entregar instrucciones una por una bajo demanda al robot.
- Mantener una arquitectura modular y desacoplada.

---

# 🏗 Arquitectura General

[Semantic Parser / LLM]
→
[primitive_to_clips]
→
[clips_node]
→
[plan_manager_node]
→
[Execution]

---

# 🔄 Flujo Completo de Ejecución

1. Se generan primitivas desde un parser semántico o LLM.
2. Se envían a `primitive_to_clips`.
3. Se convierten en hechos `(goal ...)`.
4. Se insertan en CLIPS mediante `clips_node`.
5. Se inicia la planificación.
6. `clips_node` construye el plan completo.
7. Se publica en `/clips/results`.
8. `plan_manager_node/supervisor` recibe el plan.
9. El robot solicita instrucciones vía `/request_instruction`.

| Nodo                  | Lenguaje | Función                                                                                   |
|-----------------------|----------|-------------------------------------------------------------------------------------------|
| `primitive_to_clips`  | Python   | Recibe primitivas en JSON, las traduce a hechos CLIPS y las envía en lote.               |
| `clips_node`          | Python   | Motor CLIPS: carga reglas, ejecuta razonamiento, publica el plan completo en `/clips/results`. |
| `plan_manager_node`   | C++      | Almacena el plan, expone servicio `/request_instruction` para entregar pasos uno a uno.  |

---
## 📁 Estructura

```
clips_interfaces/        (paquete de mensajes personalizados)
clips/
│   ├── primitive_to_clips/
│   │ └── primitive_to_clips/
│   │     └── primitive_to_clips.py
│   ├── clips_node/
│   │ └── clips_node/
│   │   │ └── clips_node.py
│   │   └── clips_rules/
│   │       ├── rules_list.dat   # lista de archivos .clp a cargar
│   │       └── ...              # archivos de reglas .clp
│   └── plan_manager_node/
│     └── src/
│         └── plan_manager_node.cpp
```
---
# 🧩 Nodo 1: primitive_to_clips (Python)

## 📖 Función

Convierte primitivas en formato JSON a hechos CLIPS del tipo `(goal ...)` y los envía en batch al motor de inferencia.

## 🔧 Servicio

/primitive_to_clips/convert
---
Tipo:

clips_interfaces/srv/String
---

### Entrada

JSON serializado con lista de primitivas:

```json
[
  {
    "primitive": "PTRANS",
    "actor": "robot",
    "object": "entrance"
  },
  {
    "primitive": "WAIT",
    "actor": "robot",
    "condition": "door_to_be_opened"
  }
]

```

Salida del servicio:

OK: * facts asserted to CLIPS

---

# 🧠 Nodo 2: clips_node (Python)
## 📖 Función

Encapsula el motor de inferencia CLIPS y se encarga de:

- Cargar reglas desde archivos .clp
- Recibir hechos individuales o en batch
- Ejecutar el motor CLIPS
- Construir el plan generado
- Publicar el plan completo

# 📂 Carga de reglas

## Archivo:

clips/clips_node/clips_rules/rules_list.dat
---
## 1️⃣ Insertar hecho individual

/clips/assert_fact
---

Tipo:

clips_interfaces/srv/String
----

## 2️⃣ Inserta múltiples hechos y ejecuta CLIPS una sola vez.

/clips/assert_facts_batch
---

Tipo:

clips_interfaces/srv/StringArray
---

Inserta múltiples hechos y ejecuta CLIPS una sola vez.

## 📡 Publicación del plan

Topic:

/clips/results
---

Tipo:

std_msgs/String
---

Formato publicado:

=== PLAN COMPLETO: PlanName (N pasos) ===

Paso 1: Justina move entrance

Paso 2: Justina wait_for door_open


=== FIN DEL PLAN ===

---

# 🤖 Nodo 3: plan_manager_node (C++)
## 📖 Función

Gestiona la ejecución del plan generado.

Este nodo:

- Recibe el plan completo desde /clips/results

- Extrae cada instrucción

- Almacena el plan internamente

- Entrega instrucciones una por una bajo demanda

## 📡 Suscripción
/clips/results
---

## 🔧 Servicio
/request_instruction


Tipo:

std_srvs/Trigger
---

Comportamiento

Si hay plan activo → devuelve la siguiente instrucción

Si no hay plan → responde "NoPlanAssigned"

📤 Publicación opcional

Topic:

/instruction_msg
---
Publica la instrucción actual para otros nodos.

# 🕹️ Cómo usar el sistema
## 1. Lanzar los nodos
```
ros2 run clips_node clips_node

ros2 run primitive_to_clips primitive_to_clips

ros2 run plan_manager_node plan_manager_node
```
## Llamada al launch que ejecuta los nodos principales:
```
ros2 ros2 launch clips_launch clips.launch.py
```

## 2. Enviar primitivas
```
ros2 service call /primitive_to_clips/convert clips_interfaces/srv/String \
"{data: '[{\"primitive\":\"PTRANS\",\"actor\":\"robot\",\"object\":\"entrance\"}]'}"
```
## 3. Solicitar instrucción
```
ros2 service call /request_instruction std_srvs/srv/Trigger
```


## Intalar requirimientos:

```
chmod +x install_clips_planning.sh
```
```
./install_clips_planning.sh
```
