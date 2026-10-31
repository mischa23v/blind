/**
 * V2 prepared analytic controls, NOT executed. Authored poses may use declared
 * per-profile standoffs; real-room probes must retain identical supplied poses.
 * Existing VTK hazards remain a separate mandatory gate.
 */
import {ARMS, ENVELOPES, FROZEN, makeCallBudget, runFrozenProbes} from "./comparator.mjs";
function assert(ok, message) { if (!ok) throw new Error(message); }
const H = envelope => envelope === "body" ? 0.15 : 0.30;
const EPS = 0.001; // Frozen Float32 geometric assertion tolerance, not a collision margin.
function mesh(vertices, faces) {
  return {vertices: new Float32Array(vertices.flat()), indices: new Uint32Array(faces.flat())};
}
function mergeMeshes(...parts) {
  const vertices = [], faces = [];
  for (const part of parts) {
    const offset = vertices.length / 3;
    vertices.push(...part.vertices); faces.push(...Array.from(part.indices, n => n + offset));
  }
  return {vertices: new Float32Array(vertices), indices: new Uint32Array(faces)};
}
function floor(x0 = -2, x1 = 2, y = 0) {
  return mesh([[x0,y,-2],[x1,y,-2],[x1,y,2],[x0,y,2]], [[0,2,1],[0,3,2]]);
}
function wall(x, y0 = -0.2, y1 = 2, reverse = false) {
  const f = [[0,1,2],[0,2,3]];
  return mesh([[x,y0,-2],[x,y1,-2],[x,y1,2],[x,y0,2]], reverse ? f.map(a => [...a].reverse()) : f);
}
function probe(id, foot = [0,0.002,0], desired = [0.025,0,0], extra = {}) {
  return {id, kind: desired.every(v => v === 0) ? "stationary" : "translation",
    foot, yawRadians: 0, desiredDelta: desired, inputArm: "exact_xyz",
    independentEvidence: {origin: "authored analytic fixture", nativeOracleExecuted: false,
      status: "independent_oracle_required", hazardsMayNotBeSuppressed: true}, ...extra};
}
function assertFlat(row) {
  const p = row.proposedMovement, d = row.requestedDelta;
  assert(p.every((v,i) => Math.abs(v-d[i]) <= EPS), "flat/open motion differs from requested translation");
}
function assertAdvance(row, expected, direction = [1,0,0]) {
  const p = row.proposedMovement, advance = p.reduce((s,v,i) => s+v*direction[i],0);
  assert(row.collisions.length > 0, "expected contact not reported");
  assert(Math.abs(advance-expected) <= EPS, "contact advance outside analytic gap-minus-offset interval");
  assert(Math.abs(p[1]) <= EPS, "wall unexpectedly climbed");
}
export function preparedFixtures(envelope) {
  assert(ENVELOPES.includes(envelope), "profile must be explicit");
  const half = H(envelope), front = 0.17-half-0.02, back = 0.17+half+0.02;
  const atWall = id => probe(id,[front,0.002,0]);
  const seam = mesh([[-2,0,-2],[2,0,2],[2,0,-2],[-2,0,-2],[-2,0,2],[2,0,2],
    [2.00001,0,2],[2.5,0,2],[2.5,0,2.5]], [[0,1,2],[3,4,5],[6,7,8]]);
  const c = Math.SQRT1_2, wallDistance = 0.5, centerDistance = wallDistance-half-0.02;
  const diagonal = mesh([[wallDistance*c-2*c,-0.2,wallDistance*c+2*c],
    [wallDistance*c-2*c,2,wallDistance*c+2*c],[wallDistance*c+2*c,2,wallDistance*c-2*c],
    [wallDistance*c+2*c,-0.2,wallDistance*c-2*c]],[[0,1,2],[0,2,3]]);
  const fixtures = [
    {id:"flat",geometry:floor(),probes:[probe("flat_forward"),probe("flat_zero",[0,0.002,0],[0,0,0])],check:assertFlat},
    {id:"exact_uv_and_near_duplicate",geometry:seam,probes:[probe("seam_forward")],check:assertFlat,
      checkImport(result) { assert(result.importedMapping.vertexCount === (result.arm==="raw_trimesh"?9:7),
        "exact duplicate merge or distinct near-vertex retention failed"); }},
    {id:"margin_only_same_pose",geometry:wall(0.32),probes:[probe("margin_only_same_pose")],
      check(row) { if(envelope==="body") { assertFlat(row);assert(row.collisions.length===0,"nominal body hit margin-only wall"); }
        else assertAdvance(row,0.018); }},
    {id:"wall_front",geometry:wall(0.17),probes:[atWall("wall_front")],check:row=>assertAdvance(row,0.018)},
    {id:"wall_back",geometry:wall(0.17),probes:[probe("wall_back",[back,0.002,0],[-0.025,0,0])],
      check:row=>assertAdvance(row,0.018,[-1,0,0])},
    {id:"wall_reversed_winding",geometry:wall(0.17,-0.2,2,true),probes:[atWall("wall_reversed")],
      check:row=>assertAdvance(row,0.018)},
    {id:"low_riser_1cm",geometry:mergeMeshes(floor(),wall(0.17,0,0.01)),probes:[atWall("low_riser_1cm")],
      requiredIndependentHazard:"low_obstacle",check:row=>assertAdvance(row,0.018)},
    {id:"step_10cm",geometry:mergeMeshes(floor(-2,0.17,0),floor(0.17,2,0.10),wall(0.17,0,0.10)),
      probes:[atWall("step_10cm")],requiredIndependentHazard:"step",check:row=>assertAdvance(row,0.018)},
    {id:"down_step_1cm",geometry:mergeMeshes(floor(-2,0.17,0),floor(0.17,2,-0.01),wall(0.17,-0.01,0)),
      probes:[atWall("down_step_1cm")],requiredIndependentHazard:"down_step",check:assertFlat},
    {id:"support_gap",geometry:mergeMeshes(floor(-2,-0.45),floor(0.45,2)),probes:[probe("support_gap")],
      requiredIndependentHazard:"unsupported_or_unknown_ground",check(row) { assertFlat(row);
        assert(row.computedGrounded===false,"wide gap unexpectedly reported grounded"); }},
    {id:"zero_input_overlap",geometry:wall(0),probes:[probe("zero_input_overlap",[0,0,0],[0,0,0])],
      check(row) { assert(Math.abs(Math.abs(row.proposedMovement[0])-(half+0.002))<=EPS,
        "initial wall overlap did not produce expected proposed-only depenetration");
        assert(Math.abs(row.proposedMovement[1])<=EPS && Math.abs(row.proposedMovement[2])<=EPS,"unexpected transverse depenetration"); }},
    {id:"low_ceiling",geometry:floor(-2,2,1.58),probes:[probe("low_ceiling_zero",[0,0,0],[0,0,0])],
      requiredIndependentHazard:"head_contact",check(row) { assert(Math.abs(row.proposedMovement[1]+0.022)<=EPS,
        "low ceiling did not produce expected downward depenetration proposal"); }},
    {id:"turn_unsupported",geometry:floor(),probes:[probe("turn_unsupported",[0,0.002,0],[0,0,0],
      {kind:"turn",endYawRadians:Math.PI/2})]},
    {id:"yaw_45_diagonal_wall",geometry:diagonal,probes:[probe("yaw_45_diagonal_wall",
      [centerDistance*c,0.002,centerDistance*c],[0.025*c,0,0.025*c],{yawRadians:Math.PI/4})],
      check(row) { assertAdvance(row,0.018,[c,0,c]);
        assert(Math.abs(row.queryPoseFloat32[4]+Math.sin(Math.PI/8))<1e-6 &&
          Math.abs(row.queryPoseFloat32[6]-Math.cos(Math.PI/8))<1e-6,"positive yaw quaternion sign/axis mismatch"); }},
  ];
  for(const degrees of [14.9,15.0,15.1,16.89]) {
    const radians=degrees*Math.PI/180,slope=Math.tan(radians);
    const geometry=mesh([[-2,-2*slope,-2],[2,2*slope,-2],[2,2*slope,2],[-2,-2*slope,2]],[[0,2,1],[0,3,2]]);
    const foot=[0,half*slope+FROZEN.controllerOffsetMetres/Math.cos(radians),0];
    fixtures.push({id:"slope_"+degrees,geometry,analyticNormalGapMetres:FROZEN.controllerOffsetMetres,
      probes:[probe("slope_"+degrees+"_horizontal",foot),probe("slope_"+degrees+"_upward_intent",foot,[0.020,0.005,0]),
        probe("slope_"+degrees+"_projected",foot,[0.020,0.005,0],{inputArm:"horizontal_projection"})],
      check(row) {
        assert(row.collisions.length>0,"slope control never contacted slope");
        const [x,y]=row.proposedMovement;
        if(row.id.endsWith("_upward_intent")) {
          assert(x>0.012 && y>0.003,"explicit upward-intent behavior not exercised");
        } else if(degrees<15) {
          assert(x>0.012 && y>0.003,"below-limit slope did not produce a climbing proposal");
        } else if(degrees>15) {
          assert(x<=0.005 && y<=0.002,"above-limit slope admitted substantial climb without upward intent");
        } else {
          // Exact equality is observational: Float32 normal/angle rounding can flip the branch.
          assert(x<=0.005 || (x>0.012 && y>0.003),"15-degree boundary result outside frozen qualitative bins");
        }
      }});
  }
  return fixtures;
}
/** Explicit admitted execution only. onProbe preserves raw rows before any assertion. */
export function runPreparedControls(R,onResult=()=>{},budget=makeCallBudget(),onProbe=()=>{}) {
  const records=[];
  for(const envelope of ENVELOPES) for(const fixture of preparedFixtures(envelope)) for(const arm of ARMS) {
    const before=budget.count;
    const result=runFrozenProbes(R,{...fixture.geometry,probes:fixture.probes,arm,envelope,budget,
      onResult:row=>onProbe({fixtureID:fixture.id,arm,envelope,row})});
    const record={fixtureID:fixture.id,arm,envelope,result,analyticProfileStandoff:fixture.id.startsWith("slope_") || ["wall_front","wall_back","wall_reversed_winding","low_riser_1cm","step_10cm","down_step_1cm","yaw_45_diagonal_wall"].includes(fixture.id),
      requiredIndependentHazard:fixture.requiredIndependentHazard??null,
      independentVTKOracleExecutedByThisModule:false,physicalAuthority:false,
      recordPhase:"raw_before_assertions"};
    onResult(record); // Retain the current failing fixture, not just earlier successes.
    for(const row of result.results) {
      assert(row.movementApplied===false && row.physicalAuthority===false,"movement authority leaked");
      assert(row.support==="unknown" && row.semanticFloor==="unknown","grounded became support/floor truth");
      if(row.kind==="turn") {
        assert(row.status==="unsupported_rotation" && row.controllerCalled===false && row.proposedMovement===null,"turn treated as supported");
      } else {
        assert(row.proposalWasNotApplied===true && row.proposedMovement.every(Number.isFinite),"invalid proposal");
        assert(row.computedGroundedIsNotSupportEvidence===true,"grounded promoted to support");
        if(row.kind==="stationary") assert(Array.isArray(row.zeroInputDepenetrationProposal),"depenetration not separately recorded");
        fixture.check?.(row);
      }
    }
    fixture.checkImport?.(result);
    if(fixture.id==="turn_unsupported") assert(budget.count===before,"unsupported turn called controller");
    records.push(record);
  }
  return {status:"adapter_controls_completed_only",records,wrapperRecordCount:records.length,
    nestedProbeRowCount:records.reduce((s,r)=>s+r.result.results.length,0),callCount:budget.count,
    independentHazardOraclePassed:false,independentHazardOracleStatus:"not_run_by_this_module"};
}
