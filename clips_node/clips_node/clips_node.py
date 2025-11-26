import rclpy
import os
from rclpy.node import Node
from std_msgs.msg import String
from clips import Environment
from pathlib import Path
from std_srvs.srv import Trigger
from service.srv import String as StringSrv
import threading


class ClipsNode(Node):
    def __init__(self):
        super().__init__('clips_node')

        self.get_logger().info('Iniciando nodo CLIPS...')
        self.broadcast_pub = self.create_publisher(String, 'clips/results', 10)

        # Servicio para iniciar CLIPS
        self.start_service = self.create_service(
            Trigger, 
            'clips/start_planning', 
            self.start_planning_callback
        )

        # Servicio para recibir hechos
        self.assert_fact_service = self.create_service(
            StringSrv,  
            'clips/assert_fact', 
            self.assert_fact_callback
        )

        # Inicializar CLIPS
        self.env = Environment()
        self.env.clear()

        # Suscriptor de hechos
        self.subscription = self.create_subscription(
            String,
            'clips/facts',
            self.listener_callback,
            10
        )

        # Cargar reglas desde .dat
        self.load_rules_from_dat()
        
        # Variables para controlar el estado y acumular pasos
        self.planning_started = False
        self.plan_steps = []  # Lista para acumular pasos del plan
        self.current_plan_name = None
        self.started = False

    def load_rules_from_dat(self):
        rules_list_file = Path(os.getcwd()) /'clips'/'clips_node'/'clips_rules'/'rules_list.dat'

        if not rules_list_file.exists():
            rules_list_file = Path(os.getcwd()) /'src'/'Planning'/'clips'/'clips_node'/'clips_rules'/'rules_list.dat'
            if not rules_list_file.exists():
                self.get_logger().error(f'Archivo de lista de reglas no encontrado: {rules_list_file}')
                return

        try:
            with open(rules_list_file, 'r', encoding='utf-8') as f:
                for line in f:
                    clp_path = line.strip()
                    if clp_path == '' or clp_path.startswith('#'):
                        continue
                    clp_file = Path(clp_path)
                    if not clp_file.is_absolute():
                        clp_file = rules_list_file.parent / clp_file
                    if clp_file.exists():
                        # Cargar archivos CLIPS directamente
                        self.env.load(str(clp_file))
                        self.get_logger().info(f'Reglas cargadas desde: {clp_file}')
                    else:
                        self.get_logger().warn(f'Archivo de reglas no encontrado: {clp_file}')
            
            self.env.reset()
            self.get_logger().info('Todas las reglas CLIPS cargadas exitosamente')
            
        except Exception as e:
            self.get_logger().error(f'Error cargando reglas: {e}')

    def start_planning_callback(self, request, response):
        """Callback del servicio para iniciar la planificación"""
        try:
            if not self.planning_started:
                # Reiniciar la lista de pasos
                self.plan_steps = []
                
                # Insertar el hecho que inicia la planificación
                self.env.assert_string("(start action-planning)")
                
                # Ejecutar CLIPS en un hilo separado para no bloquear el servicio
                thread = threading.Thread(target=self.run_clips)
                thread.daemon = True
                thread.start()
                
                self.planning_started = True
                self.started = True
                response.success = True
                response.message = "CLIPS iniciado con el hecho (start action-planning)"
                self.get_logger().info('Planificación iniciada mediante servicio')
            else:
                response.success = False
                response.message = "La planificación ya fue iniciada previamente"
                
        except Exception as e:
            response.success = False
            response.message = f"Error iniciando CLIPS: {str(e)}"
            self.get_logger().error(f'Error en servicio start_planning: {e}')
            
        return response

    def run_clips(self):
        """Ejecuta CLIPS en un hilo separado"""
        try:
            fired = self.env.run()
            self.get_logger().info(f'Reglas disparadas: {fired}')
            
            # Procesar y publicar mensajes ROS generados por las reglas
            self._process_ros_messages()
            
        except Exception as e:
            self.get_logger().error(f'Error ejecutando CLIPS: {e}')

    def listener_callback(self, msg):
        """Callback para recibir hechos adicionales durante la ejecución"""
        fact_str = msg.data.strip()
        self.get_logger().info(f'Recibido hecho durante ejecución: {fact_str}')

        try:
            # Insertar el hecho en CLIPS
            self.env.assert_string(fact_str)
            
            # Ejecutar las reglas
            thread = threading.Thread(target=self.run_clips)
            thread.daemon = True
            thread.start()
            
        except Exception as e:
            self.get_logger().error(f'Error procesando hecho adicional: {e}')

    def assert_fact_callback(self, request, response):
        """Callback del servicio para recibir hechos"""
        fact_str = request.data.strip()
        self.get_logger().info(f'Recibido hecho mediante servicio: {fact_str}')

        try:
            # Insertar el hecho en CLIPS
            self.env.assert_string(fact_str)
            
            # Ejecutar las reglas en un hilo separado
            thread = threading.Thread(target=self.run_clips)
            thread.daemon = True
            thread.start()
            
            response.data = f"Hecho '{fact_str}' procesado exitosamente"
            self.get_logger().info(f'Hecho procesado via servicio: {fact_str}')
            
        except Exception as e:
            error_msg = f'Error procesando hecho adicional: {e}'
            response.data = error_msg
            self.get_logger().error(error_msg)
            
        return response

    def _process_ros_messages(self):
        """Procesa los hechos de mensajes ROS y los publica"""
        try:
            messages_processed = 0
            plan_info = {}  # Diccionario para almacenar información del plan
            facts_to_retract = []  # Lista para almacenar hechos a retractar después
            step_num = 0
            self.plan_steps = []
            
            # Primero: recolectar todos los hechos 'plan' sin modificarlos
            for fact in self.env.facts():
                if fact.template.name == 'plan':
                    try:
                        # Extraer información del hecho plan
                        name = fact['name'] 
                        step_num = fact['number'] 
                        arguments = " ".join(fact['actions'])
                        
                        # Almacenar información del plan
                        if name not in plan_info:
                            plan_info[name] = {'steps': [], 'max_step': 0}
                        
                        plan_info[name]['steps'].append((step_num, arguments))
                        
                        # Actualizar el paso máximo
                        if step_num > plan_info[name]['max_step']:
                            plan_info[name]['max_step'] = step_num
                        
                        # Formatear el paso del plan
                        step_info = f"Paso {step_num}: {name} {arguments}"
                        
                        # Acumular el paso
                        self.plan_steps.append(step_info)
                        self.get_logger().info(f'{step_info}')
                        
                        # Guardar el hecho para retractarlo después
                        facts_to_retract.append(fact)
                        messages_processed += 1
                        
                    except Exception as e:
                        self.get_logger().error(f'Error procesando hecho plan: {e}')
                        continue  # Continuar con el siguiente hecho

                elif fact.template.name == 'ros-message':
                    try:
                        if not self.started:
                            self.plan_steps.pop()
                            messages_processed -= 1
                            self.started = True
                            
                        name = "Justina"

                        step_num += 1
                        arguments = fact['content']
                        
                        # Almacenar información del plan
                        if name not in plan_info:
                            plan_info[name] = {'steps': [], 'max_step': 0}
                        
                        plan_info[name]['steps'].append((step_num, arguments))
                        
                        # Actualizar el paso máximo
                        if step_num > plan_info[name]['max_step']:
                            plan_info[name]['max_step'] = step_num
                        
                        # Formatear el paso del plan
                        step_info = f"Paso {step_num}: {name} {arguments}"
                        
                        # Acumular el paso
                        self.plan_steps.append(step_info)
                        self.get_logger().info(f'{step_info}')
                        
                        # Guardar el hecho para retractarlo después
                        facts_to_retract.append(fact)
                        messages_processed += 1
                        
                    except Exception as e:
                        self.get_logger().error(f'Error procesando hecho plan: {e}')
                        continue  # Continuar con el siguiente hecho
            
            # Segundo: retractar todos los hechos después de procesarlos
            for fact in facts_to_retract:
                try:
                    fact.retract()
                except Exception as e:
                    self.get_logger().error(f'Error retractando hecho: {e}')            
            
            if messages_processed > 0:
                # Enviar el plan completo
                self._send_complete_plan(name, plan_info[name]['max_step'])
                self.get_logger().info(f'Procesados {messages_processed} mensajes ROS')
                    
        except Exception as e:
            self.get_logger().error(f'Error procesando mensajes ROS: {e}')

    def _send_complete_plan(self, plan_name, total_steps):
        """Envía todos los pasos del plan acumulados en un solo mensaje"""
        try:
            if self.plan_steps:
                # Crear un mensaje con todos los pasos del plan
                plan_header = f"=== PLAN COMPLETO: {plan_name} ({total_steps} pasos) ==="
                steps_text = "\n".join(self.plan_steps)
                complete_plan = f"{plan_header}\n{steps_text}\n=== FIN DEL PLAN ==="
                
                # Publicar el plan completo
                ros_msg = String()
                ros_msg.data = complete_plan
                self.broadcast_pub.publish(ros_msg)
                
                self.get_logger().info(f'Plan completo enviado: {plan_name} con {len(self.plan_steps)} pasos')
                
                # Limpiar la lista de pasos para el próximo plan
                self.plan_steps = []
            else:
                self.get_logger().warn('Se detectó fin de planificación pero no hay pasos acumulados')
                
        except Exception as e:
            self.get_logger().error(f'Error enviando plan completo: {e}')


def main(args=None):
    rclpy.init(args=args)
    node = ClipsNode()
    
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info('Apagando nodo CLIPS...')
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()