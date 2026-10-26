"""Phone-mask loop proposal only; no reference, actor, or physical authority.

Detour owns every leg search. SciPy owns connected components. The remaining
code deterministically selects four query endpoints and validates the returned
cycle; it is not a new planner. Importing this module performs no data load or
native query. Call propose_loop only in a separately authorized bounded worker.
"""
from pathlib import Path
import hashlib
import json
import math
import sys

import numpy as np
from scipy import ndimage

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
RES = .05
DISC = .375
STEP = .025
TURN_STEP = math.radians(5)
EPS = 1e-9
NUMERICAL_COALESCE = 1e-6
SIDES = ("north", "east", "south", "west")
ADAPTER_SHA = "5e0132f4711200bca1b7ae90eb27b5666ce0707b1573e815e40e622caff98c09"
PROTOCOL_SHA = "07555ca479879c3d30ea8561887007038f5383fa5adf0e70508a2b92c69b788a"


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def diagnostic_json_value(value):
    """Keep rejected native missing coordinates explicit, never invent zeros."""
    if isinstance(value, (float, np.floating)):
        return float(value) if math.isfinite(value) else None
    if isinstance(value, np.integer):
        return int(value)
    if isinstance(value, np.bool_):
        return bool(value)
    if isinstance(value, dict):
        return {k: diagnostic_json_value(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [diagnostic_json_value(v) for v in value]
    return value


def proposal_json(proposal):
    """Serialization only; the bounded owner chooses an exclusive output path."""
    return json.dumps(diagnostic_json_value(proposal), indent=2, allow_nan=False)+"\n"


def checked_mask(mask):
    mask = np.asarray(mask)
    if mask.ndim != 2 or mask.dtype != np.bool_ or not mask.size or mask.size > 60250:
        raise ValueError("bounded two-dimensional Boolean phone mask required")
    return mask


def choose_target(mask):
    """8-connected blocked islands; 4-connected walk diagnostics; no filling."""
    mask = checked_mask(mask)
    blocked, blocked_count = ndimage.label(~mask, structure=np.ones((3, 3), int))
    walk, walk_count = ndimage.label(mask, structure=ndimage.generate_binary_structure(2, 1))
    walk_cells = np.argwhere(mask)
    if not len(walk_cells):
        return None, walk, {"reason": "noWalkablePhoneCells", "blockedComponents": int(blocked_count), "walkComponents": 0}
    # Cell-centre +0.5 cancels in centroid differences; no world/reference pose.
    centre = walk_cells.mean(axis=0)
    border = set(map(int, np.concatenate((blocked[0], blocked[-1], blocked[:, 0], blocked[:, -1]))))
    rows = []
    for label, box in enumerate(ndimage.find_objects(blocked), 1):
        if label in border or box is None:
            continue
        local = np.argwhere(blocked[box] == label)
        cells = local + np.array([box[0].start, box[1].start])
        centroid = cells.mean(axis=0)
        first = int(np.min(cells[:, 0] * mask.shape[1] + cells[:, 1]))
        rows.append(((-len(cells), float(np.sum((centroid-centre)**2)), first), label, cells))
    diagnostic = {"blockedComponents": int(blocked_count), "walkComponents": int(walk_count),
                  "enclosedBlockedComponents": len(rows), "walkableCells": len(walk_cells),
                  "selectionOrder": "descending size, centroid distance squared, lowest C-order flat index",
                  "walkCentroidSourceIndex": centre.tolist()}
    if not rows:
        diagnostic["reason"] = "noEnclosedPhoneObstacleTarget"
        return None, walk, diagnostic
    rows.sort(key=lambda row: row[0])
    key, label, cells = rows[0]
    diagnostic["selectedRankKey"] = list(key)
    return {"label": int(label), "cells": cells}, walk, diagnostic


def outline_segments(cells):
    """Exact exposed cell edges in integer source-grid coordinates, not a hull."""
    cells = {tuple(map(int, p)) for p in cells}
    segments = []
    for i, j in sorted(cells):
        if (i-1, j) not in cells: segments.append([[i, j], [i, j+1]])
        if (i+1, j) not in cells: segments.append([[i+1, j], [i+1, j+1]])
        if (i, j-1) not in cells: segments.append([[i, j], [i+1, j]])
        if (i, j+1) not in cells: segments.append([[i, j+1], [i+1, j+1]])
    return segments


def side_geometry(cells, origin):
    cells = np.asarray(cells, int)
    origin = np.asarray(origin, float)
    low = origin + cells.min(axis=0)*RES
    high = origin + (cells.max(axis=0)+1)*RES
    middle = .5*(low+high)
    offset = DISC + RES*math.sqrt(2)/2
    targets = np.array([[middle[0], high[1]+offset], [high[0]+offset, middle[1]],
                        [middle[0], low[1]-offset], [low[0]-offset, middle[1]]])
    return low, high, targets


def winding_numbers(closed_source_xy, target_source_xy):
    """Integer directed crossing count; a target on the centreline is invalid.

    No resampling, area fit, angle rounding, or route repair is performed.
    Positive winding is counterclockwise in source level-X/level-Y coordinates.
    """
    path = np.asarray(closed_source_xy, float)
    q = np.asarray(target_source_xy, float)
    if (path.ndim != 2 or path.shape[1] != 2 or len(path) < 4 or q.ndim != 2 or q.shape[1] != 2
            or not np.isfinite(path).all() or not np.isfinite(q).all()
            or not np.array_equal(path[0], path[-1])):
        raise ValueError("finite explicitly closed path and target centres required")
    winding = np.zeros(len(q), np.int32)
    on_boundary = np.zeros(len(q), bool)
    for a, b in zip(path[:-1], path[1:]):
        d = b-a
        length = float(np.linalg.norm(d))
        if length <= EPS:
            on_boundary |= np.linalg.norm(q-a, axis=1) <= EPS
            continue
        delta = q-a
        cross = d[0]*delta[:, 1] - d[1]*delta[:, 0]
        along = delta @ d
        on_boundary |= (np.abs(cross) <= EPS*length) & (along >= -EPS*length) & (along <= length*length+EPS*length)
        winding += ((a[1] <= q[:, 1]) & (b[1] > q[:, 1]) & (cross > 0)).astype(np.int32)
        winding -= ((a[1] > q[:, 1]) & (b[1] <= q[:, 1]) & (cross < 0)).astype(np.int32)
    return winding, on_boundary


def winding_receipt(path, centres):
    winding, boundary = winding_numbers(path, centres)
    codes, counts = np.unique(winding, return_counts=True)
    valid = bool(len(winding) and not boundary.any() and abs(int(winding[0])) == 1 and np.all(winding == winding[0]))
    return {"passed": valid, "targetCentresChecked": len(winding), "centresOnRoute": int(boundary.sum()),
            "windingHistogram": {str(int(k)): int(n) for k, n in zip(codes, counts)},
            "commonSignedWinding": int(winding[0]) if valid else None,
            "signCoordinates": "source level-X, level-Y", "boundaryToleranceMetres": EPS,
            "simpleNonSelfIntersectingPolygonProven": False}


def planar_cycle(waypoints, native_legs):
    """Retain native corners and explicitly connect each projected goal to its requested waypoint."""
    if len(waypoints) != 4 or len(native_legs) != 4:
        raise ValueError("four fixed waypoints and native legs required")
    path = [np.asarray(waypoints[0], float).copy()]
    path[0][1] = 0.
    connectors = []
    for i, leg in enumerate(native_legs):
        if not leg["complete"]:
            raise ValueError("cannot assemble an incomplete native cycle")
        coalescences = []
        for point_index, point in enumerate(leg["points"]):
            p = np.asarray(point, float).copy()
            if p.shape != (3,) or not np.isfinite(p).all():
                raise ValueError("nonfinite native corner")
            p[1] = 0.  # Supplied level-map geometry only, never a physics pose.
            residual = float(np.linalg.norm((p-path[-1])[[0, 2]]))
            if residual > NUMERICAL_COALESCE:
                path.append(p)
            else:
                coalescences.append({"nativePointIndex": point_index, "originalNativePoint": list(point),
                    "retainedCandidatePoint": path[-1].tolist(), "horizontalResidualMetres": residual,
                    "reason": "consecutive native candidate duplicate within predeclared 1e-6 m"})
        endpoint = np.asarray(waypoints[(i+1) % 4], float).copy()
        endpoint[1] = 0.
        length = float(np.linalg.norm((endpoint-path[-1])[[0, 2]]))
        connector = {"legIndex": i, "from": path[-1].tolist(), "to": endpoint.tolist(),
                     "lengthMetresBeforeNumericalCoalescing": length, "nativeSearchForConnector": False,
                     "nativeCornerCoalescences": coalescences, "goalNeighbourCoalescences": [],
                     "coalescedToExactRequestedWaypoint": length <= NUMERICAL_COALESCE,
                     "reason": "retain exact requested waypoint for numerical coincidence" if length <= NUMERICAL_COALESCE else "explicit associated projected-goal connector retained",
                     "numericalCoalescingBoundMetres": NUMERICAL_COALESCE,
                     "actorStartGoalOrPoseChanged": False}
        connectors.append(connector)
        if length > .1+EPS:
            raise ValueError("projected goal connector exceeds existing association bound")
        if length > NUMERICAL_COALESCE:
            path.append(endpoint)
        else:
            path[-1] = endpoint
        # Replacing a numerically coincident goal can make its previous native
        # vertex coincident too. Retain the exact waypoint; record every removal.
        while len(path) > 1:
            residual = float(np.linalg.norm((path[-1]-path[-2])[[0, 2]]))
            if residual > NUMERICAL_COALESCE:
                break
            connector["goalNeighbourCoalescences"].append({"originalCandidatePoint": path[-2].tolist(),
                "retainedCandidatePoint": endpoint.tolist(), "horizontalResidualMetres": residual,
                "reason": "consecutive candidate duplicate after retaining exact requested waypoint"})
            del path[-2]
        connector["lengthMetres"] = 0. if length <= NUMERICAL_COALESCE else length
    path[-1] = path[0].copy()
    if len(path) < 5:
        raise ValueError("degenerate four-waypoint cycle")
    return np.asarray(path), connectors


def sampled_closed_check(model, path):
    """Unchanged source sweep, explicit closure seam, plus exact endpoints.

    Returned poses are source XY/yaw samples for route-flag diagnostics only.
    Neither the finite rectangle lattice nor this routine is continuous contact.
    """
    p = np.asarray(path, float)
    xy = np.column_stack((p[:, 0], -p[:, 2]))
    delta = np.diff(xy, axis=0)
    lengths = np.linalg.norm(delta, axis=1)
    if np.any(lengths <= EPS) or not np.array_equal(xy[0], xy[-1]):
        raise ValueError("nondegenerate explicitly closed centreline required")
    heading = np.arctan2(delta[:, 1], delta[:, 0])
    source_path = np.column_stack((xy[:, 0], np.zeros(len(xy)), xy[:, 1]))
    # Appending the first outgoing segment makes the unchanged routine test the
    # turn from the final incoming segment at the closure seam as well.
    upstream = model.rr.sweep_ok(model.mask, model.origin, np.vstack((source_path, source_path[1])))
    poses = []
    endpoints_ok = True
    turns_ok = True
    for i, (a, b, length, theta) in enumerate(zip(xy[:-1], xy[1:], lengths, heading)):
        for point in (a, b):
            endpoints_ok &= bool(model.rr.rect_ok(model.mask, model.origin, *point, float(theta)))
        for distance in np.arange(0., length+1e-9, STEP):
            point = a+(b-a)*min(1., float(distance/length))
            poses.append((float(point[0]), float(point[1]), float(theta)))
        poses.append((float(b[0]), float(b[1]), float(theta)))
        previous = float(heading[i-1])
        change = (float(theta)-previous+math.pi) % (2*math.pi)-math.pi
        for k in range(int(abs(change)/TURN_STEP)+2):
            angle = previous+change*min(1., k*TURN_STEP/max(abs(change), 1e-9))
            turns_ok &= bool(model.rr.rect_ok(model.mask, model.origin, *a, angle))
            poses.append((float(a[0]), float(a[1]), float(angle)))
    return {"passed": upstream == "ok" and endpoints_ok and turns_ok,
            "unchangedUpstreamSweepIncludingSeam": upstream, "exactSegmentEndpointHeadingsFit": endpoints_ok,
            "allVertexTurnsIncludingClosureFit": turns_ok, "sampledPoseCount": len(poses),
            "translationSampleSpacingMetres": STEP, "turnSampleStepDegrees": 5,
            "continuousClearanceProven": False}, poses


def route_flags(model, poses):
    flag = model.flags["lowUnresolvedFlag"]
    rb = model.rr.RB
    unique = set()
    visits = 0
    flagged_poses = 0
    outside_samples = 0
    for x, y, angle in poses:
        c, s = math.cos(angle), math.sin(angle)
        xx = x+rb[:, 0]*c-rb[:, 1]*s
        yy = y+rb[:, 0]*s+rb[:, 1]*c
        i = np.floor((xx-model.origin[0])/RES).astype(int)
        j = np.floor((yy-model.origin[1])/RES).astype(int)
        inside = (i >= 0) & (i < flag.shape[0]) & (j >= 0) & (j < flag.shape[1])
        outside_samples += int((~inside).sum())
        cells = np.unique(np.column_stack((i[inside], j[inside])), axis=0)
        marked = cells[flag[cells[:, 0], cells[:, 1]]]
        visits += len(marked)
        flagged_poses += bool(len(marked))
        unique.update(map(tuple, marked.tolist()))
    return {"scope": "planned sampled route, not executed actor exposure", "sampledPoseCount": len(poses),
            "lowUnresolvedCellVisits": visits, "uniqueLowUnresolvedCells": len(unique),
            "posesWithLowUnresolved": int(flagged_poses), "outsideMaskRectangleSamples": outside_samples,
            "visitDefinition": "one visit per unique flag cell per sampled pose; duplicate seam/end samples retained",
            "farOnlyDipConflict": "unavailable in supplied split artifact"}


def nominal_budget(path):
    """Preregisterable three-lap tick proposal, never an execution grant."""
    path = np.asarray(path, float)
    delta = np.diff(path[:, [0, 2]], axis=0)
    lengths = np.linalg.norm(delta, axis=1)
    if np.any(lengths <= EPS) or not np.array_equal(path[0], path[-1]):
        raise ValueError("nondegenerate closed path required for tick proposal")
    heading = np.arctan2(delta[:, 1], delta[:, 0])
    turns = (heading-np.roll(heading, 1)+math.pi) % (2*math.pi)-math.pi
    translation = int(math.ceil(float(lengths.sum())/.02))
    turn_ticks = [int(math.ceil(abs(float(angle))/math.radians(1))) for angle in turns]
    # Fixed disclosed allowance, not fitted to any actor/reference outcome.
    allowance_per_lap = 300
    terminal_allowance = 150
    return {"status": "proposal_requires_separate_execution_freeze", "laps": 3,
            "nominalTranslationMetresPerTick": .02, "maximumAppliedTranslationMetresPerTick": .025,
            "maximumYawRadiansPerTick": math.radians(1), "tickRateHz": 15,
            "perLapLengthMetres": float(lengths.sum()), "perLapTranslationTicksCeilTotalLength": translation,
            "perLapTranslationTicksSumSegmentCeilsDiagnostic": int(np.ceil(lengths/.02).sum()),
            "perLapTurnRadiansIncludingClosure": turns.tolist(), "perTurnTicks": turn_ticks,
            "perLapTurnTicksIncludingClosure": sum(turn_ticks),
            "fixedAllowanceTicksPerLap": allowance_per_lap, "fixedTerminalDrainAllowanceTicks": terminal_allowance,
            "proposedMaximumEpisodeTicks": 3*(translation+sum(turn_ticks)+allowance_per_lap)+terminal_allowance,
            "allowanceChosenFromOutcome": False, "deadlockRuleNotExtended": True,
            "actorResetOrTeleportAllowed": False}


def pinned_model(model):
    """Tie the passed object to the reviewed, unmodified CandidateMap cut."""
    adapter = GAME/"source/candidate_map.py"
    module = sys.modules.get(type(model).__module__)
    if (module is None or Path(module.__file__).resolve() != adapter
            or type(model) is not module.CandidateMap or digest(adapter) != ADAPTER_SHA
            or digest(HERE/"PROTOCOL.md") != PROTOCOL_SHA):
        raise ValueError("reviewed CandidateMap/protocol identity required")
    if model.engine is None or model.mask is not model.flags["walk"] or model.mask.flags.writeable:
        raise ValueError("live immutable provided-phone-map instance required")
    if model.mask.shape != (241, 250) or not np.isfinite(model.origin).all():
        raise ValueError("fixed phone-map geometry required")
    expected = dict(module.SOURCE_PINS)
    expected.update({adapter: ADAPTER_SHA, HERE/"PROTOCOL.md": PROTOCOL_SHA,
                     GAME/"inputs/koivu_5cm_occthres_split0.7.npz": module.SPLIT_SHA,
                     GAME/"inputs/koivu_5cm_v2_pipeline2_out.npz": module.META_SHA})
    for path, sha in expected.items():
        if digest(path) != sha:
            raise ValueError("source/input pin mismatch: "+str(path))
    rr, de = module.modules()
    if model.rr is not rr or model.de is not de:
        raise ValueError("map implementation differs from pinned modules")
    return {str(p.relative_to(GAME.parent)): sha for p, sha in expected.items()}


def propose_loop(candidate_map):
    """Construct one fixed phone-only proposal; no alternative if a stage fails."""
    model = candidate_map
    pins = pinned_model(model)
    pins[str(Path(__file__).resolve().relative_to(GAME.parent))] = digest(__file__)
    result = {"status": "pending", "targetComponent": None, "targetOutline": None,
              "waypoints": [], "nativeLegs": [], "closedPath": None, "windingChecks": None,
              "sampledFit": None, "flagCounts": None, "rejectedStages": [], "sourcePins": pins,
              "semanticTarget": "unresolvedGeometricProxy", "lapEpisodeAuthorized": False,
              "physicalAuthority": False, "referenceInputsUsed": False, "mapRevision": model.revision,
              "requestedLapsIfLaterApproved": 3, "movementEpisodesExecuted": 0,
              "failureMeaning": "no loop found by this fixed construction, not global infeasibility"}

    def stop(status, stage, details):
        result["status"] = status
        result["rejectedStages"].append({"stage": stage, "details": details})
        return result

    target, walk_labels, topology = choose_target(model.mask)
    result["topology"] = topology
    if target is None:
        return stop(topology["reason"], "target", topology["reason"])
    cells = target["cells"]
    centres = np.asarray(model.origin)+(cells+.5)*RES
    low, high, side_targets = side_geometry(cells, model.origin)
    result["targetComponent"] = {"blocked8ComponentLabel": target["label"], "cellCount": len(cells),
        "sourceCellIndices": cells.tolist(), "sourceCentroidXY": centres.mean(axis=0).tolist(),
        "sourceBoundsMinXY": low.tolist(), "sourceBoundsMaxXY": high.tolist(),
        "meaning": "largest enclosed blocked geometric component; not a verified table label"}
    result["targetOutline"] = {"representation": "exposed integer-grid edges", "sourceGridEdges": outline_segments(cells),
        "originSourceXY": list(model.origin), "cellSizeMetres": RES,
        "gameTransform": "[sourceX, sourceY, height] -> [sourceX, height, -sourceY]"}
    clearance = ndimage.distance_transform_edt(model.mask)*RES-RES*math.sqrt(2)/2
    candidates = np.argwhere(clearance >= DISC)
    positions = np.asarray(model.origin)+(candidates+.5)*RES
    side_masks = (positions[:, 1] >= high[1], positions[:, 0] >= high[0],
                  positions[:, 1] <= low[1], positions[:, 0] <= low[0])
    result["waypointSelection"] = {"discFitCentres": len(candidates), "sideOrder": list(SIDES),
        "halfPlanes": "on or outside target bounding-rectangle side; source north is +levelY",
        "targetOffsetMetres": DISC+RES*math.sqrt(2)/2, "trials": []}
    selected_indices = []
    for side, target_xy, side_mask in zip(SIDES, side_targets, side_masks):
        available = np.flatnonzero(side_mask)
        if len(available):
            squared = np.sum((positions[available]-target_xy)**2, axis=1)
            available = available[np.lexsort((candidates[available, 1], candidates[available, 0], squared))]
        rejected = []
        chosen = None
        for index in available:
            x, y = positions[index]
            heading = next((k for k in range(72) if model.rr.rect_ok(model.mask, model.origin, x, y, math.radians(k*5))), None)
            if heading is not None:
                chosen = int(index)
                break
            rejected.append(candidates[index].tolist())
        trial = {"side": side, "fixedTargetSourceXY": target_xy.tolist(), "halfPlaneCandidates": len(available),
                 "rejectedNoHeadingFitSourceIJ": rejected, "chosenSourceIJ": None}
        result["waypointSelection"]["trials"].append(trial)
        if chosen is None:
            return stop("noFixedSideWaypoint", "waypoints", side)
        i, j = map(int, candidates[chosen])
        trial.update(chosenSourceIJ=[i, j], firstFittingSourceHeadingDegrees=heading*5,
                     walk4Component=int(walk_labels[i, j]))
        selected_indices.append((i, j))
        x, y = positions[chosen]
        result["waypoints"].append({"side": side, "sourceIJ": [i, j], "point": [float(x), 0., float(-y)]})
    if len(set(selected_indices)) != 4:
        return stop("duplicateFixedWaypoints", "waypoints", "independent first choices are not replaced")
    labels = [int(walk_labels[i, j]) for i, j in selected_indices]
    if len(set(labels)) != 1 or labels[0] == 0:
        return stop("fixedWaypointsDisconnected", "topology", {"walk4Components": labels})
    points = [w["point"] for w in result["waypoints"]]
    # Every fixed query is retained even if an earlier leg fails. No alternate
    # waypoint, reverse-cycle retry, search tuning or reference scoring follows.
    for i in range(4):
        route = model.route(points[i], points[(i+1) % 4])
        result["nativeLegs"].append(route)
        if not route["complete"]:
            result["rejectedStages"].append({"stage": "nativeLeg", "legIndex": i, "reason": route["reason"]})
    if result["rejectedStages"]:
        result["status"] = "fixedNativeCycleRejected"
        return result
    path, connectors = planar_cycle(points, result["nativeLegs"])
    result["closedPath"] = path.tolist()
    result["projectedGoalConnectors"] = connectors
    sampled, poses = sampled_closed_check(model, path)
    result["sampledFit"] = sampled
    result["flagCounts"] = route_flags(model, poses)
    source_xy = np.column_stack((path[:, 0], -path[:, 2]))
    result["windingChecks"] = winding_receipt(source_xy, centres)
    result["pathLengthMetres"] = float(np.linalg.norm(np.diff(source_xy, axis=0), axis=1).sum())
    result["threeLapTickBudgetProposal"] = nominal_budget(path)
    if not sampled["passed"]:
        return stop("sampledClosedCycleRejected", "closedSampledFit", sampled)
    if not result["windingChecks"]["passed"]:
        return stop("targetWindingRejected", "winding", result["windingChecks"])
    result["status"] = "phoneModelLoopFeasibleSemanticTargetUnresolved"
    result["initialYawRadians"] = math.atan2(path[1, 2]-path[0, 2], path[1, 0]-path[0, 0])
    return result


def write_phone_only_diagnostic(proposal, candidate_map, output):
    """Optional later plot of supplied masks and frozen proposal, never truth.

    No map construction, new route query, reference field or actor data is used.
    Output is exclusive. The caller owns aggregate disk/time/RSS supervision.
    """
    model = candidate_map
    pinned_model(model)
    if proposal["mapRevision"] != model.revision or proposal["referenceInputsUsed"] is not False:
        raise ValueError("matching phone-only proposal required")
    import matplotlib
    matplotlib.use("Agg")
    from matplotlib import pyplot as plt
    from matplotlib.collections import LineCollection

    ox, oy = model.origin
    extent = [ox, ox+model.mask.shape[0]*RES, oy, oy+model.mask.shape[1]*RES]
    fig, ax = plt.subplots(figsize=(8, 8), constrained_layout=True)
    ax.imshow(model.mask.T, origin="lower", extent=extent, interpolation="nearest",
              cmap="Greys_r", vmin=0, vmax=1)
    flags = np.ma.masked_where(~model.flags["lowUnresolvedFlag"].T, model.flags["lowUnresolvedFlag"].T)
    ax.imshow(flags, origin="lower", extent=extent, interpolation="nearest", cmap="Blues", alpha=.65, vmin=0, vmax=1)
    outline = proposal.get("targetOutline")
    if outline:
        edges = np.asarray(outline["sourceGridEdges"], float)*RES+np.asarray(model.origin)
        ax.add_collection(LineCollection(edges, colors="darkorange", linewidths=1.0, label="geometric target outline"))
    path = proposal.get("closedPath")
    if path:
        path = np.asarray(path, float)
        ax.plot(path[:, 0], -path[:, 2], color="crimson", linewidth=1.8, label="candidate centreline")
    for waypoint in proposal.get("waypoints", []):
        x, _, z = waypoint["point"]
        ax.plot(x, -z, "o", color="limegreen", markersize=5)
        ax.annotate(waypoint["side"][0].upper(), (x, -z), xytext=(4, 4), textcoords="offset points")
    ax.set(xlabel="Phone level X (m)", ylabel="Phone level Y (m); game Z has opposite sign",
           title="Phone-mask geometric loop proposal — not a semantic table label\n"+proposal["status"],
           xlim=extent[:2], ylim=extent[2:])
    ax.set_aspect("equal")
    ax.text(.01, .01, "White: permissive walk mask | blue: unresolved low flag\nNo FARO, actor trace, or physical clearance evidence",
            transform=ax.transAxes, fontsize=8, va="bottom", bbox={"facecolor": "white", "alpha": .85, "edgecolor": "none"})
    if outline or path is not None:
        ax.legend(loc="upper right", fontsize=8)
    output = Path(output)
    try:
        with output.open("xb") as f:
            fig.savefig(f, format="png", dpi=140)
    finally:
        plt.close(fig)
    return {"path": str(output), "bytes": output.stat().st_size, "sha256": digest(output),
            "referenceInputsUsed": False, "newRouteQueries": 0, "physicalAuthority": False}
