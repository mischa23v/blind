# Independent public-packet review

Reviewed 2026-10-26. Scope: additive `tools/recent-iphone-depth-comparison/` evidence packet only. No source edits, downloads, LZFSE decoding, compiler/dependency work, native replay, new experiment or remote writes were performed.

**Outcome: no publication blocker found in the reviewed cut.**

## Identity of reviewed cut

- Public package: 151 files including its manifest; 7,060,543 bytes.
- `PACKAGE_MANIFEST.json` SHA-256: `cb71cd7178e7ca8a9c62dd1a17bf5c5439b41c8d2198e85cde11274787108b95`.
- `PUBLIC_NORMALIZATION.json` SHA-256: `f522e5f03e3411da6f71dc1cbf0116a581fa159fa7a4e9b4f305dad0e8b16410`.

## Checks performed

- Executed the standalone standard-library `verify_packet.py`: all 150 listed public files pass hash/size checks, original selected members and decoded-array hashes reconcile, and all sixteen saved per-frame predicate counts agree with the recorded native results. Totals remain 86,236/98,304 for EM1-1093 and 34,240/98,304 for EM1-0387. This is saved-evidence reconciliation, not a native rerun.
- Independently re-read all 143 mapped original files. Original hashes/sizes match; public bytes equal either the exact original or precisely the documented workspace/shared-root display substitutions. Exactly six files changed. Every copied Python/Swift/C/header source, selected sensor member, original metadata file, decoded array and numerical result remains byte-identical.
- Executed Swift/driver hashes and unchanged policy source hash match the known tested cut. The compiled policy wrapper is exactly its recorded import prefix plus the unchanged production source. LZFSE upstream files match the pinned upstream manifest; the BSD-3-Clause license is included. No compiled decoder/library/compiler payload is present.
- Scanned public text for private executor roots/identifiers and common credential patterns; no match. Entry-point Markdown relative links resolve.
- Reviewed inclusion/omission, license and privacy disclosures. Complete raw archives, binaries and caches are explicitly omitted; immutable original URLs, bytes and hashes are supplied. Dataset attribution/CC BY 4.0 notice is retained. Independently checked all sixteen JPEG headers: no EXIF, IPTC or comment segments were present. Original JSON metadata keys contain calibration, relative timestamps and poses, not names/GPS/device identifiers. The preparing reviewer's actual-pixel inspection is documented; this note does not claim a new independent biometric-anonymization guarantee.
- README/result claims consistently distinguish unmatched tasks/materials, device-relative confidence, publisher-only exact model provenance, and the CaryX 12 Pro comparator from Koivu's 12 Pro Max. No accuracy, cable-recall, body-coverage, route-completion or navigation-safety result is implied by admission/projection success.
- Public normalization explicitly preserves historical hash referents. The two normalized input manifests intentionally no longer satisfy the original path-dependent hashes; the package is not advertised as a turnkey native replay. A future portable run requires a distinct reviewed source/input cut and execution receipt. Historical pre-acquisition status text is clearly distinguished from terminal receipts.
- The concise Apple camera note distinguishes fixed versus variable main-camera aperture while leaving LiDAR module identity unverified. It does not turn RGB/processor changes into a depth-performance claim.

This review covers the exact manifest above. Any later payload modification requires refreshing its manifest and rechecking affected claims. It does not attest that a remote GitHub push or release mirror has occurred.
