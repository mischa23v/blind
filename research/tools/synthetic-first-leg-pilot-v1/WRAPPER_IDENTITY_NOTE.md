# Archive identity versus readable publication summaries

The three uploaded archive blobs and original MANIFEST.json remain unchanged. Their original publication-wrapper payloads are preserved durably here:

- ORIGINAL_ARCHIVE_WRAPPERS/README.md
- ORIGINAL_ARCHIVE_WRAPPERS/CURRENT_CHECKPOINT_PREFIX.md

These snapshots match the original archive manifest hashes. The root README.md and CURRENT_CHECKPOINT_PREFIX.md were subsequently edited only for human-readable spacing and phrasing; measured values and evidence claims were not changed. They are current publication summaries **outside the original archive identity**.

The current memory emitter still reads the original root wrapper paths. It will intentionally fail its hash check against these newly readable summaries. To reproduce the old archives, use the preserved original wrapper payloads at those original paths in an isolated staging workspace, or explicitly teach a separate rebuild reader to read these pinned snapshots. Do not modify the old manifest, silently substitute new prose or claim that unchanged-path regeneration currently succeeds.

PACKAGE_CHECK.json records the successful integrity/rebuild checks before this readability-only separation. The original source experiment files and all measured run evidence remain unchanged.
