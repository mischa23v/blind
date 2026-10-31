#!/usr/bin/env python3
"""Further exact-anchor markers, staged in memory by instrument.py before writes."""
def refine(texts, files):
    io, reg, nav, test = files
    def change(path, old, new, count=1):
        assert texts[path].count(old) == count, f'Refinement anchor mismatch: {path}: {old[:80]}'
        texts[path] = texts[path].replace(old, new)
    # Thread-local context associates nested storage/decode events with the preparing IO token.
    change(io, '    static func emit(_ phase: String, _ token: UUID? = nil) {', '''    static func preparing<T>(_ token: UUID, body: () throws -> T) rethrows -> T {
        let dictionary = Thread.current.threadDictionary
        let key = "BlindAssist.diagnostic.io-token"
        let previous = dictionary[key]
        dictionary[key] = token
        defer { if let previous { dictionary[key] = previous } else { dictionary.removeObject(forKey: key) } }
        return try body()
    }
    static func emit(_ phase: String, _ explicitToken: UUID? = nil, at: TimeInterval? = nil) {
        let token = explicitToken ?? (Thread.current.threadDictionary["BlindAssist.diagnostic.io-token"] as? UUID)''')
    change(io, '\\(ProcessInfo.processInfo.systemUptime) main=', '\\(at ?? ProcessInfo.processInfo.systemUptime) main=')
    change(io, '                let candidate = try prepare(storage)', '                let candidate = try IndoorIOPhaseTrace.preparing(job.token.generation) { try prepare(storage) }')
    change(io, '    private let lock = NSLock()', '    private let diagnosticOwner = UUID()\n    private let lock = NSLock()')
    change(io, '        IndoorIOPhaseTrace.emit("drain.enter")', '        IndoorIOPhaseTrace.emit("drain.enter", diagnosticOwner)')
    # Never print while holding the production slot lock. Capture acquisition time,
    # then emit it after unlocking; timestamp (not print order) is authoritative.
    change(io, '''    private func take() -> Job? {
        lock.lock(); defer { lock.unlock() }''', '''    private func take() -> Job? {
        let before = ProcessInfo.processInfo.systemUptime
        lock.lock()
        let acquired = ProcessInfo.processInfo.systemUptime
        defer {
            lock.unlock()
            IndoorIOPhaseTrace.emit("slot.lock.before", diagnosticOwner, at: before)
            IndoorIOPhaseTrace.emit("slot.lock.acquired", diagnosticOwner, at: acquired)
        }''')
    change(io, '        let file = try FileHandle(forReadingFrom: url)', '''        IndoorIOPhaseTrace.emit("file.open.begin")
        let file = try FileHandle(forReadingFrom: url)
        IndoorIOPhaseTrace.emit("file.open.end")''')
    change(io, '        let size = try file.seekToEnd()', '''        IndoorIOPhaseTrace.emit("file.seek-end.begin")
        let size = try file.seekToEnd()
        IndoorIOPhaseTrace.emit("file.seek-end.end")''')
    change(io, '        try file.seek(toOffset: 0)', '''        IndoorIOPhaseTrace.emit("file.seek-start.begin")
        try file.seek(toOffset: 0)
        IndoorIOPhaseTrace.emit("file.seek-start.end")''')
    change(io, '        var bytes = Data()', '''        IndoorIOPhaseTrace.emit("file.read.begin")
        defer { IndoorIOPhaseTrace.emit("file.read.return") }
        var bytes = Data()''')
    change(reg, '''        let data: Data
        do { data = try storage.read(maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes) }''', '''        let data: Data
        IndoorIOPhaseTrace.emit("prior.read.begin")
        defer { IndoorIOPhaseTrace.emit("prior.return") }
        do { data = try storage.read(maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes) }''')
    change(reg, '''        restrictions: (blocked: Set<MapConnection>, zones: [KeepOutZone]), configuration: Configuration?,
        sha256: SpatialMapSHA256, persist: Bool) throws -> SpatialMapPrepared<Loaded> {
''', '''        restrictions: (blocked: Set<MapConnection>, zones: [KeepOutZone]), configuration: Configuration?,
        sha256: SpatialMapSHA256, persist: Bool) throws -> SpatialMapPrepared<Loaded> {
        IndoorIOPhaseTrace.emit("decode.begin")
        defer { IndoorIOPhaseTrace.emit("decode.return") }
''')
    change(reg, '        let map = try JSONDecoder().decode(IndoorMap.self, from: data); try map.validate()', '''        IndoorIOPhaseTrace.emit("preview.decode.begin")
        let map = try JSONDecoder().decode(IndoorMap.self, from: data)
        IndoorIOPhaseTrace.emit("preview.decode.end")
        try map.validate()
        IndoorIOPhaseTrace.emit("preview.validate.end")''')
