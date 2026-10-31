# Independent saved-frame camera association review and historical proof

2026-10-28. This stage owns only the integrated reversible verification layer. Candidate implementation belongs to `research/saved-frame-diagnostic-association-20261028/CANDIDATE_MANIFEST.json`.

## Independent source review

No blocking source finding identified:

- Opaque, non-Codable receipt is camera-only, uncertainty unmeasured, with no transform or physical guidance permission.
- Receipt creation requires the exact latest validated capture timestamp, matching session and the real capture-time freshness lease. A retained earlier descriptor cannot silently associate a later capture.
- Recovery UUID changes after established tracking loss/gap/reset, preventing treating a newly recovered sequence as the old one.
- The pre-throttle interruption seam ignores foreign/pre-begin/older/duplicate callbacks, cannot establish normal-frame evidence, and forwards only actual relocalizing/unavailable evidence into the existing gate. It inspects no anchors or geometry.
- Native ARSession object identity guards precede callback effects; interruption/failure withdraw saved-frame evidence before existing critical retirement.
- Normal recovery observes actual receipt uptime, not a capture timestamp masquerading as receipt time.
- Receipt `arkit-session:<UUID>` source-frame naming matches the existing observation bridge.

Eight authored Swift test methods cover exact latest capture/clock, delayed lease expiry, throttled relocalizing, tracking loss/recovery epoch, obsolete callbacks, reset/new begin, unverified normal/bad anchor, and stale/future interruption. **Swift is unavailable and these methods were not executed locally.** Source review is not a sensor/accuracy or physical navigation result.

A receipt consumer/recorder overlay is not implemented by this candidate. Keeping past receipts as history does not renew current association. It remains inappropriate to turn this camera-only receipt into body, floor support, collision clearance or calibrated-error evidence.

## Reversible proof

`research/native-candidate-app-integration-85/integrated/saved-frame-camera-association.patch` is a separate NavigationModel-only overlay. It reverses candidate `fcea783bbbbaa4e1bdda04740fc38f11c10f30de1e6160d8eb5072d7b4a01298` to recorder checkpoint `f101f67cb88c6b2ea8847a380ce09a351322f73e01df0dcb9e0893146d4264d1` before every earlier overlay is reversed. The PBX remains `63fc5fcd1d9ef153c87ca48b9fa195f270fec3c039ee58887d407d46b300d87c`; no membership, generator, dependency or workflow change.

The integrated checker now explicitly requires the new session guard/recovery withdrawal at the start of failure/interruption handlers, then the prior critical-retirement ordering. It separately checks the frame owner guard and constant-work tracking hook before existing evidence retirement. No old patch, original hash or intermediate hash was rewritten.

## Executed evidence

- Independent selected source suite: **26/26** checks passed (`source-review.log`).
- Integrated historical checker: **49/49** source checks passed (`integrated-result.json`).
- No native build, Swift test, device run, download or upload executed.

```sh
node --test tools/test/saved-frame-camera-association.test.mjs tools/test/spatial-review-regressions.test.mjs
python3 research/native-candidate-app-integration-85/integrated/check.py
```
