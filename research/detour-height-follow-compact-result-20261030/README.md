# Detour height following: completed two-route diagnostic

**The offline endpoint-height reset is real and correctable. This is not yet a
safe route or device-navigation result.**

Actual compact attempt 002 ran from source
`0a1a59cd580239a52939f5cdc9642cc608ece425`. Compilation, native height tracing and
VTK auditing exited 0 with retired process groups. Independent saved-result review
verified **all 3,696 native events and 29,568 collision records**, 10,228,056 triangle
candidates, 125,778 contact occurrences and 971 distinct contacted faces.
Runtime:89.361 wall /89.319 CPU seconds; sampled peak aggregate RSS 193,658,880 B.
All 101 input pins stayed unchanged. No native engine was rerun for this audit.

The serialization repair is lossless: all 29,069 previously saved records match
attempt 001 exactly after decoding, including IDs and canonical JSON bytes. The
complete native-height event file is byte-identical to attempt 001. Its recording
failure remains a failure, not a retroactive pass. Final encoded evidence was
45,319,246 bytes, within the original 64 MiB cap; no process limit was increased.

## What improved—and what did not

Counts below are **authored query events containing any raw triangle contact**,
not independent journeys or physical collision probabilities. Every swept turn,
translation and endpoint was checked; no ground triangles were exempted.

| Route/profile | Untrimmed: original → native Y | Lower 2 mm trim: original → native Y |
|---|---:|---:|
| Conference 120→200, nominal |22 →20 / 2,052|2 →0 / 2,052|
| Conference 120→200, 15 cm margin |720 →718 / 2,052|652 →652 / 2,052|
| Coffee 0→8, nominal |4 →0 / 1,644|0 →0 / 1,644|
| Coffee 0→8, 15 cm margin |432 →430 / 1,644|426 →426 / 1,644|

At the **Conference terminal pose**, the original downward anchor-Y connector
produced 15 nominal and 25 margin triangle contacts. Released native detail Y
removes those contacts in both bands while retaining the original goal identity
and XZ. At the **Coffee terminal pose**, nominal untrimmed contacts fall 26→0;
margin contacts fall 119→51 untrimmed and 60→51 trimmed. Those 51 remaining faces
are not cleared by correcting the foot datum.

The margin problem is not just endpoints or turns: native-Y untrimmed contact
occurs in 98/269 Conference translation events and 63/377 Coffee translation
events. Conference nominal untrimmed contacts remain in 4 translations and 16
turns. All exact changed ID sets are in `CONTACT_CHANGES.json`.

## Why this cannot be presented as newly safe clearance

**Every lost contact triangle lies entirely below both native event foot heights.**
This establishes that changing the query's lower boundary explains the lost
contacts; it does NOT establish that those triangles were harmless noise.
Maximum lost-triangle tops relative to original foot: Conference 12.75 mm nominal /
17.02 mm margin; Coffee 0.37mm nominal / 9.50 mm margin. No higher triangle disappeared
from the paired ID sets. The 10 cm and 50 cm descriptive bands in the audits are not
safety thresholds; changing a foot-relative classification is not removal of a
physical object.

The proposed foot can rise by **25.95 mm in Conference and 19.06 mm in Coffee**;
it can also fall locally by 1.97 mm / 0.58 mm. Such a raised virtual body omits a real
vertical band near the floor. Native detail height is an approximate navmesh
surface—not measured wearer foot position, continuous observed support or proof
that a toy is absent. The original mesh and all triangles are still present.

## Path identity and native behavior

- All original desired XZ samples, goal identities and authored headings remain
  unchanged. Maximum native-returned XZ discrepancy was 0.164 µm, below the frozen
  numerical 1 µm comparison budget; this is not physical localization accuracy.
- Official `moveAlongSurface` + `getPolyHeight` maintained local polygon state
  for all events, with explicit successful statuses and no reseed/replan.
- Original requested XYZ remains in the historical arm and association records.
  The native arm does not force the body back down to the requested map-anchor Y.
  Reaching that map association is **not original exact-XYZ physical arrival**.
- Starts were authored offline, not measured human body poses. No movement was
  applied. Other Conference requests and the live app were not tested/changed.

## Practical consequence

Keep **map-destination association separate from collision-query/body-foot Y**
in the offline path pipeline; use the released height query consistently rather
than appending an artificial vertical goal connector. This fixes a specific
representation defect without introducing a hand-fitted floor plane.

Do not activate native Y as physical foot authority or discard remaining low
contacts. Continuous support/low hazards need their own evidence. The preserved
margin contacts—especially higher furniture—still require clearance planning
and independent full-body checking. This result narrows the fault; it does not
close the iPhone, stair, child-safety or end-to-end journey gates.

## Reproduction and evidence

`RESULTS.json` contains all 8 before/after groups, exact raw hashes, immutable
inputs, native/prefix equality checks and runtime. `CONTACT_CHANGES.json` contains
all 37 changed pairs with complete old/new/lost/added IDs, endpoint uncovered
bands, and source whole-triangle geometry references for those IDs.
`ENDPOINTS.json` and `NATIVE_ASSOCIATIONS.json` retain both goal associations.
The 971-face full catalog and 29,568 raw records are retained in the actual work
output, identified by hashes, not reuploaded as a redundant archive.

Run `python -S summarize.py <fresh-output-directory>` from this packet to
reproduce the four main JSON files using saved local outputs. It imports only
stdlib result-validation/codec code, never native geometry libraries.
`independent_contact_audit.py` and `INDEPENDENT_CONTACT_AUDIT.json` provide a
separate complete paired-contact audit. Whole-triangle heights are not exact
contact-point heights. None of these diagnostics establish safe movement.
