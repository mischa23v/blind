#include "../shared/MobilityProtocol.h"
#include <cmath>
#include <cstdio>
#include <initializer_list>
using namespace mobility;
// An idealized static geometry sensitivity experiment, not physical sensor validation.
int main() {
    puts("direction,step_cm,pitch_degrees,baseline_mm,measured_mm,expected_flag,observed_flags,recognized");
    for (int direction : {-1, 1}) for (int cm : {4, 8, 10, 12, 18, 25, 40}) for (int angle : {30, 45, 60}) {
        const double sine = std::sin(angle * 3.141592653589793 / 180);
        const auto baseline = uint16_t(std::lround(1000 / sine));
        const auto measured = uint16_t(std::lround((1000 - direction * cm * 10) / sine));
        GroundMonitor monitor; Range ranges[2]; monitor.beginCalibration();
        for (uint32_t i = 0; i < 20; ++i) {
            ranges[0].update(baseline, i*10); ranges[1].update(baseline, i*10);
            monitor.update(ranges, i*10);
        }
        ranges[0].update(measured, 200); // second channel remains flat and fresh
        const auto flags = monitor.update(ranges, 200);
        const auto expected = direction == -1 ? Drop : Obstacle;
        printf("%s,%d,%d,%u,%u,%u,%u,%d\n", direction == -1 ? "down" : "up", cm, angle,
            baseline, measured, expected, flags, (flags & expected) != 0);
    }
}
