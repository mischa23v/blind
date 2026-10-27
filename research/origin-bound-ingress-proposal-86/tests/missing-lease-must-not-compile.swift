// Expected compile rejection: no legacy admission without an explicit lease.
import Foundation
import OriginBoundMeshIngress86
let owner = try OriginBoundMeshIngress86()
_ = owner.remove(anchorID: UUID(), receiptUptime: 1)
