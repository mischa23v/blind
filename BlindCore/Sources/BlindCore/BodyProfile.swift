import Foundation

/// Optional local-only input. Gender is self-description, not biological sex or a
/// geometric predictor. Age is reported, never proof of age/guardian presence.
public struct BodyProfileInput: Codable, Equatable, Sendable {
    public var ageYears: Double?
    public var gender: String?
    public var weightKilograms: Double?
    public var heightMetres: Double?
    public init(ageYears: Double? = nil, gender: String? = nil,
                weightKilograms: Double? = nil, heightMetres: Double? = nil) {
        self.ageYears = ageYears; self.gender = gender
        self.weightKilograms = weightKilograms; self.heightMetres = heightMetres
    }
    public var valid: Bool {
        func optional(_ value: Double?, _ range: ClosedRange<Double>) -> Bool {
            value.map { $0.isFinite && range.contains($0) } ?? true
        }
        return optional(ageYears, 0...130) && optional(weightKilograms, 0.5...700) &&
            optional(heightMetres, 0.3...2.5) &&
            (gender.map { $0.utf8.count <= 100 && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) } ?? true)
    }
    public static func metres(centimetres: Double) -> Double { centimetres / 100 }
    public static func metres(inches: Double) -> Double { inches * 0.0254 }
    public static func kilograms(pounds: Double) -> Double { pounds * 0.45359237 }
}

public enum BodyDimensionSource: String, Codable, Hashable, Sendable { case estimated, reported, measured }
/// Recorded dimensions are not an accuracy certificate. Measured means a recorded
/// measurement with provenance, not a validated native collision/pose provider.
public struct BodyDimensions: Codable, Equatable, Sendable {
    public let height: Double
    public let width: Double
    public let depth: Double
    public let uncertainty: Double?
    public let source: BodyDimensionSource
    public let provenance: String
    public let recordedAt: Double
    public let profileRevision: UUID
    public init(height: Double, width: Double, depth: Double, uncertainty: Double?,
                source: BodyDimensionSource, provenance: String, recordedAt: Double, profileRevision: UUID) {
        self.height = height; self.width = width; self.depth = depth; self.uncertainty = uncertainty
        self.source = source; self.provenance = provenance; self.recordedAt = recordedAt; self.profileRevision = profileRevision
    }
    public var valid: Bool {
        [height, width, depth, recordedAt].allSatisfy(\.isFinite) &&
        (0.3...2.5).contains(height) && (0.1...2).contains(width) && (0.1...2).contains(depth) &&
        (uncertainty.map { $0.isFinite && (0...1).contains($0) } ?? true) && recordedAt >= 0 && !provenance.isEmpty && provenance.utf8.count <= 200
    }
}

/// Body coordinates: +right, +up, +forward; origin at floor below body centre.
/// Not a camera-to-map transform, floor measurement, or body-heading calibration.
public struct ChestMountMetadata: Codable, Equatable, Sendable {
    public var right: Double?
    public var up: Double?
    public var forward: Double?
    public var source: BodyDimensionSource
    public init(right: Double? = nil, up: Double? = nil, forward: Double? = nil,
                source: BodyDimensionSource = .reported) {
        self.right = right; self.up = up; self.forward = forward; self.source = source
    }
    public var valid: Bool {
        [right, up, forward].allSatisfy { $0.map(\.isFinite) ?? true } &&
        (right.map { abs($0) <= 1 } ?? true) && (up.map { (0...2.5).contains($0) } ?? true) &&
        (forward.map { abs($0) <= 1 } ?? true)
    }
    public var complete: Bool { valid && right != nil && up != nil && forward != nil }
}

