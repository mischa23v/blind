import Foundation

/// Normalized detector bounds in the caller's documented image convention. No image is retained.
public struct ObservedObjectBox: Codable, Equatable, Sendable {
    public let x, y, width, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var valid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
            width > 0 && height > 0 && x + width <= 1 && y + height <= 1
    }
}

/// An attributed observation, not an assertion of present location or ownership.
public struct ObservedObjectSighting: Codable, Equatable, Identifiable, Sendable {
    /// Only code-owned on-device perception may produce these records. There is no LLM source.
    public enum Source: String, Codable, Sendable {
        case onDeviceDetector
        /// An uncalibrated appearance comparison is a candidate, not verified personal identity.
        case appearanceComparison
        /// Dated furniture/category evidence from a measured RoomPlan scan, never an instance ID.
        case roomPlanScan
        /// Reserved for an independently validated instance matcher, not a category detector.
        case verifiedInstanceMatcher
    }
    public let id: String
    public let category: String
    public let categoryKey: String
    public let source: Source
    /// Exact producer-owned point/object ID for a measurement receipt, not personal identity.
    public let sourceObservationID: String?
    public let observedAt: Date
    public let frameID: String?
    public let roomID: String?
    public let roomName: String?
    /// A known house/building/place, never inferred from the category or coordinates.
    public let placeID: String?
    public let placeName: String?
    public let floorID: String?
    public let floorName: String?
    /// Recorded place markers, not a fabricated "near", "on" or directional relationship.
    public let landmarks: [String]
    public let position: Point3?
    /// Nil means unknown, never zero. Metres in the point's named frame.
    public fileprivate(set) var uncertaintyMetres: Double?
    /// True only after independently validated target-to-measurement association.
    /// The existing detector-box-centre depth sampler must leave this false.
    public let associationValidated: Bool
    /// Independently validated association of this historical observation to its recorded spot.
    /// This is NOT evidence that the object remains there. The centre-depth sampler leaves it false.
    public fileprivate(set) var recordedSpotValidated: Bool
    public let confirmedInstanceID: String?
    public let box: ObservedObjectBox?
    public fileprivate(set) var isActive: Bool
    public fileprivate(set) var geometryValid: Bool
    public fileprivate(set) var recordedSpotGeometryValid: Bool

