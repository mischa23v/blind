This checkpoint is historical. The later [context-driven increment](CONTEXTUAL_CAPABILITIES_ACCEPTANCE.md) adds passive/goal-driven triggers and replaces the default-off familiar-gallery dependency described below.

# Everyday companion: tools, memory and task continuity

## Scope and purpose, 2026-10-23

The product goal is a free on-device personal assistant with useful continuous context, not primarily navigation and not a menu of isolated scanners. Reading, conversation, belongings, known people, shopping and room memory should cooperate. This increment connects existing components; it does not establish all-day reliability, general autonomous planning or safe unsupervised physical assistance.

## Implemented source

- The existing read-only `savedMemory` tool now retrieves relevant original reports, explicit saved belongings, dated observed-object candidates, saved places, preferences and task/list records. Four records/800 scalars; original report IDs/order retained; coordinates excluded. Historical observations never become present identity/location. A missing match is unknown, not absent. No new database or remote storage.
- An app-owned bounded task coordinator selects the existing reader, document, barcode, colour, banknote, known-person, clock and item adapters for supported explicit requests. It preserves a parent goal across subtasks, retains bounded retry counts, rejects old dispatch tickets, and distinguishes information obtained from a user saying a step is done. Physical find requests still pass the original evidence gate. The model's own tool remains read-only.
- A private shopping checklist accepts explicit English/Arabic additions, removals and read requests. Entries retain original user words and timestamps in the existing `companion` store. No image/model output marks an item bought, possessed or paid for. No transaction or inferred balance is created.
- Automatic saved-room recovery ranks fresh appearance, previous/adjacent room and fresh coarse location as candidate clues. At most three map attempts per episode, with deadlines/backoff; requested reading/conversation defers new attempts. A candidate is never a validated pose. Exact saved-frame/anchor verification remains mandatory. Exhaustion leaves conversation/RGB available and does not repeatedly ask for manual selection or reset the session.
- Document/barcode entry now checks the available view before asking the person to manipulate the phone/product. Existing evidence-based framing guidance remains when actually needed.
- Existing proactive consented known-person gallery notices and independent hazard priority remain. Recognition still requires its existing enablement flow and defaults off; passive encounter handling is not default-on eligibility. Removing that normal-path activation dependency is a separate next slice. Known people can be friends or teachers as well as family; strangers are not automatically identified.

## What is not implemented or proven

- Voice is not meant to become a spoken command menu. This increment's explicit dispatcher does **not** fulfill automatic context-triggered tool selection. Known-person encounters have passive triggers only after the existing recognition service is enabled, while bounded room recovery starts automatically; money still needs an initial request, then may retry once. Goal-relevant light changes, a visible banknote candidate automatically invoking the dedicated verifier, and shelf/product assistance automatically following the shopping goal remain unconnected paths. Never announce a detector/model denomination as verified money.

- The coordinator is bounded routing/state, not an LLM planner with unrestricted actions. Natural language outside supported parsers can still fall back to ordinary conversation/scene handling. Single-shot currency/colour checks can make one bounded fresh-frame retry while the same task remains active and the device is ready/quiet. White/neutral-colour uncertainty is not retried as though another photo would certify it. Continuous readers/item search and known-person work retain their existing loops. Currency manual “try again” retains its separate finite retake budget after automatic attempts; two coordinator attempts is not a global lifetime capture maximum. This is not autonomous cross-tool replanning. Full task completion such as dressing, shopping or cooking is not demonstrated.
- Known-person adapter completion is not yet fully reflected into the general coordinator; the existing face service owns its own capture/operation lifecycle. Portable coordinator fixtures are not native callback proof.
- Lists are explicit user-authored records, not inferred routines. Automatic confirmed routine learning, multi-step recipe execution, financial bookkeeping and general semantic search remain gaps.
- No general detector asset is added. Historical saved locations, room inventories and candidate boxes do not establish target-bound depth, pickup safety or present ownership. Physical action gates remain in force.
- Camera-derived exact white/gray verification, actual money accuracy, face accuracy/latency, relocalization thresholds, actual model compliance, VoiceOver, thermal/battery and background behavior require native device work.
- The map implementation must be described by the actual configured adapters, not assumed to be Google Maps. Online weather remains unavailable until a real source is integrated.

