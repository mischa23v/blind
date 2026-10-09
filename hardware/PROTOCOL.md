# Wearable transport contract

All UUIDs share suffix `-B5A3-4F7D-8F16-A962EAF724A0`. Service prefix is `594A0001`; hazard summary `594A0002`; phone command `594A0003`; raw measurement `594A0004`. Each controller is a BLE peripheral; the phone is central. No Wi-Fi or cloud service is involved.

Both firmwares request link security on connection. Reads and commands require encryption, and notification delivery is explicitly restricted to encrypted connections. The iPhone reads the summary during discovery to initiate system pairing if needed. Local sensing and haptics continue while pairing is pending or disconnected. This uses unauthenticated BLE pairing/bonding; physical owner enrollment and bond reset remain unimplemented.

All multi-byte integers are little-endian. Distances are unsigned millimeters. **65535 means unknown**, never an unobstructed path. Roles: belt=1, wrist=2. Reconnection resets the phone's per-device sequence and measurement-assembly state.

## Hazard summary, 20 bytes, nominal 20 Hz

| Byte | Field |
|---|---|
| 0 | Version 1 |
| 1 | Role |
| 2 | Flags: fault=1, drop=2, obstacle=4, overhead=8, calibrated=16, raised-ground qualifier=32 |
| 3 | Wrapping sequence number |
| 4–19 | Eight body-sector ranges, two bytes each, clockwise from front |

A wrist uses only slot 0 for pointing range. Drop and overhead ranges are absent from this summary; the app must not use a nearby side obstacle's range as the drop distance. Fault may coexist with an urgent hazard. Phone summary timeout is 0.8 s. This is a liveness threshold, not a promised detection latency.

The raised-ground qualifier must accompany obstacle=4. It identifies a shorter downward range, so the app and local belt warning use the front direction without inventing a horizontal distance from a different body sensor. Unknown bits and an orphan qualifier are rejected. Earlier builds reject the new bit; update app and firmware together. Both longer (possible drop) and shorter (possible raised ground) range changes can warn independently. The current 250 mm slant-range threshold is a prototype limitation under evaluation, not a guaranteed detectable stair height.

## Raw sensor measurement, 20-byte fragments

| Byte | Field |
|---|---|
| 0 | Version 2 |
| 1 | Role |
| 2 | Sensor ID |
| 3 | Fragment index, starting at zero |
| 4–7 | Source MCU uptime in milliseconds at acquisition/readout |
| 8 | Sample sequence |
| 9 | Total zones: 1 or 16 |
| 10–19 | Five ranges; out-of-range padding must equal 65535 |

One-point sensors take one fragment; a 4×4 sensor takes four. Every fragment of one sample has identical timestamp, sequence, role, sensor ID and zone count. The phone accepts out-of-order fragments within 250 ms, emits only a complete sample, and uses the first fragment's receipt time for freshness. It rejects replayed source timestamps, handles uint32 uptime wrap, and clears all state after reconnection. Unknown zones stay unknown.

Belt IDs: 0=left downward TFmini-S; 1=right downward; 2–9=ring S0–S7; 10=overhead; 11=front MB1040. Wrist ID 0=pointing VL53L1X. Ring zones preserve sensor-native array order; mounting/zone projection calibration is required before spatial fusion.

At 5 Hz for eight 16-zone sensors, ring payload is 8 × 4 × 20 × 5 = **3,200 bytes/s**. Four single-point belt sources at up to 10 Hz add 800 bytes/s; summary adds 400 bytes/s. This is application payload only; BLE overhead/retries increase airtime. Fixed 20-byte fragments work at minimum ATT MTU; the physical radio still needs sustained-throughput and latency testing.

## Phone commands, six bytes, write with response

Version=1, opcode, sector, intensity, duration in 10 ms units, reserved=0. Opcode 1 requests a body-sector haptic pulse; sector 0–7, intensity 0–255, duration 10–500 ms. Opcode 2 requests explicit level-ground calibration and all remaining fields are zero. Opcode 3 identifies the device with a pulse. Calibration is never automatic on boot or reconnection.

The wrist accepts identification and produces its own ranging pulses; it does not execute body-sector guidance. Radio write acknowledgment proves delivery to the BLE stack, not completed calibration or a functioning motor. Those states must be observed separately.

The current protocol does not carry battery level, sensor extrinsics, IMU orientation, negotiated capability tables or clock synchronization. These require a versioned extension before the product can use them. A source timestamp alone is not synchronized phone time.
