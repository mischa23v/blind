import Foundation

/// Delivery binding, never a new clock read or a renewed acquisition lease.
/// Keep this receipt for queueing/playback/repeat instead of admitting the same
/// string again against a newer clock read with identical minute text.
public struct CompanionClockDeliveryReceipt: Equatable, Sendable {
    public let text: String
    public let requestID: UUID
    public let generation: UInt64
    public let replyIDs: [UUID]
    fileprivate init(text: String, requestID: UUID, generation: UInt64, replyIDs: [UUID]) {
        self.text = text; self.requestID = requestID; self.generation = generation; self.replyIDs = replyIDs
    }
}

/// App-specific admission adapter over the original CompanionClockReplyLease.
/// Native code owns the acquisition ledger. Model text/decoded tool JSON cannot
/// create a lease, alter its source, or advance its monotonic start.
public enum CompanionClockDelivery {
    /// Bounded defense for current-time statements, not general semantic truth
    /// detection. Ordinary arithmetic, history and explicitly quoted stories do
    /// not need a clock. Recognized current-time claims need exact code wording.
    public static func requiresClockEvidence(_ sentence: String) -> Bool {
        var text = SpatialClaimGuard.normalizeArabic(sentence.lowercased())
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["right now, ", "right now ", "currently, ", "currently "] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("device clock") || text.hasPrefix("ساعه الجهاز") { return true }
        func has(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        let value = #"(?:[0-9]{1,2}:[0-9]{2}(?:\s*[ap]\.?m\.?)?|[0-9]{1,2}\s*(?:[ap]\.?m\.?|o'?clock)|(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?:\s+(?:fifteen|thirty|forty five))?\s*(?:[ap]\.?m\.?|o'?clock)|noon|midnight)"#
        if has(#"^(?:the )?(?:current|local|device) time is\b"#)
            || has(#"^(?:the )?(?:time now|time) is "# + value + #"(?:\b|$)"#) { return true }
        if has(#"^(?:i (?:think|guess) )?it(?:'s| is) (?:currently |now )?"# + value + #"(?:\b|$)"#) { return true }
        return has(#"^(?:الساعه(?: الان| الحين)?|الوقت(?: الان| الحين)?|التوقيت الحالي)\s*[:،]?\s*(?:هي |هو )?(?:[0-9٠-٩۰-۹]|الواحده|الثانيه|الثالثه|الرابعه|الخامسه|السادسه|السابعه|الثامنه|التاسعه|العاشره|الحاديه|الثانيه عشره|واحده|اثنين|ثلاثه|اربعه|خمسه|سته|سبعه|ثمانيه|تسعه|عشره)"#)
    }

    /// Nil means withhold. An empty replyIDs list means ordinary nonclock text.
    /// The oldest exact read in this turn is deliberately selected. Callers keep
    /// invalidated entries until the turn ends: repeated model reads of the same
    /// minute string cannot silently renew a previously queued/displayed answer.
    public static func admit(_ text: String, leases: inout [UUID: CompanionClockReplyLease],
                             requestID: UUID, generation: UInt64, now: Date,
                             monotonicNow: Double, timeZone: TimeZone) -> CompanionClockDeliveryReceipt? {
        guard !text.isEmpty, text.unicodeScalars.count <= 2000 else { return nil }
        var ids: [UUID] = []
        for part in CompanionEvidenceGuard.sentenceParts(text) {
            let sentence = part.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let matching = leases.values.filter {
                $0.binding.requestID == requestID && $0.binding.generation == generation
                    && $0.reply.utf8.elementsEqual(sentence.utf8)
            }.sorted {
                $0.issuedAt == $1.issuedAt ? $0.binding.replyID.uuidString < $1.binding.replyID.uuidString : $0.issuedAt < $1.issuedAt
            }
            if let lease = matching.first {
                if !ids.contains(lease.binding.replyID) { ids.append(lease.binding.replyID) }
            } else if requiresClockEvidence(sentence) { return nil }
        }
        let receipt = CompanionClockDeliveryReceipt(text: text, requestID: requestID, generation: generation, replyIDs: ids)
        return validates(receipt, text: text, leases: &leases, requestID: requestID,
            generation: generation, now: now, monotonicNow: monotonicNow, timeZone: timeZone) ? receipt : nil
    }

    public static func validates(_ receipt: CompanionClockDeliveryReceipt, text: String,
                                 leases: inout [UUID: CompanionClockReplyLease],
                                 requestID: UUID, generation: UInt64, now: Date,
                                 monotonicNow: Double, timeZone: TimeZone) -> Bool {
        guard receipt.requestID == requestID, receipt.generation == generation,
              receipt.text.utf8.elementsEqual(text.utf8) else { return false }
        for id in receipt.replyIDs {
            guard var lease = leases[id] else { return false }
            let binding = CompanionClockReplyLease.Binding(requestID: requestID, generation: generation, replyID: id)
            let valid = lease.validates(reply: lease.reply, binding: binding, now: now,
                monotonicNow: monotonicNow, timeZone: timeZone)
            leases[id] = lease
            guard valid else { return false }
        }
        return true
    }

    /// A turn that actually selected the clock tool renders this code-owned
    /// receipt, not any model-authored time wording. The first selected read ID
    /// remains fixed through all callbacks; later reads cannot renew it.
    public static func replyForClockOperation(_ replyID: UUID,
                                             leases: inout [UUID: CompanionClockReplyLease],
                                             requestID: UUID, generation: UInt64, now: Date,
                                             monotonicNow: Double, timeZone: TimeZone) -> CompanionClockDeliveryReceipt? {
        guard let original = leases[replyID] else { return nil }
        let receipt = CompanionClockDeliveryReceipt(text: original.reply, requestID: requestID,
            generation: generation, replyIDs: [replyID])
        return validates(receipt, text: original.reply, leases: &leases, requestID: requestID,
            generation: generation, now: now, monotonicNow: monotonicNow, timeZone: timeZone) ? receipt : nil
    }

    /// Post-await tool boundary: canonical-looking JSON is not sufficient. Match
    /// the entire original record and source, then recheck its acquisition lease.
    public static func validatesToolResult(_ result: CompanionToolResult,
                                          leases: inout [UUID: CompanionClockReplyLease],
                                          requestID: UUID, generation: UInt64, now: Date,
                                          monotonicNow: Double, timeZone: TimeZone) -> Bool {
        guard result.status == .success, result.evidence.count == 1,
              let original = leases.values.first(where: { $0.evidence.id == result.evidence[0].id }),
              result == original.result else { return false }
        let receipt = CompanionClockDeliveryReceipt(text: original.reply, requestID: requestID,
            generation: generation, replyIDs: [original.binding.replyID])
        return validates(receipt, text: original.reply, leases: &leases, requestID: requestID,
            generation: generation, now: now, monotonicNow: monotonicNow, timeZone: timeZone)
    }
}
