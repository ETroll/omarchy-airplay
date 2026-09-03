import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
QML = (ROOT / "BarWidget.qml").read_text()
PANEL = (ROOT / "Panel.qml").read_text()
RUNNER = (ROOT / "bin" / "omarchy-airplay-run").read_text()


class DoubleTakeCliTest(unittest.TestCase):
    def test_keeps_pairing_code_out_of_process_arguments(self):
        self.assertIn('command.push("DOUBLETAKE_CODE=" + pairCode)', QML)
        self.assertIn('command.push("-pair")', QML)
        self.assertNotIn('"-code", pairCode', QML)

    def test_uses_current_video_codec_flag(self):
        self.assertIn('"-video-codec"', QML)

    def test_accepts_pin_or_configured_password(self):
        self.assertIn("maximumLength: 128", PANEL)
        self.assertIn("echoMode: TextInput.Password", PANEL)
        self.assertNotIn("Qt.ImhDigitsOnly", PANEL)
        self.assertIn("pairingCode.text.length > 0", PANEL)

    def test_authentication_error_reopens_credentials(self):
        self.assertIn("var credentialRequired =", QML)
        self.assertIn("root.pairingPromptActive = true", QML)
        self.assertIn('"\\n\\nDoubleTake: " + diagnostic', QML)

    def test_configured_password_does_not_force_pin_pairing(self):
        self.assertIn('pairCode !== "" && !root.configuredPasswordRequired', QML)
        self.assertIn("root.configuredPasswordRequired = passwordRequired", QML)

    def test_runner_disables_interactive_password_prompt(self):
        self.assertIn("stdin=subprocess.DEVNULL", RUNNER)


if __name__ == "__main__":
    unittest.main()
