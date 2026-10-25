import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,copyFileSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {coreFiles,extractIndoorNavigator,extractCommunityPreparation} from '../extract-spatial-map-io.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
test('actual asynchronous map owner, file worker and extracted UI reject stale IO', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to execute actual Swift spatial IO and controller tests.', timeout:180_000,
},()=>{
  const work=mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(),'blind-spatial-map-io-'));
  for(const dir of ['Sources/BlindCore','Sources/NativeSpatialAdapter','Tests/BlindCoreTests','home'])mkdirSync(join(work,dir),{recursive:true});
  const inputs={};
  const read=path=>{const bytes=readFileSync(join(root,path));inputs[path]=createHash('sha256').update(bytes).digest('hex');return bytes;};
  const copy=(from,to)=>writeFileSync(join(work,to),read(from));
  for(const file of coreFiles)copy(`BlindCore/Sources/BlindCore/${file}.swift`,`Sources/BlindCore/${file}.swift`);
  for(const file of ['RegisteredIndoorNavigation','SpatialMapIO'])copy(`ios/BlindAssist/${file}.swift`,`Sources/NativeSpatialAdapter/${file}.swift`);
  writeFileSync(join(work,'Sources/NativeSpatialAdapter/IndoorNavigator.swift'),extractIndoorNavigator(read('ios/BlindAssist/IndoorNavigator.swift').toString()));
  writeFileSync(join(work,'Sources/NativeSpatialAdapter/CommunityPreparationHarness.swift'),extractCommunityPreparation(read('ios/BlindAssist/CommunityMapsView.swift').toString()));
  copy('tools/test/fixtures/spatial-map-io/PlatformTestStubs.swift','Sources/NativeSpatialAdapter/PlatformTestStubs.swift');
  copy('tools/test/fixtures/spatial-map-io/ExtractedCommunityPreparationTests.swift','Tests/BlindCoreTests/ExtractedCommunityPreparationTests.swift');
  for(const file of ['SpatialIntegrationFixture','SpatialMapIOTests','IndoorNavigatorAsyncTests','RegisteredIndoorNavigationTests'])copy(`ios/BlindAssistTests/${file}.swift`,`Tests/BlindCoreTests/${file}.swift`);
  writeFileSync(join(work,'inputs.json'),JSON.stringify({inputs,limitations:'Synthetic geometry and explicit UI/cache stubs. No Apple playback, measured latency, real localization or calibrated native capture issuer.'},null,2)+'\n');
  writeFileSync(join(work,'Package.swift'),'// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "SpatialMapIOReplay", targets: [.target(name: "BlindCore"), .target(name: "NativeSpatialAdapter", dependencies: ["BlindCore"]), .testTarget(name: "BlindCoreTests", dependencies: ["BlindCore", "NativeSpatialAdapter"])])\n');
  const swift=join(dirname(process.env.BLIND_SWIFTC),'swift');
  const result=spawnSync(swift,['test','--package-path',work,'--scratch-path',join(work,'build'),'--cache-path',join(work,'cache'),'--jobs','1'],{encoding:'utf8',timeout:175_000,maxBuffer:8*1024*1024,env:{...process.env,HOME:join(work,'home'),XDG_CACHE_HOME:join(work,'cache'),SWIFTPM_MODULECACHE_OVERRIDE:join(work,'modules'),CLANG_MODULE_CACHE_PATH:join(work,'clang-cache')}});
  const output=`${result.stdout||''}\n${result.stderr||''}`;writeFileSync(join(work,'execution.log'),output);
  assert.equal(result.status,0,`Spatial IO replay failed; preserved source/inputs/log: ${work}\n${output.slice(-12000)}`);
  assert.match(output,/Executed 44 tests, with 0 failures/);
});
