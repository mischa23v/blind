# Historical first-pair diagnostic, recovered narrative only

**Not a fresh evaluation of reconstructed code.** Original photos, source snapshots and detailed JSON are missing after workspace loss. The following observations were reported before the loss and remain available in conversation, not as independently reverified artifacts.

For two visually different-serial Saudi 100-front photographs, the original prototype accepted tightly framed B as reference and wider-margined A as query: SIFT 201 unique inliers, ORB 87 and AKAZE 71. Reversing the reference direction abstained: SIFT 45, ORB 61 and AKAZE 39 inliers, with full-image boundary/spread failures. A front reference versus a low-resolution back query also abstained (ratio matches 1/0/0).

This was one pair and one side, not nine independent examples or an eight-way benchmark. Wider reference white margins projected outside the tight query; thresholds were not loosened. The reference direction was subsequently selected during development, not as an untouched held-out choice. Assistant review was not human validation or authenticity verification.

The original software suite reportedly passed 103 tests across matcher/comparison/preparation files. Those original bytes and logs are unavailable; only the new `FRESH_TEST_LOG.txt` applies to this reconstruction.
