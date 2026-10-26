# Independent source review: Koivu FARO acquisition and inventory only

2026-10-26 03:46 UTC. Read-only inspection; this reviewer did not download, scan archive bytes, extract files, run tests, compile or execute geometry. Reviewed installed Python 3.12 `tarfile` method source to confirm guard placement.

**Approved for the exact maintainer-authorized bounded acquisition and inventory-only scope.** No remaining source-review blocker at script SHA-256:

`ee2e095bfd35f864d509ede0ec2404362825edff79af38c18f19f8e5e7ea1e37`

Source: `acquire_and_inventory.py`. A later source change requires separate review; this is not a successful-download or complete-inventory result.

## Scope and provenance

- Fixed official URL: `https://zenodo.org/api/records/10222321/files/koivu_mesh_pd.tar.gz/content`.
- Fixed compressed size: **455,583,916 bytes**; published MD5: **`1fc9598ff73fc833b6e4db90af604062`**.
- Cached official metadata is checked before parsing against SHA-256 **`147ea028701494eeb1e267bf2ec575c683a87bfab606fafe306ca8d603dc803b`**. The matching asset URL, length/checksum, open access and CC BY 4.0 metadata are then required.
- Initial request is fixed HTTPS. Redirects and the final response URL must remain HTTPS on `zenodo.org`, without username/password. The final URL is recorded.
- The downloader uses exclusive partial-file creation, refuses existing archive/partial files, enforces the exact size and 460 MiB ceiling while streaming, verifies MD5 and records SHA-256 before rename. It reserves remaining transfer space plus the 768 MiB free-space floor. Failed partial files are not silently removed or substituted.

## Inventory safeguards

- SHA-256 and exact compressed size are verified through one open archive descriptor before seeking that same descriptor back for gzip/tar reading. Device/inode/size/mtime are checked after scanning. No pathname reopen is used between the verified archive read and inventory.
- Decompressed reads are bounded to **2 GiB**. The raw-header counter covers ordinary members, root entries and hidden PAX/GNU headers, with a **10,000-header cap**. This avoids counting only the logical names yielded by Python's parser.
- PAX/global/Solaris and GNU long-name/link metadata bodies are limited to **1 MiB before allocation** through the installed `TarInfo._proc_member` hook. GNU sparse type, all three installed PAX sparse processing hooks and any yielded sparse member are rejected. The outer **384 MiB address-space** and **300-second CPU/wall** limits remain containment layers, not evidence that an unknown archive fits.
- Names reject traversal, absolute paths, backslashes, NUL, overlong names and drive-like prefixes. Normalized duplicates, links and special members are rejected. The normalized root is allowed only as a directory and still consumes a raw-header count.
- After the logical tar end, bounded draining continues through gzip EOF so gzip truncation/CRC failures cannot be skipped merely because tar encountered its terminator. Trailing content is not extracted or interpreted as geometry. The report's `allListedMembersValidated` applies to listed members, not a physical mesh-completeness claim.
- There is no extraction API or extraction command. Receipt flags keep extraction and comparison false. This review does not authorize loading the mesh, pose alignment, point-cloud comparison or geometry processing.

## Corrections incorporated before approval

The author added the immutable metadata hash check, raw-header count, extension-body cap, complete sparse rejection and full final-URL check following review. Final source was re-inspected; no archive acquisition or synthetic guard test was performed by this reviewer.

Keep the acquisition receipt, actual archive SHA-256, inventory outcome and any failure evidence separate from this pre-execution review. A successful file transfer is not proof that the reference mesh is complete, aligned to iPhone data or suitable as independent collision truth.
