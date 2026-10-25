import XCTest
import BlindCore
@testable import AcquisitionReplay
final class AcquisitionTests: XCTestCase {
 let matrix: [Double] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
 func frame() -> SavedWorldFrame { .init(placeID: UUID().uuidString, revision: UUID().uuidString, worldMapSHA256: String(repeating:"a",count:64), roomCaptureSHA256: String(repeating:"b",count:64), originAnchorID:UUID().uuidString,capturedAt:Date(timeIntervalSince1970:10)) }
 func feature(_ x: Double = 0, id: UUID = UUID(), kind: String = "refrigerator") -> RoomRegistrationAcquisition.Feature {
  var m=matrix;m[12]=x;return .init(id:id.uuidString,kind:kind,transform:m,dimensions:Point3(1,2,1))
 }
 func record() -> RoomRegistrationAcquisition { .init(frame:frame(),sessionID:UUID(),scanID:UUID(),baselineRoomID:UUID(),measuredRoomID:UUID(),startedAt:10,capturedAt:11,recordedAt:Date(timeIntervalSince1970:100),cameraToWorld:matrix,baseline:[feature(),feature(4)],measured:[feature(0.1),feature(4.2)])! }
 func testA001SimilarFridgesNeverAutoPair() {
  let r=record();XCTAssertTrue(r.valid);XCTAssertTrue(r.correspondences.isEmpty);XCTAssertNil(r.maximumCenterResidualMetres)
  XCTAssertNotEqual(r.baseline[0].id,r.measured[0].id)
 }
 func testA002ExplicitIndependentPairsMeasureOriginalCoordinates() {
  var r=record();let p=RoomRegistrationAcquisition.Correspondence(baselineID:r.baseline[0].id,measuredID:r.measured[0].id)
  XCTAssertTrue(r.select([p],acquisitionID:r.id));XCTAssertEqual(r.maximumCenterResidualMetres!,0.1,accuracy:0.00001)
  let swapped=RoomRegistrationAcquisition.Correspondence(baselineID:r.baseline[1].id,measuredID:r.measured[0].id)
  XCTAssertFalse(r.select([p,swapped],acquisitionID:r.id));XCTAssertEqual(r.correspondences,[p])
 }
 func testA003OtherHomeOrScanReceiptCannotCommit() {
  var a=record();let b=record();XCTAssertNotEqual(a.frame.placeID,b.frame.placeID)
  XCTAssertFalse(a.select([.init(baselineID:a.baseline[0].id,measuredID:a.measured[0].id)],acquisitionID:b.id));XCTAssertTrue(a.correspondences.isEmpty)
  XCTAssertFalse(a.select([.init(baselineID:b.baseline[0].id,measuredID:a.measured[0].id)],acquisitionID:a.id))
 }
 func testA004NativeCaptureLossAndSessionChangeCannotRecoverByNormalFrameAlone() {
  var c=RoomRegistrationCapture();let session=UUID(),scan=UUID();c.begin(frame:frame(),sessionID:session,scanID:scan,now:10)
  c.observe(sessionID:session,scanID:scan,capturedAt:10.1,cameraToWorld:matrix,trackingNormal:true,now:10.1);XCTAssertNotNil(c.sample(sessionID:session,scanID:scan,now:10.2))
  c.observe(sessionID:session,scanID:scan,capturedAt:10.2,cameraToWorld:matrix,trackingNormal:false,now:10.2)
  c.observe(sessionID:session,scanID:scan,capturedAt:10.3,cameraToWorld:matrix,trackingNormal:true,now:10.3);XCTAssertNil(c.latest)
  c.begin(frame:frame(),sessionID:session,scanID:scan,now:11)
  c.observe(sessionID:UUID(),scanID:scan,capturedAt:11.1,cameraToWorld:matrix,trackingNormal:true,now:11.1);XCTAssertNotNil(c.frame);XCTAssertNil(c.latest)
 }
 func testA005StaleReplayAndWrongScanAreRejected() {
  var c=RoomRegistrationCapture();let session=UUID(),scan=UUID();c.begin(frame:frame(),sessionID:session,scanID:scan,now:10)
  c.observe(sessionID:session,scanID:scan,capturedAt:10.1,cameraToWorld:matrix,trackingNormal:true,now:10.1)
  c.observe(sessionID:session,scanID:scan,capturedAt:10.1,cameraToWorld:matrix,trackingNormal:true,now:10.2);XCTAssertEqual(c.latest?.capturedAt,10.1)
  XCTAssertNil(c.sample(sessionID:session,scanID:scan,now:11));XCTAssertNil(c.sample(sessionID:session,scanID:UUID(),now:10.2))
  c.observe(sessionID:session,scanID:scan,capturedAt:11,cameraToWorld:matrix,trackingNormal:true,now:11);XCTAssertNil(c.frame)
 }
 func testA006RestartPreservesHistoricalProvenanceNotLiveCapture() throws {
  let a=record(),decoded=try Foundation.JSONDecoder().decode(RoomRegistrationAcquisition.self,from:JSONEncoder().encode(a));XCTAssertEqual(decoded,a)
  let restarted=RoomRegistrationCapture();XCTAssertNil(restarted.sample(sessionID:a.sessionID,scanID:a.scanID,now:11));XCTAssertNil(restarted.frame)
 }
 func testA007MalformedAndOversizedMeasurementsRejectWhole() {
  var m=matrix;m[0]=Double.nan
  XCTAssertNil(RoomRegistrationAcquisition(frame:frame(),sessionID:UUID(),scanID:UUID(),baselineRoomID:UUID(),measuredRoomID:UUID(),startedAt:10,capturedAt:11,recordedAt:Date(),cameraToWorld:m,baseline:[feature()],measured:[feature()]))
  XCTAssertNil(RoomRegistrationAcquisition(frame:frame(),sessionID:UUID(),scanID:UUID(),baselineRoomID:UUID(),measuredRoomID:UUID(),startedAt:10,capturedAt:11,recordedAt:Date(),cameraToWorld:matrix,baseline:(0..<33).map { feature(Double($0)) },measured:[feature()]))
 }
 func testA008MaximumRecordFitsExistingStoreBudget() throws {
  let r=RoomRegistrationAcquisition(frame:frame(),sessionID:UUID(),scanID:UUID(),baselineRoomID:UUID(),measuredRoomID:UUID(),startedAt:10,capturedAt:11,recordedAt:Date(),cameraToWorld:matrix,baseline:(0..<32).map { feature(Double($0),kind:String(repeating:"x",count:64)) },measured:(0..<32).map { feature(Double($0),kind:String(repeating:"x",count:64)) })!
  XCTAssertLessThan(try JSONEncoder().encode(r).count,64000)
 }
}

