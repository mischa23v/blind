# Observation-only OctoMap ray adapter: saved build and control verification

The actual fresh build at source commit `b9d58e91637932a5d74cad68118d4a9ea870eee5` completed with exit zero. All **48 synthetic controls passed**: 16 original occupancy, 22 unchanged conservative read-only ray, and 10 new observation-only ray controls. No failures, errors or skips. This packet independently checks the saved receipts, exact named test log, input/toolchain hashes, and produced library hash; it does not load the library or rerun native work.

The separately named `om_ro_observed_rays` calls official OctoMap `castRay(ignoreUnknown=true)`. Its hits have status 9, **observed-hit-visibility-unverified**. This reports an observed occupied voxel along the ray, not proof that unseen nearer space is clear. Occupied origins are refused. The original `om_ro_rays` and ordinary Python `cast()` remain conservative (`ignoreUnknown=false`), retaining unknown-origin/gap refusal. Explicit observation queries cannot override the prior primary result's 18,904 unknown rays or authorize movement.

Binary SHA-256: `82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26`. Binary is deliberately not included. Source manifest: `98ddf1a4cd0cadb285509389f6b7ba2ae40e94558e6e1cd19db83bb79a04a14f`; build pins: `c38fe60ad36ee4ab5ee20dba52e8bf84a6ce9bd91f539f59e6f771ba7827b5e2`.

Build: 12.383900 CPU seconds, 12.403244 wall seconds, 184,532,992 bytes maximum sampled/waited RSS. Guard reports child process group retired and identical before/after source hashes. Control worker: 0.229813 CPU seconds, 0.174871 timed wall seconds, 34,136,064 bytes peak RSS. CPU includes startup outside the worker's wall interval. A separate outer process-group receipt for controls was not supplied; worker receipt/log and root-observed terminal success are distinct evidence.

The earlier conservative v1 compile failure remains archived unchanged. Its Vector3 accessor problem was resolved by 15 `[]` to official `()` corrections in the separate v2 source. This new observation adapter extends that successful v2; it does not rewrite either earlier attempt.

## Reproduction of this verification

From the workspace with original pinned source/build/control artifacts retained:

```
python3 -B -I blind/research/coffee-observation-ray-controls-result-20261030/verify_saved_result.py
```

Compare stdout with `VERIFICATION.json`. Only Python standard-library reading/hashing/parsing occurs. The seven small text files are listed in `PUBLICATION_FILES.json`. Copied receipts and test log preserve original bytes.

**Scope:** synthetic adapter controls only. No real heldout frames tested by this build/control packet; no safety, visibility, route, navigation or child-use validation. A separate data-driver review and bounded run are required for observation-only depth consistency. The original conservative result must reproduce unchanged alongside it.
