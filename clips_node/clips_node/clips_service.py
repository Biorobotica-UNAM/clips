import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from clips import Environment
from pathlib import Path

class ClipsNode(Node):
    def __init__(self):
        super().__init__('clips_node')

        self.get_logger().info('Iniciando nodo CLIPS...')
        self.broadcast_pub = self.create_publisher(String, 'clips/results', 10)

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

    def load_rules_from_dat(self):
        rules_list_file = Path(__file__).parent / 'clips_rules' / 'rules_list.dat'

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
                        # Ahora podemos cargar directamente los archivos
                        self.env.load(str(clp_file))
                        self.get_logger().info(f'Reglas cargadas desde: {clp_file}')
                    else:
                        self.get_logger().warn(f'Archivo de reglas no encontrado: {clp_file}')
            
            self.env.reset()
            self.get_logger().info('Todas las reglas CLIPS cargadas exitosamente')
            
        except Exception as e:
            self.get_logger().error(f'Error cargando reglas: {e}')

    def listener_callback(self, msg):
        fact_str = msg.data.strip()
        self.get_logger().info(f'Recibido hecho: {fact_str}')
        try:
            self.env.assert_string(fact_str)
            
            # # Mostrar todos los hechos antes de ejecutar
            # self.get_logger().info("=== Hechos antes de ejecutar ===")
            # for fact in self.env.facts():
            #     self.get_logger().info(f"  {fact}")
            
            fired = self.env.run()
            # self.get_logger().info(f'Reglas disparadas: {fired}')
            
            # # Mostrar todos los hechos después de ejecutar
            # self.get_logger().info("=== Hechos después de ejecutar ===")
            # for fact in self.env.facts():
            #     self.get_logger().info(f"  {fact}")

            self._process_ros_messages()

        except Exception as e:
            self.get_logger().error(f'Error procesando hecho: {e}')

    def _process_ros_messages(self):
        """Procesa los hechos de mensajes ROS y los publica"""
        try:
            messages_processed = 0
            
            # Buscar todos los hechos ros-message en la base de conocimientos
            for fact in self.env.facts():
                if fact.template.name == 'ros-message':
                    content = fact['content']
                    
                    # Publicar el mensaje en ROS
                    ros_msg = String()
                    ros_msg.data = str(content)
                    self.broadcast_pub.publish(ros_msg)
                    self.get_logger().info(f'Publicado en ROS: {content}')
                    
                    # Eliminar el hecho para evitar repeticiones
                    fact.retract()
                    messages_processed += 1
            
            if messages_processed > 0:
                self.get_logger().info(f'Procesados {messages_processed} mensajes ROS')
                
        except Exception as e:
            self.get_logger().error(f'Error procesando mensajes ROS: {e}')

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