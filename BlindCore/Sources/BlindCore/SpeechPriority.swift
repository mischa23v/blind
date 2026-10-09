/// Application priorities layered over UIKit/AVFoundation completion callbacks.
/// Producers retry with fresh evidence; obsolete speech is never kept in a FIFO.
public enum SpeechPriority: Int, Sendable {
    case status = 0, information = 1, mobility = 2, danger = 3
    public func canInterrupt(_ active: SpeechPriority?) -> Bool {
        guard let active else { return true }
        return self == .danger || (self == .mobility && active.rawValue < rawValue)
    }
}
