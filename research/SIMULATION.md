# Reproducible fake café evaluation

Run `npm run simulate -- --docker` on Windows, or `npm run simulate` on the Mac. Open `artifacts/simulation/report.html`. The JSON beside it contains the complete machine-readable trace; `cafe.synthetic.json` can be imported to inspect the example map, never to guide a person in a real venue.

The café has tables, a cashier, two aisles, a restroom, a side exit and an entrance. It deliberately includes a graph edge crossing the tables, which the collision layer must reject. The executable uses the actual BlindCore detector, map planner, context filter, bilingual destination matching and ID validation. Synthetic depth frames go through floor calibration and temporal hazard detection. It does not use actual camera images, BLE radios or a live language model.

Seventeen cases cover the normal route, blocked passage rerouting, unreachable destination, drop, chair, overhead obstacle, empty depth, tracking loss, unknown indoor position, missing and ambiguous destinations, selected detail, a fabricated model ID, and four Arabic variants. Fixed hazard text is shared with the iPhone app. Detailed model selections are deliberately scripted: this tests the boundary, not language understanding. Invalid model IDs fall back to the selected observed facts rather than inventing a location.

## Actual model evaluations

On a supported Apple Silicon Mac with macOS 26 or newer, a suitable Xcode SDK, Apple Intelligence enabled and its model downloaded:

```sh
npm run simulate
npm run evaluate:apple
```

This calls the same `OnDeviceLanguage` implementation and prompts as the iPhone. It records language support, IDs, latency and expected-ID matches in `apple-model-results.json`. Arabic support is checked using `supportsLocale`; an unavailable model or unsupported language is a failure/unavailable result, never represented as a pass. No cloud fallback exists. A passing Mac test does not establish iPhone performance, Arabic speech quality or battery behavior.

For an optional real OpenAI comparison, put the key and chosen model in `server/.env` and run `npm run evaluate:openai`. It makes at most six text-only requests using entirely fake map/evidence data, with no automatic retries. It records tokens and latency in `openai-results.json`. The schema wrapper differs from Apple's JSON-array response, while the ID-selection task is the same. This benchmark is not an integration of OpenAI into offline navigation and does not test photo understanding. No real provider test has run without credentials.

Exact-match scores are narrow regression checks, not complete model-quality evaluation. The test must be extended with many real-world variations and professionally reviewed Arabic before field trials. More than one selection can sometimes be reasonable; inspect traces when a score fails. Physical localization, glass, sunlight, crowds, moving furniture and sensor blind spots require device testing.

## Cost design

Camera/depth processing, BLE, maps, collision checks and fixed Arabic/English alerts do not make model requests. Templates and unique destination-name matching also work without a model. An on-device model runs for explicit questions or selected optional descriptions, not every video frame. Cloud images require a separate action and offline mode defaults on. No continuous cloud service is needed for the implemented monitoring loop.

[Apple Foundation Models](https://developer.apple.com/videos/play/wwdc2025/286/) provides on-device processing and offline operation on supported systems. Model availability, language support and battery use must be tested on the target phone. [Google ML Kit GenAI](https://developers.google.com/ml-kit/genai) uses Gemini Nano through AICore on supported Android devices; it is not the iPhone's built-in model. The [Gemini API terms](https://ai.google.dev/gemini-api/terms) checked on 2026-10-02 exclude applications directed at or likely accessed by under-18s, so that cloud service is not selected for this children's app. A free API quota would also not be a dependable all-day runtime budget.
