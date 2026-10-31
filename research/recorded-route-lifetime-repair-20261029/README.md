# Recorded-route restart test: reviewed, not adopted

**Research preservation only.** The adjacent patch changes one test file. It has not been applied to the app's test target, compiled or executed. The added regression is **authored/unrun**. Adoption will be bundled separately with the selected engine checkpoint; no CI run is authorized by this packet.

## Diagnosis and bounded correction

The original restart test failed its **five-second snapshot wait**, followed by missing-page and missing-first-frame assertions. Its first read had no worker-entry timing mark at the failed wait; the underlying delay remains unknown. Store, repository and test source were unchanged from the preceding app checkpoint. These observations do not prove a new storage regression or database corruption.

A concrete test failure cascade was found: the 90-sample loop ignored a timed-out snapshot, and later reads could return non-nil busy/withheld snapshots inline. Such callbacks do not drain the worker. The test could reopen the same database and eventually delete its temporary directory before the first owner had drained.

The exact reviewed patch:

- Preserves the original snapshot helper and **5 s failure**, but aborts subsequent restart assertions on timeout or a busy/load-failed/persistence-failed result.
- Requires a real prior trip, 90 durable samples and no volatile remainder; retains the original bounded-page and first-frame checks.
- Reuses the existing stop/test-drain seam. Cleanup waits boundedly and deletes storage only after drain and weak-owner retirement checks; otherwise it retains the owned directory. No product API, queue, QoS or deadline changes.
- Adds one blocked-factory regression requiring explicit release, retired-read delivery and actual drain acknowledgment in order. A factory timeout cannot substitute for release.

## Status

Independent **source-only PASS**: 58 review assertions plus 57 portable source checks. All 24 original class selectors remain; 23 unrelated bodies are identical. The proposed added method makes 25 class methods and **291 expected default hosted identities** after adoption. This is not a native pass: the historical 290-case run still contains 12 failures and two skips.

Source hashes, review identity and the two required native selectors are in `SOURCE_PINS.json`. The patch is byte-identical to the reviewed candidate. Native compilation, discovery, execution and the original delay diagnosis remain open. Do not retry automatically, raise the original deadline, or treat a later focused pass as a full-suite pass.
