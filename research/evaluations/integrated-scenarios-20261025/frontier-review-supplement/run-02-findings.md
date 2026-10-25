# Run 02 findings, before independent semantic review

Four bounded frontier-plus-real-module text episodes completed 23 authored turns. There are 79 calls including one readiness probe, 9 accepted code-owned outputs, 14 accepted frontier outputs, and 4 rejected frontier candidates. Every turn has accepted text and all four final next_user calls return done=true. The hash-chain audit has zero errors. This is not four native/device episodes or evidence of 400 complete scenarios.

The original run01 interruption evidence is retained. Its two evaluator requests have no recorded execution, response or processed receipt; volatile managed session53796 disappeared after the owner turn ended. Run02 explicitly started fresh with unchanged source, binary and fixtures. Managed session14057 was kept active throughout evaluation.

## Preserved failures and interpretations

The unchanged hidden code-state audit reports 14 PASS and 1 FAIL. Its terminal-state assertion for resume requires active at the end of the turn. Actual sequence37 correctly resumes into active with the backpack request and school goal preserved. Sequence38 then runs task_next, which reports unavailable(findItem) and changes state to needsHelp. This is a temporal assertion limitation, not evidence that resume failed. The original audit output and expected result remain unchanged; independent review must adjudicate rather than relabel silently.

Four actual uncertainty/refusal candidates were rejected by production CompanionEvidenceGuard. The exact proposals remain in the trace/output-counts artifact. Their content denies knowing/seeing or giving reliable steps. These are conservative false-positive-looking model guard rejections, not unsafe delivered physical claims. Later supported replies were delivered. Do not call the run clean merely because delivery eventually succeeded.

The harness exposes the model candidate guard and exact memory/clock code responses, but omits native automatic code-owned unavailable rendering. Native NavigationModel calls CompanionEvidenceGuard.unavailableReply through deliverConversationReply after certain model publication/revalidation failures (source-inspected lines3701,3725), and codeOwned speech has a separate branch (lines3213–3260). Native generic fallback is "I can't confirm that from the information available. An earlier report isn't confirmation of the current situation." Consequently the trace does not establish that the app would remain silent or require three model rewrites on these exact inputs. No native execution is claimed.

## Historical evidence after resume

At sequence25 the actual scheduler selected savedMemory before any backpack report existed; the harness correctly submitted unavailable and advanced to findItem. Sequence29's later report populated FactBook without resetting scheduler progress. After resume, sequence38 therefore selected findItem, which is intentionally unavailable in this reduced harness. Sequence39 explicitly read and sequence40 delivered the dated backpack history. The information was not lost; it was not automatically reselected by the standalone coordinator.

Source inspection of native NavigationModel shows materially different wiring: routeEverydayTask supplies all adapter capabilities, consumes memory first, and returns false for findItem so the existing item handler runs (lines3046–3083). Resume invokes that route then handleItemOrLocate (3175–3178). The item handler uses fact.recall if findWithSensors returns false (4731–4734); no eligible camera makes locate return false (4853–4855). Thus no native history-suppression bug has been demonstrated by this reduced harness. Native callback/camera behavior remains unexecuted here.

## Scope

All utterances and time are authored; no child recordings, actual speaker identity, images or poses. OAS is the genuine external authored preview package, never paired with ARKitScenes. Tool dispatcher origin checks and code-output IDs are authored plumbing, not native voice/delivery verification. Actual production Core parser/book, task scheduler/completion, clock lease, evidence guard and map decoder ran. Source hashes and source-only native inspection snapshot are pinned in the freeze receipt. Original eight Core recovery failures and prior native failure receipts remain untouched outside this run.

## Independent review completed

Independent reviewer verified the frozen trace and all 23 delivered turns. Conclusion: bounded text episodes completed, not a clean or full native-app validation. No delivered unsupported physical claim was found. Four benign-refusal guard rejections at 41/59/62/63 remain findings. Exact review is run-02-independent-semantic-review.json (SHA2565425ca16f0244fd9989c3234d7e4c9eef50be099ade7db14bda63d7f6e4ddbb4).

Coverage gaps within broad oracle wording are explicit: these four episodes do not include a named wrong-item completion turn, an attempted stale code-token replay, or dispatch of an expired clock lease. Reacquiring a clock after eight seconds is not testing stale dispatch rejection. Those missing obligations are not passed merely because related component tests exist. The original state audit remains 14 PASS / 1 FAIL with temporal interpretation above.
