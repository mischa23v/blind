# Koivu matching-height / reference-coverage audit

**This is not a safety validation or a movement experiment: 0/100 game episodes.**
The frozen 1,413-column evaluator pass completed in 86.32 s (85.62 CPU s),
2.14 GB peak RSS. Thirty-two small authored/source-contract fixtures pass.
Every original saved reference score was reproduced before new bands were scored.

## Main results

- Original statistical-object headline: 44/1,035 low-band matches ≥2.5 cm.
  Its existing low-or-body union is 100/1,035; including 1–2.5 cm gives
  143 vertex-positive columns. Full triangle checks give **147/1,035**
  reference-surface-positive columns across 1–180 cm.
- All 129 isolated specks were checked: **3** have 1–2.5 cm reference contacts.
- Fixed phone-only random sample of 256 statistical-clear columns: **12**
  reference-surface contacts. Do not extrapolate this as a whole-map safety rate.
- Five fixed height probes miss in 7 object columns and 1 sampled-clear column.
  All five hits would still not prove continuous/measured support.

Positive near-floor geometry can be floor registration or surface-height variation,
not a physical obstacle. The reference was cleaned/completed and captured at a
separate time. No measured-support mask exists. A negative vertex or triangle
query is not verified free space. This audit covers 10–1800 mm; 2–10 mm is
untested. No phone obstacle is deleted and no confidence/tracking is fabricated.
Closed triangle boxes may share boundary contacts; overall counts use unions.

## Reproduction and dependencies

Exact latest supplied labels: commit c1231d4042068176e09a33c3020647c2c0e292ba,
`research/mapping-audit-opus-20261026/derived/pipeline-outputs/koivu_v1_pipeline_out.npz`,
SHA256 dfd9a7afa958fc8012e43b9fe86f72dafb97e88d4198640080c110c14941b55e.
Original scoring source: commit b9a652bbe0203f11caade0bf136e8df22badbbea.
The exact source cut and input hashes are in FROZEN.json. This packet includes
own source and aggregate receipts, not raw maps, labels, meshes, images, per-column
geometry, trajectories or binaries. AGGREGATE_RESULTS.json omits only the original
summary's machine metadata and dataset transform; its original hash is retained.

The executed scripts use the pinned local sibling workspace layout, not a portable
installer. Required separately pinned support: `blind-koivu-reference-comparison-06/reference_geometry.py`
and unchanged `blind-koivu-game-07/reference_container.py`, as named/hashed in
FROZEN.json; original scoring fixture reads the exact pinned upstream pipeline.py.
Those dependencies and recorded inputs are not bundled or implicitly installed.
Installed NumPy/SciPy/Pillow/VTK 9.3.1 were used; no new library was installed here.

MuSHRoom dataset: Xuqian Ren et al., CC BY 4.0, official project
https://github.com/TUTvision/MuSHRoom ; iPhone record https://zenodo.org/records/10230733 ;
reference record https://zenodo.org/records/10222321 . Data and library licenses
are distinct. FARO was evaluator-only; no route selection or map correction used it.

Original earlier maps, selector failures and D1 source remain unchanged. The
source-review document records its earlier budget cut; the protocol/runner and
frozen manifest record the explicitly approved final pre-run 1800/2700-second cap.
