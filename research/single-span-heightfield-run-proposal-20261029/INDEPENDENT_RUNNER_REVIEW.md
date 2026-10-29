# Independent runner source review — 2026-10-29

**No remaining source-review blocker to root's separately admitted one-shot trusted synthetic compile/comparison.** This is a source review, not execution evidence or a hostile-process sandbox certification. Root must publish/pin the source commit and perform admission; this review ran neither supervisor nor compiler/native executable.

Final reviewed SHA-256:

- `run_once.py`: `c4dc7b1c9b438d5199114339447b089293dc7741fc674a3d743577c1c89968e5`
- `RUN_PINS.json`: `9ec9aed20b5ef273dc85b629950321a0f49dacf8912ad4f0c006dabada5ccf3b`

All 21 manifest inputs were independently checked as regular files with matching SHA-256. Python AST parsing succeeded without importing/executing the runner. The candidate's prior independent source review remains separate; its 23 masks and 37 refusal cases are authored, not executed at this checkpoint.

## Fixed and re-read before this decision

- Replaced rglob/is_file/stat output enumeration with bounded descriptor-relative traversal using entry names only. No cached DirEntry type predicate is trusted. Directory opens use O_DIRECTORY/O_NOFOLLOW and inode/device identity checks; regular-file opens use O_NOFOLLOW/O_NONBLOCK and regular-file validation. Symlinks, special files and errors other than active-phase ENOENT fail. Terminal scans tolerate no disappearance. Entry count, depth and cumulative regular-file bytes are bounded before terminal content hashing.
- Strict terminal inventory performs two equal metadata/hash passes after observed process-group retirement. Failure paths capture this inventory when retirement is established, or explicitly record unverified retirement/inventory errors. RESULT.json is included in byte accounting but excluded from payload hashes because the final receipt changes it.
- Receipt writing itself now opens with O_NOFOLLOW and validates regular-file type before truncation, including compact failure receipts. It does not follow a symlink that output inspection just rejected.
- A zero-exit leader with remaining process-group members is a failure, not silently accepted after killing descendants. Cleanup kills the group, waits for the leader and requires observed empty membership; inability to establish retirement fails and blocks comparison. No automatic retry or reuse of attempt-001.
- Loaded manifest bytes must match the exact admitted git commit; HEAD must match admission. Input hashes and manifest identity are checked before work and again on completion/failure. Executable digest is saved after compile and checked after comparison. Post-run pin errors are failures.
- Aggregate CPU/wall checks include final evidence/pin hashing and final receipt generation, not just payload loops. Payload/output accounting reserves 128 KiB for receipt and uses a receipt size cap. Compiler and comparison are serial with inherited one-core affinity, per-process CPU/file/core backstops, and retained command/exit records.

## Remaining observation limits, not hidden guarantees

The 512 MiB limit is observed aggregate RSS, not a hard kernel memory sandbox; procfs snapshots and 20 ms sampling can miss or overshoot peaks. Child ru_maxrss helps with some fast exits but is not a simultaneous aggregate peak proof. CPU/output/wall limits are observed and checked, with bounded cleanup/evidence work after a failure; they are not a guarantee of zero overshoot. A blocked kernel/filesystem operation or externally killed supervisor cannot be made reliably cleanable by these Python checks. Output accounting is logical file size, not filesystem metadata/allocation usage. Process-group membership covers this trusted non-daemonizing compiler/test workload, not deliberate escaping children. Signal interruption can prevent a complete receipt; missing or failed evidence must not become acceptance.

The selected compiler/backends/UBSan and local source dependencies are pinned, but Python, standard/system headers and other host libraries are not a hermetic toolchain. No compiler compatibility, runtime sanitizer result, native API qualification, device behavior, route clearance or physical authority is established by this source review. Source/pin/guard changes after this freeze require review of the change; a failed attempt is retained and cannot be relabeled as a pass.

No native build/test, guard execution, install, network operation, app edit, commit or push was performed by the reviewer. No permission denial occurred. One initial lookup used the candidate subdirectory rather than the separate run-proposal directory and returned file-not-found; it was corrected without execution or permission escalation.
