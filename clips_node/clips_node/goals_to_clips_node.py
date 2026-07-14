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
    name: str
    target: str = ""
    args: Tuple[str, ...] = ()
    kwargs: Optional[Dict[str, str]] = None
    kind: str = "unknown"


class GoalParser:
    _GOAL_RE = re.compile(r"^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\((.*)\)\s*$")

    def parse_many(self, payload: str) -> List[ParsedGoal]:
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
        match = self._GOAL_RE.match(raw_goal)
        if not match:
            raise ValueError(f"invalid goal syntax: {raw_goal}")

        name = match.group(1).strip().lower()
        args, kwargs = self._parse_args(match.group(2))
        args = self._normalize_goal_args(name, args)
        target = args[0] if args else ""
        return ParsedGoal(name=name, target=target, args=tuple(args), kwargs=kwargs)

    def _parse_args(self, body: str) -> Tuple[List[str], Dict[str, str]]:
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
        lexer = shlex.shlex(body, posix=True)
        lexer.whitespace = ","
        lexer.whitespace_split = True
        lexer.commenters = ""
        return [token.strip() for token in lexer]

    def _clean(self, value: str) -> str:
        return value.strip().strip("\"'").replace(" ", "_")

    def _normalize_goal_args(self, name: str, args: List[str]) -> List[str]:
        if not args:
            return args

        normalized = self._normalize_talk_target(args[0])
        if name in {"talk", "answer_question"}:
            return [normalized, *args[1:]]
        if name == "tell" and normalized != args[0]:
            return [normalized, *args[1:]]
        return args

    def _normalize_talk_target(self, value: str) -> str:
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
        kwargs = {
            key: value
            for key, value in (goal.kwargs or {}).items()
            if key != "to"
        }
        return ParsedGoal(
            name=goal.name,
            target=goal.target,
            args=goal.args,
            kwargs=kwargs,
        )


class ClipsGoalFactBuilder:
    _KNOWN_FIELDS = ("to", "on", "in", "gesture", "pose", "wearing", "property")

    def build(self, goals: List[ParsedGoal]) -> List[str]:
        return [self._build_goal_fact(step, goal) for step, goal in enumerate(goals, start=1)]

    def _build_goal_fact(self, step: int, goal: ParsedGoal) -> str:
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
        kwargs = goal.kwargs or {}
        for key in self._KNOWN_FIELDS:
            if key in kwargs:
                return key, kwargs[key]
        if goal.name == "deliver" and len(goal.args) > 1:
            return "to", goal.args[1]
        return "", ""

    def _destination(self, goal: ParsedGoal) -> str:
        kwargs = goal.kwargs or {}
        if "to" in kwargs:
            return kwargs["to"]
        if "on" in kwargs:
            return kwargs["on"]
        if "in" in kwargs:
            return kwargs["in"]
        if goal.name == "deliver" and len(goal.args) > 1:
            return goal.args[1]
        return ""

    def _first_present(self, kwargs: Dict[str, str], keys: Tuple[str, ...]) -> str:
        for key in keys:
            if key in kwargs:
                return f"{key}:{kwargs[key]}"
        return ""

    def _q(self, value: str) -> str:
        escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'


class GoalsToClipsNode(Node):
    def __init__(self) -> None:
        super().__init__("goals_to_clips")
        self._parser = GoalParser()
        self._builder = ClipsGoalFactBuilder()

        self._service = self.create_service(
            StringSrv,
            "/planning/goals_to_clips/convert",
            self._handle_convert,
        )

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
        if not self._assert_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("assert_facts_batch service not available.")
            return False
        req = StringArray.Request()
        req.data = facts
        future = self._assert_client.call_async(req)
        return self._wait_future(future, timeout_sec=5.0) and future.result().successful

    def _trigger_planning(self) -> bool:
        if not self._planning_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("start_planning service not available.")
            return False
        future = self._planning_client.call_async(Trigger.Request())
        return self._wait_future(future, timeout_sec=5.0) and future.result().success

    def _wait_future(self, future, timeout_sec: float) -> bool:
        deadline = time.monotonic() + timeout_sec
        while rclpy.ok() and not future.done() and time.monotonic() < deadline:
            time.sleep(0.01)
        return future.done() and future.result() is not None

    def destroy_node(self) -> None:
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
