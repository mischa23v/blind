import CoreBluetooth
import BlindCore

final class BeltLink: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    struct Device {
        var peripheral: CBPeripheral
        var telemetry: CBCharacteristic?
        var command: CBCharacteristic?
        var freshness = PacketFreshness()
        var packet: WearablePacket?
        var role: WearableRole?
        var assembler = MeasurementAssembler()
        var measurements: [UInt8: SensorMeasurement] = [:]
    }
    private var central: CBCentralManager!
    private var devices: [UUID: Device] = [:]
    private var scanning = false
    private var selected = Set<UUID>()
    private var expectedRoles: [UUID: WearableRole] = [:]
    private(set) var discovered: [CBPeripheral] = []
    var onUpdate: (() -> Void)?
    private(set) var status = "Disconnected"
    /// Paired wearables are remembered so they reconnect by themselves after a restart, a
    /// Bluetooth drop or the app returning from the background (always on, 2026-10-22).
    private static let savedKey = "paired-wearables"
    private var saved: Set<UUID> {
        get { Set((UserDefaults.standard.stringArray(forKey: Self.savedKey) ?? []).compactMap(UUID.init(uuidString:))) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: Self.savedKey) }
    }
    override init() {
        super.init()
        // State restoration lets iOS relaunch the Bluetooth link in the background (bluetooth-central).
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey: "org.blindassist.wearables"])
        if !saved.isEmpty { scanning = true }
    }
    func connect() { scanning = true; scanIfReady() }
    func select(_ peripheral: CBPeripheral) {
        guard selected.count < 2 || selected.contains(peripheral.identifier) else { return }
        selected.insert(peripheral.identifier); saved.insert(peripheral.identifier)
        attach(peripheral)
    }
    /// Forget a wearable on purpose (pairing a different belt). Plain reconnects keep it.
    func forget(_ id: UUID) { saved.remove(id); selected.remove(id) }
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        scanning = true
        // Restored links are reattached through reattachSaved() once Bluetooth reports powered on.
        for peripheral in dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? [] where saved.contains(peripheral.identifier) {
            selected.insert(peripheral.identifier)
        }
    }
    /// Reattach remembered wearables without waiting for a new scan result.
    private func reattachSaved() {
        guard scanning, central.state == .poweredOn else { return }
        for peripheral in central.retrievePeripherals(withIdentifiers: Array(saved)) {
            selected.insert(peripheral.identifier)
            attach(peripheral)
        }
    }
    private func attach(_ peripheral: CBPeripheral) {
        guard scanning, devices[peripheral.identifier] == nil else { return }
        devices[peripheral.identifier] = Device(peripheral: peripheral)
        status = "Connecting to wearable"; onUpdate?()
        peripheral.delegate = self; central.connect(peripheral)
    }
    func disconnect() {
        scanning = false; central.stopScan()
        selected = []; expectedRoles = [:]; discovered = []
        for device in devices.values { central.cancelPeripheralConnection(device.peripheral) }
        devices = [:]; status = "Disconnected"; onUpdate?()
    }
    var hasWearables: Bool { !devices.isEmpty }
    func detections(at time: Double) -> [Detection] {
        selected.filter { expectedRoles[$0] != .wrist }.map { id in
            guard let device = devices[id] else { return Detection(.uncertain) }
            guard device.freshness.isFresh(at: time), let packet = device.packet else { return Detection(.uncertain) }
            return packet.detection
        }
    }
    var wristDistance: Double? {
        guard let wrist = devices.values.first(where: { $0.role == .wrist }),
              wrist.freshness.isFresh(at: ProcessInfo.processInfo.systemUptime),
              let packet = wrist.packet, !packet.hasFault else { return nil }
        let distance = packet.distancesMM[0]
        return distance == UInt16.max ? nil : Double(distance) / 1000
    }
    func rangeEvidence(at time: Double, arabic: Bool) -> [SceneObservation] {
        devices.values.sorted { ($0.role?.rawValue ?? 0) < ($1.role?.rawValue ?? 0) }.flatMap { device -> [SceneObservation] in
            guard device.freshness.isFresh(at: time), let packet = device.packet,
                  let receivedAt = device.freshness.lastReceived else { return [] }
            return WearableEvidence.observations(packet: packet, receivedAt: receivedAt, now: time, arabic: arabic)
        }
    }
    var diagnostic: String {
        devices.values.map { "\($0.role == .wrist ? "Wrist" : "Belt"): \($0.packet?.hazard.rawValue ?? "waiting")" }.joined(separator: ", ")
    }
    var freshSensorCount: Int {
        let now = ProcessInfo.processInfo.systemUptime
        return devices.values.flatMap { $0.measurements.values }.filter { $0.isFresh(at: now) && $0.validZones > 0 }.count
    }
    func send(_ data: Data, to role: WearableRole = .belt) {
        for device in devices.values where device.role == role {
            if let characteristic = device.command {
                device.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
        }
    }
    private func scanIfReady() {
        guard scanning, central.state == .poweredOn else { return }
        reattachSaved()
        central.scanForPeripherals(withServices: [CBUUID(string: WearablePacket.serviceUUID)], options: nil)
        status = "Looking for belt and wristband"; onUpdate?()
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: scanIfReady()
        case .unauthorized: status = "Bluetooth permission denied"
        case .poweredOff: status = "Bluetooth is off"; devices = [:]
        case .unsupported: status = "Bluetooth unavailable"
        default: status = "Bluetooth unavailable"
        }
        onUpdate?()
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discovered.contains(where: { $0.identifier == peripheral.identifier }), discovered.count < 20 {
            discovered.append(peripheral); onUpdate?()
        }
        if selected.contains(peripheral.identifier) { attach(peripheral) }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard scanning, selected.contains(peripheral.identifier) else { central.cancelPeripheralConnection(peripheral); return }
        peripheral.discoverServices([CBUUID(string: WearablePacket.serviceUUID)])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        devices.removeValue(forKey: peripheral.identifier); status = "Connection failed"; onUpdate?()
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        devices.removeValue(forKey: peripheral.identifier)
        status = "Wearable disconnected"; onUpdate?()
        if scanning, selected.contains(peripheral.identifier) { attach(peripheral) }
        scanIfReady()
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { status = "Service discovery failed"; onUpdate?(); return }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([CBUUID(string: WearablePacket.telemetryUUID),
                                               CBUUID(string: WearablePacket.commandUUID),
                                               CBUUID(string: SensorMeasurement.characteristicUUID)], for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { status = "Characteristic discovery failed"; onUpdate?(); return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == CBUUID(string: WearablePacket.telemetryUUID) {
                devices[peripheral.identifier]?.telemetry = characteristic
                // Reading the encrypted characteristic also lets CoreBluetooth initiate pairing.
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == CBUUID(string: WearablePacket.commandUUID) {
                devices[peripheral.identifier]?.command = characteristic
            } else if characteristic.uuid == CBUUID(string: SensorMeasurement.characteristicUUID) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil || !characteristic.isNotifying {
            status = "Wearable sensor subscription unavailable"; onUpdate?()
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { status = "Wearable reading unavailable; check pairing"; onUpdate?(); return }
        if error == nil, characteristic.uuid == CBUUID(string: SensorMeasurement.characteristicUUID),
           let data = characteristic.value, var device = devices[peripheral.identifier], let role = device.role {
            if let sample = device.assembler.accept(data, role: role, at: ProcessInfo.processInfo.systemUptime) {
                device.measurements[sample.sensor] = sample
            }
            devices[peripheral.identifier] = device
            return
        }
        guard error == nil, characteristic.uuid == CBUUID(string: WearablePacket.telemetryUUID),
              let data = characteristic.value, let packet = WearablePacket(data: data),
              var device = devices[peripheral.identifier] else { return }
        // Restarted peripherals must reconnect before sequence state is reset.
        guard device.freshness.accept(packet, at: ProcessInfo.processInfo.systemUptime) else { return }
        if let old = device.role, old != packet.role { return }
        if let expected = expectedRoles[peripheral.identifier], expected != packet.role { return }
        if devices.contains(where: { $0.key != peripheral.identifier && $0.value.role == packet.role }) {
            // A second belt (or wristband) would report "uncertain" forever; drop it instead.
            status = "A device with this role is already connected"
            selected.remove(peripheral.identifier); devices.removeValue(forKey: peripheral.identifier)
            central.cancelPeripheralConnection(peripheral); onUpdate?(); return
        }
        device.role = packet.role; device.packet = packet
        expectedRoles[peripheral.identifier] = packet.role
        devices[peripheral.identifier] = device; status = "Connected"; onUpdate?()
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { status = "Wearable command failed"; onUpdate?() }
    }
}
