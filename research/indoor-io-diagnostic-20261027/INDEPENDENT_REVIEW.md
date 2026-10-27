# Independent static review

Reviewer: `/root/diagnose_native_navigation_test/review_focused_io_harness`
Outcome: Approved for root publication/launch after static review.

Initial findings, resolved before approval:
1. Added review-branch/path-scoped push trigger; no reliance on default registration for new workflow dispatch.
2. Exact original case-name sets required; earlier failures remain sticky across duplicate terminal outcomes.
3. Increased outer step/job bounds to 50/55 minutes around the unchanged bounded invocation budgets (18-minute build, four 6-minute tests).

Reviewer confirmed no production changes, assertion relaxation, UI execution, signing or full-result upload. Publishing the two workflow/helper paths automatically launches the diagnostic. Native correctness remains unverified until the actual run; reviewer executed no commands or tests.

Author local checks: Python AST parse, YAML parse/serial matrix assertion, original failure-line regex match. Helper not executed; no build/compile/cache created. No external writes made.

## Trigger-isolation re-review (supersedes original helper destination)
Root identified that `tools/ci/**` would activate the existing broad native Apple workflow. Helper publication destination, focused push filter and run path changed to `research/indoor-io-diagnostic-20261027/focused-indoor-io.py`. Helper bytes are unchanged.

Independent reviewer: **Approved revised paths.** Neither publication path matches existing native-Apple or room-mesh filters. Both match the focused workflow among those three workflows. YAML checkout/run/filter agree; pins, test scope and time bounds unchanged. Publish both files atomically in one commit to avoid missing-helper launch.

Author independently fetched both existing workflows at exact `8d878c86ab0b3a96d5fd44b31b418fbdc9bc5ed6`, parsed current YAML and checked all path matches. Existing source, workflows and native-apple.sh were not edited. No external writes or native execution.

Final publication hashes:
- Helper: `39684d595f5c788e2d677368553381eb4a609160c9465d137013e6f26068d6e4`
- Workflow: `24307aa95d4f2967613ee975aea59f1ab05b630300ee23c5a60427f2327a9d96`
