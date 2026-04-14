import pathlib
import sys
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import ai_chat


class AiChatOpenFangBridgeTests(unittest.TestCase):
    def test_normalize_base_url_adds_scheme_and_trims_slash(self):
        self.assertEqual(
            ai_chat.normalize_base_url("127.0.0.1:4200/"), "http://127.0.0.1:4200"
        )
        self.assertEqual(
            ai_chat.normalize_base_url("https://example.com///"), "https://example.com"
        )

    def test_friendly_network_error_for_dns_failure(self):
        message = ai_chat.friendly_network_error("Temporary failure in name resolution")
        self.assertIn("DNS", message)
        self.assertIn("conectividad", message)

    def test_resolve_agent_prefers_explicit_selection_even_if_not_ready(self):
        agents = [
            {"id": "a", "name": "assistant", "state": "Crashed", "ready": False},
            {"id": "b", "name": "General Assistant", "state": "Running", "ready": True},
        ]

        resolved = ai_chat.resolve_agent(agents, requested_id="a")
        self.assertEqual(resolved["id"], "a")

    def test_resolve_agent_falls_back_to_ready_general_assistant(self):
        agents = [
            {"id": "x", "name": "browser-hand", "state": "Running", "ready": True},
            {"id": "y", "name": "General Assistant", "state": "Running", "ready": True},
        ]

        resolved = ai_chat.resolve_agent(agents)
        self.assertEqual(resolved["id"], "y")

    def test_iter_sse_events_parses_named_events(self):
        stream = [
            b"event: chunk\n",
            b'data: {"content":"Hola"}\n',
            b"\n",
            b"event: done\n",
            b'data: {"done":true}\n',
            b"\n",
        ]

        self.assertEqual(
            list(ai_chat.iter_sse_events(stream)),
            [("chunk", '{"content":"Hola"}'), ("done", '{"done":true}')],
        )


if __name__ == "__main__":
    unittest.main()
