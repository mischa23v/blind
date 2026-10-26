p='game_v3.py';s=open(p).read()
s=s.replace("from oriented_ground_container import GroundedReferenceContainer","from oriented_ground_container import GroundedReferenceContainer\nfrom fast_container import FastGroundedContainer\nEQUIV={'checked':0,'max':40}")
old="SETUP[key]=('ok',(init,ground,GroundedReferenceContainer(base.surface,base.transform,ground=ground,body=base.body),round(time.time()-tg,1)))"
assert old in s
s=s.replace(old,"SETUP[key]=('ok',(init,ground,(FastGroundedContainer(base.surface,base.transform,ground=ground,body=base.body),GroundedReferenceContainer(base.surface,base.transform,ground=ground,body=base.body)),round(time.time()-tg,1)))")
s=s.replace("    init,ground,scorer,res['groundSetupSeconds']=val","    init,ground,(scorer,slow),res['groundSetupSeconds']=val\n    eq_left=[40] if cond=='baseline' else [0]")
old2="                    c=scorer.swept_contacts(a,b,ay,d);f=contact_status(c)"
assert old2 in s
s=s.replace(old2,"""                    c=scorer.swept_contacts(a,b,ay,d);f=contact_status(c)
                    if eq_left[0]>0:   # built-in equivalence guard against the original slow scorer
                        cs=slow.swept_contacts(a,b,ay,d);eq_left[0]-=1;EQUIV['checked']+=1
                        for k in ('actualBody','horizontalMargin'):
                            if bool(cs[k]['contact'])!=bool(c[k]['contact']) or cs[k].get('firstReferenceCellID')!=c[k].get('firstReferenceCellID'):raise SystemExit('FAST/SLOW SCORER MISMATCH '+k)""")
s=s.replace("worldModel='master 7506ad9 v3 connected-ground world (reused unchanged)',","worldModel='master 7506ad9 v3 connected-ground world; contact via decision-equivalent fast path (fast_container.py) with in-run equivalence guard',equivalenceChecks=EQUIV['checked'],")
open(p,'w').write(s);print('ok')
