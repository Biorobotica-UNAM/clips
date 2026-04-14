"""
Client for the /world/get_state ROS2 service.

Replaces WorldStateLoader (which read from disk) with a live call
to the knowledge_manager node, implementing the Blackboard pattern.

Responsibility (SRP): query the world state over ROS2 and convert
the JSON response to CLIPS assert_strings. No file I/O, no YAML.

Design notes:
    DIP  — depends on the /world/get_state service interface, not on
           any specific node implementation behind it.
    OCP  — the CLIPS fact format is unchanged; only the data source
           changes (disk -> ROS2 service).

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from rclpy.node import Node
from rclpy.callback_groups import MutuallyExclusiveCallbackGroup
from rclpy.executors import Executor
from knowledge_interfaces.srv import GetWorldState


class WorldStateClient:
    """
    Queries the knowledge_manager node for the current world state
    and converts it to CLIPS assert_strings.

    This class is a drop-in replacement for WorldStateLoader.
    The public interface is identical: load() returns List[str].

    Threading note:
        load() is called from inside a ROS2 service callback
        (PrimitiveToClips._handle_convert). Calling
        rclpy.spin_until_future_complete() from inside a callback
        raises "Executor is already spinning".

        The fix: create the service client in its own
        MutuallyExclusiveCallbackGroup and call the future with
        executor.spin_until_future_complete(), which is safe to
        call from within a callback of a different group.
    """

    _SERVICE_NAME = "/world/get_state"
    _TIMEOUT_SEC = 3.0

    def __init__(self, node: Node, executor: Executor) -> None:
        """
        Args:
            node:     The parent ROS2 node (PrimitiveToClips).
            executor: The executor that is spinning the node.
                      Used to drive the future without nested spin.
        """
        self._node = node
        self._executor = executor
        # A dedicated callback group isolates this client from the
        # node's main callback group, which allows the executor to
        # process our future while already inside another callback.
        self._cb_group = MutuallyExclusiveCallbackGroup()
        self._client = node.create_client(
            GetWorldState,
            self._SERVICE_NAME,
            callback_group=self._cb_group,
        )

    def load(self) -> List[str]:
        """
        Fetch the current world state and return CLIPS assert_strings.

        Returns an empty list (never raises) if the service is
        unavailable or returns malformed data. The caller can safely
        proceed with zero world facts.
        """
        if not self._client.wait_for_service(timeout_sec=self._TIMEOUT_SEC):
            self._node.get_logger().warning(
                f"{self._SERVICE_NAME} not available. "
                "Planning will proceed without world state."
            )
            return []

        future = self._client.call_async(GetWorldState.Request())
        response = self._wait_for_future(future)

        if response is None:
            return []

        return self._json_to_clips_facts(response.json)

    # ──────────────────────────────────────────────────────────────────────────
    # Private helpers
    # ──────────────────────────────────────────────────────────────────────────

    def _wait_for_future(self, future) -> Optional[Any]:
        """
        Drive the future to completion via the shared executor.

        Using executor.spin_until_future_complete() instead of
        rclpy.spin_until_future_complete() avoids the "Executor is
        already spinning" error because the executor processes the
        future's callback group without trying to re-acquire its lock.
        """
        try:
            self._executor.spin_until_future_complete(
                future, timeout_sec=self._TIMEOUT_SEC
            )
            return future.result()
        except Exception as exc:
            self._node.get_logger().error(
                f"Service call to {self._SERVICE_NAME} failed: {exc}"
            )
            return None

    def _json_to_clips_facts(self, json_str: str) -> List[str]:
        """Convert the JSON world state to CLIPS assert_strings."""
        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as exc:
            self._node.get_logger().error(
                f"WorldStateClient: invalid JSON from service: {exc}"
            )
            return []

        facts: List[str] = []
        facts.extend(self._build_robot_fact(data.get("robot", {})))
        facts.extend(self._build_object_facts(data.get("objects", [])))
        return facts

    def _build_robot_fact(self, robot: Dict[str, Any]) -> List[str]:
        """Build the (robot-state ...) CLIPS fact."""
        if not robot:
            return []
        room = self._sym(robot.get("room", "unknown"))
        holding = self._sym(robot.get("holding", "nothing"))
        return [f"(robot-state (room {room}) (holding {holding}))"]

    def _build_object_facts(self, objects: List[Dict]) -> List[str]:
        """Build one (object-state ...) CLIPS fact per known object."""
        facts = []
        for obj in objects:
            name = self._sym(obj.get("name", "unknown"))
            room = self._sym(obj.get("room", "unknown"))
            facts.append(f"(object-state (name {name}) (room {room}))")
        return facts

    @staticmethod
    def _sym(value: Any) -> str:
        """Convert a value to a valid CLIPS symbol (no spaces)."""
        if not value or str(value).strip().lower() == "unknown":
            return "unknown"
        return "_".join(str(value).strip().lower().split())
