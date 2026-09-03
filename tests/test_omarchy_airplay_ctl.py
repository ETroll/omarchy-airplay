import os
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


CTL = runpy.run_path(
    Path(__file__).parents[1] / "bin" / "omarchy-airplay-ctl"
)
avahi_unescape = CTL["avahi_unescape"]
main = CTL["main"]


class AvahiUnescapeTest(unittest.TestCase):
    def test_decodes_utf8_octets(self):
        self.assertEqual(avahi_unescape(r"B\195\188ro"), "Büro")

    def test_decodes_ascii_escape(self):
        self.assertEqual(avahi_unescape(r"Living\032Room"), "Living Room")

    def test_preserves_unescaped_unicode(self):
        self.assertEqual(avahi_unescape("日本語"), "日本語")

    def test_preserves_out_of_range_escape(self):
        self.assertEqual(avahi_unescape(r"Room\999"), r"Room\999")


class MissingCredentialsTest(unittest.TestCase):
    def test_clear_restore_before_first_pairing_is_a_noop(self):
        with tempfile.TemporaryDirectory() as config_home:
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": config_home}):
                with patch.object(sys, "argv", ["omarchy-airplay-ctl", "clear-restore", "AA:BB"]):
                    self.assertIsNone(main())


if __name__ == "__main__":
    unittest.main()
