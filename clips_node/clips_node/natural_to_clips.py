#!/usr/bin/env python3

import torch
import json
import re
import os
import warnings
import rclpy
from rclpy.node import Node
from clips_interfaces.srv import String as StringSrv
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from peft import PeftModel
from pathlib import Path

# =====================================================
# CONFIGURACIÓN (ajusta según tu entorno)
# =====================================================
BASE_MODEL_NAME = "Qwen/Qwen2.5-7B"
# Obtener el directorio donde está este script
SCRIPT_DIR = Path(__file__).parent.resolve()

# Resolver rutas relativas desde allí
ADAPTER_PATH = (SCRIPT_DIR / "../../nl2cd_qwen7b").resolve()
DATA_DIR = (SCRIPT_DIR / "../../CompetitionTemplate").resolve()

# Convertir rutas relativas a absolutas (respecto al directorio de trabajo actual)
ADAPTER_PATH = os.path.abspath(ADAPTER_PATH)
DATA_DIR = os.path.abspath(DATA_DIR)

# =====================================================
# FUNCIONES DE PARSEO (igual que antes)
# =====================================================
def read_data(file_path):
    with open(file_path, "r") as file:
        data = file.read()
    return data

def parse_names(data):
    parsed_names = re.findall(r"\|\s*([A-Za-z]+)\s*\|", data, re.DOTALL)
    parsed_names = [name.strip() for name in parsed_names]
    if parsed_names:
        return parsed_names[1:]
    return []

def parse_locations(data):
    parsed_locations = re.findall(r"\|\s*([0-9]+)\s*\|\s*([A-Za-z,\s, \(,\)]+)\|", data, re.DOTALL)
    parsed_locations = [b for (a, b) in parsed_locations]
    parsed_locations = [location.strip() for location in parsed_locations]
    parsed_placement_locations = [loc for loc in parsed_locations if loc.endswith("(p)")]
    parsed_locations = [loc.replace("(p)", "").strip() for loc in parsed_locations]
    parsed_placement_locations = [loc.replace("(p)", "").strip() for loc in parsed_placement_locations]
    return parsed_locations, parsed_placement_locations

def parse_rooms(data):
    parsed_rooms = re.findall(r"\|\s*(\w+ \w*)\s*\|", data, re.DOTALL)
    parsed_rooms = [room.strip() for room in parsed_rooms]
    if parsed_rooms:
        return parsed_rooms[1:]
    return []

def parse_objects(data):
    parsed_objects = re.findall(r"\|\s*(\w+)\s*\|", data, re.DOTALL)
    parsed_objects = [obj for obj in parsed_objects if obj != "Objectname"]
    parsed_objects = [obj.replace("_", " ") for obj in parsed_objects]
    parsed_objects = [obj.strip() for obj in parsed_objects]
    parsed_categories = re.findall(r"# Class \s*([\w,\s, \(,\)]+)\s*", data, re.DOTALL)
    parsed_categories = [cat.strip() for cat in parsed_categories]
    parsed_categories = [cat.replace("(", "").replace(")", "").split() for cat in parsed_categories]
    categories_plural = [cat[0].replace("_", " ") for cat in parsed_categories if len(cat) >= 1]
    categories_singular = [cat[1].replace("_", " ") for cat in parsed_categories if len(cat) >= 2]
    return parsed_objects, categories_plural, categories_singular

VALID_GESTURES = {
    "waving", "person raising their left arm", "person raising their right arm",
    "person pointing to the left", "person pointing to the right",
    "pointing", "waving", "raising left arm", "raising right arm"
}
VALID_POSES = {"sitting", "standing", "lying"}

