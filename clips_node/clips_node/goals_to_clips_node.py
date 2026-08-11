"""Conversión de metas semánticas a hechos para el planificador CLIPS.

El nodo recibe un JSON con metas escritas como ``accion(argumentos)``. Primero
las parsea y normaliza, después infiere el tipo de cada objetivo y finalmente
construye hechos ``gpsr-goal`` compatibles con ``goals_planning.clp``.

Flujo completo::

    JSON -> ParsedGoal -> (gpsr-goal ...) -> assert_facts_batch -> start_planning

El envío por lote reinicia la memoria de trabajo de CLIPS. La llamada posterior
a ``start_planning`` agrega el hecho disparador que comienza la expansión de
las metas en acciones para el robot.
"""

import json
import re
import shlex
import threading
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import rclpy
from clips_interfaces.srv import String as StringSrv
from clips_interfaces.srv import StringArray
from rclpy.executors import SingleThreadedExecutor
from rclpy.node import Node
from std_srvs.srv import Trigger


@dataclass
class ParsedGoal:
    """Representación intermedia de una meta antes de convertirla a CLIPS.

    ``args`` conserva los argumentos posicionales y ``kwargs`` los argumentos
    con nombre. ``kind`` se calcula después de parsear todas las metas, porque
    su valor puede depender del contexto completo del plan.
    """

    name: str
    target: str = ""
    args: Tuple[str, ...] = ()
    kwargs: Optional[Dict[str, str]] = None
    kind: str = "unknown"


