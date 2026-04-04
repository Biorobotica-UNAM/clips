"""
ROS2 node for CLIPS-based robot task planning.

Responsibility: expose ROS2 services and coordinate the
planning pipeline. Contains no CLIPS logic — delegates
everything to ClipsEngine, RuleLoader, and PlanExtractor.

Services exposed:
    clips/start_planning     (std_srvs/Trigger)
    clips/assert_fact        (clips_interfaces/String)
    clips/assert_facts_batch (clips_interfaces/StringArray)

Topics published:
    clips/results            (std_msgs/String)

Design patterns applied:
    Facade        — ClipsEngine hides clips.Environment
    SRP           — four classes, four responsibilities
    Clean Code    — no bare except, no magic strings,
                    no hardcoded debug prints

BioRobotics Laboratory, Facultad de Ingenieria, UNAM
"""

import os
import queue
import threading
from pathlib import Path
from typing import List

import clips
import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from std_srvs.srv import Trigger
from clips_interfaces.srv import String as StringSrv
from clips_interfaces.srv import StringArray

from clips_node.clips_engine import ClipsEngine
from clips_node.clips_components import RuleLoader, PlanExtractor


# ============================================================
# Plan Logger
# ============================================================


class PlanLogger:
    """
    Writes the generated plan to a log file.

    Responsibility: persist the plan to disk for debugging
    and post-execution analysis.

    Searches for a writable log directory in known workspace paths.
    Creates the file if it does not exist.
    """

    _LOG_FILENAME = "plan_execution.log"

    _SEARCH_PATHS = (
        Path("src") / "Knowledge" / "knowledge_bank",
        Path("src") / "Planning" / "clips",
        Path("src") / "clips",
        Path("clips"),
    )

    def __init__(self, logger=None) -> None:
        self._logger = logger
        self._path = self._find_or_create_log_path()

    def initialize(self) -> None:
        """Clear the log file at node startup."""
        try:
            with open(self._path, "w", encoding="utf-8") as f:
                f.write("")
            if self._logger:
                self._logger.info(f"Plan log initialized: {self._path}")
        except OSError as e:
            if self._logger:
                self._logger.error(f"Could not initialize log file: {e}")

    def write(self, text: str) -> None:
        """Append text to the log file."""
        try:
            with open(self._path, "a", encoding="utf-8") as f:
                f.write(text + "\n")
        except OSError as e:
            if self._logger:
                self._logger.error(f"Could not write to log file: {e}")

    def _find_or_create_log_path(self) -> Path:
        """
        Find an existing log directory or use the first available path.
        Creates the log file if the directory exists but the file does not.
        """
        cwd = Path(os.getcwd())
        for relative_path in self._SEARCH_PATHS:
            candidate_dir = cwd / relative_path
            if candidate_dir.exists():
                return candidate_dir / self._LOG_FILENAME
        # Fallback: use cwd
        return cwd / self._LOG_FILENAME


# ============================================================
# CLIPS Node
# ============================================================


