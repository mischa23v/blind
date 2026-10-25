// Minimal isolated PBX project using the repository's dependency-free generator pattern.
// No application repository project, package, source or build settings are changed.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve, join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(process.argv[2] ?? '');
if (!process.argv[2] || out === here || !process.argv[2].startsWith('/')) throw Error('Fresh absolute scratch output required');
const expected = {
  'VoiceEnrollment.swift': '7b4991e62d69c7761260d48b2427233749a66823e038597c47c2f475070d3b65',
  'ProtectedVoiceEnrollmentStore.swift': '901f60c371d02c4b0532fc8572d126a2dc76e51dfd778d0061048af4ca9d907e'
};
const sourcePaths = {
  'VoiceEnrollment.swift': '../source/VoiceEnrollment.swift',
  'ProtectedVoiceEnrollmentStore.swift': '../source-native-v2/ProtectedVoiceEnrollmentStore.swift'
};
const input = {};
for (const [name, hash] of Object.entries(expected)) {
  const bytes = await readFile(join(here, sourcePaths[name]));
  if (createHash('sha256').update(bytes).digest('hex') !== hash) throw Error('Reviewed source hash mismatch: ' + name);
  input[name] = bytes.toString('utf8');
}
await mkdir(out, {recursive:false}); // Refuse to overwrite/reuse another project.
const hooks = `
    #if VOICE_ENROLLMENT_TESTING
    // Probe-only seam: absent from production builds and restricted to temp-container paths.
    private var testFailBeforeErase = false
    init(testDirectory: URL, failBeforeErase: Bool = false) throws {
        let root = FileManager.default.temporaryDirectory.standardizedFileURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard testDirectory.isFileURL,
              testDirectory.standardizedFileURL.path.hasPrefix("/" + root + "/") else {
            throw VoiceEnrollmentError.invalidRecord
        }
        directory = testDirectory
        file = directory.appendingPathComponent("enrollment-v1.json", isDirectory: false)
        deletionFence = VoiceEnrollmentDeletionFence(directory: directory)
        testFailBeforeErase = failBeforeErase
    }
    #endif
`;
const anchor = '    private func secure(_ url: URL) throws {';
const erase = '                try fence.removeOtherChildren()';
const security = '        guard checked.isExcludedFromBackup == true,';
for (const [needle, count] of [[anchor, 1], [erase, 1], [security, 1]]) {
  if (input['ProtectedVoiceEnrollmentStore.swift'].split(needle).length - 1 !== count) throw Error('Unexpected injection anchor');
}
const projected = input['ProtectedVoiceEnrollmentStore.swift'].replace(anchor, hooks + anchor)
  .replace(erase, `                #if VOICE_ENROLLMENT_TESTING
                if testFailBeforeErase {
                    testFailBeforeErase = false
                    throw VoiceEnrollmentError.invalidRecord
                }
                #endif
` + erase)
  .replace(security, `        #if VOICE_ENROLLMENT_TESTING
        // Synthetic fixture metadata only. Never print the URL, record or directory contents.
        if checked.isExcludedFromBackup != true || attributes[.protectionKey] as? FileProtectionType != .complete {
            let protection = attributes[.protectionKey]
            let kind = protection.map { String(reflecting: type(of: $0)) } ?? "missing"
            print("VOICE_PROBE_SECURITY excluded=" + String(checked.isExcludedFromBackup == true)
                + " typedComplete=" + String(protection as? FileProtectionType == .complete)
                + " rawComplete=" + String(protection as? String == FileProtectionType.complete.rawValue)
                + " attributeType=" + kind)
        }
        #endif
` + security);
await writeFile(join(out, 'VoiceEnrollment.swift'), input['VoiceEnrollment.swift']);
await writeFile(join(out, 'ProtectedVoiceEnrollmentStore.swift'), projected);
await writeFile(join(out, 'ActorTests.swift'), await readFile(join(here, 'ActorTests.swift')));
await writeFile(join(out, 'Host.swift'), `import SwiftUI
@main struct ProbeHostApp: App {
    var body: some Scene {
        WindowGroup { Color.clear }
    }
}
`);
const objects = [], id = name => createHash('sha256').update(name).digest('hex').slice(0,24).toUpperCase();
const add = (name, body) => { objects.push(`${id(name)} = { ${body} };`); return id(name); };
const refs = [], builds = {};
for (const name of ['Host.swift', 'VoiceEnrollment.swift', 'ProtectedVoiceEnrollmentStore.swift', 'ActorTests.swift']) {
  const ref = add(name, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${name}"; sourceTree = "<group>";`);
  refs.push(ref); builds[name] = add('build:'+name, `isa = PBXBuildFile; fileRef = ${ref};`);
}
const hostProduct = add('host-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = VoiceProbeHost.app; sourceTree = BUILT_PRODUCTS_DIR;');
const testProduct = add('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = VoiceProbeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
const group = add('group', `isa = PBXGroup; children = (${[...refs,hostProduct,testProduct].join(',')},); sourceTree = "<group>";`);
const common = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_NAME = "$(TARGET_NAME)"; CODE_SIGNING_ALLOWED = NO; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES;';
const config = (name, settings) => {
  const c = add(name+'-debug', `isa = XCBuildConfiguration; name = Debug; buildSettings = { ${settings} };`);
  return add(name+'-configs', `isa = XCConfigurationList; buildConfigurations = (${c},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;`);
};
const hostConfig = config('host', common + ' PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.voiceprobe.host; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES;');
const testConfig = config('test', common + ' PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.voiceprobe.tests; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) VOICE_ENROLLMENT_TESTING"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/VoiceProbeHost.app/VoiceProbeHost"; BUNDLE_LOADER = "$(TEST_HOST)";');
const projectConfig = config('project', '');
const sources = (name, files) => add(name+'-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${files.map(f=>builds[f]).join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
const hostSources = sources('host', ['Host.swift']);
const testSources = sources('test', ['VoiceEnrollment.swift','ProtectedVoiceEnrollmentStore.swift','ActorTests.swift']);
const host = add('host', `isa = PBXNativeTarget; buildConfigurationList = ${hostConfig}; buildPhases = (${hostSources},); buildRules = (); dependencies = (); name = VoiceProbeHost; productName = VoiceProbeHost; productReference = ${hostProduct}; productType = "com.apple.product-type.application";`);
const proxy = add('proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${host}; remoteInfo = VoiceProbeHost;`);
const dependency = add('dependency', `isa = PBXTargetDependency; target = ${host}; targetProxy = ${proxy};`);
const tests = add('tests', `isa = PBXNativeTarget; buildConfigurationList = ${testConfig}; buildPhases = (${testSources},); buildRules = (); dependencies = (${dependency},); name = VoiceProbeTests; productName = VoiceProbeTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
const project = add('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${tests} = { TestTargetID = ${host}; }; }; }; buildConfigurationList = ${projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = ${group}; projectDirPath = ""; projectRoot = ""; targets = (${host},${tests},);`);
const bundle = join(out,'VoiceProbe.xcodeproj');
await mkdir(join(bundle,'xcshareddata/xcschemes'), {recursive:true});
await writeFile(join(bundle,'project.pbxproj'), `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${project}; }\n`);
const ref = (target,name) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="${name}" BlueprintName="${name.replace(/\.(app|xctest)$/,'')}" ReferencedContainer="container:VoiceProbe.xcodeproj"/>`;
await writeFile(join(bundle,'xcshareddata/xcschemes/VoiceProbe.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">${ref(host,'VoiceProbeHost.app')}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">${ref(tests,'VoiceProbeTests.xctest')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">${ref(tests,'VoiceProbeTests.xctest')}</TestableReference></Testables></TestAction>
</Scheme>
`);
console.log('Generated isolated two-source actor probe; production source hashes pinned; no app repository wiring.');
