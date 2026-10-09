# Selective attention and fast screen-reader listening

Researched 2026-10-08. Evidence and proposed product policy, not implemented behavior. See [engine](MEMORY_AND_INFORMATION_ENGINE.md), [tasks](../TASKS.md), and [acceptance scenarios](ASSISTANT_TEST_PLAN.md).

## Evidence

The user later supplied Sol's extended report. [Reviewed additions](SOL_IDEAS_REVIEW.md) add primary research on conversational control, camera framing and category-specific notification choices, plus explicit last-seen/change scenarios. Preserve the user's priority and high-detail options; the report's quiet-default suggestion and illustrative ranking equation are not adopted as universal policy.

| Primary source | What it supports | Limits |
| --- | --- | --- |
| [Dietrich, Hertrich and Ackermann, 2013](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2013.00701/full) | Studied JAWS/Eloquence training with five late-blind adults and one sighted adult, targeting 18 syllables/second. Performance varied substantially; the paper also discusses earlier highly skilled listeners. Fast listening is a real learned capability. | A small adult laboratory study, not a universal listening rate, child result, or walking/navigation trial. Syllables/second cannot be converted to one language-independent words/minute value. |
| [NVDA official user guide, Speech Settings](https://download.nvaccess.org/documentation/en/userGuide.html#SpeechSettings) | Provides rate controls and a rate-boost option when supported by the synthesizer. | A rate setting is not a measured comprehension score or a universal words/minute value. |
| [JAWS official hotkeys](https://www.freedomscientific.com/training/jaws/hotkeys/) | Users can change rate during Say All, including Page Up/Page Down, and control speech modes. | App content budgets should not override these user controls. |
| [Apple VoiceOver rotor documentation](https://support.apple.com/en-ie/guide/iphone/iph3e2e3a6d/ios) | VoiceOver supports adjusting speaking rate through the rotor. | The app should provide accessible content and announcements; it need not manage the person's chosen speed. |
| [Droll, Hayhoe, Triesch and Sullivan, 2005](https://www.cs.utexas.edu/~dana/Droll.pdf) | In a virtual brick-sorting experiment, task relevance influenced acquisition, storage and detection of changed visual features. Attention is selective and depends on the current task. | This does not supply a universal list of what sighted people notice, nor a validated speech-ranking algorithm. |

## Product interpretation

The following rules are engineering inferences from the evidence and the user's requirements. They are not a claim that this app reproduces human vision or that a paper validates its mobility performance.

Offer a broad world model and selective delivery. The person may want rich descriptions of furniture, clothes, art, people and available choices. A short default is not a ceiling on their ability. Separate **detail**, **information rate (words per time window)**, **frequency**, **interests**, and **automatic/on-request mode**. Do not read speech speed as an expertise score, and do not automatically assign children or new users a fixed information limit. Enforce the ordinary word budget before generation and speech admission: changing VoiceOver speed cannot by itself limit how much text the app produces.

Maintain three explicit priority classes:

1. **Danger: immediate preemption.** A supported current danger event bypasses ordinary memory, identity, objective, novelty, preference and language-generation gates. It interrupts lower-priority output and uses the available local speech/haptic path. Existing detector validity checks do not become a slow secondary review. An unresolved detector observation must not be promoted into a confident hazard assertion.
2. **Mobility and orientation: next.** Due route cues, loss of localisation, required turns, doors, floor transitions and exit orientation take priority over descriptive content. These need current pose/route evidence. Necessary cues are not withheld by an exhausted ordinary narration budget. Repeating routine guidance without need must not monopolise speech.
3. **Awareness, discovery and description.** Answer requests and select useful social/environmental/interest information through the eight gates. Rich narration is available while stationary and while moving when timing permits. Danger and due mobility cues can interrupt it at any time.

Priority is a delivery rule, not an LLM prompt that the app hopes will be followed. Connect inspected event/speech primitives to a small explicit domain policy. Record reasons and evaluate the integration. No reviewed upstream supplies this entire policy prevalidated for this product.

## What to offer, keep available, or suppress

| Situation | Candidate information | Selection behavior |
| --- | --- | --- |
| Entering an unfamiliar room | Position/facing if known, exits, layout, people, notable features | Orientation first; overview then optional rich detail. A mapped door need not be in the camera view. |
| Walking toward a shop | Next relevant turn, shop identity, landmark, changed obstruction | Due navigation first; offer useful nearby discoveries without repeatedly enumerating all signs. |
| Walking with family or a guide dog | User-selected surroundings, people, displays, dining options | Companion context may support more description; it does not prove clearance or disable hazard alerts. |
| Waiting or sitting | Décor, clothing, activity, people, art, objects of interest | Allow fuller descriptions at the selected frequency; respond to quiet or conversation controls. |
| Familiar room unchanged | Known layout and already delivered details | Keep available for questions; suppress unwanted repetition. Announce relevant changes. |
| Person approaches or changes seat | Observed movement, supported identity, current/last-seen position | Report the observation; do not invent an intention to speak or silently convert old positions into current ones. |
| Goal changes to dining | Nearby choices, observed signs versus map listings, remembered preferences | Change relevance while retaining entrance, companion/meeting and return context. Offer alternatives beyond past preferences. |
| User asks for everything | Detailed grounded description in interruptible chunks | Preserve requested richness; replace stale spatial statements instead of building an unlimited queue. |

Not selected for speech does not mean deleted from all memory. Keep stable place knowledge and useful outing events; expire transient tracks and redundant frames. Long-term preferences come from explicit input or reviewable corrections, not a guess that silence means disinterest.

The engine must reserve opportunities for novel choices outside the current objective. A sighted person can discover a restaurant without first knowing its name; the assistant should support that agency too. The scope and frequency are user-controlled.

## Delivery and evaluation

Text appearing on screen does not itself guarantee hands-free VoiceOver delivery. Use documented announcements, completion/interruption handling and a bounded queue without moving focus. Revalidate affected content after a turn, a delay, a person moving or a map update. Complete speech is not proof of comprehension; the ledger tracks delivery, not the listener's mind.

Evaluate the same scenes with short and rich detail, different user-chosen screen-reader rates, stationary and walking conditions, companions, interruptions and repeat requests. Measure task success, useful discoveries, comprehension, repetition burden and late/missed cues. Do not infer walking performance from a quiet-room reading result. Child evaluations follow the staged protocol in the test plan.

This research supports accommodating expert throughput and individual choice. It does not support a fixed maximum amount of information for every blind user, perpetual talking regardless of context, or a claim that reading speed establishes safe independent mobility.