/// Maximum protrusion beyond the recorded body, including hands, clothing,
/// backpack, carried objects and mobility aid sweep. Nil is unknown, not zero.
/// No sideways squeeze or cane/backpack shape is inferred from these bounds.
public struct BodyEquipmentBounds: Codable, Equatable, Sendable {
    public var radialExtension: Double?
    public var overheadExtension: Double?
    public init(radialExtension: Double? = nil, overheadExtension: Double? = nil) {
        self.radialExtension = radialExtension; self.overheadExtension = overheadExtension
    }
    public var valid: Bool {
        [radialExtension, overheadExtension].allSatisfy { $0.map { $0.isFinite && (0...3).contains($0) } ?? true }
    }
}

public enum BodyProfileError: Error { case invalidInput, invalidDimension, staleRevision, temporalRollback }
public enum BodyPreviewDecision: Equatable, Sendable { case rejected, unknown }

/// Deliberately has no positive clearance result and cannot mint a spatial lease.
public struct BodyEnvelopePreview: Sendable {
    public let envelope: BodyEnvelope?
    public let dimensionSource: BodyDimensionSource
    public let missingEvidence: [String]
    public let profileRevision: UUID
    public let mountRevision: UUID
    public func evaluate(surface: NavigationSurface, from: Point3, to: Point3) -> BodyPreviewDecision {
        guard let envelope, envelope.valid else { return .unknown }
        return surface.permitsLeg(from: from, to: to, body: envelope) ? .unknown : .rejected
    }
}

