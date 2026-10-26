from pathlib import Path
import sys,compare_reference as d
root=Path.cwd().parent
assert Path(d.plane_support_height.__code__.co_filename).resolve()==root/'ground-follow-v3/run_ground_pilot.py'
assert Path(sys.modules[d.v3.GroundSupport.__module__].__file__).resolve()==root/'ground-follow-v3/ground_support.py'
assert Path(d.shared_ground.__code__.co_filename).resolve()==root/'camera-approach-executor-14/ground_setup.py'
assert Path(sys.modules[d.GroundOBBReferenceContainer.__module__].__file__).resolve()==root/'ground-obb-v6/oriented_ground_obb_container.py'
assert Path(sys.modules[d.GroundTiledReferenceContainer.__module__].__file__).resolve()==Path.cwd()/'oriented_ground_tiled_container.py'
assert d.TICKS==(0,9,15,28,30,45,60,75,90,106)
import test_oriented_ground_obb_container as f
f.serial_vtk()
_,plain=f.pair(f.scene([[[0,.5,0],[.01,.5,0],[0,.5,.01]]]))
original=d.IdentityV6(plain.surface,plain.transform,ground=plain.ground)
optimized=d.GroundTiledReferenceContainer(plain.surface,plain.transform,ground=plain.ground)
corners=f.box_corners();expected=plain.contact_corners(corners)
assert original.contact_corners(corners)==expected==optimized.contact_corners(corners)
assert len(original.identity_rows)==len(optimized.optimization_rows)==1
assert original.identity_rows[0]['sortedCandidateIDsSHA256']==optimized.optimization_rows[0]['sortedCandidateIDsSHA256']
assert original.identity_seconds==original.identity_rows[0]['identityCaptureSeconds']>=0
assert original.box_queries==1 and optimized.box_queries==2
assert optimized.optimization_rows[0]['fallbackUsed'] and optimized.optimization_rows[0]['completed']
print('PASS: fresh driver owners; tiny authored IdentityV6 output/digest/capture timing boundary; recorded main not called')
