# Independent read-only source review

The separate reviewer inspected the exact upstream source/receipts and the new
label/triangle audit code without loading the recorded reference or executing
its data pass. The unchanged game scorer was also inspected.

Confirmed source issues: the headline low-band count excludes body matches;
the statistical 1 cm threshold does not match the 2.5 cm scoring threshold;
any-vertex coverage does not establish floor/full-band coverage; latest strict
mask omits the far-only-dip veto; and the 87-miss distance claim refers to an
earlier pass. Old D1 arrays cannot substitute for the exact latest pipeline.

Before freezing, the reviewer required the original vertex scorer's floating
point +2.5 cm then −2.5 cm round-trip to be preserved. That repair was applied
before any recorded scoring. The saved level transform to +Y-up helper frame,
reflected horizontal box bounds, phone-only 1,413-column selection, exact saved
vertex-array gate, six height bands, closed-box boundary semantics, Float32
reader rounding disclosure and resource watchdog were then re-reviewed.

No remaining concrete source blocker was identified at source-close:

- score_reference.py: ccb8b730cde932e191571cebd1c0b09ffbce8429e67de21455268eff5c6d53d7
- label_contract.py: e9107b10238fff7ead7f8d60733b0439771d592a9a6f1bece2ddf547c44c4db3
- run_bounded.py: aed02a2d205067fbfc113863ac6aa13b19ea6cc00388c2a779b1bb8169594f42

Release remains conditional on the label/transform fixtures, complete frozen
source/input identities and exclusive compute slot. Source review is not a
recorded score, navigation result or physical safety certification.
