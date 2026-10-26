"""Explicit geometry variants over unchanged pinned map, Detour and sampled checks."""
from pathlib import Path
import hashlib, importlib.util, json, math, sys
sys.dont_write_bytecode = True
import numpy as np
from scipy import ndimage

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
WS = GAME.parent
OLD = GAME/"table-loop-proposal"
PROFILES = {
    "body45cmMargin0": dict(width=.45, depth=.30, height=1.60, margin=0., nativeProposalRadius=.225),
    "body45cmMargin5cm": dict(width=.45, depth=.30, height=1.60, margin=.05, nativeProposalRadius=.275),
    "abstract28cmProfile": dict(width=.28, depth=.30, height=1.60, margin=0., nativeProposalRadius=.15),
}
NATIVE_CELL_SIZE = .025
ADAPTER_SHA = "5e0132f4711200bca1b7ae90eb27b5666ce0707b1573e815e40e622caff98c09"
LOOP_SHA = "8ff34e28a8b30961db2c287f5e91ddf29497ca8ecc729bf6023afae185493cc6"
RECT_SHA = "c96f1cb4e87e1f283645f4dbe7e8ee76f51b1d701ddf6a0965be4e1a1bd5c980"
BINDING_SHA = "8ab51b8fe7ac2585cfbe797615dd9ac78956e6cb14277deb092aca19df38787d"
PROPOSAL_SHA = "45f034606811b7896dea48ff2d0ebc68166b70a090400338cd1900f65b38b78a"
TOPOLOGY_SHA = "7e5b7923a4435559bb7bc6be90f8abb0fb14b4a873d9ec7718a76c9014ed24a9"
TOPOLOGY_RESULT_SHA = "bc31ee23f0333d476e8508e715d98776a2a6af0cacd72b4ecff089ddb4513301"


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_pinned(name, path, expected):
    if sha(path) != expected: raise ValueError("source pin mismatch: "+str(path))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def geometry(name, proposal_radius=None):
    profile = PROFILES[name]
    lateral = profile["width"]*.5+profile["margin"]
    forward = profile["depth"]*.5+profile["margin"]
    if proposal_radius is not None and not (name == "abstract28cmProfile" and proposal_radius == .125):
        raise ValueError("only the predeclared abstract28 proposal-only .125 fallback is permitted")
    radius = profile["nativeProposalRadius"] if proposal_radius is None else proposal_radius
    radius32, cell32 = np.float32(radius), np.float32(NATIVE_CELL_SIZE)
    quotient32 = np.float32(radius32/cell32)
    cells = int(math.ceil(float(quotient32)))
    return {**profile, "nativeProposalRadius": radius, "publicProfile": name,
        "proposalOnlyFallback": proposal_radius is not None, "horizontalEnvelopeWidth": 2*lateral,
        "horizontalEnvelopeDepth": 2*forward, "halfLateral": lateral, "halfForward": forward,
        "nativeRadiusIntended": radius, "nativeRadiusFloat32": float(radius32),
        "nativeRadiusPolicy": "explicit proposal-only radius; unchanged full rectangle must validate every candidate",
        "maxHalfBodyEnvelopeRadiusDiagnostic": max(lateral, forward),
        "nativeCellSize": NATIVE_CELL_SIZE, "nativeCellSizeFloat32": float(cell32),
        "nativeFloat32RadiusCellQuotient": float(quotient32), "nativeWalkableRadiusCells": cells,
        "nativeEffectiveErosionRadiusMetres": cells*float(cell32),
        "nativeRadiusFormula": "(int)std::ceil(c->radius/config.cs); operands are Float32",
        "nativeHeight": 1.75, "sourceMaskCellSize": .05, "newSensorDetailCreated": False,
        "discIsNotFullRectangleClearance": True, "circleFailureIsNotPhysicalFitImpossibility": True,
        "abstractGeometrySensitivityOnly": name == "abstract28cmProfile"}


def base_module():
    if sha(GAME/"source/candidate_map.py") != ADAPTER_SHA: raise ValueError("original adapter mismatch")
    sys.path.insert(0, str(GAME/"source"))
    import candidate_map
    if Path(candidate_map.__file__).resolve() != GAME/"source/candidate_map.py": raise ValueError("wrong adapter import")
    candidate_map.modules()  # Exact original source/native pin checks, no engine build.
    return candidate_map


def rectangle_module(name, proposal_radius=None):
    base_module()
    g = geometry(name, proposal_radius)
    rr = load_pinned("rectangle_variant_"+name, GAME/"upstream/scripts/routes_rect.py", RECT_SHA)
    rr.LAT, rr.FORE, rr.DISC = g["halfLateral"], g["halfForward"], g["nativeRadiusIntended"]
    # Exact original rectangle lattice construction, only declared half-extents vary.
    gx = np.arange(-rr.FORE, rr.FORE+1e-9, .025)
    gy = np.arange(-rr.LAT, rr.LAT+1e-9, .025)
    # Width .28 is not a multiple of .025: never omit the actual positive
    # rectangle edge. Existing divisible 45/55 cm lattices remain unchanged.
    if rr.FORE-gx[-1] > 1e-9: gx = np.r_[gx, rr.FORE]
    if rr.LAT-gy[-1] > 1e-9: gy = np.r_[gy, rr.LAT]
    rx, ry = np.meshgrid(gx, gy, indexing="ij")
    rr.RB = np.c_[rx.ravel(), ry.ravel()]
    rr.RB.setflags(write=False)
    return rr


