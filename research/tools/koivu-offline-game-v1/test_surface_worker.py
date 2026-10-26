"""Actual native NavigationSurface tests on authored schema fixtures only."""
import json,math,os,subprocess,unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
MODE='offline-known-phone-map-game-v1'

def point(x,y,z):return {'x':x,'y':y,'z':z}

def run_case(change=None, start=(1,0,1), goal=(2,0,1)):
    cells=[{'floor':0,'clearance':2.,'blocked':False,'floorUncertainty':None} for _ in range(1600)]
    if change:
        for i in range(len(cells)):change(cells[i],i%40,i//40)
    surface={'level':'offline-game','origin':point(0,0,0),'resolution':.1,'width':40,'depth':40,'cells':cells}
    body={'radius':math.hypot(.45,.30)/2*math.sqrt(2),'height':1.6,'margin':.15}
    initialize={'mode':MODE,'command':'initialize','surface':surface,'body':body}
    query={'mode':MODE,'command':'validateLegs','legs':[{'from':point(*start),'to':point(*goal)}]}
    env=os.environ.copy();env['LD_LIBRARY_PATH']=str(HERE.parent/'blind-navigation-recorded/build-06')
    p=subprocess.run([str(HERE/'build/surface-worker')],input='\n'.join(map(json.dumps,[initialize,query]))+'\n',
                     text=True,capture_output=True,env=env,timeout=3)
    if p.returncode:raise AssertionError(p.stderr)
    rows=[json.loads(v) for v in p.stdout.splitlines()]
    for r in rows:
        assert not r['physicalAuthority'] and not r['physicalOwnerHasLocalizationEvidence'] and not r['physicalOwnerHasCurrentPose']
    return rows[-1]['permits'][0]


class SurfaceWorkerTests(unittest.TestCase):
    def test_declared_level_game_model_fit(self):self.assertTrue(run_case())
    def test_unknown_floor_blocks(self):
        self.assertFalse(run_case(lambda c,x,z:c.update(floor=None) if x==15 else None))
    def test_unknown_vertical_clearance_blocks(self):
        self.assertFalse(run_case(lambda c,x,z:c.update(clearance=None) if x==15 else None))
    def test_positive_obstacle_blocks(self):
        self.assertFalse(run_case(lambda c,x,z:c.update(blocked=True) if x==15 else None))
    def test_head_clearance_blocks(self):
        self.assertFalse(run_case(lambda c,x,z:c.update(clearance=1.7)))
    def test_positive_floor_uncertainty_is_not_flattened(self):
        self.assertFalse(run_case(lambda c,x,z:c.update(floorUncertainty=.01)))
    def test_nonlevel_geometry_not_tolerated(self):
        self.assertFalse(run_case(lambda c,x,z:c.update(floor=.001) if x==15 else None))
    def test_body_footprint_must_fit_start(self):
        self.assertFalse(run_case(start=(.3,0,1)))


if __name__=='__main__':unittest.main(verbosity=2)
