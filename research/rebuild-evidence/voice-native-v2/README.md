# Voice native-v2: observed protected-storage gate failure

Exact commit `50d503f03b126c8b6e1533b794dee54c8e35f920`, [run 40207102790](https://github.com/mischa23v/blind/actions/runs/40207102790), terminal **failure**.

- Actual iOS SDK typecheck passed.
- Three native XCTest methods executed: the attribute-representation/negative-input test passed; both save/delete scenario methods failed at the protection verification guard.
- Safe metadata from synthetic temporary storage: `excluded=true typedComplete=false rawComplete=false attributeType=missing`.

The selected iOS 27 simulator did not report the required protection attribute in this fixture. Exact raw-value normalization therefore cannot establish complete protection. The implementation correctly continues to reject it; this run is not an actor storage pass. It does not prove behavior on every simulator or physical device, nor establish whether platform/environment details would differ on an iPhone.

Do not weaken the guard, skip the scenarios, substitute a fake protection result or claim missing protection means success. The smallest remaining native acceptance needs the isolated synthetic harness on an authorized physical iPhone/Xcode destination with actual complete protection and backup flags, followed by controlled lock/unlock and failure cases. No private audio/enrollment data is needed or authorized. Device/signed-test provisioning is not provided by this cloud run. Production single-owner/lifecycle and UI retry integration remain open.

The native-v2 representation helper is separately tested against typed/String/NSString exact complete, missing/weaker/unknown/numeric inputs. This pass does not identify the original failure as a cast bug: actual diagnostics show the attribute was missing. Original 71-check archive, first host crash and second guard rejection remain historical evidence. Nothing is wired into the app, and no speaker identity/authority claim follows.

This evidence is outside the probe push filter to avoid retriggering a known failing native run merely to record its result. No source or workflow behavior is changed by this result packet.
