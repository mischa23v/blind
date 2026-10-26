## Current checkpoint — Apple bridge passed; five short synthetic pilots completed

**73:five of five predeclared first-leg synthetic episodes reached the original goal region.** Nominal2.775841m/172ticks;3-tick command delay2.839975m/197ticks;2±2-tick pose timing delay/jitter2.800000m/370ticks;1.15× translation2.783000m/154ticks;capture withholding60–89 returned2.775841m/202ticks. These are short development trials on the SAME route, not five laps, five rooms or a100episode validation suite. **Jitter caused193 stop ticks/191 coalesced packets: arrival was not smooth guidance.** Zero actual contacts alone is insufficient with a reference veto; no predicted collision/support veto occurred here. Future no-path/invalid starts remain counted.

[Protocol and pilot evidence](research/tools/synthetic-first-leg-pilot-v1/README.md).72's corrected20 distinct ordered anchor-pair×5condition matrix is planned, not executed. Independent73 review checks actual trace/queues rather than treating a successful process exit as navigation success.

**Apple SDK71:** [verified results](research/apple-sdk-result-71/README.md) retain55 unchanged macOS ARM64 native/Swift replay checks,636 exclusion spans and15 exactly matching route comparisons. SimulatorARM64 native+Swift compiled and linked ONLY; executable not launched. No app build, live ARKit or device test. Explicit native `-ffp-contract=off` fixed the recorded platform parity discrepancy without relaxing geometry/assertions/tolerance; earlier failures remain preserved.

**Earlier milestone remains:** [69 three continuous assisted laps](research/tools/verified-continuous-three-laps-v1/README.md),61.791889m,15goals,oneactor/noreset. The original35cm goal tolerance and unwalked winding-closing chords remain disclosed; this was nominal deterministic simulation.

**Limits:** one static recorded scene,45×30×160cm zero-margin body,simulated delivered pose,manual tabletop ROI/unknown source confidence,evaluator/reference floor support. Floor contacts unmeasured;finite probes/sub2mm ambiguity remain. Synthetic timing/translation perturbations are not measured real sensor error or human reaction models. Spatial drift, dynamic hazards,holdout scenes,margins,full100matrix and live sensor integration/device safety remain open.

---
