// Authored platform/storage seams. Both native deletion methods are extracted at execution.
// ItemMemory and RememberedItem are the real public BlindCore types, not fixture replacements.
import Foundation
import BlindCore
@MainActor final class ExtractedSavedItemDeletionController {
 enum MemoryError: Error { case missing }
 final class Store {
  private(set) var writes = 0
  private(set) var payload: Data?
  func saveValue(namespace: String, id: String, payload: Data) throws {
   precondition(namespace == "items" && id == "all")
   writes += 1; self.payload = payload
  }
 }
 struct Places { var memory: Store? = Store() }
 final class Appearance {
  var forgotten: [String] = []
  func forget(_ key: String) -> Bool { forgotten.append(key); return true }
 }
 final class NativeObservations {
  var purges = 0
  func clearHistory(memory: Store?, completion: @escaping (Bool) -> Void) {
   purges += 1; completion(true)
  }
 }
 final class Changes { var count = 0; func send() { count += 1 } }
 var places = Places()
 var items = ItemMemory()
 let itemAppearance = Appearance()
 let nativeObservations = NativeObservations()
 let objectWillChange = Changes()
 var itemMemoryRevision = UUID()
 var learningItem: RememberedItem?
 var arabic = false
 var retirements = 0, diagnosticPurges = 0, invalidations = 0, cancellations = 0
 var removedHistory: [String] = [], spoken: [String] = []
 func retireHeldSearchForPrivacyDeletion() { retirements += 1 }
 func purgeDebugSessionDiagnostics() { diagnosticPurges += 1 }
 func invalidatePerceptionWork() { invalidations += 1 }
 func cancelDescription() { cancellations += 1 }
 func removeObservedHistory(category: String) throws { removedHistory.append(category) }
 func say(_ text: String) { spoken.append(text) }
 func deleteAfterPurge(_ item: RememberedItem) -> Bool { forgetItemAfterNativePurge(item) }
