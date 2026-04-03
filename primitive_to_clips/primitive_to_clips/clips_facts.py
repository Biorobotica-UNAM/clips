"""
Concrete CLIPS fact builders — one class per CD primitive type.

Each class inherits from ClipsFact and overrides _extract_slots()
to pull the relevant fields for its primitive type.

To add a new primitive:
  1. Create a new class here inheriting from ClipsFact.
  2. Register it in ClipsFactFactory._BUILDERS.
  No other code needs to change.

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

from typing import Any, Dict
from primitive_to_clips.clips_fact import ClipsFact


# ── Movement ─────────────────────────────────────────────────────────────────


class PtransFact(ClipsFact):
    """
    PTRANS — robot moves to a location.
    Relevant fields: actor, to (destination).
    Object is typically unknown for navigation commands.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["to"] = self._sym(primitive.get("to", "unknown"))
        return slots


class AtransFact(ClipsFact):
    """
    ATRANS — robot transfers an object to a location or person.
    Relevant fields: actor, object, from (origin), to (destination).
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["object"] = self._sym(primitive.get("object", "unknown"))
        slots["from"] = self._sym(primitive.get("from", "unknown"))
        slots["to"] = self._sym(primitive.get("to", "unknown"))
        return slots


class AccompanyFact(ClipsFact):
    """
    ACCOMPANY — robot escorts a person from one place to another.
    Relevant fields: actor, object (person), from, to.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["object"] = self._sym(primitive.get("object", "unknown"))
        slots["from"] = self._sym(primitive.get("from", "unknown"))
        slots["to"] = self._sym(primitive.get("to", "unknown"))
        return slots


# ── Manipulation ─────────────────────────────────────────────────────────────


class GraspFact(ClipsFact):
    """
    GRASP — robot physically grasps an object.
    Relevant fields: actor, object.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["object"] = self._sym(primitive.get("object", "unknown"))
        return slots


# ── Perception ───────────────────────────────────────────────────────────────


class AttendFact(ClipsFact):
    """
    ATTEND — robot searches for or perceives an object or person.
    Relevant fields: actor, object, location.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["object"] = self._sym(primitive.get("object", "unknown"))
        slots["location"] = self._sym(primitive.get("location", "unknown"))
        return slots


# ── Communication ─────────────────────────────────────────────────────────────


class MtransFact(ClipsFact):
    """
    MTRANS — robot communicates information to a recipient.
    Relevant fields: actor, content, to (recipient).
    Content goes into the 'content' slot, not 'object'.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["content"] = self._sym(primitive.get("content", "unknown"))
        slots["to"] = self._sym(primitive.get("to", "user"))
        return slots


class SpeakFact(ClipsFact):
    """
    SPEAK — robot says something without a specific recipient.
    Relevant fields: actor, content.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["content"] = self._sym(primitive.get("content", "unknown"))
        return slots


# ── Cognition ────────────────────────────────────────────────────────────────


class MbuildFact(ClipsFact):
    """
    MBUILD — robot builds or infers internal knowledge.
    Relevant fields: actor, content.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        slots["content"] = self._sym(primitive.get("content", "unknown"))
        return slots


# ── Social ───────────────────────────────────────────────────────────────────


class SocialFact(ClipsFact):
    """
    SOCIAL — robot performs a social interaction with a person.
    Relevant fields: actor, object (target person), location.
    Note: 'target' from the primitive maps to 'object' in the template.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        # 'target' is the field name used by the semantic parser for SOCIAL
        slots["object"] = self._sym(primitive.get("target", "unknown"))
        slots["location"] = self._sym(primitive.get("location", "unknown"))
        return slots


# ── Control ──────────────────────────────────────────────────────────────────


class WaitFact(ClipsFact):
    """
    WAIT — robot waits until a condition is met.
    Relevant fields: actor, object (condition).
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        slots = self._base_slots(primitive)
        # 'condition' from the primitive maps to 'object' in the template
        slots["object"] = self._sym(primitive.get("condition", "unknown"))
        return slots


# ── Fallback ─────────────────────────────────────────────────────────────────


class DoFact(ClipsFact):
    """
    DO — fallback for unmapped verbs.
    Preserves whatever fields are available.
    """

    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        return self._base_slots(primitive)
