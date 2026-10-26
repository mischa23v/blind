from pathlib import Path
import sys,unittest
import approach_episode
class GroundOwnerTests(unittest.TestCase):
    def test_ground_helper_is_frozen_v3(self):
        expected=Path(__file__).resolve().parents[1]/'ground-follow-v3/ground_support.py'
        self.assertEqual(Path(sys.modules[approach_episode.GroundSupport.__module__].__file__).resolve(),expected)
