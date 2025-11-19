import rclpy
from rclpy.node import Node
from openai import OpenAI
from std_msgs.msg import String
from custom_interfaces.srv import String as StringSrv

PROMPT_HECHOS = """
Eres un traductor estricto de lenguaje natural a hechos CLIPS.

REGLAS OBLIGATORIAS:
1. Debes producir SOLO hechos CLIPS válidos.
2. NO debes escribir explicaciones, comentarios o texto adicional.
3. NO incluyas texto fuera de la sintaxis CLIPS.
4. Usa exclusivamente la forma:

   (goal (<accion> robot) (<tipo> <objetivo>))

5. Si el usuario describe múltiples objetivos, genera varios hechos,
   uno por línea, todos válidos.
6. Usa solo minúsculas.
7. No generes reglas ni plantillas. SOLO hechos.
8. Si la frase no puede interpretarse, responde exactamente:
   (error parsing)

Ejemplos:

Entrada:
"Ve a la cocina"
Salida:
(goal (move robot) (room kitchen))

Entrada:
"Recoge la caja y llévala al almacén"
Salida:
(goal (pick robot) (object box))
(goal (move robot) (room storage))
"""

class NaturalToClipsNode(Node):

    def __init__(self):
        super().__init__('natural_to_clips')

        # -------------------------
        # Cliente del servicio CLIPS
        # -------------------------
        self.assert_cli = self.create_client(StringSrv, 'clips/assert_fact')

        while not self.assert_cli.wait_for_service(timeout_sec=1.0):
            self.get_logger().info('Esperando servicio clips/assert_fact...')

        # -------------------------
        # Servicio para recibir texto natural desde otro nodo
        # -------------------------
        self.interpret_srv = self.create_service(
            StringSrv,
            'natural_to_clips/interpret',
            self.interpret_callback
        )

        # -------------------------
        # Cliente OpenAI
        # -------------------------
        self.openai_client = OpenAI(api_key="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")

        self.get_logger().info("Nodo NaturalToClips listo.")
        self.get_logger().info("Puedes usar modo terminal o servicio ROS2.")

        # -------------------------
        # Modo terminal en hilo aparte
        # -------------------------
        import threading
        thread = threading.Thread(target=self.terminal_loop)
        thread.daemon = True
        thread.start()

    # ---------------------------------------------------------
    # FUNCIÓN CENTRAL: Enviar texto → ChatGPT → obtener hechos
    # ---------------------------------------------------------
    def interpretar_instruccion(self, texto):
        completion = self.openai_client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system", "content": PROMPT_HECHOS},
                {"role": "user", "content": texto}
            ]
        )
        return completion.choices[0].message.content.strip()

    # ---------------------------------------------------------
    # Enviar hechos CLIPS al servicio clips/assert_fact
    # ---------------------------------------------------------
    def enviar_a_clips(self, hecho):
        req = StringSrv.Request()
        req.data = hecho
        future = self.assert_cli.call_async(req)
        rclpy.spin_until_future_complete(self, future)

    # ---------------------------------------------------------
    # CALLBACK del servicio ROS2 para texto natural
    # ---------------------------------------------------------
    def interpret_callback(self, request, response):
        texto = request.data.strip()
        self.get_logger().info(f"[SERVICIO] Recibido texto: {texto}")

        hechos = self.interpretar_instruccion(texto)
        hechos_list = hechos.split("\n")

        for h in hechos_list:
            h = h.strip()
            if h:
                self.enviar_a_clips(h)

        response.data = f"Hechos generados y enviados:\n{hechos}"
        return response

    # ---------------------------------------------------------
    # MODO TERMINAL (paralelo al ejecutor ROS)
    # ---------------------------------------------------------
    def terminal_loop(self):
        while True:
            texto = input("\n[Terminal] Ingresa una instrucción:\n> ").strip()
            if not texto:
                continue

            hechos = self.interpretar_instruccion(texto)
            print("\nHechos generados:\n", hechos)

            for h in hechos.split("\n"):
                if h.strip():
                    self.enviar_a_clips(h.strip())


# ---------------------------------------------------------
def main(args=None):
    rclpy.init(args=args)
    node = NaturalToClipsNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