def custom_goal_to_cd(goal_str, valid_rooms=None, valid_locations=None, valid_objects=None,
                      valid_names=None, valid_gestures=None, valid_poses=None):
    # (misma función que antes, sin cambios)
    goal_str = goal_str.strip()
    if not goal_str:
        return None
    go_match = re.match(r'go\(([^)]+)\)', goal_str)
    if go_match:
        location = go_match.group(1).strip()
        valid = False
        if valid_rooms and location in valid_rooms:
            valid = True
        if valid_locations and location in valid_locations:
            valid = True
        if not valid:
            return None
        return {"primitive": "PTRANS", "object": "robot", "to": location}
    pick_match = re.match(r'pick\(([^)]+)\)', goal_str)
    if pick_match:
        obj = pick_match.group(1).strip()
        if valid_objects and obj not in valid_objects:
            return None
        return {"primitive": "GRASP", "object": obj}

    find_obj_match = re.match(r'find\(([^)]+)\)', goal_str)
    if find_obj_match:
        arg = find_obj_match.group(1).strip()
        # Verificar si es un objeto conocido
        if valid_objects and arg in valid_objects:
            return {"primitive": "MTRANS", "information": f"location_of_{arg}"}
    find_gesture = re.match(r'find\(person,\s*gesture=([^)]+)\)', goal_str)
    if find_gesture:
        gesture = find_gesture.group(1).strip()
        if valid_gestures and gesture not in valid_gestures:
            return None
        return {"primitive": "ATTEND", "target": f"person_with_{gesture}"}
    find_pose = re.match(r'find\(person,\s*pose=([^)]+)\)', goal_str)
    if find_pose:
        pose = find_pose.group(1).strip()
        if valid_poses and pose not in valid_poses:
            return None
        return {"primitive": "ATTEND", "target": f"person_{pose}"}
    find_clothes = re.match(r'find\(person,\s*clothes=([^)]+)\)', goal_str)
    if find_clothes:
        clothes = find_clothes.group(1).strip()
        return {"primitive": "ATTEND", "target": f"person_wearing_{clothes}"}
    find_name = re.match(r'find\(([^)]+)\)', goal_str)
    if find_name:
        person = find_name.group(1).strip()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "ATTEND", "target": person}
    deliver_match = re.match(r'deliver\(([^,]+),\s*([^)]+)\)', goal_str)
    if deliver_match:
        obj = deliver_match.group(1).strip()
        target = deliver_match.group(2).strip()
        if valid_objects and obj not in valid_objects:
            return None
        return {"primitive": "ATRANS", "object": obj, "destination": target}
    guide_match = re.match(r'guide\(([^,]+),\s*([^)]+)\)', goal_str)
    if guide_match:
        person = guide_match.group(1).strip()
        location = guide_match.group(2).strip()
        if valid_names and person not in valid_names:
            return None
        valid = (valid_rooms and location in valid_rooms) or (valid_locations and location in valid_locations)
        if not valid:
            return None
        return {"primitive": "ACCOMPANY", "person": person, "to": location}
    tell_to = re.match(r'tell\(([^,]+),\s*to=([^)]+)\)', goal_str)
    if tell_to:
        info = tell_to.group(1).strip()
        target = tell_to.group(2).strip()
        return {"primitive": "SPEAK", "utterance": info, "listener": target}
    tell_simple = re.match(r'tell\(([^)]+)\)', goal_str)
    if tell_simple:
        info = tell_simple.group(1).strip()
        return {"primitive": "SPEAK", "utterance": info}
    count_match = re.match(r'count\(([^)]+)\)', goal_str)
    if count_match:
        obj = count_match.group(1).strip()
        if valid_objects and obj not in valid_objects:
            return None
        return {"primitive": "MTRANS", "information": f"count_of_{obj}"}
    greet_match = re.match(r'greet\(([^)]+)\)', goal_str)
    if greet_match:
        person = greet_match.group(1).strip()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "SOCIAL", "action": f"greet {person}"}
    follow_match = re.match(r'follow\(([^)]+)\)', goal_str)
    if follow_match:
        person = follow_match.group(1).strip()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "ACCOMPANY", "person": person}
    meet_match = re.match(r'meet\(([^)]+)\)', goal_str)
    if meet_match:
        person = meet_match.group(1).strip()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "SOCIAL", "action": f"meet {person}"}
    answer_match = re.match(r'answer\(([^)]+)\)', goal_str)
    if answer_match:
        question = answer_match.group(1).strip()
        return {"primitive": "SPEAK", "utterance": f"answer {question}"}
    talk_match = re.match(r'talk\(([^,]+),\s*to=([^)]+)\)', goal_str)
    if talk_match:
        info = talk_match.group(1).strip()
        person = talk_match.group(2).strip()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "SPEAK", "utterance": info, "listener": person}
    place_match = re.match(r'place\(([^,]+),\s*on=([^)]+)\)', goal_str)
    if place_match:
        obj = place_match.group(1).strip()
        location = place_match.group(2).strip()
        if valid_objects and obj not in valid_objects:
            return None
        return {"primitive": "ATRANS", "object": obj, "destination": location}
    save_match = re.match(r'save\(([^)]+)\)', goal_str)
    if save_match:
        obj = save_match.group(1).strip()
        if valid_objects and obj not in valid_objects:
            return None
        return {"primitive": "DO", "action": f"save_{obj}"}
    check_match = re.match(r'check\(([^)]+)\)', goal_str)
    if check_match:
        condition = check_match.group(1).strip()
        return {"primitive": "MTRANS", "information": f"check_{condition}"}
    # wait patterns...
    wait_dur = re.match(r'wait\(duration=([^)]+)\)', goal_str)
    if wait_dur:
        return {"primitive": "WAIT", "seconds": wait_dur.group(1).strip()}
    wait_cmd = re.match(r'wait\(command=([^)]+)\)', goal_str)
    if wait_cmd:
        return {"primitive": "WAIT", "condition": f"command_{wait_cmd.group(1)}"}
    wait_obj = re.match(r'wait\(object=([^,]+),\s*(appears|disappears)\)', goal_str)
    if wait_obj:
        obj, event = wait_obj.groups()
        if valid_objects and obj not in valid_objects:
            return None
        return {"primitive": "WAIT", "condition": f"{event} of {obj}"}
    wait_person_gesture = re.match(r'wait\(person=([^,]+),\s*gesture=([^)]+)\)', goal_str)
    if wait_person_gesture:
        person, gesture = wait_person_gesture.groups()
        if valid_names and person not in valid_names:
            return None
        if valid_gestures and gesture not in valid_gestures:
            return None
        return {"primitive": "WAIT", "condition": f"{person} does {gesture}"}
    wait_person_pose = re.match(r'wait\(person=([^,]+),\s*pose=([^)]+)\)', goal_str)
    if wait_person_pose:
        person, pose = wait_person_pose.groups()
        if valid_names and person not in valid_names:
            return None
        if valid_poses and pose not in valid_poses:
            return None
        return {"primitive": "WAIT", "condition": f"{person} adopts {pose}"}
    wait_person_event = re.match(r'wait\(person=([^,]+),\s*(arrives|leaves)\)', goal_str)
    if wait_person_event:
        person, event = wait_person_event.groups()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "WAIT", "condition": f"{person} {event}"}
    wait_person_becomes = re.match(r'wait\(person=([^,]+),\s*becomes=([^)]+)\)', goal_str)
    if wait_person_becomes:
        person, target_pose = wait_person_becomes.groups()
        if valid_names and person not in valid_names:
            return None
        return {"primitive": "WAIT", "condition": f"{person} becomes {target_pose}"}
    wait_generic = re.match(r'wait\(([^)]+)\)', goal_str)
    if wait_generic:
        return {"primitive": "WAIT", "condition": wait_generic.group(1)}
    ask_match = re.match(r'ask\(([^)]+)\)', goal_str)
    if ask_match:
        topic = ask_match.group(1).strip()
        return {"primitive": "MTRANS", "information": f"ask_{topic}"}
    ask_question = re.match(r'ask\(([^,]+),\s*to=([^)]+)\)', goal_str)
    if ask_question:
        question, target = ask_question.groups()
        return {"primitive": "SPEAK", "utterance": f"ask {question}", "listener": target}
    return {"primitive": "DO", "action": goal_str}

