"""
ROS2 node that converts CD primitives to CLIPS facts and
triggers the planning engine.

Components:
    WorldStateLoader    — loads initial world state from YAML
    ClipsFactFactory    — Factory Method: creates CLIPS facts by primitive type
    PrimitiveToClips    — ROS2 node (thin, only handles communication)

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

#!/usr/bin/env python3

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

import rclpy
import yaml
from rclpy.node import Node
from clips_interfaces.srv import String as StringSrv
from clips_interfaces.srv import StringArray
from std_srvs.srv import Trigger

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
# World State Loader
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
        self._world_loader = self._build_world_loader()

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

    def _build_world_loader(self) -> WorldStateLoader:
        """
        Find and return a WorldStateLoader for the world_state.yaml file.

        Search paths (in order):
          1. Same directory as this file
          2. src/Planning/clips/primitive_to_clips/primitive_to_clips/
        """
        search_paths = [
            Path(__file__).parent / self._WORLD_STATE_FILE,
            Path(os.getcwd())
            / "src"
            / "Planning"
            / "clips"
            / "primitive_to_clips"
            / "primitive_to_clips"
            / self._WORLD_STATE_FILE,
        ]
        for path in search_paths:
            if path.exists():
                self.get_logger().info(f"World state loaded from: {path}")
                return WorldStateLoader(path)

        self.get_logger().warning(
            f"{self._WORLD_STATE_FILE} not found. "
            "No initial world state will be injected into CLIPS."
        )
        return WorldStateLoader(Path("nonexistent.yaml"))

    # ──────────────────────────────────────────────────────────────────────────
    # Service callback
    # ──────────────────────────────────────────────────────────────────────────

    def _handle_convert(self, request, response):
        """
        ROS2 service callback.

        Flow:
          1. Parse the incoming JSON list of CD primitives.
          2. Build world state facts from YAML.
          3. Build cd-primitive facts using the factory.
          4. Send all facts to clips/assert_facts_batch.
          5. Trigger clips/start_planning.
        """
        primitives = self._parse_request(request.data)
        if primitives is None:
            response.data = "ERROR: invalid JSON"
            return response

        self.get_logger().info(f"Received {len(primitives)} CD primitives.")

        world_facts = self._world_loader.load()
        primitive_facts = self._build_primitive_facts(primitives)
        all_facts = world_facts + primitive_facts

        if not primitive_facts:
            response.data = "ERROR: no valid primitives to assert"
            return response

        success = self._assert_facts(all_facts)
        if not success:
            response.data = "ERROR: clips/assert_facts_batch not available"
            return response

        triggered = self._trigger_planning()
        if not triggered:
            response.data = "ERROR: clips/start_planning not available"
            return response

        response.data = (
            f"OK: {len(world_facts)} world facts + "
            f"{len(primitive_facts)} primitive facts asserted, "
            f"planning triggered."
        )
        return response

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
        self._assert_client.call_async(request)
        return True

    def _trigger_planning(self) -> bool:
        """Trigger the CLIPS planning engine. Returns False if unavailable."""
        if not self._planning_client.wait_for_service(timeout_sec=3.0):
            self.get_logger().error("clips/start_planning not available.")
            return False
        self._planning_client.call_async(Trigger.Request())
        return True


# ============================================================


def main(args=None) -> None:
    rclpy.init(args=args)
    node = PrimitiveToClips()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
