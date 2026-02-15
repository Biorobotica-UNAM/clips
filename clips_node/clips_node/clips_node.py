import rclpy
import os
from rclpy.node import Node
from std_msgs.msg import String
from clips import Environment
from pathlib import Path
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

        self.get_logger().info("Inicializando Plan-Execution Manager Autónomo...")

        self.broadcast_pub = self.create_publisher(String, 'clips/results', 10)

        # Servicios SOLO para assert
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

        self.env.reset()
        self.get_logger().info(f"Reglas CLIPS cargadas {rules_list_file}")

    # ============================================================
    # ===================== ASSERT SERVICES ======================
    # ============================================================

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
            if fact.template.name == "ros-message":
                try:
                    step = fact['step']
                    content = fact['content']
                    plan.append((step, content))
                    facts_to_retract.append(fact)
                except:
                    continue

        for f in facts_to_retract:
            f.retract()

        if not plan:
            return

        # Ordenar por step real
        plan.sort(key=lambda x: x[0])

        self.current_plan = plan
        self.execution_index = 0

        self._publish_complete_plan()

    # ============================================================
    # ===================== PLAN PUBLISH =========================
    # ============================================================

    def _publish_complete_plan(self):

        header = f"== {self.robot_name} START_{self.plan_name} =="
        steps_text = "\n".join(
            [f"Paso {step}: {self.robot_name} {content}" for step, content in self.current_plan]
        )
        footer = f"== {self.robot_name} FINISH_{self.plan_name} =="

        msg = String()
        msg.data = f"{header}\n{steps_text}\n{footer}"
        self._write_log(f"{header}\n{steps_text}\n{footer}")
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
