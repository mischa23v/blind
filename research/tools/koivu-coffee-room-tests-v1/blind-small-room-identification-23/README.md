# Koivu adjoining-room identification

## Observed room and doors

- **High-confidence visual match:** the gray-carpeted adjoining room labeled **VARPU**, containing yellow tables/chairs and a flower picture.
- **Entry and return:** the open wooden/glass doorway between the red-carpeted Koivu main room and gray-carpeted VARPU.
- **Separate door:** a closed solid gray door near exit signage. Its far side and destination are not observed; this evidence does not establish an outdoor route.

## Visually checked source photographs

| Frame | Zero-based pose index | Observation |
|---|---:|---|
| `frame_00131` | 130 | Outside red-carpeted main room looking through wooden/glass doorway labeled VARPU into gray-carpeted adjoining room. |
| `frame_00140` | 139 | Close view of wooden/glass VARPU door leaf and gray floor beyond. |
| `frame_00144` | 143 | Within gray room: exit sign at left, wall, portable display. |
| `frame_00145` | 144 | Within gray room: exit sign at left, wall, portable display. |
| `frame_00155` | 147 | Closed solid gray door with silver handle and evacuation diagram; gray carpet in front. No view beyond. |
| `frame_00175` | 160 | Gray room interior with yellow table/chairs and flower picture. |
| `frame_00194` | 178 | View from gray room toward open wooden/glass doorway and red main room; threshold visible. |
| `frame_00195` | 179 | View from gray room toward red main room; wooden threshold and gray foreground clearly visible. |

All eight original RGB hashes and corresponding unchanged depth-PNG hashes were checked against existing inventories. Exact local source paths and per-file hashes are recorded only in `IDENTIFICATION_EVIDENCE.json`; no originals are duplicated here.

## Frozen candidate objectives

Coordinates below are camera-position **game XZ** associations, not body centers or camera-height-as-floor targets. The same outside objective is retained for return.

| Objective | Source frame | Original game XZ (m) | Corrected game XZ (m) |
|---|---|---|---|
| outside_start_and_same_return | `frame_00131` | (1.395819, 3.659609) | (1.396305, 3.659885) |
| inside_room | `frame_00175` | (4.559319, 0.317467) | (4.559725, 0.317696) |

## Photo/depth threshold association

Frame `frame_00195` has unchanged full-resolution 738 × 994 depth, uint16 millimetres. Original intrinsics, pixel centers, camera-to-phone pose and saved map leveling provide these associations:

| Pixel UV | Surface selection | Original game XYZ (m) | Corrected game XYZ (m) |
|---|---|---|---|
| (340, 875) | threshold_interior_sample_a | (2.325847, -0.002443, 2.331969) | (2.325847, -0.003275, 2.331968) |
| (645, 914) | threshold_interior_sample_b | (2.020146, 0.010009, 1.612481) | (2.020149, 0.009410, 1.612483) |
| (490, 894) | threshold_middle_sample | (2.169837, 0.003914, 1.966528) | (2.169838, 0.003200, 1.966529) |
| (470, 945) | gray_room_foreground_floor | (2.362309, 0.000868, 1.928409) | (2.362309, 0.000099, 1.928409) |
| (450, 780) | red_main_room_floor | (1.708584, -0.007432, 2.324979) | (1.708581, -0.008061, 2.324977) |

The two threshold samples are manually selected **interior points on the wooden strip**, not jamb endpoints. Their extended line can identify semantic entry/return sides; it is not a measured doorway width. Maximum numeric reprojection residual: 0.000032 pixels.

## Limits and source identity

- Actual RGB/depth observes the doorway and interior, permitting a candidate simulation test. The phone mask contains supported walk cells alongside unresolved, blocked and high-unknown cells. This identification is not a route-success or physical-clearance result.
- Fifteen unposed archive extras occur during this room visit; none is used for geometric association. They are listed explicitly in the evidence manifest.
- No FARO/reference fields were read or used. Map metadata access was restricted to `R`, `t`, `lo` and `res`; map flags came from the phone-only split-0.7 mask.
- No source image, pose, map or depth file was altered. No remote state was changed.

Pinned source hashes:

| Source role | SHA256 |
|---|---|
| Original phone poses | `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3` |
| Corrected phone poses | `f1373e025aa4cdd7c6b89b786b1e315ce7b68a5817d2655353331ffe13334621` |
| Original map metadata | `a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d` |
| Corrected map metadata | `ac63b5219a61094d754b6303d40b7f9dc0905a2abe446b6070bab94458c592d7` |
| Corrected phone-only split-0.7 mask | `41f26bb3bd7d364982978b8d9b3cfe7ab64e49a67de66c100f58a795e65af011` |

Evidence manifest SHA256: `4396f4712c5d16fa0ffb5900fe77f0f71a0d958e9eae75a4c97e914a183bc148`.