    fileprivate init(category: String, source: Source, sourceObservationID: String?, frameID: String?, roomID: String?, roomName: String?,
                     placeID: String?, placeName: String?, floorID: String?, floorName: String?, landmarks: [String],
                     position: Point3?, uncertaintyMetres: Double?, associationValidated: Bool,
                     recordedSpotValidated: Bool, confirmedInstanceID: String?, box: ObservedObjectBox?, at: Date, active: Bool) {
        id = UUID().uuidString; self.category = category; categoryKey = ItemMemory.key(for: category)
        self.source = source; self.sourceObservationID = sourceObservationID
        observedAt = at; self.frameID = frameID; self.roomID = roomID
        self.roomName = roomName; self.position = position; self.uncertaintyMetres = uncertaintyMetres
        self.placeID = placeID; self.placeName = placeName; self.floorID = floorID; self.floorName = floorName
        self.landmarks = landmarks; self.recordedSpotValidated = recordedSpotValidated
        self.associationValidated = associationValidated; self.confirmedInstanceID = confirmedInstanceID
        self.box = box; isActive = active; geometryValid = active; recordedSpotGeometryValid = recordedSpotValidated
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, categoryKey, source, sourceObservationID, observedAt, frameID, roomID, roomName, position
        case uncertaintyMetres, associationValidated, confirmedInstanceID, box, isActive, geometryValid
        case placeID, placeName, floorID, floorName, landmarks, recordedSpotValidated, recordedSpotGeometryValid
    }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        id = try v.decode(String.self, forKey: .id)
        category = try v.decode(String.self, forKey: .category)
        categoryKey = try v.decodeIfPresent(String.self, forKey: .categoryKey) ?? ItemMemory.key(for: category)
        source = try v.decode(Source.self, forKey: .source)
        sourceObservationID = try v.decodeIfPresent(String.self, forKey: .sourceObservationID)
        observedAt = try v.decode(Date.self, forKey: .observedAt)
        frameID = try v.decodeIfPresent(String.self, forKey: .frameID)
        roomID = try v.decodeIfPresent(String.self, forKey: .roomID)
        roomName = try v.decodeIfPresent(String.self, forKey: .roomName)
        placeID = try v.decodeIfPresent(String.self, forKey: .placeID)
        placeName = try v.decodeIfPresent(String.self, forKey: .placeName)
        floorID = try v.decodeIfPresent(String.self, forKey: .floorID)
        floorName = try v.decodeIfPresent(String.self, forKey: .floorName)
        landmarks = try v.decodeIfPresent([String].self, forKey: .landmarks) ?? []
        position = try v.decodeIfPresent(Point3.self, forKey: .position)
        uncertaintyMetres = try v.decodeIfPresent(Double.self, forKey: .uncertaintyMetres)
        associationValidated = try v.decodeIfPresent(Bool.self, forKey: .associationValidated) ?? false
        recordedSpotValidated = try v.decodeIfPresent(Bool.self, forKey: .recordedSpotValidated) ?? false
        confirmedInstanceID = try v.decodeIfPresent(String.self, forKey: .confirmedInstanceID)
        box = try v.decodeIfPresent(ObservedObjectBox.self, forKey: .box)
        // Persisted wall dates never restore a live tracking lease after a restart.
        isActive = false; geometryValid = false; recordedSpotGeometryValid = false
        guard ObservedObjectMemory.isValid(self) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                   debugDescription: "Invalid observed-object sighting"))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var v = encoder.container(keyedBy: CodingKeys.self)
        try v.encode(id, forKey: .id); try v.encode(category, forKey: .category)
        try v.encode(categoryKey, forKey: .categoryKey); try v.encode(source, forKey: .source)
        try v.encodeIfPresent(sourceObservationID, forKey: .sourceObservationID)
        try v.encode(observedAt, forKey: .observedAt)
        try v.encodeIfPresent(frameID, forKey: .frameID)
        try v.encodeIfPresent(roomID, forKey: .roomID); try v.encodeIfPresent(roomName, forKey: .roomName)
        try v.encodeIfPresent(placeID, forKey: .placeID); try v.encodeIfPresent(placeName, forKey: .placeName)
        try v.encodeIfPresent(floorID, forKey: .floorID); try v.encodeIfPresent(floorName, forKey: .floorName)
        try v.encode(landmarks, forKey: .landmarks)
        try v.encodeIfPresent(position, forKey: .position); try v.encodeIfPresent(uncertaintyMetres, forKey: .uncertaintyMetres)
        try v.encode(associationValidated, forKey: .associationValidated)
        try v.encode(recordedSpotValidated, forKey: .recordedSpotValidated)
        try v.encodeIfPresent(confirmedInstanceID, forKey: .confirmedInstanceID); try v.encodeIfPresent(box, forKey: .box)
        // Live leases and frame-validity flags are never persisted, even as false-valued metadata.
    }
}

/// A fresh pose and a separately established body heading in the sighting's coordinate frame.
public struct ObservedObjectRecallContext: Equatable, Sendable {
    public let frameID: String
    public let position: Point3
    public let bodyHeading: BodyHeading
    public let capturedAt: Date
    public let uncertaintyMetres: Double
    /// Fresh receipt from a validated alignment adapter. Never inferred merely from equal frame IDs.
    public let recordedFrameAlignmentValidated: Bool
    public let placeID: String?
    public let floorID: String?
    public let allowedRecordedPointIDs: Set<String>
    public let headingUncertaintyDegrees: Double
    public init(frameID: String, position: Point3, bodyHeading: BodyHeading,
                capturedAt: Date, uncertaintyMetres: Double, recordedFrameAlignmentValidated: Bool = false,
                placeID: String? = nil, floorID: String? = nil, allowedRecordedPointIDs: Set<String> = [],
                headingUncertaintyDegrees: Double = .infinity) {
        self.frameID = frameID; self.position = position; self.bodyHeading = bodyHeading
        self.capturedAt = capturedAt; self.uncertaintyMetres = uncertaintyMetres
        self.recordedFrameAlignmentValidated = recordedFrameAlignmentValidated
        self.placeID = placeID; self.floorID = floorID
        self.allowedRecordedPointIDs = allowedRecordedPointIDs; self.headingUncertaintyDegrees = headingUncertaintyDegrees
    }
}

