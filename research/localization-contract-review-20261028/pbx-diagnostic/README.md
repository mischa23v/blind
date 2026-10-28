# Read-only checked/generated Xcode project diagnosis

2026-10-28. No shared PBX or generator files edited; no native build or install.

## Exact cause

`selected-photo-reference.test.mjs:129` compares **entire project text**, despite its message saying source membership. Current native source membership is identical (61 Swift files); no paths are missing or extra. The new `BlindCoreTests/NativeLocalizationEvidenceGateTests.swift` is outside the generator's `ios/BlindAssist/*.swift` enumeration and is not the cause.

The remaining difference is `MeshCandidateDiagnostics.swift` serialization:

| | Checked PBX | Current generator |
|---|---|---|
| File reference ID | `341EA0D9EF7DB1BF7D1340DD` | `8E79CAFB76D50E58349A8BF6` |
| Build file ID | `F6036E27A5D1B2EB539E668E` | `DD48E07D75A8487C6C62BC5A` |
| Source tree | `SOURCE_ROOT` | `"<group>"` |
| Path | unquoted `BlindAssist/MeshCandidateDiagnostics.swift` | quoted same path |
| Membership ordering | manually prepended | canonical sorted source position |

Both include `MeshCandidateIngress83` local package/product/framework references: that earlier generator parity fix is present. This is not evidence that the mesh file is absent from the build or that photo-trash added a missing source. The full byte-equality regression correctly detects remaining project drift.

## Minimal proposed fix (root-owned, not applied here)

Use the **current** generator to refresh the checked-in normal `ios/BlindAssist.xcodeproj/project.pbxproj`. This changes the diagnostic source's IDs, location within generated records and ordering, without adding/removing Swift membership or changing the mesh dependency. Review the preserved `generated-vs-checked.diff` first. Do not loosen the regression to hide drift.

`generated-project.txt` is the exact candidate output, not a native-tested project. `comparison.json` pins input/output hashes; `generated-vs-checked.diff` is the complete delta.

## Bounded reproduction (read-only to shared files)

From repository root:

```sh
node --input-type=module <<'JS'
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { generateProject } from './tools/generate-xcode-project.mjs';
const files = (await readdir('ios/BlindAssist')).filter(f => f.endsWith('.swift')).sort();
const generated = generateProject(files);
const checked = await readFile('ios/BlindAssist.xcodeproj/project.pbxproj', 'utf8');
console.log({ nativeSwiftFileCount: files.length, exactMatch: checked === generated });
// Optional diagnostic output only. Does not replace the checked project.
await writeFile('research/localization-contract-review-20261028/pbx-diagnostic/generated-project.txt', generated);
JS
```

Root should rerun the original selected-photo suite after canonical regeneration. This diagnostic does not claim that regression has passed or that Swift compiles.

## Authorized follow-on applied locally

Root subsequently authorized the minimal canonical regeneration. The current checked PBX now exactly matches the current generator at SHA `e80ced174477574a28b45c594e2a10029d14da9c6ef588845a93f9eab3321cd1`. The original comparison/diff above remain preserved as the failure diagnosis, not rewritten as a pass.

`check_canonicalization.mjs` verifies exact current generator equality, 61 source files, the sole changed file-reference path, no package/framework changes and no build-flag changes. `canonicalization-result.json` records its source-only result. `regression.log`: **28/28** bounded mesh-project, reference-photo-trash and selected-photo source tests pass (including the formerly failing exact PBX comparison). `integrated-result.json`: **39/39** integrated source checks pass. The new reversible `project-canonicalization.patch` is undone before the old historical patches and verifies the original 5aa44 project hash. No old patch was rewritten. No native build, workflow activation or new compilation flag occurred.

The first diagnostic checker invocation had an over-deep relative import (`ERR_MODULE_NOT_FOUND`); its path was corrected before the successful source-only receipt. This was a diagnostic script path error, not a native build result.
