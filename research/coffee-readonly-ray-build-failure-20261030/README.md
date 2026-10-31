# Read-only ray adapter: failed first compilation

The first additive adapter build failed at commit `29fc2e539b26827a4eac0ae637aa16cc3168da88`. Compiler exit1 was observed and its process group retired. All before/after input hashes and terminal output hashes were verified unchanged. Original failure files remain untouched; this directory contains text copies and a concise result.

Cause: the new adapter used `[]` for OctoMap point3d (Vector3) coordinates. The retained official implementation exposes `operator()`. This was our adapter API mistake, not a failure of the released mapping engine or dataset. No candidate library or native control result was obtained.

Measured bounded build:11.30719CPU seconds,11.424037wall seconds,165,822,464-byte peak observed RSS. No held-out depth was opened, and no geometry or mapping threshold was changed.

The separate v2 source corrects15 Vector3 accesses, keeps C arrays indexed with `[]`, preserves the double-domain bounds guard, and uses a fresh build02 output. It requires independent review and a new measured build. A source correction is not a passing test.