class GoalParser:
    """Parsea, normaliza y clasifica las metas recibidas en el JSON."""

    _GOAL_RE = re.compile(r"^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\((.*)\)\s*$")

    def parse_many(self, payload: str) -> List[ParsedGoal]:
        """Convierte un arreglo JSON, o ``{"goals": [...]}``, en metas.

        Las reparaciones se aplican antes de inferir ``kind`` para que la
        clasificación se realice sobre la secuencia que realmente recibirá
        CLIPS y no sobre la salida posiblemente defectuosa del modelo.
        """

        data = json.loads(payload)
        if isinstance(data, dict):
            raw_goals = data.get("goals", [])
        else:
            raw_goals = data

        if not isinstance(raw_goals, list):
            raise ValueError("goals must be a list")

        goals = [self.parse_one(str(item)) for item in raw_goals]
        goals = self._repair_malformed_goals(goals)
        self._infer_person_targets(goals)
        return goals

    def parse_one(self, raw_goal: str) -> ParsedGoal:
        """Parsea una expresión individual con forma ``nombre(argumentos)``."""

        match = self._GOAL_RE.match(raw_goal)
        if not match:
            raise ValueError(f"invalid goal syntax: {raw_goal}")

        name = match.group(1).strip().lower()
        args, kwargs = self._parse_args(match.group(2))
        args = self._normalize_goal_args(name, args)
        target = args[0] if args else ""
        return ParsedGoal(name=name, target=target, args=tuple(args), kwargs=kwargs)

    def _parse_args(self, body: str) -> Tuple[List[str], Dict[str, str]]:
        """Separa argumentos posicionales de argumentos ``clave=valor``."""

        args: List[str] = []
        kwargs: Dict[str, str] = {}

        for token in self._split_top_level(body):
            if not token:
                continue
            if "=" in token:
                key, value = token.split("=", 1)
                kwargs[self._clean(key).lower()] = self._clean(value)
            else:
                args.append(self._clean(token))

        return args, kwargs

    def _split_top_level(self, body: str) -> List[str]:
        """Divide por comas respetando valores encerrados entre comillas."""

        lexer = shlex.shlex(body, posix=True)
        lexer.whitespace = ","
        lexer.whitespace_split = True
        lexer.commenters = ""
        return [token.strip() for token in lexer]

    def _clean(self, value: str) -> str:
        """Limpia comillas externas y adapta espacios al formato del executor."""

        return value.strip().strip("\"'").replace(" ", "_")

    def _normalize_goal_args(self, name: str, args: List[str]) -> List[str]:
        """Normaliza conceptos de conversación que tienen una respuesta fija."""

        if not args:
            return args

        normalized = self._normalize_talk_target(args[0])
        if name in {"talk", "answer_question"}:
            return [normalized, *args[1:]]
        if name == "tell" and normalized != args[0]:
            return [normalized, *args[1:]]
        return args

    def _normalize_talk_target(self, value: str) -> str:
        """Traduce preguntas frecuentes a las claves usadas por las reglas."""

        text = re.sub(r"[^a-z0-9_]+", " ", value.lower().replace("_", " "))
        tokens = [("team" if token == "teams" else token) for token in text.split()]
        token_set = set(tokens)

        if "yourself" in token_set:
            return "about_yourself"
        if "time" in token_set:
            return "current_time"
        if "country" in token_set and ("team" in token_set or "your" in token_set):
            return "team_country"
        if "affiliation" in token_set and ("team" in token_set or "your" in token_set):
            return "team_affiliation"
        if "team" in token_set and "name" in token_set:
            return "team_name"
        if "day" in token_set and "tomorrow" in token_set:
            return "day_tomorrow"
        if "day" in token_set and "today" in token_set:
            return "day_today"
        if "day" in token_set and "week" in token_set:
            return "day_of_week"
        if "day" in token_set and "month" in token_set:
            return "day_of_month"
        return value

    def _infer_person_targets(self, goals: List[ParsedGoal]) -> None:
        """Infiere ``kind`` usando tanto la meta como el resto del plan.

        Por ejemplo, si una meta entrega un objeto a Laura, cualquier
        ``find(Laura)`` del mismo plan debe interpretarse como búsqueda de una
        persona aunque no incluya un atributo visual explícito.
        """

        person_targets = {"person", "me", "user"}

        for goal in goals:
            if goal.name in {"follow", "guide", "greet"} and goal.target:
                person_targets.add(goal.target)
            if goal.name == "find" and self._looks_like_person_name(goal.target):
                person_targets.add(goal.target)
            if goal.name == "find" and self._person_qualifier(goal):
                person_targets.add(goal.target or "person")
            if goal.name == "deliver":
                destination = self._destination(goal)
                if destination and destination not in {"me", "user", "unknown"}:
                    person_targets.add(destination)

        for goal in goals:
            if goal.name in {"go", "place", "drop"}:
                goal.kind = "location"
            elif goal.name in {"tell", "talk", "save", "answer_question"}:
                goal.kind = "info"
            elif goal.name == "count":
                goal.kind = "person" if goal.target == "person" or self._person_qualifier(goal) else "object"
            elif goal.name in {"follow", "guide", "greet"}:
                goal.kind = "person"
            elif goal.name == "find":
                goal.kind = "person" if goal.target in person_targets or self._person_qualifier(goal) else "object"
            elif goal.name in {"take", "deliver"}:
                goal.kind = "object"

    def _person_qualifier(self, goal: ParsedGoal) -> bool:
        kwargs = goal.kwargs or {}
        return any(key in kwargs for key in ("gesture", "pose", "wearing"))

    def _looks_like_person_name(self, target: str) -> bool:
        if not target or target in {"person", "user", "me", "anybody"}:
            return False
        parts = target.replace("_", " ").split()
        return bool(parts) and all(part[:1].isupper() for part in parts)

    def _destination(self, goal: ParsedGoal) -> str:
        kwargs = goal.kwargs or {}
        return kwargs.get("to") or (goal.args[1] if len(goal.args) > 1 else "")

    def _repair_malformed_goals(self, goals: List[ParsedGoal]) -> List[ParsedGoal]:
        """Repara el patrón erróneo ``go(person)`` producido por el LLM.

        Un ``go`` cuyo objetivo es una persona se convierte en ``find``. Si a
        continuación existe un ``follow`` de esa misma persona hacia un lugar,
        el destino se adelanta como una meta ``go`` y se elimina del ``follow``
        para no ejecutar el desplazamiento dos veces.
        """

        repaired: List[ParsedGoal] = []
        index = 0

        while index < len(goals):
            goal = goals[index]
            if not self._is_malformed_person_go(goal):
                repaired.append(goal)
                index += 1
                continue

            find_goal = self._person_find_from_malformed_go(goal)
            next_goal = goals[index + 1] if index + 1 < len(goals) else None

            if self._is_follow_same_person(next_goal, find_goal):
                destination = self._destination(next_goal)
                if destination:
                    repaired.append(
                        ParsedGoal(
                            name="go",
                            target=destination,
                            args=(destination,),
                            kwargs={},
                        )
                    )
                    repaired.append(find_goal)
                    repaired.append(self._follow_without_destination(next_goal))
                    index += 2
                    continue

            repaired.append(find_goal)
            index += 1

        return repaired

    def _is_malformed_person_go(self, goal: ParsedGoal) -> bool:
        if goal.name != "go":
            return False

        kwargs = goal.kwargs or {}
        return (
            goal.target in {"person", "user", "me"} or
            kwargs.get("finding") in {"person", "user", "me"} or
            self._person_qualifier(goal)
        )

    def _person_find_from_malformed_go(self, goal: ParsedGoal) -> ParsedGoal:
        kwargs = goal.kwargs or {}
        person_target = kwargs.get("finding") or goal.target or "person"
        if person_target in {"user", "me"}:
            person_target = "person"

        find_kwargs = {
            key: value
            for key, value in kwargs.items()
            if key in {"gesture", "pose", "wearing"}
        }
        return ParsedGoal(
            name="find",
            target=person_target,
            args=(person_target,),
            kwargs=find_kwargs,
        )

    def _is_follow_same_person(
        self,
        goal: Optional[ParsedGoal],
        find_goal: ParsedGoal,
    ) -> bool:
        if goal is None or goal.name != "follow":
            return False

        return (goal.target or "person") == (find_goal.target or "person")

    def _follow_without_destination(self, goal: ParsedGoal) -> ParsedGoal:
        """Copia un ``follow`` retirando su destino nominal o posicional."""

        kwargs = {
            key: value
            for key, value in (goal.kwargs or {}).items()
            if key != "to"
        }
        args = goal.args[:1] if len(goal.args) > 1 else goal.args
        return ParsedGoal(
            name=goal.name,
            target=goal.target,
            args=args,
            kwargs=kwargs,
        )


