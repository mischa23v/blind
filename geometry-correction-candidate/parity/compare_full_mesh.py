#!/usr/bin/env python3
"""Bounded same-export numerical comparator. Never geometry repair or routing authority."""
import argparse, hashlib, json, math, struct, uuid
from collections import Counter

def tol(scale):
    return 64*2**-23*max(1,abs(scale))

def near(a,b):
    return len(a)==len(b) and all(math.isfinite(x) and math.isfinite(y) and abs(x-y)<=tol(max(abs(x),abs(y))) for x,y in zip(a,b))

def words(values):
    if not isinstance(values,list) or any(type(x)!=int or not 0<=x<=0xffffffff for x in values): raise ValueError('Float32 encoding')
    out=[struct.unpack('<f',struct.pack('<I',x))[0] for x in values]
    if any(not math.isfinite(x) or abs(x)>10000 for x in out): raise ValueError('Float32 range')
    return out

def triples(values):
    if len(values)%3: raise ValueError('triplet length')
    return [values[i:i+3] for i in range(0,len(values),3)]

def multiset_match(a,b,predicate):
    """Exact bipartite cardinality under numerical tolerance, preserving multiplicity."""
    if len(a)!=len(b) or len(a)>1024: return False
    edges=[[j for j,y in enumerate(b) if predicate(x,y)] for x in a]
    matched={}
    for start in sorted(range(len(a)),key=lambda i:len(edges[i])):
        queue=[start]; seen_left={start}; parent_right={}; finish=None
        for i in queue:
            for j in edges[i]:
                if j in parent_right: continue
                parent_right[j]=i
                if j not in matched:
                    finish=j;break
                owner=matched[j]
                if owner not in seen_left: seen_left.add(owner);queue.append(owner)
            if finish is not None: break
        if finish is None: return False
        inverse={i:j for j,i in matched.items()}
        while finish is not None:
            i=parent_right[finish]; prior=inverse.get(i)
            matched[finish]=i; finish=prior
    return True

def triangles(points,indices):
    if any(type(i)!=int or not 0<=i<len(points) for i in indices): raise ValueError('triangle index')
    return [[points[i] for i in t] for t in triples(indices)]

def oriented_equal(a,b):
    return any(all(near(a[i],b[(i+k)%3]) for i in range(3)) for k in range(3))

def compare(reference,inventory,inventory_sha):
    if reference['nativeInventorySHA256']!=inventory_sha: raise ValueError('different native inventory bytes')
    if reference['stageMetersPerUnit']!=1 or reference['stageUpAxis']!='Y' or reference.get('metersPerUnitAuthored') is not True or reference.get('upAxisAuthored') is not True: raise ValueError('unexpected source units/axis')
    rows=[x for x in inventory['fixtures'] if x['fixtureID']==reference['fixtureID']]
    if len(rows)!=1: raise ValueError('fixture identity')
    row=rows[0]
    if row.get('inventoryFailure') or row.get('meshParityFailure'): raise ValueError('native inventory/capture failed')
    if row['sourceSHA256'] != reference['sourceSHA256']: raise ValueError('source identity mismatch')
    capture=row.get('meshParity')
    if not capture or capture.get('schema')!='blind.public-apple-native-mesh-parity.v1' or capture.get('complete') is not True: raise ValueError('complete native capture missing')
    if capture.get('representation')!='raw-diagnostic-export' or capture.get('coordinateEncoding')!='float32-bit-patterns-column-major' or capture.get('winding')!='ordered-native-triangle-indices': raise ValueError('capture representation')
    def keyed(meshes,key):
        out={}
        for m in meshes:
            k=str(uuid.UUID(m[key]))
            if k in out: raise ValueError('multiple meshes per identity require explicit path matching; do not guess')
            out[k]=m
        return out
    native=keyed(capture['meshes'],'featureID'); refs=keyed(reference['meshes'],'featureID')
    if set(native)!=set(refs) or not 0<len(refs)<=64: raise ValueError('mesh identity membership')
    if sum(len(m['localPositionBits'])//3 for m in native.values())>1024 or sum(len(m['triangleIndices'])//3 for m in native.values())>1024: raise ValueError('fixture geometry cap')
    nodes={n['path']:n for n in reference['nodes']}; results=[]
    for identity in sorted(refs):
        n,r=native[identity],refs[identity]; node=nodes[r['path']]
        if r.get('holeIndices') != [] or r.get('subdivisionScheme')!='none' or r['orientation']!='rightHanded' or any(c!=3 for c in r['faceVertexCounts']): raise ValueError('nontriangle/nonrightHanded mesh unsupported, not converted')
        lp,wp=triples(words(n['localPositionBits'])),triples(words(n['worldPositionBits']))
        ri=r['faceVertexIndices']; ni=n['triangleIndices']
        checks={
            'localTransform':near(words(n['localTransformBits']),sum(node['localMatrixRows'],[])),
            'worldTransform':near(words(n['worldTransformBits']),sum(node['worldMatrixRows'],[])),
            'localVertexMultiset':multiset_match(lp,r['localPositions'],near),
            'worldVertexMultiset':multiset_match(wp,r['worldPositions'],near),
            'orientedLocalTriangleMultiset':multiset_match(triangles(lp,ni),triangles(r['localPositions'],ri),oriented_equal),
            'orientedWorldTriangleMultiset':multiset_match(triangles(wp,ni),triangles(r['worldPositions'],ri),oriented_equal),
        }
        results.append({'featureID':identity,'referencePath':r['path'],'nativeNodeIndex':n['nodeIndex'],'nativeVertices':len(lp),'referenceVertices':len(r['localPositions']),'nativeTriangles':len(ni)//3,'referenceTriangles':len(ri)//3,'checks':checks,'pass':all(checks.values())})
    return {'schema':'blind.full-same-export-parity.v1','fixtureID':reference['fixtureID'],'inventorySHA256':inventory_sha,'usdzSHA256':reference['usdzSHA256'],'metadataSHA256':reference['metadataSHA256'],'sourceSHA256':reference['sourceSHA256'],'meshCount':len(results),'meshes':results,'allPassed':all(r['pass'] for r in results),'tolerance':'64*2^-23*max(1,abs(a),abs(b)) per scalar; existing adapter Float32 numerical allowance, not physical accuracy','policy':'Same-export raw ModelIO vs official OpenUSD; no scale/axis/mesh repair; multiplicity and oriented triangle cyclic order retained','physicalAuthority':False,'liveNavigationValidated':False}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('reference');p.add_argument('inventory');p.add_argument('output');a=p.parse_args()
    raw=open(a.inventory,'rb').read()
    if len(raw)>131072: raise ValueError('inventory byte cap')
    refraw=open(a.reference,'rb').read()
    if len(refraw)>2*1024*1024: raise ValueError('reference byte cap')
    report=compare(json.loads(refraw),json.loads(raw),hashlib.sha256(raw).hexdigest())
    open(a.output,'w').write(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'allPassed':report['allPassed'],'meshCount':report['meshCount'],'physicalAuthority':False}))
