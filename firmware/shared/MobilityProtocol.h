#pragma once
#include <stdint.h>
#include <stddef.h>

namespace mobility {
constexpr char SERVICE[] = "594A0001-B5A3-4F7D-8F16-A962EAF724A0";
constexpr char TELEMETRY[] = "594A0002-B5A3-4F7D-8F16-A962EAF724A0";
constexpr char COMMAND[] = "594A0003-B5A3-4F7D-8F16-A962EAF724A0";
constexpr char MEASUREMENTS[] = "594A0004-B5A3-4F7D-8F16-A962EAF724A0";
constexpr uint16_t UNKNOWN = 65535;
enum Flag : uint8_t { Fault = 1, Drop = 2, Obstacle = 4, Overhead = 8, Calibrated = 16, GroundRise = 32 };
enum Role : uint8_t { Belt = 1, Wrist = 2 };
inline bool measurementFragment(Role role, uint8_t sensor, uint8_t sequence, uint32_t timeMS,
                                const uint16_t* ranges, uint8_t count, uint8_t part, uint8_t out[20]) {
    if ((count != 1 && count != 16) || part >= (count + 4) / 5) return false;
    out[0] = 2; out[1] = role; out[2] = sensor; out[3] = part;
    for (int b = 0; b < 4; ++b) out[4+b] = (timeMS >> (b*8)) & 255;
    out[8] = sequence; out[9] = count;
    for (int i = 0; i < 5; ++i) {
        const int index = part * 5 + i;
        const uint16_t value = index < count ? ranges[index] : UNKNOWN;
        out[10+i*2] = value & 255; out[11+i*2] = value >> 8;
    }
    return true;
}
struct Packet {
    Role role = Belt;
    uint8_t flags = Fault, sequence = 0;
    uint16_t range[8] = {UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN};
    void encode(uint8_t out[20]) const {
        out[0] = 1; out[1] = role; out[2] = flags; out[3] = sequence;
        for (int i = 0; i < 8; ++i) { out[4+i*2] = range[i] & 255; out[5+i*2] = range[i] >> 8; }
    }
};
struct Command {
    uint8_t operation = 0, sector = 0, intensity = 0;
    uint16_t durationMS = 0;
    static bool decode(const uint8_t* data, size_t length, Command& result) {
        if (length != 6 || data[0] != 1 || data[5] != 0 || data[1] < 1 || data[1] > 3) return false;
        if (data[1] == 1 && (data[2] > 7 || data[4] == 0 || data[4] > 50)) return false;
        if (data[1] == 2 && (data[2] || data[3] || data[4])) return false;
        if (data[1] == 3 && (data[2] || data[4] == 0 || data[4] > 50)) return false;
        result.operation = data[1]; result.sector = data[2]; result.intensity = data[3];
        result.durationMS = uint16_t(data[4]) * 10;
        return true;
    }
};
struct Range {
    uint16_t mm = UNKNOWN;
    uint32_t timestamp = 0;
    bool fresh(uint32_t now, uint32_t maxAgeMS = 250) const { return mm > 0 && mm != UNKNOWN && uint32_t(now - timestamp) <= maxAgeMS; }
    void update(uint16_t distance, uint32_t now) { mm = distance; timestamp = now; }
};
class TFParser {
    uint8_t bytes[9] = {}, count = 0;
public:
    bool push(uint8_t value, uint32_t now, Range& range) {
        if (count < 2 && value != 0x59) { count = 0; return false; }
        bytes[count++] = value;
        if (count != 9) return false;
        count = 0; uint8_t checksum = 0;
        for (int i = 0; i < 8; ++i) checksum += bytes[i];
        if (checksum != bytes[8]) return false;
        const uint16_t cm = uint16_t(bytes[2]) | uint16_t(bytes[3]) << 8;
        const uint16_t strength = uint16_t(bytes[4]) | uint16_t(bytes[5]) << 8;
        // A weak or out-of-range frame leaves the last good return in place; Range::fresh then
        // expires it after 250 ms, so one dark/shiny/sunlit frame does not count as a lost floor.
        if (cm < 10 || cm > 800 || strength < 100 || strength == 65535) return false;
        range.update(cm * 10, now); return true;
    }
};
class GroundMonitor {
    uint16_t baseline[2] = {}, low[2] = {UNKNOWN, UNKNOWN}, high[2] = {};
    uint32_t sums[2] = {};
    uint8_t count = 0, releaseRemaining[2] = {}, riseReleaseRemaining[2] = {};
    bool calibrating = false, calibrated = false, faulted = false, stale = false;
    uint8_t latchedHazards = 0;
    uint32_t lastSamples[2] = {UINT32_MAX, UINT32_MAX}, staleSince = 0;
    uint8_t lastFlags = 0;
public:
    /// A floor return missing longer than this means the mount may have moved: recalibrate.
    static constexpr uint32_t maxLostReturnMS = 5000;
    void beginCalibration() {
        calibrated = false; calibrating = true; faulted = false; stale = false; latchedHazards = 0; count = 0;
        lastSamples[0] = lastSamples[1] = UINT32_MAX; lastFlags = 0;
        for (int i = 0; i < 2; ++i) { sums[i] = 0; low[i] = UNKNOWN; high[i] = 0; releaseRemaining[i] = 0; riseReleaseRemaining[i] = 0; }
    }
    uint8_t update(const Range (&ranges)[2], uint32_t now) {
        if (calibrated) {
            for (int i = 0; i < 2; ++i) {
                // Evaluate each fresh channel BEFORE a different channel's fault.
                // One credible detection warns immediately. Only release is filtered.
                if (ranges[i].fresh(now) && lastSamples[i] != ranges[i].timestamp) {
                    if (ranges[i].mm > baseline[i] + 250) releaseRemaining[i] = 3;
                    else if (releaseRemaining[i]) --releaseRemaining[i];
                    if (uint32_t(ranges[i].mm) + 250 < baseline[i]) riseReleaseRemaining[i] = 3;
                    else if (riseReleaseRemaining[i]) --riseReleaseRemaining[i];
                    lastSamples[i] = ranges[i].timestamp;
                }
            }
            lastFlags = Calibrated | ((releaseRemaining[0] || releaseRemaining[1]) ? Drop : 0)
                | ((riseReleaseRemaining[0] || riseReleaseRemaining[1]) ? (Obstacle | GroundRise) : 0);
        }
        if (!ranges[0].fresh(now) || !ranges[1].fresh(now)) {
            // No floor return is never a cleared path. While calibrated, a lost return may be a
            // drop-off, so it warns as a drop and keeps the baseline briefly; the release filter
            // then needs three normal samples before the drop clears. A long loss needs a new
            // calibration because the mount may have moved.
            latchedHazards |= lastFlags & (Drop | Obstacle | GroundRise);
            if (calibrated) {
                if (!stale) { stale = true; staleSince = now; }
                for (int i = 0; i < 2; ++i) if (!ranges[i].fresh(now)) releaseRemaining[i] = 3;
                if (uint32_t(now - staleSince) <= maxLostReturnMS) {
                    lastFlags = Fault | Drop | latchedHazards;
                    return lastFlags;
                }
            }
            calibrated = false; calibrating = false; faulted = true; stale = false;
            lastFlags = Fault | latchedHazards;
            return lastFlags;
        }
        if (stale) { stale = false; latchedHazards = 0; }
        if (faulted) return Fault | latchedHazards;
        if (calibrating) {
            // Calibration consumes complete pairs; runtime drop evidence is independent per sensor.
            if (lastSamples[0] == ranges[0].timestamp || lastSamples[1] == ranges[1].timestamp) return lastFlags;
            lastSamples[0] = ranges[0].timestamp; lastSamples[1] = ranges[1].timestamp;
            for (int i = 0; i < 2; ++i) {
                const auto d = ranges[i].mm;
                if (d < 300 || d > 2500) { beginCalibration(); return Fault; }
                if (d < low[i]) low[i] = d;
                if (d > high[i]) high[i] = d;
                if (high[i] - low[i] > 50) { beginCalibration(); return 0; }
                sums[i] += d;
            }
            if (++count >= 20) {
                for (int i = 0; i < 2; ++i) baseline[i] = sums[i] / count;
                calibrated = true; calibrating = false;
            }
        }
        if (!calibrated) return 0;
        const uint8_t flags = Calibrated | ((releaseRemaining[0] || releaseRemaining[1]) ? Drop : 0)
            | ((riseReleaseRemaining[0] || riseReleaseRemaining[1]) ? (Obstacle | GroundRise) : 0);
        lastFlags = flags; return flags;
    }
};

struct AlertPulse {
    bool active; uint8_t sector, intensity; uint16_t durationMS;
    AlertPulse(bool active = false, uint8_t sector = 0, uint8_t intensity = 0, uint16_t durationMS = 0)
        : active(active), sector(sector), intensity(intensity), durationMS(durationMS) {}
};
/// Local decisions are independent of BLE/LLM. Missing coverage blocks navigation commands.
class BeltAlertPolicy {
    bool emitted = false;
    uint8_t previousState = 0;
    uint32_t lastAlert = 0;
public:
    AlertPulse update(uint8_t flags, const uint16_t (&ranges)[8], const Command* command, uint32_t now) {
        const uint8_t hazard = flags & Drop ? Drop : flags & Overhead ? Overhead : flags & Obstacle ? Obstacle : 0;
        const bool unavailable = (flags & Fault) || !(flags & Calibrated);
        const uint8_t state = hazard ? hazard : unavailable ? Fault : 0;
        if (state) {
            const uint32_t interval = hazard ? 500 : 1000;
            if (!emitted || state != previousState || uint32_t(now - lastAlert) >= interval) {
                emitted = true; previousState = state; lastAlert = now;
                uint8_t sector = 0;
                if (hazard == Obstacle && !(flags & GroundRise)) {
                    for (int i = 1; i < 8; ++i) if (ranges[i] < ranges[sector]) sector = i;
                }
                return {true, sector, uint8_t(hazard ? 240 : 160), uint16_t(hazard ? 250 : 100)};
            }
            return {}; // Even between local warnings, phone commands cannot replace them.
        }
        emitted = false; previousState = 0;
        if (command && (command->operation == 1 || command->operation == 3))
            return {true, command->sector, command->intensity, command->durationMS};
        return {};
    }
};
}
