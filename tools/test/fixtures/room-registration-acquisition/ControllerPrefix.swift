// Authored Apple platform seams; method bodies below are exact proposal source.
import Foundation
import BlindCore
import BlindMemory
struct simd_float4x4: Codable { static var reads = 0; let columns: [SIMD4<Float>]; subscript(_ i: Int) -> SIMD4<Float> { Self.reads += 1; return columns[i] } }
struct CapturedRoom: Codable {
 struct Feature: Codable { let identifier: UUID; let category: String; let transform: simd_float4x4; let dimensions: SIMD3<Float>; let polygonCorners: [SIMD3<Float>] }
 let identifier: UUID; let story: Int
 var floors: [Feature] = [], walls: [Feature] = [], doors: [Feature] = [], windows: [Feature] = [], openings: [Feature] = [], objects: [Feature] = []
}
struct SavedPlace { let id: UUID; let worldFrame: SavedWorldFrame? }
final class ARSession {}
struct ARFrame {
 enum Tracking { case normal, unavailable }
 struct Camera { let transform: simd_float4x4; let trackingState: Tracking }
 let camera: Camera; let timestamp: Double
}
final class RoomCaptureSession {
 struct Configuration {}
 weak var delegate: ExtractedRegistrationIngress?
 init(arSession: ARSession) {}
 func run(configuration: Configuration) {}
 func stop(pauseARSession: Bool) {}
}
final class ExtractedRegistrationIngress {
 var scanning = false, finishing = false, arabic = false, comparisonLocalized = false
 var liveScanLayout: Int?, comparison: SavedPlace?, capture: RoomCaptureSession?
 var name = "", lastInstruction = "", message = "", registrationStatus = ""
 var lastInstructionTime = -Double.infinity
 var scanID = UUID(), registrationRequestID = UUID()
 var registrationSelectionPlaceID: UUID?
 var worldFrameRecovery = SavedWorldFrameRecovery()
 var registrationSessionID: UUID?, registrationStoreOwner: UUID?
 var memory: MemoryStore?
 var places: [SavedPlace] = []
 var registrationSaving = false, registrationLoading = false, registrationLoadNeedsRetry = false
 var registration: RoomRegistrationAcquisition?
    private struct RegistrationBaseline: Sendable {
        let identifier: UUID
        let story: Int
        let features: [RoomRegistrationAcquisition.Feature]
    }
    private struct RegistrationBytes: Sendable {
        let frame: SavedWorldFrame
        let owner: UUID
        let data: Data
    }
    private static let maximumRegistrationRoomBytes = 8 * 1024 * 1024
    private var registrationBytes: RegistrationBytes?
    // A cancelled selection retires publication, not the physical utility task.
    // Keep this lease until completion so rapid rescan cannot fan out decoders.
    private var registrationPreparation: UUID?
    private var registrationBaseline: RegistrationBaseline?
 var registrationCapture = RoomRegistrationCapture()
 var processing: Task<Void,Never>?
 var onMessage: ((String) -> Void)?
 var actualSession = UUID(), recovered: SavedWorldFrame?, baseline = CapturedRoom(identifier: UUID(), story: 0)
 func t(_ english: String, _ arabic: String) -> String { english }
 func currentWorldFrame(sessionID: UUID) -> SavedWorldFrame? { sessionID == actualSession ? recovered : nil }
 struct Artifacts { let room: Data }
 func worldMapArtifacts(for place: SavedPlace) throws -> Artifacts { Artifacts(room: try JSONEncoder().encode(baseline)) }

 func seedBytes(_ data: Data, frame: SavedWorldFrame) { registrationBytes = RegistrationBytes(frame:frame,owner:memory!.writeOwner,data:data) }
 var hasPreparedBaseline: Bool { registrationBaseline != nil }
 var preparationBusy: Bool { registrationPreparation != nil }
 var hasCachedBytes: Bool { registrationBytes != nil }
 func retryDeletionCleanup() {}
 func invalidateWorldMapRecovery() { recovered = nil; registrationBytes = nil; registrationBaseline = nil; registrationRequestID = UUID(); registrationCapture.invalidate() }
