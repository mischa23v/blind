# Current-source body-profile regression

Verified GitHub Actions run [40571313226](https://github.com/mischa23v/blind/actions/runs/40571313226), commit `0babd78d14eafe8b818e3b15be1ebe84aaf04caf`. Artifact `12764309072` SHA-256 `c5cad70fa01f51ebfcdb6576e8a3330491dd99ddac8d2050f89eba84a001e2da`; ZIP size and CRC verified.

Actual untruncated XCTest log has 55 distinct passing test cases: 9 BodyProfileStore, 11 BodyCollisionWarning, 19 BodyProfile, 16 Detector. All 27 compiled-input hashes match the current local reviewed sources; SpatialMapIO is the `.userInitiated` candidate, SHA-256 `f044ff2aa869cf0ea3ab8a2ff8d4c6ba7fc7fcd9915fe1fed59109219a3c548c`. The producer verified the compiled copy and used no historical overlay.

Apple Swift 6.4 on arm64 macOS 27. These are extracted-source host fixtures, not full app regression, actual sensor accuracy or device safety proof.
