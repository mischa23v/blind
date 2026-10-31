# Executed static four-frame diagnostic — review package

Executed 2026-10-29 on previously acquired Microsoft 7-Scenes Stairs sequence 01 frames 0–3. No network, installation, model, app integration or detector execution. This is a local noncommercial research experiment under the retained MSR licence, not authorization for production reuse. Raw samples and derived previews are not included. This publication contains only source and aggregate diagnostic evidence.

## Actual result

- All twelve source SHA256 hashes matched the prior manifest; colour dimensions and depth uint16/640×480 checked. Licence hash retained in JSON.
- Zero-depth unknown counts: 26,256 / 24,630 / 25,551 / 25,615; no 65535 sentinel observed. Both codes explicitly excluded. Valid point counts: 280,944 / 282,570 / 281,649 / 281,585. No triangles, hole filling or inferred floor support.
- Depth converted mm→m and backprojected with Microsoft's **default uncalibrated** fx=fy=585,cx=320,cy=240. Point provenance is preserved in parallel pixel/raw-depth arrays during processing. RGB is not used for depth-aligned labels.
- Pixel roundtrip maximum 1.137e-13 pixels. General 4×4 inverse roundtrip maximum 8.882e-16 m. These are algebraic adapter checks, NOT measured calibration, scene dimensions, true pose accuracy or detection quality.
- All four supplied rotation blocks fail the predeclared experimental 1e-5 orthogonality and determinant tolerances. Orthogonality maximum residuals 1.456e-4–1.464e-4; determinants 0.99980655–0.99980761. Homogeneous rows pass. First execution stopped on this check; second records all failures rather than aborting. **No tolerance tuning or pose correction.**
- Supplementary transpose-as-inverse roundtrip errors: 0.40046 / 0.40435 / 0.40801 / 0.40548 mm maximum coordinate error. A true numerical inverse avoids that algebraic approximation; it does not make supplied KinectFusion poses independently accurate.
- The cause of nonorthogonality is not established. Decimal entries have about 7–8 significant figures, so text precision alone is not demonstrated as its explanation. This is not evidence of incorrect coordinate convention, sensor fault or scale error. No rigid-pose eligibility claim until reviewed.

## Resource evidence and previews

Main run: one CPU affinity [0], one numerical-library thread, RLIMIT_AS 268,435,456 bytes, CPU limit 30 seconds, external wall timeout 30 seconds; completed in 23.229 seconds, peak RSS 79,576 KiB. Supplementary pose run used the same limits and exited successfully. NumPy 2.3.5 and existing Pillow only. No dependencies installed.

Four local-only point previews were generated. Each uses every 16th valid point, camera X/Y and X/Z projections, depth colouring and per-frame bounds. Frame 0 was visually inspected: multiple separated surfaces and blank coverage are visible; the projection is too ambiguous to independently identify reliable tread/riser patches or thin-rail fidelity. Blank areas may be absent coverage, projection or subsampling, never clearance. No semantic stair count or annotation was derived. These previews are qualitative adapter inspection, not benchmark outputs.

## Files and review boundary

`static_diagnostic.py`, `STATIC_DIAGNOSTIC.json`, `pose_followup.py`, `POSE_FOLLOWUP.json` and this README constitute the source/aggregate review package. `REVIEW.json` records this independent publication review. `INPUT_MANIFEST.json` records expected input hashes, not raw input files. The original executed scripts are preserved byte-for-byte. Previews and the dataset licence file are not redistributed; the expected licence hash is in the aggregate.

No timestamps, cadence, gravity, floor class, FloorDetector angle or hazard/event labels were invented. Four near-identical recorded views are not four independent approaches. No temporal core invocation, recall, false-warning rate, latency, clearance or 92.5% comparison is supported. Existing 17 native paper-core tests are separate evidence. Stage B cross-frame consistency and any manual geometry annotations remain unexecuted pending review of this diagnostic.

Sources: https://www.microsoft.com/en-us/research/project/rgb-d-dataset-7-scenes/ and the official licence at https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/7-scenes-msr-la-dataset-7-scenes.rtf . This run uses retained files; no new source request was made.

## Reproduction from this repository

**A repository checkout alone is insufficient.** The Microsoft dataset is not bundled. Obtain the official Stairs sequence-01 data under its noncommercial licence, select original frames 000000–000003, and provide the matching colour/depth/pose files locally. Rename them to the exact `7scenes-frame-000000.color.png`, `.depth.png`, `.pose.txt` pattern in `INPUT_MANIFEST.json`. Also retain the official licence as `7scenes-license.rtf`. Hashes must match the published receipt before claiming exact reproduction; another sequence/export is a different experiment.

The original scripts intentionally expect inputs in their parent directory. The following explicit staging layout makes that contract usable without assuming any unpublished repository-relative directory. It requires an existing Linux Python environment with NumPy/Pillow, CPU affinity/resource support and `timeout`; no installation is performed by these commands. Set the first two paths to your actual checkout and lawfully acquired inputs. Use a new empty WORK directory.

```bash
AUDIT=/path/to/blind/research/real-stair-input-diagnostic-20261029
INPUTS=/path/to/your/matching-stairs-inputs
WORK=/path/to/new-local-diagnostic-work
mkdir -p "$WORK/diagnostic"
cp "$AUDIT/static_diagnostic.py" "$AUDIT/pose_followup.py" "$WORK/diagnostic/"
cp "$AUDIT/INPUT_MANIFEST.json" "$WORK/MANIFEST.json"
cp "$INPUTS"/7scenes-frame-00000[0-3].color.png "$WORK/"
cp "$INPUTS"/7scenes-frame-00000[0-3].depth.png "$WORK/"
cp "$INPUTS"/7scenes-frame-00000[0-3].pose.txt "$WORK/"
cp "$INPUTS/7scenes-license.rtf" "$WORK/"
cd "$WORK/diagnostic"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
timeout --signal=TERM --kill-after=1s 30s python3 static_diagnostic.py
# Only after reviewing the first result and input hashes:
timeout --signal=TERM --kill-after=1s 30s python3 pose_followup.py
```

The source checks all twelve image/pose hashes. Check the licence hash separately against `INPUT_MANIFEST.json`; the script records it but does not assert its expected value. The supplementary script relies on the first-stage validated local inputs and does not independently hash them. Do not change inputs between stages. The scripts write outputs/previews only into WORK, not this repository. Resource timing and preview hashes may depend on library/platform versions; geometry arithmetic and retained tolerance failures are the scientific checks. An exit code of zero means the report was produced, **not that all checks passed**. All four supplied rotations failed both frozen rigidity tolerances in the retained result.
