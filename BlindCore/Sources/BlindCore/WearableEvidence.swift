import Foundation

/// Body-relative sensor reports, never camera-object identities or world coordinates.
public enum WearableEvidence {
    public static func observations(packet: WearablePacket, receivedAt: Double, now: Double, arabic: Bool) -> [SceneObservation] {
        guard receivedAt.isFinite, now.isFinite, now >= receivedAt, now - receivedAt <= 0.8,
              !packet.hasFault, packet.isCalibrated else { return [] }
        let english = ["front", "front-right", "right", "rear-right", "rear", "rear-left", "left", "front-left"]
        let translated = ["الأمام", "الأمام يميناً", "اليمين", "الخلف يميناً", "الخلف", "الخلف يساراً", "اليسار", "الأمام يساراً"]
        let count = packet.role == .belt ? 8 : 1
        return (0..<count).sorted { packet.distancesMM[$0] == packet.distancesMM[$1] ? $0 < $1 : packet.distancesMM[$0] < packet.distancesMM[$1] }.compactMap { index in
            let mm = packet.distancesMM[index]
            guard mm > 0, mm != .max else { return nil }
            let metres = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), Double(mm) / 1000)
            let text: String
            if packet.role == .wrist {
                text = arabic ? "حساس المعصم: نحو \(metres) متر باتجاه توجيهه. الغرض غير محدد." : "Wrist sensor: about \(metres) metres along its pointing direction. Object unidentified."
            } else {
                text = arabic ? "حساس الحزام، \(translated[index]): نحو \(metres) متر. الغرض غير محدد." : "Belt sensor, \(english[index]): about \(metres) metres. Object unidentified."
            }
            // For range records, 1 means a valid received report, not a probability of physical accuracy.
            return SceneObservation(id: "wearable-\(packet.role.rawValue)-\(index)", kind: .range, text: text,
                                    confidence: 1, capturedAt: receivedAt)
        }
    }
    /// Only speak an old snapshot if fresh reports still agree at the spoken 0.1 m precision.
    public static func stillMatches(_ previous: [SceneObservation], current: [SceneObservation]) -> Bool {
        let latest = current.filter { $0.kind == .range }
        return previous.filter { $0.kind == .range }.allSatisfy { old in
            latest.contains { $0.id == old.id && $0.text == old.text }
        }
    }
}
