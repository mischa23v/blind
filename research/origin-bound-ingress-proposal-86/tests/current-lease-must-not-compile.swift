// Expected compile rejection: callbacks cannot retrieve a freshly current lease.
import OriginBoundMeshIngress86
let owner = try OriginBoundMeshIngress86()
_ = owner.currentLease
