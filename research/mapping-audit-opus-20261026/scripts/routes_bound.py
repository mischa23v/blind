"""DIAGNOSTIC UPPER BOUND ONLY: block reference-confirmed low objects (FARO) instead of the phone's
statistical 'object' calls. This leaks the evaluator into the map and is NOT a planner result; it
measures how much route capacity the ~1,000 false object calls cost."""
import numpy as np,routes_rect as R
D=np.load('policyD.npz');st=np.load('lowband_stat.npz');refobj=np.load('ref_lowobj.npy');miss=np.load('ref_miss.npy')
walk=D['walk'];state=st['state']
R.run(walk&~miss,'UPPER BOUND: D1 permissive minus reference low objects (FARO leak)')
R.run(walk&(state!='unresolved')&~miss,'UPPER BOUND: D1, unresolved blocked, reference objects blocked, stat-object ignored')
