#include "../shared/MobilityProtocol.h"
#include <assert.h>
#include <stdio.h>
using namespace mobility;

static void calibrate(GroundMonitor& monitor, Range (&ranges)[2], uint32_t start = 0) {
    monitor.beginCalibration();
    for (uint32_t i = 0; i < 20; ++i) {
        const uint32_t time = start + i * 10;
        ranges[0].update(1000, time); ranges[1].update(1100, time);
        const auto flags = monitor.update(ranges, time);
        assert(bool(flags & Calibrated) == (i == 19));
    }
}
static void groundFailures() {
    Range ranges[2]; GroundMonitor monitor;
    calibrate(monitor, ranges);
    // One sensor's asynchronous updates must detect a drop while the other remains fresh.
    for (uint32_t i = 0; i < 3; ++i) {
        ranges[0].update(1400, 200 + i * 10);
        const auto flags = monitor.update(ranges, 200 + i * 10);
        assert(flags & Drop); // first sample, no waiting for agreement or later samples
    }
    ranges[0].update(UNKNOWN, 230);
    assert(monitor.update(ranges, 230) == (Fault | Drop));
    // A brief loss resumes on the kept baseline, but the drop clears only after three normal samples.
    ranges[0].update(1000, 240); ranges[1].update(1100, 240);
    assert(monitor.update(ranges, 240) == (Calibrated | Drop));
    ranges[0].update(1000, 250); assert(monitor.update(ranges, 250) == (Calibrated | Drop));
    ranges[0].update(1000, 260); assert(monitor.update(ranges, 260) == Calibrated);
    // A lost floor return while calibrated warns as a possible drop-off, not just a fault.
    calibrate(monitor, ranges, 300);
    ranges[1].update(UNKNOWN, 500);
    assert(monitor.update(ranges, 500) == (Fault | Drop));
    ranges[0].update(1000, 510); ranges[1].update(1100, 510);
    assert(monitor.update(ranges, 510) == (Calibrated | Drop));
    // A loss longer than maxLostReturnMS requires a new calibration (the mount may have moved).
    calibrate(monitor, ranges, 600);
    ranges[0].update(UNKNOWN, 800);
    assert(monitor.update(ranges, 800) == (Fault | Drop));
    assert(monitor.update(ranges, 800 + GroundMonitor::maxLostReturnMS + 1) == (Fault | Drop));
    ranges[0].update(1000, 6000); ranges[1].update(1100, 6000);
    assert(monitor.update(ranges, 6000) == (Fault | Drop)); // latched, no silent recovery

    // Re-reading a normal sample cannot advance the three-sample release filter.
    calibrate(monitor, ranges, 1000);
    ranges[0].update(1400, 1200);
    for (uint32_t time = 1200; time < 1250; ++time) assert(monitor.update(ranges, time) & Drop);
    ranges[0].update(1000, 1250); ranges[1].update(1100, 1250);
    for (uint32_t time = 1250; time < 1260; ++time) assert(monitor.update(ranges, time) & Drop);
    ranges[0].update(1000, 1260); assert(monitor.update(ranges, 1260) & Drop);
    ranges[0].update(1000, 1270); assert(!(monitor.update(ranges, 1270) & Drop));
    assert(monitor.update(ranges, 1521) == (Fault | Drop)); // stale floor returns: possible drop

    // A simultaneous fault on the other sensor must not mask the first danger sample.
    for (int danger = 0; danger < 2; ++danger) {
        calibrate(monitor, ranges, 1600);
        ranges[danger].update(1500, 1800); ranges[1-danger].update(UNKNOWN, 1800);
        assert(monitor.update(ranges, 1800) == (Fault | Drop));
    }
    Range invalid; invalid.update(0, 0); assert(!invalid.fresh(0));

    // A shorter ground range is also danger: raised step / low obstacle.
    for (int raised = 0; raised < 2; ++raised) {
        calibrate(monitor, ranges, 1600);
        ranges[raised].update(600, 1800);
        assert(monitor.update(ranges, 1800) & Obstacle);
        ranges[1-raised].update(UNKNOWN, 1810);
        assert(monitor.update(ranges, 1810) == (Fault | Drop | Obstacle | GroundRise));
    }
    calibrate(monitor, ranges, 1600);
    ranges[0].update(600, 1800); ranges[1].update(1500, 1800);
    assert(monitor.update(ranges, 1800) == (Calibrated | Drop | Obstacle | GroundRise));

    // Unstable mounting cannot complete baseline calibration.
    monitor.beginCalibration();
    for (uint32_t i = 0; i < 200; ++i) {
        ranges[0].update(i % 2 ? 1300 : 1000, 2000 + i * 10);
        ranges[1].update(1100, 2000 + i * 10);
        assert(!(monitor.update(ranges, 2000 + i * 10) & Calibrated));
    }
    // Freshness and paired calibration work across the MCU millisecond rollover.
    calibrate(monitor, ranges, UINT32_MAX - 100);
    assert(monitor.update(ranges, 100) & Calibrated);
}
static void localAlerts() {
    uint16_t ranges[8] = {1500, UNKNOWN, 400, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN};
    Command command; command.operation = 1; command.sector = 7; command.intensity = 100; command.durationMS = 200;
    for (uint8_t flags = 0; flags < 64; ++flags) {
        if ((flags & GroundRise) && !(flags & Obstacle)) continue;
        BeltAlertPolicy policy;
        const bool blocked = (flags & (Fault | Drop | Obstacle | Overhead)) || !(flags & Calibrated);
        auto first = policy.update(flags, ranges, &command, 0);
        assert(first.active); // initial local warning or permitted command
        if (blocked) {
            assert(first.sector != command.sector); // local decision wins
            assert(!policy.update(flags, ranges, &command, 1).active); // command cannot fill warning interval
        } else {
            assert(first.sector == 7 && first.intensity == 100);
            assert(policy.update(flags, ranges, &command, 1).active);
        }
    }
    BeltAlertPolicy policy;
    assert(policy.update(Calibrated, ranges, nullptr, 0).active == false);
    auto lost = policy.update(Fault, ranges, &command, 1);
    assert(lost.active && lost.durationMS == 100); // no five-second delay
    assert(!policy.update(Fault, ranges, nullptr, 1000).active);
    assert(policy.update(Fault, ranges, nullptr, 1001).active);
    auto drop = policy.update(Fault | Drop, ranges, &command, 1002);
    assert(drop.active && drop.sector == 0 && drop.durationMS == 250);
    auto head = policy.update(Calibrated | Overhead | Obstacle, ranges, nullptr, 1003);
    assert(head.active && head.sector == 0);
    auto object = policy.update(Calibrated | Obstacle, ranges, nullptr, 1004);
    assert(object.active && object.sector == 2);
    auto raised = policy.update(Calibrated | Obstacle | GroundRise, ranges, nullptr, 1504);
    assert(raised.active && raised.sector == 0); // no invented body-range bearing
    BeltAlertPolicy wrapping;
    assert(wrapping.update(Drop, ranges, nullptr, UINT32_MAX - 100).active);
    assert(!wrapping.update(Drop, ranges, nullptr, 20).active);
    assert(wrapping.update(Drop, ranges, nullptr, 400).active);
}
static void parserFailures() {
    TFParser parser; Range range;
    for (uint32_t test = 0; test < 256; ++test) {
        uint8_t frame[9] = {0x59, 0x59, 100, 0, uint8_t(test), 0, 0, 0, 0};
        for (int i = 0; i < 8; ++i) frame[8] += frame[i];
        for (auto byte : frame) parser.push(byte, test, range);
        assert(test < 100 ? range.mm == UNKNOWN : range.mm == 1000);
    }
    // A later weak frame keeps the last good return, which then expires by age (debounce).
    uint8_t weak[9] = {0x59, 0x59, 100, 0, 50, 0, 0, 0, 0};
    for (int i = 0; i < 8; ++i) weak[8] += weak[i];
    for (auto byte : weak) parser.push(byte, 300, range);
    assert(range.mm == 1000 && range.timestamp == 255 && range.fresh(300) && !range.fresh(506));
    // Deterministic random command frames must never admit out-of-range haptic parameters.
    uint32_t random = 0x456789AB;
    int accepted = 0;
    for (int test = 0; test < 100000; ++test) {
        uint8_t bytes[6];
        for (auto& byte : bytes) { random = 1664525 * random + 1013904223; byte = random >> 24; }
        if (test % 2 == 0) { bytes[0] = 1; bytes[1] = bytes[1] % 3 + 1; bytes[2] %= 10; bytes[4] %= 60; bytes[5] = 0; }
        Command command;
        if (Command::decode(bytes, sizeof(bytes), command)) {
            ++accepted;
            assert(command.operation >= 1 && command.operation <= 3);
            if (command.operation != 2) assert(command.sector <= 7 && command.durationMS > 0 && command.durationMS <= 500);
        }
    }
    assert(accepted > 1000);
}
int main() {
    groundFailures(); localAlerts(); parserFailures();
    puts("Failure injection passed: asynchronous ground sensors, missing/stale returns, latched drop, unstable calibration, local alert priority, timer wrap, weak returns and 100000 command frames.");
}
