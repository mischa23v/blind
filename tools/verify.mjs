import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
run(process.execPath, ['--test', '--test-concurrency=1', 'server/test/*.test.mjs', 'tools/test/*.test.mjs']);
run(process.execPath, ['tools/generate-xcode-project.mjs', ...(process.argv.includes('--multimodal') ? ['--multimodal'] : [])]);
if (process.argv.includes('--docker')) {
  run('docker', ['run', '--rm', '-v', `${root}:/workspace`, '-w', '/workspace/BlindCore', 'swift:6.2-noble', 'swift', 'test', '--scratch-path', '/tmp/blind-swift-build', '-j', '4']);
  run('docker', ['run', '--rm', '-v', `${root}:/workspace`, '-w', '/workspace', 'swift:6.2-noble', 'sh', '-c', 'clang++ -std=c++17 -Wall -Wextra -Werror firmware/test/protocol_test.cpp -o /tmp/protocol-test && /tmp/protocol-test']);
  run('docker', ['run', '--rm', '-v', `${root}:/workspace`, '-w', '/workspace', 'swift:6.2-noble', 'sh', '-c', 'clang++ -std=c++11 -Wall -Wextra -Werror -fsanitize=address,undefined firmware/test/failure_test.cpp -o /tmp/failure-test && /tmp/failure-test']);
  run('docker', ['run', '--rm', '-v', `${root}:/workspace`, '-w', '/workspace', 'swift:6.2-noble', 'sh', '-c', 'swiftc -frontend -parse ios/BlindAssist/*.swift ios/BlindAssistUITests/*.swift && swiftc -frontend -parse -D BLIND_RTABMAP ios/BlindAssist/NativeMapping.swift integration/MobilitySceneDelegate.swift']);
} else if (process.platform === 'darwin') {
  run('swift', ['test', '--package-path', 'BlindMemory', '--scratch-path', 'artifacts/swift-memory-macos', '-j', '2']);
  run('swift', ['test', '--package-path', 'BlindCore', '--scratch-path', 'artifacts/swift-macos', '-j', '2']);
  run('clang++', ['-std=c++17', '-Wall', '-Wextra', '-Werror', 'firmware/test/protocol_test.cpp', '-o', '/tmp/blind-protocol-test']);
  run('/tmp/blind-protocol-test', []);
  run('clang++', ['-std=c++11', '-Wall', '-Wextra', '-Werror', '-fsanitize=address,undefined', 'firmware/test/failure_test.cpp', '-o', '/tmp/blind-failure-test']);
  run('/tmp/blind-failure-test', []);
}
else console.log('Swift and C++ checks not run: use the Mac handoff after heavy-build permission. Docker is not required.');
console.log('Device builds and hardware acceptance are separate; this does not certify mobility readiness.');
