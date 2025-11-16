import rclpy
from rclpy.node import Node
from custom_interfaces.srv import String
from std_srvs.srv import Trigger
import threading
from typing import Optional, Tuple

class ClipsClientLib:
    """
    Biblioteca cliente para enviar hechos a CLIPS ROS2.
    Puede ser importada y usada en otros nodos ROS2.
    """
    
    def __init__(self, node: Optional[Node] = None):
        """
        Inicializa el cliente CLIPS.
        
        Args:
            node: Nodo ROS2 existente (opcional). Si no se proporciona, se crea uno interno.
        """
        self._external_node = node is not None
        self._node = node if node else rclpy.create_node('clips_client_lib')
        
        # Crear cliente de servicios
        self._assert_fact_client = self._node.create_client(String, 'clips/assert_fact')
        
        # Esperar a que los servicios estén disponibles
        self._wait_for_services()
        
        self._logger = self._node.get_logger()
        self._logger.info('Biblioteca ClipsClientLib inicializada')
    
    def _wait_for_services(self):
        """Espera a que los servicios estén disponibles"""
        self._node.get_logger().info('Esperando servicios CLIPS...')
        
        while not self._assert_fact_client.wait_for_service(timeout_sec=1.0):
            if not rclpy.ok():
                raise RuntimeError("Interrumpido mientras se esperaba por el servicio")
            self._node.get_logger().info('Esperando servicio clips/assert_fact...')
    
    def assert_fact(self, fact: str, timeout_sec: float = 10.0) -> Tuple[bool, str]:
        """
        Envía un hecho a CLIPS.
        
        Args:
            fact: String con el hecho CLIPS a enviar
            timeout_sec: Tiempo máximo de espera para la respuesta
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje de respuesta)
        """
        try:
            request = String.Request()
            request.data = fact
            
            future = self._assert_fact_client.call_async(request)
            
            # Esperar respuesta
            start_time = self._node.get_clock().now()
            while not future.done():
                if (self._node.get_clock().now() - start_time).nanoseconds > timeout_sec * 1e9:
                    return False, "Timeout esperando respuesta del servicio"
                rclpy.spin_once(self._node, timeout_sec=0.1)
            
            response = future.result()
            return True, response.data
            
        except Exception as e:
            return False, f"Error enviando hecho: {str(e)}"
    
    def destroy(self):
        """Libera recursos si se creó un nodo interno"""
        if not self._external_node and self._node:
            self._node.destroy_node()

# Función de conveniencia para uso rápido
def send_fact_sync(fact: str, timeout_sec: float = 10.0) -> Tuple[bool, str]:
    """
    Función sincrónica para enviar un solo hecho.
    
    Args:
        fact: Hecho CLIPS a enviar
        timeout_sec: Tiempo máximo de espera
        
    Returns:
        Tuple[bool, str]: (éxito, mensaje de respuesta)
    """
    rclpy.init()
    try:
        client = ClipsClientLib()
        result = client.assert_fact(fact, timeout_sec)
        client.destroy()
        return result
    finally:
        rclpy.shutdown()