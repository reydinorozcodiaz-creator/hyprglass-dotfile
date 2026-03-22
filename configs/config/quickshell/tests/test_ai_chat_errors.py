import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "ai"))

import ai_chat


class AiChatErrorRewritingTests(unittest.TestCase):
    def test_model_not_supported_detection(self):
        message = "HTTP 400: The requested model is not supported."
        lowered = message.lower()
        self.assertIn("model is not supported", lowered)


if __name__ == "__main__":
    unittest.main()
