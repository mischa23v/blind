from pathlib import Path
import sys,profile_reference as d
root=Path.cwd().parent
assert Path(d.plane_support_height.__code__.co_filename).resolve()==root/'ground-follow-v3/run_ground_pilot.py'
assert Path(sys.modules[d.v3.GroundSupport.__module__].__file__).resolve()==root/'ground-follow-v3/ground_support.py'
assert Path(d.shared_ground.__code__.co_filename).resolve()==root/'camera-approach-executor-14/ground_setup.py'
assert Path(sys.modules[d.GroundOBBReferenceContainer.__module__].__file__).resolve()==root/'ground-obb-v6/oriented_ground_obb_container.py'
assert Path(sys.modules[d.ProfiledGroundOBBReferenceContainer.__module__].__file__).resolve()==Path.cwd()/'profiled_v6.py'
assert d.TICKS==(0,9,15,28,30,45,60,75,90,106)
print('PASS: fresh driver import and exact physics/setup/scorer module owners; main not called')
