# Training-observation diagnostic update — 2026-10-28 17:58 UTC

Three selected near-surface points from the large frame 228 discrepancy each have one depth return within the existing 20 cm axial comparison band: all three are in training frame 74 (residuals +2.8, +27.3 and +49.3 mm). The original 4 m integration cutoff excludes 39, 41 and 39 visible recorded returns respectively. Each of the three selected floor controls has five near-compatible observations.

This is a concrete lead involving sparse/conflicting observations, a depth boundary and the fixed cutoff—not proof of which frame generated a TSDF triangle or voxel. It does **not** establish the root cause, physical clearance, or a corrected map. No thresholds, geometry or original scores changed.

## Reviewed evidence

- [Full trace report](../open3d-same-data-benchmark-20261028/error-tail-diagnostic/TRAINING_TRACE.md), including selection, coordinates, limits and visual observations.
- [All 1,590 observations](../open3d-same-data-benchmark-20261028/error-tail-diagnostic/TRAINING_TRACE.json): six fixed points across 265 original training frames.
- [Independent review](../open3d-same-data-benchmark-20261028/independent-review/TRACE_REVIEW.json) and [recount script](../open3d-same-data-benchmark-20261028/independent-review/recount_trace.py): 11,180 checks passed, including exact sample pixels/statuses and all training depth hashes. Near-camera-plane floating coordinates use the explicitly reported tolerance.
- [Previous measured results](../open3d-same-data-benchmark-20261028/fresh-run/RESULTS.md) remain unchanged. [Earlier diagnostic checkpoint](../geometry-audit-update-20261028-1752/README.md) remains a dated record.

## Reproduction and publication limits

Scripts resolve paths relative to their own repository location; no machine-specific absolute paths are required to execute them. Producer manifests retain their original local source provenance, while their `repositoryPath` entries identify portable destinations. Run `trace_training.py` and then `../independent-review/recount_trace.py` from their saved locations after restoring the previously pinned inputs and evaluation arrays described in [the text-packet reproduction note](../open3d-same-data-benchmark-20261028/PUBLISHED_TEXT_PACKET.md). These inputs/arrays are **not** included in this text-only checkpoint. The plotting script also requires local RGB and writes a local figure; no photograph or figure is published here.

The original source, dataset and released-engine license notices remain in the linked prior packet; this diagnostic does not relicense those materials. The independent-review checksum list is updated for two new reviewed files, and its hash in the fresh-run checksum chain is updated explicitly. Older dated publication manifests retain their original historical hashes. No raw depth/RGB, figures, runtime/build files, private backup links or personal data are added. The 17:09 full audit remains a snapshot; this update does not mark the wider audit, reconstruction comparisons, native validation or navigation complete.
