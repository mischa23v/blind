# Corrected mapping engines: frozen real-data first-hit comparison

**Result: no across-the-board accuracy upgrade.** Fresh projective B exactly reproduces the historical stock Voxblox summary (its mesh is byte-identical). C0 differs only slightly and in mixed directions. C1 gains coverage and some pooled/near-reference tails, but worsens median/tight-band agreement and longer-reference-range tails. Do not promote C1 as a blanket improvement or select a weighted winner from the mean.

All 265 original training frames; same 29 excluded heldout views; original poses/K; 1,335,885 integer-pixel stride 4 rays; immutable author-registered FARO first-hit cache. No GT mapping inputs, post-result fit, deletion, smoothing, threshold changes or mesh repairs. B/C0/C1 scored fresh once each, sequentially, after explicit root recovery admission and independent source/output review.

## Recovery and configuration

The original three-arm mapping batch remains failed/quarantined after its 300 CPU-second cap. B/C0 had completed all 265 frames and were independently admitted per arm under a separate root amendment. C1 was rerun from an empty map, all 265 frames, with unchanged inputs/kernel/configuration; no TSDF resume. The original failure receipt was not rewritten. All fresh scorers passed their own 60 CPU/90 wall-second/1 CPU/1 GiB RSS/1 GiB-output caps.

- **B:** Voxfield fork projective, common D1 exact-zero ray fix and N2 provider. Native byte-identical to historical stock Voxblox on this recording; the synthetic bug repair creates no measured geometry gain here. Historical stock is not an isolated matched D1 control.
- **C0:** non-projective, normal availability disabled. B→C0 changes native weighting/math, not only normals.
- **C1:** non-projective, normal availability enabled. C0→C1 includes gradient/grazing/correction behavior; N2 normal validity is numerical, not calibrated confidence.
- **Supplied-pose Open3D:** original baseline with original per-frame K/poses, 4 cm voxel/20 cm truncation. Earlier estimated-pose Open3D A/B remain substantially worse in the separately preserved `coordination/FOUR_MAPPER_SAME_PROTOCOL_COMPARISON.md`; they are not these new B/C0/C1 labels.

## Availability — every scheduled ray retained

| Metric | Supplied-pose Open3D | B | C0 | C1 |
|---|---:|---:|---:|---:|
| Scheduled rays | 1,335,885 | 1,335,885 | 1,335,885 | 1,335,885 |
| Paired positive hits | 1,187,988 | 1,189,925 | 1,189,959 | 1,190,482 |
| Reference-only / mapper miss | 6,556 | 4,619 | 4,585 | 4,062 |
| Mapper-only / reference miss | 138,401 | 138,669 | 138,738 | 138,895 |
| Neither | 2,940 | 2,672 | 2,603 | 2,446 |

## All reference ranges: paired axial-depth errors

| Metric | Supplied-pose Open3D | B | C0 | C1 |
|---|---:|---:|---:|---:|
| Scheduled stratum denominator | 1,335,885 | 1,335,885 | 1,335,885 | 1,335,885 |
| Paired positive-hit denominator | 1,187,988 | 1,189,925 | 1,189,959 | 1,190,482 |
| Median absolute (cm) | 3.404 | 3.179 | 3.182 | 3.308 |
| Mean absolute (cm) | 18.650 | 16.949 | 16.953 | 16.920 |
| p90 absolute (cm) | 33.772 | 30.191 | 30.145 | 29.565 |
| p95 absolute (cm) | 113.830 | 103.294 | 103.363 | 101.312 |
| p99 absolute (cm) | 311.695 | 279.356 | 279.944 | 279.322 |
| Maximum absolute (cm) | 627.755 | 598.866 | 599.675 | 599.766 |
| Mean signed (cm) | -0.032 | 7.741 | 7.800 | 6.850 |
| Signed p05 (cm) | -26.252 | -10.840 | -10.729 | -12.960 |
| Signed median (cm) | 0.703 | 0.896 | 0.929 | 0.696 |
| Signed p95 (cm) | 40.418 | 72.841 | 72.916 | 67.687 |

Error = mapper minus reference camera-axis depth. Earlier/later are numerical discrepancies, not obstacle labels.

| Band | Mapper | Earlier | Within | Later | Within / paired |
|---|---|---:|---:|---:|---:|
| ±2 cm | Supplied-pose Open3D | 292,192 | 438,201 | 457,595 | 36.886% |
| ±2 cm | B | 306,592 | 421,133 | 462,200 | 35.392% |
| ±2 cm | C0 | 303,803 | 420,679 | 465,477 | 35.352% |
| ±2 cm | C1 | 332,869 | 414,419 | 443,194 | 34.811% |
| ±5 cm | Supplied-pose Open3D | 179,152 | 741,384 | 267,452 | 62.407% |
| ±5 cm | B | 143,823 | 786,534 | 259,568 | 66.099% |
| ±5 cm | C0 | 142,124 | 786,983 | 260,852 | 66.135% |
| ±5 cm | C1 | 163,372 | 774,407 | 252,703 | 65.050% |
| ±10 cm | Supplied-pose Open3D | 102,975 | 948,693 | 136,320 | 79.857% |
| ±10 cm | B | 64,358 | 979,572 | 145,995 | 82.322% |
| ±10 cm | C0 | 63,726 | 978,728 | 147,505 | 82.249% |
| ±10 cm | C1 | 75,756 | 974,794 | 139,932 | 81.882% |

