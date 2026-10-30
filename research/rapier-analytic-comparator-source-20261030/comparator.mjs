/**
 * Source-only adapter for official Rapier JS 0.21.0. Not executed or admitted.
 * Caller owns immutable input/package verification, WASM init and aggregate guard.
 * No physics implementation: collision/ground/movement calculation stays upstream.
 */
export const FROZEN = Object.freeze({
  schema: 1, packageVersion: "0.21.0", coreSourceVersion: "0.36.0",
  coreCommit: "b716d375efc0201003f0cd9ef7168eee0b62c177",
  numericRepresentation: "Float32", up: Object.freeze([0, 1, 0]),
  bodyMetres: Object.freeze([0.45, 0.30, 1.60]),
  horizontalMarginMetres: 0.15,
  controllerOffsetMetres: 0.002, // Additional gap; NOT lower exclusion or horizontal margin.
  maxSlopeRadians: 15 * Math.PI / 180,
  minSlopeSlideRadians: 15 * Math.PI / 180,
  normalNudgeFactor: 0.0001, timestep: 1 / 60,
  autostep: false, snapToGround: false, impulses: false,
  maximumDesiredTranslation: 0.025, maximumControllerCalls: 2000,
  originalVTKLowerExclusionMetres: 0.002, // Baseline unchanged; not applied to full KCC cuboid.
});
export const ARMS = Object.freeze(["raw_trimesh", "two_sided_internal_edges"]);
export const ENVELOPES = Object.freeze(["body", "horizontal_margin"]);
function requireValue(ok, message) { if (!ok) throw new Error(message); }
const vector = (a) => ({x: a[0], y: a[1], z: a[2]});
const xyz = (v) => [v.x, v.y, v.z];
const xyzw = (q) => [q.x, q.y, q.z, q.w];
const finiteArray = (a, n) => Array.isArray(a) && a.length === n && a.every(Number.isFinite);
const equal = (a, b) => a.length === b.length && a.every((v, i) => Object.is(v, b[i]));
function poseOf(c) { return [...xyz(c.translation()), ...xyzw(c.rotation())]; }
function queryRotation(yaw) {
  // Existing source convention: +X forward, positive yaw toward +Z.
  // Rapier uses right-handed Y-axis quaternions, hence the minus sign.
  return {x: 0, y: -Math.sin(yaw / 2), z: 0, w: Math.cos(yaw / 2)};
}
function checkProbe(p) {
  requireValue(typeof p.id === "string" && p.id.length > 0 && p.id.length <= 160, "invalid probe id");
  requireValue(["translation", "stationary", "turn"].includes(p.kind), "unknown probe kind");
  requireValue(finiteArray(p.foot, 3) && Number.isFinite(p.yawRadians), "invalid frozen pose");
  requireValue(finiteArray(p.desiredDelta, 3), "invalid desired delta");
  requireValue(["exact_xyz", "horizontal_projection"].includes(p.inputArm), "input arm must be explicit");
  requireValue(p.independentEvidence && typeof p.independentEvidence === "object", "missing independent evidence/unknown record");
  requireValue(Math.hypot(...p.desiredDelta) <= FROZEN.maximumDesiredTranslation + 1e-12, "desired displacement exceeds frozen cap");
  if (p.kind === "stationary") requireValue(p.desiredDelta.every(v => v === 0), "stationary delta must be zero");
  if (p.kind === "turn") {
    requireValue(Number.isFinite(p.endYawRadians), "turn requires end yaw");
    requireValue(p.desiredDelta.every(v => v === 0), "turn translation must be separate");
  }
}
export function makeCallBudget() {
  let count = 0;
  return Object.freeze({
    take() { requireValue(count < FROZEN.maximumControllerCalls, "controller call budget exhausted"); count += 1; },
    get count() { return count; },
  });
}
function checkMesh(vertices, indices) {
  requireValue(vertices instanceof Float32Array && indices instanceof Uint32Array, "mesh must be explicit Float32/Uint32");
  requireValue(vertices.length > 0 && vertices.length % 3 === 0 && vertices.length <= 6000000, "vertex count invalid");
  requireValue(indices.length > 0 && indices.length % 3 === 0 && indices.length <= 6000000, "triangle count invalid");
  for (const value of vertices) requireValue(Number.isFinite(value), "nonfinite mesh coordinate");
  for (const index of indices) requireValue(index < vertices.length / 3, "mesh index outside vertex buffer");
}
function verifyImportedMesh(collider, vertices, indices, arm) {
  const v = collider.vertices(), f = collider.indices();
  requireValue(v instanceof Float32Array && f instanceof Uint32Array, "missing imported trimesh buffers");
  requireValue(f.length === indices.length, "triangle deletion/insertion forbidden");
  const originalToEngine = new Uint32Array(vertices.length / 3).fill(0xffffffff);
  for (let i = 0; i < f.length; ++i) {
    const original = indices[i], imported = f[i];
    requireValue(imported < v.length / 3, "imported index invalid");
    for (let axis = 0; axis < 3; ++axis) {
      // Numeric exactness includes +/- zero as equal geometry; no epsilon welding.
      requireValue(vertices[3 * original + axis] === v[3 * imported + axis], "triangle ordinal/XYZ/winding changed");
    }
    const previous = originalToEngine[original];
    requireValue(previous === 0xffffffff || previous === imported, "one original vertex mapped inconsistently");
    originalToEngine[original] = imported;
  }
  if (arm === "raw_trimesh") {
    requireValue(v.length === vertices.length && equal(Array.from(f), Array.from(indices)), "raw mesh unexpectedly reindexed");
    requireValue(equal(Array.from(v), Array.from(vertices)), "raw mesh coordinates changed");
  }
  return {vertexCount: v.length / 3, triangleCount: f.length / 3,
    originalTriangleOrdinalPreserved: true, originalToEngineVertex: originalToEngine};
}
function serializeCollision(c) {
  requireValue(c !== null, "collision event unexpectedly missing");
  const row = {colliderHandle: c.collider?.handle ?? null, toi: c.toi,
    translationApplied: xyz(c.translationDeltaApplied), translationRemaining: xyz(c.translationDeltaRemaining),
    witness1: xyz(c.witness1), witness2: xyz(c.witness2), normal1: xyz(c.normal1), normal2: xyz(c.normal2),
    originalTriangleID: null, originalTriangleIDReason: "not exposed by upstream CharacterCollision"};
  requireValue(Number.isFinite(row.toi) && [row.translationApplied, row.translationRemaining,
    row.witness1, row.witness2, row.normal1, row.normal2].every(a => a.every(Number.isFinite)), "nonfinite collision result");
  return row;
}
/**
 * Run only after separate root execution admission. R is already initialized.
 * Each probe resets to its ORIGINAL input pose. No returned motion is applied.
 * Unsupported turns never call the controller. No arrival/clearance verdict exists.
 * onResult allows a guarded caller to retain partial receipts if a later query fails.
 */
