import { spawnSync } from 'node:child_process';
import { mkdir, writeFile, statfs } from 'node:fs/promises';
import { arch, totalmem, release } from 'node:os';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
export function buildCommands(native = false) {
  const base = ['-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist', '-configuration', 'Debug', '-jobs', '2'];
  const jobs = [
    ['xcodebuild', [...base, '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', 'artifacts/xcode-simulator', 'CODE_SIGNING_ALLOWED=NO', 'build']],
    ['xcodebuild', [...base, '-destination', 'generic/platform=iOS', '-derivedDataPath', 'artifacts/xcode-device', 'CODE_SIGNING_ALLOWED=NO', 'build']]
  ];
  if (native) jobs.push(['xcodebuild', ['-project', '.tools/rtabmap/app/ios/RTABMapApp.xcodeproj', '-scheme', 'RTABMapApp', '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-derivedDataPath', 'artifacts/xcode-native', 'CODE_SIGNING_ALLOWED=NO', 'build']]);
  return jobs;
}
async function main() {
  const native = process.argv.includes('--native');
  if (process.argv.includes('--print')) { console.log(JSON.stringify(buildCommands(native), null, 2)); return; }
  if (process.platform !== 'darwin') throw new Error('Run this command on the Mac mini. Use --print to inspect the build steps on Windows.');
  const output = join(root, 'artifacts/mac-checks'); await mkdir(output, { recursive: true });
  const disk = await statfs(root);
  const machine = { architecture: arch(), kernel: release(), memoryGiB: +(totalmem() / 1024 ** 3).toFixed(1),
    availableWorkspaceGiB: +(disk.bavail * disk.bsize / 1024 ** 3).toFixed(1), node: process.version };
  await writeFile(join(output, 'machine.json'), JSON.stringify(machine, null, 2));
  console.log(`Mac: ${machine.architecture}, ${machine.memoryGiB} GiB RAM, ${machine.availableWorkspaceGiB} GiB available on workspace volume.`);
  console.log('Native mapping dependencies are a separate, larger build; available space is reported, not a measured capacity guarantee.');
  for (const [command, args] of [['xcodebuild', ['-version']], ['xcrun', ['--sdk', 'iphoneos', '--show-sdk-path']]]) {
    const check = spawnSync(command, args, { cwd: root, stdio: 'inherit' });
    if (check.error || check.status !== 0) throw new Error('Install full Xcode, launch it once, install the iOS platform, and select Xcode in Settings > Locations > Command Line Tools.');
  }
  const report = [];
  async function run(command, args, cwd = root) {
    console.log(`Running ${command} ${args.join(' ')}`);
    const result = spawnSync(command, args, { cwd, encoding: 'utf8', maxBuffer: 80 * 1024 * 1024 });
    const log = `${String(report.length + 1).padStart(2, '0')}-${command.split('/').at(-1)}.log`;
    await writeFile(join(output, log), (result.stdout ?? '') + (result.stderr ?? ''));
    report.push({ command, args, log, passed: result.status === 0 && !result.error });
    await writeFile(join(output, 'report.json'), JSON.stringify({ time: new Date().toISOString(), checks: report }, null, 2));
    if (result.error || result.status !== 0) throw new Error(`Check failed. Read artifacts/mac-checks/${log}. ${result.error?.message ?? ''}`);
  }
  if (process.argv.includes('--multimodal')) {
    const sdk = spawnSync('xcrun', ['--sdk', 'iphoneos', '--show-sdk-version'], { encoding: 'utf8' });
    if (sdk.status !== 0 || !/^\s*(\d+)/.test(sdk.stdout) || +sdk.stdout.trim().split('.')[0] < 27) throw new Error('The multimodal image adapter requires the iOS 27 SDK. Select Xcode 27 or newer, or omit --multimodal for the evidence-template build.');
  }
  await run(process.execPath, ['tools/verify.mjs', ...(process.argv.includes('--multimodal') ? ['--multimodal'] : [])]);
  if (native) {
    await run(process.execPath, ['tools/prepare-rtabmap.mjs', ...(process.argv.includes('--multimodal') ? ['--multimodal'] : [])]);
    if (process.argv.includes('--install-native-deps')) {
      const check = spawnSync('cmake', ['--version'], { stdio: 'ignore' });
      if (check.status !== 0) throw new Error('Install CMake first, for example with brew install cmake.');
      await run('bash', ['install_deps.sh'], join(root, '.tools/rtabmap/app/ios/RTABMapApp'));
    }
  }
  for (const [command, args] of buildCommands(native)) await run(command, args);
  if (process.argv.includes('--ui')) {
    const list = spawnSync('xcrun', ['simctl', 'list', 'devices', 'available', '--json'], { encoding: 'utf8' });
    if (list.status !== 0) throw new Error('Could not list simulators. Install an iOS simulator runtime in Xcode Settings.');
    const devices = Object.entries(JSON.parse(list.stdout).devices).filter(([runtime]) => runtime.includes('iOS')).flatMap(([, devices]) => devices);
    const device = devices.find(device => device.isAvailable && device.name.startsWith('iPhone'));
    if (!device) throw new Error('No iPhone simulator available. Install an iOS runtime in Xcode Settings > Components.');
    await run('xcodebuild', ['-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist', '-destination', `platform=iOS Simulator,id=${device.udid}`,
      '-derivedDataPath', 'artifacts/xcode-ui', '-jobs', '2', '-parallel-testing-enabled', 'NO', 'CODE_SIGNING_ALLOWED=NO', 'test']);
  }
  console.log('Mac builds passed. Open the Xcode project, select your signing team and connected iPhone, then Run. See MAC_HANDOFF.md for device acceptance.');
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(error => { console.error(error.message); process.exitCode = 1; });
