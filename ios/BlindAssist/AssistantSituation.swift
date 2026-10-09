import Foundation
import BlindCore
import BlindMemory

enum AssistantSituation {
    /// Preparation time cannot freeze evidence ages. Expired pose is removed before
    /// either provider sees it; catalogue/map data may remain as historical context.
    static func aged(_ snapshot: [String: Any], milliseconds: Double) -> [String: Any] {
        var result = snapshot
        guard milliseconds.isFinite, milliseconds >= 0 else {
            result["location"] = IndoorSituation.unknownLocation; result["visualTracks"] = []; result.removeValue(forKey: "arrival")
            return result
        }
        if var location = result["location"] as? [String: Any], location["state"] as? String != "unknown" {
            let age = (location["ageMS"] as? Double ?? 0) + milliseconds
            if age > 500 { result["location"] = IndoorSituation.unknownLocation; result.removeValue(forKey: "arrival") }
            else { location["ageMS"] = age; result["location"] = location }
        }
        if let tracks = result["visualTracks"] as? [[String: Any]] {
            result["visualTracks"] = tracks.compactMap { item -> [String: Any]? in
                var item = item; let age = (item["ageMS"] as? Double ?? 0) + milliseconds
                guard age <= 1500 else { return nil }; item["ageMS"] = age; return item
            }
        }
        return result
    }
    /// Until floor/frame alignment is supplied, no saved room is asserted as current.
    /// Only the explicitly selected preview is shared, never the entire private catalogue.
    static func snapshot(dialogue: AssistantDialogue, preview: SavedPlace?, layout: RoomLayout?, preferences: AssistantPreferences = AssistantPreferences(), narration: [NarrationRecord] = [], navigation: IndoorSituation? = nil, arabic: Bool = false) -> [String: Any] {
        let unknown = NSNull()
        var places: [[String: Any]] = []
        var entities: [[String: Any]] = []
        var notes: [[String: Any]] = []
        if navigation == nil, let preview, let layout, let revision = layout.revisionID {
            places = [["id": preview.id.uuidString, "name": String(preview.name.prefix(300)), "kind": "room", "parentID": unknown, "sourceID": revision]]
            // Mapped inventory is historical; these records are not current occupancy or clearance.
            entities = layout.features.filter { $0.kind != "wall" }.prefix(32).map {
                ["id": String($0.id.prefix(64)), "category": $0.kind == "furniture" ? "furniture" : "landmark",
                 "description": String(($0.label ?? $0.category).prefix(300)), "placeID": preview.id.uuidString,
                 "state": "mapped", "ageMS": max(0, Date().timeIntervalSince(preview.createdAt) * 1000), "sourceID": revision]
            }
            if let description = (arabic ? layout.descriptionArabic : layout.descriptionEnglish),
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notes = [["placeID": preview.id.uuidString, "text": description, "sourceID": revision, "state": "mapped"]]
            }
        }
        return ["version": 1, "snapshotID": UUID().uuidString, "coverage": "partial",
            "location": navigation?.location ?? IndoorSituation.unknownLocation,
            "places": navigation?.places ?? places, "connections": navigation?.connections ?? [],
            "entities": navigation?.entities ?? entities, "mapNotes": navigation?.mapNotes ?? notes,
            "goal": ["description": dialogue.goal.isEmpty ? "Answer the current question" : dialogue.goal, "targetPlaceID": unknown, "focusEntityID": unknown],
            "preferences": preferences.interests.map { ["category": $0.category, "value": $0.value, "source": $0.source] },
            "categoryModes": Dictionary(uniqueKeysWithValues: AssistantPreferences.categories.map { ($0, preferences.mode(for: $0)) }),
            "deliveredFactIDs": [], "returnPlaceID": unknown,
            "narration": narration.prefix(4).map { record -> [String: Any] in
                let age = Date().timeIntervalSince(record.created) * 1000
                return ["id": record.id, "snapshotID": record.snapshotID, "sourceIDs": record.sourceIDs,
                        "text": record.text, "outcome": record.outcome, "ageMS": age.isFinite && age >= 0 ? age as Any : unknown]
            },
            "conversation": ["goalRevision": dialogue.goalRevision, "turns": dialogue.turns.map { ["role": $0.role, "text": $0.text] }]]
    }
}
