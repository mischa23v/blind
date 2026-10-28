# Explicit public-floor inventory schema repair

Native run 40773062534 at 49a9878 passed the producing Apple fixture but the prior strict inventory reader rejected four newly emitted fields. The original failure is preserved in NATIVE_FAILURE_RECEIPT.json. This patch changes only the bounded evidence reader and its tests, not geometry, routes, source allowlists or authority.

New fields are typed and bounded; original source polygons must match the SHA-admitted public fixture after Float32 conversion. Generated buffers are capped at 4096 decoded bytes per row with exact base64/count agreement. Ignored-face receipts require known public feature IDs, unique bounded raw indices and the same exact duplicate-pair mask in local/world triples. These are diagnostics, not a proof that removing geometry is safe. Unknown fields remain rejected; historical inventories remain accepted without the new fields.

Validation:82 reader tests (normal and Python -O),17 same-export tests pass. The actual unsupported inventory payload was not retained by the old exporter; no actual-payload replay is claimed. Native rerun is required for new inventory/asset acceptance.
