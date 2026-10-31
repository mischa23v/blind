"""Receipt-only accounting; no collision/support decisions or state updates."""
import math

def increment_progress(kind,start,mid,end,*,accepted):
    result={'translationIncrements':0,'translation3DMetres':0.,
            'translationXZMetres':0.,'turnVerticalAdjustmentMetres':0.}
    if not accepted:return result
    if kind=='translate':
        result['translationIncrements']=1
        result['translation3DMetres']=math.dist(start,mid)+math.dist(mid,end)
        result['translationXZMetres']=math.dist([start[0],start[2]],[end[0],end[2]])
    elif kind=='turn':
        # Support can adjust Y during a turn, but that is not route progress.
        result['turnVerticalAdjustmentMetres']=abs(mid[1]-start[1])+abs(end[1]-mid[1])
    else:
        raise ValueError('only accepted turn/translate increments have interval accounting')
    return result
