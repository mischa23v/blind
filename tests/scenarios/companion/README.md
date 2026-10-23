# Companion scenario suite: portable evidence and iPhone test plan

This package contains the user's53-family scenario requirements, source-informed additions, frozen response fixtures/rubrics, preserved results and pending execution status. It contains no actual user/private-child images or raw copied YouTube descriptions. Fictional names and scenes are synthetic.

## Read first

- `RUN_STATUS.json` is the execution ledger. A fixture is not a passing test merely because present.
- `SCENARIO_TRACEABILITY.md` maps family requirements to partial production evidence, response cases and native gaps.
- `scenario_registry.json` specifies the coverage baseline and variant obligations. It does not certify every paraphrase/language/circumstance.
- `COMMUNITY_SOURCES.md` distinguishes public firsthand self-reports from authored variants.
- `GENERATED_SEED_VERIFICATION.md` explains why supplied generated video summaries are not verified scene evidence.
- `IPHONE_CHECKLIST.md` gives separate native/sensor/model procedures and supervised constraints.

## Automated versus manual

`python3 validate_suite.py` verifies JSON readability, frozen-input hashes, response counts and artifact integrity. It is a package-integrity check, not an app, model, perception or behavioral test. It has no third-party dependencies, network or device access.

The frozen response JSON is suitable for an evaluation harness that supplies exactly the listed evidence to a model and records its actual outputs. Run the smaller local model through the application's real context/tool boundary where available, not merely a duplicate prompt in an unrelated chatbot. Do not inject expected criteria into the response model. Grade against the paired frozen rubric afterward. Record model, prompt, source commit, device, settings and raw answers.

No turnkey iPhone runner is claimed in this package. Production tests are owned by the application's test targets and their actual receipts. Native live-camera/map/audio tests are manual or app-harness work described separately. Do not feed synthetic safe-path facts into live navigation as if sensors measured them.

## Keep evidence levels distinct

Legacy v1/v2 are consumed development cases. V3 and seeded cases were authored fresh to their response runners; their high scores are not empirical recognition accuracy. Community/capability/adult results are included with12 usefulness omissions retained; see NEW_RESPONSE_RESULTS.md. Any reused worker context must be disclosed. Device-native success, physical task completion, sustained battery and child usability cannot be inferred from a cloud text response.

When integrating into the repository, use a stable folder such as `tests/scenarios/companion/` and keep relative paths intact. No source-code changes or runtime asset downloads are included here.
