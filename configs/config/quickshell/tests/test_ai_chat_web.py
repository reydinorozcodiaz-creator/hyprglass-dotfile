import unittest
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import ai_chat


class AiChatWebHeuristicsTests(unittest.TestCase):
    def test_live_web_required_for_currency_today_query(self):
        self.assertTrue(ai_chat.query_needs_live_web("en cuanto esta el dolar en colombia hoy"))
        self.assertTrue(ai_chat.query_needs_live_web("what is the current usd cop exchange rate today"))

    def test_live_web_not_required_for_general_code_question(self):
        self.assertFalse(ai_chat.query_needs_live_web("explica este codigo qml"))
        self.assertFalse(ai_chat.query_needs_live_web("como mejorar esta arquitectura"))

    def test_small_talk_does_not_trigger_web_tools(self):
        self.assertFalse(ai_chat.query_should_use_web_tools("hola"))
        self.assertFalse(ai_chat.query_should_use_web_tools("gracias"))

    def test_explicit_web_request_triggers_web_tools(self):
        self.assertTrue(ai_chat.query_should_use_web_tools("busca en internet mejores teclados"))
        self.assertTrue(ai_chat.query_should_use_web_tools("dame fuentes sobre Wayland"))

    def test_live_time_query_triggers_web_tools(self):
        self.assertTrue(ai_chat.query_needs_live_time("que hora es en bogota"))
        self.assertTrue(ai_chat.query_should_use_web_tools("que hora es en bogota"))

    def test_prepend_live_web_instruction_only_when_context_used(self):
        messages = [{"role": "user", "content": "hola"}]
        untouched = ai_chat.prepend_live_web_instruction(messages, True, {"used": False})
        self.assertEqual(untouched, messages)

        enriched = ai_chat.prepend_live_web_instruction(messages, True, {"used": True})
        self.assertEqual(enriched[0]["role"], "system")
        self.assertIn("tiempo real", enriched[0]["content"])


if __name__ == "__main__":
    unittest.main()
