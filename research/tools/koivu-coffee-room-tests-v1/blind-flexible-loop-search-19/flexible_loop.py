"""Finite phone-mask loop candidates: Detour legs, SciPy shortest paths.

No mapping, reference input, actor movement, A*, or physical clearance authority.
Graph paths advance eight sectors once. Winding is explicitly bounded [-8, 8].
The shared graph retains incoming heading through directed-leg states; each
Dijkstra source row identifies the initial leg for the exact closing turn.
"""
from pathlib import Path
import hashlib, importlib.util, json, math, sys
import numpy as np
from scipy import ndimage, sparse
from scipy.sparse.csgraph import dijkstra

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
WS = HERE.parent
ADAPTER = WS / 'blind-corrected-mask-route-comparison-18/paired_adapter.py'
ADAPTER_SHA = '86d4510a3f801a2f5dd303fe184c8fe0f3fb1d1c90b9057ab1665352939d7c04'
ANCHOR_OLD_GAME = np.array([-1.225, 0., .075])
SECTORS, PER_SECTOR, EXAMINED = 8, 8, 256
WMIN, WMAX = -8, 8
WCOUNT = WMAX-WMIN+1
STEP, TURN, BOUNDARY_EPS = .025, math.radians(5), 1e-9
LENGTH_TIE = 1e-10  # Metres; only deterministic numerical shortest-path ties.


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def adapter():
    if sha(ADAPTER) != ADAPTER_SHA:
        raise ValueError('unchanged paired adapter pin')
    spec = importlib.util.spec_from_file_location('flexible_pinned_adapter', ADAPTER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def clearance_field(mask):
    """Cell-centre lower bound to closed blocked squares, including exterior."""
    return np.maximum(0., ndimage.distance_transform_edt(np.pad(mask, 1))* .05
                      - .05*math.sqrt(2)/2)[1:-1, 1:-1]


def clearance_at(xy, origin, field):
    points = np.asarray(xy, float).reshape(-1, 2)
    ij = np.floor((points-np.asarray(origin))/.05).astype(int)
    inside = np.all((ij >= 0) & (ij < np.asarray(field.shape)), axis=1)
    values = np.zeros(len(points), float)
    c = ij[inside]
    centres = np.asarray(origin)+(c+.5)*.05
    values[inside] = np.maximum(0., field[c[:, 0], c[:, 1]]
                               - np.linalg.norm(points[inside]-centres, axis=1))
    return values


def open_crossings(xy, anchor):
    """Signed half-open positive-X ray crossings; reject centreline touching anchor."""
    p = np.asarray(xy, float)
    q = np.asarray(anchor, float)
    total = 0
    for a, b in zip(p[:-1], p[1:]):
        delta = b-a
        length = float(np.linalg.norm(delta))
        rel = q-a
        if length <= BOUNDARY_EPS:
            if np.linalg.norm(rel) <= BOUNDARY_EPS:
                return None
            continue
        cross = delta[0]*rel[1]-delta[1]*rel[0]
        along = float(rel @ delta)
        if abs(cross) <= BOUNDARY_EPS*length and -BOUNDARY_EPS*length <= along <= length*length+BOUNDARY_EPS*length:
            return None
        total += int(a[1] <= q[1] < b[1] and cross > 0)
        total -= int(b[1] <= q[1] < a[1] and cross < 0)
    return total


def choose_candidates(model, old, new, ad, field):
    cells = np.argwhere(model.mask)
    xy = np.asarray(model.origin)+(cells+.5)*.05
    game = np.c_[xy[:, 0], np.zeros(len(xy)), -xy[:, 1]]
    old_game, _ = ad.map_objective(game, new, old)
    old_xy = ad.game_to_level(old_game)[:, :2]
    anchor_xy = ad.game_to_level(ANCHOR_OLD_GAME)[:2]
    delta = old_xy-anchor_xy
    angle = np.mod(np.arctan2(delta[:, 1], delta[:, 0]), 2*math.pi)
    sectors = np.floor(angle/(2*math.pi/SECTORS)).astype(int)
    ranked = field[cells[:, 0], cells[:, 1]]
    groups, receipts = [], []
    for sector in range(SECTORS):
        ids = np.flatnonzero(sectors == sector)
        ids = ids[np.lexsort((cells[ids, 1], cells[ids, 0], -ranked[ids]))]
        selected, trials = [], []
        for order, idx in enumerate(ids[:EXAMINED]):
            row = {'sourceIJ': cells[idx].tolist(), 'rank': order,
                   'centreClearanceLowerBoundMetres': float(ranked[idx])}
            if any(np.linalg.norm(xy[idx]-np.asarray(c['sourceXY'])) < .50 for c in selected):
                row['reason'] = 'diversitySeparationBelow0p50m'
                trials.append(row)
                continue
            heading = next((k for k in range(72) if model.sampled_fit(game[idx], -math.radians(5*k))), None)
            row.update(firstFittingHeadingIndex=heading,
                       reason='selected' if heading is not None else 'noSampledHeadingFits')
            trials.append(row)
            if heading is None:
                continue
            selected.append({'sector': sector, 'indexInSector': len(selected),
                'id': sector*PER_SECTOR+len(selected), 'sourceIJ': cells[idx].tolist(),
                'flatIndex': int(cells[idx, 0]*model.mask.shape[1]+cells[idx, 1]),
                'sourceXY': xy[idx].tolist(), 'gameXYZ': game[idx].tolist(),
                'originalLevelXYForSector': old_xy[idx].tolist(),
                'centreClearanceLowerBoundMetres': float(ranked[idx]),
                'firstFittingHeadingIndex': heading})
            if len(selected) == PER_SECTOR:
                break
        groups.append(selected)
        receipts.append({'sector': sector, 'availableWalkCentres': len(ids),
                         'rankedCentresExamined': len(trials), 'trials': trials,
                         'selected': selected})
    return groups, receipts


def path_metric(path, origin, field):
    p = np.asarray(path, float)
    xy = np.c_[p[:, 0], -p[:, 2]]
    delta = np.diff(xy, axis=0)
    lengths = np.linalg.norm(delta, axis=1)
    if np.any(lengths <= 1e-6):
        raise ValueError('nondegenerate already coalesced leg required')
    samples = []
    for a, d, length in zip(xy[:-1], delta, lengths):
        t = np.r_[np.arange(0., length+1e-9, STEP), length]
        samples.append(a+np.minimum(t/length, 1.)[:, None]*d)
    samples = np.concatenate(samples)
    return {'length': float(lengths.sum()),
            'capacity': float(clearance_at(samples, origin, field).min()),
            'firstHeading': float(math.atan2(delta[0, 1], delta[0, 0])),
            'lastHeading': float(math.atan2(delta[-1, 1], delta[-1, 0])),
            'centreSamples': len(samples)}


def junction(model, incoming, outgoing, point, field):
    change = (outgoing-incoming+math.pi) % (2*math.pi)-math.pi
    angles = [incoming+change*min(1., k*TURN/max(abs(change), 1e-9))
              for k in range(int(abs(change)/TURN)+2)]
    fits = all(model.rr.rect_ok(model.mask, model.origin, *point, angle) for angle in angles)
    return {'passed': bool(fits), 'headingChangeRadians': float(change),
            'headingSamples': len(angles),
            'capacity': float(clearance_at([point], model.origin, field)[0])}


def leg_graph(model, groups, helpers, ad, anchor_xy, field, leg_file, heartbeat):
    accepted, counts = [], {}
    queries = 0
    for sector in range(SECTORS):
        for a in groups[sector]:
            for b in groups[(sector+1) % SECTORS]:
                result = ad.query_fixed(model, a['gameXYZ'], b['gameXYZ'], helpers)
                result.update(queryID=queries, sector=sector, fromCandidateID=a['id'], toCandidateID=b['id'])
                if result['status'] == 'fixedPhoneModelLegAccepted':
                    path = result['planarFootprintValidationPath']
                    xy = np.c_[np.asarray(path)[:, 0], -np.asarray(path)[:, 2]]
                    crossing = open_crossings(xy, anchor_xy)
                    if crossing is None:
                        result['status'] = 'anchorTouchOrNumericalAmbiguity'
                    else:
                        metric = path_metric(path, model.origin, field)
                        leg = {'id': len(accepted), 'queryID': queries, 'sector': sector,
                               'from': a['id'], 'to': b['id'], 'fromFlat': a['flatIndex'],
                               'toFlat': b['flatIndex'], 'fromXY': a['sourceXY'],
                               'toXY': b['sourceXY'], 'path': path, 'crossings': crossing,
                               **metric}
                        accepted.append(leg)
                        result['graphLeg'] = {k: v for k, v in leg.items() if k != 'path'}
                leg_file.write(json.dumps(ad.safe(result), separators=(',', ':'), allow_nan=False)+'\n')
                counts[result['status']] = counts.get(result['status'], 0)+1
                queries += 1
                if queries > 512:
                    raise ValueError('predeclared native query cap')
                if queries % 32 == 0:
                    heartbeat({'phase': 'nativeLegs', 'queries': queries, 'accepted': len(accepted)})
    transitions, closures, turn_receipts = [], {}, []
    by_sector = [[leg for leg in accepted if leg['sector'] == k] for k in range(SECTORS)]
    for sector in range(SECTORS):
        for first in by_sector[sector]:
            for second in by_sector[(sector+1) % SECTORS]:
                if first['to'] != second['from']:
                    continue
                receipt = junction(model, first['lastHeading'], second['firstHeading'], first['toXY'], field)
                receipt.update(incomingLegID=first['id'], outgoingLegID=second['id'], closure=sector == 7)
                turn_receipts.append(receipt)
                if not receipt['passed']:
                    continue
                capacity = min(first['capacity'], second['capacity'], receipt['capacity'])
                if sector == 7:
                    closures[(first['id'], second['id'])] = capacity
                else:
                    transitions.append((first['id'], second['id'], capacity))
    return accepted, transitions, closures, turn_receipts, queries, counts


def state(leg_id, winding):
    return leg_id*WCOUNT+winding-WMIN


def make_graph(legs, transitions, threshold):
    rows, cols, weights = [], [], []
    for a, b, capacity in transitions:
        if capacity < threshold:
            continue
        for winding in range(WMIN, WMAX+1):
            after = winding+legs[b]['crossings']
            if WMIN <= after <= WMAX:
                rows.append(state(a, winding)); cols.append(state(b, after)); weights.append(legs[b]['length'])
    graph = sparse.csr_matrix((weights, (rows, cols)), shape=(len(legs)*WCOUNT,)*2)
    graph.sort_indices()
    return graph


def terminals(first, legs, closures, threshold):
    return [state(last['id'], winding) for last in legs if last['sector'] == 7
            and closures.get((last['id'], first['id']), -1.) >= threshold
            for winding in (-1, 1)]


def threshold_distances(legs, transitions, closures, threshold):
    starts = [leg for leg in legs if leg['sector'] == 0 and leg['capacity'] >= threshold
              and WMIN <= leg['crossings'] <= WMAX]
    if not starts:
        return None
    graph = make_graph(legs, transitions, threshold)
    indices = [state(leg['id'], leg['crossings']) for leg in starts]
    distance = np.atleast_2d(dijkstra(graph, directed=True, indices=indices))
    winners = []
    for row, first in enumerate(starts):
        ends = terminals(first, legs, closures, threshold)
        if not ends:
            continue
        best = float(distance[row, ends].min())+first['length']
        if math.isfinite(best):
            winners.append((best, first['id']))
    return (graph, starts, winners) if winners else None


def recover_lex_path(graph, first, legs, closures, threshold):
    ends = terminals(first, legs, closures, threshold)
    # SciPy owns shortest distances. Greedy reconstruction is confined to the
    # resulting tight-edge DAG, using explicit numerical ties, not a new search.
    suffix = dijkstra(graph.T.tocsr(), directed=True, indices=ends, min_only=True)
    current = state(first['id'], first['crossings'])
    if not math.isfinite(float(suffix[current])):
        raise ValueError('missing shortest suffix')
    selected = [first['id']]
    for _ in range(7):
        options = []
        for k in range(graph.indptr[current], graph.indptr[current+1]):
            nxt, weight = int(graph.indices[k]), float(graph.data[k])
            if math.isfinite(float(suffix[nxt])) and abs(weight+suffix[nxt]-suffix[current]) <= LENGTH_TIE:
                leg = legs[nxt//WCOUNT]
                options.append(((leg['toFlat'], leg['id']), nxt))
        if not options:
            raise ValueError('no tight shortest-path successor within declared numerical tie')
        current = min(options)[1]
        selected.append(current//WCOUNT)
    if current not in ends or len(selected) != 8:
        raise ValueError('wrong terminal sector, winding or closure')
    return selected


def rank_cycle(legs, transitions, closures):
    if not legs or not closures:
        return {'found': False, 'reason': 'noAcceptedLegOrCompatibleClosure', 'thresholdChecks': []}
    levels = sorted(set([leg['capacity'] for leg in legs]+[x[2] for x in transitions]+list(closures.values())))
    checks, low, high, best = [], 0, len(levels)-1, None
    while low <= high:
        mid = (low+high)//2
        available = threshold_distances(legs, transitions, closures, levels[mid])
        checks.append({'capacity': levels[mid], 'feasible': available is not None})
        if available is None:
            high = mid-1
        else:
            best = mid; low = mid+1
    if best is None:
        return {'found': False, 'reason': 'noWindingCompatibleFiniteGraphCycle', 'thresholdChecks': checks}
    capacity = levels[best]
    graph, _, winners = threshold_distances(legs, transitions, closures, capacity)
    shortest = min(x[0] for x in winners)
    tied = []
    for length, first_id in winners:
        if abs(length-shortest) <= LENGTH_TIE:
            ids = recover_lex_path(graph, legs[first_id], legs, closures, capacity)
            key = tuple([legs[ids[0]]['fromFlat']]+[legs[i]['toFlat'] for i in ids])
            tied.append((key, tuple(ids)))
    selected = list(min(tied)[1])
    return {'found': True, 'legIDs': selected, 'maximumBottleneckCentreClearanceMetres': capacity,
            'selectedLengthMetres': float(sum(legs[i]['length'] for i in selected)),
            'scipyShortestLengthMetres': shortest, 'shortestTieToleranceMetres': LENGTH_TIE,
            'winding': sum(legs[i]['crossings'] for i in selected),
            'thresholdChecks': checks, 'liftedNodes': graph.shape[0],
            'thresholdedGraphEdges': graph.nnz, 'finiteWindingBound': [WMIN, WMAX],
            'globalPhysicalOrAllNativeHomotopyOptimumClaimed': False}


def assemble_cycle(legs, ids):
    path = list(legs[ids[0]]['path'])
    for leg_id in ids[1:]:
        nxt = legs[leg_id]['path']
        if not np.array_equal(path[-1], nxt[0]):
            raise ValueError('exact requested junction endpoint mismatch')
        path.extend(nxt[1:])
    if not np.array_equal(path[0], path[-1]):
        raise ValueError('exact requested cycle closure mismatch')
    return np.asarray(path, float)


def run_profile(ad, profile, output, old, new, helpers):
    model, geometry = ad.open_model('new', profile)
    heartbeat = lambda row: print(json.dumps({'profile': profile, **row}), flush=True)
    try:
        anchor, anchor_receipt = ad.map_objective(ANCHOR_OLD_GAME, old, new)
        anchor_xy = ad.game_to_level(anchor)[:2]
        ij = np.floor((anchor_xy-np.asarray(model.origin))/.05).astype(int)
        if not np.all((ij >= 0) & (ij < np.asarray(model.mask.shape))) or model.mask[tuple(ij)]:
            raise ValueError('same original phone-space anchor is not blocked in supplied candidate map')
        field = clearance_field(model.mask)
        groups, candidates = choose_candidates(model, old, new, ad, field)
        heartbeat({'phase': 'candidates', 'counts': list(map(len, groups))})
        with (output/(profile+'-native-legs.jsonl')).open('x') as f:
            legs, transitions, closures, turns, queries, counts = leg_graph(
                model, groups, helpers, ad, anchor_xy, field, f, heartbeat)
        ranked = rank_cycle(legs, transitions, closures)
        result = {'profile': profile, 'geometry': geometry, 'mapRevision': model.revision,
                  'anchor': anchor_receipt, 'anchorCandidateSourceIJ': ij.tolist(),
                  'anchorIsBlocked': True, 'candidateSelection': candidates,
                  'nativeQueries': queries, 'nativeOutcomeCounts': counts,
                  'acceptedNativeLegs': len(legs), 'junctions': turns, 'graphRanking': ranked,
                  'referenceInputsUsed': False, 'movementEpisodesExecuted': 0,
                  'physicalAuthority': False, 'semanticTableVerified': False,
                  'clearanceMetric': 'minimum sampled centre-to-blocked-square distance lower bound; not body clearance',
                  'failureScope': 'finite 8-sector policy, <=8 candidates/sector, winding prefix bound [-8,8], one native path/pair; not all possible loops'}
        if not ranked['found']:
            result['status'] = 'noLoopWithinDeclaredFinitePolicy'
            return result
        path = assemble_cycle(legs, ranked['legIDs'])
        check, poses = helpers['loop'].sampled_closed_check(model, path)
        wind = helpers['loop'].winding_receipt(np.c_[path[:, 0], -path[:, 2]], anchor_xy.reshape(1, 2))
        result.update(candidatePath=path.tolist(), sampledClosedCheck=check, anchorWinding=wind,
                      lowUnresolvedExposure=helpers['loop'].route_flags(model, poses),
                      selectedLegQueryIDs=[legs[i]['queryID'] for i in ranked['legIDs']],
                      initialYawRadians=-legs[ranked['legIDs'][0]]['firstHeading'],
                      originalNativeFullXYZRetainedInLegJSONL=True)
        result['status'] = ('selectedPhoneOnlyFlexibleLoop' if check['passed'] and wind['passed']
                            and wind['commonSignedWinding'] == ranked['winding']
                            else 'finalAssembledValidationRejected')
        result['finalFailureTriggersNoAlternateSearch'] = True
        return result
    finally:
        model.close()


def main(output, expected_frozen_sha):
    freeze = HERE/'FROZEN.json'
    if sha(freeze) != expected_frozen_sha:
        raise ValueError('explicit frozen manifest SHA required before parse')
    pins = json.loads(freeze.read_text())['files']
    def verify():
        for p, h in pins.items():
            if sha(WS/p) != h:
                raise ValueError('frozen source or input changed: '+p)
    verify()
    ad = adapter(); helpers = ad.helper_modules(); old, new = ad.metadata('old'), ad.metadata('new')
    out = Path(output); out.mkdir(exist_ok=False)
    summaries = []
    for profile in ad.PROFILES:
        result = run_profile(ad, profile, out, old, new, helpers)
        filename = profile+'.json'
        with (out/filename).open('x') as f:
            json.dump(ad.safe(result), f, separators=(',', ':'), allow_nan=False); f.write('\n')
        row = {'profile': profile, 'status': result['status'], 'nativeQueries': result['nativeQueries'],
               'acceptedNativeLegs': result['acceptedNativeLegs'], 'artifact': filename,
               'sha256': sha(out/filename), 'legArtifact': profile+'-native-legs.jsonl',
               'legArtifactSHA256': sha(out/(profile+'-native-legs.jsonl'))}
        summaries.append(row); print(json.dumps(row), flush=True)
    verify()
    with (out/'RESULTS.json').open('x') as f:
        json.dump({'results': summaries, 'nativeQueries': sum(r['nativeQueries'] for r in summaries),
                   'sourceInputHashesVerifiedBeforeAfter': True, 'movementEpisodesExecuted': 0,
                   'referenceInputsUsed': False, 'physicalAuthority': False}, f, indent=2); f.write('\n')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