extension AcquisitionTests {
 func testA009NativeStartRequiresExactRecoveredSessionAndArtifact() {
  let c=ExtractedRegistrationIngress();c.recovered=frame();let place=SavedPlace(id:UUID(uuidString:c.recovered!.placeID)!,worldFrame:c.recovered)
  c.startScan(session:ARSession(),name:"kitchen",compare:place,relocalized:true,registrationSessionID:UUID())
  XCTAssertNil(c.registrationCapture.frame);XCTAssertNil(c.registration)
  let d=ExtractedRegistrationIngress();d.recovered=c.recovered
  d.startScan(session:ARSession(),name:"identical kitchen name",compare:place,relocalized:true,registrationSessionID:d.actualSession)
  XCTAssertEqual(d.registrationCapture.frame,c.recovered);XCTAssertNil(d.registration)
 }
 func testA010ActualNativeFrameConsumerWithdrawsOnTrackingLoss() {
  let c=ExtractedRegistrationIngress();c.recovered=frame();let place=SavedPlace(id:UUID(uuidString:c.recovered!.placeID)!,worldFrame:c.recovered)
  c.startScan(session:ARSession(),name:"kitchen",compare:place,relocalized:true,registrationSessionID:c.actualSession)
  let now=ProcessInfo.processInfo.systemUptime
  let m=simd_float4x4(columns:[SIMD4<Float>(1,0,0,0),SIMD4<Float>(0,1,0,0),SIMD4<Float>(0,0,1,0),SIMD4<Float>(0,0,0,1)])
  c.observeRegistrationFrame(.init(camera:.init(transform:m,trackingState:.normal),timestamp:now),sessionID:c.actualSession,now:now)
  XCTAssertNotNil(c.registrationCapture.sample(sessionID:c.actualSession,scanID:c.scanID,now:now));XCTAssertNil(c.registration)
  c.observeRegistrationFrame(.init(camera:.init(transform:m,trackingState:.unavailable),timestamp:now+0.01),sessionID:c.actualSession,now:now+0.01)
  XCTAssertNil(c.registrationCapture.frame)
 }
 func testA011ActualRoomPlanAdapterPreservesFloorPolygonAndDistinctFridgeIDs() {
  let m=simd_float4x4(columns:[SIMD4<Float>(1,0,0,0),SIMD4<Float>(0,1,0,0),SIMD4<Float>(0,0,1,0),SIMD4<Float>(0,0,0,1)])
  var room=CapturedRoom(identifier:UUID(),story:2)
  let floor=CapturedRoom.Feature(identifier:UUID(),category:"floor",transform:m,dimensions:SIMD3(4,0,4),polygonCorners:[SIMD3(0,0,0),SIMD3(4,0,0),SIMD3(4,0,4),SIMD3(0,0,4)])
  room.floors=[floor];room.objects=[.init(identifier:UUID(),category:"refrigerator",transform:m,dimensions:SIMD3(1,2,1),polygonCorners:[]),.init(identifier:UUID(),category:"refrigerator",transform:m,dimensions:SIMD3(1,2,1),polygonCorners:[])]
  let measured=RoomLayoutAdapter.registrationFeatures(room)!
  XCTAssertEqual(measured.count,3);XCTAssertEqual(measured[0].polygonCorners.count,4);XCTAssertNotEqual(measured[1].id,measured[2].id)
  XCTAssertEqual(measured[0].transform,matrix)
 }
}

