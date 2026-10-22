import Foundation

/// Decision gates for an opt-in familiar-face experiment, not trustworthy identification.
/// Thresholds are uncalibrated for this app's users and devices. A candidate establishes
/// neither a relationship nor guardianship, liveness, permission to follow, or safety.
/// Consent, local-only storage, session binding and deletion are the caller's responsibility.
public enum FamiliarFacePolicy {
    private static let maximumTemplates = 20
    // Arbitrary UNCALIBRATED feature-print experiment settings, NOT facial thresholds.
    private static let visionMaximumDistance = 0.3
    private static let visionMinimumMargin = 0.1

    /// Accepts only the selected 128 or 512 finite components with a nonzero norm. Double accumulation avoids
    /// overflow/underflow for finite Float components, including subnormal embeddings.
    public static func validFeature(_ feature: [Float], expectedDimension: Int = 128) -> Bool {
        [128, 512].contains(expectedDimension) && feature.count == expectedDimension && feature.allSatisfy { $0.isFinite }
            && feature.contains { $0 != 0 }
    }

    /// Bounded reference-template aggregation, not a new recognition model.
    /// Every example contributes equally after normalization; contradictory examples
    /// with an averaged norm at or below 1e-6 fail closed instead of amplifying noise.
    public static func normalizedMean(_ examples: [[Float]], expectedDimension: Int = 128) -> [Float]? {
        guard (1...6).contains(examples.count), examples.allSatisfy({ validFeature($0, expectedDimension: expectedDimension) })
        else { return nil }
        var mean = [Double](repeating: 0, count: expectedDimension)
        for feature in examples {
            let norm = feature.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot()
            for index in mean.indices {
                mean[index] += Double(feature[index]) / norm / Double(examples.count)
            }
        }
        let meanNorm = mean.reduce(0.0) { $0 + $1 * $1 }.squareRoot()
        guard meanNorm.isFinite, meanNorm > 1e-6 else { return nil }
        return mean.map { Float($0 / meanNorm) }
    }

    /// Uses all 1...6 expected example distances, never a best-of-many shortcut.
    /// The caller must supply every enrolled example; missing/failed examples must not
    /// be silently omitted. This function cannot detect an omitted otherwise-valid value.
    public static func meanVisionDistance(_ distances: [Double]) -> Double? {
        guard (1...6).contains(distances.count),
              distances.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        // Scale first to avoid intermediate overflow, even for six greatest-finite values.
        guard let scale = distances.max(), scale > 0 else { return 0 }
        let scaledMean = distances.reduce(0.0) { $0 + $1 / scale } / Double(distances.count)
        return min(1, scaledMean) * scale
    }

    /// Native experimental adapter supplies scores from upstream FaceRecognizerSF.match(FR_COSINE).
    /// Reject the entire batch on malformed data, including duplicate enrolled identities.
    public static func candidate(scores: [(id: UUID, cosine: Double)], cosineThreshold: Double = 0.363, minimumMargin: Double = 0.1) -> UUID? {
        guard cosineThreshold.isFinite, (-1...1).contains(cosineThreshold),
              minimumMargin.isFinite, (0...2).contains(minimumMargin), !scores.isEmpty, scores.count <= maximumTemplates,
              Set(scores.map { $0.id }).count == scores.count,
              scores.allSatisfy({ $0.cosine.isFinite && (-1...1).contains($0.cosine) })
        else { return nil }
        let ranked = scores.sorted { $0.cosine > $1.cosine }
        guard let best = ranked.first, best.cosine >= cosineThreshold else { return nil }
        if ranked.count > 1 {
            // Addition avoids subtractive cancellation at the inclusive margin boundary.
            guard best.cosine >= ranked[1].cosine + minimumMargin else { return nil }
        }
        return best.id
    }