## Reference below 4 m: paired axial-depth errors

| Metric | Supplied-pose Open3D | B | C0 | C1 |
|---|---:|---:|---:|---:|
| Scheduled stratum denominator | 1,042,402 | 1,042,402 | 1,042,402 | 1,042,402 |
| Paired positive-hit denominator | 1,036,454 | 1,038,373 | 1,038,410 | 1,038,843 |
| Median absolute (cm) | 3.394 | 3.161 | 3.166 | 3.290 |
| Mean absolute (cm) | 15.722 | 16.588 | 16.591 | 16.482 |
| p90 absolute (cm) | 27.787 | 31.213 | 31.161 | 29.968 |
| p95 absolute (cm) | 90.941 | 102.290 | 102.327 | 99.760 |
| p99 absolute (cm) | 248.116 | 272.291 | 272.908 | 270.955 |
| Maximum absolute (cm) | 604.508 | 598.866 | 599.675 | 599.766 |
| Mean signed (cm) | 3.651 | 9.694 | 9.753 | 8.875 |
| Signed p05 (cm) | -16.601 | -9.600 | -9.493 | -11.320 |
| Signed median (cm) | 0.893 | 1.091 | 1.122 | 0.901 |
| Signed p95 (cm) | 43.712 | 84.948 | 84.909 | 79.963 |

Error = mapper minus reference camera-axis depth. Earlier/later are numerical discrepancies, not obstacle labels.

| Band | Mapper | Earlier | Within | Later | Within / paired |
|---|---|---:|---:|---:|---:|
| ±2 cm | Supplied-pose Open3D | 236,923 | 382,611 | 416,920 | 36.915% |
| ±2 cm | B | 247,851 | 369,994 | 420,528 | 35.632% |
| ±2 cm | C0 | 245,590 | 369,358 | 423,462 | 35.570% |
| ±2 cm | C1 | 269,097 | 365,122 | 404,624 | 35.147% |
| ±5 cm | Supplied-pose Open3D | 140,956 | 651,982 | 243,516 | 62.905% |
| ±5 cm | B | 116,133 | 687,126 | 235,114 | 66.173% |
| ±5 cm | C0 | 114,802 | 687,230 | 236,378 | 66.181% |
| ±5 cm | C1 | 132,591 | 676,139 | 230,113 | 65.086% |
| ±10 cm | Supplied-pose Open3D | 76,002 | 838,149 | 122,303 | 80.867% |
| ±10 cm | B | 49,511 | 857,634 | 131,228 | 82.594% |
| ±10 cm | C0 | 48,958 | 856,845 | 132,607 | 82.515% |
| ±10 cm | C1 | 59,144 | 853,937 | 125,762 | 82.201% |

## Reference at least 4 m: paired axial-depth errors

| Metric | Supplied-pose Open3D | B | C0 | C1 |
|---|---:|---:|---:|---:|
| Scheduled stratum denominator | 152,142 | 152,142 | 152,142 | 152,142 |
| Paired positive-hit denominator | 151,534 | 151,552 | 151,549 | 151,639 |
| Median absolute (cm) | 3.489 | 3.307 | 3.290 | 3.445 |
| Mean absolute (cm) | 38.674 | 19.421 | 19.432 | 19.917 |
| p90 absolute (cm) | 142.580 | 25.611 | 25.671 | 26.926 |
| p95 absolute (cm) | 286.542 | 114.742 | 115.335 | 120.483 |
| p99 absolute (cm) | 478.044 | 357.039 | 356.962 | 372.737 |
| Maximum absolute (cm) | 627.755 | 565.220 | 565.306 | 565.178 |
| Mean signed (cm) | -25.218 | -5.639 | -5.586 | -7.029 |
| Signed p05 (cm) | -271.235 | -28.987 | -28.801 | -34.242 |
| Signed median (cm) | -0.743 | -1.107 | -1.070 | -1.355 |
| Signed p95 (cm) | 20.789 | 22.586 | 22.813 | 20.551 |

Error = mapper minus reference camera-axis depth. Earlier/later are numerical discrepancies, not obstacle labels.

