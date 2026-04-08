"""
Facade over the CLIPS Environment.

Responsibility: hide all direct interactions with clips.Environment
behind a clean, intention-revealing interface.

No other class in this package should import clips.Environment directly.
If the underlying CLIPS library changes, only this file needs to change.

Design pattern: Facade
Principle:      Dependency Inversion — depend on this abstraction,
                not on clips.Environment directly.

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

from typing import Any, List
import clips


class ClipsEngine:
    """
    Facade over clips.Environment.

    Provides a clean, intention-revealing interface for:
      - Loading rule files
      - Asserting facts
      - Running the inference engine
      - Querying facts by template name

    Public API:
        load(path)
        reset()
        assert_fact(fact_string)
        assert_facts(fact_strings)
        run() -> int
        get_facts_by_template(template_name) -> list
        eval(expression) -> Any
    """

    def __init__(self) -> None:
        self._env = clips.Environment()
        self._env.clear()

    # ──────────────────────────────────────────────────────────────────────────
    # Rule loading
    # ──────────────────────────────────────────────────────────────────────────

    def load(self, path: str) -> None:
        """
        Load a CLIPS rule file into the environment.

        Args:
            path: Absolute path to the .clp file.
        """
        self._env.load(path)

    def reset(self) -> None:
        """
        Reset the CLIPS environment.

        Clears all facts from working memory while keeping
        loaded rules and templates intact.
        """
        self._env.reset()

    # ──────────────────────────────────────────────────────────────────────────
    # Fact assertion
    # ──────────────────────────────────────────────────────────────────────────

    def assert_fact(self, fact_string: str) -> None:
        """
        Assert a single fact into the CLIPS environment.

        Args:
            fact_string: A valid CLIPS assert string.
                         Example: "(robot-state (room kitchen))"
        """
        self._env.assert_string(fact_string)

    def assert_facts(self, fact_strings: List[str]) -> None:
        """
        Assert multiple facts into the CLIPS environment.

        Args:
            fact_strings: List of valid CLIPS assert strings.
        """
        for fact in fact_strings:
            self._env.assert_string(fact)

    # ──────────────────────────────────────────────────────────────────────────
    # Inference
    # ──────────────────────────────────────────────────────────────────────────

    def run(self) -> int:
        """
        Run the inference engine until the agenda is empty.

        Returns:
            Number of rules fired during this run.
        """
        return self._env.run()

    # ──────────────────────────────────────────────────────────────────────────
    # Fact queries
    # ──────────────────────────────────────────────────────────────────────────

    def get_facts_by_template(self, template_name: str) -> list:
        """
        Return all facts matching a given template name.

        Args:
            template_name: The deftemplate name to filter by.
                           Example: "ros-message"

        Returns:
            List of CLIPS fact objects matching the template.
        """
        return [
            fact for fact in self._env.facts() if fact.template.name == template_name
        ]

    def retract(self, fact) -> None:
        """
        Retract a single fact from the environment.

        Args:
            fact: A CLIPS fact object previously retrieved
                  via get_facts_by_template().
        """
        fact.retract()

    # ──────────────────────────────────────────────────────────────────────────
    # Debug
    # ──────────────────────────────────────────────────────────────────────────

    def eval(self, expression: str) -> Any:
        """
        Evaluate a CLIPS expression directly.

        Intended for debugging only. Do not use in production logic.

        Args:
            expression: A valid CLIPS expression string.
                        Example: "(watch rules)"
        """
        return self._env.eval(expression)
