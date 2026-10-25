import SwiftUI

/// Durable state/retry receipt, not an arrival/location or deletion-success guess.
struct ConnectedJourneyPersistenceView: View {
    @ObservedObject var store: JourneyStore
    let arabic: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.connectedPersistenceMessage(arabic: arabic))
                .accessibilityIdentifier("connected-journey-persistence-status")
            if let receipt = store.connectedEraseReceipt, receipt.state == .failed {
                Button(arabic ? "أعد محاولة حذف سجل الرحلة" : "Retry journey history erasure") {
                    store.retryConnectedErase(receipt.id)
                }.accessibilityIdentifier("retry-connected-journey-erasure")
            } else if store.connectedSaveFailed {
                Button(arabic ? "أعد حفظ تغييرات الرحلة" : "Retry saving journey changes") {
                    store.retryConnectedSave()
                }.accessibilityIdentifier("retry-connected-journey-save")
            }
        }
    }
}