class ClipsGoalFactBuilder:
    """Serializa ``ParsedGoal`` como hechos del template ``gpsr-goal``.

    Los valores de texto se escriben como strings CLIPS escapados. ``name`` y
    ``kind`` se escriben como símbolos porque las reglas comparan esos slots
    con símbolos como ``follow``, ``person`` u ``object``.
    """

    _KNOWN_FIELDS = ("to", "on", "in", "gesture", "pose", "wearing", "property")
    _POSITIONAL_DESTINATION_GOALS = {"deliver", "guide", "follow", "place", "drop"}
    _POSITIONAL_TO_GOALS = {"deliver", "guide", "follow"}

    def build(self, goals: List[ParsedGoal]) -> List[str]:
        """Construye un hecho por meta asignando pasos consecutivos desde 1."""

        return [self._build_goal_fact(step, goal) for step, goal in enumerate(goals, start=1)]

    def _build_goal_fact(self, step: int, goal: ParsedGoal) -> str:
        """Construye la representación textual que acepta ``assert_string``."""

        kwargs = goal.kwargs or {}
        relation, value = self._primary_relation(goal)
        slots = {
            "step": str(step),
            "name": goal.name,
            "target": goal.target,
            "kind": goal.kind,
            "destination": self._destination(goal),
            "relation": relation,
            "value": value,
            "qualifier": self._first_present(kwargs, ("gesture", "pose", "wearing", "property")),
        }
        return (
            "(gpsr-goal "
            f"(step {slots['step']}) "
            f"(name {slots['name']}) "
            f"(target {self._q(slots['target'])}) "
            f"(kind {slots['kind']}) "
            f"(destination {self._q(slots['destination'])}) "
            f"(relation {self._q(slots['relation'])}) "
            f"(value {self._q(slots['value'])}) "
            f"(qualifier {self._q(slots['qualifier'])}))"
        )

    def _primary_relation(self, goal: ParsedGoal) -> Tuple[str, str]:
        """Obtiene la relación principal que CLIPS usará como contexto.

        Los argumentos con nombre tienen prioridad. Para acciones dirigidas a
        una persona o lugar, el segundo argumento posicional equivale a ``to``.
        """

        kwargs = goal.kwargs or {}
        for key in self._KNOWN_FIELDS:
            if key in kwargs:
                return key, kwargs[key]
        if goal.name in self._POSITIONAL_TO_GOALS and len(goal.args) > 1:
            return "to", goal.args[1]
        return "", ""

    def _destination(self, goal: ParsedGoal) -> str:
        """Obtiene el destino nominal o el segundo argumento posicional.

        Se aceptan ambas formas, por ejemplo ``follow(person, to=kitchen)`` y
        ``follow(person, kitchen)``.
        """

        kwargs = goal.kwargs or {}
        if "to" in kwargs:
            return kwargs["to"]
        if "on" in kwargs:
            return kwargs["on"]
        if "in" in kwargs:
            return kwargs["in"]
        if goal.name in self._POSITIONAL_DESTINATION_GOALS and len(goal.args) > 1:
            return goal.args[1]
        return ""

    def _first_present(self, kwargs: Dict[str, str], keys: Tuple[str, ...]) -> str:
        """Codifica el primer atributo visual como ``clave:valor``."""

        for key in keys:
            if key in kwargs:
                return f"{key}:{kwargs[key]}"
        return ""

    def _q(self, value: str) -> str:
        """Escapa un valor para insertarlo de forma segura como string CLIPS."""

        escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'


