# Model providers and account access

Verified 2026-10-08. The app must not impose a small-model ceiling. Use a thin provider adapter, select capabilities from actual device/account availability, and evaluate English/Arabic image understanding, context use, latency and resource use on the same scenarios.

| Path | Verified capability | Remaining integration |
| --- | --- | --- |
| ChatGPT plan usage | Official sign-in supports eligible open-source/local apps using plan allowance. Account-specific discovery lists available models; the inference example uses `gpt-6.1-sol`. | Verify our registration/eligibility and native authentication/session lifecycle. Discover available Astra/Sol models rather than promise access based on a dollar plan label. |
| OpenAI API key | This environment successfully listed models and completed 12 bounded Sol 6.1 synthetic text-context requests. | This does not test plan sign-in, Dot, camera perception or native speech. Store credentials appropriately; never bundle a shared key in the app. |
| Apple on-device | Apple documents image inputs through Foundation Models multimodal prompting. | `LocalImageAssistant` now wraps the documented API behind an explicit iOS 27 SDK flag. Uncompiled and untested; actual images/languages and resource measurements remain pending. The existing known-ID selector remains a distinct fallback. See [adapter handoff](COMMUNITY_IMPLEMENTATION_HANDOFF.md). |
| Gemini Nano | Google documents on-device Android inference through AICore/ML Kit. | A possible Android provider, not evidence that iOS exposes the same runtime. Do not assume VoiceOver's implementation gives third-party apps that access. |

The plan-usage OAuth model catalog differs from the API-key catalog. Use the selected account token and documented discovery response. The documented plan inference path uses the public Responses API with `store:false` and `stream:true`; handle the final completion or failure, not just receipt of the first event. Do not reuse private browser cookies or internal endpoints. Plan limits still apply.

Sign-in provides supported model access, not automatic access to private ChatGPT conversations, Dot memories or all hosted tools. The current preview documents input/tool limitations. App memory remains local and app-managed; any Dot/computer/reservation connector is a separately verified, scoped integration.

Sources: [plan eligibility](https://developers.openai.com/siwc/token-sharing-open-source), [models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference), [preview limits](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations), [Apple multimodal prompting](https://developer.apple.com/documentation/FoundationModels/analyzing-images-with-multimodal-prompting), [Gemini Nano on Android](https://developer.android.com/ai/gemini-nano).

Do not infer task reliability from another app's image descriptions. Test map/image/sensor consistency, user/body heading, partial coverage, stale information, goal changes and speech delivery separately. Stronger cloud models and usable local models can coexist; urgent local warnings never wait for either provider.
