// Expected compile rejection: no legacy custom capture admission without a lease.
import Foundation
import OriginBoundMeshIngress86
let owner = try OriginBoundMeshIngress86()
_ = owner.ingest(anchorID: UUID(), receiptUptime: 1) { _ in fatalError("must not compile") }