extension AcquisitionTests {
 func testA012RoomOnlyHistoryAvailableAfterIdentityLossWithoutFridgeGuess() throws {
  let c=HistoryController(),a=UUID(),b=UUID()
  let scopeA=CompanionMemoryScope(map:.init(mapID:"A",frameID:"fA",revision:"1"),placeID:a.uuidString,floorID:"upstairs",roomID:"room-A")!
  let scopeB=CompanionMemoryScope(map:.init(mapID:"B",frameID:"fB",revision:"1"),placeID:b.uuidString,floorID:"downstairs",roomID:"room-B",objectInstanceID:"fridge-B")!
  c.companionWorkingState.transitionMemoryScope(scopeA);c.companionWorkingState.changeGoal("Make breakfast")
  let textA="Maybe I left my milk in the fridge"
  c.companionWorkingState.record(textA,at:Date(timeIntervalSince1970:10));let sourceA=c.companionWorkingState.reports.last!.sourceID!
  _ = c.companionWorkingState.respond(to:CompanionUtterance.parse(textA)!,message:textA,now:Date(timeIntervalSince1970:10),arabic:false,sourceID:sourceA)
  c.companionWorkingState.transitionMemoryScope(scopeB)
  let textB="My milk is on the shelf"
  c.companionWorkingState.record(textB,at:Date(timeIntervalSince1970:20))
  _ = c.companionWorkingState.respond(to:CompanionUtterance.parse(textB)!,message:textB,now:Date(timeIntervalSince1970:20),arabic:false,sourceID:c.companionWorkingState.reports.last!.sourceID)
  c.companionWorkingState.transitionMemoryScope(nil);let revision=c.companionWorkingState.goalRevision
  let result=c.historicalReports(for:.init(id:a,worldFrame:nil))
  XCTAssertEqual(result.count,1);XCTAssertEqual(result[0].sourceID,sourceA);XCTAssertNil(result[0].scope?.objectInstanceID);XCTAssertTrue(result[0].hedged)
  XCTAssertEqual(result[0].at,Date(timeIntervalSince1970:10));XCTAssertNil(c.companionWorkingState.memoryScope)
  XCTAssertEqual(c.companionWorkingState.goalRevision,revision);XCTAssertNil(c.companionWorkingState.currentContextFact(for:"milk"))
  let restored=try Foundation.JSONDecoder().decode(CompanionWorkingState.self,from:JSONEncoder().encode(c.companionWorkingState))
  XCTAssertEqual(restored.factBook.reportedHistory(placeID:a.uuidString).first?.sourceID,sourceA)
 }
 func testA013FreshObservationWinsCurrentScopeButHistoricalReportSurvives() {
  var book=CompanionFactBook();let scope=CompanionMemoryScope(map:.init(mapID:"A",frameID:"fA",revision:"1"),placeID:"home-A",floorID:"upstairs",roomID:"kitchen")!
  book.record(object:"milk",place:"in the fridge",tense:.current,hedged:false,at:Date(timeIntervalSince1970:10),scope:scope,sourceID:"old-report")
  let now=Date(timeIntervalSince1970:20)
  let evidence=CompanionEvidence(id:"fresh",kind:.currentObservation,text:"The label says oat milk",source:"authored validated observation fixture",observedAt:now,expiresAt:now.addingTimeInterval(1))
  let result=CompanionScopedRecall.select(object:"milk",scope:scope,now:now,observations:[.init(scope:scope,object:"milk",evidence:evidence)],book:book)
  XCTAssertEqual(result,.observation(evidence));XCTAssertEqual(book.reportedHistory(placeID:"home-A").first?.sourceID,"old-report")
 }
}