def evaluate_variant(name, native_directory, native_library_sha256, proposal_radius=None):
    cm = base_module()
    g = geometry(name, proposal_radius)
    native_directory = Path(native_directory).resolve()
    library = native_directory/"libblind_detour.so"
    if len(native_library_sha256) != 64 or sha(library) != native_library_sha256:
        raise ValueError("explicit approved variant native library SHA required")
    proposal_path = OLD/"run-03/artifacts/PROPOSAL.json"
    if sha(proposal_path) != PROPOSAL_SHA or sha(OLD/"CENTRE_TOPOLOGY.json") != TOPOLOGY_RESULT_SHA:
        raise ValueError("fixed original target/topology provenance mismatch")
    target = np.asarray(json.loads(proposal_path.read_text())["targetComponent"]["sourceCellIndices"], int)
    if target.shape != (4667, 2): raise ValueError("fixed target size")
    previous = json.loads((OLD/"CENTRE_TOPOLOGY.json").read_text())
    proxy = np.asarray(previous["fixedTargetNearestCentroidCell"], int)
    rr = rectangle_module(name, proposal_radius)
    de = load_pinned("detour_binding_variant_"+name, native_directory/"detour_engine.py", BINDING_SHA)
    loop = load_pinned("loop_variant_"+name, OLD/"table_loop.py", LOOP_SHA)
    topo = load_pinned("topology_variant_"+name, OLD/"topology_quick.py", TOPOLOGY_SHA)
    loop.DISC = g["nativeRadiusIntended"]
    original_choose_target = loop.choose_target
    def fixed_choose_target(mask):
        chosen, labels, report = original_choose_target(mask)
        if chosen is None or not np.array_equal(chosen["cells"], target):
            raise ValueError("original target changed; no substitution allowed")
        return chosen, labels, report
    loop.choose_target = fixed_choose_target
    with cm.CandidateMap() as model:
        model.close()  # Original fixed loader reused; no original engine queries.
        model.rr, model.de = rr, de
        model.revision = hashlib.sha256((model.revision+json.dumps(g, sort_keys=True)+native_library_sha256).encode()).hexdigest()
        pins = dict(cm.SOURCE_PINS)
        pins.update({GAME/"source/candidate_map.py": ADAPTER_SHA, OLD/"table_loop.py": LOOP_SHA,
            proposal_path: PROPOSAL_SHA, OLD/"topology_quick.py": TOPOLOGY_SHA,
            OLD/"CENTRE_TOPOLOGY.json": TOPOLOGY_RESULT_SHA, library: native_library_sha256,
            native_directory/"detour_engine.py": BINDING_SHA,
            GAME/"inputs/koivu_5cm_occthres_split0.7.npz": cm.SPLIT_SHA,
            GAME/"inputs/koivu_5cm_v2_pipeline2_out.npz": cm.META_SHA,
            HERE/"PROTOCOL.md": sha(HERE/"PROTOCOL.md"), Path(__file__): sha(__file__)})
        def validate_variant(actual):
            if actual is not model or actual.rr is not rr or actual.de is not de or actual.mask.flags.writeable:
                raise ValueError("isolated variant identity/immutable map mismatch")
            if actual.engine.config.radius != g["nativeRadiusIntended"] or actual.engine.config.cell_size != NATIVE_CELL_SIZE:
                raise ValueError("variant native configuration mismatch")
            for path, expected in pins.items():
                if sha(path) != expected: raise ValueError("variant source/input changed")
            return {str(path): expected for path, expected in pins.items()}
        loop.pinned_model = validate_variant
        vertices, triangles = rr.quads(model.mask, model.origin, .05)
        vertices[:, 2] *= -1
        triangles = triangles[:, [0, 2, 1]].copy()
        model.engine = de.Engine(vertices, triangles, de.Config(radius=g["nativeRadiusIntended"], height=1.75,
            cell_size=NATIVE_CELL_SIZE, max_climb=0.), mode="known-provided-map")
        candidate = loop.propose_loop(model)
        eligibility = model.mask & (ndimage.distance_transform_edt(model.mask)*.05-.05*np.sqrt(2)/2 >= g["nativeRadiusIntended"])
        topology = topo.analyse(eligibility, target, proxy)
        validate_variant(model)
        return {"profile": name, "geometry": g, "candidate": candidate, "discCentreTopology": topology,
            "eligibleCentreCount": int(eligibility.sum()), "fixedOriginalTargetCells": 4667,
            "fixedTargetProbe": proxy.tolist(), "rawWalkTopologyEvidence": {"path": str(OLD/"CENTRE_TOPOLOGY.json"), "sha256": TOPOLOGY_RESULT_SHA},
            "sourcePins": {str(path): expected for path, expected in pins.items()},
            "sourceInputHashesVerifiedBeforeAndAfter": True, "nativeLibrarySHA256": native_library_sha256,
            "movementEpisodesExecuted": 0, "referenceInputsUsed": False, "physicalAuthority": False}


def serialize(value):
    if isinstance(value, float) and not math.isfinite(value): return None
    if isinstance(value, dict): return {k: serialize(v) for k, v in value.items()}
    if isinstance(value, (tuple, list)): return [serialize(v) for v in value]
    return value
