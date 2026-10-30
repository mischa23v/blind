"""Source-only route scheduling glue; no collision/support engine or native imports.
Matches the frozen original stop/turn/translate policy: <=25mm, <=1deg,
shortest signed turn with +pi tie, +X forward/+Z positive yaw. No smoothing.
"""
import math

TRANSLATION=0.025
TURN=math.pi/180.0

def make_schedule(chain):
    if not 2<=len(chain)<=1000 or any(len(p)!=3 or not all(math.isfinite(v) for v in p) for p in chain):
        raise ValueError('bounded finite requested-connector chain required')
    chain=[list(p) for p in chain]
    horizontal=[math.atan2(b[2]-a[2],b[0]-a[0]) for a,b in zip(chain,chain[1:]) if b[0]!=a[0] or b[2]!=a[2]]
    if not horizontal: raise ValueError('route must have horizontal travel')
    yaw=horizontal[0];initial=yaw
    events=[{'kind':'initial','a':chain[0],'b':chain[0],'yaw':yaw,'dyaw':0.,'edge':-1}]
    for edge,(a,b) in enumerate(zip(chain,chain[1:])):
        dx=b[0]-a[0];dz=b[2]-a[2]
        target=math.atan2(dz,dx) if dx or dz else yaw
        delta=(target-yaw+math.pi)%(2*math.pi)-math.pi
        if delta==-math.pi:delta=math.pi
        if delta:
            steps=math.ceil(abs(delta)/TURN);increment=delta/steps
            for j in range(steps):
                events.append({'kind':'turn','a':a,'b':a,'yaw':yaw+j*increment,'dyaw':increment,'edge':edge})
            yaw+=delta
        distance=math.dist(a,b)
        if distance:
            steps=math.ceil(distance/TRANSLATION)
            for j in range(steps):
                # Preserve segment endpoints exactly, including both connectors.
                x=a if j==0 else [a[k]+(b[k]-a[k])*j/steps for k in range(3)]
                y=b if j+1==steps else [a[k]+(b[k]-a[k])*(j+1)/steps for k in range(3)]
                events.append({'kind':'translate','a':x,'b':y,'yaw':yaw,'dyaw':0.,'edge':edge})
        else:
            events.append({'kind':'stationary','a':a,'b':b,'yaw':yaw,'dyaw':0.,'edge':edge})
    events.append({'kind':'terminal','a':chain[-1],'b':chain[-1],'yaw':yaw,'dyaw':0.,'edge':len(chain)-1})
    if len(events)>10000:raise ValueError('frozen schedule exceeds inherited source event cap')
    return {'chain':chain,'initialYaw':initial,'events':events}
