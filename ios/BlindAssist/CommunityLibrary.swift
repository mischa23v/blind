import Foundation
import CryptoKit
import Combine
import BlindCore

struct InstalledPlacePackage: Identifiable, Sendable {
    let digest: String
    let package: PlacePackage
    var id: String { digest }
}

struct CommunityFileIssue: Identifiable, Sendable {
    let id: String
    let message: String
    var removable: Bool { id.count == 64 && id.allSatisfy { "0123456789abcdef".contains($0) } }
}
struct CommunityInventory: Sendable {
    var installed: [InstalledPlacePackage] = []
    var issues: [CommunityFileIssue] = []
}

/// All package file IO is off the UI actor; immutable content files need no mutable index.
actor CommunityPackageStorage {
    private let directory: URL
    private let maximumStorage: Int
    private let maximumRevisions: Int
    init(directory: URL? = nil, maximumStorage: Int = 40_000_000, maximumRevisions: Int = 100) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommunityMaps", isDirectory: true)
        self.maximumStorage = max(1, min(40_000_000, maximumStorage))
        self.maximumRevisions = max(1, min(100, maximumRevisions))
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        var url = directory, values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
    }
    func list() throws -> CommunityInventory {
        try prepare()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard files.count <= 200 else { throw CommunityError.quota }
        var result = CommunityInventory()
        for file in files where file.pathExtension == "json" {
            let digest = file.deletingPathExtension().lastPathComponent
            do { result.installed.append(InstalledPlacePackage(digest: digest, package: try load(digest: digest))) }
            catch { result.issues.append(CommunityFileIssue(id: digest, message: error.localizedDescription)) }
        }
        result.installed.sort { $0.package.createdAt > $1.package.createdAt }; return result
    }
    func install(_ package: PlacePackage) throws -> CommunityInventory {
        try Task.checkCancellation()
        let data = try package.encoded(), digest = Self.digest(data), inventory = try list(), installed = inventory.installed
        if let existing = installed.first(where: { $0.package.id == package.id && $0.package.revision == package.revision }) {
            guard existing.digest == digest else { throw CommunityError.conflict }; return inventory
        }
        // Preserve damaged evidence until the user explicitly removes it; never overwrite it on retry.
        guard !FileManager.default.fileExists(atPath: directory.appendingPathComponent(digest).appendingPathExtension("json").path) else { throw CommunityError.checksum }
        let bytes = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        guard installed.count < maximumRevisions, bytes + data.count <= maximumStorage else { throw CommunityError.quota }
        try Task.checkCancellation()
        try data.write(to: directory.appendingPathComponent(digest).appendingPathExtension("json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return try list()
    }
    func load(digest: String) throws -> PlacePackage {
        guard digest.count == 64, digest.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw CommunityError.invalid }
        let file = directory.appendingPathComponent(digest).appendingPathExtension("json")
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= PlacePackage.maximumBytes else { throw CommunityError.invalid }
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        let data = try handle.read(upToCount: PlacePackage.maximumBytes + 1) ?? Data()
        guard data.count <= PlacePackage.maximumBytes else { throw CommunityError.tooLarge }
        guard Self.digest(data) == digest else { throw CommunityError.checksum }
        return try PlacePackage.decode(data)
    }
    func remove(digest: String) throws -> CommunityInventory {
        try Task.checkCancellation()
        guard digest.count == 64, digest.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw CommunityError.invalid }
        try FileManager.default.removeItem(at: directory.appendingPathComponent(digest).appendingPathExtension("json"))
        return try list()
    }
    func venueCatalog() throws -> VenuePackageCatalog {
        try prepare()
        let file = directory.appendingPathComponent("venue-directory.catalog")
        guard FileManager.default.fileExists(atPath: file.path) else { return .init(references: []) }
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= VenuePackageCatalog.maximumBytes else { throw CommunityError.invalid }
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        return try VenuePackageCatalog.decode(handle.read(upToCount: VenuePackageCatalog.maximumBytes + 1) ?? Data())
    }
    func saveVenueCatalog(_ catalog: VenuePackageCatalog) throws {
        try catalog.validate(); let bytes = try JSONEncoder().encode(catalog)
        guard bytes.count <= VenuePackageCatalog.maximumBytes else { throw CommunityError.tooLarge }
        try Task.checkCancellation(); try prepare()
        try bytes.write(to: directory.appendingPathComponent("venue-directory.catalog"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func export(_ package: PlacePackage) throws -> URL {
        let data = try package.encoded()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).blindplace.json")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); return url
    }
}

@MainActor final class CommunityLibrary: ObservableObject {
    @Published private(set) var venueCatalog = VenuePackageCatalog(references: [])
    @Published private(set) var installed: [InstalledPlacePackage] = []
    @Published private(set) var fileIssues: [CommunityFileIssue] = []
    @Published private(set) var releases: [PublicMapRelease] = []
    @Published private(set) var preview: PlacePackage?
    @Published private(set) var status = ""
    @Published private(set) var busy = false
    @Published private(set) var hasNextPage = false
    private let storage: CommunityPackageStorage
    private let client: PublicMapClient
    private var task: Task<Void, Never>?
    private var networkOperation = false
    private var generation = UUID()
    private var page = 0
    private var repository = ""
    var networkAllowed = false { didSet { if !networkAllowed && networkOperation { cancel() } } }
    init(storage: CommunityPackageStorage = CommunityPackageStorage(), client: PublicMapClient = PublicMapClient()) {
        self.storage = storage; self.client = client; reload()
    }
    func cancel() { generation = UUID(); task?.cancel(); task = nil; busy = false; networkOperation = false }
    private func perform(network: Bool = false, _ operation: @escaping @MainActor () async throws -> Void) {
        cancel(); let id = generation; busy = true; networkOperation = network
        task = Task { [weak self] in
            do { try await operation() }
            catch is CancellationError {}
            catch { if self?.generation == id { self?.status = error.localizedDescription } }
            if self?.generation == id { self?.busy = false; self?.task = nil; self?.networkOperation = false }
        }
    }
    func reload() {
        perform { [self] in
            let result = try await storage.list(); try Task.checkCancellation(); accept(result)
            do {
                let catalog = try await storage.venueCatalog(); try Task.checkCancellation()
                venueCatalog = catalog
            } catch is CancellationError { throw CancellationError() }
            catch {
                try Task.checkCancellation(); venueCatalog = .init(references: [])
                status = "Saved packages loaded. Local venue directory is unavailable or damaged; its file was preserved. Import a valid directory to replace it."
            }
        }
    }
    private func accept(_ result: CommunityInventory) { installed = result.installed; fileIssues = result.issues }
    func search(repository: String, more: Bool = false) {
        guard networkAllowed else { status = CommunityError.offline.localizedDescription; return }
        let target = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = more && target == self.repository ? page + 1 : 1
        perform(network: true) { [self] in
            let result = try await client.releases(repository: target, page: next)
            try Task.checkCancellation(); guard networkAllowed else { throw CommunityError.offline }
            if next == 1 { releases = [] }
            let existing = Set(releases.map(\.id)); releases += result.filter { !existing.contains($0.id) }
            // These are filtered assets, not raw GitHub pages: an empty filtered page
            // does not prove later pages contain no compatible map.
            page = next; self.repository = target; hasNextPage = next < 50
            status = result.isEmpty ? "No compatible map assets on this release page. You can check the next page." : "Choose a package to download and review. GitHub stars do not verify its map."
        }
    }
    func download(_ release: PublicMapRelease) {
        guard networkAllowed else { status = CommunityError.offline.localizedDescription; return }
        preview = nil
        perform(network: true) { [self] in
            let data = try await client.download(release); try Task.checkCancellation()
            guard networkAllowed else { throw CommunityError.offline }
            if let digest = release.digest {
                guard digest == "sha256:\(CommunityPackageStorage.digest(data))" else { throw CommunityError.checksum }
            }
            let package = try PlacePackage.decode(data)
            guard package.visibility == "public" else { throw CommunityError.invalid }
            preview = package
            status = release.digest == nil ? "Downloaded for review. Publisher checksum was not supplied; source identity and review claims remain unverified." : "Download checksum matched. Review claims and physical layout still require verification."
        }
    }
    func importFile(_ url: URL) {
        preview = nil
        perform { [self] in
            let data = try await Task.detached {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true, let size = values.fileSize, size <= PlacePackage.maximumBytes else { throw CommunityError.tooLarge }
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let bytes = try handle.read(upToCount: PlacePackage.maximumBytes + 1) ?? Data()
                guard bytes.count <= PlacePackage.maximumBytes else { throw CommunityError.tooLarge }; return bytes
            }.value
            try Task.checkCancellation(); preview = try PlacePackage.decode(data); status = "Imported for review. Not activated as your current location."
        }
    }
    func importVenueCatalog(_ url: URL) {
        perform { [self] in
            let data = try await Task.detached {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, size <= VenuePackageCatalog.maximumBytes else { throw CommunityError.tooLarge }
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                return try handle.read(upToCount: VenuePackageCatalog.maximumBytes + 1) ?? Data()
            }.value
            try Task.checkCancellation()
            let catalog = try VenuePackageCatalog.decode(data)
            try await storage.saveVenueCatalog(catalog); try Task.checkCancellation()
            venueCatalog = catalog; status = "Local venue directory saved. Choose a venue explicitly; coordinates are candidates, not your location."
        }
    }
    func review(_ item: InstalledPlacePackage) {
        preview = nil
        perform { [self] in
            let package = try await storage.load(digest: item.digest); try Task.checkCancellation()
            preview = package; status = "Offline saved revision. This is a place preview, not your current location."
        }
    }
    func savePreview() {
        guard let preview else { return }
        perform { [self] in
            let result = try await storage.install(preview); try Task.checkCancellation()
            accept(result); status = "Saved for offline use. Active route unchanged."
        }
    }
    func remove(_ item: InstalledPlacePackage) {
        perform { [self] in
            let result = try await storage.remove(digest: item.digest); try Task.checkCancellation(); accept(result)
            if preview?.id == item.package.id && preview?.revision == item.package.revision { preview = nil }
            status = "Offline revision removed. Any separately loaded route remains unchanged."
        }
    }
    func removeDamaged(_ issue: CommunityFileIssue) {
        guard issue.removable else { return }
        perform { [self] in
            let result = try await storage.remove(digest: issue.id); try Task.checkCancellation(); accept(result)
            status = "Damaged file removed. You can import or download that revision again."
        }
    }
    func exportedPreview() async throws -> URL {
        guard let preview else { throw CommunityError.missing }; return try await storage.export(preview)
    }
    func draft(map: IndoorMap, author: String, license: String) {
        do { cancel(); preview = try PlacePackage.draft(map: map, author: author, license: license); status = "Private draft. Review names, geometry, ownership and license before sharing." }
        catch { status = error.localizedDescription }
    }
    func preparePublicCopy() {
        guard var package = preview else { return }
        cancel(); package.visibility = "public"; package.revision = UUID().uuidString
        if package.routeMap?.packageID != nil { package.routeMap?.packageRevision = package.revision }
        package.createdAt = ISO8601DateFormatter().string(from: Date()); package.reviews = []
        preview = package; status = "Public-sharing draft only. Previous review claims were removed because this is a new revision. Review before exporting; nothing is published."
    }
}

/// Explicit local venue switch. This reuses IndoorNavigator's real map IO owner;
/// a catalogue match is never an observation of the user's building/floor/pose.
@MainActor final class VenuePackageActivation: ObservableObject {
    typealias Loader = @MainActor (String) async throws -> PlacePackage
    @Published private(set) var package: PlacePackage?
    @Published private(set) var selected: VenuePackageReference?
    @Published private(set) var status = "Choose a venue package. Live location is unknown."
    @Published private(set) var loading = false
    private struct Request {
        let generation: UUID
        let reference: VenuePackageReference
        let indoor: IndoorNavigator
        let intent: IndoorNavigator.CommunityImportIntent
    }
    private var queued: Request?
    var operationInFlight: Bool { task != nil }
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var pending: (IndoorNavigator, IndoorNavigator.CommunityImportIntent)?
    private var completingRevision: UUID?
    private let load: Loader
    init(storage: CommunityPackageStorage = CommunityPackageStorage(), loader: Loader? = nil) {
        load = loader ?? { digest in try await storage.load(digest: digest) }
    }
    func cancel() {
        if loading { package = nil; status = "Venue loading cancelled. Guidance remains unavailable; live location is unknown." }
        generation = UUID(); queued = nil; loading = false
        if let (indoor, intent) = pending {
            if indoor.ownsCommunityImport(intent) { indoor.failCommunityImport(intent) }
            else if indoor.revision == completingRevision, let selected {
                // Retire the ordered writer too, not only the earlier package-read task.
                let replacement = indoor.beginCommunityImport(packageID: selected.packageID, revision: selected.packageRevision)
                indoor.failCommunityImport(replacement)
            }
        }
        pending = nil; completingRevision = nil
    }
    func select(_ reference: VenuePackageReference, indoor: IndoorNavigator) {
        cancel(); package = nil; selected = reference
        // Even a missing or invalid new target must not retain the previous route/pose.
        let intent = indoor.beginCommunityImport(packageID: reference.packageID, revision: reference.packageRevision)
        pending = (indoor, intent); let request = generation
        loading = true; status = "Loading exact saved venue revision. Live location is unknown."
        queued = Request(generation: request, reference: reference, indoor: indoor, intent: intent)
        startReadIfIdle()
    }
    private func startReadIfIdle() {
        guard task == nil else { return }
        task = Task { [self] in
            // One real read at a time; newer selections replace one queued request.
            // Retiring authority cannot pretend a synchronous file read has ended.
            while let request = queued {
                queued = nil
                await read(request)
            }
            task = nil
        }
    }
    private func read(_ work: Request) async {
        let request = work.generation, reference = work.reference, indoor = work.indoor, intent = work.intent
            do {
                try reference.validate()
                let value = try await load(reference.digest)
                try Task.checkCancellation()
                guard generation == request else { return }
                guard indoor.ownsCommunityImport(intent) else { throw SpatialMapIOError.superseded }
                try reference.validate(package: value, actualDigest: CommunityPackageStorage.digest(try value.encoded()))
                // Preserve the full floor/room/layout package even when it has no route graph.
                package = value
                guard value.localization == "manual-landmarks", value.routeMap != nil else {
                    indoor.failCommunityImport(intent); pending = nil; loading = false
                    status = "Venue layout loaded for preview; no compatible route graph. Live location is unknown."
                    return
                }
                await withCheckedContinuation { (finished: CheckedContinuation<Void, Never>) in
                    indoor.completeCommunityImport(value, intent: intent) { [weak self] result in
                        // Keep the single operation slot until the real ordered writer callback.
                        defer { finished.resume() }
                        guard let self, self.generation == request else { return }
                        self.pending = nil; self.completingRevision = nil; self.loading = false
                        switch result {
                        case .success:
                            self.status = "Venue floors, rooms, objects and authored routes loaded. Live location and floor are unknown; fresh localization is required."
                        case .failure:
                            self.package = nil
                            self.status = "Venue activation was superseded or failed. Guidance remains unavailable."
                        }
                    }
                    completingRevision = indoor.revision
                }
            } catch {
                guard generation == request else { return }
                indoor.failCommunityImport(intent); pending = nil; package = nil; loading = false
                status = "Exact venue package unavailable or invalid. Import/download and review this revision first; no automatic network request was made. Guidance remains unavailable."
            }
    }
}