extension AcquisitionTests {
 @MainActor func testA014ActualNativeReviewSaveAndReloadKeepOriginalAcquisition() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:")
  let r=record();c.registration=r;c.registrationStoreOwner=c.memory?.writeOwner;c.places=[.init(id:UUID(uuidString:r.frame.placeID)!,worldFrame:r.frame)]
  let pair=RoomRegistrationAcquisition.Correspondence(baselineID:r.baseline[0].id,measuredID:r.measured[0].id)
  XCTAssertFalse(c.selectRegistrationPairs([pair],acquisitionID:UUID()));XCTAssertTrue(c.registration!.correspondences.isEmpty)
  XCTAssertTrue(c.selectRegistrationPairs([pair],acquisitionID:r.id));let saved=await c.saveRegistration(acquisitionID:r.id);XCTAssertTrue(saved)
  c.registration=nil;await c.loadRegistration(for:c.places[0])
  XCTAssertEqual(c.registration?.id,r.id);XCTAssertEqual(c.registration?.recordedAt,r.recordedAt);XCTAssertEqual(c.registration?.capturedAt,r.capturedAt);XCTAssertEqual(c.registration?.correspondences,[pair])
  XCTAssertNil(c.registrationCapture.frame)
 }
 @MainActor func testA015ActualNativeSaveRejectedAfterPrivacyDeletion() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let r=record();c.registration=r;c.registrationStoreOwner=c.memory?.writeOwner;c.places=[.init(id:UUID(uuidString:r.frame.placeID)!,worldFrame:r.frame)]
  try c.memory!.deleteRoom(r.frame.placeID)
  let saved=await c.saveRegistration(acquisitionID:r.id);XCTAssertFalse(saved);XCTAssertFalse(c.registrationSaving)
  XCTAssertTrue(c.registrationStatus.contains("not saved"));XCTAssertNil(try c.memory!.value(namespace:"places",id:"registration:"+r.frame.placeID))
 }
}

extension AcquisitionTests {
 @MainActor func testA016StoreReplacementCannotRebindOldAcquisition() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let r=record();c.registration=r;c.registrationStoreOwner=c.memory?.writeOwner;c.places=[.init(id:UUID(uuidString:r.frame.placeID)!,worldFrame:r.frame)]
  c.memory=try .init(path:":memory:")
  let saved=await c.saveRegistration(acquisitionID:r.id);XCTAssertFalse(saved)
  XCTAssertTrue(c.registrationStatus.contains("context changed"));XCTAssertNil(try c.memory!.value(namespace:"places",id:"registration:"+r.frame.placeID))
  await c.loadRegistration(for:c.places[0]);XCTAssertNil(c.registration)
 }
 func testA017WrongFloorIsRawMismatchNotInferredIdentity() {
  let base=record()
  let r=RoomRegistrationAcquisition(frame:base.frame,sessionID:base.sessionID,scanID:base.scanID,baselineRoomID:base.baselineRoomID,measuredRoomID:base.measuredRoomID,startedAt:10,capturedAt:11,recordedAt:base.recordedAt,cameraToWorld:matrix,baseline:base.baseline,measured:base.measured,baselineStory:1,measuredStory:2)!
  XCTAssertEqual(r.baselineStory,1);XCTAssertEqual(r.measuredStory,2);XCTAssertTrue(r.correspondences.isEmpty)
  // This diagnostic remains reviewable, never a floor ID or a memory scope.
  XCTAssertNil(r.maximumCenterResidualMetres)
 }
}

