import SwiftUI
import BlindCore
import BlindMemory

/// Explicit local diagnostic UI. No camera permission request, route issuer or export.
/// Inject the app's existing bridge, never create a second AR session for this view.
@MainActor struct NavigationTestRecordingView: View {
    let bridge: NativeARObservationBridge
    let arabic: Bool
    var onRecordingStarted: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: RecordedRouteStore.TestSnapshot?
    @State private var message = ""
    @State private var rawFrame = true
    @State private var saved: [NavigationTestSessionState] = []
    @State private var savedListFailed = false
    @State private var visible = false
    @State private var requestGeneration = UUID()
    private func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
    private var recording: NavigationTestRecording? { snapshot?.recording }
    private var active: Bool { recording?.status == .recording }
    var body: some View {
        List {
            Section {
                Text(t("Compare the planned line with the measured phone path", "قارن المسار المخطط بمسار الهاتف المقاس")).font(.headline)
                Text(t("Diagnostic only. The camera path is not your body or feet. This plot does not reconstruct furniture or prove clearance. Close the saved recording or explicitly delete it before starting another. No photos, audio or uploads are recorded.",
                       "للتشخيص فقط. مسار الكاميرا ليس مسار جسمك أو قدميك. لا يعيد هذا الرسم بناء الأثاث ولا يثبت خلو المسار. أغلق التسجيل المحفوظ أو احذفه صراحةً قبل بدء تسجيل آخر. لا تُسجل صور أو أصوات ولا تُرفع بيانات."))
                Button(t("Start local path recording", "بدء تسجيل المسار محلياً")) {
                    if bridge.startNavigationTestRecording() { message = ""; onRecordingStarted() }
                    else { message = t("Recording could not start. The existing camera session must be active.", "تعذر بدء التسجيل. يجب أن تكون جلسة الكاميرا الحالية نشطة.") }
                    refresh()
                }.disabled(recording != nil || snapshot?.deleting == true || snapshot?.erasePending == true)
                    .accessibilityIdentifier("navigationTest.start")
                Button(t("Stop recording", "إيقاف التسجيل")) { stop() }.disabled(!active)
                    .accessibilityIdentifier("navigationTest.stop")
                Button(t("Delete this diagnostic recording", "حذف هذا التسجيل التشخيصي"), role: .destructive) {
                    let token = requestGeneration
                    bridge.deleteNavigationTestRecording { success in
                        guard visible, token == requestGeneration else { return }
                        message = success ? "" : t("Deletion failed. The saved recording may still exist; retry from the saved list.", "فشل الحذف. قد يبقى التسجيل المحفوظ؛ أعد المحاولة من القائمة.")
                        refresh(); refreshSaved()
                    }; refresh()
                }.disabled(recording == nil || snapshot?.deleting == true)
                    .accessibilityIdentifier("navigationTest.deleteCurrent")
                Button(t("Close saved recording", "إغلاق التسجيل المحفوظ")) {
                    if !bridge.closeNavigationTestRecording() { message = t("Wait for saving or retry the failed save before closing.", "انتظر الحفظ أو أعد محاولة الحفظ الفاشل قبل الإغلاق.") }
                    refresh(); refreshSaved()
                }.disabled(recording == nil || active || snapshot?.saving == true || snapshot?.saveFailed == true || (snapshot?.pendingEvents ?? 0) > 0)
                    .accessibilityIdentifier("navigationTest.close")
                if snapshot?.saveFailed == true {
                    Text(t("Saving failed. Recording stopped; unsaved events remain in memory. Retry or explicitly delete. They will not survive process exit.", "فشل الحفظ. توقف التسجيل وتبقى الأحداث غير المحفوظة في الذاكرة. أعد المحاولة أو احذف صراحةً. لن تبقى هذه الأحداث بعد إنهاء العملية."))
                    Button(t("Retry local save", "إعادة محاولة الحفظ المحلي")) { bridge.retryNavigationTestSave(); refresh() }
                        .accessibilityIdentifier("navigationTest.retrySave")
                }
                if !message.isEmpty { Text(message) }
                Text(t("Saved only on this phone, with no export or sharing. Leaving this screen or backgrounding stops recording. Reopening restores only committed events, always stopped; a crash can lose the unsaved tail.",
                       "يُحفظ على هذا الهاتف فقط، دون تصدير أو مشاركة. تُوقف مغادرة هذه الشاشة أو نقل التطبيق للخلفية التسجيل. تستعيد إعادة الفتح الأحداث المحفوظة فقط بحالة متوقفة؛ وقد يفقد التعطل الأحداث غير المحفوظة."))
            }
            Section(t("Saved local recordings", "التسجيلات المحلية المحفوظة")) {
                Button(t("Refresh saved recordings", "تحديث التسجيلات المحفوظة")) { refreshSaved() }
                    .accessibilityIdentifier("navigationTest.refreshSaved")
                if savedListFailed { Text(t("Saved recordings could not be read.", "تعذرت قراءة التسجيلات المحفوظة.")) }
                ForEach(saved, id: \.id) { session in
                    VStack(alignment: .leading) {
                        Text(Date(timeIntervalSince1970: session.createdAt).formatted()).font(.caption)
                        Text(t("\(session.nextSequence) saved events", "\(session.nextSequence) حدث محفوظ"))
                        Button(t("Open stopped recording", "فتح التسجيل بحالة متوقفة")) { openSaved(session.id) }
                            .disabled(recording != nil || snapshot?.deleting == true || snapshot?.erasePending == true)
                            .accessibilityIdentifier("navigationTest.open." + session.id)
                        Button(t("Delete saved recording", "حذف التسجيل المحفوظ"), role: .destructive) { deleteSaved(session.id) }
                            .disabled(recording?.id.uuidString == session.id || snapshot?.deleting == true)
                            .accessibilityIdentifier("navigationTest.deleteSaved." + session.id)
                    }
                }
            }
            if let recording {
                Section(t("Recording evidence", "أدلة التسجيل")) {
                    Text("\(statusLabel(recording.status)) · \(recording.entries.count)/\(NavigationTestRecording.maximumSamples)")
                        .accessibilityIdentifier("navigationTest.status")
                        .accessibilityLabel(t("Recording status \(statusLabel(recording.status)), \(recording.entries.count) camera samples", "حالة التسجيل \(statusLabel(recording.status))، \(recording.entries.count) عينة كاميرا"))
                    Text(t("Saved events: \(snapshot?.savedEvents ?? 0). Pending events: \(snapshot?.pendingEvents ?? 0).", "الأحداث المحفوظة: \(snapshot?.savedEvents ?? 0). الأحداث المعلقة: \(snapshot?.pendingEvents ?? 0)."))
                        .accessibilityIdentifier("navigationTest.saveStatus")
                    if recording.restoredHistorical {
                        Text(recording.restoredInterrupted
                            ? t("Recovered committed prefix: recording was interrupted and is stopped. No actual stop time is known.", "استُعيد الجزء المحفوظ: انقطع التسجيل وهو متوقف. وقت التوقف الفعلي غير معروف.")
                            : t("Saved historical recording, stopped. This is not your current location.", "تسجيل تاريخي محفوظ بحالة متوقفة. ليس هذا موقعك الحالي."))
                        Text(t("Original rejection counters are not included in this archive version.", "عدادات الرفض الأصلية غير مضمنة في نسخة الأرشيف هذه."))
                    } else {
                        Text(t("Rejected samples: \(snapshot?.rejectedSamples ?? 0). Rejected route updates: \(snapshot?.rejectedPlans ?? 0).",
                               "العينات المرفوضة: \(snapshot?.rejectedSamples ?? 0). تحديثات المسار المرفوضة: \(snapshot?.rejectedPlans ?? 0)."))
                    }
                    Toggle(t("Show raw camera frame", "عرض إطار الكاميرا الخام"), isOn: $rawFrame)
                    NavigationTestTrajectoryPlot(recording: recording, rawFrame: rawFrame)
                        .frame(height: 260)
                        .accessibilityLabel(rawFrame
                            ? t("Raw camera-frame dots, latest source frame only. No planned route or verified map position is shown.", "نقاط إطار الكاميرا الخام، لأحدث إطار مصدر فقط. لا يُعرض مسار مخطط أو موضع موثق في الخريطة.")
                            : t("Latest plan revision only. Blue is planned; orange is recorded camera position registered to that same revision. Gaps are not joined.", "أحدث نسخة مخطط فقط. الأزرق للمخطط والبرتقالي لموضع الكاميرا المسجل المرتبط بالنسخة نفسها. الفجوات غير موصولة."))
                    if rawFrame, let last = recording.entries.last {
                        Text(t("Latest source frame only:", "أحدث إطار مصدر فقط:"))
                        Text(last.sample.sourceFrameID).font(.caption).textSelection(.enabled)
                    } else if let plan = recording.plans.last {
                        Text("\(plan.map.mapID) / \(plan.map.revision)").font(.caption)
                        Text(t("Latest plan revision only. Only samples with matching supplied registration are plotted. Registration may be wrong; raw samples are retained.",
                               "أحدث نسخة مخطط فقط. تُرسم العينات ذات التسجيل المطابق المقدم فقط. قد يكون التسجيل خاطئاً؛ تبقى العينات الخام محفوظة."))
                    }
                    Text(t("\(recording.entries.filter { $0.cameraInMap == nil }.count) samples have no map association.",
                           "\(recording.entries.filter { $0.cameraInMap == nil }.count) عينة دون ارتباط بالخريطة."))
                }
                Section(t("Mark a problem you noticed", "ضع علامة على مشكلة لاحظتها")) {
                    ForEach(problemChoices, id: \.0) { problem, label in
                        Button(label) {
                            if !bridge.markNavigationTestProblem(problem) { message = t("Marker was not recorded.", "لم تُسجل العلامة.") }
                            refresh()
                        }.disabled(!active).accessibilityIdentifier("navigationTest.mark." + problem.rawValue)
                    }
                    ForEach(Array(recording.markers.enumerated()), id: \.offset) { _, marker in
                        Text("\(problemLabel(marker.problem)) · \(marker.recordedAt - recording.startedAt, specifier: "%.1f") \(t("s", "ث"))")
                    }
                }
            }
        }
        .navigationTitle(t("Local path diagnostic", "تشخيص المسار المحلي"))
        .task {
            visible = true; requestGeneration = UUID(); refresh(); refreshSaved()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { break }
                guard !Task.isCancelled else { break }; refresh()
            }
        }
        .onDisappear { visible = false; requestGeneration = UUID(); stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
    }
    private func statusLabel(_ status: NavigationTestRecording.Status) -> String {
        switch status {
        case .recording: return t("Recording", "جارٍ التسجيل")
        case .stopped: return t("Stopped", "متوقف")
        case .capacityReached: return t("Stopped: recording limit reached", "توقف: تم بلوغ حد التسجيل")
        }
    }
    private func problemLabel(_ problem: NavigationTestRecording.Problem) -> String {
        problemChoices.first { $0.0 == problem }?.1 ?? t("Other reported problem", "مشكلة أخرى مُبلّغ عنها")
    }
    private var problemChoices: [(NavigationTestRecording.Problem, String)] {
        [(.apparentWallCrossing, t("Path appears to cross a wall", "يبدو أن المسار يعبر جداراً")),
         (.apparentFurnitureCrossing, t("Path appears to cross furniture", "يبدو أن المسار يعبر أثاثاً")),
         (.wrongDirection, t("Wrong direction", "اتجاه خاطئ")),
         (.missedObstacle, t("Missed obstacle", "عائق لم يُكتشف")),
         (.falseBlockage, t("Clear space shown blocked", "مساحة خالية تظهر مسدودة")),
         (.trackingMismatch, t("Phone position looks wrong", "موضع الهاتف يبدو خاطئاً"))]
    }
    private func refreshSaved() {
        let token = requestGeneration
        bridge.listSavedNavigationTests { rows in
            guard visible, token == requestGeneration else { return }
            savedListFailed = rows == nil; saved = rows ?? []
        }
    }
    private func openSaved(_ id: String) {
        let token = requestGeneration
        bridge.reopenNavigationTest(id: id) { success in
            guard visible, token == requestGeneration else { return }
            message = success ? "" : t("Recording could not be reopened.", "تعذرت إعادة فتح التسجيل.")
            refresh()
        }
    }
    private func deleteSaved(_ id: String) {
        let token = requestGeneration
        bridge.deleteSavedNavigationTest(id: id) { success in
            guard visible, token == requestGeneration else { return }
            message = success ? "" : t("Deletion failed; the saved recording may still exist.", "فشل الحذف؛ قد يبقى التسجيل المحفوظ.")
            refresh(); refreshSaved()
        }; refresh()
    }
    private func refresh() { snapshot = bridge.navigationTestSnapshot() }
    private func stop() { bridge.stopNavigationTestRecording(); refresh() }
}

