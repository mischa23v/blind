"""Catch historical module-name/path collisions without loading any mesh."""
from pathlib import Path
import sys,unittest
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import run_approaches,approach_episode
class DriverImportTests(unittest.TestCase):
    def test_ground_motion_bound_to_exact_frozen_v3_file(self):
        expected=(HERE.parent/'ground-follow-v3/run_ground_pilot.py').resolve()
        for fn in (approach_episode.connected_support,approach_episode.plane_support_height,approach_episode.proposed_ground_motion):
            self.assertEqual(Path(fn.__code__.co_filename).resolve(),expected)
    def test_batch_owns_this_additive_episode_cut(self):
        self.assertEqual(Path(run_approaches.episode.__code__.co_filename).resolve(),HERE/'approach_episode.py')
if __name__=='__main__':unittest.main(verbosity=2)