extension AcquisitionTests {
 func testA018LateOldOwnerCannotEraseNewCapture() {
  for normal in [true,false] {
   var c=RoomRegistrationCapture();let a=UUID(),b=UUID(),scanA=UUID(),scanB=UUID()
   c.begin(frame:frame(),sessionID:a,scanID:scanA,now:10)
   c.begin(frame:frame(),sessionID:b,scanID:scanB,now:11)
   c.observe(sessionID:b,scanID:scanB,capturedAt:11.1,cameraToWorld:matrix,trackingNormal:true,now:11.1)
   c.observe(sessionID:a,scanID:scanA,capturedAt:11.2,cameraToWorld:matrix,trackingNormal:normal,now:11.2)
   XCTAssertEqual(c.sample(sessionID:b,scanID:scanB,now:11.2)?.capturedAt,11.1)
  }
 }
}

extension AcquisitionTests {
 func testA019ActualNativeLatePreStartAndReplayCannotEraseCurrentAcquisition() {
  let c=ExtractedRegistrationIngress();c.recovered=frame();let place=SavedPlace(id:UUID(uuidString:c.recovered!.placeID)!,worldFrame:c.recovered)
  c.startScan(session:ARSession(),name:"kitchen",compare:place,relocalized:true,registrationSessionID:c.actualSession)
  let start=c.registrationCapture.startedAt!
  let m=simd_float4x4(columns:[SIMD4<Float>(1,0,0,0),SIMD4<Float>(0,1,0,0),SIMD4<Float>(0,0,1,0),SIMD4<Float>(0,0,0,1)])
  c.observeRegistrationFrame(.init(camera:.init(transform:m,trackingState:.unavailable),timestamp:start-0.1),sessionID:c.actualSession,now:start)
  XCTAssertNotNil(c.registrationCapture.frame)
  c.observeRegistrationFrame(.init(camera:.init(transform:m,trackingState:.normal),timestamp:start+0.1),sessionID:c.actualSession,now:start+0.1)
  c.observeRegistrationFrame(.init(camera:.init(transform:m,trackingState:.unavailable),timestamp:start+0.05),sessionID:c.actualSession,now:start+0.2)
  XCTAssertEqual(c.registrationCapture.sample(sessionID:c.actualSession,scanID:c.scanID,now:start+0.2)?.capturedAt,start+0.1)
 }
}

