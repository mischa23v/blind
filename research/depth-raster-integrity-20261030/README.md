# Raw depth raster accounting repair

This isolated repair tightens raw observation validation. It does not implement temporal floor support, localization, calibration, or physical guidance.

## Reproduced source defects

The previous `NativeDepthObservation.validate` added the unbounded decoded `invalidPixelCount` to the pixel-array count before checking the sample budget. `Int.max` invalid samples plus one pixel therefore reaches overflowing Swift integer arithmetic instead of a throwing rejection. It also accepted a 1 × 1 raster claiming two invalid sampled sites.

The repair first bounds sampled count to 0...4096, then bounds invalid count to 0...sampled count, compares using subtraction, and checks the maximum stride-lattice capacity using ceiling division. Width/height/stride are validated before arithmetic. Sparse subsets and missing/low confidence remain permitted history; no missing cell becomes observed or clear. Existing native adapter uses an 1,024-site budget and is unchanged.

Four XCTest methods cover overflow, impossible raster counts, ceiling-stride capacity/sparse subsets, and negative/oversized counts. `source_check.py` executes pinned source-order and independent arithmetic controls only. There is no Swift toolchain here; XCTest and Apple build remain **unrun**. Required native command: `swift test --package-path BlindCore --filter NativeObservationTests`.

## Remaining true floor-support integration requirements

The existing source audit and independent review remain authoritative for this distinction. Production calibration is `unconfigured`; no concrete validated `NativeLocalizationMeasurements` producer exists. Needed real inputs are measured camera-to-body reference/revision, measured depth/pose/time/mount error envelopes for the hardware/domain, actual original-frame depth/confidence/pose/intrinsics and recovery epochs, support-query body geometry, independently validated observed-versus-unknown coverage and contradiction handling, and validated temporal persistence/expiry policy. Original acquisition time must remain separate from current evaluation time. No numerical uncertainty/expiry values are guessed here.

Current map floor labels, retained height, tracking-normal and ordinal confidence do not supply those missing measurements. Production issuer and physical-output gates remain withheld. This repair fixes a recoverable input-integrity defect; it does not close the hardware/domain measurement or upstream-backed temporal-producer gap.
