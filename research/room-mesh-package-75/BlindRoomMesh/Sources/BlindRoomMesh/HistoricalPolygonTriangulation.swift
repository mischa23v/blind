import CEarcut

/// Released Mapbox earcut CPU adapter. Returns indices into the exact source
/// points, not a repaired polygon or live supporting-floor evidence. Callers
/// retain responsibility for source and resulting boundary/area validation.
public enum HistoricalPolygonTriangulation {
    public enum Failure: Error { case invalidInput, triangulationFailed }
    public static func indices(xy: [Double]) throws -> [Int32] {
        guard xy.count % 2 == 0, (3...1024).contains(xy.count / 2),
              xy.allSatisfy(\.isFinite) else { throw Failure.invalidInput }
        let vertexCount = xy.count / 2, capacity = 3 * (xy.count / 2 - 2)
        var output = [Int32](repeating: 0, count: capacity)
        let count = Int(xy.withUnsafeBufferPointer { points in
            output.withUnsafeMutableBufferPointer { indices in
                bn_earcut_simple_ring(points.baseAddress, Int32(vertexCount), indices.baseAddress, Int32(capacity))
            }
        })
        guard count > 0, count <= capacity, count % 3 == 0 else { throw Failure.triangulationFailed }
        let result = Array(output.prefix(Int(count)))
        guard result.allSatisfy({ $0 >= 0 && Int($0) < vertexCount }) else { throw Failure.triangulationFailed }
        return result
    }
}
