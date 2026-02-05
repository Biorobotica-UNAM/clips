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
            'planning/primitive_to_clips/convert',
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

    def primitives_to_clips(self, primitives):
        clips_facts = []

        for p in primitives:
            primitive_type = p.get('primitive')
            actor = p.get('actor')

            if primitive_type == 'PTRANS':
                obj = p.get('object')
                if actor and obj:
                    fact = f'(goal (move {actor}) (objective {obj}))'
                    clips_facts.append(fact)

            elif primitive_type == 'WAIT':
                condition = p.get('condition')
                if actor and condition:
                    fact = f'(goal (wait_for {actor}) (objective "{condition}"))'
                    clips_facts.append(fact)

            else:
                self.get_logger().warn(f'Unknown primitive: {primitive_type}')

        return clips_facts


    # ======================================================
    # Callback del servicio
    # ======================================================
    def convert_callback(self, request, response):
        # 1. Parsear JSON
        try:
            primitives = json.loads(request.data)
            if not isinstance(primitives, list):
                raise ValueError('JSON must be a list of primitives')
        except Exception as e:
            response.data = f'ERROR parsing JSON: {str(e)}'
            return response

        # 2. Convertir a hechos CLIPS
        clips_facts = self.primitives_to_clips(primitives)
        print(clips_facts)
        if not clips_facts:
            response.data = 'ERROR: no valid primitives to assert'
            return response

        # 3. Esperar servicio CLIPS
        if not self.assert_fact_client.wait_for_service(timeout_sec=3.0):
            response.data = 'ERROR: clips/assert_fact service not available'
            return response

        # 4. Enviar cada hecho a CLIPS
        for fact in clips_facts:
            req = StringSrv.Request()
            req.data = fact

            future = self.assert_fact_client.call_async(req)
            rclpy.spin_until_future_complete(self, future)

            if future.result() is None:
                response.data = f'ERROR asserting fact: {fact}'
                return response

        # 5. Respuesta final
        response.data = f'OK: {len(clips_facts)} facts asserted to CLIPS'
        return response



def main(args=None):
    rclpy.init(args=args)
    node = PrimitiveToClips()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
