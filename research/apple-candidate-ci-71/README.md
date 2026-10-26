# Prepared test-only Apple SDK candidate bridge check (71)

**Prepared locally; no GitHub workflow was dispatched and no Apple build result
is claimed.** Local pinned-source/fixture checks and the existing Linux70 binary
passed55 checks, including636 excluded spans and five candidate-route parity
pairs. That validates the compact fixture and unchanged Swift source, not the
new Apple compiler/linker commands.

## Exact publication scope

Copy this package to `research/apple-candidate-ci-71/` and its
`native-candidate-bridge.yml` ALSO to
`.github/workflows/native-candidate-bridge.yml`. Keep the package copy: runtime
checks both copies are identical. PUBLICATION_MAP.json gives source→destination
paths. No existing app, default workflow, tools/ci or upstream file is modified.

Workflow triggers only master pushes touching this research folder or its own
workflow, plus explicit workflow_dispatch. Those paths do not match the existing
native-apple workflow's app/core/memory/tools/ci-specific filters, so this change
does not deliberately retrigger the existing large UI suite. The job uses the
already working xcode-27 runner, Xcode27.0, public mischa23v/blind only,
contents:read, pinned checkout and artifact actions, persist-credentials:false,
no submodules/LFS. No user secret expressions, signing identity/profile,
codesign invocation, deployment, TestFlight or install command. Standard ephemeral
GitHub checkout/artifact tokens still exist; this is not a token-free CI claim.

## What Apple CI will attempt

1. Verify every package and upstream hash; validate/decompress a bounded fixture.
2. Rebuild original pinned Recast sources plus stage66 adapter into a **new Apple
   macOS dylib** using xcrun clang++, arm64/macos14 minimum, existing macOS SDK.
3. Compile reviewed70 Swift/C-ABI source and run its55-check geometry/native
   parity harness on macOS. Raw scene data/physical authority remain absent.
4. Rebuild that native library and compile/link the same Swift harness for
   arm64-apple-ios17.0-simulator against installed iOS27.0 SDK. **Compile/link only:**
   no simulator boot, installation, launch, application bundle or sensor test.
5. Preserve bounded JSON stage receipts, hashes and macOS result. No fixture,
   compiler cache, binaries, screenshots, environment dumps or full logs uploaded.

The Linux .so is never downloaded, renamed or linked on Apple. C++ algorithms are
unchanged; the copied stage66 native source has only its header include path
adapted. Swift files are byte-identical to stage70. SOURCE_PINS.json verifies43
upstream files already tracked at tools/navigation-recast/upstream, revision
9f4ce64458dfae86e1239c525ddc219c4e9e06f1. Their Git blobs were compared with
repository219dc42f3d7c7751fe79c40be57207608e0a9b0a:43 matches,0 differences. No SDK,
package manager, model, archive or compiler installation is included.

## Fixture/provenance

fixture/room.json.gz is1,272,299bytes, decoding to3,088,598bytes. It contains only
public MuSHRoom Polycam geometry,32 synthetic anchor transforms, the frozen
manually assisted unknown tabletop exclusion, five query pairs and reference
candidate outputs. No photos, private user input or FARO. ATTRIBUTION.md documents
CC BY4.0 source and changes; PROVENANCE.json maps every copied source back to66/70.
All29,366 triangles are retained. This is a derivative of fused phone geometry,
not a real ARMeshAnchor event stream. Geometric route parity is not safety proof.

## Bounds and reproducibility

Job timeout18minutes; build/test step16minutes; each subprocess300wall/300CPU
seconds (macOS replay120wall); serial Swift jobs1 and single native compiler driver;
individual output-file limit128MiB; scratch512MiB checked after each stage;
compressed/decompressed fixture hashes and8MiB decode limit enforced. Scratch
check is a stage-end guard, not a hard aggregate filesystem quota or RSS guarantee.
Artifacts retain3days and only allowlisted JSON files. Failing compiler diagnostics
are bounded to35 lines from public source; no raw job logs are published here.

Local verification:
```
python blind-apple-candidate-ci-71/ci.py --validate-only \
  --upstream blind-split-candidate-game-03/body-margin-variants-07/native025/upstream
```
LINUX_VALIDATION.json records an existing70-binary rerun using the byte-identical
uncompressed fixture already local, avoiding another3MB raw mesh copy. Source
bytes were compared, not newly compiled for Apple. The compact package is under
2MiB. Do not call the Apple path passing until the dispatched job actually passes.

## Known unrelated baseline failures remain visible

Existing Apple run40271201457 compiled the default unsigned app successfully, but
had5 hosted test failures and1 UI Dynamic Type failure. This dedicated candidate
job neither fixes nor suppresses them, and must not be presented as green app CI.
Likewise it does not wire70 into the app or enable physical guidance. A future
app integration still needs explicit review, live sensor coverage and device tests.

Independent prepared-package review PASS:14 packaged source/fixture pins and43
upstream pins verified, gzip decoded hash and70 Swift byte identity confirmed.
Reviewer independently checked timeout and missing-executable failure receipts.
See INDEPENDENT_REVIEW.json. This is approval of the prepared test scope, NOT a
passed Apple job. The existing repository Apple runner has executed previously;
this new candidate job and these Apple compiler commands remain unexecuted.

### Native grid allocation bounds audit
The unchanged `native/blind_detour_exclusion.cpp` rejects nonfinite or absolute
coordinates above 10,000 m (line 80), extents above 200 m X/Z or 20 m Y (93–94),
and invalid cell sizes below 0.025 m (47). Thus `rcCalcGridSize` receives at most
8,000 cells per planar dimension, safely inside integer range. Its 64-bit
width×height check rejects grids above the configured cap (maximum 250,000),
before the heightfield allocation (97–103). This guards grid extents, not a claim
of a hard total RSS cap. `check_native_bounds.py` independently exercised seven
small rejection cases against the existing pinned Linux native66 library,
including huge finite coordinates, excessive extents and a 200×200 m grid.
`NATIVE_BOUNDS_CHECK.json` records all seven rejected correctly. No scored mesh,
frozen66/70 source, or Apple build code changed; this is not an Apple execution.