/// A relation to an earlier measured spot, not the object's present location, a route, or reachability.
/// It has no pickup, handling, clearance or movement-command authority.
public struct ObservedObjectRecordedSpotOrientation: Equatable, Sendable {
    public let sightingID: String
    public let observedAt: Date
    public let frameID: String
    public let relation: SpatialRelation
}

public struct ObservedObjectRecall: Equatable, Sendable {
    public enum Status: String, Sendable { case notFound, history, currentCandidate, ambiguous }
    public let status: Status
    /// Newest first. Ambiguity means alternative observations, not a confirmed object count.
    public let sightings: [ObservedObjectSighting]
    /// Orientation to a recent measured observation only. Never reach, pickup or clearance authority.
    public let relation: SpatialRelation?
    public let recordedSpotOrientation: ObservedObjectRecordedSpotOrientation?
    fileprivate let context: ObservedObjectRecallContext?
}

/// A bounded domain payload for the existing app-private GRDB store, not a database or recognizer.
/// Callers supply capture dates (not completion dates) and unique AR session/map-revision frame IDs.
/// All observations remain private on the phone. Eviction reserves a bounded share for dated scans
/// so continuous transient detections do not erase furniture history. This does not confer authority.
/// Re-query immediately before delivery and after frame/reset events; a recall is only a snapshot.
public struct ObservedObjectMemory: Codable, Equatable, Sendable {
    public static let limit = 256
    public static let roomPlanReservation = 64
    public static let maximumEncodedBytes = 256 * 1024
    public static let schemaVersion = 2
    public static let activeLifetime: TimeInterval = 8
    public static let geometryLifetime: TimeInterval = 0.5
    public static let maximumUncertaintyMetres = 0.25
    /// A bounded duplicate-observation-site tolerance, NOT an identity matcher or calibrated accuracy.
    public static let repeatedSiteToleranceMetres = 0.25
    public private(set) var sightings: [ObservedObjectSighting] = []
    public init() {}

