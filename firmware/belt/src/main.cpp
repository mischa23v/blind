#include <Arduino.h>
#include <Wire.h>
#include <NimBLEDevice.h>
#include <Adafruit_DRV2605.h>
#include <VL53L1X.h>
#include <SparkFun_VL53L5CX_Library.h>
#include "MobilityProtocol.h"

using namespace mobility;
// Two muxes: 8 ToF sensors at 0x70; 8 haptics at 0x71. Overhead sensor is direct at 0x30.
HardwareSerial downA(1), downB(2);
TFParser parsers[2]; Range downward[2], overhead;
SparkFun_VL53L5CX ring[8];
VL53L5CX_ResultsData zones;
bool ringReady[8] = {};
Range ringRange[8], sonar;
// "Responsive but nothing in range" is not a fault: these record the last answer from each device.
// A dead or stalled device (no answer for 350 ms) is a fault; no-target leaves the range unknown.
uint32_t overheadAlive = 0, ringAlive[8] = {};
uint16_t ringSamples[8][16]; bool newRingSample[8] = {};
volatile uint32_t sonarRise = 0, sonarWidth = 0, sonarTime = 0;
void IRAM_ATTR sonarEdge() {
    if (digitalRead(SONAR_PWM)) sonarRise = micros();
    else { sonarWidth = micros() - sonarRise; sonarTime = millis(); }
}
GroundMonitor ground;
VL53L1X upper;
bool upperReady = false, motorReady[8] = {};
Adafruit_DRV2605 motors[8];
NimBLECharacteristic* telemetry;
NimBLECharacteristic* measurements;
NimBLEServer* bleServer;
// Existing encrypted pairing behavior is retained. A physical pairing window
// requires a tested peer-identity policy; bond count alone cannot authorize a peer.
class Connections : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer*, NimBLEConnInfo& info) override {
        NimBLEDevice::startSecurity(info.getConnHandle());
    }
};
Connections connections;
void notifyEncrypted(NimBLECharacteristic* characteristic, const uint8_t* bytes, size_t length) {
    characteristic->setValue(bytes, length);
    for (auto handle : bleServer->getPeerDevices()) {
        if (bleServer->getPeerInfoByHandle(handle).isEncrypted()) characteristic->notify(bytes, length, handle);
    }
}
Packet packet;
portMUX_TYPE commandLock = portMUX_INITIALIZER_UNLOCKED;
Command pending; bool hasPending = false;
uint32_t motorUntil[8] = {}, lastTick = 0;
bool motorActive[8] = {};  // separate flag: a stop time that wraps to 0 must still be honoured
BeltAlertPolicy localAlerts;
void sendRanges(uint8_t sensor, const uint16_t* ranges, uint8_t count, uint32_t time) {
    uint8_t bytes[20];
    for (uint8_t part = 0; part < (count + 4) / 5; ++part) {
        measurementFragment(Belt, sensor, packet.sequence, time, ranges, count, part, bytes);
        notifyEncrypted(measurements, bytes, sizeof(bytes));
    }
}

