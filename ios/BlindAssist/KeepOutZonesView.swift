import SwiftUI
import BlindCore

struct KeepOutZonesView: View {
    @ObservedObject var indoor: IndoorNavigator
    let arabic: Bool
    @State private var landmarkID = ""
    @State private var halfSize = 1.0
    @State private var error = ""
    @State private var pendingRemoval: KeepOutZone?
    private func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
    var body: some View {
        List {
            Section(t("Parent or school setup", "إعداد الوالدين أو المدرسة")) {
                Text(t("Mark a square around a surveyed landmark. Its position comes from the imported route map. For other shapes and locations, edit the map's rectangles before import.", "حدد مربعاً حول معلم مقاس. يؤخذ الموقع من خريطة المسار المستوردة. للمواقع والأشكال الأخرى، عدّل مستطيلات الخريطة قبل الاستيراد."))
                Picker(t("Centre landmark", "المعلم في المركز"), selection: $landmarkID) {
                    Text(t("Select", "اختر")).tag("")
                    ForEach(indoor.map?.nodes ?? [], id: \.id) { node in
                        Text(node.localizedName(arabic: arabic) + " · " + node.level).tag(node.id)
                    }
                }
                Stepper(value: $halfSize, in: 0.5...10, step: 0.5) {
                    Text(t("Distance from centre to each side", "المسافة من المركز إلى كل جانب") + ": \(halfSize.formatted()) " + t("metres", "متر"))
                }
                Button(t("Save keep-out area", "حفظ المنطقة المحظورة")) {
                    do { try indoor.addKeepOutZone(landmarkID: landmarkID, halfSize: halfSize); error = "" }
                    catch { self.error = t("Could not save this area.", "تعذر حفظ المنطقة.") }
                }.disabled(landmarkID.isEmpty)
                Text(t("Stored routes avoid these areas with body clearance. Adding a restriction cancels the current route, not a measured pose. Registered restrictions cannot be reopened without fresh observed-clearance evidence. This screen does not detect physical tape or provide continuous boundary alarms.", "تتجنب المسارات المخزنة هذه المناطق مع مساحة للجسم. تُلغي إضافة منطقة محظورة المسار الحالي، لا الموقع المقاس. لا يمكن إعادة فتح المناطق المسجلة دون دليل حديث على خلوها. لا تكشف هذه الشاشة الشريط الأرضي ولا توفر إنذارات حدود مستمرة."))
            }
            Section(t("Saved areas", "المناطق المحفوظة")) {
                if indoor.storedKeepOutZones.isEmpty { Text(t("No keep-out areas saved.", "لا توجد مناطق محظورة محفوظة.")) }
                ForEach(indoor.storedKeepOutZones) { zone in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(zone.localizedName(arabic: arabic)).font(.headline)
                        Text(t("Level", "الطابق") + ": " + zone.level)
                        Text("X: \(zone.minX.formatted()) … \(zone.maxX.formatted()), Z: \(zone.minZ.formatted()) … \(zone.maxZ.formatted()) m")
                        Button(t("Remove", "حذف") + " " + zone.localizedName(arabic: arabic), role: .destructive) { pendingRemoval = zone }
                            .disabled(!indoor.canRemoveStoredKeepOutZones)
                    }
                }
            }
            Text(StatusText.localized(indoor.message, arabic: arabic))
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle(t("Keep-out areas", "المناطق المحظورة"))
        .confirmationDialog(t("Remove this keep-out area?", "حذف هذه المنطقة المحظورة؟"), isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })) {
            Button(t("Remove area", "حذف المنطقة"), role: .destructive) {
                guard let zone = pendingRemoval else { return }
                do { try indoor.removeKeepOutZone(id: zone.id); error = "" }
                catch { self.error = t("Could not remove this area.", "تعذر حذف المنطقة.") }
                pendingRemoval = nil
            }
        }
    }
}
