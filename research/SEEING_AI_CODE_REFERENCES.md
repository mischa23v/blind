# Seeing AI and related source-code references

Checked 2026-10-22, at the user's request. This covers all eleven repositories in
the supplied list. It is a starting inventory, not a claim to have found every
repository related to Seeing AI or every open-source assistant for blind people.
These repositories are learning references; none was adopted or executed here.

## What is public

The complete Microsoft Seeing AI mobile application source was not verified as
public. A [public .NET Android issue](https://github.com/dotnet/android-libraries/issues/595)
identifies `msresearch/SeeingAI/_git/SeeingAI-Mobile` as an internal Azure DevOps
repository. That reference does not provide access or permission to its source.

The strongest public connections are BankNote-Net, the currency-development
example, and the Seeing AI team's audio-description project. The other entries
are independent work or general Microsoft technologies, not the mobile app.

## Repositories from the supplied list

| Repository | What to learn | Connection and limits |
| --- | --- | --- |
| [microsoft/banknote-net](https://github.com/microsoft/banknote-net) | Banknote embeddings, MobileNetV2 encoder, training a classifier for an existing currency or custom image classes. | README reports deployment of a model variation in Seeing AI. Its published currency-choice example does not list SAR; do not assume Saudi-note support. This is not the full app or a ready-verified iOS integration. |
| [xiaoyongzhu/SeeingAI-Currency-Detection](https://github.com/xiaoyongzhu/SeeingAI-Currency-Detection) | Transfer-learning notebooks, background rejection, varied framing/occlusion, mobile model export with Core ML, and Azure deployment examples. | Explicit Seeing AI currency-development article/example, hosted under an individual account. Historical toolchain; reported upstream timing is not our measured iPhone result. No top-level licence returned by the API: reuse permission remains unresolved. |
| [microsoft/ai-audio-descriptions](https://github.com/microsoft/ai-audio-descriptions) | Timing narration around dialogue, editable drafts, review, speech rendering and audio mixing. | README identifies the Seeing AI team. The supplied workflow uses Azure/Foundry and speech resources; study its design rather than making our offline core depend on it. |
| [aiformankind/seeing-the-world](https://github.com/aiformankind/seeing-the-world) | Fruit/vegetable image collection and recognition experiments, varied grocery examples and model evaluation ideas. | Independent AI for Mankind project aiming to improve recognition and contribute models; not Microsoft Seeing AI app source. Its historical Docker instructions were not run. |
| [Azure-Samples/azure-ai-vision-sdk](https://github.com/Azure-Samples/azure-ai-vision-sdk) | Vision sample integration, capture and result-handling patterns, including mobile samples. | General Azure SDK/sample repository. Inspect the pinned contents for supported features; do not assume a particular SDK generation or offline inference from the name. |
| [Azure-Samples/cognitive-services-speech-sdk](https://github.com/Azure-Samples/cognitive-services-speech-sdk) | Speech SDK samples across platforms, including Apple languages, streaming and speech lifecycles. | General Azure Speech examples. Our default remains native on-device speech and VoiceOver; a cloud service cannot be a core requirement. |
| [microsoft/AI](https://github.com/microsoft/AI) | Catalogue of AI examples, reference architectures and linked projects. | Broad collection with submodules, not Seeing AI code. Each linked project has its own version, dependencies and terms. |
| [microsoft/psi-samples](https://github.com/microsoft/psi-samples) | Multimodal pipelines, sensor/audio/video handling and situated-interaction examples. | General Platform for Situated Intelligence samples. Learn timing and evidence-flow patterns; no iOS-ready integration is established. |
| [microsoft/Earth-Lens](https://github.com/microsoft/Earth-Lens) | A real mobile application's image-classification, interface and test structure. | Archived Microsoft Garage iPad project for aerial imagery. Different domain and older stack; not Seeing AI and not evidence of maintained assistive recognition. |
| [microsoft/AgentsClientSDK.iOS](https://github.com/microsoft/AgentsClientSDK.iOS) | iOS agent-client samples, chat and adaptive-card integration. | General agent SDK/sample repository, not Seeing AI perception code. Uses Microsoft-specific SDK terms; account/network-oriented examples do not meet our offline core requirement by themselves. |
| [microsoft/samples-for-ai](https://github.com/microsoft/samples-for-ai) | Historical deep-learning examples across several frameworks. | General learning resource with older frameworks; not the Seeing AI application. Inspect modern compatibility before reuse. |

## Provenance, licensing and evidence

`SEEING_AI_REPOSITORY_EVIDENCE.json` records each repository's exact checked commit,
source URLs, archive status, README and licence SHA-256 hashes, and paths matching
test/build evidence. `seeing-ai-reference-evidence.zip` retains those small source
documents and per-repository review records. No source archives, model weights,
large datasets, installers or dependencies were downloaded for this review.

Most checked source licences are MIT. Important distinctions:

- BankNote-Net's root code licence is MIT; its README separately assigns the dataset
  CDLA-Permissive-2.0 and discusses model/data terms. Resolve the exact selected
  model's terms independently; a code licence does not automatically cover weights.
- The currency-development example has no licence returned by the GitHub licence
  API. Public visibility is not a licence grant.
- Psi-samples' API label is NOASSERTION, but its actual LICENSE.txt states MIT.
- AgentsClientSDK.iOS uses Microsoft Software License Terms in License.md, rather
  than an inferred MIT grant. Review the particular SDK and marked samples.
- Dataset/image licences are separate from code. These links do not approve the
  Saudi currency ZIP for training or distribution.

Test/build paths in the evidence are source inventory, not passing test results.
No upstream builds, tests, notebooks, inference or training were executed. No local
adapter changes were made. Integration suitability and iPhone results remain open.

## Next work on the Mac

Start the currency investigation with BankNote-Net and the currency-development
example: inspect the pinned training/export code, confirm Saudi denomination and
front/back labels, preserve separate held-out captures, include background/unknown
examples, and evaluate an explicit uncertain/reposition response. Avoid near-duplicate
frames crossing training and evaluation splits. These are proposed checks, not
results. A classifier must not confidently invent a value from unreadable evidence.

Use the other repositories for UI, narration timing, sensor synchronization and
recognition ideas. Preserve this project's free, private, on-device, offline core
and permanent spatial rules. Do not copy cloud photo-upload flows into the app.
No Docker, heavy installation, model downloads or training is authorised by this
reference-note task. Later reuse needs a scoped adapter and measured tests.

## Additional discovery links

These searches change over time and are not evidence that every match is relevant:

- [Repositories matching Seeing AI](https://github.com/search?q=Seeing+AI&type=repositories)
- [Code mentioning SeeingAI](https://github.com/search?q=SeeingAI&type=code)
- [Currency-recognition repositories](https://github.com/search?q=Seeing+AI+currency&type=repositories)
- [Microsoft computer-vision repositories](https://github.com/search?q=org%3Amicrosoft+computer+vision&type=repositories)
- [Azure vision examples](https://github.com/search?q=org%3AAzure-Samples+vision&type=repositories)
- [Open-source visual assistants for blind users](https://github.com/search?q=blind+visual+assistant&type=repositories)
- [Microsoft developer samples](https://learn.microsoft.com/en-us/samples/)

## User-supplied reference images

The companion private release holds the original `hello.zip` unchanged: three PNG
screenshots, IMG_6575.PNG, IMG_6576.PNG and IMG_6577.PNG, showing the Read, Describe
and More interface. These are user-supplied developer reference material, not a
training dataset or approval to upload app users' camera/memory data. Keep pictures
as private release assets; only this written note and repository evidence go in Git.

## Seeing AI features compared with this app, and what was added (2026-10-22)

The Seeing AI app source is internal, so this compares its documented features ([Microsoft: Seeing AI 2](https://blogs.microsoft.com/accessibility/seeing-ai-2/), [What's new](https://blogs.microsoft.com/accessibility/?p=5455), [VOA](https://learningenglish.voanews.com/amp/personal-tech-seeing-ai/3949984.html), [1.3 release notes](https://apkmirror.com/apk/microsoft-corporation/seeing-ai/seeing-ai-1-3-release)) with this app. No code was copied. Everything added uses Apple's on-device Vision, ARKit and code: free, offline, private, and with no language model deciding what is there.

| Seeing AI | Here |
| --- | --- |
| Scene / Describe | Already present (grounded image descriptions) |
| Person | Opt-in familiar-people experiment; no age, emotion or traits (rule) |
| Currency | Present, disabled until a reviewed reference pack exists |
| Colour | Requested clothing colour |
| Find my things | Saved items by look and place, live search, tracked target to reach |
| **Short Text**: speaks text as it appears | **Added**: "Read text". Live OCR every 0.7 s; each line spoken once, top to bottom, repeated only after 10 s out of view (`LiveTextReader`). |
| **Document**: guidance to centre the page | **Added**: "Read the page". Vision document detection tells the child to move left, right, up or down, closer or further, until the page is held still for three looks, then reads it with accurate OCR (`DocumentGuidance`). |
| **Product**: beeps toward the barcode | **Added**: "Scan the barcode". A tick every 0.8 s while searching (30 s limit). It reads QR text and names link hosts without opening them, and reads product codes. "Call this apple juice" saves a name on the phone (`ProductMemory`); later scans say "This is apple juice". There is no online product lookup (offline rule). |
| **Light** detector | **Added**: "Is the light on?". ARKit light estimate gives dark, dim, normal, bright or very bright, spoken on change, with beeps that get faster in brighter light (`LightLevel`). |
| **Explore photo by touch** | **Added**: "Explore a picture by touch" (Settings › Ask and goals). The picture stays in memory only. Text, people, the page and detector objects are VoiceOver regions labelled with where they are, and the picture is forgotten on leaving. |
| Describe photos from the library | **Added**: "Describe a photo from my library" in Explore a picture. Apple's Photos picker opens; the photo is read in memory only. It gets the same touch regions, plus a hedged overview ("may show") from Vision image categories. |
| Describe photos shared from other apps | Not yet: needs a share extension target. The library picker covers saved photos. |
| Handwriting | Covered partly by accurate OCR in page reading; not separately evaluated |

Tests: `BlindCore/Tests/BlindCoreTests/ReadingToolsTests.swift` (written, not run here), plus a static check in `tools/test/companion-evidence.test.mjs` that the reading tools use no model or upload path.
