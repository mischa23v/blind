# Recorder access without a saved room

A Rooms-tab diagnostic entry now calls the existing NavigationModel factory outside the saved-room loop. It does not start the camera or recording, request permission, create a bridge, select a map or assert clearance. The link is disabled while scanning. Existing saved-room entry remains.

Before this change, a saved room was required solely to reach the recorder screen. Source review confirmed the app retains the shared camera across intra-app navigation. This change removes that unnecessary UI prerequisite; native navigation and VoiceOver remain untested.

The first camera-container source check failed because its exact whole-file baseline correctly noticed this new unrelated section. The check now reverses only the exact checked-in entry block before comparing the original baseline, and separately checks that the entry is outside the saved-room list and cannot start capture. No runtime audit or native test was suppressed. Removing that exact block restores Dashboard SHA256 3833318d7d3e6b1cffcf092bc613cdd42c6566cbf31346396aef48c686de3193.
