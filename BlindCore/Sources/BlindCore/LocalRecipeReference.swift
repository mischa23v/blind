import Foundation

/// Explicitly selected reference text, never a camera observation, allergy
/// clearance, handling instruction from the model, or proof of cooked food.
public struct LocalRecipeReference: Equatable, Sendable {
    public static let maximumBytes = 128 * 1024
    public struct Ingredient: Decodable, Equatable, Sendable {
        public let name: String
        /// Verbatim source amount/unit. No guessed conversions or scaling.
        public let quantity: String
    }
    public struct Step: Decodable, Equatable, Sendable {
        public let text: String
        public let timerSeconds: Int?
    }
    private struct Input: Decodable {
        let schema: Int
        let title, attribution: String
        let ingredients: [Ingredient]
        let steps: [Step]
    }
    public let title, attribution: String
    public let ingredients: [Ingredient]
    public let steps: [Step]
    public enum Invalid: Error { case malformed }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw Invalid.malformed }
        let input = try JSONDecoder().decode(Input.self, from: data)
        guard input.schema == 1, text(input.title, limit: 200), text(input.attribution, limit: 1000),
              (1...100).contains(input.ingredients.count), (1...100).contains(input.steps.count),
              input.ingredients.allSatisfy({ text($0.name, limit: 300) && text($0.quantity, limit: 200) }),
              input.steps.allSatisfy({ text($0.text, limit: 4000) && ($0.timerSeconds.map { (1...86400).contains($0) } ?? true) }) else {
            throw Invalid.malformed
        }
        return Self(title: input.title, attribution: input.attribution,
                    ingredients: input.ingredients, steps: input.steps)
    }
    private static func text(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= limit &&
        !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }
    }
}

/// Foreground, volatile reference navigation. Advancing a page is not completion.
/// Timer values use monotonic uptime, not a wall-clock cooking-safety guarantee.
public struct LocalRecipeSession: Equatable, Sendable {
    public enum TimerState: Equatable, Sendable { case idle, running, elapsed, cancelled, invalidClock }
    public let recipe: LocalRecipeReference
    public private(set) var stepIndex = 0
    public private(set) var timerState: TimerState = .idle
    public private(set) var remainingSeconds: Int?
    private var deadline: Double?
    private var lastUptime: Double?
    public init(recipe: LocalRecipeReference) { self.recipe = recipe }
    public var step: LocalRecipeReference.Step { recipe.steps[stepIndex] }
    @discardableResult public mutating func move(by offset: Int) -> Bool {
        guard offset == 1 || offset == -1 else { return false }
        let next = stepIndex + offset
        guard recipe.steps.indices.contains(next) else { return false }
        cancelTimer(); stepIndex = next; return true
    }
    @discardableResult public mutating func startTimer(uptime: Double) -> Bool {
        guard timerState != .running, let seconds = step.timerSeconds,
              uptime.isFinite, uptime >= 0, (uptime + Double(seconds)).isFinite else { return false }
        deadline = uptime + Double(seconds); lastUptime = uptime
        remainingSeconds = seconds; timerState = .running; return true
    }
    public mutating func tick(uptime: Double) {
        guard timerState == .running, let deadline, let previous = lastUptime else { return }
        guard uptime.isFinite, uptime >= previous else {
            self.deadline = nil; lastUptime = nil; remainingSeconds = nil; timerState = .invalidClock; return
        }
        lastUptime = uptime
        remainingSeconds = Int(ceil(max(0, deadline - uptime)))
        if uptime >= deadline { self.deadline = nil; timerState = .elapsed }
    }
    public mutating func cancelTimer() {
        if timerState == .running { timerState = .cancelled }
        deadline = nil; lastUptime = nil; remainingSeconds = nil
    }
}
