import Foundation

/// A per-floor 2.5D collision layer in the same metre coordinates as IndoorMap.
/// Each cell records support height and free vertical space, not just an image pixel.
public struct SurfaceCell: Codable, Equatable, Sendable {
    public var floor: Double?
    public var clearance: Double?
    public var blocked: Bool
    public init(floor: Double? = nil, clearance: Double? = nil, blocked: Bool = false) {
        self.floor = floor; self.clearance = clearance; self.blocked = blocked
    }
}

public struct BodyEnvelope: Codable, Equatable, Sendable {
    public var radius: Double
    public var height: Double
    public var margin: Double
    public init(radius: Double = 0.3, height: Double = 1.8, margin: Double = 0.15) {
        self.radius = radius; self.height = height; self.margin = margin
    }
    public var valid: Bool {
        radius.isFinite && height.isFinite && margin.isFinite &&
        radius >= 0.1 && radius <= 1 && height >= 0.5 && height <= 2.5 && margin >= 0.05 && margin <= 1
    }
}

public struct NavigationSurface: Codable, Sendable {
    public var level: String
    public var origin: Point3
    public var resolution: Double
    public var width: Int
    public var depth: Int
    /// Row-major cells: z * width + x. nil measurements are unknown and impassable.
    public var cells: [SurfaceCell]
    public init(level: String, origin: Point3, resolution: Double, width: Int, depth: Int, cells: [SurfaceCell]) {
        self.level = level; self.origin = origin; self.resolution = resolution
        self.width = width; self.depth = depth; self.cells = cells
    }
    public func validate() throws {
        guard !level.isEmpty, origin.isFinite, resolution.isFinite, resolution >= 0.05, resolution <= 1,
              width > 0, depth > 0, width <= 2000, depth <= 2000, width * depth <= 250_000,
              cells.count == width * depth,
              cells.allSatisfy({ ($0.floor == nil || $0.floor!.isFinite) &&
                  ($0.clearance == nil || ($0.clearance!.isFinite && $0.clearance! >= 0)) }) else { throw MapError.invalid }
    }
    /// Sweeps the body cylinder along a straight authored route leg. Sampling adds half
    /// a sample interval to the radius, conservatively covering the space between samples.
    /// Unknown cells, bounds, head obstacles, rises and drops all reject the leg.
    public func permitsLeg(from a: Point3, to b: Point3, body: BodyEnvelope = BodyEnvelope()) -> Bool {
        guard (try? validate()) != nil else { return false }
        return permitsValidatedLeg(from: a, to: b, body: body)
    }
    internal func permitsValidatedLeg(from a: Point3, to b: Point3, body: BodyEnvelope) -> Bool {
        guard body.valid, a.isFinite, b.isFinite,
              abs(a.y - b.y) <= 0.09 else { return false }
        let length = hypot(b.x - a.x, b.z - a.z)
        guard length.isFinite, length <= 100 else { return false }
        let steps = max(1, Int(ceil(length / (resolution * 0.5))))
        let radius = body.radius + body.margin + length / Double(steps) * 0.5
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let x = a.x + (b.x - a.x) * t - origin.x
            let z = a.z + (b.z - a.z) * t - origin.z
            guard x - radius >= 0, z - radius >= 0,
                  x + radius < Double(width) * resolution, z + radius < Double(depth) * resolution else { return false }
            let minX = Int(((x - radius) / resolution).rounded(.down))
            let maxX = Int(((x + radius) / resolution).rounded(.down))
            let minZ = Int(((z - radius) / resolution).rounded(.down))
            let maxZ = Int(((z + radius) / resolution).rounded(.down))
            for cz in minZ...maxZ {
                for cx in minX...maxX {
                    let nearestX = max(Double(cx) * resolution, min(x, Double(cx + 1) * resolution))
                    let nearestZ = max(Double(cz) * resolution, min(z, Double(cz + 1) * resolution))
                    guard hypot(x - nearestX, z - nearestZ) <= radius else { continue }
                    let cell = cells[cz * width + cx]
                    guard !cell.blocked, let floor = cell.floor, let clearance = cell.clearance,
                          abs(floor - a.y) <= 0.09, clearance >= body.height + body.margin else { return false }
                }
            }
        }
        return true
    }
}
