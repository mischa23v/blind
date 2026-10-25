# Model availability observation, not an acceptance waiver

Hosted main sources cc3b5f77 and 96fd2d retained five failing model methods (14 parameterized nil-text issues), two skips, and no runtime XCTest failures. Logs report missing safety model assets and the adapter's generic on-device-reply-failed status. These are not successful model acceptance results, and they do not prove simulators universally unsupported.

## Small test-only observation

Immediately before each of the eight existing `LocalImageAssistant.converse` call sites, including the unavailable-path contract, record a fixed fixture label, an allowlisted public `SystemLanguageModel.default.availability` state, and numeric test-runtime OS version. The label explicitly says **before adapter invocation**. It is not a new readiness gate. Existing conditions, assertions, replies, skips, and limits are unchanged.

The adapter creates both its streaming and bookkeeping `LanguageModelSession` without supplying a model. Apple's [session initializer](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:)) specifies `.default`, so the observed model matches that configuration. The adapter can retry or perform bookkeeping internally; this test-only observation does not capture availability at each internal generation and cannot expose the swallowed typed error. No production callback or error-description logging was added.

The CI helper emits at most 80 availability records of 600 characters in a dedicated excerpt on both success and failure, preserving the original command exit code. Preflight logs only the host OS version and build using `sw_vers`; invalid/missing values become `unknown`, not a new failure. Xcode and simulator SDK provenance already exist. No environment dump, hostname, serial number, prompt, returned text, or generic error description is added.

## Official guidance and limits

Apple's [availability guidance](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) requires checking availability and describes model readiness/system reasons. The public [unavailable reasons](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason) are device eligibility, Apple Intelligence disabled, and model not ready. Unknown future cases map to fixed labels.

Apple's [Foundation Models code-along](https://developer.apple.com/videos/play/wwdc2025/259/) discusses simulator inference versus physical-device performance and loading the model and safety guardrail. The [iOS 27 notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes) include a simulator fix for Private Cloud Compute, not a diagnosis of these on-device missing-asset errors. No official documentation/release-note remedy for the exact safety_deny/safety_embedding asset identifiers was located. No assets are downloaded or settings changed by this diagnostic.

Three focused Node checks pass, including synthetic shell success/failure and bounded extraction. Swift frontend syntax parsing passes; FoundationModels API typechecking still requires Apple SDK CI. Source preservation checks confirm only the documented diagnostic insertions in the test source. Missing model assets remain a reported runtime/environment failure, not grounds to weaken model assertions or reinterpret a skipped test as acceptance.
