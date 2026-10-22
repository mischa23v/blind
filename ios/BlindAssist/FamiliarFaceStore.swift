#if BLIND_FAMILIAR_PEOPLE
import Foundation
import CryptoKit
import Security
import BlindCore

struct FamiliarVisionPrint: Codable, Sendable {
    let archive: Data
    let revision: Int
    let cropContract: String
    let osVersion: String
}

struct FamiliarExample: Codable, Identifiable, Sendable {
    let id: UUID
    let feature: [Float]
    let visionPrint: FamiliarVisionPrint?
    let source: String // camera or selected-photo; no asset IDs or original images retained.
    let createdAt: Date
    let quality: Float
}

struct FamiliarTemplate: Codable, Identifiable, Sendable {
    let id: UUID
    let label: String // User supplied; Mom/Dad labels are not inferred relationships.
    let examples: [FamiliarExample]
    let consent: String
    let consentAt: Date
    var feature: [Float] { FamiliarFacePolicy.normalizedMean(examples.map(\.feature), expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension) ?? [] }
}

/// No photographs, exports, syncing, analytics or conversation-memory integration.
/// All calls are serialized on the main thread; cryptographic key is created only on explicit enrollment.
final class FamiliarFaceStore {
    enum StoreError: Error { case unavailable, corrupt, invalid }
    private struct Archive: Codable {
        let version: Int
        let model: String
        let people: [FamiliarTemplate]
    }
    static var modelID: String {
        let profile = FamiliarModelConfiguration.selected
        return "\(profile.backendKind):\(profile.detectorIdentifier):\(profile.detectorSHA256):\(profile.recognizerIdentifier):\(profile.recognizerSHA256):\(profile.embeddingDimension)"
    }
    private let service = "org.blindassist.familiar-people.experimental.v1"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "encryption-key", kSecAttrSynchronizable as String: false]
    }
    private func location() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        return base.appendingPathComponent("FamiliarFacesPrivate", isDirectory: true)
            .appendingPathComponent("templates.aesgcm")
    }
    private func key(create: Bool) throws -> SymmetricKey {
        var request = query
        request[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound, create else { throw StoreError.unavailable }
        let key = SymmetricKey(size: .bits256)
        var item = query
        item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw StoreError.unavailable }
        return key
    }
    func load() throws -> [FamiliarTemplate] {
        dispatchPrecondition(condition: .onQueue(.main))
        let file = try location()
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 512_000 else { throw StoreError.corrupt }
        let bytes = try Data(contentsOf: file)
        guard bytes.count < 512_000 else { throw StoreError.corrupt }
        let data = try AES.GCM.open(AES.GCM.SealedBox(combined: bytes), using: key(create: false))
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.version == 2, archive.model == Self.modelID, valid(archive.people) else { throw StoreError.corrupt }
        return archive.people
    }
    func save(_ people: [FamiliarTemplate]) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard valid(people) else { throw StoreError.invalid }
        var file = try location(), directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var excluded = URLResourceValues(); excluded.isExcludedFromBackup = true
        try directory.setResourceValues(excluded)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        let plain = try JSONEncoder().encode(Archive(version: 2, model: Self.modelID, people: people))
        // Do not silently replace a missing key when an existing gallery needs it.
        let encryptionKey = try key(create: !FileManager.default.fileExists(atPath: file.path))
        guard let sealed = try AES.GCM.seal(plain, using: encryptionKey).combined else { throw StoreError.unavailable }
        guard sealed.count < 512_000 else { throw StoreError.invalid }
        try sealed.write(to: file, options: [.atomic, .completeFileProtection])
        try file.setResourceValues(excluded)
    }
    func deleteAll() throws {
        dispatchPrecondition(condition: .onQueue(.main))
        let file = try location()
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.unavailable }
    }
    private func valid(_ people: [FamiliarTemplate]) -> Bool {
        people.count <= 20 && Set(people.map(\.id)).count == people.count && people.allSatisfy { person in
            !person.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && person.label.count <= 60 &&
            !person.label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) &&
            person.consent == "self-or-consenting-adult" && person.consentAt.timeIntervalSince1970.isFinite &&
            (1...6).contains(person.examples.count) && Set(person.examples.map(\.id)).count == person.examples.count &&
            FamiliarFacePolicy.validFeature(person.feature, expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension) && person.examples.allSatisfy { example in
                FamiliarFacePolicy.validFeature(example.feature, expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension) && ["camera", "selected-photo"].contains(example.source) &&
                example.createdAt.timeIntervalSince1970.isFinite && example.quality.isFinite && (0...1).contains(example.quality) &&
                (example.visionPrint.map { !$0.archive.isEmpty && $0.archive.count < 65_536 && $0.cropContract.count <= 100 && $0.osVersion.count <= 200 } ?? true)
            }
        }
    }
}
#endif
