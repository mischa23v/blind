import { readdir, mkdir, writeFile, readFile, stat, lstat, realpath, open, opendir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { resolve, join, dirname, basename, isAbsolute, sep } from 'node:path';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const id = name => createHash('sha256').update(name).digest('hex').slice(0, 24).toUpperCase();
export function generateProject(files, { multimodal = false, familiarPeople = false, familiarBackend = 'sface', opencvFramework, familiarModels, currencyReference = false, currencyReferencePack, currencyDeviceTest = false, currencyReferencePackSHA256, liveActivity = false, objectDetector, objectDetectorSHA256, objectDetectorManifestSHA256 } = {}) {
  if (familiarPeople && (!opencvFramework || !familiarModels)) throw new Error('Experimental people requires explicit framework and model paths.');
  if (!['sface', 'auraface'].includes(familiarBackend)) throw new Error('Unknown familiar backend.');
  if (!familiarPeople && familiarBackend !== 'sface') throw new Error('AuraFace requires --familiar-people.');
  const nativeEnabled = familiarPeople || currencyReference;
  if (nativeEnabled && (!opencvFramework || !isAbsolute(opencvFramework) || basename(opencvFramework) !== 'opencv2.framework')) throw new Error('Native inference requires an explicit absolute opencv2.framework path.');
  if (currencyReferencePack && !currencyReference) throw new Error('A reference pack requires --currency-reference.');
  if (currencyReferencePack && (!isAbsolute(currencyReferencePack) || basename(currencyReferencePack) !== 'SaudiBanknoteReferences')) throw new Error('The reference folder must be named SaudiBanknoteReferences.');
  if (currencyDeviceTest && (!currencyReference || !currencyReferencePack)) throw new Error('Device testing requires --currency-reference and --currency-reference-pack.');
  if (currencyDeviceTest && (typeof currencyReferencePackSHA256 !== 'string' || !/^[a-f0-9]{64}$/.test(currencyReferencePackSHA256))) throw new Error('Device testing requires the verified reference manifest SHA-256.');
  if (!currencyDeviceTest && currencyReferencePackSHA256 !== undefined) throw new Error('A device-test manifest pin requires --currency-device-test.');
  if (objectDetector) {
    if (!isAbsolute(objectDetector) || /[\p{Cc}$]/u.test(objectDetector) || !['Detector.mlmodel', 'Detector.mlmodelc'].includes(basename(objectDetector))) throw new Error('Use an absolute Detector.mlmodel or Detector.mlmodelc path.');
    if (![objectDetectorSHA256, objectDetectorManifestSHA256].every(value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value))) throw new Error('Object detector requires verified artifact and manifest hashes.');
  } else if (objectDetectorSHA256 !== undefined || objectDetectorManifestSHA256 !== undefined) throw new Error('Detector hashes require --object-detector.');
  const objects = [], add = (name, body) => { objects.push(`${id(name)} = { ${body} };`); return id(name); };
  const refs = [], sources = [];
  for (const file of files) {
    const ref = add(file, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${JSON.stringify(`BlindAssist/${file}`)}; sourceTree = "<group>";`);
    refs.push(ref); sources.push(add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${ref};`));
  }
  // Optional Lock Screen / Dynamic Island status (--live-activity): a WidgetKit extension plus
  // attributes shared with the app. Off by default so the standard build has no extension target.
  const activityFiles = ['CompanionActivityAttributes.swift', 'CompanionLiveActivityWidget.swift'];
  const activityRefs = [];
  if (liveActivity) {
    for (const file of activityFiles) activityRefs.push(add(`activity:${file}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${JSON.stringify(`BlindAssistLiveActivity/${file}`)}; sourceTree = "<group>";`));
    sources.push(add('build:app-activity-attributes', `isa = PBXBuildFile; fileRef = ${activityRefs[0]};`));
  }
  const nativeFrameworkBuilds = [], resourceBuilds = [];
  if (objectDetector) {
    // .mlmodel is compiled by Xcode; a precompiled bundle is copied intact. No
    // sibling directory, manifest, sample image or model download is included.
    const compiled = objectDetector.endsWith('.mlmodelc');
    const ref = add('object-detector', `isa = PBXFileReference; lastKnownFileType = ${compiled ? 'folder' : 'file.mlmodel'}; path = ${JSON.stringify(objectDetector)}; sourceTree = "<absolute>";`);
    refs.push(ref);
    (compiled ? resourceBuilds : sources).push(add('build:object-detector', `isa = PBXBuildFile; fileRef = ${ref};`));
  }
  if (familiarPeople) {
    const notice = add('face-notice', 'isa = PBXFileReference; lastKnownFileType = text; path = BlindAssist/FamiliarNative/MODEL_NOTICES.txt; sourceTree = "<group>";');
    refs.push(notice); resourceBuilds.push(add('build:face-notice', `isa = PBXBuildFile; fileRef = ${notice};`));
    const native = add('face-native', 'isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.objcpp; path = BlindAssist/FamiliarNative/BAFaceEngine.mm; sourceTree = "<group>";');
    refs.push(native); sources.push(add('build:face-native', `isa = PBXBuildFile; fileRef = ${native};`));
    for (const name of Object.keys(familiarHashesForBackend(familiarBackend))) {
      const ref = add(`face-model:${name}`, `isa = PBXFileReference; lastKnownFileType = file; path = ${JSON.stringify(join(familiarModels, name))}; sourceTree = "<absolute>";`);
      refs.push(ref); resourceBuilds.push(add(`build:face-model:${name}`, `isa = PBXBuildFile; fileRef = ${ref};`));
    }
  }
  if (currencyReference) {
    const native = add('currency-native', 'isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.objcpp; path = BlindAssist/CurrencyNative/BACurrencyReferenceEngine.mm; sourceTree = "<group>";');
    refs.push(native); sources.push(add('build:currency-native', `isa = PBXBuildFile; fileRef = ${native};`));
    const notice = add('currency-notice', 'isa = PBXFileReference; lastKnownFileType = text; path = BlindAssist/CurrencyNative/THIRD_PARTY_NOTICES.txt; sourceTree = "<group>";');
    refs.push(notice); resourceBuilds.push(add('build:currency-notice', `isa = PBXBuildFile; fileRef = ${notice};`));
    if (currencyReferencePack) {
      // A folder reference copies the reviewed private directory intact, not its
      // contents flattened into the bundle. No copy or activation occurs here.
      const pack = add('currency-pack', `isa = PBXFileReference; lastKnownFileType = folder; path = ${JSON.stringify(currencyReferencePack)}; sourceTree = "<absolute>";`);
      refs.push(pack); resourceBuilds.push(add('build:currency-pack', `isa = PBXBuildFile; fileRef = ${pack};`));
    }
  }
  if (nativeEnabled) {
    const framework = add('opencv-framework', `isa = PBXFileReference; lastKnownFileType = wrapper.framework; path = ${JSON.stringify(opencvFramework)}; sourceTree = "<absolute>";`);
    refs.push(framework); nativeFrameworkBuilds.push(add('build:opencv', `isa = PBXBuildFile; fileRef = ${framework};`));
    for (const name of ['UIKit', 'Accelerate', 'CoreGraphics', 'QuartzCore', ...(currencyReference ? ['ImageIO'] : [])]) {
      const ref = add(`face-framework:${name}`, `isa = PBXFileReference; lastKnownFileType = wrapper.framework; path = System/Library/Frameworks/${name}.framework; sourceTree = SDKROOT;`);
      refs.push(ref); nativeFrameworkBuilds.push(add(`build:face-framework:${name}`, `isa = PBXBuildFile; fileRef = ${ref};`));
    }
  }
  const resourcesPhase = add('resources', `isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (${resourceBuilds.join(',')}${resourceBuilds.length ? ',' : ''}); runOnlyForDeploymentPostprocessing = 0;`);
  const conditions = ['$(inherited)', ...(multimodal ? ['BLIND_APPLE_MULTIMODAL'] : []), ...(familiarPeople ? ['BLIND_FAMILIAR_PEOPLE'] : []), ...(familiarPeople && familiarBackend === 'auraface' ? ['BLIND_FAMILIAR_AURAFACE'] : []), ...(currencyReference ? ['BLIND_CURRENCY_REFERENCE'] : []), ...(liveActivity ? ['BLIND_LIVE_ACTIVITY'] : [])].join(' ');
  const nativeDefinitions = ['$(inherited)', ...(familiarPeople ? ['BLIND_FAMILIAR_PEOPLE=1'] : []), ...(currencyReference ? ['BLIND_CURRENCY_REFERENCE=1'] : [])];
  const bridge = currencyReference ? 'BlindAssist/CurrencyNative/BlindAssist-Currency-Bridging-Header.h' : 'BlindAssist/FamiliarNative/BlindAssist-Bridging-Header.h';
  const nativeSettings = nativeEnabled ? `SWIFT_OBJC_BRIDGING_HEADER = ${bridge}; GCC_PREPROCESSOR_DEFINITIONS = (${nativeDefinitions.map(value => JSON.stringify(value)).join(',')},); CLANG_CXX_LANGUAGE_STANDARD = "c++17"; CLANG_CXX_LIBRARY = "libc++"; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; GCC_ENABLE_CPP_EXCEPTIONS = YES; FRAMEWORK_SEARCH_PATHS = ("$(inherited)",${JSON.stringify(dirname(opencvFramework))},); OTHER_LDFLAGS = ("$(inherited)","-lc++",); "EXCLUDED_ARCHS[sdk=iphonesimulator*]" = arm64;` : '';
  const product = add('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = BlindAssist.app; sourceTree = BUILT_PRODUCTS_DIR;');
  const pkg = add('package', 'isa = XCLocalSwiftPackageReference; relativePath = ../BlindCore;');
  const dependency = add('dependency', `isa = XCSwiftPackageProductDependency; package = ${pkg}; productName = BlindCore;`);
  const lib = add('lib', `isa = PBXBuildFile; productRef = ${dependency};`);
  const memoryPackage = add('memory-package', 'isa = XCLocalSwiftPackageReference; relativePath = ../BlindMemory;');
  const memoryDependency = add('memory-dependency', `isa = XCSwiftPackageProductDependency; package = ${memoryPackage}; productName = BlindMemory;`);
  const memoryLibrary = add('memory-lib', `isa = PBXBuildFile; productRef = ${memoryDependency};`);
  const sourcesPhase = add('sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${sources.join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
  const frameworksPhase = add('frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${lib},${memoryLibrary},${nativeFrameworkBuilds.join(",")}${nativeFrameworkBuilds.length ? "," : ""}); runOnlyForDeploymentPostprocessing = 0;`);
  let activityTarget, activityEmbed;
  if (liveActivity) {
    const activityProduct = add('activity-product', 'isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = BlindAssistLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR;');
    const activityPlist = add('activity-plist', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = BlindAssistLiveActivity/Info.plist; sourceTree = "<group>";');
    refs.push(...activityRefs, activityPlist, activityProduct);
    const activitySources = add('activity-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${activityRefs.map((ref, index) => add(`build:activity:${activityFiles[index]}`, `isa = PBXBuildFile; fileRef = ${ref};`)).join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
    const activityFrameworks = add('activity-frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;');
    const activityConfigs = ['Debug', 'Release'].map(name => add(`activity-${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) BLIND_LIVE_ACTIVITY${name === 'Debug' ? ' DEBUG' : ''}"; TARGETED_DEVICE_FAMILY = "1"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility.liveactivity; INFOPLIST_FILE = BlindAssistLiveActivity/Info.plist; APPLICATION_EXTENSION_API_ONLY = YES; SKIP_INSTALL = YES; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)","@executable_path/Frameworks","@executable_path/../../Frameworks",); CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = YES; SWIFT_OPTIMIZATION_LEVEL = "${name === 'Debug' ? '-Onone' : '-O'}"; };`));
    const activityConfigList = add('activity-configs', `isa = XCConfigurationList; buildConfigurations = (${activityConfigs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
    activityTarget = add('activity-target', `isa = PBXNativeTarget; buildConfigurationList = ${activityConfigList}; buildPhases = (${activitySources},${activityFrameworks},); buildRules = (); dependencies = (); name = BlindAssistLiveActivity; productName = BlindAssistLiveActivity; productReference = ${activityProduct}; productType = "com.apple.product-type.app-extension";`);
    const activityProxy = add('activity-proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${activityTarget}; remoteInfo = BlindAssistLiveActivity;`);
    add('activity-dep', `isa = PBXTargetDependency; target = ${activityTarget}; targetProxy = ${activityProxy};`);
    const embedBuild = add('build:activity-embed', `isa = PBXBuildFile; fileRef = ${activityProduct}; settings = { ATTRIBUTES = (RemoveHeadersOnCopy,); };`);
    activityEmbed = add('activity-embed', `isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = (${embedBuild},); name = "Embed Foundation Extensions"; runOnlyForDeploymentPostprocessing = 0;`);
  }
  const group = add('group', `isa = PBXGroup; children = (${refs.join(',')},${product},${id('ui-file')},${id('ui-product')},${id('unit-file')},${id('unit-product')},); sourceTree = "<group>";`);
  const configs = [];
  for (const name of ['Debug', 'Release']) {
    // Adult-configured private device trial only. Release receives neither the
    // activation flag nor a manifest pin; the production profile remains nil.
    const deviceTest = currencyDeviceTest && name === 'Debug';
    const configurationConditions = conditions + (name === 'Debug' ? ' DEBUG' : '') + (deviceTest ? ' BLIND_CURRENCY_DEVICE_TEST' : '');
    const deviceSettings = (deviceTest ? `CURRENCY_REFERENCE_PACK_SHA256 = "${currencyReferencePackSHA256}";` : '') +
      (objectDetector ? ` OBJECT_DETECTOR_SHA256 = "${objectDetectorSHA256}"; OBJECT_DETECTOR_MANIFEST_SHA256 = "${objectDetectorManifestSHA256}";` : '');
    configs.push(add(name, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "${configurationConditions}"; ${deviceSettings} ${nativeSettings} TARGETED_DEVICE_FAMILY = "1"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility; INFOPLIST_FILE = BlindAssist/Info.plist; CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = YES; ENABLE_TESTABILITY = ${name === 'Debug' ? 'YES' : 'NO'}; ONLY_ACTIVE_ARCH = ${name === 'Debug' ? 'YES' : 'NO'}; SWIFT_OPTIMIZATION_LEVEL = "${name === 'Debug' ? '-Onone' : '-O'}"; };`));
  }
  const configList = add('configs', `isa = XCConfigurationList; buildConfigurations = (${configs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
  const target = add('target', `isa = PBXNativeTarget; buildConfigurationList = ${configList}; buildPhases = (${sourcesPhase},${frameworksPhase},${resourcesPhase},${activityEmbed ? `${activityEmbed},` : ''}); buildRules = (); dependencies = (${activityTarget ? `${id('activity-dep')},` : ''}); name = BlindAssist; productName = BlindAssist; productReference = ${product}; productType = "com.apple.product-type.application"; packageProductDependencies = (${dependency},${memoryDependency},);`);
  const uiFile = add('ui-file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BlindAssistUITests/LaunchTests.swift; sourceTree = SOURCE_ROOT;');
  const uiBuild = add('ui-build', `isa = PBXBuildFile; fileRef = ${uiFile};`);
  const uiSources = add('ui-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${uiBuild},); runOnlyForDeploymentPostprocessing = 0;`);
  const uiProduct = add('ui-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = BlindAssistUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
  const uiConfigs = ['Debug', 'Release'].map(name => add(`ui-${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited)${name === 'Debug' ? ' DEBUG' : ''}"; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = ""; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility.uitests; TEST_TARGET_NAME = BlindAssist; CODE_SIGN_STYLE = Automatic; };`));
  const uiConfigList = add('ui-configs', `isa = XCConfigurationList; buildConfigurations = (${uiConfigs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
  const proxy = add('ui-proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${target}; remoteInfo = BlindAssist;`);
  const dependencyTarget = add('ui-dep', `isa = PBXTargetDependency; target = ${target}; targetProxy = ${proxy};`);
  const uiTarget = add('ui-target', `isa = PBXNativeTarget; buildConfigurationList = ${uiConfigList}; buildPhases = (${uiSources},); buildRules = (); dependencies = (${dependencyTarget},); name = BlindAssistUITests; productName = BlindAssistUITests; productReference = ${uiProduct}; productType = "com.apple.product-type.bundle.ui-testing";`);
  const unitFile = add('unit-file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BlindAssistTests/CommunityTests.swift; sourceTree = SOURCE_ROOT;');
  const unitBuild = add('unit-build', `isa = PBXBuildFile; fileRef = ${unitFile};`);
  const replayFile = add('unit-replay-file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BlindAssistTests/CompanionNativeReplayTests.swift; sourceTree = SOURCE_ROOT;');
  const replayBuild = add('unit-replay-build', `isa = PBXBuildFile; fileRef = ${replayFile};`);
  const unitSources = add('unit-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${unitBuild},${replayBuild},); runOnlyForDeploymentPostprocessing = 0;`);
  const unitProduct = add('unit-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = BlindAssistTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
  const unitCore = add('unit-core', `isa = XCSwiftPackageProductDependency; package = ${pkg}; productName = BlindCore;`);
  const unitCoreBuild = add('unit-core-build', `isa = PBXBuildFile; productRef = ${unitCore};`);
  const unitFrameworks = add('unit-frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${unitCoreBuild},); runOnlyForDeploymentPostprocessing = 0;`);
  const unitConfigs = ['Debug', 'Release'].map(name => add(`unit-${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited)${name === 'Debug' ? ' DEBUG' : ''}"; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = ""; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/BlindAssist.app/BlindAssist"; BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; };`));
  const unitConfigList = add('unit-configs', `isa = XCConfigurationList; buildConfigurations = (${unitConfigs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;`);
  const unitDependency = add('unit-dep', `isa = PBXTargetDependency; target = ${target}; targetProxy = ${proxy};`);
  const unitTarget = add('unit-target', `isa = PBXNativeTarget; buildConfigurationList = ${unitConfigList}; buildPhases = (${unitSources},${unitFrameworks},); buildRules = (); dependencies = (${unitDependency},); name = BlindAssistTests; productName = BlindAssistTests; productReference = ${unitProduct}; productType = "com.apple.product-type.bundle.unit-test"; packageProductDependencies = (${unitCore},);`);
  const project = add('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${uiTarget} = { TestTargetID = ${target}; }; ${unitTarget} = { TestTargetID = ${target}; }; }; }; buildConfigurationList = ${configList}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, ar, Base); mainGroup = ${group}; projectDirPath = ""; projectRoot = ""; packageReferences = (${pkg},${memoryPackage},); targets = (${target},${uiTarget},${unitTarget},${activityTarget ? `${activityTarget},` : ''});`);
  let result = `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${project}; }\n`;
  return result;
}
export function generateScheme() {
  const target = id('target');
  const reference = `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="BlindAssist.app" BlueprintName="BlindAssist" ReferencedContainer="container:BlindAssist.xcodeproj"/>`;
  return `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id('unit-target')}" BuildableName="BlindAssistTests.xctest" BlueprintName="BlindAssistTests" ReferencedContainer="container:BlindAssist.xcodeproj"/></TestableReference><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id('ui-target')}" BuildableName="BlindAssistUITests.xctest" BlueprintName="BlindAssistUITests" ReferencedContainer="container:BlindAssist.xcodeproj"/></TestableReference></Testables><CommandLineArguments><CommandLineArgument argument="--ui-testing" isEnabled="YES"/></CommandLineArguments></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n`;
}
export const familiarModelHashes = Object.freeze({
  'face_detection_yunet_2023mar.onnx': '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
  'face_recognition_sface_2021dec.onnx': '0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79',
});
export function familiarHashesForBackend(backend = 'sface') {
  if (backend === 'sface') return familiarModelHashes;
  if (backend !== 'auraface') throw new Error('Unknown familiar backend.');
  return Object.freeze({
    'face_detection_yunet_2023mar.onnx': familiarModelHashes['face_detection_yunet_2023mar.onnx'],
    'glintr100.onnx': 'a7933ea5330113b01c9b60351d8f4c33003f145d8470ac5f0e52ee2effe25c60',
  });
}
export async function verifyOpenCVFramework(framework) {
  if (typeof framework !== 'string' || basename(framework) !== 'opencv2.framework' || !(await stat(framework)).isDirectory()) throw new Error('Use the verified static opencv2.framework, not a guessed SDK path.');
  const header = await readFile(join(framework, 'Headers/core/version.hpp'), 'utf8');
  if (!/#define CV_VERSION_MAJOR\s+4\b/.test(header) || !/#define CV_VERSION_MINOR\s+14\b/.test(header) || !/#define CV_VERSION_REVISION\s+0\b/.test(header)) throw new Error('OpenCV 4.14.0 required.');
  const binary = await stat(join(framework, 'opencv2'));
  if (!binary.isFile() || binary.size === 0) throw new Error('OpenCV framework binary is missing or empty.');
  // This checks version/layout, not provenance or redistribution clearance. The
  // externally obtained official archive must still have its receipt reviewed.
}
export async function verifyFamiliarInputs(framework, models, backend = 'sface') {
  await verifyOpenCVFramework(framework);
  for (const [name, expected] of Object.entries(familiarHashesForBackend(backend))) {
    if (createHash('sha256').update(await readFile(join(models, name))).digest('hex') !== expected) throw new Error(`Model hash mismatch: ${name}`);
  }
}
const packLimits = Object.freeze({ manifest: 256 * 1024, image: 8 * 1024 * 1024, total: 96 * 1024 * 1024, references: 48 });
const safePackPath = path => typeof path === 'string' && path.length > 0 && path.length <= 256
  && !/[\p{Cc}\\:%]/u.test(path) && !isAbsolute(path)
  && path.split('/').every(part => part && part !== '.' && part !== '..');
async function boundedPackFile(root, relative, limit) {
  if (!safePackPath(relative)) throw new Error('Unsafe reference pack path.');
  let current = root;
  for (const part of relative.split('/')) {
    current = join(current, part);
    if ((await lstat(current)).isSymbolicLink()) throw new Error('Reference pack symlinks are forbidden.');
  }
  const info = await lstat(current);
  if (!info.isFile() || info.size <= 0 || info.size > limit || !(await realpath(current)).startsWith(root + sep)) throw new Error('Invalid reference pack file or byte limit.');
  const handle = await open(current, 'r');
  try {
    const bytes = Buffer.alloc(info.size + 1);
    let length = 0;
    while (length < bytes.length) {
      const { bytesRead } = await handle.read(bytes, length, bytes.length - length, null);
      if (bytesRead === 0) break;
      length += bytesRead;
    }
    if (length !== info.size) throw new Error('Reference pack changed while reading.');
    return bytes.subarray(0, length);
  } finally { await handle.close(); }
}
export async function verifyCurrencyReferencePack(folder) {
  if (typeof folder !== 'string' || basename(folder) !== 'SaudiBanknoteReferences') throw new Error('The reference folder must be named SaudiBanknoteReferences.');
  const info = await lstat(folder);
  if (!info.isDirectory() || info.isSymbolicLink()) throw new Error('Reference pack must be a directory, not a symlink.');
  const root = await realpath(folder);
  const bytes = await boundedPackFile(root, 'manifest.json', packLimits.manifest);
  const manifest = JSON.parse(bytes.toString('utf8'));
  if (!manifest || manifest.schema_version !== 2 || manifest.reference_kind !== 'private_banknote_photos' || manifest.currency !== 'SAR'
      || JSON.stringify(manifest.labels) !== '[1,5,10,20,50,100,200,500]' || !Array.isArray(manifest.references)
      || manifest.references.length > packLimits.references) throw new Error('Invalid reference pack schema or inventory.');
  const expected = new Set(['manifest.json']), directories = new Set(), hashes = new Set();
  let total = 0;
  for (const ref of manifest.references) {
    if (!ref || !safePackPath(ref.path) || !/\.(?:png|jpe?g)$/i.test(ref.path) || expected.has(ref.path)
        || typeof ref.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(ref.sha256) || hashes.has(ref.sha256)) throw new Error('Invalid or duplicate reference image path/hash.');
    expected.add(ref.path); hashes.add(ref.sha256);
    const parts = ref.path.split('/');
    for (let i = 1; i < parts.length; i++) directories.add(parts.slice(0, i).join('/'));
    const image = await boundedPackFile(root, ref.path, packLimits.image);
    total += image.length;
    if (total > packLimits.total) throw new Error('Reference pack exceeds total byte limit.');
    if (createHash('sha256').update(image).digest('hex') !== ref.sha256) throw new Error('Reference image hash mismatch.');
  }
  // Folder resources copy every member. Reject stray images, hidden files,
  // symlinks and unlisted directories rather than accidentally packaging them.
  async function checkInventory(relative = '') {
    for await (const entry of await opendir(join(root, relative))) {
      const path = relative ? `${relative}/${entry.name}` : entry.name;
      if (entry.isDirectory() && directories.has(path)) await checkInventory(path);
      else if (!entry.isFile() || !expected.delete(path)) throw new Error('Unlisted or unsafe reference pack member.');
    }
  }
  await checkInventory();
  if (expected.size) throw new Error('Reference pack inventory is incomplete.');
  // Packaging preflight only. The runtime strict parser also validates duplicate
  // JSON keys, labels, metadata, review and boundaries against the pinned profile.
  return Object.freeze({ manifestSHA256: createHash('sha256').update(bytes).digest('hex'), references: manifest.references.length });
}
const detectorLimits = Object.freeze({ manifest: 256 * 1024, file: 256 * 1024 * 1024, total: 512 * 1024 * 1024, files: 256 });
const detectorSHA = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const detectorText = value => typeof value === 'string' && value.trim() === value && value.length > 0 && value.length <= 300 && !/[\p{Cc}]/u.test(value);
// Deliberately narrow compiled Core ML inventory. New compiler layouts require
// review, not a generic folder copy that could include private images or secrets.
const detectorCompiledPath = path => safePackPath(path) && /^(?:model\d+\/)*(?:(?:analytics\/)?coremldata\.bin|metadata\.json|model\.mil|model\.espresso\.(?:net|weights|shape)|weights\/(?:\d+-)?weight\.bin)$/.test(path);
async function hashDetectorFile(root, relative) {
  if (!safePackPath(relative)) throw new Error('Unsafe detector artifact path.');
  let current = root;
  for (const part of relative.split('/')) {
    current = join(current, part);
    if ((await lstat(current)).isSymbolicLink()) throw new Error('Detector symlinks are forbidden.');
  }
  const info = await lstat(current);
  if (!info.isFile() || info.size <= 0 || info.size > detectorLimits.file || !(await realpath(current)).startsWith(root + sep)) throw new Error('Invalid detector file or byte limit.');
  const handle = await open(current, 'r');
  try {
    const hash = createHash('sha256'), buffer = Buffer.alloc(64 * 1024);
    let length = 0;
    while (true) {
      const { bytesRead } = await handle.read(buffer, 0, buffer.length, null);
      if (!bytesRead) break;
      length += bytesRead;
      if (length > info.size) throw new Error('Detector changed while reading.');
      hash.update(buffer.subarray(0, bytesRead));
    }
    const final = await handle.stat();
    if (length !== info.size || final.size !== info.size || final.mtimeMs !== info.mtimeMs) throw new Error('Detector changed while reading.');
    return { sha256: hash.digest('hex'), bytes: length };
  } finally { await handle.close(); }
}

/// Packaging verification only: the manifest is a human-reviewed declaration,
/// not proof that the Core ML binary yields Vision object observations or is accurate.
export async function verifyObjectDetector(model, manifestPath) {
  if (typeof model !== 'string' || !isAbsolute(model) || /[\p{Cc}$]/u.test(model) || !['Detector.mlmodel', 'Detector.mlmodelc'].includes(basename(model))) throw new Error('Use an absolute Detector.mlmodel or Detector.mlmodelc path.');
  if (typeof manifestPath !== 'string' || !isAbsolute(manifestPath)) throw new Error('Object detector requires an explicit external manifest.');
  const modelInfo = await lstat(model), compiled = model.endsWith('.mlmodelc');
  if (modelInfo.isSymbolicLink() || (compiled ? !modelInfo.isDirectory() : !modelInfo.isFile())) throw new Error('Invalid detector artifact type or symlink.');
  const realModel = await realpath(model), realManifest = await realpath(manifestPath);
  const repository = await realpath(resolve(fileURLToPath(new URL('..', import.meta.url))));
  if (realModel.startsWith(repository + sep)) throw new Error('Keep the supplied detector outside the source repository.');
  if (realManifest === realModel || (compiled && realManifest.startsWith(realModel + sep))) throw new Error('Detector manifest must be external to the artifact.');
  const manifestRoot = await realpath(dirname(manifestPath));
  const bytes = await boundedPackFile(manifestRoot, basename(manifestPath), detectorLimits.manifest);
  const manifest = JSON.parse(bytes.toString('utf8'));
  if (!manifest || manifest.schema_version !== 1 || manifest.resource_kind !== 'vision_object_detector'
      || manifest.artifact_name !== basename(model) || !detectorSHA(manifest.artifact_sha256)
      || manifest.vision_output !== 'VNRecognizedObjectObservation' || manifest.postprocessing !== 'model_embedded_nms'
      || manifest.reviewed_for_bundling !== true) throw new Error('Invalid detector manifest or unsupported raw-tensor output contract.');
  if (!manifest.input || manifest.input.type !== 'image' || !detectorText(manifest.input.name)
      || !['RGB', 'BGR', 'grayscale'].includes(manifest.input.color_space)
      || ![manifest.input.width, manifest.input.height].every(value => Number.isSafeInteger(value) && value > 0 && value <= 4096)) throw new Error('Invalid detector image-input declaration.');
  if (!Array.isArray(manifest.labels) || !manifest.labels.length || manifest.labels.length > 1000
      || !manifest.labels.every(value => detectorText(value) && value.length <= 80 && /^[\p{L}\p{N}][\p{L}\p{N} _'\-]*$/u.test(value))
      || new Set(manifest.labels.map(value => value.toLowerCase())).size !== manifest.labels.length) throw new Error('Invalid or duplicate detector labels.');
  let source;
  try { source = new URL(manifest.source_url); } catch { throw new Error('Detector source URL is required.'); }
  if (source.protocol !== 'https:' || source.username || source.password || source.search || source.hash
      || ![manifest.source_revision, manifest.model_license, manifest.data_license].every(detectorText)) throw new Error('Detector provenance and separate model/data licenses are required; secret-bearing URLs are forbidden.');
  if (!Array.isArray(manifest.files) || !manifest.files.length || manifest.files.length > detectorLimits.files
      || (!compiled && (manifest.files.length !== 1 || manifest.files[0]?.path !== 'Detector.mlmodel'))) throw new Error('Invalid detector inventory.');
  const root = compiled ? realModel : await realpath(dirname(model));
  const expected = new Set(), directories = new Set(), hashes = [];
  let total = 0;
  for (const file of manifest.files) {
    if (!file || !safePackPath(file.path) || (compiled && !detectorCompiledPath(file.path)) || expected.has(file.path) || !detectorSHA(file.sha256)) throw new Error('Unlisted, duplicate or unsafe detector artifact member.');
    expected.add(file.path);
    const parts = file.path.split('/');
    for (let i = 1; i < parts.length; i++) directories.add(parts.slice(0, i).join('/'));
    const actual = await hashDetectorFile(root, file.path);
    total += actual.bytes;
    if (total > detectorLimits.total) throw new Error('Detector artifact exceeds total byte limit.');
    if (actual.sha256 !== file.sha256) throw new Error('Detector artifact hash mismatch.');
    hashes.push(`${file.path}\0${actual.sha256}\n`);
  }
  if (compiled) {
    if (!expected.has('coremldata.bin')) throw new Error('Compiled detector lacks coremldata.bin.');
    async function checkInventory(relative = '') {
      for await (const entry of await opendir(join(root, relative))) {
        const path = relative ? `${relative}/${entry.name}` : entry.name;
        if (entry.isDirectory() && directories.has(path)) await checkInventory(path);
        else if (!entry.isFile() || !expected.delete(path)) throw new Error('Unlisted or unsafe detector artifact member.');
      }
    }
    await checkInventory();
    if (expected.size) throw new Error('Detector artifact inventory is incomplete.');
  }
  const artifactSHA256 = compiled ? createHash('sha256').update(hashes.sort().join('')).digest('hex') : manifest.files[0].sha256;
  if (manifest.artifact_sha256 !== artifactSHA256) throw new Error('Detector artifact inventory hash mismatch.');
  return Object.freeze({ artifactSHA256, manifestSHA256: createHash('sha256').update(bytes).digest('hex'), labels: manifest.labels.length, compiled, bytes: total });
}

export function parseProjectArguments(args) {
  const booleans = new Set(['--multimodal', '--familiar-people', '--currency-reference', '--currency-device-test', '--live-activity']);
  const values = new Set(['--familiar-backend', '--opencv-framework', '--familiar-models', '--currency-reference-pack', '--object-detector', '--object-detector-manifest']);
  const parsed = new Map();
  for (let i = 0; i < args.length; i++) {
    const name = args[i];
    if ((!booleans.has(name) && !values.has(name)) || parsed.has(name)) throw new Error(`Unknown or repeated option: ${name}`);
    if (booleans.has(name)) parsed.set(name, true);
    else {
      if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error(`Missing ${name} <value>`);
      parsed.set(name, args[++i]);
    }
  }
  const familiarPeople = parsed.has('--familiar-people'), currencyReference = parsed.has('--currency-reference');
  const currencyDeviceTest = parsed.has('--currency-device-test');
  if (parsed.has('--object-detector') !== parsed.has('--object-detector-manifest')) throw new Error('--object-detector and --object-detector-manifest are required together.');
  if (currencyDeviceTest && (!currencyReference || !parsed.has('--currency-reference-pack'))) throw new Error('Device testing requires --currency-reference and --currency-reference-pack.');
  if (!familiarPeople && (parsed.has('--familiar-backend') || parsed.has('--familiar-models'))) throw new Error('Face options require --familiar-people.');
  if (!currencyReference && parsed.has('--currency-reference-pack')) throw new Error('A reference pack requires --currency-reference.');
  if (!familiarPeople && !currencyReference && parsed.has('--opencv-framework')) throw new Error('The framework requires an explicit native feature.');
  if ((familiarPeople || currencyReference) && !parsed.has('--opencv-framework')) throw new Error('Missing --opencv-framework <path>');
  if (familiarPeople && !parsed.has('--familiar-models')) throw new Error('Missing --familiar-models <path>');
  const familiarBackend = parsed.get('--familiar-backend') ?? 'sface';
  familiarHashesForBackend(familiarBackend);
  const path = name => parsed.has(name) ? resolve(parsed.get(name)) : undefined;
  return { multimodal: parsed.has('--multimodal'), liveActivity: parsed.has('--live-activity'), familiarPeople, familiarBackend, currencyReference, currencyDeviceTest,
    opencvFramework: path('--opencv-framework'), familiarModels: path('--familiar-models'), currencyReferencePack: path('--currency-reference-pack'),
    objectDetector: path('--object-detector'), objectDetectorManifest: path('--object-detector-manifest') };
}
export async function verifyProjectInputs(options) {
  if (options.currencyDeviceTest && (!options.currencyReference || !options.currencyReferencePack || !options.opencvFramework)) throw new Error('Device testing requires explicit native currency, a reference pack and OpenCV.');
  if (options.familiarPeople) await verifyFamiliarInputs(options.opencvFramework, options.familiarModels, options.familiarBackend);
  else if (options.currencyReference) await verifyOpenCVFramework(options.opencvFramework);
  let pack;
  if (options.currencyReferencePack) {
    pack = await verifyCurrencyReferencePack(options.currencyReferencePack);
    if (options.currencyDeviceTest && pack.references === 0) throw new Error('Device testing requires a nonempty verified reference pack.');
  }
  if (Boolean(options.objectDetector) !== Boolean(options.objectDetectorManifest)) throw new Error('Object detector and external manifest are required together.');
  const objectDetector = options.objectDetector ? await verifyObjectDetector(options.objectDetector, options.objectDetectorManifest) : undefined;
  return pack || objectDetector ? { ...(pack ?? {}), ...(objectDetector ? { objectDetector } : {}) } : undefined;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const files = (await readdir(join(root, 'ios/BlindAssist'))).filter(file => file.endsWith('.swift')).sort();
  const options = parseProjectArguments(process.argv.slice(2));
  const pack = await verifyProjectInputs(options);
  const project = generateProject(files, {
    ...options,
    ...(options.currencyDeviceTest ? { currencyReferencePackSHA256: pack?.manifestSHA256 } : {}),
    ...(pack?.objectDetector ? { objectDetectorSHA256: pack.objectDetector.artifactSHA256,
      objectDetectorManifestSHA256: pack.objectDetector.manifestSHA256 } : {})
  });
  const output = join(root, 'ios/BlindAssist.xcodeproj'); await mkdir(output, { recursive: true });
  await writeFile(join(output, 'project.pbxproj'), project);
  if (pack?.manifestSHA256) console.log(`Private reference manifest SHA-256: ${pack.manifestSHA256}. ${options.currencyDeviceTest
    ? 'Debug-only adult-supervised device-test profile. Unvalidated recognition; Release stays disabled.'
    : 'Packaging does not activate recognition.'}`);
  if (pack?.objectDetector) console.log(`Detector artifact SHA-256: ${pack.objectDetector.artifactSHA256}. Packaging declaration checked; native Vision output, licenses and accuracy still require independent acceptance.`);
  const schemes = join(output, 'xcshareddata/xcschemes'); await mkdir(schemes, { recursive: true });
  await writeFile(join(schemes, 'BlindAssist.xcscheme'), generateScheme());
  console.log('Generated ios/BlindAssist.xcodeproj (phone/BLE build). For native RTAB-Map use npm run native:prepare.');
}
