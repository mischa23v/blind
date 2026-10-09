# Research and reuse decisions — 2026-10-02

| Project | Relevance | Use in this workspace |
| --- | --- | --- |
| [RTAB-Map](https://github.com/introlab/rtabmap) | Existing phone camera/depth mapping, persistent 3D database | Pinned native iOS adapter and preparation script. Apple SDK build still pending. |
| [Microsoft Soundscape](https://github.com/microsoft/soundscape) and [Soundscape Community](https://github.com/soundscape-community/soundscape) | Spatial audio, landmarks and user-controlled exploration | Research reference; no source port claimed. MIT repositories; services/dependencies must be evaluated separately. |
| [CMU CaBot navigation](https://github.com/CMU-cabot/cabot-navigation) | Assistive robot navigation, multi-floor maps, user interaction and ROS navigation integration | Architecture reference; not embedded into the phone app. Repository includes MIT and Apache licensing details to retain if porting. |
| [Clew](https://github.com/occamLab/Clew) | AR-based indoor path recording and retracing | Concept reference. Our current-session retracing was independently implemented; license was not established for copying its code. |
| [Recast/Detour](https://github.com/recastnavigation/recastnavigation) | Game geometry to navmesh, route queries and crowd navigation | Upstream tests compiled and run at `9f4ce64458dfae86e1239c525ddc219c4e9e06f1`: 32 cases passed, one skipped upstream, 5,000 assertions passed. Not integrated into app. Zlib license. |
| [Nav2](https://github.com/ros-navigation/navigation2) | Robot localization/navigation separation, costmaps and planning | Architecture reference; full ROS stack tests not run. |
| [SLAM Toolbox](https://github.com/SteveMacenski/slam_toolbox) | Persistent 2D lidar mapping | Useful when a real planar lidar is present; current belt's sparse ranges are not a full planar scan. Not integrated. |
| [EGO-Planner](https://github.com/ZJU-FAST-Lab/ego-planner) | Drone local planning | Research only. Free-space drone paths do not establish floor support or human accessibility. |

The user's robot vacuum/game analogy is appropriate for separation of mapping, localization, clearance and planning. Reusing a mapper does not supply all four automatically. Mapping geometry also needs semantic labels—cashier, restroom, exits—and a calibrated transform linking live sensors to the saved venue. Unknown space must not be filled in by a model.

RNIB guidance emphasizes asking how the person prefers to be guided, speaking directly, and locating hazards concretely, including whether known steps go up or down. See [RNIB](https://www.rnib.org.uk/living-with-sight-loss/supporting-others/guiding-a-blind-or-partially-sighted-person/) and [Perkins orientation and mobility](https://www.perkins.org/resource/orientation-mobility/). These sources inform the prompts, selectable detail levels and short landmark cues; they are not evidence that this prototype is ready for independent travel.

Bluetooth carries belt/wrist measurements and control. Compressed image transfer is technically possible, as illustrated by [Nordic's iOS image-transfer demo](https://github.com/NordicPlayground/iOS-Image-Transfer-Demo), but not implemented here. For an external camera, use Bluetooth for control and a local Wi-Fi link for image/video transport; this can operate without internet. The phone's own camera requires neither transport. The [ESP32-S3](https://www.espressif.com/en/products/socs/esp32-s3) has Wi-Fi and Bluetooth LE, but that fact alone does not supply camera hardware, firmware, synchronization or the iOS receiver.
