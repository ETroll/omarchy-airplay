import unittest
from pathlib import Path


QML = (Path(__file__).parents[1] / "BarWidget.qml").read_text()


class DoubleTakeCliTest(unittest.TestCase):
    def test_keeps_pairing_code_out_of_process_arguments(self):
        self.assertIn('command.push("DOUBLETAKE_CODE=" + pairCode)', QML)
        self.assertIn('command.push("-pair")', QML)
        self.assertNotIn('"-code", pairCode', QML)

    def test_uses_current_video_codec_flag(self):
        self.assertIn('"-video-codec"', QML)


if __name__ == "__main__":
    unittest.main()
