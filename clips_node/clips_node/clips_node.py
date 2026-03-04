import rclpy
import os
from rclpy.node import Node
from std_msgs.msg import String
from clips import Environment
from pathlib import Path
from std_srvs.srv import Trigger
from clips_interfaces.srv import String as StringSrv
from clips_interfaces.srv import StringArray
import threading
import queue
from enum import Enum
from datetime import datetime

# ============================================================
# ======================= MAIN NODE ==========================
# ============================================================

class ClipsNode(Node):

    def __init__(self):
        super().__init__('clips_node')

        self.get_logger().info("Inicializando CLIPS Manager Autónomo...")

        self.broadcast_pub = self.create_publisher(String, 'clips/results', 10)

        # Servicios
        self.create_service(Trigger, 'clips/start_planning', self.start_planning_callback)
        self.create_service(StringSrv, 'clips/assert_fact', self.assert_fact_callback)
        self.create_service(StringArray, 'clips/assert_facts_batch', self.assert_facts_batch_callback)

        # CLIPS
        self.env = Environment()
        self.env.clear()
        self.load_rules_from_dat()

        # Worker único
        self.task_queue = queue.Queue()
        self.worker = threading.Thread(target=self._worker_loop, daemon=True)
        self.worker.start()
       
        self.current_plan = []

        self.robot_name = "Justina"
        self.plan_name = "HRI"

        self.plan_file_path = Path(os.getcwd()) /'src'/'Knowledge'/'knowledge_bank' / "plan_execution.log"
        if not self.plan_file_path.exists():
            self.plan_file_path = Path(os.getcwd()) / 'src'/ 'Planning' / 'clips' / "plan_execution.log"
            if not self.plan_file_path.exists():
                self.plan_file_path = Path(os.getcwd()) / 'clips' / "plan_execution.log"
        self._initialize_plan_file()

    # ============================================================
    # ===================== FILE FUNCTIONS =======================
    # ============================================================

    def _initialize_plan_file(self):
        """Crea o limpia el archivo al iniciar el nodo"""
        with open(self.plan_file_path, "w", encoding="utf-8") as f:
            f.write("")  # Limpia el archivo
        self.get_logger().info(f"Archivo de plan reiniciado: {self.plan_file_path}")

    def _write_log(self, text):
        with open(self.plan_file_path, "a", encoding="utf-8") as f:
            f.write(text + "\n")

    # ============================================================
    # ======================= WORKER ==============================
    # ============================================================

    def _worker_loop(self):
        while rclpy.ok():
            task = self.task_queue.get()
            if task is None:
                break
            try:
                task()
            except Exception as e:
                self.get_logger().error(f"Worker error: {e}")
            self.task_queue.task_done()

    # ============================================================
    # ====================== RULE LOADING ========================
    # ============================================================

    def load_rules_from_dat(self):
        rules_list_file = Path(os.getcwd()) / 'clips' / 'clips_node' / 'clips_rules' / 'rules_list.dat'

        if not rules_list_file.exists():
            rules_list_file = Path(os.getcwd()) / 'src' / 'Planning' / 'clips' / 'clips_node' / 'clips_rules' / 'rules_list.dat'
            if not rules_list_file.exists():
                self.get_logger().error("No se encontró rules_list.dat")
                return

        with open(rules_list_file, 'r', encoding='utf-8') as f:
            for line in f:
                clp_path = line.strip()
                if clp_path and not clp_path.startswith('#'):
                    clp_file = Path(clp_path)
                    if not clp_file.is_absolute():
                        clp_file = rules_list_file.parent / clp_file
                    if clp_file.exists():
                        self.env.load(str(clp_file))

        # 🔥 DEBUGGING
        # self.env.eval("(watch rules)")
        # self.env.eval("(watch facts)")
        # self.env.eval("(watch activations)")
        # self.env.eval("(watch focus)")
        self.env.reset()
        self.get_logger().info(f"Reglas CLIPS cargadas {clp_file}")

    # ============================================================
    # ===================== SERVICES =============================
    # ============================================================

    def start_planning_callback(self, request, response):

        def task():
            self.current_plan.clear()
            self.env.reset()
            self.env.assert_string("(start (name action-planning))")
            self._run_and_check_plan()

        self.task_queue.put(task)

        response.success = True
        response.message = "Planificación iniciada"
        return response

    def assert_fact_callback(self, request, response):

        def task():
            self.env.assert_string(request.data)
            self._run_and_check_plan()

        self.task_queue.put(task)
        response.data = "Hecho recibido"
        return response

    def assert_facts_batch_callback(self, request, response):

        def task():
            for fact in request.data:
                self.env.assert_string(fact)
            self._run_and_check_plan()

        self.task_queue.put(task)
        response.successful = True
        return response

    # ============================================================
    # ===================== CORE EXECUTION =======================
    # ============================================================

    def _run_and_check_plan(self):

        fired = self.env.run()
        self.get_logger().info(f"Reglas disparadas: {fired}")

        # Detectar si se generó un plan
        ros_facts = [f for f in self.env.facts() if f.template.name == "ros-message"]

        if ros_facts:
            self._extract_plan()

    # ============================================================
    # ===================== PLAN EXTRACTION ======================
    # ============================================================

    def _extract_plan(self):

        plan = []
        facts_to_retract = []

        for fact in self.env.facts():
            print(fact)
            if fact.template.name == "ros-message":
                try:
                    step = fact['step']
                    robot = fact['robot']
                    action = fact['action']
                    params = " ".join(f for f in fact['params'])
                    content = f"{action} {params}"
                    # content = fact['content']
                    plan.append(f"Paso {step}: {robot} {content}")
                    facts_to_retract.append(fact)
                except:
                    step = fact['step']
                    content = fact['content']
                    plan.append(f"Paso {step}: {self.robot_name} {content}")
                    facts_to_retract.append(fact)
            elif fact.template.name == "plan-note":
                robot = fact['robot']
                state = fact['state']
                plan.append(f"=={robot} {state}==")     

        for f in facts_to_retract:
            f.retract()

        if not plan:
            return

        self.current_plan = plan
        self.execution_index = 0

        self._publish_complete_plan()

    # ============================================================
    # ===================== PLAN PUBLISH =========================
    # ============================================================

    def _publish_complete_plan(self):

        steps_text = "\n".join(plan for plan in self.current_plan)
        steps_text += (f"\nPaso {len(self.current_plan)}: {self.robot_name} say test_completed ")

        msg = String()
        msg.data = steps_text
        self._write_log(msg.data)
        self.broadcast_pub.publish(msg)

        self.get_logger().info(f"Plan generado con {len(self.current_plan)} pasos")

# ============================================================

def main(args=None):
    rclpy.init(args=args)
    node = ClipsNode()

    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.task_queue.put(None)
        node.worker.join()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
