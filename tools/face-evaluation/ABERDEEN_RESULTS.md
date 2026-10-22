# Frozen Aberdeen evaluation snapshot

This directory now contains the actual metadata for the completed research run, not only a recipe for choosing a future split. No photographs, model weights, embeddings or per-image similarity scores are included.

- `aberdeen.frozen-protocol.json` is a byte-identical copy of the manifest written before inference. SHA256: `5ec165aa47a3ad93c2f6dc268608af01e848b1be2ddf172d9f5125c3b85fd096`. It includes exact filename labels/splits, every source image SHA256, archive/model hashes, exclusions, anchor, grid and tie rule.
- `aberdeen.aggregate-results.csv` records all 42 calibration-grid rows plus the 8 calibration/held-out anchor/selected summaries. Repeated anchor/selected rows are intentional; they are not extra observations.
- `aberdeen.result-snapshot.json` records aggregate-file integrity, original execution-report hashes, delivered source-file hashes, detection/enrollment totals and timing. Source hashes identify the packaging snapshot, not a signed pre-execution code attestation.
- `aberdeen.provenance.json` preserves official source, archive size/hash, attribution and bounded research-use terms. Public filename labels are included only as necessary research metadata. Images are not licensed for redistribution by this package.

## Actual split and result

61 eligible canonical filename identities / 609 photographs, with ambiguous/singleton/angle-suffix items excluded before scoring. Alphabetically alternating identities form 31 calibration and 30 held-out identities. Each phase has a 10-person gallery; the lowest-number image enrolls and is not a probe. Calibration: 78 known and 236 unknown probes from 21 unknown identities. Held-out: 82 known and 193 unknown probes from 20 unknown identities. All selected images had one detected face and both galleries enrolled all 10 intended identities; no failures were replaced.

The fixed numeric anchor is cosine 0.363 / margin 0.1. Calibration minimizes false unknown names plus wrong-known names, then maximizes known correct, then selects higher threshold/margin. It selected SFace 0.7 / 0.2 and AuraFace 0.5 / 0.2 before held-out scoring.

Held-out rows:

| Model / policy | Known correct | Wrong known | Known abstain | False unknown names |
|---|---:|---:|---:|---:|
| SFace anchor | 82/82 | 0/82 | 0/82 | 7/193 |
| SFace calibration-selected | 76/82 | 0/82 | 6/82 | 0/193 |
| AuraFace anchor | 82/82 | 0/82 | 0/82 | 0/193 |
| AuraFace calibration-selected | 82/82 | 0/82 | 0/82 | 0/193 |

Only 20 unknown identities were held out. Zero observed errors do not establish a below-1% population error rate: even nominal independent-query Wilson upper bound for 0/193 is 1.95%; photographs are correlated. Filename disjointness is not proof of biological identity independence or nonoverlap with model training. This selected subset is not a representative demographic/pose benchmark. Do not combine calibration and held-out counts, or pool them with ORL/stress observations.

## Reproduce the recorded split

Acquire approved assets manually using the provenance files. Keep them outside the repository. Use the delivered frozen manifest directly; do not regenerate or edit it for the reported run:

```sh
PYTHONDONTWRITEBYTECODE=1 /path/to/python tools/face-evaluation/fresh_benchmark.py \
  --assets /path/to/ASSETS \
  --protocol tools/face-evaluation/aberdeen.frozen-protocol.json \
  --output /path/outside/repo/aberdeen-results.json
```

The script verifies the archive/image/model hashes and split before inference. Its calibration file is persisted before held-out scoring. Reproduction is not a new untouched test set. This snapshot was packaged by extracting aggregates and validating hashes/denominators only; no additional model run occurred.

The app's 3–6-example normalized-mean enrollment, Apple Vision veto, camera orientation, quality/clipping gates and temporal/voice behavior are not recognition-accuracy validated by this single-template Python benchmark. Optional native AuraFace source exists, but Apple build/device evidence remains separate.
