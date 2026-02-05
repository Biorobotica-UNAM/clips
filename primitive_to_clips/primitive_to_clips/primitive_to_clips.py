#!/usr/bin/env python3

import rclpy
from rclpy.node import Node

import json

from clips_interfaces.srv import String as StringSrv


class PrimitiveToClips(Node):

    def __init__(self):
        super().__init__('primitive_to_clips')

        # ==============================
        # Almacenamiento interno
        # ==============================
        self.last_primitives = None  # puede ser list o dict

        # ==============================
        # Servicio que recibe primitivas
        # ==============================
        self.convert_service = self.create_service(
            StringSrv,
            'primitive_to_clips/convert',
            self.convert_callback
        )

        # ==============================
        # Cliente al servicio de CLIPS
        # ==============================
        self.assert_fact_client = self.create_client(
            StringSrv,
            'planning/clips/assert_fact'
        )

        self.get_logger().info('Nodo primitive_to_clips iniciado correctamente')

    # ======================================================
    # Callback del servicio
    # ======================================================
    def convert_callback(self, request, response):
        self.get_logger().info('Received request')

        # ----------------------------------
        # 1. Parsear JSON desde string
        # ----------------------------------
        try:
            primitives = json.loads(request.data)

            if not isinstance(primitives, (list, dict)):
                raise ValueError('JSON must be list or dict')

            self.last_primitives = primitives

            self.get_logger().info(
                f'Parsed JSON OK ({type(primitives).__name__})'
            )

        except json.JSONDecodeError as e:
            response.data = f'ERROR: invalid JSON ({str(e)})'
            self.get_logger().error(response.data)
            return response

        except Exception as e:
            response.data = f'ERROR: {str(e)}'
            self.get_logger().error(response.data)
            return response

        # ----------------------------------
        # 2. Esperar servicio CLIPS
        # ----------------------------------
        if not self.assert_fact_client.wait_for_service(timeout_sec=3.0):
            response.data = 'ERROR: clips/assert_fact service not available'
            self.get_logger().error(response.data)
            return response

        # ----------------------------------
        # 3. Enviar JSON original a CLIPS
        # ----------------------------------
        clips_request = StringSrv.Request()
        clips_request.data = request.data  # JSON string original

        future = self.assert_fact_client.call_async(clips_request)
        rclpy.spin_until_future_complete(self, future)

        if future.result() is None:
            response.data = 'ERROR: no response from CLIPS'
            self.get_logger().error(response.data)
            return response

        # ----------------------------------
        # 4. Respuesta final
        # ----------------------------------
        response.data = (
            'OK: JSON received, stored and sent to CLIPS | '
            + future.result().data
        )

        self.get_logger().info(response.data)
        return response


def main(args=None):
    rclpy.init(args=args)
    node = PrimitiveToClips()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
