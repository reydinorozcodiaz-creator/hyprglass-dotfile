import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SYS_AGENT_PATH = ROOT / "scripts" / "agents" / "sys-agent.py"


def load_module():
    spec = importlib.util.spec_from_file_location("sys_agent", SYS_AGENT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class SysAgentHelpersTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sys_agent = load_module()

    def test_compute_cpu_usage_returns_expected_percentage(self):
        usage = self.sys_agent.compute_cpu_usage(100, 40, 180, 70)
        self.assertEqual(usage, 62)

    def test_compute_net_rates_handles_elapsed_time(self):
        rx_rate, tx_rate = self.sys_agent.compute_net_rates(1000, 500, 1800, 1100, 2)
        self.assertEqual(rx_rate, 400)
        self.assertEqual(tx_rate, 300)

    def test_compute_net_rates_handles_zero_elapsed(self):
        rx_rate, tx_rate = self.sys_agent.compute_net_rates(1000, 500, 1800, 1100, 0)
        self.assertEqual(rx_rate, 0)
        self.assertEqual(tx_rate, 0)


if __name__ == "__main__":
    unittest.main()
