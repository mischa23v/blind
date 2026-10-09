# Contextual assistant integration evidence

Updated 2026-10-08. Source reuse and local verification are separate evidence. No Docker, model-weight download, Swift build, iPhone trial or child trial occurred for this expansion.

Latest: [native implementation/Mac handoff](NATIVE_MEMORY_HANDOFF.md) records GRDB revisions, room review, restart recovery, goal/dialogue dispatch, speech lifecycle and word/frequency controls now in source. Production SQL has four passing direct SQLite tests; Swift and iPhone verification are pending. Earlier relay/model numbers below remain historical checkpoints.

## Components

| Component | Provenance and current scope | Verification |
| --- | --- | --- |
| Ajv 8.20.0 | [Ajv repository](https://github.com/ajv-validator/ajv), npm gitHead `0fba0b8e649909613cfce0999b149cd08f4a4987`, MIT. Exact npm version/integrities in package-lock. Five small packages installed with lifecycle scripts disabled. | New bounded JSON schema and domain reference checks in `server/src/situation-context.mjs`; local integration tests pass. Ajv upstream suite was not run here. |
| GRDB 7.11.1 | [Release](https://github.com/groue/GRDB.swift/releases/tag/v7.11.1), commit `b83108d10f42680d78f23fe4d4d80fc88dab3212`. Seven inspected source/license files and hashes in `assistant-selected/grdb-7.11.1/SELECTED_SOURCE.json`. | Exact BlindMemory package dependency, migration/transaction adapter and license resource added. Production SQL checks pass; package resolution, Swift 6.1 compatibility, XCTest and Apple build remain pending. |
| Context relay | Existing HTTP relay and prompt path; Ajv validates bounded room hierarchy, pose, entities, provenance, goals, interests, delivered IDs, optional dialogue and arrival. | Stale pose, invalid references/floors, cycles, guessed identity basis, oversized dialogue, inconsistent arrival and excess answer words rejected in Node tests. Schema validation does not establish physical truth or verify a claimed identity match. |
| Word allowance | `Intl.Segmenter` relay word counting and rejection when oversized. Native `NarrationBudget` plus `NLTokenizer` now provide rolling dispatch accounting and independent UI controls. | Relay English/Arabic checks pass. Native single-producer accounting, segmentation and interruption behavior await Swift/device verification; general reservation arbitration remains open. |
| Model evaluation | Official Responses API, `gpt-6.1-sol`, synthetic text only, sequential bounded calls. | 8 room/social/interest responses plus 4 conversational-destination responses. Real provider answers saved; not image perception, OAuth, Dot or phone integration. |

## Commands and evidence

- `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs`: **24 passed, 0 failed**. Log: `artifacts/home-awareness/node-tests.tap`.
- Initial unchanged source evaluation: **1/11** context checks (only danger bypass). First connected relay: **11/11**. Exact original reports: `baseline.json`, `connected.json` under `artifacts/home-awareness`.
- First bounded Sol run: `sol-6-1.json`, **8 completed answers**, all within the requested 100 words. The initial fixture retained a living-room observation in the bedroom case; the answer correctly distinguished rooms. Later fixture generation removes that unrelated observation; the original result remains unchanged as historical evidence.
- Four new cases: `node tools/evaluate-home-awareness.mjs --model gpt-6.1-sol --label conversation-sol-6-1 --cases bathroom-arrival,bathroom-heading,goal-change,ambiguous-goal`: **4 context checks and 4 completed responses**, each within 100 words. These are independent supplied dialogue snapshots, not a running persistent conversation.
- `node tools/render-home-awareness.mjs` produces a local inspectable report from saved answers. The drawing is a fictional schematic; it was not input to the model.

## Review of actual answers

The original responses used supplied Maya/Omar associations, separated current/last-seen presence, described a possible sofa seat without guaranteeing access, included appearance/art, connected the fish tank to an explicit interest, and focused on Maya's movement during conversation. The bathroom response preserved the destination across bedroom entry, the computer response honored the goal change, and ambiguous “there” prompted clarification. Missing orientation/distance did not produce fabricated steps.

One keyword flag missed the valid phrase “isn’t confirmed”; keyword checks are not a quality score. Descriptive verbosity and repeated “supplied observations” phrasing need real-user tuning. The heading response still referred to separate Routes mode: the intended native experience must connect the same conversation to the route adapter so users do not need to switch modes for every step (O08). No response proves safe walking, reliable visual recognition, sustained operation or completed product percentage.

## Baseline and rollback

`artifacts/assistant-baselines/20261008-184236/BASELINE_MANIFEST.json` records 95 individually hashed pre-edit source files, including the original server. No Git repository exists. Restore only a reviewed individual file after comparing concurrent changes. New files are not removed by baseline restoration: situation-context source/test, home fixture/evaluator/renderer, model-access checker, package-lock and new research/evidence files must be reviewed separately. `node_modules` is a dependency cache, not source evidence.

The handoff packager now includes all root trackers and package-lock. It has not been run for this update; existing archives predate these changes. Generated report files stay local unless explicitly selected for a later handoff.
