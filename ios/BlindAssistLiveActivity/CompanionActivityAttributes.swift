import ActivityKit

/// Shared with the optional widget. The Lock Screen is public to bystanders, so
/// only microphone/camera status belongs here, never replies or private context.
struct CompanionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var cameraOn: Bool
        var listening: Bool
        var arabic: Bool

        init(cameraOn: Bool, listening: Bool, arabic: Bool) {
            self.cameraOn = cameraOn; self.listening = listening; self.arabic = arabic
        }
        private enum CodingKeys: String, CodingKey { case cameraOn, listening, arabic }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            cameraOn = try values.decodeIfPresent(Bool.self, forKey: .cameraOn) ?? false
            // Old activities never supplied actual microphone state. Unknown is
            // not listening; do not preserve the previous always-listening label.
            listening = try values.decodeIfPresent(Bool.self, forKey: .listening) ?? false
            arabic = try values.decodeIfPresent(Bool.self, forKey: .arabic) ?? false
        }
    }
}

extension CompanionActivityAttributes.ContentState {
    func title(stale: Bool) -> String {
        if stale { return arabic ? "حالة المساعد غير مؤكدة" : "Assistant status needs checking" }
        return listening ? (arabic ? "المساعد يستمع" : "Assistant is listening")
            : (arabic ? "الميكروفون متوقف" : "Microphone is off")
    }
    func detail(stale: Bool) -> String {
        if stale { return arabic ? "افتح المساعد للتحقق من الميكروفون والكاميرا." : "Open the assistant to check microphone and camera status." }
        return cameraOn ? (arabic ? "الكاميرا تعمل." : "Camera is on.")
            : (arabic ? "الكاميرا متوقفة." : "Camera is off.")
    }
    func microphoneSymbol(stale: Bool) -> String { stale ? "questionmark.circle" : listening ? "mic" : "mic.slash" }
    func cameraSymbol(stale: Bool) -> String { stale ? "questionmark.circle" : cameraOn ? "eye" : "eye.slash" }
}