/// Private per-wearer storage payload only. Never include in map packages, model
/// prompts, telemetry, cloud backup or a different wearer's conversation context.
/// App storage must use protected, backup-excluded local persistence. This type
/// itself does no IO and grants no consent, identity or speech authority.
public struct LocalBodyProfile: Codable, Equatable, Sendable {
    public private(set) var input: BodyProfileInput
    public private(set) var mount: ChestMountMetadata
    public private(set) var equipment: BodyEquipmentBounds
    public private(set) var revision: UUID
    public private(set) var measurementBasisRevision: UUID
    public private(set) var geometryRevision: UUID
    public private(set) var mountRevision: UUID
    public private(set) var dimensions: [BodyDimensions]
    public init(input: BodyProfileInput = .init(), mount: ChestMountMetadata = .init(),
                equipment: BodyEquipmentBounds = .init()) throws {
        guard input.valid, mount.valid, equipment.valid else { throw BodyProfileError.invalidInput }
        self.input = input; self.mount = mount; self.equipment = equipment
        revision = UUID(); measurementBasisRevision = UUID(); geometryRevision = UUID(); mountRevision = UUID(); dimensions = []
    }
    public var valid: Bool {
        input.valid && mount.valid && equipment.valid && dimensions.count <= 3 && dimensions.allSatisfy(\.valid) &&
            Set(dimensions.map(\.source)).count == dimensions.count && dimensions.allSatisfy { $0.profileRevision == measurementBasisRevision }
    }
    /// Growth-relevant inputs retire prior dimension association; explicit remeasurement
    /// is required after growth/weight/mount/equipment changes, even equal envelopes.
    @discardableResult public mutating func update(input: BodyProfileInput, mount: ChestMountMetadata,
                                                   equipment: BodyEquipmentBounds) throws -> Bool {
        guard input.valid, mount.valid, equipment.valid else { throw BodyProfileError.invalidInput }
        guard self.input != input || self.mount != mount || self.equipment != equipment else { return false }
        let geometryChanged = self.input.ageYears != input.ageYears || self.input.weightKilograms != input.weightKilograms ||
            self.input.heightMetres != input.heightMetres || self.mount != mount || self.equipment != equipment
        if self.mount != mount { mountRevision = UUID() }
        self.input = input; self.mount = mount; self.equipment = equipment
        revision = UUID()
        if geometryChanged { geometryRevision = UUID(); measurementBasisRevision = UUID(); dimensions = [] }
        return true
    }
    public mutating func record(_ value: BodyDimensions, replacingGeometryRevision expected: UUID) throws {
        guard value.valid else { throw BodyProfileError.invalidDimension }
        guard value.profileRevision == measurementBasisRevision, expected == geometryRevision else { throw BodyProfileError.staleRevision }
        guard dimensions.allSatisfy({ value.recordedAt >= $0.recordedAt }) else { throw BodyProfileError.temporalRollback }
        // A fresh full measured set supersedes earlier reports/estimates. Later
        // reports remain separate and can expand (never shrink) that known bound.
        if value.source == .measured { dimensions = [] }
        dimensions.removeAll { $0.source == value.source }; dimensions.append(value)
        revision = UUID(); geometryRevision = UUID()
        // Never rewrite retained measurement provenance, timestamp or association.
    }
    public static func decodeLocal(_ data: Data) throws -> LocalBodyProfile {
        guard data.count <= 16_384 else { throw BodyProfileError.invalidInput }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.valid else { throw BodyProfileError.invalidInput }
        return value
    }
    /// Candidate planning must not treat the settings preview's generic defaults
    /// as the wearer's recorded dimensions. Reported/measured full bounds remain
    /// conditional inputs, not validated coverage, pose or clearance evidence.
    /// Preserve all preview gaps and a nil envelope for unsupported/oversized bounds.
    public func recordedBoundsPreview() -> BodyEnvelopePreview? {
        guard valid, dimensions.contains(where: {
            $0.profileRevision == measurementBasisRevision &&
                ($0.source == .reported || $0.source == .measured)
        }) else { return nil }
        return preview()
    }
    public func preview() -> BodyEnvelopePreview {
        var gaps = ["validated full-body and equipment coverage", "current measured chest-to-body transform", "fresh map-aligned pose and floor support"]
        guard valid else { return .init(envelope: nil, dimensionSource: .estimated, missingEvidence: gaps + ["valid profile"], profileRevision: geometryRevision, mountRevision: mountRevision) }
        let current = dimensions.filter { $0.profileRevision == measurementBasisRevision }
        let measured = current.first { $0.source == .measured }
        let reported = current.first { $0.source == .reported }
        let selected = measured ?? reported ?? current.first { $0.source == .estimated }
        // Historical generic dimensions are visualization defaults, NOT population
        // bounds. No age/weight/gender to width equation or anatomy assumption.
        // A later contradictory report conservatively expands retained measured
        // bounds; it does not refresh or relabel the older measurement.
        let active = measured != nil && reported != nil ? [measured!, reported!] : selected.map { [$0] } ?? []
        let height = active.map { $0.height + ($0.uncertainty ?? 0) }.max() ?? input.heightMetres ?? 1.8
        let radius = active.map { hypot($0.width, $0.depth) / 2 + ($0.uncertainty ?? 0) }.max() ?? 0.3
        let source: BodyDimensionSource = active.count > 1 ? .reported : selected?.source ?? .estimated
        if active.count > 1 { gaps.append("new report compared with retained measurement; conservative union") }
        if selected == nil { gaps.append("individual width and depth") }
        if active.isEmpty || active.contains(where: { $0.uncertainty == nil }) { gaps.append("quantified dimension uncertainty") }
        if equipment.radialExtension == nil || equipment.overheadExtension == nil { gaps.append("carried objects, backpack, clothing and cane bounds") }
        if !mount.complete { gaps.append("chest mount offset") }
        let offset = hypot(mount.right ?? 0, mount.forward ?? 0)
        let envelope = BodyEnvelope(radius: radius + (equipment.radialExtension ?? 0) + offset,
            height: height + (equipment.overheadExtension ?? 0), margin: 0.15)
        // Existing planner limits are preserved; oversized/unsupported inputs never
        // get clamped down into an apparently passable shape.
        return .init(envelope: envelope.valid ? envelope : nil, dimensionSource: source,
                     missingEvidence: gaps, profileRevision: geometryRevision, mountRevision: mountRevision)
    }
}
