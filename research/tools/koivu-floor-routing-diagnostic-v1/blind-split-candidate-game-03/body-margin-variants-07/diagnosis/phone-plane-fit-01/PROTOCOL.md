# Phone-only all-frame released plane-fit comparison

All294 original pose-matched processed depth PNGs. Exact original pipeline native-block sampling,+0.5pixel OpenGL projection, Float32 phone points and existing supplied R/t. No reference data. No raw value, pose or current walk mask changes.

Candidates per frame: absolute global-plane height<=0.12m (existing source floor-fit band), actual phone-point camera range<=4m. Fit all candidate points with already-installed Open3D0.19.0 PointCloud.segment_plane, distance_threshold0.01m,ransac_n3,num_iterations1000,probability0.99999999; reset seed0 per frame. No downsampling or new install.

A fit is reported valid only with>=100inliers,>=50%candidate inliers, normal within5degrees of original up, horizontal inlier convex-hull area>=0.25m² and minor principal-axis span>=0.10m. These are estimation gates, not walkability or support. The1cm estimation tolerance is NOT a toy-clearance rule: retain all original points and every residual, including inliers. Authored1cm toy/verticalwall/hole fixtures verify no point removal or implicit support filling.

Report all294 frames, original affected frames62–64, fixed regularly spaced pose-index controls[0,41,83,125,167,209,251,293], all57 fixed western columns including32walkable controls. No fit-only output is adopted as a map. Plane validity/coverage failures remain reported. No plane is extended to claim unseen support. All output comparisons are diagnostic; missing native confidence/tracking remain unavailable.

Limits:300CPU/450wallseconds,1GiB sampled/waited RSS,16MiB outputs,768MiBfree reserve. Serialize with other geometry tasks. Reverify all input/source and loaded module hashes before/after; preserve failure if any.

Primary implementation documentation: https://www.open3d.org/docs/release/tutorial/geometry/pointcloud.html#plane-segmentation . Official example uses1cm/3points/1000iterations; extra validity gates are explicitly our predeclared diagnostic adapter, not an upstream safety guarantee.
