import Foundation

/// A platform completion signal is not proof of human comprehension.
public enum NarrationDelivery: String, Codable, Sendable {
    case completed, interrupted, unknown
}
