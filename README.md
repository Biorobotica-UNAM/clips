# 🧠 Planning - ROS 2 + CLIPS

## 📌 Descripción

Este repositorio implementa una arquitectura completa de **planificación simbólica** basada en ROS 2 y el motor de inferencia **CLIPS**.

El sistema traduce instrucciones en lenguaje natural a un plan ejecutable paso a paso para un robot de servicio, combinando procesamiento de lenguaje natural, representación semántica con Dependencia Conceptual (CD) de Schank, y razonamiento simbólico con precondiciones.

```
Lenguaje natural
      ↓
semantic_parser        texto → primitivas CD (JSON)
      ↓
primitive_to_clips     JSON → hechos CLIPS + estado del mundo
      ↓
clips_node             razonamiento + generación del plan
      ↓
/clips/results         plan publicado paso a paso
      ↓
supervisor / executor  ejecución en el robot
```

---

## 🎯 Objetivo

- Interpretar instrucciones en lenguaje natural y convertirlas en planes ejecutables.
- Razonar sobre el estado del mundo (posición del robot, ubicación de objetos) para inferir pasos intermedios necesarios.
- Soportar tanto planes **dinámicos** (GPSR — generados desde lenguaje natural) como planes **fijos** (HRI, PnP, etc. — hardcodeados en reglas CLIPS).
- Mantener una arquitectura modular, extensible y compatible con los principios SOLID y patrones de diseño.

---

## 🏗️ Arquitectura

| Nodo | Lenguaje | Responsabilidad |
|------|----------|----------------|
| `semantic_parser` | Python | Texto → primitivas CD en JSON |
| `primitive_to_clips` | Python | JSON → hechos CLIPS + estado del mundo inicial |
| `clips_node` | Python | Motor CLIPS: carga reglas, razona, publica el plan |
| `plan_manager_node` | C++ | Almacena el plan, entrega pasos uno a uno bajo demanda |

### Patrones de diseño aplicados

| Patrón | Dónde |
|--------|-------|
| **Facade** | `ClipsEngine` oculta `clips.Environment` |
| **Chain of Responsibility** | Pipeline NLP: SRL → Mapping → Expansion |
| **Factory Method** | `ClipsFactFactory` crea hechos por tipo de primitiva |
| **Strategy** | Backend NLP intercambiable (spaCy hoy, otro mañana) |

---

## 📁 Estructura

```
clips/
├── primitive_to_clips/
│   └── primitive_to_clips/
│       ├── primitive_to_clips.py   # Nodo ROS2 + WorldStateLoader + ClipsFactFactory
│       ├── clips_fact.py           # Clase base abstracta (Factory Method)
│       ├── clips_facts.py          # Builders concretos por primitiva CD
│       └── world_state.yaml        # Estado inicial del mundo (editar antes de competencia)
├── clips_node/
│   ├── clips_node/
│   │   ├── clips_node.py           # Nodo ROS2 (delgado, solo comunicación)
│   │   ├── clips_engine.py         # Facade sobre clips.Environment
│   │   └── clips_components.py     # RuleLoader + PlanExtractor + PlanLogger
│   └── clips_rules/
│       ├── rules_list.dat          # Lista de .clp a cargar (editar para cambiar modo)
│       ├── gpsr_templates.clp      # Templates compartidos para GPSR
│       ├── gpsr_planning.clp       # Plan dinámico desde primitivas CD
│       ├── hri_planning.clp        # Plan fijo HRI
│       └── ...                     # Otros planes fijos
└── plan_manager_node/
    └── src/
        └── plan_manager_node.cpp
```

---

## 🔄 Modos de operación

El modo se controla editando `clips_rules/rules_list.dat`. Solo un modo puede estar activo a la vez.

### Modo GPSR — Plan dinámico desde lenguaje natural

```
# rules_list.dat
gpsr_templates.clp
gpsr_planning.clp
```

Activación: enviar primitivas CD desde `semantic_parser` o directamente vía `primitive_to_clips/convert`.

### Modo planes fijos (HRI, PnP, etc.)

```
# rules_list.dat
hri_planning.clp
```

Activación: llamar directamente a `clips/start_planning`.

---

## 🧩 Nodo 1: `primitive_to_clips`

### Función

- Recibe primitivas CD en JSON.
- Carga el estado inicial del mundo desde `world_state.yaml`.
- Convierte cada primitiva al hecho CLIPS correspondiente usando `ClipsFactFactory`.
- Envía todos los hechos a CLIPS en un solo batch.
- Dispara la planificación.

### Servicio expuesto

```
/primitive_to_clips/convert
Tipo: clips_interfaces/srv/String
```

### Entrada — JSON con lista de primitivas CD

```json
[
  {"primitive": "ATRANS", "actor": "robot", "object": "apple", "from": "kitchen", "to": "user"},
  {"primitive": "ATTEND", "actor": "robot", "object": "person", "location": "living_room"}
]
```

### Ejemplo de llamada

```bash
ros2 service call /primitive_to_clips/convert \
  clips_interfaces/srv/String \
  "{data: '[{\"primitive\": \"ATRANS\", \"actor\": \"robot\", \"object\": \"apple\", \"from\": \"kitchen\", \"to\": \"user\"}]'}"
```

### Salida

```
OK: 8 world facts + 1 primitive facts asserted, planning triggered.
```

