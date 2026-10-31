#!/usr/bin/env python3
"""Current source contracts only; no Swift execution, location or physical authority."""
from pathlib import Path
import os,json,re
ROOT=Path(os.environ.get('BLIND_SOURCE_ROOT',Path(__file__).resolve().parents[2]))
PATHS={
 'venue':'BlindCore/Sources/BlindCore/VenueCatalog.swift',
 'activation':'ios/BlindAssist/CommunityLibrary.swift',
 'indoor':'ios/BlindAssist/IndoorNavigator.swift',
 'map':'BlindCore/Sources/BlindCore/IndoorMap.swift',
 'factory':'BlindCore/Sources/BlindCore/SpatialMapInstallation.swift',
 'catalog':'BlindCore/Sources/BlindCore/ConnectedJourneyCatalog.swift',
 'route':'BlindCore/Sources/BlindCore/SpatialRouteOwner.swift',
 'registered':'ios/BlindAssist/RegisteredIndoorNavigation.swift',
 'runtime':'ios/BlindAssist/ConnectedJourneyRuntime.swift',
 'gate':'BlindCore/Sources/BlindCore/NativeLocalizationEvidence.swift',
 'router':'ios/BlindAssist/NativeLocalizationRouter.swift',
 'issuer':'ios/BlindAssist/NativeLocalizationIssuer.swift',
 'place':'ios/BlindAssist/PlaceStore.swift',
 'decoder':'ios/BlindAssist/SavedRoomDiagnosticGeometryProvider.swift',
 'nav':'ios/BlindAssist/NavigationModel.swift',
}
def evaluate(d):
 c={}
 def has(name,key,*tokens):c[name]=all(t in d[key] for t in tokens)
 has('exact public package identity','venue','package.id == packageID','package.revision == packageRevision','actualDigest == digest','package.visibility == "public"')
 activation=d['activation'].split('@MainActor final class VenuePackageActivation:',1)[1]
 c['withdraw before actual package read']=activation.index('indoor.beginCommunityImport(')<activation.index('try await load(')
 c['package validation before actual completion']=activation.index('reference.validate(package:')<activation.index('indoor.completeCommunityImport(')
 c['bounded operation includes writer acknowledgement']=all(x in activation for x in ['guard task == nil else { return }','while let request = queued','await read(request)','defer { finished.resume() }','await withCheckedContinuation'])
 c['no network transform or physical package constructor']=all(x not in activation for x in ['URLSession','ARSession','setPose','SpatialFloorSupport','SpatialMapInstallation('])
 has('outgoing navigator owner withdrawn','indoor','onJourneyMapOwnershipWithdrawn?(revision)','registered?.suspendForExternalPreparation()')
 has('empty reference map cannot contain walkable geometry','map','purpose == .localizationReferenceOnly','nodes.isEmpty, edges.isEmpty','surfaces == nil, keepOutZones == nil','permitsRoutePlanning: Bool { purpose == nil }')
 has('reference constructor binds both actual hashes','factory','frame.matches(worldMapSHA256: sha256(worldMapBytes), roomCaptureSHA256: sha256(roomCaptureBytes))','floorLevels: [:], savedWorldFrame: frame','nodes: [], edges: []')
 has('route owner rejects reference install and restore','route','guard candidate.map.permitsRoutePlanning','guard restored.map.permitsRoutePlanning')
 has('endpoint catalog rejects reference','catalog','$0.map.permitsRoutePlanning && $0.registry.snapshot == registry.snapshot')
 has('runtime rejects reference before ownership changes','runtime','guard installation.map.permitsRoutePlanning else { throw JourneyRuntimeError.noRegisteredMap }')
 has('native installer rejects reference','registered','guard installation.map.permitsRoutePlanning else { throw SpatialInstallationError.invalidEnvelope }','map.permitsRoutePlanning else { throw SpatialInstallationError.invalidEnvelope }')
 has('candidate binds exact original frame session timestamp','gate','candidate.association.frame == recovered','candidate.association.sessionID == candidate.owner.arSession','candidate.association.capturedAt == candidate.capturedAt')
 has('reference cannot prepare even supplied physical measurements','gate','currentOwner.selection.kind != .localSavedFrameReference else { throw fail(.physicalReleaseNotApproved) }')
 has('typed context cannot masquerade as routing','router','value.scope == .localSavedFrameReference','value.goalRevision == nil, value.revision.floorLevels.isEmpty','(kind == .localSavedFrameReference) == (context.scope == .localSavedFrameReference)')
 c['reference never retires a separate route']=d['router'].count('case .none, .localSavedFrameReference: return')==2
 has('candidate-only status is explicit','issuer','value.owner.selection.kind == .localSavedFrameReference ? .localReferenceOnly : .missingCalibration')
 has('normal owner uses private source only without selected fallback','nav','places.nativeSavedFrameReferenceContext(sessionID: sessionID)','connectedJourneyOwnsNavigation ? .connectedJourney','indoorGuidanceOwner == .legacyPreview ? .registeredPreview','hasLocalReference ? .localSavedFrameReference : .none')
 has('actual paired recovery initiates reference','place','worldFrameRecovery.begin(frame: descriptor, sessionID: sessionID, now: now)','prepareLocalSavedFrameReference(frame: descriptor, sessionID: sessionID)')
 has('worker lease persists while one latest request waits','place','guard localReferenceWorker == nil, let work = pendingLocalReference else { return }','defer { self.drainLocalSavedFrameReference() }','localReferenceContext = nil; pendingLocalReference = nil; localReferenceRequest = UUID()')
 has('actual native decoder is default utility worker','place','localReferenceLoader: @escaping LocalReferenceLoader = SavedRoomDiagnosticGeometryDecoder.localSavedFrameReference','Task.detached(priority: .utility)','loader(work.source, work.worldMapURL)')
 has('completed worker rechecks actual ownership','place','self.localReferenceRequest == work.request','self.worldFrameRecoverySessionID == work.sessionID','self.ownsWorldMapRecovery(work.source.frame), self.ownsDiagnosticGeometrySource(work.source)')
 has('published context has no floor or goal','place','revision.savedWorldFrame == work.source.frame, revision.floorLevels.isEmpty','goalRevision: nil, scope: .localSavedFrameReference')
 has('current source rechecked at every context request','place','context.sessionID == sessionID, let frame = context.revision.savedWorldFrame','ownsWorldMapRecovery(frame) else { return nil }')
 decoder=d['decoder'].split('    static func localSavedFrameReference(',1)[1].split('    static func decode(',1)[0]
 c['native pair decoder is bounded and actual']=all(x in decoder for x in ['SpatialMapFileStorage.readBounded(source.url, maximumBytes: maximumSourceBytes)','SpatialMapFileStorage.readBounded(worldMapURL, maximumBytes: 32 * 1024 * 1024)','_ = try decode(room, frame: source.frame)','NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: world)','PlaceStore.matchesOrigin($0, descriptor: source.frame)'])
 c['actual decoder checks deletion and memory both sides']=decoder.count('source.memory.writeOwner == source.memoryOwner')==2 and decoder.count('try !source.memory.isDeleted(room: source.frame.placeID)')==2
 has('published Boolean repair retained','nav','guard self.revalidateCurrentNavigationHazards(now: ProcessInfo.processInfo.systemUptime) else { return false }','return self.feedback.spatialRouteBeacon(sector: cue.sector, distance: min(10, cue.distance), id: id)')
 return c

