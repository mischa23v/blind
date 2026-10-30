"""Preregistered pose/K-only view selection. No image, depth, map, or native read."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORK = HERE.parents[2]
POSE_SHA = '46c8d1fc5188d38179e88eff98fd42f99956fb93b570bd9483e6e92764ae7010'
CONTRACT_SHA = '64a89282d3aaa3667483c6fefa7fa6e0ddec9a26e4ed14b34d1dc40c8e5d2bfc'
BUILD = ('frame_00290', 'frame_00357', 'frame_00391')
FRACTIONS = (.1, .3, .5, .7, .9)
DEPTHS = (1., 2., 3.)
MIN_INDEX_GAP = 8  # sample-partition spacing; not time or an accuracy criterion


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inverse3(r):
    cof = []
    for i in range(3):
        row = []
        for j in range(3):
            m = [[r[a][b] for b in range(3) if b != j]
                 for a in range(3) if a != i]
            row.append((-1)**(i+j)*(m[0][0]*m[1][1]-m[0][1]*m[1][0]))
        cof.append(row)
    det = sum(r[0][j]*cof[0][j] for j in range(3))
    assert abs(det-1) <= 2e-6
    return [[cof[j][i]/det for j in range(3)] for i in range(3)]


def optical_angle(a, b):
    x = [a['t'][i][2] for i in range(3)]
    y = [b['t'][i][2] for i in range(3)]
    dot = sum(v*w for v,w in zip(x,y))/math.sqrt(sum(v*v for v in x)*sum(w*w for w in y))
    return math.degrees(math.acos(max(-1., min(1., dot))))


def contained(probes, camera):
    count = 0
    k, inv, origin = camera['frame'], camera['inverse'], camera['origin']
    for point in probes:
        q = [sum(inv[i][j]*(point[j]-origin[j]) for j in range(3)) for i in range(3)]
        if not 0 < q[2] < 4:
            continue
        u = k['fl_x']*q[0]/q[2]+k['cx']
        v = k['fl_y']*q[1]/q[2]+k['cy']
        count += 0 <= u < k['w'] and 0 <= v < k['h']
    return count


def main():
    pose_path = WORK/'coffee-recovered-source/transformations.json'
    contract_path = WORK/'blind/research/coffee-shared-pose-occupancy-source-20261029/pose_contract.py'
    assert sha(pose_path) == POSE_SHA and sha(contract_path) == CONTRACT_SHA
    spec = importlib.util.spec_from_file_location('pinned_pose_contract', contract_path)
    contract = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(contract)
    metadata = json.loads(pose_path.read_text())
    assert metadata['camera_model'] == 'OPENCV' and metadata['orientation_override'] == 'none'
    names = [Path(f['file_path']).stem for f in metadata['frames']]
    assert names == sorted(set(names))
    cameras = []
    for index, frame in enumerate(metadata['frames']):
        t, origin = contract.frame_contract(frame)
        inv = inverse3([row[:3] for row in t[:3]])
        probes = []
        for depth in DEPTHS:
            for fy in FRACTIONS:
                for fx in FRACTIONS:
                    u, v = fx*(frame['w']-1), fy*(frame['h']-1)
                    p = [(u-frame['cx'])*depth/frame['fl_x'],
                         (v-frame['cy'])*depth/frame['fl_y'], depth]
                    probes.append([sum(t[i][j]*p[j] for j in range(3))+origin[i] for i in range(3)])
        cameras.append({'index':index, 'name':names[index], 'frame':frame,
                        't':t, 'origin':origin, 'inverse':inv, 'probes':probes})
    build_indices = [names.index(name) for name in BUILD]
    anchors = (cameras[build_indices[0]], cameras[build_indices[-1]])
    selected, reviews = [], []
    for anchor in anchors:
        ranking = []
        for candidate in cameras:
            i = candidate['index']
            if min(abs(i-j) for j in build_indices) < MIN_INDEX_GAP:
                continue
            if any(abs(i-j['originalMetadataZeroBasedIndex']) < MIN_INDEX_GAP for j in selected):
                continue
            forward = contained(anchor['probes'], candidate)
            reverse = contained(candidate['probes'], anchor)
            row = {'frameID':candidate['name'], 'originalMetadataZeroBasedIndex':i,
                   'anchorFrame':anchor['name'], 'anchorVirtualProbesInsideCandidate':forward,
                   'candidateVirtualProbesInsideAnchor':reverse,
                   'minimumDirectionalCount':min(forward,reverse), 'totalCount':forward+reverse,
                   'suppliedOpticalAxisAngleDegrees':optical_angle(anchor,candidate),
                   'suppliedTranslationDistanceMetres':math.dist(anchor['origin'],candidate['origin'])}
            ranking.append(row)
        ranking.sort(key=lambda r:(-r['minimumDirectionalCount'], -r['totalCount'],
                                  r['suppliedOpticalAxisAngleDegrees'],
                                  r['suppliedTranslationDistanceMetres'],
                                  r['originalMetadataZeroBasedIndex']))
        assert ranking
        chosen = dict(ranking[0]); chosen['member'] = 'room_datasets/coffee_room/iphone/long_capture/depth/'+chosen['frameID']+'.png'
        chosen['depthSHA256'] = None
        chosen['depthHashState'] = 'not extracted or inspected; member bound by archive hash'
        selected.append(chosen)
        reviews.append({'anchorFrame':anchor['name'], 'eligibleCandidates':len(ranking), 'topFive':ranking[:5]})
    assert len(set(r['frameID'] for r in selected)) == 2
    result = {
        'schema':1, 'status':'metadata-only selection executed; no held-out depth/image/map read or native call',
        'sourceSHA256':sha(Path(__file__)), 'originalPosesSHA256':POSE_SHA,
        'poseContractSHA256':CONTRACT_SHA,
        'archiveSHA256':'591672a1c4afa50e5109fc78ff08d8f608d05756a9181cfdd7cef38a57a1623d',
        'archiveBytes':183080957, 'buildFrameIDsUnchanged':list(BUILD),
        'buildFrameZeroBasedIndices':build_indices, 'anchorsInOrder':[r['name'] for r in anchors],
        'minimumCaptureIndexGapFromEveryBuildAndPreviousHoldout':MIN_INDEX_GAP,
        'gapIsElapsedTimeOrAccuracyThreshold':False,
        'virtualProbePixelFractions':list(FRACTIONS), 'virtualProbeAxialDepthsMetres':list(DEPTHS),
        'probesPerFrustum':75, 'projectionBounds':'0 <= u < w; 0 <= v < h; 0 < projected axial z < 4 m',
        'sortRule':['maximum minimum directional count','maximum total count','minimum optical-axis angle','minimum translation distance','minimum metadata index'],
        'virtualProbesAreMeasuredGeometry':False, 'virtualContainmentGuaranteesActualSurfaceOverlap':False,
        'heldoutFrames':selected, 'rankingDiagnostics':reviews,
        'frozenBeforeNewDepthInspection':True, 'noSwapsAfterResults':True,
        'heldOutMeaning':'same-capture held-out depth; not independent calibration or globally unseen imagery',
        'physicalAuthority':False,
    }
    output = HERE/'HOLDOUT_SELECTION.json'
    assert not output.exists()
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(selected,indent=2))


if __name__ == '__main__':
    main()
