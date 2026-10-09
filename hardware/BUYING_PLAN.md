# Prototype purchasing plan

Reviewed 2026-10-02. Buy in stages after the preceding stage works. This is a development bill of materials, not a validated device for children. No all-day runtime, complete coverage, or total cost has been established. The old cost estimate and interchangeable sensor suggestions in `blind.txt` are preliminary notes; use this document and CONNECTIONS.md for the current firmware profile.

The belt is a core part of the intended mobility system. Phone-first evaluation is a development stage. The present belt profile still lacks belt-attitude compensation and validated ground coverage/warning distance; do not treat this list as a final child-ready design. See [elevation and lighting requirements](../research/ELEVATION_AND_LIGHTING.md). A rigidly mounted belt IMU and a complementary ground-sensing modality need engineering selection and integration; buying an extra sensor alone does not enable them.

## First: phone and Mac evaluation

Your existing hardware is an M1 Mac mini with 16 GB RAM, 256 GB storage and an iPhone 18 Pro Max. Use these first; no new phone or computer is recommended. Check the Mac's free storage and installed macOS before setup. The native dependency setup targets Apple Silicon. Apple lists M1-and-later Macs as Apple Intelligence-capable, but that does not establish the performance of this application. [Apple requirements](https://support.apple.com/en-us/121115).

Apple lists LiDAR on your **iPhone 18 Pro Max**, satisfying the relevant RoomPlan hardware requirement. Device capability is not proof that this app runs correctly; the first Apple SDK build and physical tests are still outstanding. [Apple's hardware specifications](https://www.apple.com/ae/iphone-18-pro/specs/), [RoomPlan hardware support](https://developer.apple.com/documentation/roomplan/roomcapturesession/issupported).

Initially use the phone speaker and a USB data cable. A stable, adjustable phone mount comes next for adult tests, with the rear camera and LiDAR unobstructed. Test mounting position, field of view, heat and comfort; do not assume a chest mount produces adequate downward coverage. Try existing open-ear headphones if available before buying a set. Bluetooth audio delay and environmental sound awareness need evaluation.

**Do not buy a robot vacuum, magnetic boundary tape, a full set of belt sensors, an Apple Watch, or phones for a class yet.** None is needed to find the first iOS build and usability problems.

Apple's current general Apple Intelligence language list does not list Arabic. This app checks the Foundation Models language capability at runtime and retains fixed Arabic phrases and Arabic map-name matching. Arabic conversation with a free local LLM is not established. Do not purchase a phone on the promise that this feature already works. [Apple language requirements](https://support.apple.com/en-us/121115).

## Second: a small electronics bench

After the iPhone app builds and its stationary controls work, start with one pointing-range node to evaluate a real sensor, BLE and timing:

| Part | Quantity | Purpose |
| --- | ---: | --- |
| [Seeed XIAO nRF52840](https://wiki.seeedstudio.com/XIAO_BLE/) | 1 | Current wrist firmware target; Sense is optional, its IMU is not integrated |
| [Pololu VL53L1X carrier, item 3415](https://www.pololu.com/product/3415) | 1 | Supported pointing-range sensor |
| [Adafruit DRV2605L breakout, product 2305](https://www.adafruit.com/product/2305) | 1 | Haptic driver, before connecting a selected/calibrated motor |
| USB data cable, suitable headers/wires, multimeter | 1 set | USB-powered bench assembly and electrical checks |

The current firmware selects LRA mode, but the motor's rated voltage, clamp and resonance/calibration settings have not been matched to a purchased motor. Choose a documented compatible LRA and configure/test those settings before connecting it for wear. Do not substitute a generic ERM coin motor. Without a working haptic driver the firmware reports a fault; a partial bench rig is not a functioning mobility device. Defer a wrist battery until USB bench tests pass and the exact protected-cell/charging arrangement is reviewed.

## Third: full belt reference, after bench validation

These quantities match the existing full belt profile. There is no validated reduced-sensor wearing profile. Start by testing individual modules on the bench; buying everything at once will not establish that the belt works.

| Part | Full belt quantity | Notes |
| --- | ---: | --- |
| [Seeed XIAO ESP32-S3](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/) | 1 | Standard board matching the default firmware pins |
| [Benewake TFmini-S](https://en.benewake.com/TFminiS/index.html) | 2 | Downward UART ranges; use TFmini-S, not a substitute without porting |
| [SparkFun Qwiic ToF Imager VL53L5CX](https://www.sparkfun.com/sparkfun-qwiic-tof-imager-vl53l5cx.html) | 8 | Body-relative ring sensors; VL53L8CX is not the current driver target |
| [Pololu VL53L1X carrier](https://www.pololu.com/product/3415) | 1 | Upward range sensor, additional to the wrist sensor |
| [MaxBotix MB1040 LV-MaxSonar-EZ4](https://maxbotix.com/products/mb1040) | 1 | PWM ultrasonic input; not an interchangeable HRLV model |
| TCA9548A breakout | 2 | Separate sensor/haptic muxes, addresses 0x70 and 0x71 |
| [Adafruit DRV2605L breakout](https://www.adafruit.com/product/2305) | 8 | One driver per belt LRA |
| Documented LRA actuators | 8 | Exact part and drive calibration remain to be selected and bench-tested |
| Power, cabling and enclosure | 1 set | Regulated rails, switch/fuse, decoupling, strain relief and measured electrical budget |

TFmini-S takes 5 V power with 3.3 V UART levels; review the exact [manufacturer datasheet](https://en.benewake.com/uploadfiles/2024/04/20240426140025367.pdf). Do not power the entire array from the XIAO's 3.3 V pin. The full belt's current draw, bus integrity, sensor interference, coverage, haptic behavior and battery life remain unmeasured. An electronics-experienced adult should assemble and check it using [CONNECTIONS.md](CONNECTIONS.md).

Magnetic tape detection, wrist sonar/IMU integration, battery telemetry and authenticated physical pairing setup remain separate work. Buying these extra parts now would not activate those features.
