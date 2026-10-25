import Foundation
struct Room { var visits = 1 }
struct Memory { var rooms: [String: Room] = ["room": Room()] }
struct Companion { var currentRoom: String? = "room"; var memory = Memory(); var released: [String] = []; mutating func release(_ key: String) { released.append(key) } }
struct Session { var generation: UInt64 = 1 }
struct Indoor { var revision = UUID(); var alignmentRevision = UUID() }
enum Outcome { case completed, cancelled, unknown }
final class NativeProjection {
var passiveSceneDelivery = PassiveSceneDelivery()
var companion = Companion(); var assistantSession = Session(); var indoor = Indoor()
var observationFrameID = UUID().uuidString; var perceptionGeneration = UUID(); var preferencesRevision = UUID()
var reached = false
    var passiveSceneOwner: String {
        let room = companion.currentRoom ?? "unknown"
        let visits = companion.memory.rooms[room]?.visits ?? 0
        return [String(assistantSession.generation), observationFrameID, perceptionGeneration.uuidString,
                room, String(visits), indoor.revision.uuidString, indoor.alignmentRevision.uuidString,
                preferencesRevision.uuidString].joined(separator: "|")
    }
func generation(automatic: Bool, passiveOwner: String, passiveSignature: PassiveSceneDelivery.Signature?) {
reached = false
                if automatic {
                    guard self.passiveSceneOwner == passiveOwner, let passiveSignature,
                          self.passiveSceneDelivery.allows(passiveSignature, owner: passiveOwner) else { return }
                }
reached = true
}
func dispatch(automatic: Bool, passiveOwner: String, passiveSignature: PassiveSceneDelivery.Signature?, currentRequest: UUID) {
reached = false
                if automatic {
                    guard self.passiveSceneOwner == passiveOwner, let passiveSignature,
                          self.passiveSceneDelivery.begin(id: currentRequest, signature: passiveSignature,
                                                          owner: passiveOwner) else { return }
                }
reached = true
}
func finished(id: UUID, outcome: Outcome) {
            if self.passiveSceneDelivery.finish(id: id, completed: outcome == .completed,
                                                currentOwner: self.passiveSceneOwner) {
                self.companion.release("passive-scene:" + id.uuidString)
            }
}
func cancel() {
        if let id = passiveSceneDelivery.cancelPending() {
            companion.release("passive-scene:" + id.uuidString)
        }
}
}
let h = NativeProjection()
let evidence = PassiveSceneDelivery.signature(observations: [.init(id: "ocr", kind: .text, text: "Welcome", confidence: 1, capturedAt: 1)], confirmedObjects: [])!
let scope = h.passiveSceneOwner
h.generation(automatic: true, passiveOwner: scope, passiveSignature: nil); precondition(!h.reached)
h.generation(automatic: false, passiveOwner: scope, passiveSignature: nil); precondition(h.reached)
let first = UUID()
h.dispatch(automatic: true, passiveOwner: scope, passiveSignature: evidence, currentRequest: first); precondition(h.reached)
h.finished(id: first, outcome: .cancelled)
h.generation(automatic: true, passiveOwner: scope, passiveSignature: evidence); precondition(h.reached)
let second = UUID()
h.dispatch(automatic: true, passiveOwner: scope, passiveSignature: evidence, currentRequest: second); precondition(h.reached)
h.cancel(); h.finished(id: second, outcome: .completed)
h.generation(automatic: true, passiveOwner: scope, passiveSignature: evidence); precondition(h.reached)
let third = UUID()
h.dispatch(automatic: true, passiveOwner: scope, passiveSignature: evidence, currentRequest: third); precondition(h.reached)
h.finished(id: third, outcome: .completed)
h.generation(automatic: true, passiveOwner: scope, passiveSignature: evidence); precondition(!h.reached)
h.generation(automatic: false, passiveOwner: scope, passiveSignature: evidence); precondition(h.reached)
h.companion.memory.rooms["room"]!.visits += 1
h.generation(automatic: true, passiveOwner: scope, passiveSignature: evidence); precondition(!h.reached)
h.generation(automatic: true, passiveOwner: h.passiveSceneOwner, passiveSignature: evidence); precondition(h.reached)
precondition(h.companion.released.count == 3)
print("Native exact-block projection: 12 lifecycle/admission assertions passed; containers stubbed, no Apple audio execution")
