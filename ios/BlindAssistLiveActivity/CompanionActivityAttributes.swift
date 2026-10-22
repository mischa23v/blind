import ActivityKit

/// Shared by the app and the Lock Screen widget (built only with --live-activity). The Lock Screen
/// can be seen by anyone nearby, so it carries only whether the assistant is listening and whether
/// the camera is running: never replies, places, people or anything said.
struct CompanionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var cameraOn: Bool
        var arabic: Bool
    }
}

extension CompanionActivityAttributes.ContentState {
    var title: String { arabic ? "المساعد يستمع" : "Assistant is listening" }
    var detail: String {
        cameraOn ? (arabic ? "الكاميرا تعمل." : "Camera is on.")
            : (arabic ? "الكاميرا متوقفة. افتح المساعد لأرى." : "Camera is off. Open the assistant so I can see.")
    }
}
