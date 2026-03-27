import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import mcp_server_tools  # noqa: E402


class McpServerToolsTests(unittest.TestCase):
    def test_tool_list_contains_requested_tools(self):
        names = {item["name"] for item in mcp_server_tools.tool_list()}
        self.assertTrue(
            {
                "read_path",
                "search_codebase",
                "git_status",
                "git_diff",
                "git_log",
                "search_docs",
                "fetch_url",
                "read_logs",
                "get_system_status",
                "get_package_stats",
                "web_search",
                "lookup_current_time",
            }.issubset(names)
        )

    def test_search_codebase_finds_matches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            sample = root / "example.txt"
            sample.write_text("Orbit MCP search target\n", encoding="utf-8")
            result = mcp_server_tools.handle_call(
                "search_codebase",
                {"pattern": "Orbit MCP", "root": str(root), "max_results": 10},
            )
            self.assertFalse(result["isError"])
            self.assertIn("Orbit MCP search target", result["content"][0]["text"])

    def test_git_status_reads_repository(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)
            (root / "tracked.txt").write_text("hello\n", encoding="utf-8")
            result = mcp_server_tools.handle_call("git_status", {"path": str(root)})
            self.assertFalse(result["isError"])
            self.assertIn("tracked.txt", result["content"][0]["text"])

    def test_fetch_url_reads_local_file_uri(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "page.html"
            path.write_text(
                "<html><head><title>Test Page</title></head><body><h1>Hello</h1><p>Orbit fetch works.</p></body></html>",
                encoding="utf-8",
            )
            result = mcp_server_tools.handle_call("fetch_url", {"url": path.as_uri()})
            self.assertFalse(result["isError"])
            text = result["content"][0]["text"]
            self.assertIn("Test Page", text)
            self.assertIn("Orbit fetch works", text)

    def test_search_docs_uses_curated_domains(self):
        with mock.patch.object(
            mcp_server_tools,
            "web_search",
            return_value=[{"title": "Doc", "url": "https://doc.qt.io", "snippet": "Qt docs"}],
        ) as patched:
            result = mcp_server_tools.handle_call(
                "search_docs",
                {"query": "signals and slots", "product": "qt", "max_results": 3},
            )
            self.assertFalse(result["isError"])
            patched.assert_called_once()
            args, kwargs = patched.call_args
            self.assertEqual(args[0], "signals and slots")
            self.assertIn("doc.qt.io", kwargs["domains"])
            self.assertIn("Documentation results", result["content"][0]["text"])

    def test_get_package_stats_reads_pacman_counts(self):
        with mock.patch.object(mcp_server_tools.shutil, "which", return_value="/usr/bin/pacman"):
            with mock.patch.object(
                mcp_server_tools,
                "_run_command",
                side_effect=[
                    (True, "pkg1\npkg2\npkg3"),
                    (True, "pkg1\npkg2"),
                    (True, "aur-one"),
                ],
            ):
                result = mcp_server_tools.handle_call(
                    "get_package_stats",
                    {"scope": "aur"},
                )

        self.assertFalse(result["isError"])
        text = result["content"][0]["text"]
        self.assertIn("AUR packages installed: 1", text)
        self.assertIn("aur-one", text)


if __name__ == "__main__":
    unittest.main()
