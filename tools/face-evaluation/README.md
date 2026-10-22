# Isolated face evaluation research

This isolated, dependency-free Node harness exercises evaluation accounting and a toy decision rule. It is NOT a face recognizer, production matching policy, presentation-attack detector (PAD), or guardian verification system. It is not imported by the app. The JavaScript CLI never loads images, weights or external datasets and has no network code. The separate image_smoke.py runner uses explicitly acquired local assets only; it does not download anything.

Run from repository root:

    node --test --test-reporter=tap --test-concurrency=1 tools/face-evaluation/evaluate.test.mjs
    node tools/face-evaluation/evaluate.mjs

Requires the repository's Node 22+ runtime. No installation. The CLI accepts no arguments. Results contain only invented identities and vectors. Execution logs are stored outside the repository. Synthetic results describe the demonstration, not real accuracy.

## What is tested

Vector validity/normalization, absolute threshold, per-person template aggregation, runner-up margin, ties, low quality, freshness, ambiguous association, empty/deleted gallery, consent, model version, duplicate identifiers and metric denominators. Invalid gallery inputs fail closed. Abstentions return no candidate name. Invalid policy parameters throw. Thresholds and quality are arbitrary synthetic inputs, not calibrated or measured face properties.

The example deliberately contains an unknown person's vector identical to an enrolled vector. It is falsely accepted. The report counts that failure (1 of 2 synthetic unknown probes), rather than claiming the gate prevents strangers from being matched. This 50% figure is a demonstration fixture result, not an estimate of any face model's error rate. Unknown false identification, wrong known identity, known abstention and correct known identification have separate denominators; an absent denominator is null, not zero.

## Real-model protocol (tiny smoke run completed, larger evaluation pending)

1. Record exact source revision, model file, hash, model license/provenance, dataset protocol and permissions before acquisition. Do not auto-download model constructors or run setup scripts during review.
2. Begin with the upstream OpenCV YuNet + float SFace baseline and its published LFW evaluator, rather than rewriting detection/recognition. Pin YuNet version and OpenCV runtime together: upstream now distinguishes the 2023mar fixed-shape model from 2026may dynamic export. Review both model licenses separately.
3. Reproduce upstream preprocessing and verification results. LFW pairs establish only that benchmark reproduction, not open-set family identification or anti-spoofing.
4. Separately freeze gallery construction, template counts, model hash, runtime precision, preprocessing, quality rules and candidate thresholds using a development split. Evaluate only once on held-out identities/sessions for the reported test result. Never choose thresholds using test labels.
5. Test gallery sizes 1 through the product maximum, many genuinely unknown people, similar-looking relatives, multiple faces/crossings, blur, lighting, masks, camera distance and view angle. Count unknown false identification per probe/encounter as well as pairwise FMR. Do not count correlated frames as independent people or trials. Report counts and uncertainty, including failures and abstention by conditions.
6. PAD is a distinct evaluation: print, screen/video replay and other threat-model attacks. Similarity, quality gates and repeated matching frames alone do not establish liveness. Physical guardian binding is a further separate product/security requirement; neither a face match nor a live face proves guardianship or authorization.
7. Reproduce numerical output on iOS and measure device load/latency/heat offline. No child-facing identity speech until a separately approved assurance decision. Synthetic checks do not satisfy any real-model or device gate.

## Primary-source research leads

- OpenCV evaluator: https://github.com/opencv/opencv_zoo/blob/main/tools/eval/README.md
- SFace model and directory license: https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface
- YuNet model and directory license: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet
- AdaFace comparator (MIT code; exact checkpoint/data rights still need review): https://github.com/mk-minchul/AdaFace
- NIST version-specific 1:1 evaluation, not certification of this integration: https://pages.nist.gov/frvt/html/frvt11.html

No upstream recognition implementation was copied here. The small custom functions are test accounting and a deliberately simplified decision fixture, not a proposed substitute for established recognizers.

## Real image smoke runner

After explicit model/image acquisition authorization, a six-public-portrait smoke run was completed using Python 3.12.14, OpenCV 4.14.0 and NumPy 2.3.5 in an isolated environment. The runner checks model and image hashes, keeps enrollment/test captures distinct, rejects missing/multiple detected faces, and reports pairwise counts separately from gallery decisions. No photos/weights/logs belong in this source directory.

    /path/to/isolated/python tools/face-evaluation/image_smoke.py --assets /path/to/approved-assets --output /path/outside/repository/report.json

Asset root requires models/ containing the two exact SHA-256-checked model files in image_smoke.py and images.json containing the approved source/hash/split manifest. Do not substitute personal images or assets without rights/consent review.