## Acceptance checklist

| Scenario | Source/scripted evidence | Native acceptance still required |
| --- | --- | --- |
| School goal, find coat, ask time, return to backpack | Parent/subtask retention, no tool success recorded as possession, zero unnecessary prompts in successful fixture | Actual model language, retained conversational goal and audible timing |
| Previously seen coat outside view | Query-specific dated candidate history and explicit save/report provenance; no coordinates passed to LLM | Correct instance, room and update behavior on phone |
| Read label/page; interrupt with ordinary chat | Existing Vision adapter selected, current work token plus coordinator ticket, paused task retained | Speech onset, stop latency, resumption, OCR quality |
| Which outfit is white? | Existing neutral-colour abstention preserved; no generative colour fallback | Calibrated lighting/material evaluation; no white-uniform certification |
| Add/read/remove shopping entry | Exact original quote, bounded local persistence, English/Arabic parsers; no inferred purchase | First-tab and VoiceOver end-to-end workflow |
| General question about money | Shared inspection policy leaves ordinary definitions in chat | Actual small-model response quality |
| Silent known person enters then leaves | Existing encounter/freshness policy preserved; stale claims cannot gain authority from coordinator | Camera field of view, recognition model latency and notice before departure |
| Lost room during reading/chat | Background new map attempts deferred; deadline/backoff/no reset storm in scripted policy | ARKit relocalization, actual scheduler timing and task priority |
| Wrong or absent room candidates | Bound three attempts, ambiguity not pose, unavailable once | Real lookalike rooms and coarse-location errors |
| Old cancelled task result arrives | Exact task ticket/generation plus existing capture/operation fences | Native race/foreground/background tests |

## Validation record

Portable validation for this increment: **647 BlindCore**, **16 BlindMemory**, **273 Node** tests passed; **16 extracted working-state tests** passed. Default and DEBUG/familiar-person iOS sources parse; firmware protocol and ASan/UBSan failure injection passed (LeakSanitizer excluded under executor tracing). Aggregate verify passed in a disposable source copy and generated a byte-identical Xcode project. These are not Apple SDK, model, physical-device, VoiceOver or latency acceptance.

Native audio acceptance must include VoiceOver reading while ordinary TTS is queued, hazard preemption without competing ordinary audio, a child interrupting repeatedly, environmental-listening gaps, first useful reply before a known person leaves, and upright/rotated/chest-mounted capture. Neither a general orientation assumption nor word-level tests prove these behaviors. Existing adapters still impose capture constraints; hands-free intent is not proof all orientation/framing burden has been eliminated. Swift parsing is not Apple SDK typechecking; source contracts are not actual camera, model or audio tests. No new weights, image datasets or cloud API credentials are included.

## Upstream reuse

This increment reuses Foundation Models' existing read-only local tool adapter, Apple Vision readers, existing ARKit saved-world-map recovery, and the app's GRDB-backed MemoryStore. It adds only bounded orchestration, attributed retrieval and explicit checklist policy. API references already documented in `research/ASSISTANT_UPSTREAM_REVIEW.md`, `research/MEMORY_AND_INFORMATION_ENGINE.md` and the spatial acceptance document remain applicable. No copied third-party model/backend is introduced.

## Next bounded implementation slice

Add a context-event adapter coordinator, beginning with existing measured light/visibility changes and supported banknote candidates. Require active foreground permission, current evidence, relevant user goal, bounded work budget, cancellation and deduplication. Invoke the existing dedicated verifier before any claim; do not treat a generic label as denomination or identity. Use the existing information/attention gate for a once-useful notice, not repeated scanning speech. Product identity/where-to-reach remains gated by actual supported visual and geometric evidence. Optional helper tabs can remain, but they must not be prerequisites for the ordinary assistant loop. This is the next task, not a feature already implemented by this commit.
