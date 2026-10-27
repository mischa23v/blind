// Local diagnostic-only ABI adapter. Upstream Detour sources are unchanged.
#include "DetourCommon.h"
#include <cmath>
extern "C" int diagnostic_segment(const float* p, const float* a, const float* b,
                                   const float* camera, double* out) {
    float direction[3], offset[3];
    dtVsub(direction, b, a); dtVsub(offset, p, a);
    const float squared = dtVdot2D(direction, direction);
    if (!std::isfinite(squared) || squared < 0.000001f) return 0;
    const float length = std::sqrt(squared);
    float clamped;
    out[0] = dtDistancePtSegSqr2D(p, a, b, clamped);
    out[1] = clamped;
    out[2] = dtVdot2D(offset, direction) / squared;
    out[3] = dtVperp2D(direction, offset) / length;
    out[4] = length;
    const float cameraSquared = dtVdot2D(camera, camera);
    const float fullCameraSquared = dtVdot(camera, camera);
    if (fullCameraSquared <= 0 || cameraSquared / fullCameraSquared < 0.000001f) {
        out[5] = NAN;
    } else {
        const double pi = std::acos(-1.0);
        double angle = std::atan2(double(dtVperp2D(direction, camera)), double(dtVdot2D(direction, camera)));
        if (angle >= pi) angle -= 2 * pi;
        out[5] = angle;
    }
    return 1;
}
