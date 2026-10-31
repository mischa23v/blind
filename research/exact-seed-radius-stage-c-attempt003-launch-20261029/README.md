# Stage C attempt 003 — narrow guard compatibility and failure evidence

Private source preparation only. No Apple command, compiler, observer, route matrix,
app application or retry has run for this packet. Root must separately review,
publish and admit its exact freeze. Failed attempts 001 and 002 remain unchanged.
**Attempt 002's actual cause remains unproven.** Its exported failure was default
VALIDATION_REFUSED during Swift compilation, with no terminal resource receipt.

## Unchanged scope

- Engine/oracle source manifest: `ec2e36696ccd214f5c56b9dc3764607679f95410d56b597f1358c7925f8dae34`.
- Original source review: `c058bad95d186ea7cfd27b5e05779f1ba8ab4b67425c4a0816f923e5830edc6c`.
- Four existing public inputs, exact 17-file materialization, same 31 commands,
  15 observer groups, 50 original controls followed by 25 gated candidates.
- No route algorithm, geometry/mask, body margin, threshold, expected contact,
  continuous-clearance or physical-authority change. Stage B remains separate.
- Same 120 aggregate CPU seconds / 300 wall seconds / 2 GiB observed family RSS /
  128 MiB observed owned-output limits. No installs, affinity guarantee, SDK
  hermeticity or containment of unobserved hostile daemonization is claimed.
- Existing pinned public-source compiler-only excerpt and matrix scalar/digest
  privacy boundaries are unchanged. Diagnostic redaction is not a general secret
  detector; do not use it for user sources, inherited secrets or runtime output.

## Only compatibility exemption

The exact launcher sets both Clang/Swift cache environment variables and Swift's
`-module-cache-path` to the absolute owned `output/module-cache` path. No other
cache root receives a link exemption. LLVM's file-lock implementation creates
`<file>.lock` pointing to a same-directory `<file>.lock-<eight lowercase hex>`
unique regular file. Absolute same-directory targets are supported, as well as
basename-relative targets; both are covered using the actual frozen recipe.

`output_bytes` uses descriptor-relative, no-follow traversal/stat/readlink. It
counts the link inode's logical bytes, not the target through the link; the regular
target is counted through its own directory entry. It never traverses the link.
Only the documented filename/target pattern in `module-cache/**` is admitted.
Directory links, chain/loop targets, outside-directory targets, other scopes,
unknown forms and special files refuse with controlled codes. Missing recognized
lock/unique-lock entries and a missing exact same-directory lock target are
accepted as transient snapshot deletion; they do not authorize other dangling
links. Existing file-count bound remains 16,384; traversal also refuses over
32,768 entries or depth 32. These are sampled trusted-tool accounting rules,
not a hostile-filesystem sandbox or proof that polling sees every transient byte.

Upstream evidence inspected, not a claim about exact private Apple compiler source:

- [LLVM 20.1.8 LockFileManager](https://github.com/llvm/llvm-project/blob/llvmorg-20.1.8/llvm/lib/Support/LockFileManager.cpp): unique lock naming, create_link and removal.
- [LLVM 20.1.8 Path.cpp](https://github.com/llvm/llvm-project/blob/llvmorg-20.1.8/llvm/lib/Support/Path.cpp): createUniquePath replaces each placeholder with lowercase hexadecimal.
- [LLVM filesystem contract](https://llvm.org/doxygen/namespacellvm_1_1sys_1_1fs.html): create_link tries a symbolic link before hard-link fallback.
- [Clang ModuleCache](https://clang.llvm.org/doxygen/ModuleCache_8cpp_source.html): cross-process cache locks use LockFileManager.

## Failure ownership and resources

The first observed failure owns reason, phase, command context and finite safe
metadata. An observed nonzero exit is latched before post-exit monitoring. Later
retirement, command-finalization, postcheck, terminal-export and receipt-save
errors have separate first-per-stage codes; none overwrites the original cause.
Metadata is only output scope/type enums and bounded errno, never paths, exception
text, environment, command arguments or geometry. All guard invariants now have
specific reason codes; unexpected non-guard exceptions remain explicitly generic.

Finalization starts with a failed provisional artifact. On exceptional finalization
it writes a best-effort failed artifact without rescanning the refused tree. A
`lastValidResourceSample` is retained separately when available; it always states
`completeTerminalObservation:false` and `capComplianceEstablished:false`. It is
the last completed combined observation, **may itself exceed a limit**, and cannot
establish final cap compliance. No last sample is invented when none exists.
An inability even to write the failure artifact remains a nonzero launcher failure.
Success still requires the wrapper's zero-exit, full terminal/cap, pin and complete
route-acceptance conjunction; an inner status field alone is never sufficient.

## Portable checks and execution boundary

`test_launch_source.py` retains the 46 earlier portable fixtures unchanged.
`test_guard003.py` adds focused filesystem/fake-state regressions: relative and
absolute lock spellings, create/unlink and missing-target races, escapes,
directory/chain/loop links, actual recipe/cache path contract, first-cause
ownership, wrapped errno, nonzero-exit-before-post-monitor, and failed finalization.
No test initializes Guard, invokes a real subprocess or native compiler. One
constructor call site is exercised with Popen replaced by an inert fake.

The first portable test launcher could not find `/usr/bin/time`; no tests ran.
The next run found two fixture issues (the recipe fixture omitted @sdk, and the
chain test assumed a filesystem enumeration order). Their receipts are preserved;
the negative still requires refusal, while accepting either valid first chain/name
refusal. The corrected 62-test run passed. The final 64-test run (46 original + 18 new) passed after adding
nonzero-exit and wrapped-errno regressions: 0.228187 CPU seconds, 0.177905 wall
seconds and 22,524 KiB peak RSS, under 10 CPU / 15 wall / 512 MiB / one CPU. These are helper-source checks, not
Apple resource enforcement or route results.

Attempt identity is `003`, with fresh output
`$RUNNER_TEMP/blind-exact-seed-radius-stage-c-attempt003`. The command remains:

```text
python3 -B launch_stage_c.py --repository <exact checkout> --source-packet <materialized ec2 packet> --admission <root-created private admission> --output "$RUNNER_TEMP/blind-exact-seed-radius-stage-c-attempt003"
```

The separate workflow integration must bind this final manifest/schema and source
review, validate all new finite fields and keep the same outer timeout/export
allowlist. There is no permission in this packet to execute or retry.