Actual smoke result: two correct known matches from two separate-photo known probes, and two abstentions from two unknown probes. All six portraits had one detection. Pairwise: two mated comparisons above the upstream demo cosine threshold 0.363; six nonmated comparisons below it. Margin 0.1 is a separate uncalibrated experimental choice, frozen before observing scores. This run does not establish an error rate, rare-error assurance, training independence, PAD, iOS behavior or child safety. Public figures may have appeared in model training. There was no identity-disjoint calibration set; no thresholds were fitted. Exact sources/hashes and restrictive source-metadata notes are retained with the external asset manifest/report.

## Reproduce the approved six-portrait smoke experiment

`portraits.manifest.json` is metadata only: exact source URLs, identity/split IDs, credits, rights labels, file lengths and SHA-256 values. It contains no photographs or embeddings. Review source terms and the caveat below before acquiring assets. Download the listed originals manually into an asset root outside the repository at the manifest's relative paths. Put the two reviewed official model files into that root's models/ directory, then copy this manifest to that root as images.json. The runner itself never downloads assets.

    cp tools/face-evaluation/portraits.manifest.json /path/to/approved-assets/images.json
    /path/to/isolated/python tools/face-evaluation/image_smoke.py --assets /path/to/approved-assets --output /path/outside/repository/report.json

Original smoke runtime used opencv-python-headless==4.14.0.94 and numpy==2.3.5 on Python 3.12.14. Model official URLs:

- https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx
- https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx

Rights caveat: Obama 2009 is Pete Souza, CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Other manifest source pages label images as US government public-domain works. Some White House image metadata also retains restrictive personal/editorial-use/no-manipulation boilerplate. This research records that inconsistency rather than overriding it. Do not redistribute the portraits with this source handoff, imply endorsement, or treat this review as production rights clearance. In the bounded private smoke run, source files remained unchanged; inference temporarily resized/aligned them. Model-directory licenses are MIT for YuNet and Apache-2.0 for SFace, separately from image rights and any unresolved model training provenance.

## AT&T/ORL labeled benchmark and post-hoc diagnosis

The separate `benchmark.py` evaluates the original provider's 400-image/40-person labeled research dataset. Protocol was fixed before inference: s1..s20 image1 form a 20-person gallery, their remaining180 photos are known probes, and all200 photos of s21..s40 are unknown probes. This is our explicit open-set split, not a standardized official ORL protocol. Frozen cosine0.363/margin0.1, no fitting, no replacement enrollment images or invented detector boxes.

Observed:178/180 known correct,2 abstentions,0 wrong names. Unknown7/200 falsely identified,193 abstentions. All7 false names are one unknown subject repeatedly assigned one enrolled identity. Detection389/400 unique,11 misses retained in end-to-end denominators. These errors preclude guardian-safety assurances. All400 images are now consumed evaluation/error-analysis data; do not present a retuned result on them as untouched validation.

The provider offers research use with credit to AT&T Laboratories Cambridge, not an unrestricted production license. Exact source and archive SHA-256 are in metadata-only `orl.provenance.json`. Acquire the original archive manually after reviewing terms, extract into ASSET_ROOT/orl retaining the archive, and copy the provenance file there as provenance.json. No data download is implemented here. Models remain in ASSET_ROOT/models. All model/archive/extracted-file hashes are checked; no embeddings are exported.

    PYTHONDONTWRITEBYTECODE=1 /path/to/isolated/python tools/face-evaluation/benchmark.py --assets ASSET_ROOT --output REPORT.json
    PYTHONDONTWRITEBYTECODE=1 /path/to/isolated/python -m unittest discover -s tools/face-evaluation -p test_benchmark.py -v
    PYTHONDONTWRITEBYTECODE=1 /path/to/isolated/python tools/face-evaluation/diagnose_orl.py --assets ASSET_ROOT --output DIAGNOSTICS.json

Eight Python accounting tests pass, in addition to the16 JavaScript synthetic checks. Two full benchmark runs reproduce all scores/decisions/counts. Pairwise verification has its own denominators:101 false matches among73,743 scorable nonmated pairs,4,257 unscorable nonmated pairs;0 false nonmatches among1,723 scorable mated pairs,77 unscorable mated pairs. Pairwise and gallery false-identity fractions are different measures. All pair/image Wilson intervals are nominal/descriptive: shared identities make trials correlated. Subject-level any-error interval is also reported, but20 people do not establish population assurance.

Post-hoc `diagnose_orl.py` confirms identical grayscale input channels, upstream112x112 alignment, and normalized-dot versus official FaceRecognizerSF.match agreement within6.03e-8 on200 comparisons. All seven false-accept boxes and their matched enrollment box are in bounds; a clipped-box rejection alone does not resolve them. Detector confidence is not identity confidence. No thresholds are modified by the diagnostic script.

