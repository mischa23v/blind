import Foundation

/// People who agreed to be recognised (family at home, coworkers at work), kept on this phone only.
/// Each record keeps who consented and when; deleting a person removes them and their enrolled data.
/// Recognition is by on-device comparison only, with the same "clearly this person, or honestly
/// unsure" rule as items. Unknown or unenrolled people are only ever described anonymously.
public struct EnrolledPerson: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let relationship: String?
    public let consentedAt: Date
    /// "self" when the person agreed for themselves; "guardian" when a parent agreed for a child.
    public let consentBy: String
    /// Whether to announce this person when they come in or approach.
    public var announce: Bool
    public init(id: String = UUID().uuidString, name: String, relationship: String? = nil,
                consentedAt: Date, consentBy: String, announce: Bool = true) {
        self.id = id; self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.relationship = relationship?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.consentedAt = consentedAt; self.consentBy = consentBy; self.announce = announce
    }
}

public struct PeopleRegistry: Codable, Equatable, Sendable {
    public static let limit = 32
    public private(set) var people: [EnrolledPerson] = []
    public init() {}

    /// Adds a person after consent. Nil for empty/duplicate names, unknown consent source or a full list.
    @discardableResult
    public mutating func enroll(name: String, relationship: String? = nil, consentBy: String, at date: Date = Date()) -> EnrolledPerson? {
        let person = EnrolledPerson(name: name, relationship: relationship, consentedAt: date, consentBy: consentBy)
        guard !person.name.isEmpty, person.name.count <= 60, ["self", "guardian"].contains(consentBy),
              people.count < Self.limit,
              !people.contains(where: { $0.name.caseInsensitiveCompare(person.name) == .orderedSame }) else { return nil }
        people.append(person)
        return person
    }

    @discardableResult
    public mutating func remove(id: String) -> Bool {
        let before = people.count
        people.removeAll { $0.id == id }
        return people.count != before
    }

    public mutating func setAnnounce(_ announce: Bool, id: String) {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        people[index].announce = announce
    }

    public func person(id: String) -> EnrolledPerson? { people.first { $0.id == id } }

    /// Face-embedding distance thresholds; set when the on-device face model is chosen (TASKS V04).
    public static let acceptDistance: Float = 0.40
    public static let similarDistance: Float = 0.55
    public static let margin: Float = 0.10

    /// Who this face is, from distances to each enrolled person's saved faces (keyed by person id).
    public func identify(_ distances: [String: Float]) -> ItemAppearanceMatch.Result {
        let enrolled = distances.filter { id, _ in people.contains { $0.id == id } }
        return ItemAppearanceMatch.decide(enrolled, accept: Self.acceptDistance, similar: Self.similarDistance, margin: Self.margin)
    }

    /// Short calm announcement. An approach is what the camera observed (coming closer), never intent.
    public func announcement(for result: ItemAppearanceMatch.Result, approaching: Bool, arabic: Bool) -> String {
        switch result {
        case .same(let id):
            guard let person = person(id: id), person.announce else { return Self.anonymous(approaching: approaching, arabic: arabic) }
            if arabic { return approaching ? "\(person.name) يقترب." : "\(person.name) هنا." }
            return approaching ? "\(person.name) is coming closer." : "\(person.name) is here."
        case .similar(let id):
            guard let person = person(id: id), person.announce else { return Self.anonymous(approaching: approaching, arabic: arabic) }
            return arabic ? "ربما \(person.name)، لست متأكداً." : "Possibly \(person.name), I'm not sure."
        case .none:
            return Self.anonymous(approaching: approaching, arabic: arabic)
        }
    }

    public static func anonymous(approaching: Bool, arabic: Bool) -> String {
        if arabic { return approaching ? "شخص يقترب." : "شخص دخل." }
        return approaching ? "Someone is coming closer." : "Someone came in."
    }
}
