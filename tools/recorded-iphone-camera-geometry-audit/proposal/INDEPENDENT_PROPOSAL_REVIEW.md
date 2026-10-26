# Independent proposal review — before implementation or execution

2026-10-26. Read-only inspection of the proposal documents and existing stage-02 receipt; no implementation, build, frame/point processing or geometry run by this reviewer. Only this review and the separate convention-source note are authored here.

## Reviewed revisions

- `PROTOCOL.md`: `43df3e0bd004936ee356bc38072489b2f5d8ed96fb90edf124daf169c8b0e8a5`.
- `IMPLEMENTATION_PROPOSAL.md`: `6605ae81c5a8d321345ecf35a0ae8eea3fd344e6f8943387e659497465751e91`.
- `INDEPENDENT_LABEL_REQUIREMENTS.md`: `c963494838c4ece19a714e80d5d0c755dddfe86ee46ef474d259b34a8f32b223`.
- `CONVENTION_SOURCE_REVIEW.md`: `dad1986e140db2efe7abfe4d03947d2350f44864a590da5845a8adeeb03b9c12`.

## Outcome

The camera-only authority boundary, original-confidence preservation, no frame fusion, independent-label limitations, refusal to treat a round trip as measured accuracy, fixed eight-frame denominator and source-only publication boundary are appropriate. The existing stage-02 receipt corroborates the stated 98,304 attempted stride pixels and 31,648 admissions. These remain prior results, not geometry outcomes.

**Conditional on the following protocol additions before execution:**

1. Explicit diagnostic guards for finite positive dimensions/focal lengths, finite principal-point coefficients and scaled intrinsics, finite integer in-bounds coordinates, and finite returned XYZ. The shared core does not implement every such guard. Any unexpected projection failure must fail the diagnostic rather than silently reduce its denominator. The author has already committed to these guards without changing the frozen core.
2. An independent analytic asymmetric golden fixture and an unequal-x/y resolution-scaling fixture, not just inverse consistency and direction signs. For example, `fx=100, fy=80, cx=50, cy=40, d=2, u=60, v=56` must return `(0.2,-0.4,-2)`. A mutually consistent wrong calibration can otherwise round-trip successfully. Source-derived fixture agreement is still not physical accuracy evidence.

## Small clarifications

- The pinned official Record3D example is a **streaming library/example**, not an attested raw exporter or identified version of the recording app.
- Require all four coefficients finite, with positive `fx/fy`; principal-point coordinates need not generally be positive. The present recording need not be altered for that generic contract.
- Fix the analytical depth display range before execution, show invalid and clipped values distinctly, and retain the full original numeric counts. Display choices must not change admission or geometry.
- Enforce 24 MiB as an aggregate derived-output cap, not a per-file allowance, and include child processes in runtime/resource accounting. Implementation review must verify enforcement rather than infer it from the prose.

No obstacle-miss, physical-clearance or navigation overclaim was found in the reviewed wording. This review is not blanket approval of a yet-unwritten runner. The promised new harness input/output and bounded driver still require source review before execution, as the implementation checklist states.

## Final protocol re-review — 2026-10-26 03:12 UTC

The author added the input/output guards, five explicit golden probes including asymmetric intrinsics and unequal x/y scaling, expected scaled-intrinsic assertions, finite-all/positive-focal-only wording, streaming-example qualification, and a fixed display-only range with visible/countable clipping. I checked the probe arithmetic by inspection; no probe was executed. Both pre-execution protocol requirements above are resolved.

**Protocol is ready for the authorized implementation step.** This is not permission to bypass the promised harness/driver source review before running it, and is not a geometry-result or physical-accuracy finding. Resource enforcement remains an implementation-review item. A remaining shorthand “native/exporter convention” in the FoV paragraph refers to the already qualified streaming example and does not change the numerical contract.

Final inspected hashes:

- `PROTOCOL.md`: **`c464922f1fa4799d83f9eef5da6fb0158a62df134777ff7218181aa6f196cfaf`**.
- `IMPLEMENTATION_PROPOSAL.md`: **`10a56d9674c01c0c657c435b54d4beb8a982e628d59417a2cdf93b517f8902c5`**.
- `INDEPENDENT_LABEL_REQUIREMENTS.md`: `c963494838c4ece19a714e80d5d0c755dddfe86ee46ef474d259b34a8f32b223` (unchanged).
- `CONVENTION_SOURCE_REVIEW.md`: `dad1986e140db2efe7abfe4d03947d2350f44864a590da5845a8adeeb03b9c12` (unchanged).
