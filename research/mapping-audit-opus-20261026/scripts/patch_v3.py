p='game_v3.py';s=open(p).read()
s=s.replace("""def episode(route,cond,M,base):
    ap,sp=profiles(route,cond)""","""SETUP={}
def episode(route,cond,M,base):
    ap,sp=profiles(route,cond)""")
old="""    init=base.support_probes(start,yaw);ic=support_check(init)
    if not ic['acceptedFiniteSupportModel']:res.update(status='invalidStartReferenceSupport',initialSupportCheck=ic);return res
    pts=np.vstack((start,np.array([L2G(p) for p in route['initialPath']]),goal))
    seeds=[int(p['referenceCellID']) for p in init['probes']];sp_pts=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]] for p in init['probes']]
    tg=time.time()
    try:ground=GroundSupport.from_scorer(base,pts,seeds,sp_pts)
    except (ValueError,RuntimeError) as e:res.update(status='invalidStartGroundComponent',reason=str(e)[:200]);return res
    res['groundSetupSeconds']=round(time.time()-tg,1);print(json.dumps({'phase':'ground_ready','run':res['runID'],'seconds':res['groundSetupSeconds']}),flush=True)
    scorer=GroundedReferenceContainer(base.surface,base.transform,ground=ground,body=base.body)"""
new="""    key=route['routeID']
    if key not in SETUP:   # route-level world setup: depends only on start, frozen path and seeds, never on condition
        init=base.support_probes(start,yaw);ic=support_check(init)
        if not ic['acceptedFiniteSupportModel']:SETUP[key]=('invalidStartReferenceSupport',ic)
        else:
            pts=np.vstack((start,np.array([L2G(p) for p in route['initialPath']]),goal))
            seeds=[int(p['referenceCellID']) for p in init['probes']];sp_pts=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]] for p in init['probes']]
            tg=time.time()
            try:
                ground=GroundSupport.from_scorer(base,pts,seeds,sp_pts)
                SETUP[key]=('ok',(init,ground,GroundedReferenceContainer(base.surface,base.transform,ground=ground,body=base.body),round(time.time()-tg,1)))
            except (ValueError,RuntimeError) as e:SETUP[key]=('invalidStartGroundComponent',str(e)[:200])
            print(json.dumps({'phase':'ground_ready','route':key,'seconds':round(time.time()-tg,1),'state':SETUP[key][0]}),flush=True)
    kind,val=SETUP[key]
    if kind!='ok':res.update(status=kind,reason=val if isinstance(val,str) else None,initialSupportCheck=val if isinstance(val,dict) else None);return res
    init,ground,scorer,res['groundSetupSeconds']=val"""
assert old in s;s=s.replace(old,new)
old2="""    results=[]
    for route in F['routes']:"""
assert old2 in s;s=s.replace(old2,"""    results=[];sub=os.environ.get('ROUTE_SUBSET')
    keep=set(range(int(sub.split('-')[0]),int(sub.split('-')[1])+1)) if sub else None
    for route in F['routes']:
        if keep is not None and route['routeID'] not in keep:continue""")
old3="json.dump(out,open(os.path.join(rdir,'GAME_RESULTS.json'),'w'),indent=1)"
assert old3 in s;s=s.replace(old3,"json.dump(out,open(os.path.join(rdir,'GAME_RESULTS'+(('_part_'+sub) if sub else '')+'.json'),'w'),indent=1)")
open(p,'w').write(s);print('patched')
