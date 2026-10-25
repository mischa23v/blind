// HARNESS ONLY. Never copy this file into the app. These stubs allow the exact
// IndoorNavigator controller bodies to execute on Linux, not Apple runtime proof.
import Foundation
import BlindCore
protocol ObservableObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
struct IndoorSituation {
    init(map: IndoorMap, package: PlacePackage?, revision: String, alignment: String, level: String?,
         position: Point3?, cameraForward: Point3?, bodyForward: Point3?, age: Double) {}
}
struct InstalledPlacePackage: Sendable { let package: PlacePackage }
struct CommunityInventory: Sendable { var installed: [InstalledPlacePackage] = [] }
enum CommunityCacheTestHooks {
    private static let lock = NSLock()
    private static var handler: (@Sendable (PlacePackage) async throws -> Void)?
    static func set(_ next: (@Sendable (PlacePackage) async throws -> Void)?) { lock.lock(); handler = next; lock.unlock() }
    private static func current() -> (@Sendable (PlacePackage) async throws -> Void)? { lock.lock(); defer { lock.unlock() }; return handler }
    static func install(_ package: PlacePackage) async throws { try await current()?(package) }
}
actor CommunityPackageStorage {
    func list() throws -> CommunityInventory { .init() }
    func install(_ package: PlacePackage) async throws -> CommunityInventory { try await CommunityCacheTestHooks.install(package); return .init() }
}
enum DebugSessionLog { static func purgeForPrivacyClear(_ completion: @escaping (Bool) -> Void) { completion(true) } }
enum DebugNativeSessionTrace { static func reportPurgeResult(_ success: Bool) {} }
enum GuidanceText {
    static func noDestination(arabic: Bool) -> String { "No unique destination found. Choose a named destination in Routes." }
    static func noRoute(arabic: Bool) -> String { "No accessible authored route found. Guidance stopped." }
}