| Band | Mapper | Earlier | Within | Later | Within / paired |
|---|---|---:|---:|---:|---:|
| ±2 cm | Supplied-pose Open3D | 55,269 | 55,590 | 40,675 | 36.685% |
| ±2 cm | B | 58,741 | 51,139 | 41,672 | 33.744% |
| ±2 cm | C0 | 58,213 | 51,321 | 42,015 | 33.864% |
| ±2 cm | C1 | 63,772 | 49,297 | 38,570 | 32.509% |
| ±5 cm | Supplied-pose Open3D | 38,196 | 89,402 | 23,936 | 58.998% |
| ±5 cm | B | 27,690 | 99,408 | 24,454 | 65.593% |
| ±5 cm | C0 | 27,322 | 99,753 | 24,474 | 65.822% |
| ±5 cm | C1 | 30,781 | 98,268 | 22,590 | 64.804% |
| ±10 cm | Supplied-pose Open3D | 26,973 | 110,544 | 14,017 | 72.950% |
| ±10 cm | B | 14,847 | 121,938 | 14,767 | 80.460% |
| ±10 cm | C0 | 14,768 | 121,883 | 14,898 | 80.425% |
| ±10 cm | C1 | 16,612 | 120,857 | 14,170 | 79.700% |

## Original reference-depth strata — pooled

| Reference-depth bin | Mapper | Reference-hit scheduled | Paired | Reference-only | Median abs cm | p95 abs cm | p99 abs cm | ±5 cm count / paired |
|---|---|---:|---:|---:|---:|---:|---:|---|
| positive_below015 | Supplied-pose Open3D | 0 | 0 | 0 | — | — | — | 0 / 0 (—) |
| positive_below015 | B | 0 | 0 | 0 | — | — | — | 0 / 0 (—) |
| positive_below015 | C0 | 0 | 0 | 0 | — | — | — | 0 / 0 (—) |
| positive_below015 | C1 | 0 | 0 | 0 | — | — | — | 0 / 0 (—) |
| 015_to_below1 | Supplied-pose Open3D | 67,305 | 67,064 | 241 | 4.198 | 83.434 | 330.801 | 38,653 / 67,064 (57.636%) |
| 015_to_below1 | B | 67,305 | 67,303 | 2 | 5.212 | 100.616 | 227.285 | 32,472 / 67,303 (48.247%) |
| 015_to_below1 | C0 | 67,305 | 67,303 | 2 | 5.169 | 100.108 | 227.544 | 32,547 / 67,303 (48.359%) |
| 015_to_below1 | C1 | 67,305 | 67,305 | 0 | 5.248 | 98.465 | 208.153 | 31,909 / 67,305 (47.410%) |
| 1_to_below2 | Supplied-pose Open3D | 354,355 | 350,876 | 3,479 | 3.397 | 86.490 | 185.578 | 209,666 / 350,876 (59.755%) |
| 1_to_below2 | B | 354,355 | 351,904 | 2,451 | 3.333 | 151.685 | 318.334 | 223,272 / 351,904 (63.447%) |
| 1_to_below2 | C0 | 354,355 | 351,928 | 2,427 | 3.342 | 151.770 | 318.434 | 223,242 / 351,928 (63.434%) |
| 1_to_below2 | C1 | 354,355 | 352,142 | 2,213 | 3.532 | 150.162 | 318.151 | 217,600 / 352,142 (61.793%) |
| 2_to_below3 | Supplied-pose Open3D | 395,955 | 394,148 | 1,807 | 3.314 | 85.610 | 190.313 | 263,150 / 394,148 (66.764%) |
| 2_to_below3 | B | 395,955 | 394,787 | 1,168 | 2.980 | 68.965 | 200.531 | 280,646 / 394,787 (71.088%) |
| 2_to_below3 | C0 | 395,955 | 394,788 | 1,167 | 3.000 | 68.593 | 201.578 | 280,826 / 394,788 (71.133%) |
| 2_to_below3 | C1 | 395,955 | 394,942 | 1,013 | 3.054 | 66.433 | 197.173 | 277,579 / 394,942 (70.283%) |
| 3_to_below4 | Supplied-pose Open3D | 224,787 | 224,366 | 421 | 3.266 | 140.778 | 324.763 | 140,513 / 224,366 (62.627%) |
| 3_to_below4 | B | 224,787 | 224,379 | 408 | 2.931 | 56.195 | 312.128 | 150,736 / 224,379 (67.179%) |
| 3_to_below4 | C0 | 224,787 | 224,391 | 396 | 2.925 | 56.154 | 312.630 | 150,615 / 224,391 (67.122%) |
| 3_to_below4 | C1 | 224,787 | 224,454 | 333 | 3.001 | 55.849 | 312.070 | 149,051 / 224,454 (66.406%) |
| 4_to_below5 | Supplied-pose Open3D | 74,105 | 73,731 | 374 | 3.571 | 237.565 | 394.398 | 43,430 / 73,731 (58.903%) |
| 4_to_below5 | B | 74,105 | 73,775 | 330 | 3.667 | 43.735 | 205.233 | 47,573 / 73,775 (64.484%) |
| 4_to_below5 | C0 | 74,105 | 73,776 | 329 | 3.640 | 44.153 | 205.451 | 47,780 / 73,776 (64.764%) |
| 4_to_below5 | C1 | 74,105 | 73,831 | 274 | 3.802 | 45.671 | 205.511 | 46,834 / 73,831 (63.434%) |
| 5_and_above | Supplied-pose Open3D | 78,037 | 77,803 | 234 | 3.391 | 315.128 | 500.008 | 45,972 / 77,803 (59.088%) |
| 5_and_above | B | 78,037 | 77,777 | 260 | 2.953 | 175.025 | 510.845 | 51,835 / 77,777 (66.646%) |
| 5_and_above | C0 | 78,037 | 77,773 | 264 | 2.934 | 175.628 | 510.842 | 51,973 / 77,773 (66.827%) |
| 5_and_above | C1 | 78,037 | 77,808 | 229 | 3.076 | 183.433 | 511.045 | 51,434 / 77,808 (66.104%) |