    /// Optional veto only: Vision feature prints can never promote an unknown SFace result.
    /// Requires a complete, unique gallery and agreement with the original SFace candidate.
    /// These arbitrary UNCALIBRATED feature-print settings do not establish face accuracy.
    /// One-template galleries have no runner-up check. Both pipelines can agree and be wrong;
    /// corroboration is neither ground truth nor evidence of independent recognition errors.
    public static func corroboratedCandidate(
        sface: UUID?, visionDistances: [(id: UUID, distance: Double)], expectedIDs: Set<UUID>
    ) -> UUID? {
        guard let sface, !expectedIDs.isEmpty, expectedIDs.count <= maximumTemplates,
              visionDistances.count == expectedIDs.count,
              Set(visionDistances.map { $0.id }) == expectedIDs,
              visionDistances.allSatisfy({ $0.distance.isFinite && $0.distance >= 0 })
        else { return nil }
        let ranked = visionDistances.sorted { $0.distance < $1.distance }
        guard let best = ranked.first, best.id == sface,
              best.distance <= visionMaximumDistance else { return nil }
        if ranked.count > 1 {
            guard ranked[1].distance >= best.distance + visionMinimumMargin else { return nil }
        }
        return sface
    }

    /// Portable reference/parity path only; live recognition uses upstream match scores.
    /// This does not extract face features or replace an upstream recognition model.
    public static func candidate(probe: [Float], gallery: [(id: UUID, feature: [Float])], expectedDimension: Int = 128, cosineThreshold: Double = 0.363, minimumMargin: Double = 0.1) -> UUID? {
        guard validFeature(probe, expectedDimension: expectedDimension), !gallery.isEmpty, gallery.count <= maximumTemplates,
              gallery.allSatisfy({ validFeature($0.feature, expectedDimension: expectedDimension) }) else { return nil }
        let probeNorm = probe.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot()
        let scores = gallery.map { entry -> (id: UUID, cosine: Double) in
            let norm = entry.feature.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot()
            let cosine = zip(probe, entry.feature).reduce(0.0) {
                $0 + (Double($1.0) / probeNorm) * (Double($1.1) / norm)
            }
            // Roundoff alone can put a normalized dot product slightly beyond its range.
            return (entry.id, max(-1, min(1, cosine)))
        }
        return candidate(scores: scores, cosineThreshold: cosineThreshold, minimumMargin: minimumMargin)
    }

    /// All times must share the current session's monotonic clock, not wall-clock dates.
    /// `frameAt` is the newest camera frame; a captured probe cannot postdate that frame.
    /// The caller must separately reject results from previous sessions or gallery revisions.
    public static func fresh(capturedAt: Double, now: Double, frameAt: Double) -> Bool {
        guard capturedAt.isFinite, now.isFinite, frameAt.isFinite,
              capturedAt >= 0, capturedAt <= frameAt, frameAt <= now else { return false }
        return now - capturedAt <= 1.5 && now - frameAt <= 0.5
    }
    /// Only bounds completion of an explicitly past-snapshot utterance, NOT a live
    /// name/position or a new comparison. Caller still validates session, pose and hazards.
    public static func snapshotSpeechFresh(capturedAt: Double, now: Double, frameAt: Double) -> Bool {
        guard capturedAt.isFinite, now.isFinite, frameAt.isFinite,
              capturedAt >= 0, capturedAt <= frameAt, frameAt <= now else { return false }
        return now - capturedAt <= 12 && now - frameAt <= 0.5
    }

    /// Stateless one-shot result: loss, unusable pose, crowds or an obsolete request
    /// can never retain a previous candidate. No back-of-head/relationship inference.
    public static func candidateForAttempt(requestID: UUID, currentRequestID: UUID, faceCount: Int,
        feature: [Float], scores: [(id: UUID, cosine: Double)], expectedDimension: Int = 128,
        cosineThreshold: Double = 0.363, minimumMargin: Double = 0.1) -> UUID? {
        guard requestID == currentRequestID, faceCount == 1,
              validFeature(feature, expectedDimension: expectedDimension) else { return nil }
        return candidate(scores: scores, cosineThreshold: cosineThreshold, minimumMargin: minimumMargin)
    }
    public static func shouldSpeakFaceGuidance(lastAt: Double?, now: Double) -> Bool {
        guard now.isFinite, now >= 0 else { return false }
        guard let lastAt else { return true }
        return lastAt.isFinite && lastAt >= 0 && now >= lastAt && now - lastAt >= 8
    }

}
