#!/usr/bin/env python3
"""Read-only result audit and one PNG overview. No native routing or scientific imports.

Public outputs contain summary metrics and a raster projection, not OBJ/poses,
raw routes, a mesh archive, or geometry-repair data. Pillow is used only to draw.
"""
import hashlib, json, math, pathlib, struct

H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]
W = R.parent
EXPECTED_COMMIT = '719ec504901639f65767b717f7f7dc817a482640'
EXPECTED_PROPOSALS = '0f50fbbd52df3fa4369c0784579a93a2461b6c765b052acb2daf51d15f5f290f'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def length(points):
    assert all(len(p) == 3 and all(math.isfinite(x) for x in p) for p in points)
    return sum(math.dist(a, b) for a, b in zip(points, points[1:]))


def main():
    old = W / 'conference-native-comparison-attempt-001'
    attempt = W / 'conference-native-comparison-attempt-002'
    proposal_file = attempt / 'comparison/PROPOSALS.json'
    receipt_file = attempt / 'GUARD_RUN/RESULT.json'
    proposals = json.loads(proposal_file.read_text())
    receipt = json.loads(receipt_file.read_text())
    controls = json.loads((attempt / 'GUARD_RUN/controls.stdout').read_text())
    assert receipt['sourceCommit'] == EXPECTED_COMMIT
    assert receipt['status'] == 'completed-zero-exit'
    assert receipt['inputHashesBefore'] == receipt['inputHashesAfter']
    assert all(c['exitCode'] == 0 and c['groupRetired'] for c in receipt['commands'])
    assert receipt['limits'] == {'cpuSeconds': 120, 'wallSeconds': 180, 'observedRSSBytes': 1024 ** 3, 'outputBytes': 16 * 1024 ** 2}
    assert controls['status'] == 'passed' and controls['count'] == 26
    old_receipt = json.loads((old / 'GUARD_RUN/RESULT.json').read_text())
    assert old_receipt['status'] == 'failed' and [c['exitCode'] for c in old_receipt['commands']] == [0, 1]
    failure = json.loads((R / 'research/conference-replay-source-20261029/ATTEMPT_001_FAILURE.json').read_text())
    for name, record in failure['retainedFiles'].items():
        assert sha(old / name) == record['sha256']
    assert proposal_file.read_bytes() == (old / 'comparison/PROPOSALS.json').read_bytes()
    assert sha(proposal_file) == EXPECTED_PROPOSALS
    for name, record in receipt['finalPayloadInventory'].items():
        if 'sha256' in record:
            assert sha(attempt / name) == record['sha256']
    inventory = R / 'research/conference-replay-input-inventory-20261029'
    requests = json.loads((inventory / 'TARGETS.json').read_text())['primaryPairs']
    assert len(proposals['paths']) == len(requests) == 7
    assert {k: receipt['comparison'][k] for k in ('queries', 'baselineCompleteAndAssociated', 'gridProposals', 'gridDisconnected', 'gridUnavailable')} == {'queries': 7, 'baselineCompleteAndAssociated': 7, 'gridProposals': 7, 'gridDisconnected': 0, 'gridUnavailable': 0}
    rows = []
    for row, request in zip(proposals['paths'], requests):
        assert row['name'] == request['name']
        for key in ('requestedStartXYZ', 'requestedGoalXYZ', 'sourcePoseIndices'):
            assert row[key] == request[key]
        assert row['baselineCompleteAndAssociated'] is True
        assert row['gridStatus'] == 'proposalOnlyAwaitingHardValidation'
        choice = row['gridSelection']
        shortest, centered = choice['distanceGrid'], choice['clearanceGrid']
        assert math.isclose(choice['lengthCapMetres'], 1.5 * shortest['lengthMetres'] + .5, abs_tol=1e-12)
        for candidate in (shortest, centered):
            assert candidate['requestedConnectorChainXYZ'] == [request['requestedStartXYZ']] + candidate['pointsXYZ'] + [request['requestedGoalXYZ']]
            assert math.isclose(length(candidate['pointsXYZ']), candidate['lengthMetres'], rel_tol=0, abs_tol=1e-9)
            assert math.isclose(length(candidate['requestedConnectorChainXYZ']), candidate['connectorInclusiveLengthMetres'], rel_tol=0, abs_tol=1e-9)
            assert candidate['lengthMetres'] <= choice['lengthCapMetres'] + 1e-9
        baseline = row['baselineRequestedConnectorChainXYZ']
        assert baseline == [request['requestedStartXYZ']] + row['baselineNative']['points'] + [request['requestedGoalXYZ']]
        s, c = shortest['connectorInclusiveLengthMetres'], centered['connectorInclusiveLengthMetres']
        rows.append({'name': row['name'], 'nativeConnectorInclusiveMetres': length(baseline),
                     'shortestConnectorInclusiveMetres': s, 'centeredConnectorInclusiveMetres': c,
                     'additionalMetres': c - s, 'additionalPercent': 100 * (c / s - 1),
                     'shortestGraphMetres': shortest['lengthMetres'], 'centeredGraphMetres': centered['lengthMetres'],
                     'unchangedGraphLengthCapMetres': choice['lengthCapMetres'],
                     'shortestMinimumGraphWallProxyMetres': shortest['minimumResidualWallProxyMetres'],
                     'centeredMinimumGraphWallProxyMetres': centered['minimumResidualWallProxyMetres'],
                     'shortestMinimumInteriorGraphWallProxyMetres': shortest['interiorMinimumResidualWallProxyMetres'],
                     'centeredMinimumInteriorGraphWallProxyMetres': centered['interiorMinimumResidualWallProxyMetres'],
                     'shortestExposureCost': shortest['clearanceExposureCost'], 'centeredExposureCost': centered['clearanceExposureCost'],
                     'exposureCostReductionPercent': 100 * (1 - centered['clearanceExposureCost'] / shortest['clearanceExposureCost']),
                     'centeredTierMetres': centered['thresholdMetres'],
                     'baselineStartHorizontalAssociationMetres': row['baselineStartAssociation']['horizontalMetres'],
                     'baselineGoalHorizontalAssociationMetres': row['baselineGoalAssociation']['horizontalMetres']})
    # Draw only the exact original OBJ, with the same fixed historical transform.
    mesh = W / 'conference-source-recovery/extracted-001/textured.obj'
    assert sha(mesh) == proposals['sourceMeshSHA256']
    reg = json.loads((inventory / 'evidence/REGISTRATION_RESULT.json').read_text())
    mesh_receipt = json.loads((inventory / 'evidence/MESH_INPUT_RECEIPT.json').read_text())
    q, t = reg['rotationOBJToLevel'], reg['translationOBJToLevel']
    vertices, triangles = [], []
    for line in mesh.open():
        parts = line.split()
        if parts and parts[0] == 'v':
            xyz = list(map(float, parts[1:])); assert len(xyz) == 3
            level = [sum(a * b for a, b in zip(axis, xyz)) + shift for axis, shift in zip(q, t)]
            vertices.append((level[0], level[2], -level[1]))
        elif parts and parts[0] == 'f':
            face = tuple(int(v.split('/')[0]) - 1 for v in parts[1:]); assert len(face) == 3
            triangles.append(face)
    assert (len(vertices), len(triangles)) == (18398, 29366)
    vertex_digest = hashlib.sha256(b''.join(struct.pack('<3f', *p) for p in vertices)).hexdigest()
    triangle_digest = hashlib.sha256(b''.join(struct.pack('<3i', *p) for p in triangles)).hexdigest()
    assert vertex_digest == mesh_receipt['transformedFloat32VertexBytesSHA'] == proposals['registeredFloat32VerticesSHA256']
    assert triangle_digest == mesh_receipt['triangleBytesSHA'] == proposals['trianglesInt32SHA256']
    forward, reverse = proposals['paths'][-2:]
    centered_reverse_matches = forward['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'] == reverse['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'][::-1]
    assert centered_reverse_matches
    summary = {'status': 'REVIEWED_GEOMETRY_PROPOSALS_NOT_PHYSICAL_ACCEPTANCE', 'sourceCommit': EXPECTED_COMMIT,
               'receiptSHA256': sha(receipt_file), 'proposalsSHA256': sha(proposal_file),
               'attempt001ProposalsByteIdentical': True, 'priorAttemptStillFailed': True,
               'controlsPassed': controls['count'], 'resultCounts': receipt['comparison'],
               'resources': {k: receipt[k] for k in ('aggregateCPUSeconds', 'wallSeconds', 'peakObservedAggregateRSS')},
               'graphNodes': proposals['graphNodes'], 'graphDirectedEdges': proposals['graphDirectedEdges'],
               'allRequestedEndpointsAndSourcePoseIndicesUnchanged': True, 'allRecordedLengthsRecomputed': True,
               'allGraphLengthsWithinUnchangedCap': True, 'allInputPinsUnchanged': True,
               'rows': rows, 'varpuCenteredReverseExactlyReversed': centered_reverse_matches,
               'tableFiveLegLengthSums': {key: sum(row[key] for row in rows[:5]) for key in ('nativeConnectorInclusiveMetres', 'shortestConnectorInclusiveMetres', 'centeredConnectorInclusiveMetres')},
               'figure': {'sourceMeshSHA256': sha(mesh), 'originalVertices': len(vertices), 'originalTriangles': len(triangles),
                          'renderedAllOriginalTriangleEdges': True, 'registeredFloat32VerticesSHA256': vertex_digest,
                          'trianglesInt32SHA256': triangle_digest, 'axes': ['native X = historical level X', 'native Z = minus historical level Y'],
                          'perspective': 'orthographic top-down; height omitted, not a floor/support/occupancy map',
                          'allPathsIncludeExactRequestedConnectors': True, 'output': 'conference-seven-objective-overview.png'},
               'nativeRoutingExecutedByReview': False, 'physicalAuthority': False, 'movementExecuted': False,
               'bodyValidation': 'notEstablished', 'fullFootprintSupport': 'notEstablished', 'cameraMeshCalibration': 'notEstablished'}
    draw_overview(vertices, triangles, proposals, rows)
    summary['figure']['sha256'] = sha(H / 'conference-seven-objective-overview.png')
    (H / 'RESULT_REVIEW.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({'rows': rows, 'tableFiveLegLengthSums': summary['tableFiveLegLengthSums'], 'figureSHA256': summary['figure']['sha256']}, indent=2))


def draw_overview(vertices, triangles, proposals, rows):
    from PIL import Image, ImageDraw, ImageFont
    image = Image.new('RGB', (2000, 1500), '#ffffff'); draw = ImageDraw.Draw(image)
    font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    bold_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    def text(x, y, value, size=23, fill='#243145', bold=False):
        draw.text((x, y), value, font=ImageFont.truetype(bold_path if bold else font_path, size), fill=fill)
    text(75, 45, 'Conference room: seven unchanged objectives', 43, bold=True)
    text(78, 111, 'Actual source-mesh proposals | shortest grid vs clearance-weighted grid', 27)
    text(78, 155, 'Historical estimated registration only. Not calibrated movement, body clearance or floor support.', 23, '#9a402c')
    box = (85, 245, 1260, 1350)
    xmin, xmax = min(p[0] for p in vertices) - .35, max(p[0] for p in vertices) + .35
    zmin, zmax = min(p[2] for p in vertices) - .35, max(p[2] for p in vertices) + .35
    scale = min((box[2] - box[0]) / (xmax - xmin), (box[3] - box[1]) / (zmax - zmin))
    xoff = box[0] + ((box[2] - box[0]) - scale * (xmax - xmin)) / 2
    zoff = box[1] + ((box[3] - box[1]) - scale * (zmax - zmin)) / 2
    def xy(p): return (xoff + (p[0] - xmin) * scale, zoff + (zmax - p[2]) * scale)
    draw.rectangle(box, fill='#fafbfc', outline='#dce2e8', width=2)
    for x in range(math.ceil(xmin), math.floor(xmax) + 1):
        px = xy((x, 0, 0))[0]; draw.line([(px, box[1]), (px, box[3])], fill='#edf0f3'); text(px - 8, box[3] + 14, str(x), 18, '#647184')
    for z in range(math.ceil(zmin), math.floor(zmax) + 1):
        py = xy((0, 0, z))[1]; draw.line([(box[0], py), (box[2], py)], fill='#edf0f3'); text(box[0] - 37, py - 11, str(z), 18, '#647184')
    projected = [xy(p) for p in vertices]
    for face in triangles:
        points = [projected[index] for index in face]
        draw.line(points + points[:1], fill='#d9dee4', width=1)
    colors = ['#4269ba', '#b9780c', '#228354', '#c34c46', '#7956a6', '#168a91', '#cc4d91']
    def dashed(points, color, width=3):
        phase = 0.
        for a, b in zip(points, points[1:]):
            distance = math.dist(a, b); used = 0.
            while used < distance:
                remaining = (11. if phase < 11. else 17.) - phase
                step = min(remaining, distance - used)
                if phase < 11. and distance:
                    p = tuple(a[k] + (b[k] - a[k]) * used / distance for k in range(2))
                    q = tuple(a[k] + (b[k] - a[k]) * (used + step) / distance for k in range(2))
                    draw.line([p, q], fill=color, width=width)
                used += step; phase = (phase + step) % 17.
                if step < 1e-9: phase = 0.
    for i, row in enumerate(proposals['paths']):
        points = [xy(p) for p in row['gridSelection']['distanceGrid']['requestedConnectorChainXYZ']]
        dashed(points, colors[i], 4 if i < 6 else 2)
    for i, row in enumerate(proposals['paths']):
        points = [xy(p) for p in row['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ']]
        if i != 6: draw.line(points, fill='#ffffff', width=10, joint='curve')
        draw.line(points, fill=colors[i], width=8 if i == 5 else (3 if i == 6 else 5), joint='curve')
    anchors = {}
    for row in proposals['paths']:
        a, b = row['sourcePoseIndices']
        anchors[a] = row['requestedStartXYZ']; anchors[b] = row['requestedGoalXYZ']
    offsets = {92: (-59, -39), 120: (-69, -39), 200: (-15, 14), 220: (-49, 12), 20: (-48, 12), 130: (14, -38), 160: (14, -10)}
    for index, point in anchors.items():
        px, py = xy(point); draw.ellipse((px - 6, py - 6, px + 6, py + 6), fill='#ffffff', outline='#1d2a3c', width=3)
        dx, dy = offsets[index]; label = str(index); font = ImageFont.truetype(bold_path, 22)
        bounds = draw.textbbox((px + dx, py + dy), label, font=font)
        draw.rectangle((bounds[0] - 5, bounds[1] - 3, bounds[2] + 5, bounds[3] + 3), fill='#ffffff')
        draw.text((px + dx, py + dy), label, font=font, fill='#1d2a3c')
    text(425, 1405, 'Native X / historical level X (m)', 21)
    text(88, 207, 'Native Z = -historical level Y (m)  |  all original triangle edges', 20, '#647184')
    x = 1325
    text(x, 245, '7 / 7 proposal-only outputs', 29, bold=True)
    text(x, 291, 'All seven native baselines associated.', 22)
    text(x, 328, 'No endpoint dropped or relocated.', 22)
    draw.line([(x, 393), (x + 86, 393)], fill='#35465c', width=5); text(x + 110, 375, 'Clearance-weighted', 23)
    dashed([(x, 439), (x + 86, 439)], '#35465c', 4); text(x + 110, 421, 'Shortest grid', 23)
    text(x, 487, 'Requested-connector lengths (m)', 23, bold=True)
    text(x + 258, 527, 'Shortest', 20, '#647184'); text(x + 407, 527, 'Centered', 20, '#647184')
    labels = ['92 → 120', '120 → 200', '200 → 220', '220 → 20', '20 → 92', '130 → 160', '160 → 130']
    for i, row in enumerate(rows):
        y = 573 + i * 54; draw.line([(x, y + 14), (x + 33, y + 14)], fill=colors[i], width=6)
        text(x + 48, y, labels[i], 23); text(x + 273, y, f"{row['shortestConnectorInclusiveMetres']:.3f}", 23); text(x + 425, y, f"{row['centeredConnectorInclusiveMetres']:.3f}", 23)
    text(x, 991, '130 ↔ 160 centered routes coincide;', 21)
    text(x, 1023, 'teal / pink overlay shows both directions.', 21)
    text(x, 1086, 'Interpretation limits', 24, '#9a402c', True)
    for i, line in enumerate(['Mesh projection is not a floor/support map.', 'Camera anchors are not body poses.', 'VARPU graph endpoint-edge proxy stays 0.', 'No full-body or margin validation ran.', 'No actual journey or live movement ran.']):
        text(x, 1132 + 37 * i, line, 20, '#5b6572')
    text(78, 1460, 'MuSHRoom / Xuqian Ren et al. / CC BY 4.0  •  Source 719ec5049016  •  No floor repair, smoothing or mesh changes', 18, '#647184')
    image.save(H / 'conference-seven-objective-overview.png')


if __name__ == '__main__':
    main()
