"""Frozen standard-library metric definitions, no native or raster access."""
import math
STATUSES=('unresolved','hit-known-prefix','origin-unknown','origin-occupied','unknown-before-hit','range-exhausted','invalid-input','bounds-rejected','intersection-failed')
PRIMARY_STATUSES=STATUSES
STATUSES=STATUSES+('observed-hit-visibility-unverified',)
FRAMES=('frame_00232','frame_00370')
GRID_COUNT=len(range(0,738,8))*len(range(0,994,8))
def distributions(values):
    a=sorted(float(x)for x in values)
    if not all(math.isfinite(x)for x in a):raise ValueError('nonfinite residual, no filtering')
    if not a:return {'count':0,'signed':None,'absolute':None}
    def stats(q):
        def quantile(p):
            i=(len(q)-1)*p;j=math.floor(i);return q[j]+(q[min(j+1,len(q)-1)]-q[j])*(i-j)
        return {'min':q[0],'p05':quantile(.05),'p25':quantile(.25),'median':quantile(.5),'p75':quantile(.75),'p95':quantile(.95),'max':q[-1],'mean':math.fsum(q)/len(q),'rms':math.sqrt(math.fsum(x*x for x in q)/len(q))}
    return {'count':len(a),'signed':stats(a),'absolute':stats(sorted(abs(x)for x in a))}
def partition(statuses,denominator):
    result={k:0 for k in STATUSES}
    for s in statuses:
        if s not in result:raise ValueError('unrecognized ray status')
        result[s]+=1
    if sum(result.values())!=denominator:raise ValueError('status denominator mismatch')
    return result

def inverse3(r):
    a,b,c=r[0];d,e,f=r[1];g,h,i=r[2]
    det=a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
    if not math.isfinite(det)or abs(det)<1e-12:raise ValueError('singular supplied matrix')
    return (( (e*i-f*h)/det,(c*h-b*i)/det,(b*f-c*e)/det),
            ((f*g-d*i)/det,(a*i-c*g)/det,(c*d-a*f)/det),
            ((d*h-e*g)/det,(b*g-a*h)/det,(a*e-b*d)/det))
def axial(world_point,origin,inverse):
    if len(world_point)!=3 or not all(isinstance(x,(int,float)) and math.isfinite(x)for x in world_point):raise ValueError('invalid scored point')
    return math.fsum(inverse[2][j]*(world_point[j]-origin[j])for j in range(3))

def primary_partition(statuses,denominator):
    if any(s not in PRIMARY_STATUSES for s in statuses):raise ValueError("nonconservative primary status")
    return {k:v for k,v in partition(statuses,denominator).items() if k in PRIMARY_STATUSES}
