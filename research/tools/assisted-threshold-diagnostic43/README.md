# Assisted threshold diagnostic43 checkpoint

# Stage43 result: partial assisted sill motion, no completed journey

The nominal45x30x160cm actor travelled1.616166m horizontally and1.652689m in3D over98 ticks. Entry did not finish; return was not attempted. Executed movement reported0 body/margin/underbody contacts. A rejected pre-commit sweep reported1 predicted body overlap (and the identical zero-margin envelope overlap), not an actual collision.

It stepped upward at the old1.5m stop. At tick97, however, a corner probe moved from the wooden top onto its ramp and the nine-point maximum lowered the rigid body while an interior part of its footprint still overlapped the top. Exact face16815409 is in the frozen typed TOP set. Its full triangle height is19.451–20.377mm, while the second half of the rejected FOLLOW sweep begins at20.197mm after its2mm bottom exclusion. This is an inadequate finite-sample support placement law, not a narrow doorway result. No geometry has been erased to make it pass.

Run01 reached the same terminal trace but failed writing a NumPy boolean toJSON. Its complete trace, logs, original frozen manifest and source snapshot are preserved. Run02 changes only boolean normalization and output-directory routing; its trace arrays exactly equal run01.31 authored fixtures passed before retry. Run02 completed within36.77s wall/37.06s CPU/2.13GiB peakRSS. A future geometric support-envelope variant must remain separate and preserve this failure.

This used manually annotated reference-world sill geometry and reference support heights, not automatic phone-only perception or human walking validation. The horizontal source route was unchanged. Old partial annotation, original proposal and stage40 failure remain available. See CURRENT_PROTOCOL.md, run-02/result/RESULT.json, postrun/RECOUNT.json and exact ACTUAL_TRACE.csv.

## Archive

Lossless archive contains 97 checked files plus manifest. SHA-256: `88103aa3a6916e5f9f8c57824d4c1eeb5d6e7f3a6acefe786e6d0af0c841c680`. See MANIFEST.json for individual source paths and checksums.

# Assisted threshold diagnostic43

Read RESULT_REPORT.md first. The actor moved1.616166m but entry and return did not complete. This is a failed assisted simulator support rule, not a validated navigation system.

- CURRENT_PROTOCOL.md describes the explicit reference-world assistance and frozen behavior.
- FROZEN.json pins437 original inputs plus the serialization regression log. Original run01 frozen sources are retained in run-01/frozen-source/.
- run-02/result/RESULT.json and postrun/RECOUNT.json contain terminal evidence; ACTUAL_TRACE.csv contains actual positions only.
- complete-manual-sill/ defines the manual physical-object association; manual-sill-association/ preserves the earlier incomplete annotation.
- Historical PROPOSAL.md and STATUS.json intentionally remain unchanged and describe the earlier state, not current completion.

Reproduction needs prior full repository research inputs listed by exact path/hash in FROZEN.json, the published Polycam comparator archive (master4211356), earlier room-test/query-performance assets, and the public660550085-byte FARO reference mesh from the navigation-test-data-20261026 release. This compact packet is not standalone and contains no replacement raw scan.

Stage45 is a separate mathematical support-envelope correction. No stage45 result is claimed here.
