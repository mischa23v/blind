import RoomPlan
import BlindCore
import simd

enum RoomLayoutAdapter {
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
