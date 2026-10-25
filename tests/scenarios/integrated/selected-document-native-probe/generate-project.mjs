import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
if (!process.argv[2]) throw new Error('A fresh output directory is required');
const out = resolve(process.argv[2]);
if (out === here || out.startsWith(here + '/')) throw new Error('Output must be outside the immutable packet');
try { await stat(out); throw new Error('Output exists; preserve prior evidence'); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
const pins = JSON.parse(await readFile(join(here, 'source-pins.json'), 'utf8'));
const files = {};
for (const [path, pin] of Object.entries(pins.files)) {
  const bytes = await readFile(join(here, path));
  if (createHash('sha256').update(bytes).digest('hex') !== pin.sha256) throw new Error('Exact snapshot review required: ' + path);
  files[path] = bytes;
}
const testText = files['Tests/SelectedDocumentPDFTests.swift'].toString('utf8');
if (pins.expectedNativeTests !== 14 || (testText.match(/func test[A-Za-z0-9_]*\(/g) || []).length !== 14) throw new Error('Expected exactly fourteen frozen tests');
if (!testText.includes('@testable import BlindAssist')) throw new Error('Preserve original test module');
await mkdir(out, { recursive: true });
for (const [path, bytes] of Object.entries(files)) {
  await mkdir(dirname(join(out, path)), { recursive: true });
  await writeFile(join(out, path), bytes);
}
await writeFile(join(out, 'Host.swift'), `import SwiftUI
@main struct PDFProbeHost: App {
    var body: some Scene { WindowGroup { Color.clear } }
}
`);
await writeFile(join(out, 'copied-source-pins.json'), JSON.stringify(pins, null, 2) + '\n');
const objects = [], id = name => createHash('sha256').update(name).digest('hex').slice(0, 24).toUpperCase();
const add = (name, body) => { objects.push(`${id(name)} = { ${body} };`); return id(name); };
const refs = [], builds = {};
for (const name of ['Host.swift', ...Object.keys(files)]) {
  const ref = add(name, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${name}"; sourceTree = "<group>";`);
  refs.push(ref); builds[name] = add('build:' + name, `isa = PBXBuildFile; fileRef = ${ref};`);
}
const hostProduct = add('host-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = BlindAssist.app; sourceTree = BUILT_PRODUCTS_DIR;');
const testProduct = add('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = SelectedDocumentNativeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
const group = add('group', `isa = PBXGroup; children = (${[...refs, hostProduct, testProduct].join(',')},); sourceTree = "<group>";`);
// The host MODULE stays BlindAssist for the unchanged @testable import. Its
// bundle identity, sources and empty scene are isolated from the real app.
const common = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_NAME = "$(TARGET_NAME)"; CODE_SIGNING_ALLOWED = NO; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES; ONLY_ACTIVE_ARCH = YES;';
const config = (name, settings) => {
  const debug = add(name + '-debug', `isa = XCBuildConfiguration; name = Debug; buildSettings = { ${settings} };`);
  return add(name + '-configs', `isa = XCConfigurationList; buildConfigurations = (${debug},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;`);
};
const hostConfig = config('host', common + ' PRODUCT_MODULE_NAME = BlindAssist; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.selectedpdfprobe.host; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES;');
const testConfig = config('tests', common + ' PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.selectedpdfprobe.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/BlindAssist.app/BlindAssist"; BUNDLE_LOADER = "$(TEST_HOST)";');
const projectConfig = config('project', '');
const sources = (name, names) => add(name + '-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${names.map(n => builds[n]).join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
const hostSources = sources('host', ['Host.swift', 'Sources/SelectedDocumentPDFAdapter.swift', 'Sources/SelectedDocumentPicker.swift']);
const testSources = sources('tests', ['Tests/SelectedDocumentPDFTests.swift']);
const host = add('host', `isa = PBXNativeTarget; buildConfigurationList = ${hostConfig}; buildPhases = (${hostSources},); buildRules = (); dependencies = (); name = BlindAssist; productName = BlindAssist; productReference = ${hostProduct}; productType = "com.apple.product-type.application";`);
const proxy = add('proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${host}; remoteInfo = BlindAssist;`);
const dependency = add('dependency', `isa = PBXTargetDependency; target = ${host}; targetProxy = ${proxy};`);
const tests = add('tests', `isa = PBXNativeTarget; buildConfigurationList = ${testConfig}; buildPhases = (${testSources},); buildRules = (); dependencies = (${dependency},); name = SelectedDocumentNativeTests; productName = SelectedDocumentNativeTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
const project = add('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${tests} = { TestTargetID = ${host}; }; }; }; buildConfigurationList = ${projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = ${group}; projectDirPath = ""; projectRoot = ""; targets = (${host},${tests},);`);
const bundle = join(out, 'SelectedDocumentProbe.xcodeproj');
await mkdir(join(bundle, 'xcshareddata/xcschemes'), { recursive: true });
await writeFile(join(bundle, 'project.pbxproj'), `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${project}; }\n`);
const ref = (target, name, blueprint) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="${name}" BlueprintName="${blueprint}" ReferencedContainer="container:SelectedDocumentProbe.xcodeproj"/>`;
await writeFile(join(bundle, 'xcshareddata/xcschemes/SelectedDocumentProbe.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">${ref(host, 'BlindAssist.app', 'BlindAssist')}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">${ref(tests, 'SelectedDocumentNativeTests.xctest', 'SelectedDocumentNativeTests')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">${ref(tests, 'SelectedDocumentNativeTests.xctest', 'SelectedDocumentNativeTests')}</TestableReference></Testables></TestAction>
</Scheme>
`);
console.log('Prepared exact three-file PDFKit and picker-delegate probe; no app controller, Core package, database or model.');
