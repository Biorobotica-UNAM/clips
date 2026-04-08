"""
Abstract base class for CLIPS fact builders.

Implements the Factory Method pattern:
each subclass knows how to build the CLIPS assert_string
for one specific CD primitive type.

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

from abc import ABC, abstractmethod
from typing import Any, Dict


class ClipsFact(ABC):
    """
    Abstract base class for a CLIPS fact builder.

    Responsibility: define the contract that every concrete
    fact builder must fulfill.

    Each subclass represents one CD primitive type and knows
    exactly which slots to populate in the cd-primitive template.

    Public API:
        build(step, primitive) -> str

    All helper methods are private implementation details.
    """

    def build(self, step: int, primitive: Dict[str, Any]) -> str:
        """
        Build the CLIPS assert_string for this primitive.

        Args:
            step:      The step number in the execution plan (1-based).
            primitive: The CD primitive dict from the semantic parser.

        Returns:
            A string ready to be passed to env.assert_string() in CLIPS.
            Example:
                "(cd-primitive (step 1) (primitive ATTEND)
                               (actor robot) (object a_snack)
                               (from unknown) (to unknown)
                               (location the_kitchen) (content unknown))"
        """
        slots = self._extract_slots(primitive)
        return self._format_fact(step, slots)

    @abstractmethod
    def _extract_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        """
        Extract and normalize the relevant slots for this primitive type.

        Each subclass overrides this to pull only the fields it needs
        from the primitive dict and convert them to CLIPS symbols.

        Args:
            primitive: The CD primitive dict.

        Returns:
            Dict with keys: actor, object, from, to, location, content.
            All values are valid CLIPS symbols (no spaces).
        """
        ...

    def _format_fact(self, step: int, slots: Dict[str, str]) -> str:
        """
        Format the final CLIPS assert_string from step and slots.

        The cd-primitive template always has the same structure.
        This method is shared by all subclasses — they only differ
        in how they fill the slots.
        """
        return (
            f"(cd-primitive"
            f" (step {step})"
            f" (primitive {slots['primitive']})"
            f" (actor {slots['actor']})"
            f" (object {slots['object']})"
            f" (from {slots['from']})"
            f" (to {slots['to']})"
            f" (location {slots['location']})"
            f" (content {slots['content']})"
            f")"
        )

    def _sym(self, value: Any) -> str:
        """
        Convert any value to a valid CLIPS symbol.

        CLIPS symbols cannot contain spaces. This method replaces
        spaces with underscores and lowercases the result.

        None and "unknown" both map to the symbol 'unknown'.

        Examples:
            "a snack"          → "a_snack"
            "the living room"  → "the_living_room"
            None               → "unknown"
            "unknown"          → "unknown"
        """
        if not value or str(value).strip().lower() == "unknown":
            return "unknown"
        return "_".join(str(value).strip().lower().split())

    def _base_slots(self, primitive: Dict[str, Any]) -> Dict[str, str]:
        """
        Extract the common slots shared by all primitive types.

        Subclasses call this and then override only the slots
        that are specific to their primitive type.
        """
        return {
            "primitive": primitive.get("primitive", "DO"),
            "actor": self._sym(primitive.get("actor", "robot")),
            "object": self._sym(primitive.get("object", "unknown")),
            "from": self._sym(primitive.get("from", "unknown")),
            "to": self._sym(primitive.get("to", "unknown")),
            "location": self._sym(primitive.get("location", "unknown")),
            "content": self._sym(primitive.get("content", "unknown")),
        }
