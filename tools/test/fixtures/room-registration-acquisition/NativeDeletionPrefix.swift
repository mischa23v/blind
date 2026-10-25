// Authored asynchronous purge and irrelevant controller seams; deletePlace is exact source.
import Foundation
import BlindCore
final class HeldNativePurge {
 var completion: ((Bool)->Void)?
 func clearHistory(memory: MemoryStore?, completion: @escaping (Bool)->Void) { self.completion=completion }
}
final class NativeDeletionController {
 let places: ExtractedRegistrationIngress
 let nativeObservations=HeldNativePurge()
 var recognizedPlace: SavedPlace?, awaitingPlace: SavedPlace?
 var arabic=false, placeRecoveryQuestion="", said=""
 struct Recovery { mutating func reset() {} };var placeRecovery=Recovery()
 init(_ places:ExtractedRegistrationIngress) { self.places=places }
 func retireHeldSearchForPrivacyDeletion() {}
 func purgeDebugSessionDiagnostics() {}
 func invalidatePerceptionWork() {}
 func invalidateAutomaticRoomClues() {}
 func invalidateRecognizedRoom() {}
 func say(_ value:String) { said=value }
 func deletePlaceAfterNativePurge(_ place:SavedPlace) { places.delete(place) }
