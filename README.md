# 🗣️ CLIPS - ROS 2

1. **Nodo Python `natural_to_clips`** — Recibe un texto/instrucción en lenguaje natural, por ejemplo **(Ve a la cocina)**, lo convierte en un hecho y lo envía al nodo **`clips_node`**.
2. **Nodo Python `clips_node`** — Genera aun plan en base a reglas predefinidas y hechos recibidos durante su ejecución mediante el servicio **clips/assert_fact** y lo envía al nodo **robot_comm_node`**.
3. **Nodo C++ `robot_comm_node`** — Se encarga de almacenar el plan generado por el nodo **`clips_node`** de igual manera genera un servidor que permite a otros equipos (robots) conectarse y solictar los pasos del plan almacenado a través de peticiones **TCP**.  
3. **Nodo C++ `robot_to_main_comm_node`** — Realiza peticiones **TCP** a través del servicio **/request_instruction** para obtener paso a la vez el plan generado por el nodo **`clips_node`**.

---

## 📁 Estructura general

  clips_node/
  
  ├── clips_rules/ # Cabecera
  
  ├── -.clp # Reglas de CLIPS
  
  ├── clips_node/
  
  ├── clips_node.py # Nodo principal de clips
  
  ├── natural_to_clips.py # Nodo en conjunto con chatGPT

  robot_comm_node/
  
  ├── src/ # Cabecera
  
  ├── robot_comm_node.cpp # Nodo principal

  robot_to_main_comm_node/
  
  ├── src/ # Cabecera
  
  ├── robot_to_main_comm_node.cpp # Nodo principal

  service/
  
  ├── srv/ # Cabecera
  
  ├── String.srv # Servicio personalizado, recibe un string y envía uno de regreso



Llamada al launch que ejecuta los nodos principales:
```
ros2 ros2 launch clips_launch clips_system.launch.py
```
Llamada al nodo que ejecuta en el equipo del robot:
```
ros2 run robot_to_main_comm_node robot_to_main_comm_node
```

Ejemplos de llamada manual a los servicios:

Servicio que envía el mensaje en lenguaje natural
```
ros2 service call /natural_to_clips/interpret service/srv/String "{data: 've a la cocina'}"
```

Servicio que solicita el plan paso por paso
```
ros2 service call /request_instruction std_srvs/srv/Trigger
```