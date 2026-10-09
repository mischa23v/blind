#include <bluefruit.h>
#include <Wire.h>
#include <VL53L1X.h>
#include <Adafruit_DRV2605.h>
#include <MobilityProtocol.h>

using namespace mobility;
BLEService service(SERVICE);
BLECharacteristic telemetry(TELEMETRY), commands(COMMAND);
BLECharacteristic measurements(MEASUREMENTS);
VL53L1X ranger;
Adafruit_DRV2605 motor;
Range pointing;
Packet packet;
BeltAlertPolicy localAlerts;
bool rangeReady = false, motorReady = false;
volatile bool identifyRequested = false;
uint32_t lastTick = 0, lastPulse = 0, stopPulse = 0;
void connected(uint16_t handle) {
    if (auto* connection = Bluefruit.Connection(handle)) connection->requestPairing();
}
void notifyEncrypted(BLECharacteristic& characteristic, const uint8_t* bytes, uint16_t length) {
    characteristic.write(bytes, length);
    const uint16_t handle = Bluefruit.connHandle();
    auto* connection = Bluefruit.Connection(handle);
    if (connection && connection->secured()) characteristic.notify(handle, bytes, length);
}

void commandReceived(uint16_t, BLECharacteristic*, uint8_t* bytes, uint16_t length) {
    Command command;
    if (Command::decode(bytes, length, command) && command.operation == 3) identifyRequested = true;
    // A pointing wristband cannot represent body-relative navigation sectors.
}
void setup() {
    Wire.begin();
    ranger.setTimeout(20); rangeReady = ranger.init();
    if (rangeReady) { ranger.setDistanceMode(VL53L1X::Long); ranger.setMeasurementTimingBudget(50000); ranger.startContinuous(50); }
    motorReady = motor.begin(&Wire);
    if (motorReady) { motor.useLRA(); motor.setMode(DRV2605_MODE_REALTIME); motor.setRealtimeValue(0); }
    Bluefruit.begin(); Bluefruit.setName("Mobility Wrist");
    Bluefruit.Periph.setConnectCallback(connected);
    service.begin();
    telemetry.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
    telemetry.setPermission(SECMODE_ENC_NO_MITM, SECMODE_NO_ACCESS);
    telemetry.setFixedLen(20); telemetry.begin();
    measurements.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
    measurements.setPermission(SECMODE_ENC_NO_MITM, SECMODE_NO_ACCESS);
    measurements.setFixedLen(20); measurements.begin();
    commands.setProperties(CHR_PROPS_WRITE);
    commands.setPermission(SECMODE_NO_ACCESS, SECMODE_ENC_NO_MITM);
    commands.setFixedLen(6); commands.setWriteCallback(commandReceived); commands.begin();
    packet.role = Wrist;
    uint8_t bytes[20]; packet.encode(bytes); telemetry.write(bytes, sizeof(bytes));
    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addService(service); Bluefruit.ScanResponse.addName();
    Bluefruit.Advertising.restartOnDisconnect(true); Bluefruit.Advertising.start(0);
}
void loop() {
    const uint32_t now = millis();
    if (stopPulse && int32_t(now - stopPulse) >= 0) { if (motorReady) motor.setRealtimeValue(0); stopPulse = 0; }
    if (uint32_t(now - lastTick) < 50) { delay(1); return; }
    lastTick = now;
    if (rangeReady && ranger.dataReady()) {
        const auto mm = ranger.read(false);
        pointing.update(ranger.ranging_data.range_status == VL53L1X::RangeValid ? mm : UNKNOWN, now);
    }
    const bool valid = pointing.fresh(now);
    packet.flags = valid && motorReady ? Calibrated : Fault;
    packet.range[0] = valid ? pointing.mm : UNKNOWN;
    if (valid && pointing.mm < 600) packet.flags |= Obstacle;
    const auto alert = localAlerts.update(packet.flags, packet.range, nullptr, now);
    const bool localWarning = (packet.flags & (Fault | Obstacle)) != 0;
    if (localWarning) identifyRequested = false;
    if (motorReady && alert.active) {
        // DRV2605 signed RTP uses positive amplitudes 0...127, as on the belt.
        motor.setRealtimeValue(alert.intensity / 2); stopPulse = now + alert.durationMS; lastPulse = now;
    }
    const uint32_t interval = valid ? constrain(pointing.mm, 150, 2000) : 1000;
    if (motorReady && !localWarning && (identifyRequested || uint32_t(now - lastPulse) >= interval)) {
        motor.setRealtimeValue(valid ? 90 : 40); stopPulse = now + 80; lastPulse = now; identifyRequested = false;
    }
    ++packet.sequence; uint8_t bytes[20]; packet.encode(bytes); notifyEncrypted(telemetry, bytes, sizeof(bytes));
    if (valid && packet.sequence % 2 == 0) {
        measurementFragment(Wrist, 0, packet.sequence, pointing.timestamp, &pointing.mm, 1, 0, bytes);
        notifyEncrypted(measurements, bytes, sizeof(bytes));
    }
}
