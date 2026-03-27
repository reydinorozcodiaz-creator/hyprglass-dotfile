import tempfile
import unittest
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import ai_agent_runtime  # noqa: E402


class PathPolicyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.allowed = self.base / "allowed"
        self.blocked = self.base / "blocked"
        self.allowed.mkdir()
        self.blocked.mkdir()
        (self.blocked / "secret.txt").write_text("secret", encoding="utf-8")
        (self.allowed / "link_out").symlink_to(self.blocked, target_is_directory=True)
        self.policy = ai_agent_runtime.PathPolicy(
            [str(self.allowed)],
            [str(self.blocked)],
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_existing_symlink_escape_is_blocked(self):
        ok, message = self.policy.validate_existing_path(
            str(self.allowed / "link_out" / "secret.txt")
        )
        self.assertFalse(ok)
        self.assertIn("blocked", message.lower())

    def test_target_symlink_escape_is_blocked(self):
        ok, message = self.policy.validate_target_path(
            str(self.allowed / "link_out" / "new.txt")
        )
        self.assertFalse(ok)
        self.assertIn("blocked", message.lower())


class AgentRuntimeSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.allowed = self.base / "Downloads"
        self.allowed.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def test_dangerous_tools_are_disabled_by_default(self):
        runtime = ai_agent_runtime.AgentRuntime(
            {
                "agentEnabled": True,
                "dangerousToolsEnabled": False,
                "toolAllowedRoots": [str(self.allowed)],
                "toolBlockedRoots": [],
                "messages": [
                    {
                        "role": "user",
                        "content": "descarga https://example.com/file.zip en "
                        + str(self.allowed),
                    }
                ],
            }
        )
        result = runtime.handle_turn()
        self.assertIsNotNone(result)
        self.assertIn("Dangerous local tools are disabled", result["content"])

    def test_detects_git_status_plan(self):
        runtime = ai_agent_runtime.AgentRuntime(
            {
                "agentEnabled": True,
                "dangerousToolsEnabled": False,
                "toolAllowedRoots": [str(self.allowed)],
                "toolBlockedRoots": [],
                "messages": [{"role": "user", "content": "git status en " + str(self.allowed)}],
            }
        )
        plan = runtime._detect_tool_plan("git status en " + str(self.allowed))
        self.assertIsNotNone(plan)
        self.assertEqual(plan["tool"], "git_status")

    def test_detects_docs_search_plan(self):
        runtime = ai_agent_runtime.AgentRuntime(
            {
                "agentEnabled": True,
                "dangerousToolsEnabled": False,
                "toolAllowedRoots": [str(self.allowed)],
                "toolBlockedRoots": [],
                "messages": [{"role": "user", "content": "busca docs de quickshell signals"}],
            }
        )
        plan = runtime._detect_tool_plan("busca docs de quickshell signals")
        self.assertIsNotNone(plan)
        self.assertEqual(plan["tool"], "search_docs")

    def test_detects_aur_package_stats_plan(self):
        runtime = ai_agent_runtime.AgentRuntime(
            {
                "agentEnabled": True,
                "dangerousToolsEnabled": False,
                "toolAllowedRoots": [str(self.allowed)],
                "toolBlockedRoots": [],
                "messages": [{"role": "user", "content": "oye cuantos paquetes de aur tengo instalado?"}],
            }
        )
        plan = runtime._detect_tool_plan("oye cuantos paquetes de aur tengo instalado?")
        self.assertIsNotNone(plan)
        self.assertEqual(plan["tool"], "get_package_stats")
        self.assertEqual(plan["args"]["scope"], "aur")


if __name__ == "__main__":
    unittest.main()