class GoalsToClipsNode(Node):
    """Servicio ROS 2 que conecta la salida semántica con el nodo CLIPS.

    Se utiliza un nodo cliente con executor propio porque el callback de
    conversión espera las respuestas de otros servicios. Si esos clientes se
    atendieran en el mismo executor bloqueado por el callback, se produciría un
    interbloqueo.
    """

    def __init__(self) -> None:
        super().__init__("goals_to_clips")
        self._parser = GoalParser()
        self._builder = ClipsGoalFactBuilder()

        self._service = self.create_service(
            StringSrv,
            "/planning/goals_to_clips/convert",
            self._handle_convert,
        )

        # Nodo auxiliar dedicado exclusivamente a procesar las respuestas de
        # assert_facts_batch y start_planning mientras este nodo atiende convert.
        self._client_node = rclpy.create_node(
            "goals_to_clips_clients",
            namespace=self.get_namespace(),
            use_global_arguments=False,
        )
        self._assert_client = self._client_node.create_client(
            StringArray,
            "/planning/clips/assert_facts_batch",
        )
        self._planning_client = self._client_node.create_client(
            Trigger,
            "/planning/clips/start_planning",
        )
        self._client_executor = SingleThreadedExecutor()
        self._client_executor.add_node(self._client_node)
        self._client_thread = threading.Thread(
            target=self._client_executor.spin,
            daemon=True,
        )
        self._client_thread.start()
        self.get_logger().info("Goals_to_clips node ready.")

    def _handle_convert(self, request: StringSrv.Request, response: StringSrv.Response) -> StringSrv.Response:
        """Convierte el JSON, envía los hechos y solicita iniciar el plan."""

        try:
            goals = self._parser.parse_many(request.data)
            if not goals:
                response.data = "ERROR: empty goals"
                return response

            facts = self._builder.build(goals)
            self.get_logger().info("==== GOAL CLIPS FACTS ====")
            for index, fact in enumerate(facts, start=1):
                self.get_logger().info(f"[{index}] {fact}")
            self.get_logger().info("==========================")

            if not self._assert_facts(facts):
                response.data = "ERROR asserting goal facts"
                return response
            if not self._trigger_planning():
                response.data = "ERROR triggering planning"
                return response

            response.data = "OK"
            return response
        except Exception as exc:
            self.get_logger().error(f"Goal conversion error: {exc}")
            response.data = f"ERROR: {exc}"
            return response

    def _assert_facts(self, facts: List[str]) -> bool:
        """Envía todos los hechos juntos para crear un contexto CLIPS limpio."""

        if not self._assert_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("assert_facts_batch service not available.")
            return False
        req = StringArray.Request()
        req.data = facts
        future = self._assert_client.call_async(req)
        return self._wait_future(future, timeout_sec=5.0) and future.result().successful

    def _trigger_planning(self) -> bool:
        """Solicita insertar el hecho ``(start (name action-planning))``."""

        if not self._planning_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("start_planning service not available.")
            return False
        future = self._planning_client.call_async(Trigger.Request())
        return self._wait_future(future, timeout_sec=5.0) and future.result().success

    def _wait_future(self, future, timeout_sec: float) -> bool:
        """Espera una respuesta sin depender del executor del nodo servidor."""

        deadline = time.monotonic() + timeout_sec
        while rclpy.ok() and not future.done() and time.monotonic() < deadline:
            time.sleep(0.01)
        return future.done() and future.result() is not None

    def destroy_node(self) -> None:
        """Detiene el executor auxiliar antes de destruir ambos nodos."""

        self._client_executor.shutdown()
        self._client_thread.join(timeout=1.0)
        self._client_node.destroy_node()
        super().destroy_node()


def main(args=None) -> None:
    rclpy.init(args=args)
    node = GoalsToClipsNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
