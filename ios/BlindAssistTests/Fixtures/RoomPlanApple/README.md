# Apple prescanned RoomPlan fixtures

These are **unchanged `CapturedRoom` JSON files supplied by Apple**, not authored or reshaped test scenes. They were extracted on 2026-10-28 from the download linked by Apple's [Merging multiple scans into a single structure](https://developer.apple.com/documentation/roomplan/merging-multiple-scans-into-a-single-structure) sample page:

https://developer.apple.com/tutorials/3e2b731b0ef7/MergingMultipleScansIntoASingleStructure.zip

Apple's [Scanning the rooms of a single structure](https://developer.apple.com/documentation/roomplan/scanning-the-rooms-of-a-single-structure) documentation describes the linked sample as an app that merges a collection of **prescanned rooms**. The sample page associates it with WWDC23 session 10192 and requires an iOS 17 device with LiDAR. This establishes Apple-released scan provenance, **not a particular iPhone/iPad model, acquisition date, physical measurement accuracy, or blind-app capture-session success**.

## Selected bytes

| File | Original archive member | Bytes | Surfaces / objects |
| --- | --- | ---: | --- |
| `Hallway2.capturedRoom.json` | `RoomPlanMultiscanMerging/MyHome/Hallway2/capturedRoom.json` | 27,575 | 6 walls, 6 doors, 1 floor, no objects |
| `Bedroom3.capturedRoom.json` | `RoomPlanMultiscanMerging/MyHome/Bedroom3/capturedRoom.json` | 69,516 | 4 walls, 2 doors, 1 floor, 1 window, 3 objects (bed, table, chair) |

Both are version 2, story 0. The native keys and opaque `coreModel` are retained byte-for-byte. Neither is `RoomLayout`, `CapturedRoomData`, a reconstructed mesh, or synthetic Codable-shaped JSON.

The official sample's `RoomPlanMultiscanMerging/RoomTableViewController.swift`, `loadCapturedRoom(from:)`, calls `JSONDecoder().decode(CapturedRoom.self, from: data)` on these `capturedRoom.json` members. The present research verified JSON syntax and provenance; **the Apple native decoder and blind's geometry projection still need execution in the appropriate test environment**.

The exact fixture blobs also occur at mirror revision `cc5cb5fa1cd177b626a774f4b79846bc2fb00cb0` of `gromb57/ios-wwdc23__MergingMultipleScansIntoASingleStructure`; `manifest.json` contains the immutable per-file URLs, byte counts, SHA-256 hashes, and Git blob IDs. The mirror is useful for stable references; the bytes here came from Apple's official archive, not solely from that mirror.

## License and data boundary

`APPLE-LICENSE.txt` is the unchanged `LICENSE.txt` from the official archive: copyright 2025 Apple Inc., MIT-style permission text. Retain it with copies. The older pinned mirror has the same license text with a 2023 copyright year; this handoff intentionally preserves the current official archive's 2025 notice.

Only the two JSON fixtures, license, and provenance metadata were extracted. No photographs, videos, raw RGB-D frames, world maps, or entire home bundle are included. Clear-text JSON strings are scan UUIDs and standard semantic labels/attributes, not addresses, personal names, or GPS. `coreModel` is Apple's opaque binary payload and was preserved, not reverse-engineered or claimed to be independently privacy-audited.

## Integrity

From this directory:

```sh
sha256sum Hallway2.capturedRoom.json Bedroom3.capturedRoom.json APPLE-LICENSE.txt
```

Expected SHA-256:

- Hallway2: `f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d`
- Bedroom3: `44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e`
- License: `ef80d1c2ac05c7040c0ced9d603c2c359712f90fdb3ece8da70b976981a69e89`

The downloaded official archive was 2,878,214 bytes, SHA-256 `135cf2ae9c415723f9f32c31a130b4ce9efced61b3e22f50858785a4323d66a1`. No packages, model weights, or scan dataset were installed.
