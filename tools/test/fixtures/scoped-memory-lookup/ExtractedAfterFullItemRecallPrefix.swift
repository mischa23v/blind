import Foundation
import BlindCore
final class ExtractedAfterFullItemRecall {
 var companionWorkingState = CompanionWorkingState()
 var items = ItemMemory()
 var arabic = false
 var itemMemoryRevision = UUID(), requestID = UUID()
 var outputs: [String] = []
 struct Room { var name: String? }
 struct Memory { var rooms: [String:Room] = [:] }
 struct Companion { var currentRoom: String?; var memory = Memory() }; var companion = Companion()

 func verifyHeldItem(_ name: String) -> Bool { false }
 func learnItem(_ name: String) {}
 func persistItems() {}
 func say(_ text: String) { outputs.append(text) }

 func forgetItem(_ item: RememberedItem, completion: (Bool)->Void) { completion(false) }
 func locate(_ target: String, question: String) -> Bool { false }
 func run(_ question: String) -> Bool { handleItemOrLocate(question) }

 struct Frame {}
 struct Session { var currentFrame: Frame? }; var session = Session()
 struct Observation { var camera = Point3(0,0,0) }; var lastObservation: Observation?
 struct ExitRoom { var kind: String; var name: String }
 struct Package { var rooms: [ExitRoom] = [] }
 struct Map {}
 struct IndoorNavigator { static func matches(map: Map, package: Package) -> Bool { false } }
 struct FullIndoor {
  var alignmentRevision = UUID(), isAligned = false
  var activePackage: Package?, map: Map?
  func mapPosition(camera: Point3) -> Point3? { nil }
  func mapDirection(_ direction: Point3) -> Point3? { nil }
 }; var indoor = FullIndoor()
 struct Held { func cancel() {} }; let heldSearchIntent = Held()
 struct Appearance { func viewCount(_ name: String) -> Int { 1 } }; let itemAppearance = Appearance()
 var observedObjects = ObservedObjectMemory(), objectSearch: ObjectSearch?
 var recordedSpotSpeech: (UUID, Observation, String, String, String, String)?
 var appearanceCalls = 0
 static let objectInteractionGuidanceValidated = false
 func recordedSpotRecallContext() -> ObservedObjectRecallContext? { nil }
 func captureObjectView(_ frame: Frame) -> Int? { 1 }
 func currentBodyForward() -> Point3? { nil }
 func speakRequested(_ text: String, speechID: UUID) -> Bool { outputs.append(text); return true }
 func continueSearch() {}
 func findItemByLook(_ item: RememberedItem, name: String, frame: Frame) { appearanceCalls += 1 }
 var message = "", sceneAnswer = "", currentReply = ""
 var requestOwner = UUID()
 struct HistoricalSession { var generation: UInt64 = 1 }; var assistantSession = HistoricalSession()
 func interruptOrdinaryConversation(origin: CompanionCommandOrigin) {}
 func queueConversationSpeech(_ text: String, request: UUID, generation: UInt64, codeOwned: Bool) { outputs.append(text) }
 static func wordCount(_ text: String) -> Int { CompanionReferenceReading.wordCount(text) }
 func speakRequested(_ text: String) -> Bool { outputs.append(text); return true }
