// Synthetic concurrency plumbing only: the OpenCV setter is a counting stub.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = fileURLToPath(new URL('../../', import.meta.url));
test('face and currency share one OpenCV runtime configuration', async () => {
  for (const name of ['FamiliarNative/BAFaceEngine.mm', 'CurrencyNative/BACurrencyReferenceMatcher.hpp']) {
    const source = await readFile(join(root, 'ios/BlindAssist', name), 'utf8');
    assert.match(source, /ba_runtime::configureOpenCVOnce\(\)/);
    assert.doesNotMatch(source, /cv::setNumThreads|cv::ocl::setUseOpenCL/);
  }
});
test('runtime initialization is once across translation units and concurrent callers', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'blind-opencv-once-'));
  try {
    await mkdir(join(dir, 'opencv2'));
    await writeFile(join(dir, 'opencv2/core.hpp'), '#pragma once\nnamespace cv { void setNumThreads(int); }\n');
    const header = join(root, 'ios/BlindAssist/OpenCVRuntime.hpp');
    await writeFile(join(dir, 'a.cpp'), `#include "${header}"\nvoid a(){ba_runtime::configureOpenCVOnce();}\n`);
    await writeFile(join(dir, 'b.cpp'), `#include "${header}"\nvoid b(){ba_runtime::configureOpenCVOnce();}\n`);
    await writeFile(join(dir, 'main.cpp'), '#include <atomic>\n#include <thread>\n#include <vector>\n#include <exception>\nstd::atomic<int> calls{0}; namespace cv { void setNumThreads(int n){if(n!=1)std::terminate();++calls;} }\nvoid a();void b();int main(){std::vector<std::thread> ts;for(int i=0;i<32;++i)ts.emplace_back([]{for(int j=0;j<100;++j){a();b();}});for(auto &t:ts)t.join();return calls==1?0:1;}\n');
    const binary = join(dir, 'test');
    const build = spawnSync(process.env.CXX || 'c++', ['-std=c++17', '-Wall', '-Wextra', '-Werror', '-pthread', '-I', dir, join(dir,'a.cpp'), join(dir,'b.cpp'), join(dir,'main.cpp'), '-o', binary], { encoding:'utf8' });
    assert.equal(build.status, 0, build.stderr || String(build.error));
    const run = spawnSync(binary, [], { encoding:'utf8' });
    assert.equal(run.status, 0, run.stderr || String(run.error));
  } finally { await rm(dir, { recursive:true, force:true }); }
});
