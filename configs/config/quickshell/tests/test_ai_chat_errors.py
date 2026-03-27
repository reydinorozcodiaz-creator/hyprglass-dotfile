import pathlib
import sys
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import ai_chat


class AiChatErrorRewritingTests(unittest.TestCase):
    def test_model_not_supported_detection(self):
        message = "HTTP 400: The requested model is not supported."
        lowered = message.lower()
        self.assertIn("model is not supported", lowered)

    def test_friendly_network_error_for_dns_failure(self):
        message = ai_chat.friendly_network_error("Temporary failure in name resolution")
        self.assertIn("DNS", message)
        self.assertIn("conectividad", message)

    def test_handle_list_mcp_tools_normalizes_response(self):
        fake_tools = [
            {
                "name": "search_codebase",
                "description": "Search text in a local codebase.",
                "inputSchema": {"type": "object", "required": ["pattern"]},
            },
            {
                "name": "git_status",
            },
        ]

        fake_session = mock.MagicMock()
        fake_session.__enter__.return_value = fake_session
        fake_session.list_tools.return_value = fake_tools

        with mock.patch.object(ai_chat.mcp_client, "McpSession", return_value=fake_session):
            with mock.patch.object(ai_chat, "emit") as emit_mock:
                ai_chat.handle_list_mcp_tools({})

        emit_mock.assert_called_once_with(
            {
                "ok": True,
                "tools": [
                    {
                        "name": "search_codebase",
                        "description": "Search text in a local codebase.",
                        "inputSchema": {"type": "object", "required": ["pattern"]},
                    },
                    {
                        "name": "git_status",
                        "description": "",
                        "inputSchema": {},
                    },
                ],
            }
        )


if __name__ == "__main__":
    unittest.main()
