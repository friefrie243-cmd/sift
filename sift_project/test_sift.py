import unittest
from sift.core.detector import ObfuscatorDetector
from sift.core.ironbrew import IronBrewDeobfuscator
from sift.config import Config

class TestSiftCore(unittest.TestCase):
    def test_detector_luraph(self):
        sample_code = "-- Luraph script v11.4\nlocal a = 1"
        self.assertEqual(ObfuscatorDetector.detect(sample_code), "Luraph")

    def test_detector_moonsec(self):
        sample_code = "-- This file was protected with MoonSec V3\nlocal env = _ENV"
        self.assertEqual(ObfuscatorDetector.detect(sample_code), "Moonsec")

    def test_detector_unknown(self):
        sample_code = "local hello = 'world'"
        self.assertEqual(ObfuscatorDetector.detect(sample_code), "Unknown/None")

    def test_ironbrew_static_string_decrypt(self):
        # A mock IronBrew v2 script with base64 encoded strings
        sample_code = 'local strings = { "SGVsbG8=", "V29ybGQ=" }\nprint("SGVsbG8=")'
        success, refactored, decrypted = IronBrewDeobfuscator.decrypt_ib2_strings(sample_code)
        self.assertTrue(success)
        self.assertIn("Hello", decrypted)
        self.assertIn("World", decrypted)
        # Check replacement
        self.assertIn('"Hello"', refactored)

if __name__ == "__main__":
    unittest.main()
