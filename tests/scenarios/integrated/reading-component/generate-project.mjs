import {readFile,writeFile,mkdir,cp,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url));
const source=resolve(process.argv[2]), out=resolve(process.argv[3]);
if(out===source || out.startsWith(source+"/")) throw new Error("Output must be outside source");
try { await stat(out); throw new Error('Output already exists; preserve failures'); } catch(e) { if(e.code!=='ENOENT') throw e; }
const pins=JSON.parse(await readFile(join(here,'source-pins.json'),'utf8'));
for(const [path,expected] of Object.entries(pins.files)) {
 const b=await readFile(join(source,path)); const actual=createHash('sha1').update(Buffer.from('blob '+b.length+'\0')).update(b).digest('hex');
 if(actual!==expected) throw new Error('Source review required: '+path);
}
await mkdir(out,{recursive:true});
await cp(join(source,'BlindCore'),join(out,'BlindCore'),{recursive:true,filter:p=>!p.split('/').some(x=>['.build','.swiftpm'].includes(x))});
await writeFile(join(out,'CapturedTextNativeComponentTests.swift'),await readFile(join(here,'CapturedTextNativeComponentTests.swift')));
await writeFile(join(out,'Host.swift'),`import SwiftUI
@main struct ComponentHost: App { var body: some Scene { WindowGroup { Color.clear } } }
`);
const objects = [], id = name => createHash('sha256').update(name).digest('hex').slice(0,24).toUpperCase();
const add = (name, body) => { objects.push(`${id(name)} = { ${body} };`); return id(name); };
const refs = [], builds = {};
for (const name of ['Host.swift', 'CapturedTextNativeComponentTests.swift']) {
  const ref = add(name, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${name}"; sourceTree = "<group>";`);
  refs.push(ref); builds[name] = add('build:'+name, `isa = PBXBuildFile; fileRef = ${ref};`);
}
const hostProduct = add('host-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = ReadingComponentHost.app; sourceTree = BUILT_PRODUCTS_DIR;');
const testProduct = add('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = ReadingComponentTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
const group = add('group', `isa = PBXGroup; children = (${[...refs,hostProduct,testProduct].join(',')},); sourceTree = "<group>";`);
const common = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_NAME = "$(TARGET_NAME)"; CODE_SIGNING_ALLOWED = NO; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES;';
const config = (name, settings) => {
  const c = add(name+'-debug', `isa = XCBuildConfiguration; name = Debug; buildSettings = { ${settings} };`);
  return add(name+'-configs', `isa = XCConfigurationList; buildConfigurations = (${c},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;`);
};
const hostConfig = config('host', common + ' PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.readingcomponent.host; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES;');
const testConfig = config('test', common + ' PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.readingcomponent.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ReadingComponentHost.app/ReadingComponentHost"; BUNDLE_LOADER = "$(TEST_HOST)";');
const projectConfig = config('project', '');
const sources = (name, files) => add(name+'-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${files.map(f=>builds[f]).join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
const hostSources = sources('host', ['Host.swift']);
const testSources = sources('test', ['CapturedTextNativeComponentTests.swift']);
const host = add('host', `isa = PBXNativeTarget; buildConfigurationList = ${hostConfig}; buildPhases = (${hostSources},); buildRules = (); dependencies = (); name = ReadingComponentHost; productName = ReadingComponentHost; productReference = ${hostProduct}; productType = "com.apple.product-type.application";`);
const proxy = add('proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${host}; remoteInfo = ReadingComponentHost;`);
const dependency = add('dependency', `isa = PBXTargetDependency; target = ${host}; targetProxy = ${proxy};`);
const corePackage = add('core-package', 'isa = XCLocalSwiftPackageReference; relativePath = BlindCore;');
const coreProduct = add('core-product', `isa = XCSwiftPackageProductDependency; package = ${corePackage}; productName = BlindCore;`);
const coreBuild = add('core-build', `isa = PBXBuildFile; productRef = ${coreProduct};`);
const frameworks = add('test-frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${coreBuild},); runOnlyForDeploymentPostprocessing = 0;`);
const tests = add('tests', `isa = PBXNativeTarget; buildConfigurationList = ${testConfig}; buildPhases = (${testSources},${frameworks},); packageProductDependencies = (${coreProduct},); buildRules = (); dependencies = (${dependency},); name = ReadingComponentTests; productName = ReadingComponentTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
const project = add('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${tests} = { TestTargetID = ${host}; }; }; }; buildConfigurationList = ${projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = ${group}; projectDirPath = ""; projectRoot = ""; packageReferences = (${corePackage},); targets = (${host},${tests},);`);
const bundle = join(out,'ReadingComponent.xcodeproj');
await mkdir(join(bundle,'xcshareddata/xcschemes'), {recursive:true});
await writeFile(join(bundle,'project.pbxproj'), `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${project}; }\n`);
const ref = (target,name) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="${name}" BlueprintName="${name.replace(/\.(app|xctest)$/,'')}" ReferencedContainer="container:ReadingComponent.xcodeproj"/>`;
await writeFile(join(bundle,'xcshareddata/xcschemes/ReadingComponent.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">${ref(host,'ReadingComponentHost.app')}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">${ref(tests,'ReadingComponentTests.xctest')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">${ref(tests,'ReadingComponentTests.xctest')}</TestableReference></Testables></TestAction>
</Scheme>
`);
console.log('Generated isolated Core plus test-owned AVSpeech component host; no app controller or gate changes.');
