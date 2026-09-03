import unittest
from pathlib import Path


QML = (Path(__file__).parents[1] / "BarWidget.qml").read_text()


class DoubleTakeCliTest(unittest.TestCase):
    def test_uses_supported_pairing_flag(self):
        self.assertIn('command.push("-pair", "-pin", pairCode)', QML)

    def test_does_not_use_removed_flags(self):
        self.assertNotIn('"-code"', QML)
        self.assertNotIn('"-video-codec"', QML)


if __name__ == "__main__":
    unittest.main()
