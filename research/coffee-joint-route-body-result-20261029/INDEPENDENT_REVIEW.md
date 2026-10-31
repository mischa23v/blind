# Independent saved-data review — Coffee joint route, 2026-10-29

**No scoped evidence/reporting blocker found.** Review used existing saved files
and standard-library arithmetic only. No native import, collision/planner query,
controls/build rerun, source change, archive creation or push was performed by
the independent reviewer.

## Independently verified

- Exact source `3d6b7a6fdb4ae80f8fe99060a17f93573c0477d8` and run manifest
  `9ee9ad130a163b2ab38a1c4abb5ee4ea7fac2fd834538a709d5fe385259cc835`.
- All 75 current input SHA256 hashes equal both saved before/after dictionaries
  and the manifest. All six commands have saved zero exit/retired-group results;
  6 source and 67 native controls passed. All 16 terminal payload files match
  saved size/hash, totaling 291,594 bytes excluding the guard receipt.
- All 3,301 setup/contact rows; 6,618 box, 2,547,270 candidate-triangle and 189
  support-ray queries; A/B per-event raw-count equality for both modes.
- A/B each examine 1,644 events and report zero nominal-body overlaps. Each has
  17,102 raw margin occurrences over 426 events; B labels 18 component-ground
  and 17,084 other. Event-kind counts are 362 turns, 63 translations, one terminal.
- C examines 11 events/21 sweeps, with zero nominal-body overlaps. Its 41 raw
  margin occurrences divide into 38 ground and 3 other. Eight events have raw
  margin overlaps; only event 10 has other overlaps, with 1 and 2 in its halves.
- Saved-state progress reconstructs exactly: only event 1, segment 0's tiny
  connector translates; 3D distance 8.7271663854747e-8 m and XZ distance
  8.727166233481274e-8 m. Eight turns are accepted; event 10 is rejected without
  advancing accepted state. No meaningful route travel or arrival is established.
- A/B's first other-margin witness is face 45802 at event 14, whole-triangle
  range 1.468073–1.653405 m above the authored foot. C's first is face 27557 at
  event 10, 2.735887–14.674887 mm above its adjusted foot. Face 27557 is absent
  from the 4,827 saved ground IDs; independent float64 source-vertex arithmetic
  gives approximately 16.894798° signed-normal slope. This is not semantic floor
  identification, a contact-point height or a float32 native-classifier rerun.
- The saved 2D manual diagnostic contains all 286 checks, zero contacts and
  minimum residual 0.12958363049834276 m. Its two-window radial-circle scope
  differs from full-mesh XYZ/turn/body-margin enclosures and C's adjusted Y.

## Reporting/privacy scope

README/JSON distinguish successful diagnostic execution from rejected route
progress, conservative margin overlap from physical collision, and ground
component labels from semantic floor. Zero nominal-body hits do not prove
clearance around missing mesh geometry. Counts are repeated query occurrences,
not unique physical obstacles. Only the first other-face witness is logged per
mode/sweep; C's additional second-half occurrence cannot be assigned an
identity/height from the retained counts. First-witness height is not generalized
to all contacts.

The public files contain no host identifiers/runtime-environment dump or
absolute data paths. The script has only its ordinary interpreter shebang and
workspace-relative file discovery. Raw receipts, binary/array/mesh payloads and
the contact archive are not included or authorized for publication by this
review. Full-scale route/scheduler source remains separately preserved.

## Exact reviewed result files

| File | SHA256 |
|---|---|
| `README.md` | `2eb0d8167bd5e0d6a017f6736eb9a52c78778e4dc76e2ff195258964f97d86d6` |
| `PUBLIC_SAFE_RESULT.json` | `21ba7766af4bb05c28ec9763e00f6cbfbf7393589daa34d58567e59dce7a0474` |
| `recount.py` | `6d6d7fe971988e7f24c1d91b576f185fe955d003c442504dd843e5a605ad256d` |
