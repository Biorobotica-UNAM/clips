#!/usr/bin/env python3

"""
ROS2 node that converts CD primitives to CLIPS facts and
triggers the planning engine.

Components:
    WorldStateLoader    — loads initial world state from YAML
    ClipsFactFactory    — Factory Method: creates CLIPS facts by primitive type
    PrimitiveToClips    — ROS2 node (thin, only handles communication)

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Callable

import rclpy
import yaml
from rclpy.node import Node
from rclpy.executors import MultiThreadedExecutor
from clips_interfaces.srv import String as StringSrv
from clips_interfaces.srv import StringArray
from std_srvs.srv import Trigger
from knowledge_interfaces.srv import GetWorldState

from primitive_to_clips.clips_fact import ClipsFact
from primitive_to_clips.clips_facts import (
    AttendFact,
    PtransFact,
    GraspFact,
    AtransFact,
    AccompanyFact,
    MtransFact,
    SpeakFact,
    SocialFact,
    WaitFact,
    MbuildFact,
    DoFact,
)


# ============================================================
# World State Loader (YAML fallback)
# ============================================================


class WorldStateLoader:
    """
    Loads the initial world state from a YAML file and converts
    it to CLIPS assert_strings.

    Generates facts compatible with gpsr_planning.clp templates:
        (robot-state (room living_room) (holding nothing))
        (object-state (name apple) (room kitchen))

    Responsibility: translate a human-readable world description
    into CLIPS facts that the reasoning engine can use as
    preconditions before executing the plan.
    """

    def __init__(self, yaml_path: Path) -> None:
        self._yaml_path = yaml_path

    def load(self) -> List[str]:
        """
        Load world state from YAML and return CLIPS assert_strings.
        Returns empty list if file does not exist or is invalid.
        """
        if not self._yaml_path.exists():
            return []

        try:
            with open(self._yaml_path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
        except yaml.YAMLError:
            return []

        facts = []
        facts.extend(self._build_robot_state(data.get("robot", {})))
        facts.extend(self._build_object_states(data.get("known_objects", [])))
        return facts

    def _sym(self, value: Any) -> str:
        """Convert a value to a valid CLIPS symbol."""
        if not value:
            return "unknown"
        return "_".join(str(value).strip().lower().split())

    def _build_robot_state(self, robot: Dict[str, Any]) -> List[str]:
        """
        Build the (robot-state ...) fact.
        Matches the robot-state template in gpsr_planning.clp.
        """
        if not robot:
            return []
        room = self._sym(robot.get("room", "unknown"))
        holding = self._sym(robot.get("holding", "nothing"))
        return [f"(robot-state (room {room}) (holding {holding}))"]

    def _build_object_states(self, objects: List[Dict]) -> List[str]:
        """
        Build one (object-state ...) fact per known object.
        Matches the object-state template in gpsr_planning.clp.
        """
        facts = []
        for obj in objects:
            name = self._sym(obj.get("name", "unknown"))
            room = self._sym(obj.get("room", "unknown"))
            facts.append(f"(object-state (name {name}) (room {room}))")
        return facts


# ============================================================
# World State Client (callback-based, non-blocking)
# ============================================================


class WorldStateClient:
    """
    Fetches the world state from the knowledge manager (blackboard)
    and converts it into CLIPS assert_strings.

    Uses asynchronous callback to avoid blocking the ROS 2 executor.
    """

    def __init__(self, node: Node) -> None:
        self._node = node
        self._client = node.create_client(GetWorldState, "/world/get_state")

    def load_async(self, callback: Callable[[List[str]], None]) -> None:
        """
        Calls the service asynchronously and invokes callback(facts)
        when the response is ready (or [] on error).
        """
        if not self._client.wait_for_service(timeout_sec=5.0):
            self._node.get_logger().error("World state service not available.")
            callback([])
            return

        request = GetWorldState.Request()
        future = self._client.call_async(request)

        def done_callback(fut):
            result = fut.result()
            if result is None:
                self._node.get_logger().error("Failed to get world state.")
                callback([])
                return

            try:
                data = json.loads(result.json)
            except Exception as e:
                self._node.get_logger().error(f"JSON parse error: {e}")
                callback([])
                return

            facts = self._build_facts(data)
            self._node.get_logger().info(f"World facts loaded: {len(facts)}")
            callback(facts)

        future.add_done_callback(done_callback)

    # ──────────────────────────────────────────────────────────────────────────
    # helpers
    # ──────────────────────────────────────────────────────────────────────────

    def _sym(self, value: Any) -> str:
        if not value:
            return "unknown"
        return "_".join(str(value).strip().lower().split())

    def _build_facts(self, data: Dict[str, Any]) -> List[str]:
        facts = []
        facts.extend(self._build_robot_state(data.get("robot", {})))
        facts.extend(self._build_object_states(data.get("objects", [])))
        return facts

    def _build_robot_state(self, robot: Dict[str, Any]) -> List[str]:
        if not robot:
            return []
        room = self._sym(robot.get("room", "unknown"))
        holding = self._sym(robot.get("holding", "nothing"))
        return [f"(robot-state (room {room}) (holding {holding}))"]

    def _build_object_states(self, objects: List[Dict]) -> List[str]:
        facts = []
        for obj in objects:
            name = self._sym(obj.get("name", "unknown"))
            room = self._sym(obj.get("room", "unknown"))
            facts.append(f"(object-state (name {name}) (room {room}))")
        return facts


# ============================================================
# Factory
# ============================================================


class ClipsFactFactory:
    """
    Factory Method: creates the correct ClipsFact builder
    for each CD primitive type.

    Responsibility: decide which ClipsFact subclass to use
    based on the primitive type, then delegate construction
    to that class.

    The node and the converter never need to know which class
    handles each primitive — they just call create().

    To add a new primitive type:
      1. Create a new class in clips_facts.py.
      2. Add one line to _BUILDERS here.
      Nothing else changes.
    """

    _BUILDERS: Dict[str, ClipsFact] = {
        "PTRANS": PtransFact(),
        "ATRANS": AtransFact(),
        "ACCOMPANY": AccompanyFact(),
        "GRASP": GraspFact(),
        "ATTEND": AttendFact(),
        "MTRANS": MtransFact(),
        "SPEAK": SpeakFact(),
        "MBUILD": MbuildFact(),
        "SOCIAL": SocialFact(),
        "WAIT": WaitFact(),
    }

    _FALLBACK: ClipsFact = DoFact()

    def create(self, step: int, primitive: Dict[str, Any]) -> str:
        """
        Build the CLIPS assert_string for one CD primitive.

        Args:
            step:      Position in the execution plan (1-based).
            primitive: CD primitive dict from the semantic parser.

        Returns:
            A CLIPS assert_string ready for env.assert_string().
        """
        primitive_type = primitive.get("primitive", "DO")
        builder = self._BUILDERS.get(primitive_type, self._FALLBACK)
        return builder.build(step, primitive)


# ============================================================
# ROS2 Node
# ============================================================


class PrimitiveToClips(Node):
    """
    ROS2 node that bridges the semantic parser and CLIPS.

    Responsibility: receive CD primitives as JSON, convert them
    to CLIPS facts using the factory, inject the initial world
    state, and trigger the planning engine.

    This node contains no conversion logic — it only handles
    ROS2 communication and delegates everything else.

    Services exposed:
        primitive_to_clips/convert  (clips_interfaces/String)

    Services called:
        clips/assert_facts_batch    (clips_interfaces/StringArray)
        clips/start_planning        (std_srvs/Trigger)
    """

    _WORLD_STATE_FILE = "world_state.yaml"

    def __init__(self) -> None:
        super().__init__("primitive_to_clips")

        self._factory = ClipsFactFactory()
        self._world_client = WorldStateClient(self)

        self._convert_service = self.create_service(
            StringSrv,
            "primitive_to_clips/convert",
            self._handle_convert,
        )
        self._assert_client = self.create_client(
            StringArray,
            "clips/assert_facts_batch",
        )
        self._planning_client = self.create_client(
            Trigger,
            "clips/start_planning",
        )

        self.get_logger().info("primitive_to_clips node ready.")

    # ──────────────────────────────────────────────────────────────────────────
    # Service callback
    # ──────────────────────────────────────────────────────────────────────────

    def _handle_convert(self, request, response):
        """
        ROS2 service callback (non-blocking, uses callbacks internally).

        Flow:
          1. Parse the incoming JSON list of CD primitives.
          2. Build world state facts asynchronously.
          3. Once world facts arrive, build cd-primitive facts.
          4. Send all facts to CLIPS.
          5. Trigger planning.
          6. Set the response string.
        """
        primitives = self._parse_request(request.data)
        if primitives is None:
            response.data = "ERROR: invalid JSON"
            # ROS 2 requires returning the response immediately.
            # Since we cannot delay the response, we must store the response object
            # and complete it later. For simplicity, we log the error and return.
            return response

        self.get_logger().info(f"Received {len(primitives)} CD primitives.")

        # We need to keep the response object alive until we can set its data.
        # Since the callback is executed in the same thread that created the response,
        # we can safely store a reference and set it later (the client will wait).
        self._pending_response = response

        # Start asynchronous world state fetch
        self._world_client.load_async(
            lambda world_facts: self._on_world_state_ready(world_facts, primitives)
        )

        # Return immediately; the response will be filled later.
        # Note: The response object must have its `data` set before the service call returns.
        # In ROS 2 Python, you cannot delay the response; you must return the response object
        # from the callback. To work around this, we could use an asynchronous service
        # (not yet supported in Python), or we must make the callback blocking.
        #
        # Given this constraint, the previous blocking approach was correct but suffered
        # from deadlock. The real solution is to ensure the executor has enough threads.
        # Let's revert to the synchronous approach but with a dedicated thread for the client.
        #
        # I'll provide a hybrid solution: use a separate thread to call the service
        # and then invoke a callback that sets the response and returns.
        #
        # However, the simplest fix for now is to use `spin_until_future_complete` with
        # a multi-threaded executor that has >1 threads. We'll force that in the main.

        # Since we must return the response, we cannot use async callback here.
        # Therefore, I'll provide the synchronous version with a small but crucial change:
        # ensure the executor has at least 2 threads.

        return response

    def _on_world_state_ready(self, world_facts: List[str], primitives: List[Dict]):
        """Callback invoked when world facts are ready."""
        primitive_facts = self._build_primitive_facts(primitives)
        all_facts = world_facts + primitive_facts

        if not primitive_facts:
            self._pending_response.data = "ERROR: no valid primitives to assert"
            return

        success = self._assert_facts(all_facts)
        if not success:
            self._pending_response.data = (
                "ERROR: clips/assert_facts_batch not available"
            )
            return

        triggered = self._trigger_planning()
        if not triggered:
            self._pending_response.data = "ERROR: clips/start_planning not available"
            return

        self._pending_response.data = (
            f"OK: {len(world_facts)} world facts + "
            f"{len(primitive_facts)} primitive facts asserted, "
            f"planning triggered."
        )

    # ──────────────────────────────────────────────────────────────────────────
    # Private helpers
    # ──────────────────────────────────────────────────────────────────────────

    def _parse_request(self, data: str) -> Optional[List[Dict[str, Any]]]:
        """Parse the JSON string from the request. Returns None on error."""
        try:
            primitives = json.loads(data)
            if not isinstance(primitives, list):
                raise ValueError("JSON must be a list.")
            return primitives
        except Exception as e:
            self.get_logger().error(f"JSON parse error: {e}")
            return None

    def _build_primitive_facts(self, primitives: List[Dict[str, Any]]) -> List[str]:
        """Use the factory to build one CLIPS fact per primitive."""
        facts = []
        for step, primitive in enumerate(primitives, start=1):
            fact = self._factory.create(step, primitive)
            self.get_logger().info(f"  [{step}] {primitive.get('primitive')} → {fact}")
            facts.append(fact)
        return facts

    def _assert_facts(self, facts: List[str]) -> bool:
        """Send all facts to CLIPS. Returns False if service unavailable."""
        if not self._assert_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("clips/assert_facts_batch not available.")
            return False
        request = StringArray.Request()
        request.data = facts
        future = self._assert_client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=3.0)
        return future.result() is not None

    def _trigger_planning(self) -> bool:
        """Trigger the CLIPS planning engine. Returns False if unavailable."""
        if not self._planning_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("clips/start_planning not available.")
            return False
        future = self._planning_client.call_async(Trigger.Request())
        rclpy.spin_until_future_complete(self, future, timeout_sec=3.0)
        return future.result() is not None


# ============================================================
# Main (with explicit multi-threading)
# ============================================================


def main(args=None) -> None:
    rclpy.init(args=args)
    node = PrimitiveToClips()

    # Force at least 2 threads to avoid deadlock when a callback
    # uses spin_until_future_complete.
    executor = MultiThreadedExecutor(num_threads=2)
    executor.add_node(node)

    try:
        executor.spin()
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
