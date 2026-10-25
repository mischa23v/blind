# Checkpoint29 — provisional search-area clues

Trusted short answers to a delivered, code-owned room/area question can now remain a **provisional user-supplied search clue**. They are not location facts, recognized rooms, current pose, physical clearance, object detection or completed goals. No new model or dependency is introduced.

## Useful continuation

- “Find my fridge” → code-owned room/area question → “kitchen” → “I'll use «kitchen» as a search clue.”
- “No, in the garage” can amend the clue only through its current source-bound amendment handle and the original question deadline.
- Arabic short answers follow the same ownership rules. A simple answer does not require redundant confirmation.
- Accepted clues survive elapsed answer deadlines and ordinary unrelated conversation while their goal/session/scope remains valid. Expired questions cannot accept new replies.
- New targets, cancellation, session retirement, source edits/deletions and matching privacy deletion retire the relevant context. Quiet/stop-description controls preserve the goal and accepted clue.
- Exact saved-place IDs affect only explicitly matching owner scopes; raw clue words never infer room membership.

## Evidence boundaries

The published checkpoint28 baseline delegated bare answers to the generic model boundary. The source regression demonstrates missing deterministic continuation, **not an observed failure of the real model**. The pre-privacy candidate additionally failed six assertions across four deletion episodes; those paths were repaired before final verification.

Twenty-nine extracted production-controller source-projection checks cover the continuation and privacy boundaries. They are not 29 native/audio/device journeys. Native purge/storage, platform sensors and speech sinks are explicit substitutes. Saved-place deletion is verified at the working-state/helper and adapter-source boundary, not as a complete native deletion journey. Portable word counting and forced overflow tests are not Apple's NLTokenizer. Production uses its real tokenizer before installing and replaying a clue; exact short acknowledgments also pass Core requested-answer admission at a fresh minimum30-word budget.

Original diagnostic logs are retained privately. Public evidence includes only minimal result summaries and changed-source hashes. Source aggregate and latest diagnostic overlay receipts are listed separately in verification.json.

## Native acceptance still required

On the exact published app revision, begin a fresh actor/session with no saved or observed fridge location. Through a trusted user interface, request “Find my fridge”; wait for the actual question completion callback. Answer “kitchen”, then “No, in the garage”. Capture actual queue/admission/Feedback completion events and exact output. Expected: audible, brief quoted clue acknowledgment; retained fridge goal; latest garage clue; no synthetic location fact, guessed pose, found/completed state or fabricated model reply. Do not inject a speech-completion result as evidence of device playback.

Repeat with Arabic question/“المطبخ”/“لا، في الكراج”; same-target physical rephrase; ordinary chat then returning to the same find; new target; cancellation; unknown answer; interrupted/expired question; source deletion and matching privacy forget. Check fresh minimum speech budget with maximum accepted English/Arabic answers, language switch and budget rejection. A real device/assistive-audio check remains necessary to judge intelligibility and ease, and a separately grounded search/retrieval journey is needed to establish the user's physical goal.

Unverified microphone input gains no ownership from this change. Restart clears transient hints and receipts. The separate “the fridge” versus “your fridge” naming-fidelity issue is not solved here. A stored search clue alone is not proof that the companion located or helped retrieve the object.
