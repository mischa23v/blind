import Foundation
import Combine
import BlindCore

final class JourneyStore: ObservableObject {
    @Published private(set) var saved: [Journey] = []
    @Published private(set) var distance = 0.0
    @Published private(set) var message = ""
    private var recorder: JourneyRecorder?
    private var directory: URL
    var current: Journey? { recorder?.journey }
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Journeys", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            saved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }.compactMap {
                    guard let data = try? Data(contentsOf: $0) else { return nil }
                    return try? JSONDecoder().decode(Journey.self, from: data)
                }.sorted { $0.createdAt > $1.createdAt }
        } catch { message = "Journey storage unavailable." }
    }
    func begin() { finish(); recorder = JourneyRecorder(); distance = 0 }
    func observe(_ observation: Observation) {
        recorder?.observe(camera: observation.camera, time: observation.timestamp, tracking: observation.trackingNormal)
        if let recorder { distance = recorder.distance }
    }
    func breakTracking() { recorder?.breakTracking() }
    func finish() {
        guard let recorder else { return }
        self.recorder = nil
        guard !recorder.journey.points.isEmpty else { return }
        do {
            try JSONEncoder().encode(recorder.journey).write(to: url(for: recorder.journey), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            saved.insert(recorder.journey, at: 0); message = "Journey saved on this phone."
        } catch { message = "Journey could not be saved." }
    }
    func url(for journey: Journey) -> URL { directory.appendingPathComponent("\(journey.id).json") }
    func delete(_ journey: Journey) {
        do { try FileManager.default.removeItem(at: url(for: journey)); saved.removeAll { $0.id == journey.id } }
        catch { message = "Journey could not be deleted." }
    }
}
