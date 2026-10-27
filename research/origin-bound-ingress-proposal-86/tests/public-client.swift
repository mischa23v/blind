// Positive typecheck control: imports and public signatures must actually work.
import Foundation
import OriginBoundMeshIngress86
let owner = try OriginBoundMeshIngress86()
let lease = try owner.reset()
_ = owner.ingest(lease: lease, anchorID: UUID(), receiptUptime: 1) { _ in fatalError("typecheck only") }
_ = owner.remove(lease: lease, anchorID: UUID(), receiptUptime: 2)
owner.stop()
