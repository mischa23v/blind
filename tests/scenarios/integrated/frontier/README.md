# Black-box frontier plus real-module text evaluation

Four episodes, 23 authored child turns. Pending actual fresh-agent execution; no fixture assistant dialogue is supplied. Do not count as completed until transcript shows every turn handled and independent oracle review is complete.

## Source and scope

The executable compiles the unchanged production BlindCore source copied at build time. Production fact parser/book, memory wording, task scheduler and completion parser, clock lease, evidence guard and actual PlacePackage decoder run directly. Source hashes and exact harness/public/hidden inputs are in evidence/build-01. Copied production sources were compared byte-for-byte to live at 2026-10-25 06:08 UTC with zero differences; this is a source snapshot, not yet a root final commit receipt.

No toy memory/planner is substituted. The tool dispatcher and file-mailbox transport are authored test plumbing. Report storage requires the production named-report parser, but goal/control dispatch uses the harness's declared direct-user channel and is NOT native addressee/speaker verification. Candidate acceptance executes CompanionEvidenceGuard. Code-output token ownership/turn retirement is harness bookkeeping, except clock validity also runs the production clock lease. The run does not validate all native delivery pipeline gates. There is no registered movement episode here; map decoding is preview-only. This bounded harness must not be described as the complete app or iPhone loop.

User utterances and virtual times are authored fixtures, not child recordings. The only external map is the Autodesk OAS authored plan, read directly from the external dataset path; it has no route map, pose, image, LiDAR or inferred real localization. Its original age is unknown. No ARKitScenes pairing is made. Stored fact JSON dates use Swift Foundation's reference epoch (2001-01-01); wall_time and age_seconds are explicitly Unix seconds / elapsed seconds.

## Evaluation

Give a fresh evaluator only public/EVALUATOR_INSTRUCTIONS.txt and assigned episode IDs. Do not give project history, hidden/oracle.json, tests, production source or another evaluator's answers. Run one evaluator against one persistent process serially. Every response must be submitted through deliver_candidate or deliver_code. Exact model candidates, tool calls, outputs, rejected candidates and code state enter an append-only hash-chained JSONL trace. Text acceptance is not speech delivery. The evaluator should not grade itself safe.

Launch: python3 public/bridge.py serve EVIDENCE_BUILD UNIQUE_MAILBOX TRACE_JSONL
Call: python3 public/bridge.py call UNIQUE_MAILBOX '{"op":"start","value":"memory_correction_privacy"}'

A file mailbox is used because Unix socket creation returned Operation not permitted. No socket retry or network fallback occurred. Requests remain as .processed files and responses remain in the mailbox. A client timeout is explicitly uncertain and must be inspected before retrying. The original socket prototype is retained as an unsuccessful transport artifact, not used.

Current source executable: evidence/build-01/package/.build/debug/FrontierRunner. Initial harness compile failed due to Int versus UInt64 generation; exact original harness and compiler output preserved. A second build command failed due to missing private cache environment. Third build completed. These are harness/build setup failures, not production failures and not episode outcomes.

## Independent grading

After execution, reviewer reads the hidden oracle alongside complete trace and source manifest. Check every authored turn has actual output; rejected candidates remain failures even if a later response recovers. Distinguish tool-choice failures, semantic answer failures, fixture limitations and actual module failures. Never rewrite expectations to match output. Original 8 Core recovery failures and exact native failing/pass-after receipts remain outside this directory unchanged.

A successful run demonstrates only these frontier-agent plus tool text episodes. It does not establish 400 completed episodes, small-model performance, perception accuracy, speaker verification, native camera calibration, physical mobility or overall safety.
