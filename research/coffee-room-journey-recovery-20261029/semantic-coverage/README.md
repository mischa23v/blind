# Original Coffee views: real door candidate found, crossing not covered by sample

**Executed bounded public-source acquisition and image inspection; no geometry/routing change.** This is a supplementary evidence stage after the initial recovery report, not a successful sitting/walking/exit trial.

## Predeclared sampling and source verification

Before downloading or viewing any source RGB, selected exactly24 uniformly temporal indices `round(i*(388-1)/23)` from the original pose-file order. Full filenames/indices are in `SELECTION.json`; frozen SHA256 `c1795f5d7042404c62b19aa3c61a0cd2d14f25c25029086bf9428d2712b55e9d`. No favorable frame replacement. Added only the inventoried original small mesh texture and MTL. No depth member extracted in this stage.

Fresh official API check: [MuSHRoom iPhone Basic Data record10230733](https://zenodo.org/api/records/10230733), file `coffee_room_iphone.tar.gz`,183,080,957bytes, MD5`cb467b3ad18d8f2c83dbf97a486d378b`. Full received archive matched that MD5 and saved source SHA256`591672a1c4afa50e5109fc78ff08d8f608d05756a9181cfdd7cef38a57a1623d`. Data licenseCC-BY4.0, attributionXuqian Ren et al. Official file metadata and exact acquisition receipts are included; raw photos/archive/texture are local only.

Transfer183,080,957bytes; selected retained files6,735,981bytes; acquisition+selected extraction141.5601seconds; peak processRSS22,488KiB. Limits:200,000,000 counted archive-transfer bytes,600second external timeout,512MiB address-space cap,500MB archive+selected retained limit,768MiB starting disk reserve. Archive-member extraction used exact allowlist, rejected absolute/parent paths and nonregular/link types, enforced per-member≤5MB and counted output bytes. No archive code executed. The metadata request is separately small; no package/model/dependency download. Full archive retained locally within cap, enabling later specifically authorized selective extraction without another183MB transfer.

`contact_sheet.py` produced two labeled twelve-view sheets from the **original predetermined RGB images only** (display thumbnails, no invented/filled content). Both sheets were visually inspected; original full frames00357 and00391 were additionally opened for the door check. These are descriptive visual findings, not metric annotations.

## What the pixels support

- Orange/red sofas, blue-green sofa, oval tables, large TV/monitor, whiteboard and stacked chairs confirm the intended lounge/meeting-room scene. The dataset name alone still does not establish commercial/public-cafe semantics.
- A gray door beneath green exit signage appears in selected00068,00102,00341,00357,00391. Original00357 shows the complete closed door beside the folding partition and orange sofa/table grouping;00391 confirms the closed door and adjacent orange sofa/window-blind grouping.
- Visible stretches of floor occur between furniture in several views (for example00085,00223,00357). This is **not** proof of a full-body clear aisle or support everywhere along a route.
- No open-door state, threshold crossing, beyond-door corridor/room or actual sit→stand body event was observed in these24 selected frames. This is a sample-limited negative finding, **not proof the other364 posed frames lack it**. Camera pose is not body/feet location and apparent camera height alone does not establish sitting.
- No door width, seat coordinate, room dimensions, step count or motion direction is derived from RGB. No photographed door is assigned to authored topology endpoint0 or any existing query.

## Concrete next use

The gray door is now a real **semantic candidate**, so follow-on source-registration work has a target rather than an invented exit. Pair the already-fixed frame set (or a separately predeclared diagnostic subset) with its exact original depth and pose/intrinsics; validate Coffee-specific mesh-to-camera registration and reserve independent reprojection views before assigning source triangles/metric anchors. The original archive is already retained; additional member extraction must remain within the approved retention scope. Do not choose transform/geometry by which produces a successful route.

Continue the independently prepared original-mesh72-query baseline in parallel after root admission. A seat-to-near-door simulated prefix needs explicit target association, posture/body calibration and support/collision evidence. A genuine doorway→exit→return test additionally needs observed open-door/far-side geometry or another documented source capture; stop at unsupported coverage rather than fabricate it or call arrival at the closed door an exit.

## Reproduction and publication boundaries

`acquire.py` expects local `SELECTION.json` and full official API response `OFFICIAL_METADATA.json`; obtain that official response and verify the file entry against included `OFFICIAL_FILE_METADATA.json` before a fresh authorized acquisition. The acquisition script refuses an existing archive and preserves failed attempts rather than silently overwriting. Do not reacquire merely to reproduce the contact sheets when verified local source already exists. Scripts/results are source/evidence, not execution authorization. No original photos, contact sheets or texture pixels are proposed for Git publication.

### Legitimate closed-door interaction case (proposed, not executed)

After measured target association and a supported approach are established, treat the observed closed door as the intended boundary state—not as a reconstruction failure. The proposed journey owner should stop before it, preserve the exit goal, communicate that the door is closed, and request appropriate assistance/opening without inventing reach/handle commands. Remain stopped while waiting. A spoken claim that someone opened it is not clearance: require fresh door-state, pose/body, threshold support, obstacle and far-side coverage evidence before replanning through. If that evidence remains absent, keep the task pending/unsupported rather than announce exit success. Revalidate the same boundary on return. This interaction is a meaningful test even when the recorded sample cannot supply an opening sequence; any synthetic state-change fixture must be labeled synthetic and cannot count as an observed Coffee crossing.
