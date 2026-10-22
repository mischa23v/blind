#include "../shared/MobilityProtocol.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
using namespace mobility;
int main() {
    Packet packet; packet.flags = 18; packet.sequence = 255;
    const uint16_t ranges[] = {250, 1000, 65535, 65535, 2000, 65535, 400, 65535};
    memcpy(packet.range, ranges, sizeof(ranges));
    uint8_t bytes[20]; packet.encode(bytes);
    const uint8_t golden[] = {1,1,18,255,250,0,232,3,255,255,255,255,208,7,255,255,144,1,255,255};
    assert(memcmp(bytes, golden, 20) == 0);
    const uint16_t single = 1000;
    assert(measurementFragment(Wrist, 0, 7, 0x01020304, &single, 1, 0, bytes));
    const uint8_t rawGolden[] = {2,2,0,0,4,3,2,1,7,1,232,3,255,255,255,255,255,255,255,255};
    assert(memcmp(bytes, rawGolden, 20) == 0);
    assert(!measurementFragment(Wrist, 0, 7, 0, &single, 1, 1, bytes));
    Command command; uint8_t request[] = {1,1,7,170,50,0};
    assert(Command::decode(request, 6, command) && command.durationMS == 500);
    request[2] = 8; assert(!Command::decode(request, 6, command));
    request[2] = 0; request[4] = 0; assert(!Command::decode(request, 6, command));
    assert(!Command::decode(request, 5, command));
    Range sample; TFParser parser;
    uint8_t frame[] = {0x59,0x59,100,0,200,0,0,0,0};
    for (int i = 0; i < 8; ++i) frame[8] += frame[i];
    for (auto b : frame) parser.push(b, 10, sample);
    assert(sample.mm == 1000 && sample.fresh(200) && !sample.fresh(261));
    frame[8] ^= 1;
    for (auto b : frame) parser.push(b, 100, sample);
    assert(sample.timestamp == 10);
    Range down[2]; GroundMonitor monitor;
    down[0].update(1000, 0); down[1].update(1050, 0);
    assert(monitor.update(down, 0) == 0);
    monitor.beginCalibration();
    for (int i = 0; i < 20; ++i) {
        down[0].update(1000, i*50); down[1].update(1050, i*50);
        const auto flags = monitor.update(down, i*50);
        assert((flags & Calibrated) == (i == 19 ? Calibrated : 0));
    }
    down[0].update(1400, 1000); down[1].update(1050, 1000);
    assert(monitor.update(down, 1000) & Drop);
    assert(monitor.update(down, 1010) & Drop); // duplicate cannot clear the warning
    down[0].update(1400, 1050); down[1].update(1050, 1050);
    assert(monitor.update(down, 1050) & Drop);
    down[0].update(1400, 1100); down[1].update(1050, 1100);
    assert(monitor.update(down, 1100) & Drop);
    assert(monitor.update(down, 1500) == (Fault | Drop)); // loss of readings cannot clear a known drop
    // A brief loss keeps the baseline but cannot clear the drop until three normal samples.
    down[0].update(1000, 1550); down[1].update(1050, 1550);
    assert(monitor.update(down, 1550) == (Calibrated | Drop));
    sample.update(1000, UINT32_MAX - 20); assert(sample.fresh(20));
    puts("Firmware protocol, UART parser, calibration, duplicate/stale samples, and timer wrap passed.");
}
