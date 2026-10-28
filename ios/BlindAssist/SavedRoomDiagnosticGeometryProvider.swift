import Foundation
import Combine
import CryptoKit
import RoomPlan
import BlindCore
import BlindMemory

/// Read-only local source ownership. No ARSession, images, registration fitting or
/// physical-output capability is created by preparing or reading this request.
struct SavedRoomDiagnosticGeometrySource: Sendable {
    let frame: SavedWorldFrame
    let url: URL
    let memory: MemoryStore
    let memoryOwner: UUID
    let deletionGeneration: UUID
}

enum SavedRoomDiagnosticGeometryDecoder {
    static let maximumSourceBytes = 8 * 1024 * 1024
    enum Failure: Error, Equatable, Sendable { case unavailable, sourceMismatch, unsupported, invalidGeometry }
    static func load(_ source: SavedRoomDiagnosticGeometrySource) -> Result<SavedRoomDiagnosticGeometry, Failure> {
        do {
            guard source.memory.writeOwner == source.memoryOwner,
                  try !source.memory.isDeleted(room: source.frame.placeID) else { return .failure(.unavailable) }
            let data = try SpatialMapFileStorage.readBounded(source.url, maximumBytes: maximumSourceBytes)
            let geometry = try decode(data, frame: source.frame)
            guard source.memory.writeOwner == source.memoryOwner,
                  try !source.memory.isDeleted(room: source.frame.placeID) else { return .failure(.unavailable) }
            return .success(geometry)
        } catch let failure as Failure { return .failure(failure) }
        catch let failure as SpatialMapIOError where failure == .oversized { return .failure(.unsupported) }
        catch { return .failure(.unavailable) }
    }
    static func decode(_ data: Data, frame: SavedWorldFrame) throws -> SavedRoomDiagnosticGeometry {
        guard !data.isEmpty, data.count <= maximumSourceBytes else { throw Failure.unsupported }
        guard frame.valid, SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == frame.roomCaptureSHA256
        else { throw Failure.sourceMismatch }
        let room: CapturedRoom
        do { room = try JSONDecoder().decode(CapturedRoom.self, from: data) }
        catch { throw Failure.invalidGeometry }
        return try extract(room, frame: frame)
    }
    static func extract(_ room: CapturedRoom, frame: SavedWorldFrame) throws -> SavedRoomDiagnosticGeometry {
        typealias Geometry = SavedRoomDiagnosticGeometry
        let counts = Geometry.Counts(floors: room.floors.count, walls: room.walls.count,
            doors: room.doors.count, windows: room.windows.count, openings: room.openings.count, furniture: room.objects.count)
        guard counts.withinBounds else { throw Failure.unsupported }
        let groups: [(Geometry.Kind, [CapturedRoom.Surface])] = [(.floor, room.floors), (.wall, room.walls),
            (.door, room.doors), (.window, room.windows), (.opening, room.openings)]
        // Validate the WHOLE document before allocating transformed features. No
        // prefix, matcher-size cap, omitted wall, synthetic thickness or fallback.
        var cornerCount = 0
        for (_, surfaces) in groups {
            for surface in surfaces {
                guard surface.polygonCorners.count <= Geometry.maximumCornersPerFeature else { throw Failure.unsupported }
                cornerCount += surface.polygonCorners.count
                guard cornerCount <= Geometry.maximumTotalCorners else { throw Failure.unsupported }
            }
        }
        var features: [Geometry.Feature] = []
        features.reserveCapacity(counts.total ?? 0)
        for (kind, surfaces) in groups {
            features += surfaces.map { surface in
                .init(id: surface.identifier, kind: kind, category: kind.rawValue,
                    transform: NativeARObservationAdapter.transform(surface.transform),
                    dimensions: Point3(Double(surface.dimensions.x), Double(surface.dimensions.y), Double(surface.dimensions.z)),
                    polygonCorners: surface.polygonCorners.map { Point3(Double($0.x), Double($0.y), Double($0.z)) })
            }
        }
        features += room.objects.map { object in
            .init(id: object.identifier, kind: .furniture, category: String(describing: object.category),
                transform: NativeARObservationAdapter.transform(object.transform),
                dimensions: Point3(Double(object.dimensions.x), Double(object.dimensions.y), Double(object.dimensions.z)))
        }
        do { return try Geometry(frame: frame, capturedRoomID: room.identifier, story: room.story, sourceCounts: counts, features: features) }
        catch Geometry.Failure.unsupportedSize { throw Failure.unsupported }
        catch { throw Failure.invalidGeometry }
    }
}