private struct NavigationTestTrajectoryPlot: View {
    let recording: NavigationTestRecording
    let rawFrame: Bool
    var body: some View {
        Canvas { context, size in
            let planned: [Point3] = rawFrame ? [] : (recording.plans.last?.points ?? [])
            let segments: [[Point3]]
            if rawFrame, let last = recording.entries.last {
                // Dots only: never invent continuity for limited/unknown source tracking.
                segments = recording.entries.filter {
                    $0.sample.sessionID == last.sample.sessionID && $0.sample.sourceFrameID == last.sample.sourceFrameID
                }.map { [$0.sample.cameraPosition] }
            } else if let map = recording.plans.last?.map {
                segments = recording.overlaySegments.filter { $0.map == map && $0.planIndex == recording.plans.indices.last }.map(\.points)
            } else { segments = [] }
            let all = planned + segments.flatMap { $0 }
            guard let first = all.first else { return }
            let minX = all.map(\.x).min() ?? first.x, maxX = all.map(\.x).max() ?? first.x
            let minZ = all.map(\.z).min() ?? first.z, maxZ = all.map(\.z).max() ?? first.z
            let scale = min(max(1, size.width - 24) / CGFloat(max(1, maxX-minX)), max(1, size.height - 24) / CGFloat(max(1, maxZ-minZ)))
            func point(_ p: Point3) -> CGPoint {
                CGPoint(x: size.width/2 + CGFloat(p.x-(minX+maxX)/2)*scale,
                        y: size.height/2 - CGFloat(p.z-(minZ+maxZ)/2)*scale)
            }
            func line(_ points: [Point3], color: Color) {
                guard let start = points.first else { return }
                var path = Path(); path.move(to: point(start))
                for p in points.dropFirst() { path.addLine(to: point(p)) }
                context.stroke(path, with: .color(color), lineWidth: 2)
                for p in points {
                    let c = point(p)
                    context.fill(Path(ellipseIn: CGRect(x: c.x-2, y: c.y-2, width: 4, height: 4)), with: .color(color))
                }
            }
            line(planned, color: .blue)
            for segment in segments { line(segment, color: .orange) }
        }
    }
}