Reference-missing rays have no reference-depth bin: mapper-only and neither remain in the full scheduled-ray availability table, not forced into a depth stratum.

## Per-view coverage and tails — all reference ranges

Each row has 46,065 scheduled rays. Complete per-view signed statistics, all three bands, every original depth stratum and secondary processed-sensor consistency remain in each unchanged `COMMON_GEOMETRY_RESULTS.json`. These rows do not replace those full summaries.

| View | Mapper | Paired | Ref-only | Map-only | Neither | Median abs cm | p95 abs cm | p99 abs cm | ±5 cm count / paired |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| frame_00011 | Supplied-pose Open3D | 44,589 | 18 | 1,458 | 0 | 3.277 | 35.575 | 54.135 | 27,073 / 44,589 (60.717%) |
| frame_00011 | B | 44,580 | 27 | 1,458 | 0 | 4.739 | 40.150 | 56.687 | 23,734 / 44,580 (53.239%) |
| frame_00011 | C0 | 44,580 | 27 | 1,458 | 0 | 4.667 | 40.054 | 56.370 | 24,113 / 44,580 (54.089%) |
| frame_00011 | C1 | 44,585 | 22 | 1,458 | 0 | 4.697 | 39.998 | 56.153 | 24,111 / 44,585 (54.079%) |
| frame_00021 | Supplied-pose Open3D | 40,841 | 30 | 4,895 | 299 | 3.622 | 34.316 | 116.261 | 25,439 / 40,841 (62.288%) |
| frame_00021 | B | 40,850 | 21 | 5,005 | 189 | 4.176 | 37.075 | 130.203 | 23,193 / 40,850 (56.776%) |
| frame_00021 | C0 | 40,850 | 21 | 5,005 | 189 | 4.266 | 38.409 | 130.381 | 22,983 / 40,850 (56.262%) |
| frame_00021 | C1 | 40,856 | 15 | 5,026 | 168 | 4.109 | 34.202 | 128.599 | 22,958 / 40,856 (56.192%) |
| frame_00031 | Supplied-pose Open3D | 40,930 | 2 | 5,039 | 94 | 4.692 | 11.456 | 67.219 | 23,197 / 40,930 (56.675%) |
| frame_00031 | B | 40,932 | 0 | 5,035 | 98 | 2.555 | 10.738 | 66.954 | 35,345 / 40,932 (86.351%) |
| frame_00031 | C0 | 40,932 | 0 | 5,034 | 99 | 2.685 | 10.912 | 67.430 | 35,356 / 40,932 (86.377%) |
| frame_00031 | C1 | 40,932 | 0 | 5,051 | 82 | 2.583 | 9.997 | 66.465 | 35,458 / 40,932 (86.627%) |
| frame_00041 | Supplied-pose Open3D | 38,000 | 167 | 7,894 | 4 | 2.484 | 193.112 | 340.530 | 23,254 / 38,000 (61.195%) |
| frame_00041 | B | 38,050 | 117 | 7,864 | 34 | 2.798 | 184.273 | 313.934 | 23,019 / 38,050 (60.497%) |
| frame_00041 | C0 | 38,049 | 118 | 7,863 | 35 | 2.840 | 184.266 | 314.414 | 22,829 / 38,049 (59.999%) |
| frame_00041 | C1 | 38,073 | 94 | 7,889 | 9 | 3.187 | 180.589 | 310.684 | 22,278 / 38,073 (58.514%) |
| frame_00051 | Supplied-pose Open3D | 38,927 | 29 | 7,103 | 6 | 2.595 | 138.217 | 350.286 | 24,456 / 38,927 (62.825%) |
| frame_00051 | B | 38,927 | 29 | 7,103 | 6 | 2.462 | 122.876 | 350.660 | 26,253 / 38,927 (67.442%) |
| frame_00051 | C0 | 38,929 | 27 | 7,102 | 7 | 2.439 | 123.083 | 350.806 | 26,258 / 38,929 (67.451%) |
| frame_00051 | C1 | 38,937 | 19 | 7,105 | 4 | 2.376 | 122.730 | 338.031 | 26,059 / 38,937 (66.926%) |
| frame_00061 | Supplied-pose Open3D | 44,788 | 1,120 | 157 | 0 | 4.867 | 72.188 | 169.221 | 23,278 / 44,788 (51.974%) |
| frame_00061 | B | 45,358 | 550 | 157 | 0 | 4.868 | 154.062 | 203.353 | 22,995 / 45,358 (50.697%) |
| frame_00061 | C0 | 45,357 | 551 | 157 | 0 | 4.901 | 151.530 | 202.044 | 22,924 / 45,357 (50.541%) |
| frame_00061 | C1 | 45,372 | 536 | 157 | 0 | 4.968 | 149.925 | 211.852 | 22,783 / 45,372 (50.214%) |
| frame_00071 | Supplied-pose Open3D | 41,461 | 150 | 4,391 | 63 | 5.166 | 164.323 | 248.597 | 20,320 / 41,461 (49.010%) |
| frame_00071 | B | 41,523 | 88 | 4,369 | 85 | 5.652 | 158.867 | 247.823 | 19,798 / 41,523 (47.680%) |
| frame_00071 | C0 | 41,524 | 87 | 4,372 | 82 | 5.700 | 160.123 | 247.820 | 19,783 / 41,524 (47.642%) |
| frame_00071 | C1 | 41,526 | 85 | 4,381 | 73 | 5.773 | 149.835 | 251.086 | 19,477 / 41,526 (46.903%) |
| frame_00081 | Supplied-pose Open3D | 45,680 | 242 | 143 | 0 | 5.562 | 276.872 | 335.950 | 20,873 / 45,680 (45.694%) |
| frame_00081 | B | 45,890 | 32 | 143 | 0 | 5.143 | 230.203 | 313.559 | 22,048 / 45,890 (48.045%) |
| frame_00081 | C0 | 45,890 | 32 | 143 | 0 | 5.075 | 230.600 | 313.984 | 22,417 / 45,890 (48.849%) |
| frame_00081 | C1 | 45,888 | 34 | 143 | 0 | 5.138 | 232.640 | 314.385 | 21,958 / 45,888 (47.851%) |
| frame_00091 | Supplied-pose Open3D | 41,248 | 24 | 4,793 | 0 | 2.032 | 22.446 | 76.327 | 31,220 / 41,248 (75.689%) |
| frame_00091 | B | 41,271 | 1 | 4,791 | 2 | 1.535 | 25.146 | 69.389 | 34,030 / 41,271 (82.455%) |
| frame_00091 | C0 | 41,270 | 2 | 4,791 | 2 | 1.516 | 24.704 | 68.294 | 34,020 / 41,270 (82.433%) |
| frame_00091 | C1 | 41,271 | 1 | 4,792 | 1 | 1.409 | 22.617 | 67.712 | 33,881 / 41,271 (82.094%) |
| frame_00102 | Supplied-pose Open3D | 41,085 | 97 | 4,883 | 0 | 1.796 | 14.333 | 53.602 | 31,318 / 41,085 (76.227%) |
| frame_00102 | B | 41,174 | 8 | 4,883 | 0 | 1.935 | 15.317 | 56.337 | 32,807 / 41,174 (79.679%) |
| frame_00102 | C0 | 41,174 | 8 | 4,883 | 0 | 1.903 | 15.083 | 56.353 | 32,802 / 41,174 (79.667%) |
| frame_00102 | C1 | 41,180 | 2 | 4,883 | 0 | 1.990 | 15.352 | 54.040 | 32,832 / 41,180 (79.728%) |
| frame_00112 | Supplied-pose Open3D | 36,722 | 498 | 8,429 | 416 | 4.120 | 186.249 | 333.209 | 20,007 / 36,722 (54.482%) |
| frame_00112 | B | 36,661 | 559 | 8,571 | 274 | 3.335 | 217.785 | 338.774 | 21,452 / 36,661 (58.514%) |
| frame_00112 | C0 | 36,672 | 548 | 8,569 | 276 | 3.315 | 217.171 | 338.785 | 21,511 / 36,672 (58.658%) |
| frame_00112 | C1 | 36,730 | 490 | 8,610 | 235 | 3.549 | 215.412 | 338.740 | 21,451 / 36,730 (58.402%) |
| frame_00122 | Supplied-pose Open3D | 40,709 | 108 | 4,972 | 276 | 4.447 | 148.866 | 264.969 | 22,223 / 40,709 (54.590%) |
| frame_00122 | B | 40,724 | 93 | 4,908 | 340 | 4.377 | 163.152 | 265.874 | 22,340 / 40,724 (54.857%) |
| frame_00122 | C0 | 40,725 | 92 | 4,921 | 327 | 4.397 | 163.098 | 266.075 | 22,336 / 40,725 (54.846%) |
| frame_00122 | C1 | 40,753 | 64 | 4,928 | 320 | 4.775 | 157.678 | 263.305 | 21,480 / 40,753 (52.708%) |
| frame_00132 | Supplied-pose Open3D | 35,401 | 255 | 10,281 | 128 | 7.066 | 200.784 | 306.183 | 10,523 / 35,401 (29.725%) |
| frame_00132 | B | 35,043 | 613 | 10,262 | 147 | 5.624 | 322.830 | 340.612 | 14,962 / 35,043 (42.696%) |
| frame_00132 | C0 | 35,073 | 583 | 10,266 | 143 | 5.610 | 322.842 | 340.611 | 14,958 / 35,073 (42.648%) |
| frame_00132 | C1 | 35,151 | 505 | 10,297 | 112 | 5.603 | 322.654 | 340.605 | 15,072 / 35,151 (42.878%) |
| frame_00142 | Supplied-pose Open3D | 38,740 | 782 | 5,050 | 1,493 | 4.912 | 25.360 | 281.201 | 19,445 / 38,740 (50.194%) |
| frame_00142 | B | 38,961 | 561 | 5,538 | 1,005 | 3.784 | 22.767 | 98.135 | 20,705 / 38,961 (53.143%) |
| frame_00142 | C0 | 38,964 | 558 | 5,537 | 1,006 | 3.798 | 22.852 | 98.049 | 20,661 / 38,964 (53.026%) |
| frame_00142 | C1 | 38,966 | 556 | 5,566 | 977 | 3.835 | 22.381 | 100.629 | 20,613 / 38,966 (52.900%) |
| frame_00165 | Supplied-pose Open3D | 31,496 | 785 | 13,781 | 3 | 4.970 | 48.628 | 53.674 | 15,796 / 31,496 (50.152%) |
| frame_00165 | B | 31,719 | 562 | 13,776 | 8 | 5.593 | 47.227 | 51.139 | 14,636 / 31,719 (46.143%) |
| frame_00165 | C0 | 31,711 | 570 | 13,775 | 9 | 5.586 | 47.176 | 51.104 | 14,638 / 31,711 (46.161%) |
| frame_00165 | C1 | 31,826 | 455 | 13,782 | 2 | 5.816 | 47.241 | 51.216 | 14,248 / 31,826 (44.768%) |
| frame_00176 | Supplied-pose Open3D | 42,648 | 1,599 | 1,808 | 10 | 4.271 | 66.519 | 93.231 | 30,359 / 42,648 (71.185%) |
| frame_00176 | B | 43,338 | 909 | 1,818 | 0 | 3.979 | 71.643 | 123.373 | 32,245 / 43,338 (74.404%) |
| frame_00176 | C0 | 43,335 | 912 | 1,818 | 0 | 4.015 | 71.641 | 123.435 | 32,170 / 43,335 (74.236%) |
| frame_00176 | C1 | 43,390 | 857 | 1,818 | 0 | 4.024 | 71.437 | 122.922 | 32,081 / 43,390 (73.936%) |
| frame_00187 | Supplied-pose Open3D | 43,091 | 186 | 2,784 | 4 | 4.028 | 71.209 | 178.712 | 27,045 / 43,091 (62.763%) |
| frame_00187 | B | 43,225 | 52 | 2,788 | 0 | 3.597 | 79.097 | 164.166 | 27,748 / 43,225 (64.194%) |
| frame_00187 | C0 | 43,228 | 49 | 2,788 | 0 | 3.601 | 77.126 | 162.531 | 27,892 / 43,228 (64.523%) |
| frame_00187 | C1 | 43,249 | 28 | 2,788 | 0 | 3.870 | 78.264 | 163.129 | 26,137 / 43,249 (60.434%) |
| frame_00197 | Supplied-pose Open3D | 38,605 | 51 | 7,409 | 0 | 3.261 | 333.247 | 440.464 | 21,841 / 38,605 (56.576%) |
| frame_00197 | B | 38,626 | 30 | 7,405 | 4 | 2.700 | 302.868 | 357.555 | 23,489 / 38,626 (60.811%) |
| frame_00197 | C0 | 38,623 | 33 | 7,406 | 3 | 2.719 | 303.026 | 357.791 | 23,509 / 38,623 (60.868%) |
| frame_00197 | C1 | 38,641 | 15 | 7,406 | 3 | 2.682 | 302.932 | 357.081 | 23,624 / 38,641 (61.137%) |
| frame_00207 | Supplied-pose Open3D | 38,393 | 119 | 7,487 | 66 | 2.505 | 160.366 | 246.740 | 25,687 / 38,393 (66.905%) |
| frame_00207 | B | 38,473 | 39 | 7,318 | 235 | 2.521 | 128.800 | 188.631 | 28,323 / 38,473 (73.618%) |
| frame_00207 | C0 | 38,473 | 39 | 7,324 | 229 | 2.548 | 128.825 | 188.837 | 28,217 / 38,473 (73.342%) |
| frame_00207 | C1 | 38,474 | 38 | 7,343 | 210 | 2.572 | 135.313 | 187.923 | 28,436 / 38,474 (73.910%) |
| frame_00218 | Supplied-pose Open3D | 37,293 | 13 | 8,759 | 0 | 3.647 | 263.123 | 505.304 | 21,599 / 37,293 (57.917%) |
| frame_00218 | B | 37,273 | 33 | 8,655 | 104 | 2.460 | 84.674 | 520.437 | 25,196 / 37,273 (67.599%) |
| frame_00218 | C0 | 37,275 | 31 | 8,695 | 64 | 2.494 | 85.564 | 520.443 | 25,194 / 37,275 (67.590%) |
| frame_00218 | C1 | 37,270 | 36 | 8,605 | 154 | 2.742 | 86.240 | 520.613 | 24,548 / 37,270 (65.865%) |
| frame_00228 | Supplied-pose Open3D | 45,433 | 54 | 578 | 0 | 4.646 | 354.553 | 393.370 | 23,349 / 45,433 (51.392%) |
| frame_00228 | B | 45,482 | 5 | 578 | 0 | 2.194 | 99.037 | 168.958 | 32,652 / 45,482 (71.791%) |
| frame_00228 | C0 | 45,481 | 6 | 578 | 0 | 2.225 | 99.253 | 170.034 | 32,592 / 45,481 (71.661%) |
| frame_00228 | C1 | 45,486 | 1 | 578 | 0 | 2.406 | 97.184 | 164.800 | 31,085 / 45,486 (68.340%) |
| frame_00238 | Supplied-pose Open3D | 37,721 | 6 | 8,313 | 25 | 2.591 | 78.112 | 239.404 | 23,003 / 37,721 (60.982%) |
| frame_00238 | B | 37,636 | 91 | 8,251 | 87 | 4.191 | 46.303 | 175.883 | 22,339 / 37,636 (59.355%) |
| frame_00238 | C0 | 37,637 | 90 | 8,259 | 79 | 4.152 | 49.456 | 184.344 | 22,439 / 37,637 (59.620%) |
| frame_00238 | C1 | 37,650 | 77 | 8,286 | 52 | 4.309 | 49.285 | 192.413 | 22,308 / 37,650 (59.251%) |
| frame_00248 | Supplied-pose Open3D | 46,063 | 0 | 2 | 0 | 1.683 | 17.752 | 48.884 | 34,029 / 46,063 (73.875%) |
| frame_00248 | B | 46,063 | 0 | 2 | 0 | 3.859 | 15.168 | 43.742 | 31,658 / 46,063 (68.728%) |
| frame_00248 | C0 | 46,063 | 0 | 2 | 0 | 3.778 | 15.249 | 44.108 | 31,843 / 46,063 (69.129%) |
| frame_00248 | C1 | 46,063 | 0 | 2 | 0 | 3.928 | 15.083 | 43.017 | 30,163 / 46,063 (65.482%) |
| frame_00258 | Supplied-pose Open3D | 46,052 | 7 | 6 | 0 | 3.098 | 13.680 | 34.347 | 37,455 / 46,052 (81.332%) |
| frame_00258 | B | 46,048 | 11 | 6 | 0 | 2.475 | 12.318 | 33.638 | 39,811 / 46,048 (86.455%) |
| frame_00258 | C0 | 46,049 | 10 | 6 | 0 | 2.517 | 12.373 | 33.309 | 39,750 / 46,049 (86.321%) |
| frame_00258 | C1 | 46,054 | 5 | 6 | 0 | 2.519 | 12.487 | 33.305 | 39,682 / 46,054 (86.164%) |
| frame_00268 | Supplied-pose Open3D | 42,772 | 47 | 3,202 | 44 | 1.960 | 195.043 | 331.318 | 28,189 / 42,772 (65.905%) |
| frame_00268 | B | 42,715 | 104 | 3,213 | 33 | 2.215 | 191.326 | 324.431 | 27,370 / 42,715 (64.076%) |
| frame_00268 | C0 | 42,713 | 106 | 3,214 | 32 | 2.266 | 190.671 | 324.939 | 27,150 / 42,713 (63.564%) |
| frame_00268 | C1 | 42,736 | 83 | 3,216 | 30 | 2.892 | 186.782 | 323.894 | 26,009 / 42,736 (60.860%) |
| frame_00278 | Supplied-pose Open3D | 36,300 | 7 | 9,755 | 3 | 1.558 | 69.624 | 216.708 | 27,927 / 36,300 (76.934%) |
| frame_00278 | B | 36,307 | 0 | 9,743 | 15 | 2.132 | 74.912 | 190.754 | 28,666 / 36,307 (78.954%) |
| frame_00278 | C0 | 36,307 | 0 | 9,743 | 15 | 2.106 | 76.176 | 191.248 | 28,827 / 36,307 (79.398%) |
| frame_00278 | C1 | 36,307 | 0 | 9,750 | 8 | 2.172 | 69.599 | 189.603 | 28,382 / 36,307 (78.172%) |
| frame_00288 | Supplied-pose Open3D | 41,524 | 22 | 4,518 | 1 | 1.795 | 17.793 | 89.098 | 32,101 / 41,524 (77.307%) |
| frame_00288 | B | 41,543 | 3 | 4,518 | 1 | 1.809 | 15.972 | 72.207 | 34,750 / 41,543 (83.648%) |
| frame_00288 | C0 | 41,542 | 4 | 4,518 | 1 | 1.776 | 15.886 | 72.421 | 34,759 / 41,542 (83.672%) |
| frame_00288 | C1 | 41,543 | 3 | 4,518 | 1 | 1.523 | 16.093 | 71.441 | 34,605 / 41,543 (83.299%) |
| frame_00298 | Supplied-pose Open3D | 45,807 | 1 | 257 | 0 | 1.210 | 59.935 | 142.105 | 37,073 / 45,807 (80.933%) |
| frame_00298 | B | 45,808 | 0 | 257 | 0 | 1.546 | 52.037 | 127.685 | 39,845 / 45,808 (86.983%) |
| frame_00298 | C0 | 45,808 | 0 | 257 | 0 | 1.522 | 51.741 | 128.062 | 39,881 / 45,808 (87.061%) |
| frame_00298 | C1 | 45,808 | 0 | 257 | 0 | 1.603 | 52.822 | 130.786 | 39,107 / 45,808 (85.372%) |
| frame_00308 | Supplied-pose Open3D | 45,669 | 137 | 254 | 5 | 1.401 | 134.464 | 185.520 | 33,305 / 45,669 (72.927%) |
| frame_00308 | B | 45,725 | 81 | 254 | 5 | 1.906 | 129.181 | 177.854 | 35,125 / 45,725 (76.818%) |
| frame_00308 | C0 | 45,725 | 81 | 254 | 5 | 1.869 | 129.063 | 178.361 | 35,171 / 45,725 (76.919%) |
| frame_00308 | C1 | 45,765 | 41 | 254 | 5 | 2.101 | 126.903 | 178.863 | 33,581 / 45,765 (73.377%) |

