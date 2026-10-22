# Recovery record, 2026-10-22

Status: **explicit reconstruction; exact recovery was not possible**.

The original prototype source, private inputs/results and environment were lost. Retained source excerpts, algorithm parameters, preparation contracts and historical summaries guided reconstruction. Geometry, validation, preparation and tests were rewritten where original bytes were missing. New machine-readable outputs say `reconstructed_not_original`; no claim of original file hash equality or unchanged real-photo behavior is made.

The old checksum-manifest digest was `39f3b8f80fa398bc3f57ae537325be27643566df14026718455ac2499b12ee37`. That is a historical identifier, not verification of these new files. The original 103-test suite and detailed real-image candidate outputs are unavailable.

Dependencies were restored from official PyPI: OpenCV 4.14.0 (`opencv-python-headless==4.14.0.94`), NumPy 2.3.5 and Pillow 12.3.0. Use the repository-local setup in README. No training, classifier weights or private-photo downloads occurred during recovery.

Fresh reconstructed-source tests: 55/55 passed. See `FRESH_TEST_LOG.txt` and current `PORTABLE_SHA256SUMS`. Abstract-feature tests exercise actual OpenCV SIFT/ORB/AKAZE computation and synthetic schema/geometry/accounting, not Saudi banknote accuracy. An empty reference bank returns unknown and `monetary_answer: null`. The historical photo cases have not been repeated.

Intentional differences include recovery markers, dependency-unavailable fail-closed handling, empty-bank operation without cv2, reconstructed geometry/coverage validation and a smaller new suite. Original per-image evidence cannot be regenerated from prose. The historical reports distinguish retained observations from missing evidence. Native runtime parity must be established separately; the portable development manifest is not the native version-2 pack contract.