bool channel(uint8_t index) {
    Wire.beginTransmission(0x71); Wire.write(1 << index); return Wire.endTransmission() == 0;
}
bool sensorChannel(uint8_t index) {
    Wire.beginTransmission(0x70); Wire.write(1 << index); return Wire.endTransmission() == 0;
}
bool pulse(uint8_t sector, uint8_t intensity, uint16_t duration, uint32_t now) {
    if (sector > 7 || !motorReady[sector] || !channel(sector)) return false;
    // DRV2605 signed RTP positive amplitude is limited to 127.
    motors[sector].setRealtimeValue(intensity / 2);
    motorUntil[sector] = now + duration; motorActive[sector] = true;
    return true;
}
class Commands : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* characteristic, NimBLEConnInfo&) override {
        const auto value = characteristic->getValue(); Command command;
        if (!Command::decode(value.data(), value.size(), command)) return;
        // BLE task never operates I2C; the sensor loop owns hardware.
        portENTER_CRITICAL(&commandLock); pending = command; hasPending = true; portEXIT_CRITICAL(&commandLock);
    }
};
Commands commands;
void setup() {
    Serial.begin(115200);
    Wire.begin(BELT_SDA, BELT_SCL); Wire.setClock(400000); Wire.setTimeOut(20);
    for (int i = 0; i < 8; ++i) {
        motorReady[i] = channel(i) && motors[i].begin(&Wire);
        if (motorReady[i]) { motors[i].useLRA(); motors[i].setMode(DRV2605_MODE_REALTIME); motors[i].setRealtimeValue(0); }
    }
    // Disable all haptic branches before accessing the ranging bus.
    Wire.beginTransmission(0x71); Wire.write(0); Wire.endTransmission();
    // Disable all ring branches while assigning the direct overhead sensor a unique address.
    Wire.beginTransmission(0x70); Wire.write(0); const bool ringIsolated = Wire.endTransmission() == 0;
    upper.setTimeout(20); upperReady = ringIsolated && upper.init();
    if (upperReady) {
        upper.setAddress(0x30);
        upperReady = upper.last_status == 0;
        if (upperReady) {
            const auto modelID = upper.readReg16Bit(VL53L1X::IDENTIFICATION__MODEL_ID);
            upperReady = upper.last_status == 0 && modelID == 0xEACC;
        }
    }
    if (upperReady) {
        upper.setDistanceMode(VL53L1X::Short);
        upper.setMeasurementTimingBudget(20000); upper.startContinuous(50);
    }
    for (int i = 0; i < 8; ++i) {
        // A failed address change can leave the direct sensor at the ring's 0x29.
        // Keep every ring branch disabled until isolation and the new address are verified.
        ringReady[i] = upperReady && sensorChannel(i) && ring[i].begin();
        if (ringReady[i]) ringReady[i] = ring[i].setResolution(16) && ring[i].setRangingFrequency(5) && ring[i].startRanging();
    }
    downA.begin(115200, SERIAL_8N1, DROP_A_RX, DROP_A_TX);
    downB.begin(115200, SERIAL_8N1, DROP_B_RX, DROP_B_TX);
    pinMode(SONAR_PWM, INPUT); attachInterrupt(digitalPinToInterrupt(SONAR_PWM), sonarEdge, CHANGE);
    // Task watchdog on the Arduino loop (default ~5 s) requests reset after a hang.
    // Setup attempts to zero the external motor drivers. A stuck bus or powered
    // driver can defeat that attempt; this is not a hardware motor-off guarantee.
    enableLoopWDT();
    NimBLEDevice::init("Mobility Belt");
    NimBLEDevice::setSecurityAuth(true, false, true);
    auto* server = NimBLEDevice::createServer(); bleServer = server;
    server->setCallbacks(&connections, false); server->advertiseOnDisconnect(true);
    auto* service = server->createService(SERVICE);
    telemetry = service->createCharacteristic(TELEMETRY, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ_ENC);
    measurements = service->createCharacteristic(MEASUREMENTS, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ_ENC);
    auto* command = service->createCharacteristic(COMMAND, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_ENC);
    command->setCallbacks(&commands);
    uint8_t bytes[20]; packet.encode(bytes); telemetry->setValue(bytes, sizeof(bytes));
    service->start();
    auto* advertising = NimBLEDevice::getAdvertising(); advertising->setName("Mobility Belt"); advertising->addServiceUUID(SERVICE); advertising->start();
}
void loop() {
    uint32_t now = millis();
    while (downA.available()) parsers[0].push(downA.read(), now, downward[0]);
    while (downB.available()) parsers[1].push(downB.read(), now, downward[1]);
    for (int i = 0; i < 8; ++i) {
        if (motorActive[i] && int32_t(now - motorUntil[i]) >= 0) {
            if (channel(i)) {
                motors[i].setRealtimeValue(0);
                motorActive[i] = false;
            }
            // Retry selection next loop if the mux failed; don't forget a pending stop.
        }
    }
    if (uint32_t(now - lastTick) < 50) { delay(1); return; }
    lastTick = now;
    Wire.beginTransmission(0x71); Wire.write(0); Wire.endTransmission();
    if (upperReady && upper.dataReady()) {
        const auto mm = upper.read(false);
        const auto status = upper.ranging_data.range_status;
        if (status != VL53L1X::HardwareFail) overheadAlive = millis();
        // Only valid returns update the range; "no target" (signal/out-of-bounds) leaves it to expire.
        if (status == VL53L1X::RangeValid) overhead.update(mm, millis());
    }
    for (int i = 0; i < 8; ++i) {
        if (!ringReady[i] || !sensorChannel(i) || !ring[i].isDataReady()) continue;
        uint16_t nearest = UNKNOWN;
        auto& distances = ringSamples[i]; for (auto& distance : distances) distance = UNKNOWN;
        if (ring[i].getRangingData(&zones)) {
            ringAlive[i] = millis();
            for (int z = 0; z < 16; ++z) {
                if (zones.target_status[z] == 5 && zones.distance_mm[z] > 0) {
                    distances[z] = zones.distance_mm[z];
                    if (distances[z] < nearest) nearest = distances[z];
                }
            }
        }
        if (nearest != UNKNOWN) ringRange[i].update(nearest, millis());
        newRingSample[i] = true;
    }
    noInterrupts(); const uint32_t width = sonarWidth, stamp = sonarTime; interrupts();
    // LV-MaxSonar EZ4: 147 microseconds per inch, read from PWM at 3.3 V logic.
    if (stamp != 0 && width >= 870 && width <= 37500) sonar.update(uint16_t(width * 25.4 / 147), stamp);
    now = millis();
    Command command; bool received;
    portENTER_CRITICAL(&commandLock); received = hasPending; command = pending; hasPending = false; portEXIT_CRITICAL(&commandLock);
    if (received && command.operation == 2) ground.beginCalibration();
    packet.flags = ground.update(downward, now);
    // Fault means a sensor stopped answering, not that it sees nothing within its range.
    if (!upperReady || uint32_t(now - overheadAlive) > 350 || !sonar.fresh(now)) packet.flags |= Fault;
    if (overhead.fresh(now) && overhead.mm < 900) packet.flags |= Overhead;
    for (int i = 0; i < 8; ++i) packet.range[i] = UNKNOWN;
    for (int i = 0; i < 8; ++i) {
        if (!ringReady[i] || uint32_t(now - ringAlive[i]) > 350) { packet.flags |= Fault; continue; }
        if (!ringRange[i].fresh(now, 350)) continue; // responsive, nothing in range: stays unknown, never "clear"
        packet.range[i] = ringRange[i].mm;
        if (ringRange[i].mm < 800) packet.flags |= Obstacle;
    }
    if (sonar.fresh(now)) {
        packet.range[0] = min(packet.range[0], sonar.mm);
        if (sonar.mm < 800) packet.flags |= Obstacle;
    }
    for (int i = 0; i < 8; ++i) if (!motorReady[i]) packet.flags |= Fault;
    // Downward slant range is NOT a horizontal obstacle distance.
    const auto alert = localAlerts.update(packet.flags, packet.range, received ? &command : nullptr, now);
    if (alert.active) pulse(alert.sector, alert.intensity, alert.durationMS, now);
    ++packet.sequence;
    uint8_t bytes[20]; packet.encode(bytes); notifyEncrypted(telemetry, bytes, sizeof(bytes));
    // Bulk measurement delivery follows the local safety decision and urgent summary.
    for (int i = 0; i < 8; ++i) if (newRingSample[i]) {
        sendRanges(i + 2, ringSamples[i], 16, ringRange[i].timestamp); newRingSample[i] = false;
    }
    if (packet.sequence % 2 == 0) {
        for (int i = 0; i < 2; ++i) if (downward[i].fresh(now)) sendRanges(i, &downward[i].mm, 1, downward[i].timestamp);
        if (overhead.fresh(now)) sendRanges(10, &overhead.mm, 1, overhead.timestamp);
        if (sonar.fresh(now)) sendRanges(11, &sonar.mm, 1, sonar.timestamp);
    }
}