export function runFrozenProbes(R, {vertices, indices, probes, arm, envelope, budget, onResult = () => {}}) {
  requireValue(R.version() === FROZEN.packageVersion, "unexpected JS/WASM wrapper version");
  requireValue(R.TriMeshFlags.FIX_INTERNAL_EDGES_TWO_SIDED === 656, "unexpected mesh-flag API");
  requireValue(ARMS.includes(arm) && ENVELOPES.includes(envelope), "unknown comparator arm");
  requireValue(budget && typeof budget.take === "function", "shared global call budget required");
  requireValue(Array.isArray(probes) && probes.length <= 2000, "probe inventory exceeds cap");
  checkMesh(vertices, indices);
  const ids = new Set();
  for (const p of probes) { checkProbe(p); requireValue(!ids.has(p.id), "duplicate probe id"); ids.add(p.id); }
  // Preserve caller arrays; upstream may consume/copy its own view.
  const inputVertices = vertices.slice(), inputIndices = indices.slice();
  const flags = arm === "raw_trimesh" ? 0 : R.TriMeshFlags.FIX_INTERNAL_EDGES_TWO_SIDED;
  const world = new R.World({x: 0, y: 0, z: 0});
  try {
    world.timestep = FROZEN.timestep;
    const mesh = world.createCollider(R.ColliderDesc.trimesh(inputVertices.slice(), inputIndices.slice(), flags));
    const mapping = verifyImportedMesh(mesh, inputVertices, inputIndices, arm);
    const frozenMeshPose = poseOf(mesh);
    const h = envelope === "body" ? [0.15, 0.80, 0.225] : [0.30, 0.80, 0.375];
    // Parentless collider: no dynamic rigid body, gravity or velocity integration.
    const character = world.createCollider(R.ColliderDesc.cuboid(...h));
    requireValue(equal(xyz(character.halfExtents()), h.map(Math.fround)), "cuboid half-extents changed");
    const controller = world.createCharacterController(FROZEN.controllerOffsetMetres);
    controller.setUp({x: 0, y: 1, z: 0});
    controller.setSlideEnabled(true);
    controller.setMaxSlopeClimbAngle(FROZEN.maxSlopeRadians);
    controller.setMinSlopeSlideAngle(FROZEN.minSlopeSlideRadians);
    controller.setNormalNudgeFactor(FROZEN.normalNudgeFactor);
    controller.disableAutostep(); controller.disableSnapToGround();
    controller.setApplyImpulsesToDynamicBodies(false);
    const results = [];
    for (const p of probes) {
      const base = {id: p.id, kind: p.kind, arm, envelope, inputArm: p.inputArm,
        originalFoot: [...p.foot], originalYawRadians: p.yawRadians, originalDesiredDelta: [...p.desiredDelta],
        independentEvidence: p.independentEvidence, support: "unknown", semanticFloor: "unknown",
        physicalAuthority: false, movementApplied: false, arrivalEstablished: false,
        queryBandDifference: "KCC full nominal cuboid includes foot-to-foot+0.002m; existing VTK excludes that lower slice",
        frozenHalfExtents: [...h], engineHalfExtentsFloat32: xyz(character.halfExtents())};
      if (p.kind === "turn") {
        const row = {...base, status: "unsupported_rotation", endYawRadians: p.endYawRadians,
          controllerCalled: false, proposedMovement: null, existingTurnOracleMustBeRetained: true};
        results.push(row); onResult(row); continue;
      }
      const requestedCenter = [p.foot[0], p.foot[1] + 0.80, p.foot[2]];
      character.setTranslation(vector(requestedCenter));
      character.setRotation(queryRotation(p.yawRadians));
      const beforeRefresh = poseOf(character);
      requireValue(beforeRefresh.every(Number.isFinite), "nonfinite Float32 query pose");
      // This release has no active updateSceneQueries. Refresh the broad phase
      // through the documented step API, with only fixed/parentless colliders.
      world.step();
      requireValue(equal(beforeRefresh, poseOf(character)), "query-refresh step changed initial pose");
      requireValue(equal(frozenMeshPose, poseOf(mesh)), "query-refresh step moved source mesh");
      const delta = [...p.desiredDelta];
      if (p.inputArm === "horizontal_projection") delta[1] = 0;
      budget.take();
      controller.computeColliderMovement(character, vector(delta), 0, undefined,
        collider => collider.handle === mesh.handle); // Whole source mesh; no per-face filtering.
      const proposed = xyz(controller.computedMovement());
      requireValue(proposed.every(Number.isFinite), "nonfinite proposed movement");
      requireValue(equal(beforeRefresh, poseOf(character)), "controller unexpectedly moved initial pose");
      requireValue(equal(frozenMeshPose, poseOf(mesh)), "controller unexpectedly moved source mesh");
      const collisions = [];
      const n = controller.numComputedCollisions();
      requireValue(Number.isInteger(n) && n >= 0 && n <= 20, "unexpected collision inventory");
      for (let i = 0; i < n; ++i) {
        const c = serializeCollision(controller.computedCollision(i));
        requireValue(c.colliderHandle === mesh.handle, "unexpected filtered collider");
        collisions.push(c);
      }
      const row = {...base, status: "proposal_only", controllerCalled: true,
        requestedCenter, queryPoseFloat32: beforeRefresh, numericalPoseConversionOnly: true,
        requestedDelta: delta, requestedDeltaFloat32: delta.map(Math.fround),
        proposedMovement: proposed, proposalWasNotApplied: true,
        zeroInputDepenetrationProposal: delta.every(v => v === 0) ? proposed : null,
        computedGrounded: controller.computedGrounded(), computedGroundedIsNotSupportEvidence: true,
        collisions, independentHazardsMustNotBeSuppressed: true};
      results.push(row); onResult(row);
    }
    requireValue(equal(Array.from(vertices), Array.from(inputVertices)) &&
      equal(Array.from(indices), Array.from(inputIndices)), "caller source arrays changed");
    verifyImportedMesh(mesh, inputVertices, inputIndices, arm);
    return {status: "proposals_recorded_not_movement", config: FROZEN, arm, envelope, results,
      importedMapping: mapping, controllerCallsSoFar: budget.count, physicalAuthority: false};
  } finally { world.free(); }
}

