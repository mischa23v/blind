# Bounded official manufacturer PDF replay

This is **real public manufacturer PDF text through the actual Core reference/ledger code**, with **synthetic speech callback outcomes and monotonic timing**. It is not an OCR accuracy, physical-appliance identity, native PDF integration, audible speech, iPhone or live-model test. It does not recreate the missing historical 237-check data or imply that five checks are five whole real-world scenarios.

## Verified source and license boundary

- Official source: [Bosch WAT28400UC use/care manual, document 9001427628_A](https://media3.bosch-home.com/Documents/9001427628_A.pdf).
- PDF SHA-256: `dcbd212e6c8f564d3ef02e97b0d261ee547f32e751a46679ed2f0db27fc71d3c`; 4,943,563 bytes, 40 pages.
- Model verified in cover extraction: WAT28400UC as printed. This does not bind a physical machine or independently establish a `/xx` appliance variant.
- Selected page: PDF page 29 (one-based), the full time-setting subsection. Rendered page was inspected; raw text extraction preserves the complete subsection in reading order, including the notice and worked example, rather than mixing the two columns.
- Extraction: already-installed Poppler `pdftotext` 25.03.0, `-raw`, page 29 only. Cover extraction independently checks the printed model. This uses the PDF text layer, not OCR.
- [Bosch legal policy](https://www.bosch-home.com/us/en/c/legal/blt068e61b5256d1dc7) provides no open intellectual-property redistribution license. Keep the raw PDF, full extracted text, rendered page and private fixture/output outside the repository and ZIP. Published evidence contains hashes/counts/locators only, plus short section identifiers required by the adapter.

No heavy install, new recognition model, LLM call or manufacturer-content upload was performed. The PDF contains embedded JavaScript metadata, but was processed only by text/rendering tools; no embedded PDF script was executed.

## Actual executions

1. Pinned PDF and cover-model check, real page extraction and complete-block selection: passed. The selected block is 699 UTF-8 bytes, 123 whitespace-separated words. Section SHA-256: `570812f1bfd111f9a32c275eae49af3332ee51f81a8482e2571f47db0eefecd9`. The Core word convention counts punctuation/hyphen/number tokens differently from whitespace counts.
2. Preserved real-source fail-before witness: **1 test, 1 expected failure, exit 1**. The untouched generic model-evidence path returned **0 of 1** source records, because its bounded evidence rules cannot retain this complete source block. Log: `logs/07-official-pdf-fail-before.log`. The assertion and raw failure are preserved, not redefined as a pass.
3. New optional Core replay: **5 tests, 0 failures, exit 0**. Log: `logs/09-final-official-pdf-core-replay.log`. Covers the actual extracted block end to end, an actual heading-only match rejection, wrong selected model, interruption/no-resume and hazard/deadline withdrawal.
4. The typed complete result is 1,135 encoded bytes against the 900-byte model-result limit. The direct Core reading lane retains it outside that budget and reconstructs all original block bytes in order after five admitted chunks. Attributed word counts: **35, 35, 35, 35, 9**. Source-slice/spoken-text hashes and page locators are in `official-pdf-redacted-evidence.json`.
5. Issued time 100 and deadline 160 are synthetic monotonic values. Simulated completion callbacks are delivered two synthetic seconds per chunk. No real playback-speed/60-second completion promise is established; actual speech that exceeds the original deadline must withdraw without claiming remaining words were spoken.

6. Optional Python adapter rejection tests: **4 tests, 0 failures, exit 0**, covering mismatched PDF bytes, modified source text, changed locators and an unexpected private metadata field. Log: `logs/11-final-official-adapter-rejection-tests.log`. Redaction reconstructs a pinned metadata allowlist; failure assertions do not print actual source chunks.

The production Core source is unchanged from the reviewed and 963-test portable checkpoint. Optional replay tests live outside the ordinary test target and require the separately obtained local fixture, so the normal source-only package neither embeds copyrighted text nor silently skips a missing replay.

## Reused tools and adapter scope

- [Poppler](https://poppler.freedesktop.org/): installed `pdftotext` 25.03.0, no library/code redistribution. The local packaged copyright notice lists GPL-2 or GPL-3 for the main code. Upstream describes its CI platforms, but upstream CI was not executed or taken as proof of this integration. The actual pinned-page extraction and image comparison above are the local evidence.
- Python 3.12.14 standard-library hashlib, subprocess, json and uuid: small bounded local adapter only, no new recognition or extraction algorithm. The adapter checks source bytes, cover label and reviewed section boundaries and delegates extraction to Poppler.
- Existing Swift Core tool/evidence and speech ledger types are reused. No new model, weights, inference runtime or dependency installation.

## Reproduce without publishing source text

Use installed Swift 6.4.1 and `pdftotext`, obtain the exact official PDF separately, then invoke:

`bash reconstruction/reference/run-official-pdf-replay.sh /path/to/repository /outside/repo/manual.pdf /outside/repo/new-private-replay`

The wrapper uses serial Swift jobs and separate writable caches, verifies the PDF and section hashes, runs the preserved failure witness and five passing Core tests, and writes a redacted evidence file. It refuses an existing work directory and rejects raw input/output inside the source staging tree. Individual extraction/redaction/test commands were executed; the assembled shell wrapper was syntax-checked, not rerun as another full clean build.

The native exact-model manual/PDF selection/extraction adapter is still absent. Existing Vision OCR, exact selected-photo identity, native speech receipt bridging, current sensor state, actual playback cancellation and Apple tokenizer branches remain separate integration/device work.
