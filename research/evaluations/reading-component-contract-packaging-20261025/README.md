# Reading component contract packaging repair

The default `node --test tools/test/*.test.mjs` suite now includes both published reading component contract packets through `tools/test/reading-component-packaging.test.mjs`.

The wrapper copies current repository packet files and the matching actual `.github/workflows/native-reading-component.yml` or `native-reading-review-component.yml` into an isolated temporary layout, executes the unchanged Node contracts, and cleans only its own temporary directory. It clears inherited `NODE_TEST_CONTEXT` so nested failures propagate. It does not run native scripts or modify the watched probe paths, production, assertions, source pins, or gates.

Validation against immutable repository source `65a2a97e6886a246e9c0faf11147f6a46f1bdbfb`: all 18 fetched input blobs matched the published tree. Direct packet execution failed 2 of 14 checks with missing adjacent workflows (12 passed); that failure is preserved. Final wrapper: 2/2 passed, executing 6+8 unchanged contract checks, all passing. Missing-workflow and removed exact-callback-guard mutations each fail the wrapper. An initial wrapper inherited Node test context and incorrectly accepted the guard mutation; its failed validation is preserved and the corrected wrapper rejects it.

This is test-packaging coverage only, not new native acceptance. Prior native results remain unchanged. Controller, Feedback, physical camera and acoustic acceptance remain separate.
