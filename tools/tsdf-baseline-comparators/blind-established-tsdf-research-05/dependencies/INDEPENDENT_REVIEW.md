# Independent review — metadata-only Open3D dependency closure

Reviewed 2026-10-26 UTC. **No closure blocker found.** This review covers metadata and the proposed resource envelope, not acquisition, installation, native import, reconstruction, or navigation.

## Exact inputs

- `ACQUISITION_PROPOSAL.json`: SHA-256 `7294a7febe423b4643ff86252de83d16a8b87e1cdd9d497f4a0649039be45b0b`.
- `DEPENDENCY_CLOSURE.json`: SHA-256 `4a12a69b8d1762bed3233a3304016c1c9a8feaa76b317ef90a26dab060ee0557`.
- Reviewed `resolve_metadata.py`, `validate_proposal.py`, `FETCH_LEDGER.json`, README and both requirements lists. Existing source/proposal/evidence files were not edited.

## Independent checks

The lightweight, offline validator passed: 74 distributions, 97 active requirement edges, 46 installed reuse candidates and 28 missing wheels. Each active requirement and Python constraint is satisfied in the recorded environment, and selected wheel tags intersect this interpreter's tags. All 46 installed versions and METADATA SHA-256 values also match the current environment independently of the saved closure. NumPy 2.3.5 is reused, not replaced; no Torch/CUDA distribution or source build is selected.

All 112 saved successful metadata response bodies were length/hash checked. A separate read-only pass confirmed HTTPS official PyPI/pythonhosted endpoints, exact saved range associations, and independently re-parsed all 28 PEP 658 requirement sets and ZIP central-directory inventories. Compressed total is 121,400,340 bytes; declared expanded total is 368,764,121 bytes. Successful metadata bodies total 1,406,414 bytes. These are saved metadata-body counts, not complete wire traffic. Full wheel SHA-256 values remain expected official identities, **not locally verified acquired artifacts**.

The resolver uses a deliberately bounded candidate set and follows declared active dependencies. It is not a latest-version search, vulnerability audit, binary ABI test, or proof of successful runtime imports. Installed METADATA satisfaction does not by itself verify every installed package file or loaded module path. Blank license metadata fields are not license conclusions; retain the actual wheel license/notice files after any authorized acquisition.

## Disk feasibility

Archives plus two complete declared expanded payload copies total 858,928,582 logical bytes. Rounding each payload member to 4 KiB and allowing two copies gives 874,007,572 bytes including archives, about 69.7 MB below the 900 MiB cap before metadata and installer/filesystem overhead. This makes the bounded proposal plausible, not guaranteed.

The installed pip 26.2.2 source supports the intended narrower path: `_internal/operations/prepare.py` lines 133–197 reads a local wheel directly and does not unpack it during preparation; `_internal/commands/install.py` lines 604–656 moves installed temporary-home entries into the target. Same-filesystem target and TMPDIR normally avoid a second full expanded copy. Their source SHA-256 values are respectively `ccb9153120eef5c511d0a9c39b76d9dd0bc879a12b8492abaf5d3d5320cc94a4` and `0d11142c0f9319b08a86a0412e4adb0cacedc90e79ed06c37ba649518ba1db29`.

Observed free space at review was 1,976,262,656 bytes, above 900 MiB plus the 768 MiB reserve. This observation expires: execution must recheck it. Put wheel archives, pip target, TMPDIR and caches under the watched tree; disable inherited pip configuration/options; use no-index/no-deps/no-compile; measure allocated blocks and reserve continuously; fail rather than expand caps. Install and clear staging before adding sample data/results. The separate acquisition helper has its own source review and authorization.

## Remaining phase gates

Full wheel hashes, safe member inventory and actual installed footprint must be verified after authorized acquisition. A normal unmodified CPU Open3D import and loaded-path/version checks must succeed before numerical use. Reusing host packages is intentionally non-hermetic. No data acquisition, installation or native import was performed by this reviewer, and this note grants no physical-map or navigation authority.
