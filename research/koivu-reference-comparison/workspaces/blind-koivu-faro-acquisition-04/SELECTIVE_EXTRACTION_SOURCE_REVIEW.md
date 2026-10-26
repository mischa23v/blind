# Independent source review: exact three-file extraction

2026-10-26 03:58 UTC. Read-only review; no archive extraction, header scan, geometry load, tests or evaluation executed by this reviewer.

**Approved under the separate maintainer authorization for exact selective extraction and bounded header/metadata inspection only.** Reviewed helper SHA-256:

`83a8b9f25c9ec777df74bcfc50cc6581dd1290bf2aca1975dee62d7d11d1b9b9`

The helper is `extract_selected.py`. It does not modify the previously reviewed archive guard (`ee2e095bfd35f864d509ede0ec2404362825edff79af38c18f19f8e5e7ea1e37`) and checks that guard plus the installed Python tarfile source hash before loading it.

## Reviewed boundaries

- Exactly three statically named regular outputs: `gt_mesh.ply` (660,550,085 bytes), `icp_iphone.json` (449 bytes), and `transformations_colmap.json` (239,934 bytes). Total **660,790,468 bytes**. No point-cloud extraction or arbitrary member destination exists.
- Both original archive SHA-256/lengths and inventory SHA-256 values are fixed. I checked the two current inventory hashes match the helper constants. Archive descriptors use `O_NOFOLLOW`, require regular files and exact lengths, and are SHA-verified before and after parsing through the same descriptor. Device/inode/size/mtime/ctime and final pathname identity must remain unchanged.
- The pinned tar guard rejects unsafe names, links, sparse/special entries and oversized hidden metadata; raw headers and decompression remain bounded. The extractor additionally rejects sparse metadata keys and requires the entire observed logical inventory to equal its pinned inventory. It drains gzip through EOF/CRC before success.
- Only whitelisted exact original member names/types/sizes are copied, in bounded chunks, into exclusively created files in a private partial directory. Declared and actual byte totals are checked; contents are hashed and fsynced, then rehashed before publication.
- Aggregate staged outputs are capped at **640 MiB**, with **768 MiB free-space reserve**, remaining payload accounting and a receipt allowance. The helper sets **384 MiB address-space**, **300 CPU-second** and **300 wall-second** limits. Partial failures remain distinguishable and are not silently replaced.
- Final publication uses Linux `renameat2(RENAME_NOREPLACE)`, preventing an existing final-directory overwrite race. Existing final/partial paths, including symlinks, are refused.
- PLY inspection reads at most **64 KiB of header** and reports declared counts/format only. It does not load vertices/faces, infer units, apply transforms or invoke VTK. JSON inspection is byte-bounded and checks finite metadata and archive filename association, not registration accuracy. The pose-source wording correctly says the filename does not establish successful COLMAP or causal ARKit tracking.

No remaining source-review blocker was found for this narrow step. Approval does not establish that the files extract successfully, that the mesh fits an evaluation memory budget, that camera/reference association is correct, or that any sensor/reference disagreement is physically measured accuracy. Those require separate outcomes and the later protocol gate.