# =====================================================
# NODO ROS2
# =====================================================
class NaturalToClips(Node):
    def __init__(self):
        super().__init__('natural_to_clips')
        self.get_logger().info("Cargando modelo fine-tuneado...")

        # Configuración de cuantización
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16
        )

        # Tokenizer desde el modelo BASE (no desde el adaptador)
        self.tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL_NAME)
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token

        # Cargar modelo base cuantizado
        base_model = AutoModelForCausalLM.from_pretrained(
            BASE_MODEL_NAME,
            quantization_config=bnb_config,
            device_map="auto",
            dtype=torch.float16,
            trust_remote_code=True
        )
        # Cargar adaptador LoRA desde la ruta local
        self.model = PeftModel.from_pretrained(base_model, ADAPTER_PATH)
        self.model.eval()

        # Servicio para texto natural
        self.srv = self.create_service(
            StringSrv,
            'semantic_parser',
            self.handle_semantic_parser
        )

        # Cliente para primitive_to_clips/convert
        self.cli = self.create_client(
            StringSrv,
            'primitive_to_clips/convert'
        )
        while not self.cli.wait_for_service(timeout_sec=1.0):
            self.get_logger().info("Esperando servicio primitive_to_clips/convert...")

        # Cargar datos de validación
        self.load_validation_data()

        self.get_logger().info("natural_to_clips listo")

    def load_validation_data(self):
        self.get_logger().info(f"Cargando datos de validación desde {DATA_DIR}")
        names_file = os.path.join(DATA_DIR, "names/names.md")
        locations_file = os.path.join(DATA_DIR, "maps/location_names.md")
        rooms_file = os.path.join(DATA_DIR, "maps/room_names.md")
        objects_file = os.path.join(DATA_DIR, "objects/objects.md")

        try:
            names_data = read_data(names_file)
            self.valid_names = set(parse_names(names_data))
        except Exception as e:
            self.get_logger().warn(f"No se pudo cargar nombres: {e}")
            self.valid_names = set()

        try:
            locations_data = read_data(locations_file)
            locs, placement_locs = parse_locations(locations_data)
            self.valid_locations = set(locs)
            self.valid_placement_locations = set(placement_locs)
        except Exception as e:
            self.get_logger().warn(f"No se pudo cargar ubicaciones: {e}")
            self.valid_locations = set()
            self.valid_placement_locations = set()

        try:
            rooms_data = read_data(rooms_file)
            self.valid_rooms = set(parse_rooms(rooms_data))
        except Exception as e:
            self.get_logger().warn(f"No se pudo cargar habitaciones: {e}")
            self.valid_rooms = set()

        try:
            objects_data = read_data(objects_file)
            objs, _, _ = parse_objects(objects_data)
            self.valid_objects = set(objs)
        except Exception as e:
            self.get_logger().warn(f"No se pudo cargar objetos: {e}")
            self.valid_objects = set()

        self.valid_gestures = VALID_GESTURES
        self.valid_poses = VALID_POSES

        self.get_logger().info(f"Datos cargados: {len(self.valid_names)} nombres, "
                               f"{len(self.valid_locations)} ubicaciones, "
                               f"{len(self.valid_rooms)} habitaciones, "
                               f"{len(self.valid_objects)} objetos")

    def extract_goals(self, text: str):
        prompt = f"<|im_start|>user\n{text}\n<|im_end|>\n<|im_start|>assistant\n"
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.model.device)

        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=256,
                do_sample=False,
                eos_token_id=self.tokenizer.eos_token_id,
                pad_token_id=self.tokenizer.eos_token_id
            )

        full_response = self.tokenizer.decode(outputs[0], skip_special_tokens=False)
        if "<|im_start|>assistant\n" in full_response:
            assistant_part = full_response.split("<|im_start|>assistant\n")[-1]
            assistant_part = assistant_part.split("<|im_end|>")[0]
            assistant_part = assistant_part.split("<|endoftext|>")[0].strip()
        else:
            assistant_part = full_response

        # Extraer JSON con "goals"
        match = re.search(r'\{[^{}]*"goals"[^{}]*\[.*?\]\s*\}', assistant_part, re.DOTALL)
        if not match:
            start = assistant_part.find('{')
            if start == -1:
                return None
            balance = 0
            for i in range(start, len(assistant_part)):
                if assistant_part[i] == '{':
                    balance += 1
                elif assistant_part[i] == '}':
                    balance -= 1
                if balance == 0:
                    try:
                        candidate = assistant_part[start:i+1]
                        if '"goals"' in candidate:
                            data = json.loads(candidate)
                            if "goals" in data and isinstance(data["goals"], list):
                                return data["goals"]
                    except:
                        pass
                    return None
            return None
        try:
            data = json.loads(match.group(0))
            return data.get("goals", None)
        except:
            return None

    def handle_semantic_parser(self, request, response):
        self.get_logger().info(f"Recibido: {request.data}")
        goals_raw = self.extract_goals(request.data)
        if goals_raw is None:
            response.data = "ERROR: no se pudo extraer ninguna goal"
            return response

        # Convertir goals a primitivas CD (validación rápida)
        cd_primitives = []
        for g in goals_raw:
            cd = custom_goal_to_cd(
                g,
                valid_rooms=self.valid_rooms,
                valid_locations=self.valid_locations,
                valid_objects=self.valid_objects,
                valid_names=self.valid_names,
                valid_gestures=self.valid_gestures,
                valid_poses=self.valid_poses
            )
            if cd is None:
                self.get_logger().warn(f"Goal ignorado (inválido): {g}")
                continue
            cd_primitives.append(cd)
            self.get_logger().info(f"Convertido: '{g}' -> {cd}")

        if not cd_primitives:
            response.data = "ERROR: ninguna goal válida para enviar"
            return response

        # Responder inmediatamente al cliente
        response.data = f"Goals generadas: {goals_raw} "
        
        # Llamada asíncrona sin esperar (fuego y olvido)
        req = StringSrv.Request()
        req.data = json.dumps(cd_primitives)
        future = self.cli.call_async(req)
        # Opcional: agregar un callback para manejar errores si quieres loguearlos
        future.add_done_callback(self._handle_primitive_response)
        
        return response

    def _handle_primitive_response(self, future):
        """Callback que se ejecuta cuando la llamada asíncrona a primitive_to_clips termina"""
        try:
            result = future.result()
            self.get_logger().info(f"Respuesta de primitive_to_clips: {result.data}")
        except Exception as e:
            self.get_logger().error(f"Error en llamada asíncrona a primitive_to_clips: {e}")

def main(args=None):
    rclpy.init(args=args)
    node = NaturalToClips()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()