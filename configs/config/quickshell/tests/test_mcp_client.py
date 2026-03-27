import os
import pathlib
import sys
import tempfile
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import mcp_client  # noqa: E402


class McpClientTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.server_path = pathlib.Path(self.tmp.name) / "fake_mcp_server.py"
        self.server_path.write_text(
            textwrap.dedent(
                """
                import json
                import sys

                for raw in sys.stdin:
                    req = json.loads(raw)
                    method = req.get("method")
                    req_id = req.get("id")

                    if method == "initialize":
                        print(json.dumps({
                            "jsonrpc": "2.0",
                            "id": req_id,
                            "result": {
                                "protocolVersion": "2024-11-05",
                                "capabilities": {"tools": {}},
                                "serverInfo": {"name": "fake-mcp", "version": "1.0"}
                            }
                        }), flush=True)
                    elif method == "notifications/initialized":
                        continue
                    elif method == "tools/list":
                        print(json.dumps({
                            "jsonrpc": "2.0",
                            "id": req_id,
                            "result": {
                                "tools": [
                                    {"name": "web_search"},
                                    {"name": "lookup_current_time"},
                                ]
                            }
                        }), flush=True)
                    elif method == "tools/call":
                        params = req.get("params", {})
                        print(json.dumps({
                            "jsonrpc": "2.0",
                            "id": req_id,
                            "result": {
                                "echo": params.get("name"),
                                "arguments": params.get("arguments", {})
                            }
                        }), flush=True)
                    else:
                        print(json.dumps({
                            "jsonrpc": "2.0",
                            "id": req_id,
                            "error": {"code": -32601, "message": f"Unknown method: {method}"}
                        }), flush=True)
                """
            ),
            encoding="utf-8",
        )
        self.old_command = os.environ.get("AI_WEB_MCP_COMMAND")
        os.environ["AI_WEB_MCP_COMMAND"] = f"{sys.executable} {self.server_path}"

    def tearDown(self):
        if self.old_command is None:
            os.environ.pop("AI_WEB_MCP_COMMAND", None)
        else:
            os.environ["AI_WEB_MCP_COMMAND"] = self.old_command
        self.tmp.cleanup()

    def test_lists_tools_from_server(self):
        tools = mcp_client.list_tools()
        names = [item.get("name") for item in tools]
        self.assertIn("web_search", names)
        self.assertIn("lookup_current_time", names)

    def test_has_tool_uses_server_discovery(self):
        self.assertTrue(mcp_client.has_tool("web_search"))
        self.assertFalse(mcp_client.has_tool("missing_tool"))

    def test_call_tool_round_trips_arguments(self):
        result = mcp_client.call_tool("web_search", {"query": "hola", "max_results": 3})
        self.assertEqual(result["echo"], "web_search")
        self.assertEqual(result["arguments"]["query"], "hola")
        self.assertEqual(result["arguments"]["max_results"], 3)


if __name__ == "__main__":
    unittest.main()
