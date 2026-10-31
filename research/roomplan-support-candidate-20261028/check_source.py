import hashlib,json,pathlib,sys
folder=pathlib.Path(__file__).resolve().parent
root=folder.parents[1]
old=(folder/'SavedRoomRouteMeshAdapter.before.swift').read_text()
new=(root/'ios/BlindAssist/SavedRoomRouteMeshAdapter.swift').read_text()
tests=(root/'ios/BlindAssistTests/SavedRoomRouteMeshAppleFixtureTests.swift').read_text()
checks={
 'upstream_tessellator':'SCNShape(path: path, extrusionDepth: 0)' in new,
 'no_bevel':'shape.chamferRadius = 0' in new,
 'raw_vertices_retained':'rawExportVertices: vertices' in new,
 'raw_triangles_retained':'rawExportTriangles: triangles' in new,
 'raw_identities_retained':'rawExportTriangleFeatureIDs: triangleIDs' in new,
 'nonfloor_only_copy':'guard feature.kind != .floor else { continue }' in new,
 'support_source_polygon':'let points = floor.polygonCorners' in new,
 'no_changed_roundoff':old[old.index('    static func roundoffAllowance'):old.index('    /// RoomPlan')]==new[new.index('    static func roundoffAllowance'):new.index('    /// RoomPlan')],
 'no_changed_source_bound_diagnostic':old[old.index('    struct SourceBoundsAssessment:'):]==new[new.index('    struct SourceBoundsAssessment:'):],
 'furniture_bounds_retained':'if feature.kind == .furniture { try verifySourceBounds(value, feature: feature) }' in new,
 'frame_validation':'try verifyFeatureFrame(MDLTransform.globalTransform(with: node, atTime: asset.startTime), feature: feature)' in new,
 'no_model_provider':'modelProvider: nil, exportOptions: .mesh' in new,
 'area_validation':'abs(area - sourceArea) <= roundoffAllowance(sourceArea)' in new,
 'no_flip':'guard normal.y > 0' in new,
 'source_plane_offset_retained':'let planeZ = points[0][2]' in new,
 'unsupported_polygon_rejected':'abs($0[2] - planeZ) <= epsilon' in new,
 'no_physical_authority':'var physicalAuthority: Bool { false }' in new,
 'no_current_door_claim':'var currentDoorStateKnown: Bool { false }' in new,
 'no_coverage_claim':'var actualWorldCoverageKnown: Bool { false }' in new,
 'source_digest_retained':'SHA256.hash(data: data)' in new,
 'no_session_activation':'ARSession(' not in new,
 'no_hardcoded_extrusion_exception':'0.16' not in new,
 'budget_output':'flat.vertices.count / 3 <= maximumVertices - result.vertices.count / 3' in new,
 'bounded_platform_buffer':'source.data.count <= maximumExportBytes' in new,
 'test_windings':'testZeroExtrusionHasOnlyOriginalPlaneSupportForBothSourceWindings' in tests,
 'test_malformed':'testMalformedSourcePolygonsAreRejectedInsteadOfRepaired' in tests,
 'test_rim':'testRawSlabSidesUndersideAndRimCannotBecomeRoutingSupport' in tests,
 'test_transform':'testFeatureFrameRejectsScaleShiftAndDoubleTransform' in tests,
 'oriented_boundary_validation':'try verifyHistoricalFloorBoundary(source: points' in new,
 'test_concavity_mutations':'testOrientedBoundaryRejectsConcavityBridgeMissingPatchAndDuplicateTriangles' in tests,
 'leaf_frame_validated':'try verifyFeatureFrame(world, feature: feature)' in new,
 'test_plane':'testSourcePlaneOffsetAndMetricTransformAppliedOnce' in tests,
}
result={'schema':'roomplan-support-source-checks-v1','scope':'source contracts only; no Swift compilation, SceneKit execution or native fixture success','checks':checks,'passed':sum(checks.values()),'failed':sum(not x for x in checks.values()),'swiftTestsAuthored':6,'swiftTestsExecuted':0}
(folder/'SOURCE_CHECKS.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2));sys.exit(0 if all(checks.values()) else 1)
