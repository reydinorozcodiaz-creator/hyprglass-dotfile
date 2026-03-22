import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLEAR_UNPINNED_PATH = ROOT / "scripts" / "tools" / "clear-unpinned.py"


def load_module():
    spec = importlib.util.spec_from_file_location("clear_unpinned", CLEAR_UNPINNED_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ClearUnpinnedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.clear_unpinned = load_module()

    def test_load_pinned_reads_new_state_path_format(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_file = Path(tmp) / "state.json"
            state_file.write_text(
                json.dumps({"clipboard": {"pinned": ["uno", "dos"]}}),
                encoding="utf-8",
            )
            previous = self.clear_unpinned.STATE_FILE
            self.clear_unpinned.STATE_FILE = str(state_file)
            try:
                self.assertEqual(self.clear_unpinned.load_pinned(), {"uno", "dos"})
            finally:
                self.clear_unpinned.STATE_FILE = previous


if __name__ == "__main__":
    unittest.main()
