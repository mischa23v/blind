import Foundation

public struct RoomFeature: Codable, Identifiable, Sendable {
    public var id: String
    public var kind: String
    public var category: String
    public var confidence: String
    public var corners: [Point3]
    public var label: String?
    public var labelArabic: String?
    public init(id: String, kind: String, category: String, confidence: String, corners: [Point3]) {
        self.id = id; self.kind = kind; self.category = category; self.confidence = confidence; self.corners = corners
    }
    public func name(arabic: Bool) -> String {
        if let custom = arabic ? labelArabic : label, !custom.isEmpty { return custom }
        guard arabic else { return category }
        return ["wall": "جدار", "door": "باب", "window": "نافذة", "opening": "فتحة", "storage": "خزانة",
            "bed": "سرير", "table": "طاولة", "chair": "كرسي", "sofa": "أريكة", "sink": "حوض",
            "toilet": "مرحاض", "bathtub": "حوض استحمام", "refrigerator": "ثلاجة", "stove": "موقد",
            "oven": "فرن", "television": "تلفاز", "washerDryer": "غسالة", "dishwasher": "غسالة أطباق",
            "stairs": "درج", "fireplace": "مدفأة"][category] ?? "عنصر مرصود"
    }
}
public struct RoomLayout: Codable, Sendable {
    public var version = 1
    public var name: String
    public var features: [RoomFeature]
    public var confirmedRoomType: String?
    public var revisionID: String?
    public var descriptionEnglish: String?
    public var descriptionArabic: String?
    public init(name: String, features: [RoomFeature]) { self.name = name; self.features = features }
    public func validate() throws {
        guard version == 1, name.count <= 300,
              (descriptionEnglish?.count ?? 0) <= 4000, (descriptionArabic?.count ?? 0) <= 4000,
              !features.isEmpty, features.count <= 2000,
              Set(features.map(\.id)).count == features.count,
              features.allSatisfy({ !$0.id.isEmpty && ["wall", "door", "window", "opening", "furniture"].contains($0.kind) &&
                  $0.corners.count == 4 && $0.corners.allSatisfy { $0.isFinite && abs($0.x) < 10000 && abs($0.z) < 10000 } }) else { throw MapError.invalid }
    }
    /// 2D display/export only. These rectangles do not establish floor support or walkability.
    public func svg() throws -> String {
        try validate()
        func escaped(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        }
        let points = features.flatMap(\.corners), minX = points.map(\.x).min()!, maxX = points.map(\.x).max()!
        let minZ = points.map(\.z).min()!, maxZ = points.map(\.z).max()!
        let scale = min(700 / max(1, maxX - minX), 500 / max(1, maxZ - minZ))
        let polygons = features.map { feature in
            let values = feature.corners.map { "\(($0.x - minX) * scale + 40),\(($0.z - minZ) * scale + 70)" }.joined(separator: " ")
            let color = feature.kind == "wall" ? "#263d4c" : feature.kind == "door" || feature.kind == "opening" ? "#1c8b68" : feature.kind == "window" ? "#287db8" : "#b8842a"
            return "<polygon points=\"\(values)\" fill=\"\(color)\" fill-opacity=\"0.65\" stroke=\"\(color)\"><title>\(escaped(feature.label ?? feature.category))</title></polygon>"
        }.joined(separator: "\n")
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 800 640\" role=\"img\"><title>\(escaped(name)) — measured room overview, not a walking route</title><rect width=\"800\" height=\"640\" fill=\"#f4f7f9\"/><text x=\"30\" y=\"35\" font-size=\"20\">\(escaped(name))</text>\(polygons)<text x=\"30\" y=\"615\" font-size=\"14\">Scan geometry is approximate. Floor support and door connections need verification.</text></svg>"
    }
    public var modelInventory: String {
        let grouped = Dictionary(grouping: features.filter { $0.confidence != "low" && $0.kind == "furniture" }, by: \.category)
        return grouped.keys.sorted().map { "\($0): \(grouped[$0]!.count)" }.joined(separator: ", ")
    }
}