class ClipsNode(Node):
    """
    ROS2 node that exposes the CLIPS planning engine as services.

    Responsibility: handle ROS2 communication and coordinate
    the planning pipeline through the worker thread.

    This class contains no CLIPS logic. All CLIPS interactions
    are delegated to ClipsEngine via RuleLoader and PlanExtractor.

    The worker thread ensures that all CLIPS operations are
    sequential — CLIPS is not thread-safe.
    """

    _ROBOT_NAME = "Justina"
    _START_FACT = "(start (task-name action-planning))"
    _RESULTS_TOPIC = "clips/results"

    def __init__(self) -> None:
        super().__init__("clips_node")
        self.get_logger().info("Initializing CLIPS planning node...")

        self._engine = ClipsEngine()
        self._loader = RuleLoader(self._engine, self.get_logger())
        self._extractor = PlanExtractor(self._engine, self.get_logger())
        self._plan_log = PlanLogger(self.get_logger())
        self._current_plan: List[str] = []

        self._publisher = self.create_publisher(String, self._RESULTS_TOPIC, 10)
        self._task_queue = queue.Queue()
        self._worker = threading.Thread(target=self._worker_loop, daemon=True)

        self._create_services()
        self._load_rules()
        self._plan_log.initialize()
        self._worker.start()

        self.get_logger().info("CLIPS planning node ready.")

    # ──────────────────────────────────────────────────────────────────────────
    # Initialization helpers
    # ──────────────────────────────────────────────────────────────────────────

    def _create_services(self) -> None:
        """Register all ROS2 services."""
        self.create_service(
            Trigger,
            "clips/start_planning",
            self._handle_start_planning,
        )
        self.create_service(
            StringSrv,
            "clips/assert_fact",
            self._handle_assert_fact,
        )
        self.create_service(
            StringArray,
            "clips/assert_facts_batch",
            self._handle_assert_facts_batch,
        )

    def _load_rules(self) -> None:
        """Load CLIPS rules at startup."""
        success = self._loader.load()
        if not success:
            self.get_logger().error(
                "Failed to load CLIPS rules. "
                "Check rules_list.dat and workspace paths."
            )

    # ──────────────────────────────────────────────────────────────────────────
    # Worker thread
    # ──────────────────────────────────────────────────────────────────────────

    def _worker_loop(self) -> None:
        """
        Process tasks sequentially in a dedicated thread.

        CLIPS is not thread-safe — all environment interactions
        must happen in this single worker thread.
        """
        while rclpy.ok():
            task = self._task_queue.get()
            if task is None:
                break
            try:
                task()
            except Exception as e:
                self.get_logger().error(f"Worker error: {e}")
            finally:
                self._task_queue.task_done()

    def _enqueue(self, task) -> None:
        """Add a task to the worker queue."""
        self._task_queue.put(task)

    # ──────────────────────────────────────────────────────────────────────────
    # Service callbacks
    # ──────────────────────────────────────────────────────────────────────────

    def _handle_start_planning(self, request, response):
        """
        Reset CLIPS and start a new planning cycle.

        Called by primitive_to_clips after asserting all facts.
        Inserts the (start ...) trigger that activates gpsr-initialize.
        """

        def task():
            self._current_plan.clear()
            self._engine.assert_fact(self._START_FACT)
            self._run_and_collect_plan()

        self._enqueue(task)
        response.success = True
        response.message = "Planning started."
        return response

    def _handle_assert_fact(self, request, response):
        """Assert a single fact and run the engine."""

        def task():
            self._engine.assert_fact(request.data)
            self._run_and_collect_plan()

        self._enqueue(task)
        response.data = "Fact received."
        return response

    def _handle_assert_facts_batch(self, request, response):
        """Assert multiple facts and run the engine."""

        def task():
            self._engine.assert_facts(request.data)
            self._run_and_collect_plan()

        self._enqueue(task)
        response.successful = True
        return response

    # ──────────────────────────────────────────────────────────────────────────
    # Planning pipeline
    # ──────────────────────────────────────────────────────────────────────────

    def _run_and_collect_plan(self) -> None:
        """
        Run the CLIPS inference engine and collect the plan if ready.

        The plan is considered ready when ros-message facts exist
        in working memory after the engine run.
        """
        fired = self._engine.run()
        self.get_logger().info(f"Rules fired: {fired}")

        for fact in self._engine._env.facts():
            if fact.template.name in ("ros-message", "action-step", "sub-task"):
                self.get_logger().info(f"FACT: {fact}")

        has_messages = bool(self._engine.get_facts_by_template("ros-message"))
        if has_messages:
            self._collect_and_publish_plan()

    def _collect_and_publish_plan(self) -> None:
        """Extract the plan from CLIPS and publish it."""
        plan = self._extractor.extract()
        if not plan:
            return

        self._current_plan = plan
        self._publish_plan()

    def _publish_plan(self) -> None:
        """
        Publish the current plan to /clips/results.

        Appends a final 'test_completed' step so the supervisor
        knows the plan has ended.
        """
        steps = "\n".join(self._current_plan)
        final_step = (
            f"\nPaso {len(self._current_plan) + 1}: "
            f"{self._ROBOT_NAME} say test_completed"
        )
        full_plan = steps + final_step

        msg = String()
        msg.data = full_plan
        self._publisher.publish(msg)
        self._plan_log.write(full_plan)

        self.get_logger().info(f"Plan published: {len(self._current_plan)} steps.")

    # ──────────────────────────────────────────────────────────────────────────
    # Shutdown
    # ──────────────────────────────────────────────────────────────────────────

    def destroy_node(self) -> None:
        """Gracefully shut down the worker thread before destroying the node."""
        self._task_queue.put(None)
        self._worker.join()
        super().destroy_node()


# ============================================================


def main(args=None) -> None:
    rclpy.init(args=args)
    node = ClipsNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()
