# Published text packet

This repository packet contains the byte-identical text files selected by the producing Open3D worker's publication manifest, plus this publication note and the geometry audit addendum. It includes the reports, protocols, execution receipts, numerical aggregate/per-view results, reproduction scripts, independent main-metric review and DN-Splatter Apache-2.0 license.

The optional derived PLY meshes and NPZ ray arrays (approximately 63 MB) are **not included**. Neither are raw RGB/depth images, original archives, FARO geometry, wheels or installed packages. Local paths and hashes inside original receipts describe retained execution evidence; they are not claims that those files are published. Recount scripts require the arrays or a full reproduction using the pinned public inputs and runtime.

The original fresh-run publication manifest and checksum list also describe optional local binaries. They are intentionally not presented as this text-only packet's allowlist. The authoritative publication manifest is `../geometry-independent-audit-20261028/OPEN3D_ADDENDUM_PUBLICATION_MANIFEST.json` at this commit. Its SHA256 sidecar binds that manifest.

See [fresh results](fresh-run/RESULTS.md), [reproduction and licenses](fresh-run/README.md), [independent main review](independent-review/REGISTRATION_REVIEW.md), and [audit addendum](../geometry-independent-audit-20261028/UPDATE_1732.md). The exploratory edge diagnostic is post hoc and has a separate 92-check independent recount; it is not part of a preregistered acceptance score.
