# Community maps, orientation, and optional GitHub storage

Design, 2026-10-08. This is a core product workstream, not a replacement for private local storage.

Implementation continuation: public release download, bounded JSON place packages, offline import/cache/preview, revision selection and reviewed export are now prepared source. See [implementation, source provenance and tomorrow's checks](COMMUNITY_IMPLEMENTATION_HANDOFF.md). This does not yet implement asset/anchor exchange, vicinity discovery, publishing, authenticated reviews, private backup or cross-device localization. No new tests were run; no repository or account was created.

## How maps add orientation and context

A new room can be disorienting even when image captioning is excellent. A cupboard may hide the doorway, or the doorway may be outside the camera view. The app must use a downloaded or previously scanned map plus a valid current pose to relate the person to connected exits. It should not require them to repeatedly point a camera around an unfamiliar room to discover a door already represented in the map.

The first acceptance scenario is a mapped room with an occluded exit. After establishing location and facing direction, the app explains the room's orientation and a route to that exit, with live observations checking changes. If location is lost, it says what is known and offers a concrete supported recovery action. A saved map alone does not establish the current position.

Imported packages need a cross-device localisation strategy. ARWorldMap, RTAB-Map databases, visual reference anchors, surveyed entry landmarks or optional installed beacons have different compatibility constraints. A general mesh file or GPS point is insufficient to assert indoor pose. Test entering with a different phone and on another day. A map's ability to display or answer layout questions can be useful even before live guidance is available, and must be labelled separately.

## Two complementary storage paths

1. **Private personal memory:** iPhone database and files, with optional user-selected backup. A GitHub repository can hold an encrypted versioned backup or intentionally selected readable notes. The app owns backup/restore and key handling; GitHub supplies storage. AI-assisted cleanup proposes changes with provenance and preserves the user's corrections. No implicit training or full-history sharing.
2. **Community place library:** contributor-authored room/building maps, stores, restaurants, doors, lifts, routes and reference descriptions. Public places can be openly distributed under an explicit contributor-selected data license; private homes can be shared only with selected people.

Support both. Do not demand a GitHub account to use a local map or download a public package. Contributors can connect an existing account or submit through a managed community service. Personal-account signup remains a user action. Creating a repository after authorisation is a separate API operation. No repository/account is created by this planning work.

## Contribution and download journey

1. A community member, helper or venue owner captures/imports a place and labels entrances, doors, shops, floors and useful landmarks.
2. The author reviews geometry, connectivity, localisation anchors, coverage gaps and public/private scope. Face references, personal biographies, outing history and private conversations are excluded from community packages by construction.
3. A validator checks the package format, units, coordinate frames, IDs, floor connections, supported assets, file sizes and checksums. This is **format validation**, not an on-site verification claim.
4. A reviewer records what they actually checked, when, on which revision and device/setup: geometry, landmark labels, localisation, route accessibility, or field walkthrough.
5. A release exposes a downloadable package, revision, change notes, license, coverage and review records. Larger meshes/photos use release assets or an appropriate artifact store rather than frequent Git commits.
6. Another user finds the venue by name or vicinity, hears its coverage/review status and size, downloads it, and can preview it before arrival.
7. On arrival the app establishes a supported map alignment. Once aligned, it can explain location/orientation and guide to mapped destinations that need not be currently visible.
8. Users report changes and leave usefulness ratings; maintainers publish corrected revisions. A bad release can be withdrawn. Downloaded versions remain explicit; do not silently swap geometry during an active route.

The intended benefit is that a useful scan and verification effort can serve many people. Recipients should not need to repeat the original survey just to benefit from the map.

## Package contract (proposed)

Use established geometry conventions where possible: IMDF/GeoJSON for semantic indoor features, USDZ or another supported mesh format for measured surfaces, and a versioned supplemental manifest for localisation/route/verification metadata. The current `tools/import-imdf.mjs` imports point landmarks only; it is not a complete IMDF building importer.

Required manifest concepts:

- Stable venue/package ID, revision, schema version, source revision(s), dates, author and license/attribution.
- Units, coordinate conventions, origin, floor IDs and transformations, supported localisation methods and compatible device/runtime capabilities.
- Entrances/exits, connected doors/passages, stairs/lifts with traversal/accessibility metadata, destination names and Arabic/English labels.
- Geometry, observed coverage, unknown areas, last-survey date, restricted/private areas, and authored keep-out zones.
- Localisation anchors with enough capture/setup guidance to initialise the pose without assuming the entrance is visible from everywhere.
- Referenced assets with hashes, sizes and formats; distinguish measured geometry from AI-generated appearance or summaries.
- Version-specific verification claims: who, what scope, method, date, limitations and supporting evidence.

The device validates an allowlisted format, path containment, sizes and hashes before import. Reject path traversal, zip bombs, executable content and externally loaded scripts. Checksums detect corruption; publisher identity/signature trust needs a separate design. Do not invent custom cryptography.

## Ratings and verification

Show community stars for usefulness and written reviews, plus separate badges for format checks, on-site review and successful localisation trials. GitHub stars are repository-level popularity, not per-room verification. Our catalog needs its own revision-linked reviews/attestations even if GitHub hosts the files.

Examples of useful review statements: "door labels checked on this revision", "entry alignment tested with these devices", "lift access reviewed on this date", or "food-court stores may have changed". Do not give a timeless global "safe" badge based on a star count. Live obstacles and temporary closures still update the current outing.

## Reuse and implementation boundary

- [GitHub Releases](https://docs.github.com/en/rest/releases/releases): versioned downloadable artifacts, public retrieval and authenticated publishing. GitHub login is optional for recipients of public content.
- [MapLibre Native](https://github.com/maplibre/maplibre-native): potential map rendering; not localisation or community moderation.
- [RTAB-Map](https://github.com/introlab/rtabmap): current saved-map foundation; cross-phone localisation must be proven.
- [NavCog](https://github.com/hulop/NavCogIOSv3): indoor orientation/preview reference with beacon/model requirements; not a drop-in beacon-free solution.
- [OpenIndoorMaps](https://github.com/openindoormaps/openindoormaps): pre-alpha viewer reference, not selected as a complete engine.

GitHub provides hosting/versioning/review primitives. Discovery, accessible ratings, scoped verification, contributor identity, abuse reports and device-compatible map import remain product work. Keep the package and catalog transport independent so community hosting can expand beyond one provider.
