# Family room mapping

The current build can capture a room with Apple's RoomPlan, generate a 2D overview, retain the USDZ 3D model, edit landmark labels in Arabic/English, attach a private reference photo and optionally suggest a room type on-device. These additions passed portable geometry tests and Swift syntax parsing only; real scans and iOS UI behavior still require a Mac/iPhone build.

## Parent or relative workflow

1. Use a supported LiDAR iPhone. Start the live camera, then open Places and enter a room name, such as “غرفة الجلوس”.
2. Select Start room scan. The app speaks RoomPlan instructions about camera speed, lighting, texture and camera-to-wall distance. Instructions are rate-limited. Phone hazard monitoring is paused during RoomPlan scanning; begin with an adult helper in a familiar, controlled space. A separate belt's local alerts do not establish complete scanning safety.
3. Point the camera around the room gradually, including walls, doors and furniture. Finish scan and wait for processing. A saved scan does not prove the entire room was captured.
4. Open Room map, labels & photo. Inspect the 2D drawing and the accessible list of detected doors, openings and furniture. Correct names such as “باب المطبخ” / “Kitchen door”. Low-confidence detections are displayed as such. The diagram uses simplified projected rectangles, including for walls; it is not an exact architectural survey.
5. Choose the room type yourself, or request a suggestion. The model sees a furniture inventory, never changes the geometry and never creates a walking route. The parent confirms the proposed type. If the device model or requested language is unsupported, manual selection remains available.
6. Optionally choose a reference photo. It is resized, saved locally without the original photo metadata, and deleted with the room. It is for family review/manual labels in this version. Automatic photo-based landmark recognition and linking photo features to map coordinates are not implemented.
7. Export the SVG floor-plan drawing, labelled JSON or USDZ model when needed. Exports reveal the room layout; retain them privately unless intentionally shared. An exported room is not yet a complete cross-phone localization/navigation package.

## Walking through an area like a vacuum

A person can carry the LiDAR phone around the area while its camera and position tracking run continuously. In Places > Walk-through mapping progress, the live preview shows the phone's travelled trail in yellow and measured floor cells in blue. Blank space remains unknown. The trail itself never fills in floor measurements. VoiceOver users can read the counts and repeat the current mapping status.

With the native RTAB-Map build, enable Build private 3D map before starting the camera to record the full 3D database. Keep the session running between rooms. Lost tracking, large position jumps or long frame gaps clear the coordinate-dependent progress preview. Stopping saves the native database; the preview itself is temporary and is not restored from that database. The normal build provides the preview but does not save a full RTAB-Map database. RoomPlan scanning is a separate mode and pauses this preview.

This does not calculate a completion percentage, identify every unseen corner or guide the mapper to unexplored areas. A walked path does not establish that nearby floor, glass, stairs or overhead space were observed. Have an adult survey and review the map before a supervised trial. See [keep-out areas](KEEP_OUT_AREAS.md) for parent-authored route restrictions; they currently belong to the separate Routes map.

## What is still needed for a whole home

Scanning individual rooms is different from a connected home map. Rooms must have consistent coordinate transforms, doorway connections must be confirmed, traversable areas and changes in floor level must be established, and the phone must reliably localize within that saved map. The current authored Routes graph is separate from room scans. Doors are detected geometric features, not a claim that they are open or accessible.

A future accessible setup mode should allow a blind adult to review scan coverage, repeat prompts, label known landmarks by voice, and request help with uncertain geometry. Do not present the current prompts as validated independent scanning for children or blind adults in unfamiliar spaces. Test wording and movement with an orientation-and-mobility specialist.

The foundational technology is [Apple RoomPlan](https://developer.apple.com/augmented-reality/roomplan/), which already uses camera/LiDAR for room geometry and furniture categories. [Apple's multi-room guidance](https://developer.apple.com/documentation/roomplan/scanning-the-rooms-of-a-single-structure) is the next native integration reference. [markckim/RoomPlan](https://github.com/markckim/RoomPlan) demonstrates label/object handling; no code was copied from that demo because a reuse license was not established. The small projection and accessible feature-list adapter here uses the documented RoomPlan API directly.