extension AcquisitionTests {
 func testA020OversizedRawArraysRejectBeforeMatrixExpansion() {
  let m=simd_float4x4(columns:[SIMD4<Float>(1,0,0,0),SIMD4<Float>(0,1,0,0),SIMD4<Float>(0,0,1,0),SIMD4<Float>(0,0,0,1)])
  var room=CapturedRoom(identifier:UUID(),story:0)
  room.objects=(0..<33).map { _ in .init(identifier:UUID(),category:"refrigerator",transform:m,dimensions:SIMD3(1,2,1),polygonCorners:[]) }
  simd_float4x4.reads=0;XCTAssertNil(RoomLayoutAdapter.registrationFeatures(room));XCTAssertEqual(simd_float4x4.reads,0)
  room.objects=[];room.floors=[.init(identifier:UUID(),category:"floor",transform:m,dimensions:SIMD3(1,0,1),polygonCorners:Array(repeating:SIMD3(0,0,0),count:17))]
  simd_float4x4.reads=0;XCTAssertNil(RoomLayoutAdapter.registrationFeatures(room));XCTAssertEqual(simd_float4x4.reads,0)
 }
 @MainActor func testA021HeldLoadASelectionBRetiresAAndOffersExplicitBoundedRetry() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let store=c.memory!,a=record(),b=record()
  let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame),pb=SavedPlace(id:UUID(uuidString:b.frame.placeID)!,worldFrame:b.frame);c.places=[pa,pb]
  try store.saveRoomRegistration(room:a.frame.placeID,payload:JSONEncoder().encode(a));try store.saveRoomRegistration(room:b.frame.placeID,payload:JSONEncoder().encode(b))
  store.holdRead();let read=Task { @MainActor in await c.loadRegistration(for:pa) }
  let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(started)
  await c.loadRegistration(for:pb);let status=c.registrationStatus;XCTAssertTrue(c.registrationLoadNeedsRetry)
  store.release.signal();await read.value;XCTAssertNil(c.registration);XCTAssertEqual(c.registrationStatus,status)
  await c.loadRegistration(for:pb);XCTAssertEqual(c.registration?.id,b.id);XCTAssertFalse(c.registrationLoadNeedsRetry)
 }
 @MainActor func testA022HeldSaveACompletionCannotReplaceBStatusOnSuccessOrFailure() async throws {
  for fail in [false,true] {
   let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let store=c.memory!,a=record(),b=record()
   let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame),pb=SavedPlace(id:UUID(uuidString:b.frame.placeID)!,worldFrame:b.frame);c.places=[pa,pb];c.registration=a;c.registrationStoreOwner=store.writeOwner
   store.holdWrite(fail:fail);let save=Task { @MainActor in await c.saveRegistration(acquisitionID:a.id) }
   let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(started)
   await c.loadRegistration(for:pb);let status=c.registrationStatus;store.release.signal();let saved=await save.value
   XCTAssertFalse(saved);XCTAssertEqual(c.registrationStatus,status);XCTAssertTrue(c.registrationLoadNeedsRetry);XCTAssertFalse(c.registrationSaving)
  }
 }
}

