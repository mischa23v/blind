#!/usr/bin/env python3
"""Deterministic phone-only route selection. No reference geometry is imported."""
import argparse,json,math,random
from pathlib import Path
from game_model import PhoneModel,sha

HERE=Path(__file__).resolve().parent


def select(model):
    surface=model.surface;width=surface['width'];r=surface['resolution'];o=surface['origin']
    if r!=.1:raise ValueError('five-cell route lattice requires frozen10cm surface resolution')
    # Fixed half-metre lattice in surface-index coordinates, before any outcome.
    step=5;indices=[i for i in model.eligible if i%width%step==2 and (i//width)%step==2]
    points=[(o['x']+(i%width+.5)*r,0.,o['z']+(i//width+.5)*r) for i in indices]
    fits=[]
    for at in range(0,len(points),4096):
        batch=points[at:at+4096];fits.extend(model.native.permits([(p,p) for p in batch]))
    candidates=[(index,p) for index,p,fit in zip(indices,points,fits) if fit]
    if len(candidates)>2000:raise ValueError('route candidate cap; no silently changed lattice')
    pairs=[]
    for i,(ai,a) in enumerate(candidates):
        for j,(bi,b) in enumerate(candidates):
            distance=math.hypot(a[0]-b[0],a[2]-b[2])
            if 2<=distance<=6:pairs.append((i,j,distance))
    random.Random(271828).shuffle(pairs)
    routes=[]
    for number in range(20):
        if number>=len(pairs):
            routes.append({'routeID':number,'status':'insufficientPhoneMapPairs','start':None,'goal':None,
                           'seed':271828+number,'notReplacedOrResampled':True});continue
        i,j,distance=pairs[number];ai,a=candidates[i];bi,b=candidates[j]
        route=model.route(a,b)
        # Incomplete native routes are retained, not replaced by a later pair.
        target=route['points'][0] if route['complete'] else b
        yaw=math.atan2(target[2]-a[2],target[0]-a[0])
        routes.append({'routeID':number,'status':'selectedPhoneOnly','start':a,'goal':b,
                       'startSurfaceCell':ai,'goalSurfaceCell':bi,'straightDistanceMetres':distance,
                       'initialYawRadians':yaw,'seed':271828+number,'nativeInitialRoute':route,
                       'notReplacedOrResampled':True})
    return {'schema':'phone-only-fixed-routes-v1','surfaceSHA256':model.revision,'selectionSeed':271828,
            'routeCount':20,'routeSlots':routes,'phoneFootprintCandidates':len(candidates),
            'phoneOnlyOrderedPairPool':len(pairs),'selectionLatticeCells':step,
            'pairSeparationMetres':[2,6],'FAROUsed':False,'routeOutcomesUsedForSelection':False,
            'meaning':'20 fixed same-room route schedules; missing/incomplete routes are retained failures, not journeys'}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--surface',type=Path,required=True)
    parser.add_argument('--sha256',required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if args.output.exists():raise ValueError('refuse route overwrite')
    model=PhoneModel(args.surface,args.sha256)
    try:result=select(model)
    finally:model.close()
    if sha(args.surface)!=args.sha256:raise ValueError('phone map changed during route selection')
    args.output.write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'routeSlots':20,'pairs':result['phoneOnlyOrderedPairPool'],
                      'footprintCandidates':result['phoneFootprintCandidates'],'routeSHA256':sha(args.output)}))

if __name__=='__main__':main()
