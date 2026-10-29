"""Standard-library source freeze only. Never imports SciPy/native or runs worker."""
import hashlib,json,pathlib,sys
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    inputs={}
    for name in ('selector.py','prepare_coffee.py','fixtures.py','run_aggregate.py','freeze.py'):
        p=H/name;inputs[str(p.relative_to(R))]=sha(p)
    canonical=R/'research/coffee-room-journey-recovery-20261029/collision-protocol/CURRENT_PATHS_20.json'
    inputs[str(canonical.relative_to(R))]=sha(canonical)
    diagnostic=R/'research/independent-2d-route-validator-20261029'
    for name in ('validator.py','proposal_windows.py','actual-coffee-0-to-8-attempt002/INPUT_FREEZE.json'):
        p=diagnostic/name;inputs[str(p.relative_to(R))]=sha(p)
    for lib in ('/lib/x86_64-linux-gnu/libgeos_c.so.1','/lib/x86_64-linux-gnu/libgeos.so.3.13.1'):
        p=pathlib.Path(lib).resolve();inputs[str(p)]=sha(p)
    replay=W/'coffee-native-replay-prepared-002'
    frozen=json.loads((replay/'blind-coffee-native-topology/FROZEN.json').read_text())
    for name,expected in frozen['sourceSHA256'].items():
        p=replay/name
        if sha(p)!=expected:raise ValueError('Coffee002 input differs: '+name)
        inputs['@WORKSPACE@/'+str(p.relative_to(W))]=expected
    for name in ('blind-coffee-native-topology/RESULT.json','blind-coffee-native-topology/FROZEN.json'):
        p=replay/name;inputs['@WORKSPACE@/'+str(p.relative_to(W))]=sha(p)
    bp=json.loads((R/'research/coffee-room-journey-recovery-20261029/collision-protocol/BODY_RUN_PINS.json').read_text())
    for name,digest in bp['inputs'].items():
        if name.startswith('/') and ('/numpy-' in name or '/scipy-' in name or name.endswith('/bin/python3.12')):
            if sha(pathlib.Path(name))!=digest:raise ValueError('runtime metadata changed')
            inputs[name]=digest
    py=str(pathlib.Path(sys.executable).resolve());inputs[py]=sha(pathlib.Path(py))
    manifest={'status':'SOURCE_FROZEN_AWAITING_ROOT_ADMISSION','inputs':inputs,
        'workRoot':'@WORKSPACE@/coffee-clearance-comparison-attempt-001',
        'controlsCommand':[py,'@PROTOCOL@/fixtures.py'],
        'comparisonCommand':[py,'@PROTOCOL@/prepare_coffee.py','--replay-root',
            '@WORKSPACE@/coffee-native-replay-prepared-002','--canonical-paths',
            '@PROTOCOL@/../coffee-room-journey-recovery-20261029/collision-protocol/CURRENT_PATHS_20.json','--out','@WORKSPACE@/coffee-clearance-comparison-attempt-001/comparison',
            '--pins-sha256','@PINS_SHA256@'],
        'limits':{'cpuSeconds':120,'wallSeconds':180,'observedAggregateRSSBytes':1024**3,'outputBytes':16*1024**2},
        'runtimeLimitations':'Existing Coffee002 native binary pinned; NumPy/SciPy distribution metadata pinned, not entire dynamic library closure. No compile/install. Source graph ranking, not full-body support or physical authority.'}
    (H/'SOURCE_PINS.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'inputs':len(inputs),'manifestSHA256':sha(H/'SOURCE_PINS.json')}))
if __name__=='__main__':main()