/// One native utility read/decode and one latest pending selection. Cancellation
/// retires publication, not the already-running worker; rapid choices cannot fan
/// out unbounded decoding. Published geometry is immutable historical evidence.
@MainActor final class SavedRoomDiagnosticGeometryProvider: ObservableObject {
    enum Status: Equatable { case idle, loading, ready, unsupported, unavailable }
    @Published private(set) var geometry: SavedRoomDiagnosticGeometry?
    @Published private(set) var status: Status = .idle
    private weak var places: PlaceStore?
    private let loader: @Sendable (SavedRoomDiagnosticGeometrySource) -> Result<SavedRoomDiagnosticGeometry, SavedRoomDiagnosticGeometryDecoder.Failure>
    private var selected: SavedWorldFrame?
    private var selectedID = UUID()
    private var activeWorker: UUID?
    private struct Work: Sendable {
        let selectionID: UUID
        let source: SavedRoomDiagnosticGeometrySource
    }
    private var pending: Work?
    private var publishedSource: SavedRoomDiagnosticGeometrySource?
    var hasPendingWork: Bool { activeWorker != nil || pending != nil }
    init(places: PlaceStore,
         loader: @escaping @Sendable (SavedRoomDiagnosticGeometrySource) -> Result<SavedRoomDiagnosticGeometry, SavedRoomDiagnosticGeometryDecoder.Failure> = SavedRoomDiagnosticGeometryDecoder.load) {
        self.places = places; self.loader = loader
    }
    /// Idempotent for the same immutable descriptor, but every refresh rechecks
    /// app-owned deletion, source replacement and memory-store ownership.
    func select(_ frame: SavedWorldFrame?) {
        guard let frame else { cancel(); return }
        if selected == frame {
            if let source = publishedSource, places?.ownsDiagnosticGeometrySource(source) != true {
                selectedID = UUID(); pending = nil; publishedSource = nil; geometry = nil; status = .unavailable
            }
            return
        }
        selected = frame; selectedID = UUID(); geometry = nil; publishedSource = nil
        guard let source = places?.diagnosticGeometrySource(for: frame) else { pending = nil; status = .unavailable; return }
        status = .loading; pending = Work(selectionID: selectedID, source: source); drain()
    }
    /// Explicit re-read/hash check for external file changes. Cached geometry is
    /// never described as a fresh view of current furniture or current clearance.
    func reload() {
        let frame = selected; selected = nil; select(frame)
    }
    func cancel() {
        selected = nil; selectedID = UUID(); pending = nil; publishedSource = nil; geometry = nil; status = .idle
    }
    private func drain() {
        guard activeWorker == nil, let work = pending else { return }
        pending = nil
        let worker = UUID(), loader = self.loader
        activeWorker = worker
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) { loader(work.source) }.value
            guard let self, self.activeWorker == worker else { return }
            self.activeWorker = nil
            if self.selectedID == work.selectionID, self.selected == work.source.frame {
                guard self.places?.ownsDiagnosticGeometrySource(work.source) == true else {
                    self.geometry = nil; self.publishedSource = nil; self.status = .unavailable; self.drain(); return
                }
                switch result {
                case .success(let geometry):
                    guard geometry.frame == work.source.frame, (try? geometry.validate()) != nil else {
                        self.geometry = nil; self.status = .unavailable; self.drain(); return
                    }
                    self.publishedSource = work.source; self.geometry = geometry; self.status = .ready
                case .failure(let failure):
                    self.geometry = nil; self.publishedSource = nil
                    self.status = failure == .unsupported ? .unsupported : .unavailable
                }
            }
            self.drain()
        }
    }
}
