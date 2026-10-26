"""Profile-bound A-to-B wrapper; the frozen controller owns unchanged tick logic."""
from pathlib import Path
import hashlib,json,sys
import numpy as np
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
sys.path.insert(0,str(GAME/'source'))
from pilot_controller import Controller
sys.path.insert(0,str(GAME/'three-lap-executor-09'))
from profile_map import open_profile_map,variants

def load_plan(path,digest):
    p=Path(path)
    if p.stat().st_size>8*1024**2:raise ValueError('approach artifact size cap')
    raw=p.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('frozen phone approach changed')
    plan=json.loads(raw)
    if plan.get('status')!='selectedPhoneOnlyApproach'or plan.get('referenceInputsUsed')is not False or plan.get('physicalAuthority')is not False:
        raise ValueError('no complete frozen phone-only approach')
    radius=.125 if plan.get('proposalAttempt')=='proposal0125Fallback'else None
    if plan['geometry']!=variants.geometry(plan['profile'],radius):raise ValueError('numerical profile mismatch')
    for name in ('start','goal'):Controller.point(plan[name])
    route=plan['nativeInitialRoute']
    if route.get('complete')is not True or not route.get('points')or route.get('mapRevision')!=plan['mapRevision']:
        raise ValueError('complete map-associated native route required')
    if not np.isfinite(plan['initialYawRadians']):raise ValueError('finite initial yaw required')
    return plan

class ApproachController(Controller):
    def __init__(self,factory=open_profile_map,loader=load_plan):
        super().__init__();self.factory=factory;self.loader=loader;self.plan=None
    def consume(self,p):
        if p.get('command')=='initialize':
            if self.model is not None or set(p)!={'command','planPath','planSHA256','nativeDirectory','nativeSHA256'}:raise ValueError('approach initialization contract')
            self.plan=self.loader(p['planPath'],p['planSHA256'])
            if self.plan['nativeLibrarySHA256']!=p['nativeSHA256']:raise ValueError('native plan identity')
            radius=.125 if self.plan.get('proposalAttempt')=='proposal0125Fallback'else None
            self.model=self.factory(self.plan['profile'],p['nativeDirectory'],p['nativeSHA256'],radius);self.revision=self.model.revision
            if self.revision!=self.plan['mapRevision']:
                self.close();raise ValueError('plan/profile map revision mismatch')
            return {'physicalAuthority':False,'status':'importedFrozenPhoneApproach','mapRevision':self.revision,'profile':self.plan['profile'],'approachID':self.plan['approachID']}
        if p.get('command')=='beginRun':
            if self.plan is None or not np.array_equal(self.point(p['goal']),self.point(self.plan['goal'])):raise ValueError('only predeclared phone goal accepted')
        return super().consume(p)

if __name__=='__main__':
    c=ApproachController()
    try:
        for line in sys.stdin:
            if len(line)>1024**2:raise ValueError('packet cap')
            print(json.dumps(c.consume(json.loads(line)),allow_nan=False),flush=True)
    finally:c.close()
