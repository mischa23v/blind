import Foundation
struct Exclusion:Codable {
 let id:String;let revision:Int;let meshFrameID:String;let polygonFrameID:String;let heightFrameID:String
 let polygonLevelXY:[Double];let polygonPlannerXZ:[Double];let observedTopHeightRange:[Double]
 let unknown:Bool;let authority:Bool;let bodyInflationApplied:Bool
 func validatedPolygon(expectedFrame:String)throws->[Float] {
  guard !id.isEmpty,id.utf8.count<=128,revision>=0,expectedFrame=="phone-corrected-level-game-yup-v1",meshFrameID==expectedFrame,polygonFrameID==expectedFrame,heightFrameID==expectedFrame,unknown,!authority,!bodyInflationApplied else{throw Failure.invalid("exclusion metadata/frame")}
  let n=polygonPlannerXZ.count/2
  guard polygonPlannerXZ.count%2==0,n>=3,n<=64,polygonLevelXY.count==polygonPlannerXZ.count,polygonPlannerXZ.allSatisfy({$0.isFinite && Float($0).isFinite}),polygonLevelXY.allSatisfy({$0.isFinite}),observedTopHeightRange.count==2,observedTopHeightRange.allSatisfy({$0.isFinite && Float($0).isFinite}),observedTopHeightRange[0]<=observedTopHeightRange[1] else{throw Failure.invalid("exclusion shape/height")}
  for i in 0..<n{guard polygonLevelXY[2*i]==polygonPlannerXZ[2*i],polygonLevelXY[2*i+1] == -polygonPlannerXZ[2*i+1] else{throw Failure.invalid("exclusion axis conversion")}}
  var sign=0.0
  for i in 0..<n {
   let j=(i+1)%n,k=(i+2)%n
   for q in i+1..<n {guard hypot(polygonPlannerXZ[2*i]-polygonPlannerXZ[2*q],polygonPlannerXZ[2*i+1]-polygonPlannerXZ[2*q+1])>1e-7 else{throw Failure.invalid("duplicate polygon vertex")}}
   let ax=polygonPlannerXZ[2*j]-polygonPlannerXZ[2*i],az=polygonPlannerXZ[2*j+1]-polygonPlannerXZ[2*i+1]
   let bx=polygonPlannerXZ[2*k]-polygonPlannerXZ[2*j],bz=polygonPlannerXZ[2*k+1]-polygonPlannerXZ[2*j+1]
   let cross=ax*bz-az*bx
   guard cross.isFinite,abs(cross)>1e-10 else{throw Failure.invalid("degenerate polygon")}
   if sign==0{sign=cross};guard cross*sign>0 else{throw Failure.invalid("nonconvex polygon")}
  }
  // Every vertex must lie on the same interior side of every edge; local turn
  // signs alone would accept some self-intersecting star polygons.
  for i in 0..<n {let j=(i+1)%n;for q in 0..<n where q != i && q != j {
   let cross=(polygonPlannerXZ[2*j]-polygonPlannerXZ[2*i])*(polygonPlannerXZ[2*q+1]-polygonPlannerXZ[2*i+1])-(polygonPlannerXZ[2*j+1]-polygonPlannerXZ[2*i+1])*(polygonPlannerXZ[2*q]-polygonPlannerXZ[2*i])
   guard cross*sign>0 else{throw Failure.invalid("nonconvex/self-intersecting polygon")}
  }}
  let packed=(0..<n).flatMap{[Float(polygonPlannerXZ[$0*2]),Float(0),Float(polygonPlannerXZ[$0*2+1])]}
  // Native consumes Float, so Double-only convexity is insufficient at large offsets.
  let q=(0..<n).flatMap{[Double(packed[$0*3]),Double(packed[$0*3+2])]}
  for i in 0..<n {let j=(i+1)%n
   for k in i+1..<n {guard hypot(q[2*i]-q[2*k],q[2*i+1]-q[2*k+1])>1e-7 else{throw Failure.invalid("packed polygon duplicate/collapse")}}
   for k in 0..<n where k != i && k != j {
    let cross=(q[2*j]-q[2*i])*(q[2*k+1]-q[2*i+1])-(q[2*j+1]-q[2*i+1])*(q[2*k]-q[2*i])
    guard cross.isFinite,cross*sign>0 else{throw Failure.invalid("packed polygon topology")}
   }
  }
  return packed
 }
 var diagnosticFootInterval:[Double]{[observedTopHeightRange[0]-1.75,observedTopHeightRange[1]]}
}
/// Single immutable snapshot. Unsupported changes retire this owner, never remove exclusions.
final class SnapshotOwner {
 let exclusion:Exclusion?;private(set)var usable=true
 init(_ exclusion:Exclusion?)throws{if let e=exclusion{_ = try e.validatedPolygon(expectedFrame:"phone-corrected-level-game-yup-v1")};self.exclusion=exclusion}
 func unsupportedUpdateOrRemoval()throws {usable=false;throw Failure.invalid("snapshot updates unsupported; owner retired")}
 func native(_ v:[Double],_ t:[Int32])throws->Native{guard usable else{throw Failure.invalid("retired snapshot")};return try Native(v,t,exclusion:exclusion)}
}
