import SwiftUI
import BlindCore

final class SurveyProgress: ObservableObject {
    @Published private(set) var snapshot = SurveyCoverage()
    private var tracker = SurveyCoverage()
    private var lastPublish = -Double.infinity
    func reset() { tracker = SurveyCoverage(); snapshot = tracker; lastPublish = -.infinity }
    func invalidate() {
        guard tracker.state != .needsTracking || tracker.camera != nil else { return }
        tracker.invalidate(); snapshot = tracker
    }
    func observe(_ frame: Observation, floor: Double?) {
        tracker.observe(frame, floor: floor)
        if frame.timestamp - lastPublish >= 0.5 || tracker.state != snapshot.state {
            snapshot = tracker; lastPublish = frame.timestamp
        }
    }
}

struct SurveyProgressView: View {
    @ObservedObject var model: NavigationModel
    private var survey: SurveyCoverage { model.survey.snapshot }
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    private var status: String {
        switch survey.state {
        case .needsTracking: return t("Waiting for a stable camera position. Previous uncertain coverage has been cleared.", "ننتظر ثبات موقع الكاميرا. مُسحت التغطية السابقة غير المؤكدة.")
        case .needsFloor: return t("Calibrate on known level ground to record observed floor.", "اضبط قياس الأرض على سطح مستوٍ معروف لتسجيل الأجزاء المرصودة.")
        case .collecting: return t("Recording your trail and measured floor patches. Blank areas remain unknown.", "نسجل مسارك وأجزاء الأرض المقاسة. المناطق الفارغة غير معروفة.")
        case .limitReached: return t("Preview limit reached. Stop and save this section before starting another.", "وصل العرض إلى حده. توقف واحفظ هذا الجزء قبل بدء جزء آخر.")
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(t("Walk-through mapping", "رسم الخريطة أثناء التجول")).font(.title.bold())
                Text(status)
                Text(model.mapping.status)
                Canvas { context, size in
                    let cells = survey.floorCells, r = survey.resolution
                    let floorPoints = cells.map { Point3(Double($0.x) * r, 0, Double($0.z) * r) }
                    let points = floorPoints + survey.trail
                    guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                          let minZ = points.map(\.z).min(), let maxZ = points.map(\.z).max() else { return }
                    let scale = min((Double(size.width) - 32) / max(3, maxX - minX + r), (Double(size.height) - 32) / max(3, maxZ - minZ + r))
                    func screen(_ point: Point3) -> CGPoint { CGPoint(x: (point.x - minX) * scale + 16, y: (point.z - minZ) * scale + 16) }
                    for point in floorPoints {
                        context.fill(Path(CGRect(origin: screen(point), size: CGSize(width: r * scale, height: r * scale))), with: .color(.blue.opacity(0.55)))
                    }
                    var path = Path()
                    for (index, point) in survey.trail.enumerated() {
                        if index == 0 { path.move(to: screen(point)) } else { path.addLine(to: screen(point)) }
                    }
                    context.stroke(path, with: .color(.yellow), lineWidth: 3)
                    if let camera = survey.camera {
                        let point = screen(camera)
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(.white))
                    }
                }.frame(height: 360).background(Color.black.opacity(0.4)).accessibilityHidden(true)
                Text(t("Yellow: where the phone travelled. Blue: floor cells with measured samples. White dot: current phone position. Blank space is unknown, not a wall or an open passage.", "الأصفر: مسار الهاتف. الأزرق: أجزاء أرض رُصدت بقياسات. النقطة البيضاء: موقع الهاتف. الفراغ غير معروف؛ لا يعني جداراً أو ممراً مفتوحاً."))
                Text(t("Observed floor cells", "أجزاء الأرض المرصودة") + ": \(survey.floorCells.count). " + t("Trail samples", "نقاط المسار") + ": \(survey.trail.count).")
                Button(t("Repeat mapping status", "تكرار حالة رسم الخريطة")) { model.speakOperation(status) }
                Text(t("This is one continuous-session preview, not a coverage percentage or a walking route. The native mapping build saves the full 3D database. Keep the camera running between rooms; tracking loss resets this preview.", "هذا عرض لجلسة متصلة، وليس نسبة اكتمال أو مسار مشي. يحفظ إصدار الخرائط الأصلي قاعدة البيانات الثلاثية الأبعاد. أبقِ الكاميرا تعمل بين الغرف؛ يُعاد العرض عند فقدان التتبع."))
            }.padding()
        }.navigationTitle(t("Mapping progress", "تقدم رسم الخريطة"))
    }
}
