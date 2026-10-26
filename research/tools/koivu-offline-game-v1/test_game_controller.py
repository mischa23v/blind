import copy,hashlib,json,math,tempfile,unittest
from pathlib import Path
from game_controller import Controller
from game_model import PhoneModel,surface_triangles,follow_candidate


class NativeStub:
    def permits(self,legs):return [True]*len(legs)
class ModelStub:
    revision='fixed-phone-model'
    native=NativeStub()
    def route(self,start,goal):return {'complete':True,'points':[goal.tolist()]}


class ControllerBoundaryTests(unittest.TestCase):
    def ready(self):
        c=Controller();c.model=ModelStub();c.consume({'command':'beginRun','runID':'one','goal':[3,0,0]});return c
    def packet(self,tick=0,now=100.,pose=True):
        p={'kind':'simulated-kinematic-body-pose','runID':'one','tick':tick,'capturedAt':now,
           'position':[1,0,0],'yaw':0.,'mapRevision':'fixed-phone-model'}
        return {'command':'physicsTick','runID':'one','tick':tick,'now':now,'deliveredPose':p if pose else None}
    def test_original_simulated_capture_owns_freshness(self):
        c=self.ready();first=c.consume(self.packet());self.assertEqual(first['forwardMetres'],.02)
        row=c.consume(self.packet(1,100.6,False));self.assertEqual(row['reason'],'staleSimulatedPose')
        self.assertEqual(row['sourceCapturedAt'],100.);self.assertEqual(row['forwardMetres'],0)
    def test_previous_run_pose_cannot_cross_new_owner(self):
        c=self.ready();c.consume({'command':'beginRun','runID':'two','goal':[3,0,0]})
        p=self.packet();p['runID']='two'
        with self.assertRaises(ValueError):c.consume(p)
    def test_future_pose_tick_rejected(self):
        c=self.ready();p=self.packet();p['deliveredPose']['tick']=1
        with self.assertRaises(ValueError):c.consume(p)
    def test_clock_regression_rejected(self):
        c=self.ready();c.consume(self.packet())
        with self.assertRaises(ValueError):c.consume(self.packet(1,99.,False))
    def test_reference_fields_not_accepted(self):
        c=self.ready();p=self.packet();p['FAROContact']=False
        with self.assertRaises(ValueError):c.consume(p)
    def test_route_follower_has_no_teleport(self):
        f,y,_=follow_candidate([0,0,0],0.,[[10,0,0]])
        self.assertEqual(f,.02);self.assertEqual(y,0.)
        f,y,_=follow_candidate([0,0,0],0.,[[0,0,10]])
        self.assertEqual(f,0.);self.assertEqual(y,math.radians(1))
    def test_surface_resolution_is_frozen(self):
        with self.assertRaises(ValueError):surface_triangles({'width':1,'depth':1,'resolution':.2,'cells':[]})


class RealNativeModelTests(unittest.TestCase):
    def test_actual_detour_and_surface_with_unknown_cell_holes(self):
        cells=[{'floor':0,'clearance':1.75,'blocked':False,'floorUncertainty':None} for _ in range(1600)]
        value={'level':'authored-component-fixture','origin':{'x':0,'y':0,'z':0},'resolution':.1,'width':40,'depth':40,'cells':cells}
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'surface.json';p.write_text(json.dumps(value));h=hashlib.sha256(p.read_bytes()).hexdigest()
            m=PhoneModel(p,h)
            try:
                route=m.route([1,0,1],[3,0,1]);self.assertTrue(route['complete'])
                self.assertTrue(all(q[1]==0 for q in route['points']))
                self.assertTrue(m.native.permits([([1,0,1],[1.02,0,1])])[0])
            finally:m.close()
            for z in range(40):cells[z*40+20]['clearance']=None
            p.write_text(json.dumps(value));h=hashlib.sha256(p.read_bytes()).hexdigest();m=PhoneModel(p,h)
            try:
                self.assertFalse(m.route([1,0,1],[3,0,1])['complete'])
                self.assertFalse(m.native.permits([([1,0,1],[3,0,1])])[0])
            finally:m.close()


if __name__=='__main__':unittest.main(verbosity=2)