extension AcquisitionTests {
 @MainActor func prepareController() throws -> (ExtractedRegistrationIngress, SavedPlace) {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");c.recovered=frame()
  let place=SavedPlace(id:UUID(uuidString:c.recovered!.placeID)!,worldFrame:c.recovered);c.places=[place]
  c.seedBytes(try JSONEncoder().encode(c.baseline),frame:c.recovered!);return(c,place)
 }
 @MainActor func awaitPreparation(_ c:ExtractedRegistrationIngress) async {
  for _ in 0..<1000 { if !c.preparationBusy { return };try? await Task.sleep(nanoseconds:1_000_000) }
  XCTFail("Preparation did not settle")
 }
 @MainActor func testA023HeldPreparationDoesNotBlockOwnerAndCancelRescanDoesNotFanOut() async throws {
  let(c,p)=try prepareController();AcquisitionReplay.JSONDecoder.hold()
  c.startScan(session:ARSession(),name:"A",compare:p,relocalized:true,registrationSessionID:c.actualSession)
  let began=await Task.detached { AcquisitionReplay.JSONDecoder.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(began)
  XCTAssertFalse(AcquisitionReplay.JSONDecoder.decodedOnMain);XCTAssertTrue(c.scanning)
  c.cancelScan();c.startScan(session:ARSession(),name:"B",compare:p,relocalized:true,registrationSessionID:c.actualSession)
  let status=c.registrationStatus;XCTAssertTrue(status.contains("Previous scan"));XCTAssertEqual(AcquisitionReplay.JSONDecoder.count,1)
  AcquisitionReplay.JSONDecoder.release.signal();await awaitPreparation(c);XCTAssertFalse(c.hasPreparedBaseline);XCTAssertEqual(c.registrationStatus,status)
 }
 @MainActor func testA024HeldPreparationRejectsReplacedStoreOrDescriptor() async throws {
  for changeStore in [true,false] {
   let(c,p)=try prepareController();AcquisitionReplay.JSONDecoder.hold()
   c.startScan(session:ARSession(),name:"A",compare:p,relocalized:true,registrationSessionID:c.actualSession)
   let began=await Task.detached { AcquisitionReplay.JSONDecoder.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(began)
   if changeStore { c.memory=try .init(path:":memory:") } else { c.places=[SavedPlace(id:p.id,worldFrame:frame())] }
   c.registrationStatus="New selection";AcquisitionReplay.JSONDecoder.release.signal();await awaitPreparation(c)
   XCTAssertFalse(c.hasPreparedBaseline);XCTAssertEqual(c.registrationStatus,"New selection")
  }
 }
 @MainActor func testA025DeletionAdmissionRetiresHeldPreparationEvenWhenSQLFails() async throws {
  for fail in [false,true] {
   let(c,p)=try prepareController();AcquisitionReplay.JSONDecoder.hold();c.memory!.failDelete=fail
   c.startScan(session:ARSession(),name:"A",compare:p,relocalized:true,registrationSessionID:c.actualSession)
   let began=await Task.detached { AcquisitionReplay.JSONDecoder.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(began)
   c.delete(p);XCTAssertFalse(c.hasCachedBytes);XCTAssertNil(c.registrationCapture.frame)
   let status=c.registrationStatus;AcquisitionReplay.JSONDecoder.release.signal();await awaitPreparation(c)
   XCTAssertFalse(c.hasPreparedBaseline);XCTAssertNil(c.registration);XCTAssertEqual(c.registrationStatus,status)
   if fail { XCTAssertTrue(c.message.contains("did not finish"));XCTAssertEqual(c.places.count,1) }
  }
 }
 @MainActor func testA026BoundedOriginalBytesDecodeOffMainAndOversizeRejectsWhole() async throws {
  let(c,p)=try prepareController()
  let m=simd_float4x4(columns:[SIMD4<Float>(1,0,0,0),SIMD4<Float>(0,1,0,0),SIMD4<Float>(0,0,1,0),SIMD4<Float>(0,0,0,1)])
  c.baseline.objects=[.init(identifier:UUID(),category:"refrigerator",transform:m,dimensions:SIMD3(1,2,1),polygonCorners:[])]
  c.seedBytes(Data(repeating:0,count:8*1024*1024+1),frame:p.worldFrame!)
  c.startScan(session:ARSession(),name:"A",compare:p,relocalized:true,registrationSessionID:c.actualSession)
  XCTAssertFalse(c.preparationBusy);XCTAssertFalse(c.hasPreparedBaseline)
  c.cancelScan();c.seedBytes(try JSONEncoder().encode(c.baseline),frame:p.worldFrame!)
  c.startScan(session:ARSession(),name:"A",compare:p,relocalized:true,registrationSessionID:c.actualSession)
  await awaitPreparation(c);XCTAssertTrue(c.hasPreparedBaseline);XCTAssertFalse(AcquisitionReplay.JSONDecoder.decodedOnMain)
 }
}

extension AcquisitionTests {
 @MainActor func testA027RestartHeldLoadCannotPublishAfterFailedDeleteAdmission() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let store=c.memory!,a=record()
  let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame);c.places=[pa]
  try store.saveRoomRegistration(room:a.frame.placeID,payload:JSONEncoder().encode(a))
  store.holdRead();let read=Task { @MainActor in await c.loadRegistration(for:pa) }
  let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(started)
  XCTAssertNil(c.registration);XCTAssertFalse(c.hasCachedBytes);XCTAssertNil(c.comparison)
  store.failDelete=true;c.delete(pa);let status=c.registrationStatus
  store.release.signal();await read.value
  XCTAssertNil(c.registration);XCTAssertEqual(c.registrationStatus,status);XCTAssertTrue(c.message.contains("did not finish"))
 }
 @MainActor func testA028UnrelatedRoomDeletionDoesNotRetireHeldSelectionB() async throws {
  for fail in [true,false] {
   let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let store=c.memory!,a=record(),b=record()
   let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame),pb=SavedPlace(id:UUID(uuidString:b.frame.placeID)!,worldFrame:b.frame);c.places=[pa,pb]
   try store.saveRoomRegistration(room:b.frame.placeID,payload:JSONEncoder().encode(b))
   store.holdRead();let read=Task { @MainActor in await c.loadRegistration(for:pb) }
   let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(started)
   store.failDelete=fail;c.delete(pa);store.release.signal();await read.value
   XCTAssertEqual(c.registration?.id,b.id)
  }
 }
}

