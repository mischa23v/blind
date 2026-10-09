import { readdir, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { resolve, join } from 'node:path';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const id = name => createHash('sha256').update(name).digest('hex').slice(0, 24).toUpperCase();
export function generateProject(files, { multimodal = false } = {}) {
  const objects = [], add = (name, body) => { objects.push(`${id(name)} = { ${body} };`); return id(name); };
  const refs = [], sources = [];
  for (const file of files) {
    const ref = add(file, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${JSON.stringify(`BlindAssist/${file}`)}; sourceTree = "<group>";`);
    refs.push(ref); sources.push(add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${ref};`));
  }
  const product = add('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = BlindAssist.app; sourceTree = BUILT_PRODUCTS_DIR;');
  const pkg = add('package', 'isa = XCLocalSwiftPackageReference; relativePath = ../BlindCore;');
  const dependency = add('dependency', `isa = XCSwiftPackageProductDependency; package = ${pkg}; productName = BlindCore;`);
  const lib = add('lib', `isa = PBXBuildFile; productRef = ${dependency};`);
  const memoryPackage = add('memory-package', 'isa = XCLocalSwiftPackageReference; relativePath = ../BlindMemory;');
  const memoryDependency = add('memory-dependency', `isa = XCSwiftPackageProductDependency; package = ${memoryPackage}; productName = BlindMemory;`);
  const memoryLibrary = add('memory-lib', `isa = PBXBuildFile; productRef = ${memoryDependency};`);
  const sourcesPhase = add('sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${sources.join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
  const frameworksPhase = add('frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${lib},${memoryLibrary},); runOnlyForDeploymentPostprocessing = 0;`);
  const group = add('group', `isa = PBXGroup; children = (${refs.join(',')},${product},${id('ui-file')},${id('ui-product')},${id('unit-file')},${id('unit-product')},); sourceTree = "<group>";`);
  const configs = [];
  for (const name of ['Debug', 'Release']) configs.push(add(name, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility; INFOPLIST_FILE = BlindAssist/Info.plist; CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = YES; ENABLE_TESTABILITY = ${name === 'Debug' ? 'YES' : 'NO'}; SWIFT_OPTIMIZATION_LEVEL = "${name === 'Debug' ? '-Onone' : '-O'}"; };`));
  const configList = add('configs', `isa = XCConfigurationList; buildConfigurations = (${configs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
  const target = add('target', `isa = PBXNativeTarget; buildConfigurationList = ${configList}; buildPhases = (${sourcesPhase},${frameworksPhase},); buildRules = (); dependencies = (); name = BlindAssist; productName = BlindAssist; productReference = ${product}; productType = "com.apple.product-type.application"; packageProductDependencies = (${dependency},${memoryDependency},);`);
  const uiFile = add('ui-file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BlindAssistUITests/LaunchTests.swift; sourceTree = SOURCE_ROOT;');
  const uiBuild = add('ui-build', `isa = PBXBuildFile; fileRef = ${uiFile};`);
  const uiSources = add('ui-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${uiBuild},); runOnlyForDeploymentPostprocessing = 0;`);
  const uiProduct = add('ui-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = BlindAssistUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
  const uiConfigs = ['Debug', 'Release'].map(name => add(`ui-${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = ""; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility.uitests; TEST_TARGET_NAME = BlindAssist; CODE_SIGN_STYLE = Automatic; };`));
  const uiConfigList = add('ui-configs', `isa = XCConfigurationList; buildConfigurations = (${uiConfigs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
  const proxy = add('ui-proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${target}; remoteInfo = BlindAssist;`);
  const dependencyTarget = add('ui-dep', `isa = PBXTargetDependency; target = ${target}; targetProxy = ${proxy};`);
  const uiTarget = add('ui-target', `isa = PBXNativeTarget; buildConfigurationList = ${uiConfigList}; buildPhases = (${uiSources},); buildRules = (); dependencies = (${dependencyTarget},); name = BlindAssistUITests; productName = BlindAssistUITests; productReference = ${uiProduct}; productType = "com.apple.product-type.bundle.ui-testing";`);
  const unitFile = add('unit-file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BlindAssistTests/CommunityTests.swift; sourceTree = SOURCE_ROOT;');
  const unitBuild = add('unit-build', `isa = PBXBuildFile; fileRef = ${unitFile};`);
  const unitSources = add('unit-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${unitBuild},); runOnlyForDeploymentPostprocessing = 0;`);
  const unitProduct = add('unit-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = BlindAssistTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
  const unitCore = add('unit-core', `isa = XCSwiftPackageProductDependency; package = ${pkg}; productName = BlindCore;`);
  const unitCoreBuild = add('unit-core-build', `isa = PBXBuildFile; productRef = ${unitCore};`);
  const unitFrameworks = add('unit-frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${unitCoreBuild},); runOnlyForDeploymentPostprocessing = 0;`);
  const unitConfigs = ['Debug', 'Release'].map(name => add(`unit-${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = ""; PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/BlindAssist.app/BlindAssist"; BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; };`));
  const unitConfigList = add('unit-configs', `isa = XCConfigurationList; buildConfigurations = (${unitConfigs.join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;`);
  const unitDependency = add('unit-dep', `isa = PBXTargetDependency; target = ${target}; targetProxy = ${proxy};`);
  const unitTarget = add('unit-target', `isa = PBXNativeTarget; buildConfigurationList = ${unitConfigList}; buildPhases = (${unitSources},${unitFrameworks},); buildRules = (); dependencies = (${unitDependency},); name = BlindAssistTests; productName = BlindAssistTests; productReference = ${unitProduct}; productType = "com.apple.product-type.bundle.unit-test"; packageProductDependencies = (${unitCore},);`);
  const project = add('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${uiTarget} = { TestTargetID = ${target}; }; ${unitTarget} = { TestTargetID = ${target}; }; }; }; buildConfigurationList = ${configList}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, ar, Base); mainGroup = ${group}; projectDirPath = ""; projectRoot = ""; packageReferences = (${pkg},${memoryPackage},); targets = (${target},${uiTarget},${unitTarget},);`);
  let result = `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${project}; }\n`;
  if (multimodal) result = result.replaceAll('SWIFT_VERSION = 5.0;', 'SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) BLIND_APPLE_MULTIMODAL";');
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
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const files = (await readdir(join(root, 'ios/BlindAssist'))).filter(file => file.endsWith('.swift')).sort();
  const output = join(root, 'ios/BlindAssist.xcodeproj'); await mkdir(output, { recursive: true });
  await writeFile(join(output, 'project.pbxproj'), generateProject(files, { multimodal: process.argv.includes('--multimodal') }));
  const schemes = join(output, 'xcshareddata/xcschemes'); await mkdir(schemes, { recursive: true });
  await writeFile(join(schemes, 'BlindAssist.xcscheme'), generateScheme());
  console.log('Generated ios/BlindAssist.xcodeproj (phone/BLE build). For native RTAB-Map use npm run native:prepare.');
}