    private enum CodingKeys: String, CodingKey { case schemaVersion, sightings }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        let version = try v.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        guard (0...Self.schemaVersion).contains(version) else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: v,
                                                   debugDescription: "Unsupported observed-object schema")
        }
        if v.contains(.sightings) {
            var records = try v.nestedUnkeyedContainer(forKey: .sightings)
            while !records.isAtEnd {
                guard sightings.count < Self.limit else {
                    throw DecodingError.dataCorruptedError(in: records, debugDescription: "Sighting limit exceeded")
                }
                sightings.append(try records.decode(ObservedObjectSighting.self))
            }
        }
        guard valid else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                   debugDescription: "Invalid observed-object cache"))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var v = encoder.container(keyedBy: CodingKeys.self)
        try v.encode(Self.schemaVersion, forKey: .schemaVersion)
        try v.encode(sightings, forKey: .sightings)
    }

    /// Multiple detections from one capture must use the same `at` date. Different labels/positions
    /// are never silently assigned an instance ID. The wall-clock `now` is used to reject the future.
    @discardableResult
    public mutating func observe(category: String, source: ObservedObjectSighting.Source,
                                 sourceObservationID: String? = nil,
                                 frameID: String?, roomID: String? = nil, roomName: String? = nil,
                                 placeID: String? = nil, placeName: String? = nil, floorID: String? = nil,
                                 floorName: String? = nil, landmarks: [String] = [],
                                 position: Point3? = nil, uncertaintyMetres: Double? = nil,
                                 associationValidated: Bool = false, recordedSpotValidated: Bool = false,
                                 confirmedInstanceID: String? = nil,
                                 box: ObservedObjectBox? = nil, at: Date, now: Date) -> ObservedObjectSighting? {
        guard Self.dateValid(now), Self.dateValid(at), at <= now else { return nil }
        let item = ObservedObjectSighting(category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source, sourceObservationID: ItemMemory.clean(sourceObservationID),
            frameID: ItemMemory.clean(frameID), roomID: ItemMemory.clean(roomID),
            roomName: ItemMemory.clean(roomName), placeID: ItemMemory.clean(placeID), placeName: ItemMemory.clean(placeName),
            floorID: ItemMemory.clean(floorID), floorName: ItemMemory.clean(floorName),
            landmarks: landmarks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            position: position, uncertaintyMetres: uncertaintyMetres,
            associationValidated: associationValidated, recordedSpotValidated: recordedSpotValidated,
            confirmedInstanceID: ItemMemory.clean(confirmedInstanceID),
            box: box, at: at, active: now.timeIntervalSince(at) <= Self.activeLifetime)
        guard Self.isValid(item) else { return nil }
        expire(at: now)
        sightings.append(item)
        sightings.sort { $0.observedAt < $1.observedAt }
        evictToBounds()
        return sightings.first { $0.id == item.id }
    }

    /// Prefer retaining the newest 64 scan records without merging any observed entities. The byte
    /// limit is absolute: if only reserved records remain and still exceed it, oldest scans yield too.
    private mutating func evictToBounds() {
        let reserved = Set(sightings.reversed().filter { $0.source == .roomPlanScan }
            .prefix(Self.roomPlanReservation).map(\.id))
        while !sightings.isEmpty && (sightings.count > Self.limit || !withinPayloadBudget) {
            let index = sightings.firstIndex { !reserved.contains($0.id) } ?? 0
            sightings.remove(at: index)
        }
    }

    /// Irreversible expiry of live eligibility. A clock rollback cannot resurrect an expired lease.
    public mutating func expire(at now: Date) {
        for index in sightings.indices {
            let age = now.timeIntervalSince(sightings[index].observedAt)
            if !Self.dateValid(now) || !age.isFinite || age < 0 || age > Self.activeLifetime {
                sightings[index].isActive = false; sightings[index].geometryValid = false
            }
        }
    }

    /// Use on tracking/map/session reset, relocalization failure or app restart. History survives.
    public mutating func invalidateGeometry() {
        for index in sightings.indices {
            sightings[index].isActive = false; sightings[index].geometryValid = false
            sightings[index].recordedSpotGeometryValid = false
        }
    }
    /// Called only after re-reading the exact saved scan and checking its validated measurement
    /// receipt. Equal category/proximity alone cannot upgrade a record. Never creates identity/live geometry.
    @discardableResult
    public mutating func applyRecordedPointValidation(frameID: String, sourceObservationID: String,
                                                      position: Point3, uncertaintyMetres: Double) -> Bool {
        guard Self.fieldValid(frameID), Self.fieldValid(sourceObservationID), position.isFinite,
              [position.x, position.y, position.z].allSatisfy({ abs($0) <= 1_000_000 }),
              uncertaintyMetres.isFinite, (0...Self.maximumUncertaintyMetres).contains(uncertaintyMetres) else { return false }
        var candidate = self, updated = false
        for index in candidate.sightings.indices where candidate.sightings[index].source == .roomPlanScan &&
            candidate.sightings[index].frameID == frameID && candidate.sightings[index].sourceObservationID == sourceObservationID &&
            candidate.sightings[index].position == position {
            candidate.sightings[index].recordedSpotValidated = true
            candidate.sightings[index].uncertaintyMetres = uncertaintyMetres
            candidate.sightings[index].recordedSpotGeometryValid = false
            candidate.sightings[index].isActive = false; candidate.sightings[index].geometryValid = false
            updated = true
        }
        guard updated, candidate.valid else { return false }
        self = candidate
        return true
    }
    /// After reset/reload, only an explicit fresh validated alignment receipt can restore historical
    /// spot geometry. This never restores live object eligibility or validates an unverified spot.
    @discardableResult
    public mutating func revalidateRecordedFrame(using context: ObservedObjectRecallContext, at now: Date) -> Bool {
        guard context.recordedFrameAlignmentValidated, Self.contextValid(context, at: now) else { return false }
        var restored = false
        for index in sightings.indices where sightings[index].frameID == context.frameID {
            let item = sightings[index]
            if item.recordedSpotValidated && item.observedAt <= now && Self.scopeAgrees(item, context),
               let pointID = item.sourceObservationID, context.allowedRecordedPointIDs.contains(pointID) {
                sightings[index].recordedSpotGeometryValid = true; restored = true
            }
        }
        return restored
    }
    @discardableResult public mutating func forget(category: String) -> Bool {
        let count = sightings.count, key = ItemMemory.key(for: category)
        sightings.removeAll { $0.categoryKey == key }; return sightings.count != count
    }
    @discardableResult public mutating func forgetRoom(_ roomID: String) -> Bool {
        let count = sightings.count
        sightings.removeAll { $0.roomID == roomID }; return sightings.count != count
    }
    public mutating func clear() { sightings.removeAll() }

    public func recall(category: String, confirmedInstanceID: String? = nil,
                       placeID: String? = nil, placeName: String? = nil, floorID: String? = nil, floorName: String? = nil,
                       roomID: String? = nil, roomName: String? = nil, landmarks: [String] = [], at now: Date,
                       context: ObservedObjectRecallContext? = nil) -> ObservedObjectRecall {
        let key = ItemMemory.key(for: category)
        let records = Self.dateValid(now) ? sightings.filter { sighting in
            sighting.categoryKey == key && sighting.observedAt <= now &&
                (confirmedInstanceID == nil || sighting.confirmedInstanceID == confirmedInstanceID) &&
                (placeID == nil || sighting.placeID == placeID) && (floorID == nil || sighting.floorID == floorID) &&
                (roomID == nil || sighting.roomID == roomID) && Self.nameMatches(placeName, sighting.placeName) &&
                Self.nameMatches(floorName, sighting.floorName) && Self.nameMatches(roomName, sighting.roomName) &&
                landmarks.allSatisfy { wanted in sighting.landmarks.contains { ItemMemory.key(for: $0) == ItemMemory.key(for: wanted) } }
        }.sorted { $0.observedAt > $1.observedAt } : []
        let selected = Self.representativeObservations(records)
        let status: ObservedObjectRecall.Status
        if selected.isEmpty { status = .notFound }
        else if selected.count > 1 { status = .ambiguous }
        else if selected[0].isActive && now.timeIntervalSince(selected[0].observedAt) <= Self.activeLifetime {
            status = .currentCandidate
        } else { status = .history }
        let relation = status == .currentCandidate ? Self.orientation(for: selected[0], context: context, now: now) : nil
        let recorded = selected.count == 1 ? Self.recordedOrientation(for: selected[0], context: context, now: now) : nil
        return ObservedObjectRecall(status: status, sightings: selected, relation: relation,
                                    recordedSpotOrientation: recorded, context: context)
    }

    public var valid: Bool {
        sightings.count <= Self.limit && Set(sightings.map(\.id)).count == sightings.count &&
            sightings.allSatisfy(Self.isValid) && withinPayloadBudget
    }
    private var withinPayloadBudget: Bool {
        guard let bytes = try? JSONEncoder().encode(self) else { return false }
        return bytes.count <= Self.maximumEncodedBytes
    }

    /// Category labels remain categories in both languages, including an appearance-match candidate.
    /// This renderer provides no movement, handling, pickup or clearance commands.
    public static func answer(for recall: ObservedObjectRecall, asked: String, now: Date, arabic: Bool) -> String {
        guard dateValid(now), let last = recall.sightings.first, last.observedAt <= now else {
            return arabic ? "ليس لدي رصد محفوظ لهذه الفئة. هذا لا يعني أنها غير موجودة."
                : "I have no saved observation of that category. That does not mean it is absent."
        }
        let label = ItemMemory.displayName(last.category, arabic: arabic)
        let time = ItemMemory.relativeTime(from: last.observedAt, to: now, arabic: arabic)
        var text: String
        if last.source == .appearanceComparison {
            text = arabic ? "رصدت ما يشبه \(label)" : "I last noticed a possible match for \(label)"
        } else if last.source == .roomPlanScan {
            text = arabic ? "سجّل مسح الغرفة \(label)" : "The room scan recorded \(categoryPhrase(label))"
        } else {
            text = arabic ? "رصدت \(label) آخر مرة" : "I last noticed \(categoryPhrase(label))"
        }
        if let room = last.roomName { text += arabic ? " في \(room)" : " in \(ItemMemory.roomPhrase(room))" }
        for name in [last.floorName, last.placeName].compactMap({ $0 }) {
            text += arabic ? "، \(name)" : ", \(name)"
        }
        text += " \(time)."
        if recall.status == .ambiguous {
            let places = Set(recall.sightings.compactMap { $0.placeID ?? $0.placeName })
            let floors = Set(recall.sightings.compactMap { $0.floorID ?? $0.floorName })
            let question = places.count > 1 ? (arabic ? "أي بيت أو مكان تقصد؟" : "Which house or place?")
                : floors.count > 1 ? (arabic ? "أي طابق تقصد؟" : "Which floor?")
                : (arabic ? "أي غرفة تقصد؟" : "Which room?")
            text += " " + (arabic ? "لدي أرصاد محتملة أخرى. " : "I have other possible sightings. ") + question
        } else if let relation = orientation(for: last, context: recall.context, now: now),
                  recall.status == .currentCandidate {
            text += " " + SpatialFacts.phrase(label: arabic ? "نقطة الرصد المقاسة" : "Measured observation point",
                                               relation: relation, arabic: arabic, inView: nil)
        }
        if recall.status != .ambiguous {
            text += arabic ? " مكانه الآن غير مؤكد." : " Its current location is unconfirmed."
        }
        return text
    }

    /// Separate opt-in wording for the recorded spot. A normal recall never substitutes this for
    /// current-object direction. Rechecks freshness at delivery; caller also re-queries after reset.
    public static func recordedSpotAnswer(for recall: ObservedObjectRecall, now: Date, arabic: Bool) -> String? {
        guard recall.sightings.count == 1, let item = recall.sightings.first,
              let orientation = recordedOrientation(for: item, context: recall.context, now: now) else { return nil }
        let phrase = SpatialFacts.phrase(label: arabic ? "نقطة الرصد السابقة" : "Earlier recorded spot",
                                        relation: orientation.relation, arabic: arabic, inView: nil)
        return phrase + (arabic ? " هذا لا يؤكد وجود الغرض الآن أو خلو الطريق."
            : " This does not confirm the object is there now or that the route is clear.")
    }

    private static func nameMatches(_ requested: String?, _ stored: String?) -> Bool {
        guard let requested else { return true }
        let key = ItemMemory.key(for: requested)
        return !key.isEmpty && stored.map { ItemMemory.key(for: $0) == key } == true
    }
    private static func categoryPhrase(_ label: String) -> String {
        let lower = label.lowercased()
        if ["a ", "an ", "the "].contains(where: lower.hasPrefix) || (lower.hasSuffix("s") && !lower.hasSuffix("ss")) {
            return label
        }
        return (lower.first.map { "aeiou".contains($0) } == true ? "an " : "a ") + label
    }

    // Keep each detection in the newest capture batch. Older evidence at a distinct room/frame/site
    // remains an alternative. Repeated observations at one site are not asserted to be one object.
    // Only a supplied verified instance ID supersedes its earlier location when the object moves.
    private static func representativeObservations(_ records: [ObservedObjectSighting]) -> [ObservedObjectSighting] {
        var selected: [ObservedObjectSighting] = []
        for record in records {
            if let identity = record.confirmedInstanceID {
                if selected.contains(where: { $0.confirmedInstanceID == identity && $0.observedAt > record.observedAt }) { continue }
            } else {
                let newer = selected.filter {
                    $0.confirmedInstanceID == nil && sameRecordedPlace($0, record) && $0.observedAt > record.observedAt
                }
                if newer.contains(where: { repeatedObservationSite(record, $0) }) {
                    // One later detection does not show that another simultaneous candidate left.
                    // Preserve the largest observed same-batch multiplicity without claiming identity.
                    let inSamePlace: (ObservedObjectSighting) -> Bool = {
                        $0.confirmedInstanceID == nil && sameRecordedPlace($0, record) && repeatedObservationSite(record, $0)
                    }
                    let batchCount = records.filter { inSamePlace($0) && $0.observedAt == record.observedAt }.count
                    if selected.filter(inSamePlace).count >= batchCount { continue }
                }
            }
            selected.append(record)
        }
        return selected
    }
    private static func sameRecordedPlace(_ a: ObservedObjectSighting, _ b: ObservedObjectSighting) -> Bool {
        a.frameID == b.frameID && a.roomID == b.roomID && a.roomName == b.roomName &&
            a.placeID == b.placeID && a.placeName == b.placeName && a.floorID == b.floorID && a.floorName == b.floorName
    }
    private static func repeatedObservationSite(_ a: ObservedObjectSighting, _ b: ObservedObjectSighting) -> Bool {
        switch (a.position, b.position) {
        case (nil, nil): return true // newest category capture, not an instance match
        case (.some(let a), .some(let b)): return a.distance(to: b) <= repeatedSiteToleranceMetres
        default: return false // unknown versus measured sites must not be assumed to agree
        }
    }
    private static func orientation(for item: ObservedObjectSighting, context: ObservedObjectRecallContext?, now: Date) -> SpatialRelation? {
        guard item.isActive, item.geometryValid, item.associationValidated, let point = item.position,
              let uncertainty = item.uncertaintyMetres, uncertainty <= maximumUncertaintyMetres,
              let context, context.frameID == item.frameID, dateValid(now), dateValid(context.capturedAt),
              (0...geometryLifetime).contains(now.timeIntervalSince(item.observedAt)),
              (0...geometryLifetime).contains(now.timeIntervalSince(context.capturedAt)),
              context.position.isFinite, context.uncertaintyMetres.isFinite,
              (0...maximumUncertaintyMetres).contains(context.uncertaintyMetres),
              context.bodyHeading.isKnown, context.bodyHeading.confidence.isFinite,
              (0.8...1).contains(context.bodyHeading.confidence),
              context.bodyHeading.age.isFinite, context.bodyHeading.age >= 0,
              (0...geometryLifetime).contains(context.bodyHeading.age + now.timeIntervalSince(context.capturedAt)),
              let relation = SpatialFacts.relation(from: context.position, facing: context.bodyHeading.forward, to: point),
              relation.distance > 2 * (uncertainty + context.uncertaintyMetres),
              relation.distance <= SpatialFacts.cameraDepthRange.upperBound else { return nil }
        return relation
    }
    private static func recordedOrientation(for item: ObservedObjectSighting, context: ObservedObjectRecallContext?,
                                            now: Date) -> ObservedObjectRecordedSpotOrientation? {
        guard item.recordedSpotValidated, item.recordedSpotGeometryValid, item.observedAt <= now,
              let point = item.position, let frameID = item.frameID, let pointID = item.sourceObservationID,
              let uncertainty = item.uncertaintyMetres, (0...maximumUncertaintyMetres).contains(uncertainty),
              let context, context.recordedFrameAlignmentValidated, context.frameID == frameID,
              context.allowedRecordedPointIDs.contains(pointID), contextValid(context, at: now), scopeAgrees(item, context),
              context.headingUncertaintyDegrees.isFinite, (0...10).contains(context.headingUncertaintyDegrees),
              abs(point.y - context.position.y) <= 0.5,
              let relation = SpatialFacts.relation(from: context.position, facing: context.bodyHeading.forward, to: point),
              relation.distance > 1, relation.distance <= SpatialFacts.cameraDepthRange.upperBound else { return nil }
        let combinedPositionError = uncertainty + context.uncertaintyMetres
        guard combinedPositionError <= maximumUncertaintyMetres, relation.distance > combinedPositionError else { return nil }
        // Tangency to the uncertainty disk gives asin(U / d), not atan2(U, d).
        let positionalAngle = asin(combinedPositionError / relation.distance) * 180 / .pi
        let angularError = positionalAngle + context.headingUncertaintyDegrees
        func wrap(_ degrees: Double) -> Double {
            let radians = degrees * .pi / 180
            return atan2(sin(radians), cos(radians)) * 180 / .pi
        }
        // Never pick a sector if the full uncertainty interval could place the spot in another one.
        guard SpatialFacts.sector(angleDegrees: wrap(relation.angleDegrees - angularError)) == relation.sector,
              SpatialFacts.sector(angleDegrees: wrap(relation.angleDegrees + angularError)) == relation.sector else { return nil }
        return ObservedObjectRecordedSpotOrientation(sightingID: item.id, observedAt: item.observedAt,
                                                     frameID: frameID, relation: relation)
    }
    private static func contextValid(_ context: ObservedObjectRecallContext, at now: Date) -> Bool {
        dateValid(now) && dateValid(context.capturedAt) && fieldValid(context.frameID) &&
            (0...geometryLifetime).contains(now.timeIntervalSince(context.capturedAt)) && context.position.isFinite &&
            [context.position.x, context.position.y, context.position.z].allSatisfy { abs($0) <= 1_000_000 } &&
            context.uncertaintyMetres.isFinite && (0...maximumUncertaintyMetres).contains(context.uncertaintyMetres) &&
            context.bodyHeading.isKnown && context.bodyHeading.forward.isFinite &&
            hypot(context.bodyHeading.forward.x, context.bodyHeading.forward.z) > 1e-9 &&
            context.bodyHeading.confidence.isFinite && (0.8...1).contains(context.bodyHeading.confidence) &&
            context.bodyHeading.age.isFinite && context.bodyHeading.age >= 0 &&
            (0...geometryLifetime).contains(context.bodyHeading.age + now.timeIntervalSince(context.capturedAt)) &&
            context.allowedRecordedPointIDs.count <= limit && context.allowedRecordedPointIDs.allSatisfy { fieldValid($0) }
    }
    private static func scopeAgrees(_ item: ObservedObjectSighting, _ context: ObservedObjectRecallContext) -> Bool {
        (item.placeID == nil || item.placeID == context.placeID) && (item.floorID == nil || item.floorID == context.floorID)
    }
    fileprivate static func isValid(_ item: ObservedObjectSighting) -> Bool {
        guard fieldValid(item.id, limit: 64), fieldValid(item.category, limit: 80),
              !item.categoryKey.isEmpty, item.categoryKey == ItemMemory.key(for: item.category),
              dateValid(item.observedAt), fieldValid(item.frameID), fieldValid(item.roomID), fieldValid(item.roomName),
              fieldValid(item.sourceObservationID), fieldValid(item.placeID), fieldValid(item.placeName),
              fieldValid(item.floorID), fieldValid(item.floorName), item.landmarks.count <= 8,
              item.landmarks.allSatisfy({ fieldValid($0, limit: 80) }),
              Set(item.landmarks.map { ItemMemory.key(for: $0) }).count == item.landmarks.count,
              fieldValid(item.confirmedInstanceID), item.box?.valid ?? true else { return false }
        if let point = item.position,
           !point.isFinite || item.frameID == nil || [point.x, point.y, point.z].contains(where: { abs($0) > 1_000_000 }) { return false }
        if let uncertainty = item.uncertaintyMetres, !uncertainty.isFinite || uncertainty < 0 || uncertainty > 100 { return false }
        if item.associationValidated && (item.position == nil || item.uncertaintyMetres == nil) { return false }
        if item.recordedSpotValidated && (item.position == nil || item.uncertaintyMetres == nil || item.sourceObservationID == nil) { return false }
        if item.confirmedInstanceID != nil && item.source != .verifiedInstanceMatcher { return false }
        return true
    }
    private static func fieldValid(_ value: String?, limit: Int = 128) -> Bool {
        guard let value else { return true }
        return !value.isEmpty && value.count <= limit && value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
    private static func dateValid(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        // Also bounds integer relative-time rendering; unbounded finite Double dates can overflow it.
        return seconds.isFinite && (0...253_402_300_799).contains(seconds)
    }
}
