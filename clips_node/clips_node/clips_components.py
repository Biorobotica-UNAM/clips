"""
Supporting components for the CLIPS planning node.

Classes:
    RuleLoader    — finds and loads rules from rules_list.dat
    PlanExtractor — reads ros-message facts and builds the plan

Design principles applied:
    SRP   — each class has exactly one reason to change
    OCP   — new rule search paths can be added without modifying
            existing logic
    Clean Code — intention-revealing names, no magic strings

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

import os
from pathlib import Path
from typing import List, Optional, Tuple

from clips_node.clips_engine import ClipsEngine


# ============================================================
# Rule Loader
# ============================================================


class RuleLoader:
    """
    Finds and loads CLIPS rule files from rules_list.dat.

    Responsibility: locate the rules_list.dat file in the
    workspace and load each enabled rule file into the engine.

    Lines starting with '#' are treated as comments and skipped.
    Relative paths in rules_list.dat are resolved relative to
    the directory containing the .dat file itself.

    Search paths for rules_list.dat (in order):
      1. <cwd>/clips/clips_node/clips_rules/rules_list.dat
      2. <cwd>/src/Planning/clips/clips_node/clips_rules/rules_list.dat
    """

    _DAT_FILENAME = "rules_list.dat"

    _SEARCH_PATHS: Tuple[Path, ...] = (
        Path("clips") / "clips_node" / "clips_rules",
        Path("src") / "Planning" / "clips" / "clips_node" / "clips_rules",
        Path("src") / "clips" / "clips_node" / "clips_rules",
    )

    def __init__(self, engine: ClipsEngine, logger=None) -> None:
        self._engine = engine
        self._logger = logger

    def load(self) -> bool:
        """
        Find rules_list.dat and load all enabled rule files.

        Returns:
            True if rules were loaded successfully, False otherwise.
        """
        dat_path = self._find_dat_file()
        if dat_path is None:
            self._log_error("rules_list.dat not found in any search path.")
            return False

        rule_files = self._parse_dat_file(dat_path)
        for rule_file in rule_files:
            self._engine.load(str(rule_file))
            self._log_info(f"Loaded: {rule_file.name}")

        self._engine.reset()
        self._log_info(f"Rules loaded from: {dat_path}")
        return True

    def _find_dat_file(self) -> Optional[Path]:
        """Search for rules_list.dat across known workspace paths."""
        cwd = Path(os.getcwd())
        for relative_path in self._SEARCH_PATHS:
            candidate = cwd / relative_path / self._DAT_FILENAME
            if candidate.exists():
                return candidate
        return None

    def _parse_dat_file(self, dat_path: Path) -> List[Path]:
        """
        Read rules_list.dat and return absolute paths of enabled files.

        Skips empty lines and lines starting with '#'.
        Resolves relative paths relative to the .dat file's directory.
        """
        rule_files = []
        rules_dir = dat_path.parent

        with open(dat_path, "r", encoding="utf-8") as f:
            for line in f:
                clp_path = line.strip()
                if not clp_path or clp_path.startswith("#"):
                    continue
                resolved = Path(clp_path)
                if not resolved.is_absolute():
                    resolved = rules_dir / resolved
                if resolved.exists():
                    rule_files.append(resolved)
                else:
                    self._log_error(f"Rule file not found: {resolved}")

        return rule_files

    def _log_info(self, message: str) -> None:
        if self._logger:
            self._logger.info(message)

    def _log_error(self, message: str) -> None:
        if self._logger:
            self._logger.error(message)


# ============================================================
# Plan Extractor
# ============================================================


class PlanExtractor:
    """
    Reads ros-message facts from CLIPS and builds the plan list.

    Responsibility: translate CLIPS facts into a human-readable
    plan that can be published to /clips/results.

    The plan is a list of strings, one per step:
        "Paso 1: Justina goto kitchen"
        "Paso 2: Justina find apple"
        "==Justina GPSR_START=="

    Design note: this class reads plan-note facts but does NOT
    retract them — only ros-message facts are retracted after
    extraction to allow CLIPS to detect plan completion.
    """

    _ROBOT_FALLBACK = "Justina"

    def __init__(self, engine: ClipsEngine, logger=None) -> None:
        self._engine = engine
        self._logger = logger

    def extract(self) -> List[str]:
        """
        Extract the current plan from CLIPS working memory.
        ros-message facts are sorted by step before building the plan.
        """
        plan_notes = []
        ros_messages = []
        facts_to_retract = []

        for fact in self._engine._env.facts():
            template_name = fact.template.name

            if template_name == "ros-message":
                step_line = self._format_ros_message(fact)
                if step_line:
                    try:
                        step = fact["step"]
                    except Exception:
                        step = 999
                    ros_messages.append((step, step_line))
                    facts_to_retract.append(fact)

            elif template_name == "plan-note":
                note_line = self._format_plan_note(fact)
                if note_line:
                    plan_notes.append(note_line)

        for fact in facts_to_retract:
            fact.retract()

        # Ordenar por step antes de construir el plan
        ros_messages.sort(key=lambda x: x[0])
        start_notes = [n for n in plan_notes if "START" in n]
        done_notes = [n for n in plan_notes if "DONE" in n]
        other_notes = [n for n in plan_notes if "START" not in n and "DONE" not in n]

        # Construir el plan
        plan = []
        plan.extend(start_notes)
        plan.extend(line for _, line in ros_messages)
        plan.extend(other_notes)
        plan.extend(done_notes)

        return plan

    def _format_ros_message(self, fact) -> Optional[str]:
        """
        Format a ros-message fact as a plan step string.

        Tries the structured format (step + robot + action + params)
        and falls back to a simpler format if slots are missing.
        """
        try:
            step = fact["step"]
            robot = fact["robot"]
            action = fact["action"]
            params = " ".join(str(p) for p in fact["params"])
            return f"Paso {step}: {robot} {action} {params}".strip()
        except Exception:
            try:
                step = fact["step"]
                content = fact["content"]
                return f"Paso {step}: {self._ROBOT_FALLBACK} {content}"
            except Exception as e:
                if self._logger:
                    self._logger.error(f"Could not format ros-message: {e}")
                return None

    def _format_plan_note(self, fact) -> Optional[str]:
        """Format a plan-note fact as an annotation line."""
        try:
            robot = fact["robot"]
            state = fact["state"]
            return f"=={robot} {state}=="
        except Exception as e:
            if self._logger:
                self._logger.error(f"Could not format plan-note: {e}")
            return None
