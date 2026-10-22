# Private Windows-to-Mac transfer — 2026-10-22

This is the owner's development/test transfer, not a public community-map release.
The GitHub repository remains private. Sign into GitHub as its owner to download.

## Download

Release: https://github.com/mischa23v/blind/releases/tag/mac-transfer-20261022

Download all seven release assets into one folder. In Terminal, open that folder and run:

```sh
shasum -a 256 -c SHA256SUMS
mkdir -p "$HOME/blind-windows-transfer"
tar -xzf windows-project-and-test-assets.tar.gz -C "$HOME/blind-windows-transfer"
mv ca1m-val-42898570.tar "$HOME/blind-windows-transfer/research/datasets/ca1m-val-42898570/"
```

Or, if GitHub CLI is already installed and authenticated, download with:

```sh
mkdir -p "$HOME/Downloads/blind-transfer-20261022"
cd "$HOME/Downloads/blind-transfer-20261022"
gh release download mac-transfer-20261022 --repo mischa23v/blind
```

## Use the newest source with all recorded data

The Windows source snapshot is older than GitHub's current Mac changes. Keep the
extracted Windows folder as a reference; do not copy its source over your Mac project.
For a fresh checkout (choose another destination if ~/blind already exists):

```sh
cd "$HOME"
git clone https://github.com/mischa23v/blind.git blind
mkdir -p "$HOME/blind/artifacts" "$HOME/blind/research/datasets"
cp -R "$HOME/blind-windows-transfer/artifacts/." "$HOME/blind/artifacts/"
cp -R "$HOME/blind-windows-transfer/research/datasets/." "$HOME/blind/research/datasets/"
cd "$HOME/blind"
```

If the Mac already has an active checkout, preserve its uncommitted work and current
test reports; copy the missing dataset/report directories individually instead.
No source replacement or Git reset is needed.

Read the latest checkout's MAC_HANDOFF.md, PROGRESS.md, TODO.md and TASKS.md first.
Use its latest setup commands and requirements. The historical Windows snapshot's
Apple test status is superseded by newer Mac records.

## Included

- Windows project source, instructions, research, maps, scenarios and fixtures.
- Entire original CA-1M validation capture 42898570, plus extracted metadata and
  existing evaluation JPEGs. Keep the original tar at the path shown above: the
  real-scene evaluation tool reads frames from it.
- The 12-frame RGB-D stair subset: pictures, point clouds, extrinsics, manifests,
  replay inputs and previous scores.
- The 3DLite apartment mesh, inspection grid, previews and replay data.
- Existing test logs, walking-scenario transcripts, model comparisons and timings.
- Historical source handoffs and available upstream source snapshots.
- Git history in blind-history.bundle, including fetched newer Mac commits and the
  remote review branch. This is an offline history backup, not a build dependency.
- TRANSFER_MANIFEST.json: individual file hashes, source commits, dataset sources,
  licences and changes. SHA256SUMS checks the downloaded assets.

No credentials, private keys, node_modules or platform build caches are included.
Dependencies must be resolved for macOS using the checked-in pins; no model weights
or heavy dependencies were installed to prepare this transfer.

## What these datasets establish

They are reusable starting points for deterministic replay, image/model evaluation,
map import and regression comparisons. They describe the recorded source places,
not your home. The OAS apartment fixture is an authored drawing, not a LiDAR scan.
Replayed poses do not prove live ARKit localisation, cross-device alignment or present
clearance. Scan your own rooms on the iPhone for those device checks.

The source datasets retain their original licences and attribution; this private
transfer does not change them. Sources and exact file hashes are in the manifest
and the existing source.json records. CA-1M original archive is unchanged.

No new app, model, iOS or mobility tests were run during packaging. Existing results
are historical evidence. Keep the Windows originals until extraction and use on the
Mac are verified.
