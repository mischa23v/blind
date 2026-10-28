import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import BlindCore

/// Local ephemeral display of a pinned public research artifact, not the selected
/// saved room, a live pose, a floor model, or a source of spoken movement commands.
@MainActor struct RecordedRoomRoutePreview: View {
    let arabic: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var lease = RoomPreviewImportLease()
    @State private var visible = false
    @State private var importToken: UUID?
    @State private var importing = false
    @State private var archive: Data?
    @State private var preview: RoomMeshPreview?
    @State private var variant = SavedRoomMeshPreview.Variant.original
    @State private var leg = 0
    @State private var error = false
    private let expectedDigest = "e60c008fd5759ebf81863774f8335c27429a20b19253c95b2b6db45291bb44d2"
    private func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
    var body: some View {
        let callbackToken = importToken
        return List {
            Section {
                Text(t("Recorded research preview — not your current room", "معاينة بحثية مسجلة — ليست غرفتك الحالية"))
                    .font(.headline)
                Text(t("This shows an archived code-planner line only, not a 3D room, safe path, current location or walking instructions. Floor support and current obstacles remain unknown.",
                       "تعرض خطاً مسجلاً من مخطط برمجي فقط، وليس غرفة ثلاثية الأبعاد أو مساراً آمناً أو موقعك الحالي أو تعليمات للمشي. دعم الأرض والعوائق الحالية غير معروفين."))
                Button(t("Open recorded Koivu route file", "فتح ملف مسار كويفو المسجل")) {
                    guard let token = lease.begin() else { return }
                    importToken = token; importing = true
                }
                Text("research/room-mesh-package-75/ROUTE_DIAGNOSTIC.json").font(.caption)
                Text(t("Only the pinned public geometry file is accepted. It stays in memory; no photo, upload or automatic navigation.",
                       "يُقبل الملف الهندسي العام المحدد فقط. يبقى في الذاكرة؛ لا صور أو رفع بيانات أو تنقل تلقائي."))
                if archive != nil {
                    Button(t("Clear preview", "مسح المعاينة")) { clear() }
                }
                if error { Text(t("File rejected. Use the exact recorded artifact; no map was installed.", "رُفض الملف. استخدم الملف المسجل المحدد؛ لم تُثبت أي خريطة.")) }
            }
            if archive != nil {
                Section(t("Recorded hierarchy and route", "التسلسل والمسار المسجلان")) {
                    Picker(t("Source variant", "نسخة المصدر"), selection: $variant) {
                        Text(t("Original", "الأصلية")).tag(SavedRoomMeshPreview.Variant.original)
                        Text(t("Replayed", "المعاد تشغيلها")).tag(SavedRoomMeshPreview.Variant.replayed)
                        Text(t("Assisted exclusions", "استبعادات بمساعدة")).tag(SavedRoomMeshPreview.Variant.excluded)
                    }
                    Picker(t("Recorded leg", "الجزء المسجل"), selection: $leg) {
                        ForEach(0..<5, id: \.self) { i in Text("\(i + 1)").tag(i) }
                    }
                    if let preview {
                        Text("\(preview.context.placeID) / \(preview.context.floorID) / \(preview.context.roomID)")
                        Text(t("Supplied recording coordinates, not live localization. Reference-assisted study, not fresh floor evidence.",
                               "إحداثيات مقدمة من التسجيل وليست تحديد موقع مباشر. دراسة بمساعدة مرجع وليست دليلاً حديثاً على الأرض."))
                        Text(preview.context.frameID).font(.caption)
                        RecordedRoutePlot(points: preview.points).frame(height: 260).accessibilityHidden(true)
                        Text(t("Two-dimensional X/Z route plot in source metres; \(preview.points.count) recorded vertices. No walls or clearance are depicted.",
                               "رسم مسار ثنائي الأبعاد X/Z بأمتار المصدر؛ \(preview.points.count) نقاط مسجلة. لا يعرض جدراناً أو مساحة عبور."))
                        Text(t("Unknown coverage — physical guidance withheld", "تغطية غير معروفة — الإرشاد الحركي محجوب"))
                        Text(preview.sourceID).font(.caption).textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle(t("Recorded route preview", "معاينة مسار مسجل"))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard visible, scenePhase == .active, let token = callbackToken, lease.finish(token) else { return }
            importToken = nil
            clear()
            do {
                let url = try result.get()
                guard url.isFileURL else { throw RoomPreviewError.invalidArtifact }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                // Check size before reading, then enforce the same limit in Core.
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= 2_000_000 else {
                    throw RoomPreviewError.invalidArtifact
                }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: 2_000_001) ?? Data()
                preview = try decode(data); archive = data
            } catch { self.error = true }
        }
        .onChange(of: variant) { _, _ in reload() }
        .onChange(of: leg) { _, _ in reload() }
        .onAppear { visible = true; if scenePhase == .active { lease.activate() } }
        .onDisappear { visible = false; retireImport(); clear() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && visible { lease.activate() }
            else { retireImport(); clear() }
        }
    }
    private func decode(_ data: Data) throws -> RoomMeshPreview {
        let context = try RoomPreviewContext(placeID: "MuSHRoom-recorded", floorID: "recorded-level", roomID: "Koivu",
            frameID: "phone-corrected-level-game-yup-v1", poseProvenance: "Supplied recorded query coordinates; not live localization",
            supportProvenance: "Reference-assisted research; current phone floor support unknown")
        return try SavedRoomMeshPreview.load(data: data, expectedSHA256: expectedDigest,
            sha256: { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() },
            variant: variant, index: leg, context: context)
    }
    private func reload() {
        preview = nil
        guard let archive else { return }
        do { preview = try decode(archive); error = false }
        catch { clear(); error = true }
    }
    private func retireImport() { lease.retire(); importToken = nil; importing = false }
    private func clear() { preview = nil; archive = nil; error = false }
}

private struct RecordedRoutePlot: View {
    let points: [[Float]]
    var body: some View {
        Canvas { context, size in
            guard let minX = points.map({ $0[0] }).min(), let maxX = points.map({ $0[0] }).max(),
                  let minZ = points.map({ $0[2] }).min(), let maxZ = points.map({ $0[2] }).max() else { return }
            // A single uniform scale preserves aspect ratio; no independent axis stretching.
            let dx = CGFloat(maxX - minX), dz = CGFloat(maxZ - minZ)
            let scale = min(max(1, size.width - 24) / max(dx, 0.001), max(1, size.height - 24) / max(dz, 0.001))
            let x0 = (size.width - dx * scale) / 2, z0 = (size.height - dz * scale) / 2
            var path = Path()
            for (index, p) in points.enumerated() {
                let point = CGPoint(x: x0 + CGFloat(p[0] - minX) * scale, y: z0 + CGFloat(maxZ - p[2]) * scale)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(.blue), lineWidth: 3)
        }
    }
}
