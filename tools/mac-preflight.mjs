import { spawnSync } from 'node:child_process';
import { mkdir, writeFile, access } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
if (process.platform !== 'darwin') {
  console.log('Run this preflight on the Mac. It checks installed tools only; it does not build, install dependencies, download models or start Docker.');
  process.exitCode = 1;
} else {
  const checks = [];
  for (const [command, args] of [['xcodebuild', ['-version']], ['xcrun', ['swift', '--version']], ['xcrun', ['--sdk', 'iphoneos', '--show-sdk-path']], ['xcrun', ['--sdk', 'iphoneos', '--show-sdk-version']]]) {
    const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout: 15000, maxBuffer: 64000 });
    const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
    let passed = !result.error && result.status === 0;
    if (args.includes('swift')) {
      const version = output.match(/Swift version (\d+)\.(\d+)/);
      passed &&= !!version && (+version[1] > 6 || (+version[1] === 6 && +version[2] >= 1));
    }
    if (args.includes('--show-sdk-version') && process.argv.includes('--multimodal')) passed &&= +output.split('.')[0] >= 27;
    checks.push({ command, args, passed, output, error: result.error?.message });
  }
  for (const path of ['BlindMemory/Package.swift', 'BlindMemory/Sources/BlindMemory/SQL/schema.sql', 'ios/BlindAssist.xcodeproj/project.pbxproj', 'package-lock.json']) {
    let passed = true; try { await access(join(root, path)); } catch { passed = false; }
    checks.push({ file: path, passed });
  }
  checks.push({ tool: 'Node >=22', passed: +process.versions.node.split('.')[0] >= 22, version: process.version });
  const report = { time: new Date().toISOString(), kind: 'installed-tool checks only', passed: checks.every(check => check.passed), checks };
  await mkdir(join(root, 'artifacts/mac-checks'), { recursive: true });
  await writeFile(join(root, 'artifacts/mac-checks/preflight.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  if (!report.passed) process.exitCode = 1;
}
