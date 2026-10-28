import Foundation
@testable import BlindCore

/// Real recorded-source anchor coordinates, NOT a reconstructed floor, route graph,
/// observed support, ARWorldMap, true building/floor identity or human clearance.
/// Catalog hierarchy below is an authored dataset namespace, not measured geography.
enum KoivuSourceAnchorBenchFixture {
    static let sourcePath = "research/journey-benchmark-readiness-84/TWENTY_SOURCE_PAIRS.json"
    static let sourceSHA256 = "5a02f4ed25a80b6c2929bdcba04f4a5880d8af003e04817102fcf8f8baacc5ee"
    static let points: [Point3] = [
        .init(-2.281401302639457, 0.0, 1.0373834286611066),
        .init(-0.9024904099661475, 0.0, 3.796214579425151),
        .init(0.9934880945505575, 0.0, 1.4958629589009271),
        .init(0.2209646416855992, 0.0, -0.6243470786782905),
        .init(-1.5490109087842536, 0.0, -3.84606766234802),
    ]
    static func installation() throws -> SpatialMapInstallation {
        let binding = SpatialMapBinding(mapID: "koivu-source-anchor-metadata", frameID: "koivu-original-recorded-frame", revision: "source-pairs-v1")
        let hierarchy: [SpatialPlaceNode] = [
            .init(id: "dataset-world", kind: .world),
            .init(id: "dataset-place", kind: .place, parentID: "dataset-world"),
            .init(id: "dataset-building", kind: .building, parentID: "dataset-place"),
            .init(id: "dataset-floor-unverified", kind: .floor, parentID: "dataset-building"),
            .init(id: "koivu-recording", kind: .room, parentID: "dataset-floor-unverified")]
        let revision = SpatialMapRevision(binding: binding, nodeID: "dataset-floor-unverified", metersPerUnit: 1,
            floorLevels: ["recorded-level": "dataset-floor-unverified"])
        let registry = SpatialRegistrySnapshot(nodes: hierarchy, maps: [revision], activeBindings: [binding])
        var map = IndoorMap(name: "Koivu recorded anchors ONLY — no support or routes",
            nodes: points.enumerated().map { .init(id: "anchor-\($0.offset)", name: "Recorded source anchor \($0.offset)",
                level: "recorded-level", position: $0.element) }, edges: [], surfaces: nil)
        map.packageID = binding.mapID; map.packageRevision = binding.revision
        let bytes = try SpatialMapInstallation.canonicalMapBytes(map)
        return try .init(envelope: .init(snapshot: registry, binding: binding, mapBytes: bytes,
            artifactHistory: [.init(binding: binding, sha256: try SpatialIntegrationFixture.sha256(bytes))]),
            sha256: SpatialIntegrationFixture.sha256)
    }
}
