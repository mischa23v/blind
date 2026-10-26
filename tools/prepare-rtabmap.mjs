import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { resolve, relative, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readdir } from 'node:fs/promises';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const lock = JSON.parse(await readFile(join(root, 'integration/rtabmap.lock.json'), 'utf8'));
const checkout = join(root, '.tools/rtabmap');
await mkdir(join(root, '.tools'), { recursive: true });
try { execFileSync('git', ['-C', checkout, 'rev-parse', 'HEAD'], { stdio: 'pipe' }); }
catch { execFileSync('git', ['clone', '--no-checkout', '--filter=blob:none', lock.repository, checkout], { stdio: 'inherit' }); }
const head = execFileSync('git', ['-C', checkout, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
if (head !== lock.revision) {
  const dirty = execFileSync('git', ['-C', checkout, 'status', '--porcelain'], { encoding: 'utf8' });
  if (dirty.trim()) throw new Error('Upstream checkout has changes; preserve them before changing the pinned revision.');
  execFileSync('git', ['-C', checkout, 'fetch', 'origin', lock.revision], { stdio: 'inherit' });
  execFileSync('git', ['-C', checkout, 'checkout', '--detach', lock.revision], { stdio: 'inherit' });
}
// Pinned native local-grid bridge: fail on drift, never patch a different upstream.
const gridDirectory = join(root, 'integration/rtabmap');
const gridManifest = JSON.parse(await readFile(join(gridDirectory, 'local-grid-manifest.json'), 'utf8'));
if (gridManifest.revision !== lock.revision) throw new Error('Local-grid overlay and upstream pin differ.');
const expectedGridPaths = ['app/android/jni/RTABMapApp.h', 'app/android/jni/RTABMapApp.cpp',
  'app/ios/RTABMapApp/NativeWrapper.hpp', 'app/ios/RTABMapApp/NativeWrapper.cpp', 'app/ios/RTABMapApp/RTABMap.swift'];
if (!Array.isArray(gridManifest.files) || gridManifest.files.length !== expectedGridPaths.length ||
    new Set(gridManifest.files.map(entry => entry.path)).size !== expectedGridPaths.length ||
    !gridManifest.files.every(entry => expectedGridPaths.includes(entry.path) &&
      /^[0-9a-f]{64}$/.test(entry.beforeSHA256) && /^[0-9a-f]{64}$/.test(entry.afterSHA256))) {
  throw new Error('Malformed native local-grid manifest; only the five reviewed upstream paths are accepted.');
}
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const actualGridHashes = await Promise.all(gridManifest.files.map(async entry => digest(await readFile(join(checkout, entry.path)))));
const beforeGrid = gridManifest.files.every((entry, i) => entry.beforeSHA256 === actualGridHashes[i]);
const afterGrid = gridManifest.files.every((entry, i) => entry.afterSHA256 === actualGridHashes[i]);
if (!beforeGrid && !afterGrid) throw new Error('Native local-grid overlay preimage drift; preserve and review local edits.');
if (beforeGrid) {
  const patch = join(gridDirectory, 'local-grid.patch');
  execFileSync('git', ['-C', checkout, 'apply', '--check', patch], { stdio: 'inherit' });
  execFileSync('git', ['-C', checkout, 'apply', patch], { stdio: 'inherit' });
}
for (const entry of gridManifest.files) {
  if (digest(await readFile(join(checkout, entry.path))) !== entry.afterSHA256) throw new Error(`Local-grid overlay result differs: ${entry.path}`);
}
const bridgeHeader = await readFile(join(gridDirectory, 'BlindLocalGridBridge.hpp'));
const bridgeTarget = join(checkout, 'app/android/jni/BlindLocalGridBridge.hpp');
try {
  if (digest(await readFile(bridgeTarget)) !== digest(bridgeHeader)) throw new Error('Local-grid support header drift; review before replacement.');
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  await writeFile(bridgeTarget, bridgeHeader, { flag: 'wx' });
}
const base = join(checkout, 'app/ios'), project = join(base, 'RTABMapApp.xcodeproj/project.pbxproj');
const marker = join(base, '.blind-assist-project-original');
let pbx;
try { pbx = await readFile(marker, 'utf8'); }
catch { pbx = await readFile(project, 'utf8'); await writeFile(marker, pbx); }
const id = text => createHash('sha256').update(text).digest('hex').slice(0, 24).toUpperCase();
const quote = JSON.stringify;
const sourceDir = join(root, 'ios/BlindAssist');
const files = (await readdir(sourceDir)).filter(name => name.endsWith('.swift') && name !== 'BlindAssistApp.swift').sort();
const objects = [];
const builds = [];
for (const file of files) {
  const ref = id(`file:${file}`), build = id(`build:${file}`);
  const path = relative(base, join(sourceDir, file)).replaceAll('\\', '/');
  objects.push(`${ref} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${quote(path)}; sourceTree = SOURCE_ROOT; };`);
  objects.push(`${build} = {isa = PBXBuildFile; fileRef = ${ref}; };`); builds.push(build);
}
const pkg = id('BlindCore package'), product = id('BlindCore product'), framework = id('BlindCore framework');
objects.push(`${pkg} = {isa = XCLocalSwiftPackageReference; relativePath = ${quote(relative(base, join(root, 'BlindCore')).replaceAll('\\', '/'))}; };`);
objects.push(`${product} = {isa = XCSwiftPackageProductDependency; package = ${pkg}; productName = BlindCore; };`);
objects.push(`${framework} = {isa = PBXBuildFile; productRef = ${product}; };`);
const memoryPackage = id('BlindMemory package'), memoryProduct = id('BlindMemory product'), memoryFramework = id('BlindMemory framework');
objects.push(`${memoryPackage} = {isa = XCLocalSwiftPackageReference; relativePath = ${quote(relative(base, join(root, 'BlindMemory')).replaceAll('\\', '/'))}; };`);
objects.push(`${memoryProduct} = {isa = XCSwiftPackageProductDependency; package = ${memoryPackage}; productName = BlindMemory; };`);
objects.push(`${memoryFramework} = {isa = PBXBuildFile; productRef = ${memoryProduct}; };`);
function replaceOnce(pattern, replacement) {
  if (!pattern.test(pbx)) throw new Error(`Pinned upstream project no longer matches ${pattern}`);
  pbx = pbx.replace(pattern, replacement);
}
replaceOnce(/objects = \{/, `objects = {\n${objects.join('\n')}`);
replaceOnce(/(isa = PBXSourcesBuildPhase;[\s\S]*?files = \()/, `$1\n${builds.map(build => `${build},`).join('\n')}`);
replaceOnce(/(isa = PBXFrameworksBuildPhase;[\s\S]*?files = \()/, `$1\n${framework},${memoryFramework},`);
replaceOnce(/packageReferences = \(/, `packageReferences = (\n${pkg},${memoryPackage},`);
replaceOnce(/packageProductDependencies = \(/, `packageProductDependencies = (\n${product},${memoryProduct},`);
pbx = pbx.replace(/IPHONEOS_DEPLOYMENT_TARGET = [^;]+;/g, 'IPHONEOS_DEPLOYMENT_TARGET = 17.0;')
  .replace(/DEVELOPMENT_TEAM = [^;]+;/g, 'DEVELOPMENT_TEAM = "";')
  .replace(/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/g, 'PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility.native;')
  .replace(/CODE_SIGN_ENTITLEMENTS = [^;]+;/g, 'CODE_SIGN_ENTITLEMENTS = "";')
  .replace(/SWIFT_ACTIVE_COMPILATION_CONDITIONS = ([^;]*);/g, (_all, flags) => `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "${flags.replaceAll('"', '')} BLIND_RTABMAP";`);
if (process.argv.includes('--multimodal')) pbx = pbx.replaceAll('BLIND_RTABMAP', 'BLIND_RTABMAP BLIND_APPLE_MULTIMODAL');
await writeFile(project, pbx);
await copyFile(join(root, 'integration/MobilitySceneDelegate.swift'), join(base, 'RTABMapApp/SceneDelegate.swift'));
const plistPath = join(base, 'RTABMapApp/Info.plist');
let plist = await readFile(plistPath, 'utf8');
plist = plist.replace(/\s*<key>UISceneStoryboardFile<\/key>\s*<string>[^<]*<\/string>/g, '')
  .replace(/\s*<key>UIMainStoryboardFile<\/key>\s*<string>[^<]*<\/string>/g, '');
if (!plist.includes('NSBluetoothAlwaysUsageDescription')) plist = plist.replace('<dict>', '<dict>\n<key>NSBluetoothAlwaysUsageDescription</key><string>Connect to your mobility belt and wristband.</string>');
for (const [key, value] of Object.entries({
  NSMicrophoneUsageDescription: 'Record a spoken question only when you tap Talk.',
  NSSpeechRecognitionUsageDescription: 'Transcribe your question on this phone when offline recognition is available.',
  NSLocationWhenInUseUsageDescription: 'Find outdoor destinations and provide directional audio.'
})) if (!plist.includes(`<key>${key}</key>`)) plist = plist.replace('<dict>', `<dict>\n<key>${key}</key><string>${value}</string>`);
plist = plist.replace(/(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*(<\/string>)/, '$1Blind Assist$2');
// The camera adapter assumes portrait. Do not inherit upstream rotation settings.
plist = plist.replace(/(<key>UISupportedInterfaceOrientations<\/key>\s*)<array>[\s\S]*?<\/array>/,
  '$1<array><string>UIInterfaceOrientationPortrait</string></array>');
await writeFile(plistPath, plist);
console.log(`Prepared native mobility target at ${project}\nOn a Mac, build upstream iOS dependencies using RTABMapApp/install_deps.sh, then build this Xcode target. No iOS binary was built by this command.`);
