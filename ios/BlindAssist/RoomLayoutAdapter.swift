import RoomPlan
import BlindCore
import simd

enum RoomLayoutAdapter {
    /// Raw RoomPlan measurements for explicit helper correspondence review.
    /// No category pairing, confidence-to-error conversion, or identity assertion.
    static func registrationFeatures(_ room: CapturedRoom) -> [RoomRegistrationAcquisition.Feature]? {
        func feature(_ id: UUID, _ kind: String, _ transform: simd_float4x4, _ dimensions: SIMD3<Float>, _ polygon: [SIMD3<Float>] = []) -> RoomRegistrationAcquisition.Feature {
            .init(id: id.uuidString, kind: kind,
                  transform: (0..<4).flatMap { column in (0..<4).map { row in Double(transform[column][row]) } },
                  dimensions: Point3(Double(dimensions.x), Double(dimensions.y), Double(dimensions.z)),
                  polygonCorners: polygon.map { Point3(Double($0.x), Double($0.y), Double($0.z)) })
        }
        let groups = [("floor", room.floors), ("wall", room.walls), ("door", room.doors), ("window", room.windows), ("opening", room.openings)]
        let limit = RoomRegistrationAcquisition.maximumFeatures
        guard room.objects.count <= limit, groups.allSatisfy({ $0.1.count <= limit }),
              groups.reduce(room.objects.count, { $0 + $1.1.count }) <= limit,
              groups.allSatisfy({ $0.1.allSatisfy { $0.polygonCorners.count <= 16 } }) else { return nil }
        var result: [RoomRegistrationAcquisition.Feature] = []
        for (kind, surfaces) in groups {
            result += surfaces.map { feature($0.identifier, kind, $0.transform, $0.dimensions, $0.polygonCorners) }
        }
        result += room.objects.map { feature($0.identifier, String(describing: $0.category), $0.transform, $0.dimensions) }
        guard !result.isEmpty, result.count <= RoomRegistrationAcquisition.maximumFeatures,
              result.allSatisfy(\.valid), Set(result.map(\.id)).count == result.count else { return nil }
        return result
    }

    static func layout(_ room: CapturedRoom, name: String) -> RoomLayout {
        func rectangle(_ transform: simd_float4x4, width: Float, depth: Float) -> [Point3] {
            [SIMD4<Float>(-width / 2, 0, -depth / 2, 1), SIMD4<Float>(width / 2, 0, -depth / 2, 1),
             SIMD4<Float>(width / 2, 0, depth / 2, 1), SIMD4<Float>(-width / 2, 0, depth / 2, 1)].map {
                let p = transform * $0; return Point3(Double(p.x), Double(p.y), Double(p.z))
            }
        }
        var features: [RoomFeature] = []
        for (kind, surfaces) in [("wall", room.walls), ("door", room.doors), ("window", room.windows), ("opening", room.openings)] {
            features += surfaces.map { surface in
                RoomFeature(id: surface.identifier.uuidString, kind: kind, category: kind,
                    confidence: String(describing: surface.confidence),
                    corners: rectangle(surface.transform, width: surface.dimensions.x, depth: max(0.06, surface.dimensions.z)))
            }
        }
        features += room.objects.map { object in
            RoomFeature(id: object.identifier.uuidString, kind: "furniture", category: String(describing: object.category),
                confidence: String(describing: object.confidence),
                corners: rectangle(object.transform, width: object.dimensions.x, depth: object.dimensions.z))
        }
        return RoomLayout(name: name, features: features)
    }
}