extension AcquisitionTests {
 @MainActor func testA029DeletingLoadedAWhileBPendingRetiresOnlyABytesEvenOnFailure() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let store=c.memory!,a=record(),b=record()
  let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame),pb=SavedPlace(id:UUID(uuidString:b.frame.placeID)!,worldFrame:b.frame);c.places=[pa,pb]
  for r in [a,b] { try store.saveRoomRegistration(room:r.frame.placeID,payload:JSONEncoder().encode(r)) }
  await c.loadRegistration(for:pa);XCTAssertEqual(c.registration?.id,a.id)
  store.holdRead();let read=Task { @MainActor in await c.loadRegistration(for:pb) }
  let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(started)
  let request=c.registrationRequestID,status=c.registrationStatus,owner=c.registrationStoreOwner
  store.failDelete=true;c.delete(pa)
  XCTAssertNil(c.registration);XCTAssertEqual(c.registrationRequestID,request);XCTAssertEqual(c.registrationStatus,status);XCTAssertEqual(c.registrationStoreOwner,owner)
  XCTAssertFalse(c.selectRegistrationPairs([],acquisitionID:a.id))
  store.release.signal();await read.value;XCTAssertEqual(c.registration?.id,b.id)
 }
}

extension AcquisitionTests {
 @MainActor func testA030NativeDeletionRetiresDiagnosticBeforeHeldOrFailedPurge() async throws {
  let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:");let store=c.memory!,a=record(),b=record()
  let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame),pb=SavedPlace(id:UUID(uuidString:b.frame.placeID)!,worldFrame:b.frame);c.places=[pa,pb]
  for r in [a,b] { try store.saveRoomRegistration(room:r.frame.placeID,payload:JSONEncoder().encode(r)) }
  await c.loadRegistration(for:pa)
  store.holdRead();let read=Task { @MainActor in await c.loadRegistration(for:pb) }
  let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value;XCTAssertTrue(started)
  let request=c.registrationRequestID,controller=NativeDeletionController(c)
  controller.deletePlace(pa)
  XCTAssertNotNil(controller.nativeObservations.completion);XCTAssertNil(c.registration);XCTAssertEqual(c.registrationRequestID,request)
  controller.nativeObservations.completion?(false);XCTAssertTrue(controller.said.contains("could not be deleted"))
  XCTAssertNotNil(try store.value(namespace:"places",id:"registration:"+a.frame.placeID))
  store.release.signal();await read.value;XCTAssertEqual(c.registration?.id,b.id)
 }
}

extension AcquisitionTests {
 @MainActor func testA031HeldReadCannotAdmitSaveOrOverwriteSelectionStatus() async throws {
  for sameSelection in [true, false] {
   let c=ExtractedRegistrationIngress();c.memory=try .init(path:":memory:")
   let store=c.memory!,a=record(),b=record()
   let pa=SavedPlace(id:UUID(uuidString:a.frame.placeID)!,worldFrame:a.frame)
   let pb=SavedPlace(id:UUID(uuidString:b.frame.placeID)!,worldFrame:b.frame)
   c.places=[pa,pb];c.registration=a;c.registrationStoreOwner=store.writeOwner
   store.holdRead();let read=Task { @MainActor in await c.loadRegistration(for:sameSelection ? pa : pb) }
   let started=await Task.detached { store.started.wait(timeout:.now()+2) == .success }.value
   XCTAssertTrue(started);let status=c.registrationStatus
   let saved=await c.saveRegistration(acquisitionID:a.id)
   XCTAssertFalse(saved);XCTAssertTrue(c.registrationLoading);XCTAssertFalse(c.registrationSaving)
   XCTAssertEqual(c.registrationStatus,status)
   XCTAssertNil(try store.real.value(namespace:"places",id:"registration:"+a.frame.placeID))
   store.release.signal();await read.value
  }
 }
}
