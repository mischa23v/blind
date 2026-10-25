// Exact-source portability extraction only. No map/IO/cancellation body is copied
// into a substitute implementation. Platform stubs are explicitly test-only.
export const coreFiles = ['Geometry', 'IndoorMap', 'KeepOutZone', 'NarrationDelivery', 'NativeLocalizationSelection', 'NavigationSurface', 'PlacePackage', 'RoomLayout', 'SavedWorldFrame', 'SpatialFrameRegistry', 'SpatialLocalizationLease', 'SpatialMapInstallation', 'SpatialRouteOwner', 'SpeechDeliveryLedger', 'SpeechPriority'];
export function extractIndoorNavigator(source) {
  if (!source.includes('import Combine\n')) throw Error('Expected actual native Combine import');
  return source.replace(/^import Combine\n/m, '');
}
export function extractCommunityPreparation(source) {
  function method(start) { const a=source.indexOf(start); if(a<0)throw Error(start); let b=source.indexOf('{',a)+1,d=1; for(;d && b<source.length;b++){if(source[b]==='{')d++;if(source[b]==='}')d--;} if(d)throw Error('Unclosed method'); return source.slice(a,b); }
  const methods=['private func beginPreparation(', '@discardableResult private func finishPreparation(', 'private func prepareCommunityRoute('].map(method);
  return `// HARNESS ONLY: three exact view methods; explicit platform/cache/model shells.\nimport Foundation\nimport BlindCore\nfinal class CommunityPreparationHarness {\n var preparationID: UUID? { didSet { if preparationID == nil { onIdle?() } } }\n var onIdle: (() -> Void)?\n var error = ""\n let model: CommunityPreparationModelStub\n let library = CommunityPreparationLibraryStub()\n init(indoor: IndoorNavigator) { model = .init(indoor: indoor) }\n var busy: Bool { preparationID != nil }\n func start(_ package: PlacePackage) { library.preview = package; prepareCommunityRoute(package) }\n func claim() -> UUID { beginPreparation() }\n func finish(_ id: UUID) -> Bool { finishPreparation(id) }\n ${methods.join('\n')}\n}\nfinal class CommunityPreparationModelStub { let indoor: IndoorNavigator; init(indoor: IndoorNavigator){self.indoor=indoor}; func stopReturn() {} }\nfinal class CommunityPreparationLibraryStub { var preview: PlacePackage?; func reload() {} }\n`;
}
