import runpy
import unittest
from pathlib import Path


CTL = runpy.run_path(
    Path(__file__).parents[1] / "bin" / "omarchy-airplay-ctl"
)
avahi_unescape = CTL["avahi_unescape"]


class AvahiUnescapeTest(unittest.TestCase):
    def test_decodes_utf8_octets(self):
        self.assertEqual(avahi_unescape(r"B\195\188ro"), "Büro")

    def test_decodes_ascii_escape(self):
        self.assertEqual(avahi_unescape(r"Living\032Room"), "Living Room")

    def test_preserves_unescaped_unicode(self):
        self.assertEqual(avahi_unescape("日本語"), "日本語")

    def test_preserves_out_of_range_escape(self):
        self.assertEqual(avahi_unescape(r"Room\999"), r"Room\999")


if __name__ == "__main__":
    unittest.main()