### Estado del mundo — `world_state.yaml`

Editar antes de cada competencia para reflejar el entorno real. No requiere cambios en el código.

```yaml
robot:
  name: Justina
  room: living_room    # habitación donde inicia el robot
  holding: nothing

known_objects:
  - name: apple
    room: kitchen
  - name: user
    room: living_room  # ubicación asumida del usuario

known_locations:
  - name: kitchen
  - name: living_room
  - name: bathroom
  # ...
```

---

## 🧠 Nodo 2: `clips_node`

### Función

- Carga reglas CLIPS desde `rules_list.dat`.
- Expone servicios para insertar hechos y disparar planificación.
- Ejecuta el motor de inferencia.
- Extrae y publica el plan generado.
- Escribe el plan en `plan_execution.log`.

### Servicios expuestos

```
/clips/start_planning         std_srvs/Trigger
/clips/assert_fact            clips_interfaces/srv/String
/clips/assert_facts_batch     clips_interfaces/srv/StringArray
```

### Topic publicado

```
/clips/results    std_msgs/String
```

### Formato del plan publicado

```
==Justina GPSR_START==
Paso 1: Justina goto kitchen
Paso 2: Justina find apple
Paso 3: Justina take apple
Paso 4: Justina goto living_room
Paso 5: Justina give apple user
==Justina GPSR_DONE==
Paso 7: Justina say test_completed
```

---

## 🧠 Arquitectura de razonamiento GPSR

`gpsr_planning.clp` implementa planificación por precondiciones en tres capas:

### Capa 1 — Expansión (salience 200)

Convierte primitivas CD en sub-tareas de alto nivel sin verificar el estado del mundo.

```
ATRANS apple kitchen user
  → navigate-to kitchen
  → acquire apple
  → navigate-to user
  → deliver apple user
```

### Capa 2 — Resolución de precondiciones (salience 100)

Verifica el estado del mundo antes de ejecutar cada sub-tarea.

```
navigate-to kitchen + robot en living_room  →  goto kitchen (+ actualiza estado)
navigate-to kitchen + robot ya en kitchen   →  (omitir)
acquire apple + robot en kitchen            →  find apple + take apple
acquire apple + robot en living_room        →  goto kitchen (primero)
```

### Capa 3 — Serialización (salience 10)

Convierte `action-step` en `ros-message` cuando el plan está completo.

### Primitivas CD soportadas

| Primitiva | Acciones generadas |
|-----------|-------------------|
| `PTRANS` | `goto destino` |
| `ATRANS` | `goto origen` + `find` + `take` + `goto destino` + `give` |
| `ATTEND` | `goto ubicación` + `find objeto` |
| `GRASP` | `find objeto` + `take objeto` |
| `ACCOMPANY` | `follow persona` + `goto destino` |
| `MTRANS` | `say contenido` |
| `SPEAK` | `say contenido` |
| `SOCIAL` | `goto ubicación` + `find persona` + `say greet` |
| `WAIT` | `listen condición` |

---

## 🤖 Nodo 3: `plan_manager_node`

### Función

- Recibe el plan completo desde `/clips/results`.
- Almacena el plan internamente.
- Entrega instrucciones una por una bajo demanda.

### Suscripción

```
/clips/results    std_msgs/String
```

### Servicio

```
/request_instruction    std_srvs/Trigger
```

Si hay plan activo → devuelve la siguiente instrucción.
Si no hay plan → responde `NoPlanAssigned`.

---

## 🕹️ Uso del sistema

### 1. Lanzar todos los nodos

```bash
ros2 launch clips_launch clips.launch.xml
```

### 2a. GPSR — Enviar primitivas desde lenguaje natural

```bash
# Obtener primitivas del semantic_parser:
ros2 service call /semantic_parser/semantic_parser \
  semantic_parser_interfaces/srv/Parser \
  "{command: 'Bring me an apple from the kitchen'}"

# Enviar a primitive_to_clips:
ros2 service call /primitive_to_clips/convert \
  clips_interfaces/srv/String \
  "{data: '[{\"primitive\": \"ATRANS\", \"actor\": \"robot\", \"object\": \"apple\", \"from\": \"kitchen\", \"to\": \"user\"}]'}"
```

### 2b. Planes fijos — Disparar directamente

```bash
ros2 service call /clips/start_planning std_srvs/srv/Trigger {}
```

### 3. Escuchar el plan generado

```bash
ros2 topic echo /clips/results
```

### 4. Solicitar instrucción al supervisor

```bash
ros2 service call /request_instruction std_srvs/srv/Trigger {}
```

---

## ⚙️ Instalación

```bash
chmod +x install_clips_planning.sh
./install_clips_planning.sh
```

O manualmente:

```bash
pip install clips pyyaml
cd ~/ros2_ws
colcon build --packages-select clips_interfaces clips_node primitive_to_clips clips_launch
source install/setup.bash
```

---

## 📝 Notas para competencia

- Editar `world_state.yaml` con el entorno real antes de cada prueba.
- Editar `rules_list.dat` para seleccionar el modo correcto (GPSR vs HRI vs otro).
- El plan se guarda automáticamente en `plan_execution.log` para revisión post-prueba.
- El campo `user` en `world_state.yaml` define la ubicación asumida del operador — si el robot ya está en esa habitación, no se genera navegación innecesaria.
