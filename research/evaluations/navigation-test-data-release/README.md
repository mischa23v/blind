# Bounded, source-pinned public test-data mirror

The workflow is intentionally **inert** (`if: false`, unactivated source revision). Publishing these source files does not upload data. A separately reviewed workflow-only activation must pin the exact source commit and use a self-path push on `master`, with commit marker `[navigation-test-data-SOURCE7-once]`. The Python runner additionally requires that exact marker, public `mischa23v/blind`, a GitHub-hosted Linux runner, first run attempt and unmodified pinned source checkout. Manual dispatch, forks, PRs, forced pushes and reruns are rejected.

The only remote mutations are one possible creation of experimental prerelease `navigation-test-data-20261026` (`make_latest: "false"`), followed by at most one upload of each absent, exact-named asset. There is no delete, overwrite, release update or retry of a write. Ambiguous POST outcomes are reconciled by bounded GET requests. Existing mismatches, duplicate names, starter uploads, absent/incorrect digests, unexpected assets and unresolved outcomes fail visibly. A failure can leave an incomplete release or starter asset for explicit maintainer investigation; the runner never silently repairs these.

Execution source and release target are distinct immutable commits. The tag targets the activation commit, verified as current `master` before creation; the receipt and release notes record both revisions. This avoids broadening the repository-only ephemeral `GITHUB_TOKEN` beyond `contents: write`. GitHub does not allow that token to create a release at a commit whose workflow files differ from the current default branch. Existing tags must already point directly to the activation commit; annotated or conflicting tags are refused, never modified.

## Transfer and resource limits

Only the two official HTTPS Zenodo URLs in `assets.json` are allowed. Download bytes total **602,159,665**, below 1 GiB. The unchanged upload is another 602,159,665 bytes plus three small metadata files; **combined network traffic exceeds 1 GiB**. Each archive is below GitHub's 2 GiB per-asset limit. No redirects, alternate origins, package installs, persistent credentials, dataset execution or extraction occur. Python standard library only.

Job deadline: 15 minutes; runner deadline: 14 minutes, including I/O. The runner requires **4 GiB free plus expected downloads** before work, and preserves a 4 GiB free reserve while operating. HTTP operations time out; no automatic transfer retries. Only a bounded, allowlisted JSON receipt (64 KiB maximum) is uploaded as an Actions artifact, not binaries, headers, tokens or environment dumps.

## Local protocol tests (no network)

```sh
python3 -B tools/ci/test-navigation-test-data-release.py
```

Tests use mocked API responses and tiny temporary files. They exercise host/source/event guards, exact allowlist/checksums, redirect and size/hash failures, release/tag conflicts, duplicate/starter assets, remote digests, uncertain POST reconciliation and metadata bounds. They do **not** prove hosted token authorization, external uptime, transfer throughput, GitHub digest availability or actual release creation. The workflow remains inactive until separately approved. Successful upload must be checked against all five remote assets and the final receipt.

## Primary references

- [GitHub release creation and target permissions](https://docs.github.com/en/rest/releases/releases#create-a-release).
- [GitHub release asset upload/digest and failed starter assets](https://docs.github.com/en/rest/releases/assets#upload-a-release-asset).
- [GitHub repository-scoped automatic token](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication).
- Exact dataset authors, licenses and source records: [ATTRIBUTION.md](ATTRIBUTION.md).
