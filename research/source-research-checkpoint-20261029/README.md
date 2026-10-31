# Mapping and stair-data research checkpoint

**Evidence cutoff: 2026-10-29 04:46 UTC. Source research, not navigation validation.**

## Useful findings

1. Voxfield is a plausible isolated CPU experiment, but its released perspective-camera normal wrapper has source-level defects. Running it unchanged would not be a sound baseline. The normal-aware integrator also changes weighting, so an additional normals-disabled control is necessary before attributing a result to normals.
2. Real staircase recordings are available. Four ordered Microsoft 7-Scenes Stairs RGB/depth/pose frames have been materialized and inspected. They provide a useful external adapter diagnostic, but lack the iPhone paper's full inputs and warning-event labels.
3. Missing calibration, gravity, timestamp or support evidence must stay explicit. Neither a source library nor a static stair sample establishes safe navigation.

Read [Voxfield source findings](VOXFIELD_SOURCE_REVIEW.md) and [real-stair data availability](REAL_STAIR_DATA.md). The source producer confirmed at the cutoff that the authorized synthetic-only gate was being prepared and **no build had executed yet**. This checkpoint deliberately freezes that state; subsequent build receipts must be reported separately. No recorded-scene Voxfield run, quality improvement, phone performance or physical-safety result is claimed.

## Publication boundary

This checkpoint contains aggregate prose, primary links, source identities, licences and small provenance records only. It contains no dataset images, point clouds, derived geometry, benchmark arrays, route coordinates, charts, credentials or private participant information. Source inspection and sample acquisition are distinguished from execution. Linked dataset licences do not authorize redistribution by this repository. No pending derived-data publication is included.

Latest branch identity supplied by the publishing coordinator: `893550` (abbreviated). This document does not assert that this staged checkpoint has already been pushed. Existing full audits and negative results remain unchanged.
