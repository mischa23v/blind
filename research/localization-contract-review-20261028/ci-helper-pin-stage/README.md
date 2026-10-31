# Authorized CI helper source-pin repair

2026-10-28. Published native precheck failed because the authorized three-line bounded scene-phase extractor changed `tools/ci/native-apple.sh` while integrated verification still pinned the former helper.

The new `integrated/scene-timing-ci-helper.patch` is exactly the helper hunk extracted from `research/scene-publication-timing-20261028/APPLIED.patch`. The checker copies the helper to an isolated directory, reverses the hunk and requires old SHA `683323c46df0e18673ba75dc6e3c610d0aa5087884a4a07ddd74b2c5600be263`. Current SHA `163fa512486bbbce522aa735cda0d36ca2711955edef9b118d8b598e900061e6` is separately pinned. No blanket repin, helper edit, app change, workflow edit or historical rewrite.

**51/51 source checks passed** in an isolated published-baseline projection. The shared workspace concurrently contained unpublished geometry changes to NavigationModel, so the ordinary check correctly rejected that different hash (`before-check.log`). It was NOT repinned. The projection used the exact preserved `fcea783...` published NavigationModel; `PROJECTION.json` names and hashes it. Other inputs remained the current source-checked files. No native build/test or process result was claimed by this check.

The prior historical reversals and diagnostic build/default-off checks all remain. The scene extractor retains its existing eight-line / 1,500-character bounds and does not change build/test commands, failure status or time budgets.
