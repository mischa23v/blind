# Source-only publication checkpoint (2026-10-27)

This publication includes evaluator Python source, static manifests/receipts, attribution and independent recount summaries for the first **5/100** scheduled outcomes. It is not a complete binary/data reproduction package and does not claim the remaining 95 outcomes. The running experiment and its frozen code are unchanged.

The raw source84 archive awaits separate tool approval. Neither that ZIP nor its contents are included here; evaluator-forward is excluded from that separate archive. Plans, runtime inputs, floor-cache binaries, episode evidence, run logs, mutable episode ledger and active lock are deliberately omitted. Manifest references and hashes of omitted files are provenance, not a claim that those files are included. CACHE_LEDGER.json is the immutable all-20 cache-preparation snapshot whose hash was verified against CACHE_MANIFEST.json.

## Original public data and pins

The original-source/evaluator [public release](https://github.com/mischa23v/blind/releases/tag/navigation-test-data-20261026) remains available separately. See ATTRIBUTION.md for MuSHRoom authors and CC BY 4.0 terms. These are public research inputs, not private camera or family data.

- `koivu_iphone.tar.gz`: 146,575,749 bytes; SHA-256 `68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518`. [Official original](https://zenodo.org/api/records/10230733/files/koivu_iphone.tar.gz/content); [unchanged release mirror](https://github.com/mischa23v/blind/releases/download/navigation-test-data-20261026/koivu_iphone.tar.gz).
- `koivu_mesh_pd.tar.gz`: 455,583,916 bytes; SHA-256 `e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26`. [Official original](https://zenodo.org/api/records/10222321/files/koivu_mesh_pd.tar.gz/content); [unchanged release mirror](https://github.com/mischa23v/blind/releases/download/navigation-test-data-20261026/koivu_mesh_pd.tar.gz).

## Rebuild boundaries

README.md retains bounded parse/cache/episode commands, resource limits, frozen evaluator and matrix hashes. PYTHON_DEPENDENCY_RECEIPT.json retains exact Python/package versions; ADAPTATION_RECEIPT.json retains original primitive and adapter hashes. FROZEN.json and CACHE_MANIFEST.json retain all input/cache pins, including files omitted from this source checkpoint.

In a **separate fresh workspace**, after obtaining the separately approved source package and required published historical primitive inputs, the preparation sequence is `python prepare_adapter.py`, `python prepare_reference.py`, `python prepare_matrix.py`, then `python freeze.py`. Supply the original reference archive at the path expected by prepare_reference.py and retain the frozen source cohort; do not overwrite the running experiment or infer that this checkout alone is sufficient. Compare regenerated hashes before using the bounded commands in README.md. Do not substitute new routes, geometry, cache fits or tolerances to force agreement.

Recount summaries preserve saved-evidence hashes, but episode payloads are omitted, so independent full recount needs the separately retained evidence. This checkpoint does not establish live localization, phone hazard detection, human safety, hardware verification or release readiness.
