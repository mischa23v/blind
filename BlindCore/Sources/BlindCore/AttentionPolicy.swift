import Foundation

public enum AttentionMode: String, Sendable { case importantOnly, moving, stationary }

/// Filters observations BEFORE any language model sees them. Local urgent alerts bypass this filter.
public struct AttentionPolicy: Sendable {
    private var previous: Point3?
    private var lastSample: Double?
    private var stillSince: Double?
    private var lastSpoken = -Double.infinity
    private var lastContent = ""
    public private(set) var stationary = false
    /// Latest walking speed in metres per second from tracked camera motion; 0 when unknown.
    public private(set) var speed = 0.0
    public init() {}
    /// Words for one model answer while moving toward a goal, like a guide that says a word or two
    /// when you walk fast and more as you slow down (user, 2026-10-09). Sensor cues are separate.
    public static func guidanceWords(speed: Double, goalActive: Bool, standardLimit: Int) -> Int {
        guard goalActive, speed.isFinite else { return standardLimit }
        let limit = speed >= 1.0 ? 3 : speed >= 0.6 ? 6 : speed > 0.12 ? 12 : standardLimit
        return min(limit, standardLimit)
    }
    public mutating func observe(camera: Point3, at time: Double, tracking: Bool) {
        guard tracking, camera.isFinite, time.isFinite else { resetMotion(); return }
        defer { previous = camera; lastSample = time }
        guard let previous, let lastSample, time > lastSample, time - lastSample <= 0.5 else {
            stillSince = nil; stationary = false; return
        }
        let instant = previous.distance(to: camera) / (time - lastSample)
        // Smoothed so one jolt of the chest mount does not swing the word limit.
        self.speed = self.speed * 0.8 + instant * 0.2
        if instant > 0.12 { stillSince = nil; stationary = false }
        else {
            if stillSince == nil { stillSince = time }
            stationary = time - (stillSince ?? time) >= 3
        }
    }
    public mutating func resetMotion() { previous = nil; lastSample = nil; stillSince = nil; stationary = false; speed = 0 }
    public func mode(detail: DetailLevel) -> AttentionMode {
        detail == .minimal ? .importantOnly : stationary ? .stationary : .moving
    }
    public func permitsAmbient(detail: DetailLevel, urgent: Bool, now: Double) -> Bool {
        guard !urgent, let lastSample,
              now >= lastSample, now - lastSample <= 0.5 else { return false }
        return now - lastSpoken >= (detail == .detailed ? 10 : 20)
    }
    public mutating func select(text: String, people: Int, labels: [String], detail: DetailLevel,
                                arabic: Bool, now: Double, requested: Bool) -> String? {
        if !requested && !permitsAmbient(detail: detail, urgent: false, now: now) { return nil }
        var items: [String] = []
        // Text is often actionable (door names, signs); general scene labels get the remaining budget.
        if !text.isEmpty { items.append(String(text.prefix(detail == .detailed ? 400 : 180))) }
        if people > 0 { items.append(arabic ? "أشخاص مرصودون: \(people)." : "People observed: \(people).") }
        if detail == .detailed || (requested && items.isEmpty) { items.append(contentsOf: labels.prefix(detail == .detailed ? 3 : 1)) }
        let selected = items.joined(separator: " ")
        guard !selected.isEmpty, requested || selected != lastContent else { return nil }
        lastContent = selected; lastSpoken = now
        return selected
    }
}