## Score resource/integrity receipts

| Arm | Wall s | Final guard + child CPU s | Peak summed RSS MiB | Exit / stop |
|---|---:|---:|---:|---|
| B | 23.410 | 23.383 | 261.004 | 0 / none |
| C0 | 22.873 | 22.796 | 261.012 | 0 / none |
| C1 | 23.704 | 23.628 | 254.711 | 0 / none |

Input/cache/source checks matched before and after each score. All 58 original FARO/Open3D caches and the original 29 heldout processed-sensor PNGs were pinned. Monitor/prechecks/final checks are included; RSS/CPU monitoring is sampled, not a proof of zero transient overshoot.

## Interpretation and next decision

C1 versus B reduces reference-only count by 557 and increases paired hits by 557, but also adds 226 mapper-only hits. Pooled p95 improves by 1.982 cm while median worsens by 0.130 cm and the ±5 cm fraction declines by 1.050 percentage points. At reference≥4 m, p95 worsens by 5.741 cm. Below 4 m, C1 p95 remains higher than the original supplied-pose Open3D baseline (99.760 versus 90.941 cm). This is mixed evidence, not a successful accuracy-upgrade claim.

Paired-hit subsets differ: do not treat a better conditional error statistic as a better all-ray or safety outcome. Missing hits never establish clearance; one-sided hits and signed errors are not physical hazard labels. FARO was author-registered and edited/completed; registration/completion uncertainty is unbounded. The dataset and supplied poses do not test live localization. These are geometry first-hit diagnostics, not route success, hazard detection, object handling, full-body clearance, iPhone runtime or safe guidance. Any next pathing comparison must remain a separately defined and admitted evaluation.

