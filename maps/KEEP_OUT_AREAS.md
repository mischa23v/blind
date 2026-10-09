# Keep-out areas and vacuum boundary strips

Keep-out areas are saved route restrictions in the indoor map. They work offline and are enforced by geometry code, not by the language model. They are separate from observed obstacles: an empty-looking maintenance area may still be forbidden.

In Routes > Manage keep-out areas, a parent or teacher can select a surveyed landmark and save a square centred on it. The distance control measures from the centre to each side, so 1 metre creates a 2-by-2-metre square. Review the surveyed coordinates before saving. This is not a camera-based marking tool. Removing a restriction requires a confirmation. Any change cancels the previous route and alignment and is saved with the map for export/import.

For custom locations, include rectangles in the route JSON. All coordinates use the same metre axes as the map; `level` must exactly match an existing node's floor. Multiple rectangles can cover a larger shape. Example:

```json
"keepOutZones": [
  {
    "id": "stairwell",
    "name": "Stairwell",
    "nameArabic": "بيت الدرج",
    "level": "0",
    "minX": 4,
    "maxX": 6,
    "minZ": 2,
    "maxZ": 4
  }
]
```

This is fictional geometry, not a placement recommendation. The planner expands each rectangle by the configured body radius plus margin (default total 0.45 m), rejects touching or crossing route segments, and rejects a start or destination inside that expanded area. It only chooses alternative authored connections; it never invents a detour. Include sufficient surveyed separation for the particular hazard and position uncertainty; the default body margin is not a validated stopping distance.

On a request to hear the next landmark, the app also checks the line from the manually aligned current position to that landmark. If it intersects a restriction, it withholds the direction and explains why. This is **not** a continuous proximity alarm. Incorrect alignment or drift can still place the user elsewhere than estimated. Automatic saved-map localization, bounded uncertainty and continuous boundary warnings still need integration and real device validation.

Some vacuum boundary strips are magnetic: [eufy's RoboVac 30C MAX documentation](https://www.eufy.com/products/t2130) describes dedicated dual Hall sensors. Other products use active barriers, such as [iRobot's Virtual Wall](https://www.irobot.com/en_US/dual-mode-virtual-wall-barrier/4636429.html?cgid=us). They are not interchangeable universal markers.

The current phone, belt and wrist implementation has no magnetic-strip detection. A future cane-mounted detector would require a compatible sensor near the floor, measured detection range/orientation, firmware and protocol integration, local alerts during phone disconnection, and supervised validation. A belt-mounted detector or phone compass must not be assumed to detect floor tape. Tape and software boundaries do not physically stop a child; hazardous edges still need appropriate physical protection and supervision.