The baseline is not exact iOS policy parity: native orientation/RGBA handling, extra clipped-box/quality gates, device computation and temporal logic remain separately testable. ORL is historical, tiny, grayscale and pre-cropped; demographics and model-training overlap are unverified. PAD/security assurance is separate from the supervised assistive-hint use case. No guardian authorization or trust/follow claim is made.

## Exploratory alternate face model

`alternate_model.py` uses official fal AuraFace-v1 recognition ONNX with existing OpenCV DNN. It retains the baseline YuNet detections and aligned112 crops, then applies ArcFace RGB normalization and512-D L2 normalization. `auraface.provenance.json` contains exact revision, URL, bytes, hash and license provenance. Acquisition is manual, no network access occurs in evaluation. Place the approved model at `ASSETS/auraface/glintr100.onnx`; no model, image, embedding or runtime is included in source.

```sh
PYTHONDONTWRITEBYTECODE=1 /path/to/python -m unittest discover -s tools/face-evaluation -p test_alternate_model.py
PYTHONDONTWRITEBYTECODE=1 /path/to/python tools/face-evaluation/alternate_model.py --assets /path/to/ASSETS --baseline-report /path/to/face-orl-benchmark.json --output /path/outside/repo/face-auraface-exploration.json
```

The21-row grid was declared before AuraFace inference; it is exploratory on already consumed ORL, not fresh validation. At numerical anchor cosine0.363/margin0.1 (NOT transferred calibration), AuraFace gives178/180 known correct,2 abstentions,0/200 unknown false names. Original SFace gave7/200 unknown false names. The same-identity joint rule is measured directly, never assumed to have independent errors. These results do not establish a population false-name rate below1%, or Apple/iOS performance. Full report includes every grid row and the known-coverage penalty at higher thresholds. No app defaults changed.

The official card declares Apache-2.0 for AuraFace, but undisclosed training corpus provenance/demographic coverage remains a limitation; no shipping-rights warranty is given. AdaFace/CVLFace weights were not downloaded because their cards defer to training-data terms whose applicable access/license conditions could not be verified. Model code licenses do not automatically clear weights.

## Fresh Aberdeen calibration/held-out protocol

`fresh_benchmark.py` uses the official Stirling PICS Aberdeen archive only for bounded research. See `aberdeen.provenance.json` for the provider's research-use invitation, attribution, exact archive URL/size/hash. Do not redistribute images. Obtain the archive separately after reviewing the terms and place it at `ASSETS/aberdeen/Aberdeen.zip`.

Before model inference, `--prepare-only` records the complete immutable selection/split, image hashes, model hashes, threshold grid and calibration-selection tie rule. Canonical filename stems with at least four numbered images are eligible, excluding clean_ aliases. Irregular suffixes, angle-name variants and singletons are excluded before inference. This reduces the collection to61 presumed filename identities/609 images; it is not a biological identity-ground-truth audit. Alphabetically alternating identities form31 calibration identities and30 held-out identities, each with its first10 as enrolled gallery subjects. Lowest-number photograph enrolls; all other gallery photographs are known probes. Remaining identities are unknown. There are78 known/236 unknown calibration probes,82 known/193 unknown held-out probes. Failed enrollment is never replaced and missed detections stay in probe denominators. Gallery size10 differs from ORL's20.

The existing0.363/0.1 anchor is preserved. A separate21-row calibration-only grid minimizes false unknown names plus wrong-known names, then maximizes correct known names, then favors higher cosine threshold and margin. Selected policies and calibration results are saved before held-out extraction/scoring. Held-out results include the fixed anchor and the calibration-selected policies, not another tuned grid. No test-set policy changes occur. Correlated photographs, uncertain filename aliases, training overlap, pose selection bias and unmeasured iOS/PAD behavior remain limitations.

```sh
PYTHONDONTWRITEBYTECODE=1 /path/to/python -m unittest discover -s tools/face-evaluation -p test_fresh_benchmark.py
PYTHONDONTWRITEBYTECODE=1 /path/to/python tools/face-evaluation/fresh_benchmark.py --assets /path/to/ASSETS --protocol /path/outside/repo/aberdeen-protocol.json --output /path/outside/repo/aberdeen-results.json --prepare-only
# Review and retain protocol before running inference; do not replace it afterward.
PYTHONDONTWRITEBYTECODE=1 /path/to/python tools/face-evaluation/fresh_benchmark.py --assets /path/to/ASSETS --protocol /path/outside/repo/aberdeen-protocol.json --output /path/outside/repo/aberdeen-results.json
```

The exact completed split and all aggregate result rows are now included in `ABERDEEN_RESULTS.md`, `aberdeen.frozen-protocol.json`, `aberdeen.aggregate-results.csv` and `aberdeen.result-snapshot.json`. Use that frozen manifest to reproduce the reported run, rather than generating a different one. These files contain research metadata only, not photos, weights, embeddings or per-image scores.