## Exact summary inputs

- Supplied-pose Open3D: `research/open3d-same-data-benchmark-20261028/fresh-run/COMMON_GEOMETRY_RESULTS.json`, SHA256 `ed1aaf510b8c0dcfc8ba93d1a177a054299933022cc454f9122c580308075df0`.
- B: `coordination/voxfield-recovered-full265-same-protocol-score/B/COMMON_GEOMETRY_RESULTS.json`, SHA256 `772201a45725f0c5123893d5b5b48ad122853f9b3733d2516f9a0f7880c35cfe`.
- C0: `coordination/voxfield-recovered-full265-same-protocol-score/C0/COMMON_GEOMETRY_RESULTS.json`, SHA256 `be2aae0b55f6cd050c755fe5c7e8dcb9915b95939b01e1be0ced6fa3e9cf2b77`.
- C1: `coordination/voxfield-recovered-full265-same-protocol-score/C1/COMMON_GEOMETRY_RESULTS.json`, SHA256 `deeaf6622a8d2fe434ba22a2f72763a07c994eb7110e73f7affcc872709177c8`.

Fresh B complete JSON is identical to historical stock summary: `coordination/voxblox-same-protocol-score/COMMON_GEOMETRY_RESULTS.json`, SHA256 `772201a45725f0c5123893d5b5b48ad122853f9b3733d2516f9a0f7880c35cfe`. This is a fresh rerun, not a reuse-only shortcut.

Independent raw-array recount passed. `INDEPENDENT_ARRAY_RECOUNT.json` verifies original pooled scope; `INDEPENDENT_EXTENDED_ARRAY_RECOUNT.json` additionally verifies all 900 groups (3 arms × 30 per-view/pooled nodes × 10 all/reference-range/depth-bin groups), all 10 statistics, all 2/5/10 cm bands, scheduled counts and availability denominators. No new mesh/reference query was performed. Original failure/source packets remain preserved.