def main():
 d={key:(ROOT/path).read_text() for key,path in PATHS.items()};checks=evaluate(d)
 assert all(checks.values()),[k for k,v in checks.items() if not v]
 mutations=[
 ('venue','actualDigest == digest','exact public package identity'),
 ('activation','guard task == nil else { return }','bounded operation includes writer acknowledgement'),
 ('map','nodes.isEmpty, edges.isEmpty','empty reference map cannot contain walkable geometry'),
 ('factory','floorLevels: [:], savedWorldFrame: frame','reference constructor binds both actual hashes'),
 ('gate','candidate.association.capturedAt == candidate.capturedAt','candidate binds exact original frame session timestamp'),
 ('gate','currentOwner.selection.kind != .localSavedFrameReference','reference cannot prepare even supplied physical measurements'),
 ('router','value.goalRevision == nil, value.revision.floorLevels.isEmpty','typed context cannot masquerade as routing'),
 ('place','self.localReferenceRequest == work.request','completed worker rechecks actual ownership'),
 ('place','localReferenceWorker == nil','worker lease persists while one latest request waits'),
 ('decoder','PlaceStore.matchesOrigin($0, descriptor: source.frame)','native pair decoder is bounded and actual'),
 ('decoder','_ = try decode(room, frame: source.frame)','native pair decoder is bounded and actual'),
 ('nav','connectedJourneyOwnsNavigation ? .connectedJourney','normal owner uses private source only without selected fallback'),
 ]
 for key,token,control in mutations:
  assert token in d[key],token
  altered=d.copy();altered[key]=altered[key].replace(token,'MUTATED',1)
  assert not evaluate(altered)[control],control
 identities=json.loads((ROOT/'research/local-map-pipeline-20261030/SWIFT_FIXTURE_IDENTITIES.json').read_text())
 total=added=0
 for f in identities['files']:
  actual=re.findall(r'func (test\w+)\(',(ROOT/f['path']).read_text())
  assert actual==f['exactMethods']==f['existingMethods']+f['appendedMethods'],f['path']
  assert len(actual)==f['totalCount'] and len(f['existingMethods'])==f['existingCount'] and len(f['appendedMethods'])==f['appendedCount'],f['path']
  assert len(actual)==len(set(actual)),f['path']
  total+=len(actual);added+=f['appendedCount']
 print(json.dumps({'currentSourceContracts':len(checks),'negativeSourceMutationsRejected':len(mutations),'fixtureFiles':len(identities['files']),'exactAuthoredSwiftMethods':total,'appendedAuthoredSwiftMethods':added,'nativeExecuted':False,'physicalAuthority':False,'checks':list(checks)},indent=2))
if __name__=='__main__':main()
