# Open3D CPU dependency proposal — no installation yet

The installed pip 26.2.2 vendored **resolvelib 1.2.1** resolved the declared candidate set for this Python 3.12.14 / Linux x86_64 environment: **74 packages, 46 reused installed distributions, 28 missing wheels including Open3D**. Packaging 26.3 evaluates the actual interpreter tags, Python constraints and active environment markers. No Torch, CUDA, replacement NumPy or source build is selected. This is a compatible pinned proposal, not a claim that every pin is the latest release or that imports have already passed.

`ACQUISITION_PROPOSAL.json` supplies exact official artifact URLs, versions, SHA-256, compressed and declared expanded bytes, requirements and installed reuse identities. `DEPENDENCY_CLOSURE.json` adds per-wheel ZIP member inventories, platform markers, requirements and installed METADATA hashes. `missing-wheel-pins.txt` and `installed-constraints.txt` preserve the two groups separately.

## Verified metadata footprint

| Payload | Compressed bytes | Declared expanded bytes |
|---|---:|---:|
| Open3D CPU 0.19.0 | 99,643,248 | 279,050,116 |
| Other 27 missing wheels | 21,757,092 | 89,714,005 |
| Total | **121,400,340** | **368,764,121** |

The 3,138 ZIP members declare 490,164,461 bytes combined archives + expanded payload. Rounding each expanded member to a 4 KiB allocation unit gives 376,303,616 bytes for payload files, not including directory/inode overhead or installer-added metadata. These are archive metadata measurements, **not full artifact hash verification or actual installed disk usage**. Full-wheel hashes must be checked after authorized acquisition; safe extraction must reject unexpected names/types/symlinks, size overruns and central-directory inconsistencies.

Recorded successful metadata response bodies total **1,406,414 bytes**, below the 5 MiB metadata limit. A preliminary official Dash JSON connectivity probe read 80 bytes from a response declaring 12,201 bytes; it is outside the ledger. Interrupted pending requests and HTTP headers are not a wire-level traffic measurement. The saved ledger covers every completed metadata body used in resolution/inventory, with URL/range/status/length/hash. No full wheel was fetched. Only official PyPI JSON, PEP 658 metadata and bounded official wheel ZIP-tail/central-directory ranges were read. No import shim or altered Open3D package is proposed.

## Resource decision and safe phase separation

- Missing wheels consume **121,400,340 bytes**, leaving ample room within a 200 MiB total transfer allowance for the separately reviewed 3,772,513-byte official sample, plus metadata. Sample licensing and expanded size are separate pending checks; not certified by this closure.
- Final wheel archives plus declared installed payload: **490,164,461 bytes** (~467.46 MiB), before filesystem/installer overhead and results.
- Conservative simultaneous archive + two complete expanded payload copies for `pip --target` staging: **858,928,582 logical bytes**. Two 4 KiB-rounded payload copies plus archives: **874,007,572 bytes**, leaving ~69.7 MB under the 900 MiB added-disk cap for metadata and modest installer/filesystem overhead. This is a planning bound, not a promise about pip's temporary behavior.
- Install **before** downloading/extracting sample data or producing results. Put pip temporary files under the same bounded workspace, use the already proposed `--no-index --no-deps --no-compile --target`, and measure the entire added tree while retaining 768 MiB free. Abort rather than silently enlarge caps. After pip staging has actually been removed, remeasure free space and account separately for sample and outputs.
- Reuse the exact installed numerical/interpreter dependencies recorded here. Do not perform a dependency-solving install that upgrades the host. An isolated target can still import host packages, so version/METADATA identity and actual import provenance must be checked before/after; this is not a hermetic environment.
- A normal isolated `import open3d` + CPU backend/version check remains mandatory after approval. Package metadata satisfaction is not proof that all runtime shared-library dependencies or APIs work. Dash + Plotly stay present; disabling the web visualizer does not legitimately remove those imports.

## Sources and remaining gates

Official [Open3D CPU 0.19.0 metadata](https://pypi.org/pypi/open3d-cpu/0.19.0/json), [PyPI JSON API](https://docs.pypi.org/api/json/) and [PEP 658](https://peps.python.org/pep-0658/). Every exact package endpoint and immutable wheel URL is retained in the JSON evidence. The four security-facing packages queried at current releases resolved to Flask 3.1.3, Werkzeug 3.1.9, requests 2.34.2 and urllib3 2.8.0. All selected release JSON advisory lists were empty when checked; this is not a comprehensive vulnerability assessment.

The resolver deliberately uses a declared compatible candidate set for other missing distributions rather than unbounded index exploration. PEP 658 requirement expressions were normalized with `packaging.Requirement` and matched against release JSON; formatting-only quote differences do not change the dependency graph. Existing distribution dependency metadata was also traversed and checked. Default extras only; no optional notebook/testing/ML extras were requested.

No installation, full artifact verification, Open3D/native import, sample execution, TSDF integration or navigation evaluation occurred in this stage. The 768 MiB reserve, 900 MiB added-disk cap and 200 MiB transfer cap remain execution guards for a separately authorized installer, not permissions granted by this proposal.
