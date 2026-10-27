# Stage83 — owned mesh to existing candidate runtime (isolated source)

This is an unactivated integration seam, not a new planner, app delegate, sensor
claim, localization result or physical-guidance authority. Reuses stage81 decoder,
stage82 owned ARKit snapshot and stage75 `BlindRoomMesh`/Recast–Detour runtime.
Stage81's 51 Apple host checks and stage75's 87 checks are upstream evidence, NOT
results for this stage. Stage82 and stage83 exact-source Apple evidence must be
checked separately. No UI, speech, haptics, cloud or persistence is introduced.

## Ownership contract

The short NSLock boundary is entered synchronously at callback ingress, before the
nonescaping capture closure. Every callback (including invalid receipt, failed
copy, capacity refusal and removal) retires the **outer** candidate token first.
Ordinary successful updates do not call `runtime.invalidate()` because that API
means a sticky unknown delivery gap. Failed/missed work does call it. Existing
runtime offer/request revisions provide the second downstream generation fence.
Consumers only receive outer candidates and MUST recheck owner `isCurrent` at use;
access to a route field is not delivery authorization.

The producer invokes the ARKit seam on its serialized owning callback queue,
after the independent hazard pipeline and NOT on the main/hazard callback.
Nothing here establishes ARKit producer synchronization or real copy latency.
The capture closure is synchronous/nonescaping. Only stage82 owned values cross
the serial decode queue; no ARMeshAnchor, Metal buffer or raw pointer is queued.
Default one, at most two aggregate capture/decode jobs stay reserved until actual
completion, including across reset/stop. The ARKit seam clamps each job to 200k
vertices/100k faces/16MB input/8MB decoded logical budgets before copying. These
are logical budgets, not an RSS measurement. Custom capture closures must honor
the same pre-copy budgets/ownership contract; this is not a sandbox for arbitrary
caller code. Runtime has its own existing bounded native mailbox, reused across resets.
Requires the separately reviewed stage75 late apply-error lifecycle fence; without
that fix, an old native failure can contaminate a new session's gap state.

A bounded anchor revision ledger retains tombstones; entries are not evicted and
reused. New-anchor or remove overflow marks unknown. Receipt uptime is explicit,
finite, nonnegative and strictly increasing within the session. It is NOT capture
time, sensor freshness or pose evidence. A fresh internal UUID epoch on every
reset prevents A→B→A reuse; revision counters are checked before Int conversion.
Copy completion checks epoch, stop and exact anchor revision both before decode
and before installation. Newer refused same-anchor frames still supersede older
copies; an old epoch cannot mutate the new epoch. Exact removal produces the
existing empty `removed` event, never another anchor's deletion or inferred free
space. Accepted superseding updates discard obsolete copies without introducing a gap.
Gap success does not erase earlier unknown coverage. Only an explicit new
session reset resets that delivery history.

Decoder local vertices and column-major transform are passed unchanged (Float to
Double only); stage75 applies the transform once. Classifications remain stage81
validation diagnostics, not walkability, support, clearance or physical authority.
`complete: true` means complete delivery of this bounded revision, not real-world
coverage. The existing runtime still reports actual-world coverage false.

## Deliberate unresolved privacy interface

`stop()` fences output. It **does not purge**: stage75 has no public drain/discard
acknowledgement and retains its native owner. Outstanding copies and native work
can retain private geometry until they actually complete/release. Reset is also
not a privacy purge. Do not wire privacy erase or camera-off deletion to this seam
and claim erasure. A reviewed downstream drain-and-discard API, plus acknowledgement
that owned copy/decode jobs have drained and released their values, is required
before any privacy-sensitive app activation. This folder does not change stage75
to force that missing interface. Cancellation does not imply memory erasure.

## Evidence and handoff

`tests/main.swift` authors real-runtime synthetic add, replacement, exact removal,
reset/ABA, immediate pre-copy retirement, failed copy, sticky gap, strict receipt,
ledger/remove overflow, bounded outstanding work, superseded copy, late old-epoch
completion, stop and candidate-current checks. A translated floor checks exactly
one transform by querying the real native package, not a replacement planner.
Host fixture execution and actual ARKit Simulator compilation are pending; no
Swift compiler is installed locally. Local static contracts are not Swift tests.

`apple/ci.py` builds the actual stage75 package using the established serial native
SwiftPM compatibility variant, links its objects, builds stage81/82/83 modules,
runs host fixtures, and compiles/links actual ARKit Simulator source without
launching a simulator. The inert workflow proposal is for root review/publication
on the existing authorized review branch. Exact source manifests and bounded
receipts identify the inputs. Source-only compilation cannot establish real
ARMeshAnchor callback behavior, copy latency, hazard prioritization, phone memory,
tracking/localization or participant safety. Device/resource and privacy acceptance
remain open. No shared tracker, app source or workflow was changed here.
