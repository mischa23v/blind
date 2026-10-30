# Fixed resolution ablation stopped at its frozen enumeration bound

**All three 5 cm singleton baselines reproduced exactly. The first 2.5 cm map was built, then rejected by the predeclared 500,000 node/leaf enumeration guard before export or ray scoring. There are no 2.5 cm residual results from this attempt.**

| Actual outcome | Value |
|---|---:|
| Completed exact 5 cm cases | 3 / 3 |
| Fine case reached | frame 290, 2.5 cm |
| Fine tree nodes | 740,624 |
| Fine leaves | 637,567 |
| Frozen node / leaf caps | 500,000 / 500,000 |
| Fine cases scored | **0** |
| Wall / CPU time | 4.39 / 4.41 s |
| Peak RSS | 177,452 KiB |
| Address-space / CPU / wall limits | 512 MiB / 120 s / 180 s |

The process stopped as specified with `ValueError: map cap`. It did not hit its process memory/time limit, but RSS is not the same as virtual address-space consumption. The first fine map's build success does not establish that export/scoring or the other two fine maps would fit.

The original source, guard and attempt remain unchanged. No smaller residual, geometry improvement or safety conclusion can be claimed. The three completed case receipts and final failure receipt are preserved here; per-hit array hashes remain in their receipts and the local attempt directory.

## Separately proposed follow-up

A distinct reviewed protocol may raise only the internal node/leaf **enumeration guard to 1,000,000 each**, while retaining exactly the same 512 MiB address-space limit, 120 CPU seconds, 180 wall seconds, one CPU and 32 MiB per-file limit. Points, poses, resolutions, occupancy probabilities, accepted frames/pixels and scoring must stay unchanged. This is not an enlargement of the process budget, removal of a hazard, or a claim of safety. Source001 and its failure remain part of the record.

At one million leaves, exported arrays contain 52,000,000 bytes: xyz/size/probability 40,000,000, plus log-odds, hit counts and free counts at 4,000,000 each. The previous canonical hash path also builds a 40 MB in-memory NPY buffer and may retain its copy. A follow-up should stream exactly the same NPY serialization into a counting SHA-256 writer rather than buffering the complete NPY bytes. Small exact-equivalence controls and all three historical baseline payload hashes must confirm unchanged hashes before interpretation.

This reduces temporary hashing memory, not map size. Native tree storage, evidence maps, decoded depth, projection arrays, query arrays and allocator overhead still count against the unchanged address-space limit. Finer remaining views may still fail. Stop and preserve that failure; do not expand the process budget. The largest in-memory canonical array is not written as a >32 MiB file: saved per-hit arrays remain much smaller. No new dependency or native build is required.

The follow-up is proposed, not executed. This packet documents a bounded diagnostic failure, not sensor failure or navigation accuracy.
