import SwiftUI
import UniformTypeIdentifiers
import MapKit
import BlindCore

struct DashboardView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var model: NavigationModel
    @State private var placeName = ""
    @State private var focus = "surroundings"
    @State private var deletePrivateMap = false
    @State private var startNode = ""
    @State private var destinationNode = ""
    @State private var importing = false
    @State private var outdoorQuery = ""
    @State private var relayToken = ""
    @State private var uploadConfirmed = false
    @State private var importError = ""
    private let accent = Color(red: 1, green: 0.8, blue: 0.33)
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    var body: some View {
        TabView {
            NavigationStack { monitor.navigationTitle(t("Guide", "الإرشاد")) }
                .tabItem { Label(t("Guide", "الإرشاد"), systemImage: "sensor.tag.radiowaves.forward.fill") }
            NavigationStack { assistant.navigationTitle(t("Ask & describe", "اسأل وصف")) }
                .tabItem { Label(t("Ask", "اسأل"), systemImage: "bubble.left.and.text.bubble.right") }
            NavigationStack { places.navigationTitle(t("Familiar places", "الأماكن المألوفة")) }
                .tabItem { Label(t("Places", "الأماكن"), systemImage: "house") }
            NavigationStack { routes.navigationTitle(t("Routes", "المسارات")) }
                .tabItem { Label(t("Routes", "المسارات"), systemImage: "map") }
            NavigationStack { settings.navigationTitle(t("Settings", "الإعدادات")) }
                .tabItem { Label(t("Settings", "الإعدادات"), systemImage: "gearshape") }
        }
        .tint(accent)
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, model.arabic ? .rightToLeft : .leftToRight)
        .onAppear { relayToken = TokenStore.read() }
        .accessibilityAction(named: Text(t("Stop descriptions", "إيقاف الوصف"))) { model.stopDescriptions() }
    }
    private var monitor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.simulation {
                    Label(t("SIMULATION · generated readings", "محاكاة · قراءات مولدة"), systemImage: "testtube.2")
                        .font(.headline).foregroundStyle(accent).accessibilityAddTraits(.isHeader)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: model.detection.hazard.isUrgent ? "exclamationmark.octagon.fill" : "waveform.path")
                        .font(.largeTitle).foregroundStyle(model.detection.hazard.isUrgent ? .red : accent)
                        .accessibilityHidden(true)
                    Text(GuidanceText.detection(model.detection, arabic: model.arabic))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).accessibilityAddTraits(.isHeader)
                    if let distance = model.detection.distance {
                        Text(t("Measured range", "المسافة المقاسة") + " " + String(format: "%.1f m", distance)).font(.title2)
                    }
                    Text(t("Prototype for supervised testing. Keep using your cane or guide dog.",
                           "نموذج أولي للاختبار بإشراف. واصل استخدام العصا أو كلب الإرشاد."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(24)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                Button(model.running ? t("Stop monitoring", "إيقاف الرصد") : t("Start monitoring", "بدء الرصد")) {
                    if model.running { model.stop() } else { model.start() }
                }.buttonStyle(.borderedProminent).controlSize(.large).frame(minHeight: 56)
                    .accessibilityIdentifier("monitor-toggle")
                if model.running && !model.places.scanning {
                    Button(t("Repeat monitoring status", "إعادة حالة الرصد")) { model.repeatMonitoringStatus() }
                        .buttonStyle(.bordered).accessibilityIdentifier("repeat-monitoring-status")
                    Button(t("Calibrate on level ground", "المعايرة على أرض مستوية")) { model.calibrate() }
                        .buttonStyle(.bordered).controlSize(.large)
                    if model.detection.hazard == .calibrating {
                        ProgressView(value: model.calibrationProgress).accessibilityLabel(t("Floor calibration", "معايرة الأرض"))
                    }
                }
                if !model.message.isEmpty { Text(model.message).foregroundStyle(.secondary) }
                if model.running && !model.simulation {
                    Text(model.visualStairs.status(arabic: model.arabic)).font(.callout).foregroundStyle(.secondary)
                }
                Divider()
                Text(t("Wearables", "الأجهزة القابلة للارتداء")).font(.title2.bold())
                Text(model.wearableStatus)
                Text(t("Sensors delivering current measurements", "حساسات ترسل قياسات حديثة") + ": \(model.wearables.freshSensorCount)")
                Button(t("Connect belt & wristband", "توصيل الحزام والسوار")) { model.connectWearables() }
                Button(t("Disconnect wearables", "فصل الأجهزة القابلة للارتداء")) { model.wearables.disconnect() }
                ForEach(model.wearables.discovered, id: \.identifier) { peripheral in
                    Button(t("Pair", "اقتران") + " · " + (peripheral.name ?? peripheral.identifier.uuidString)) {
                        model.wearables.select(peripheral)
                    }
                }
                HStack {
                    Button(t("Calibrate belt", "معايرة الحزام")) { model.calibrateBelt() }
                    Button(t("Identify belt", "تحديد الحزام")) { model.identifyBelt() }
                }.buttonStyle(.bordered)
                if let distance = model.wearables.wristDistance {
                    Text(t("Pointing range", "مسافة الإشارة") + " " + String(format: "%.2f m", distance))
                    Button(t("Speak pointing range", "نطق مسافة الإشارة")) {
                        model.feedback.speak(String(format: model.arabic ? "المسافة %.2f متر" : "Range %.2f meters", distance))
                    }
                }
                Divider()
                Text(t("Return to start", "العودة إلى البداية")).font(.title2.bold())
                Button(model.returning ? t("Stop return guidance", "إيقاف إرشاد العودة") : t("Retrace this session", "تتبع مسار الجلسة للعودة")) {
                    if model.returning { model.stopReturn() } else { model.startReturn() }
                }.buttonStyle(.bordered).controlSize(.large).disabled(!model.running || model.simulation)
                if model.returning { Button(t("Repeat trail direction", "تكرار اتجاه المسار")) { model.speakReturnCue() } }
                if !model.returnStatus.isEmpty { Text(model.returnStatus) }
                Button(t("Repeat current status", "تكرار الحالة الحالية")) { model.feedback.alert(model.detection) }
                    .controlSize(.large)
                Button(t("Stop descriptions · keep hazard alerts", "إيقاف الوصف مع إبقاء تنبيهات المخاطر")) { model.stopDescriptions() }
                    .controlSize(.large)
                Divider()
                Button(t("Try simulation", "تجربة المحاكاة")) { model.startSimulation() }
                    .accessibilityIdentifier("start-simulation")
                if model.simulation {
                    ForEach([Hazard.observing, .drop, .obstacle, .overhead, .uncertain], id: \.self) { hazard in
                        Button(model.feedback.message(for: hazard)) { model.simulate(hazard) }.buttonStyle(.bordered)
                    }
                }
            }.padding(24)
        }
    }
    private var assistant: some View {
        Form {
            if let offer = model.companionOffer {
                // The same answer can be spoken: say yes or no after a voice-question tap.
                Section(t("Question from the assistant", "سؤال من المساعد")) {
                    Text(offer.prompt)
                    Button(t("Yes", "نعم")) { model.answerCompanionOffer(.yes) }.accessibilityIdentifier("offer-yes")
                    Button(t("No", "لا")) { model.answerCompanionOffer(.no) }.accessibilityIdentifier("offer-no")
                }
            }
            Section(t("Choose what to hear", "اختر ما تريد سماعه")) {
                Picker(t("Describe", "وصف"), selection: $focus) {
                    Text(t("Surroundings in camera view", "المحيط في مجال الكاميرا")).tag("surroundings")
                    Text(t("Room layout", "تخطيط الغرفة")).tag("room")
                    Text(t("People", "الأشخاص")).tag("people")
                    Text(t("An object", "غرض معين")).tag("object")
                    Text(t("Visible path features", "معالم المسار الظاهرة")).tag("path")
                    Text(t("Read text", "قراءة النص")).tag("text")
                }
                TextField(t("Question or target, for example: person in a blue coat", "السؤال أو الهدف، مثلاً: الشخص ذو المعطف الأزرق"), text: $model.assistantQuestion, axis: .vertical)
                    .accessibilityLabel(t("Question or target", "السؤال أو الهدف"))
                TextField(t("Ongoing goal, for example: reach the bathroom", "الهدف المستمر، مثلاً: الوصول إلى الحمام"), text: $model.objectiveDraft, axis: .vertical)
                Button(t("Set ongoing goal", "تحديد الهدف المستمر")) { model.setAssistantObjective() }
                if !model.assistantDialogue.goal.isEmpty { Text(t("Current goal: ", "الهدف الحالي: ") + model.assistantDialogue.goal) }
                Button(t("Clear goal and recent conversation", "مسح الهدف والمحادثة الأخيرة"), role: .destructive) { model.clearAssistantConversation() }
                Button(model.voice.listening ? t("Finish question", "إنهاء السؤال") : t("Talk · on-device transcription", "تحدث · تحويل الكلام على الهاتف")) {
                    if model.voice.listening { model.voice.finish() } else { model.startVoiceQuestion() }
                }.controlSize(.large).frame(minHeight: 52)
                    .accessibilityIdentifier("voice-question")
                if model.voice.listening { Text(model.voice.transcript) }
                if !model.voice.message.isEmpty { Text(model.voice.message).font(.callout) }
                Button(t("Find destination on saved map", "البحث عن الوجهة في الخريطة المحفوظة")) {
                    model.findMapDestination()
                }.disabled(model.busy || model.indoor.map == nil || model.assistantQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("map-destination")
                Button(t("Answer using this phone", "الإجابة باستخدام هذا الهاتف")) {
                    model.readScene(cloud: false, question: sceneQuestion, focus: focus)
                }.buttonStyle(.borderedProminent).controlSize(.large).frame(minHeight: 52)
                    .disabled(model.busy || model.simulation || !model.running)
                    .accessibilityIdentifier("local-answer")
                Text(t("On supported builds and devices, the local model describes the camera image using your question and goal. Otherwise, it uses detected text, people counts and scene categories. Person recognition and unseen-room mapping remain unavailable.", "في الإصدارات والأجهزة المدعومة، يصف النموذج المحلي صورة الكاميرا وفق سؤالك وهدفك. وإلا فيستخدم النص المرصود وعدد الأشخاص وتصنيفات المشهد. التعرف على هوية الأشخاص ورسم غرف غير مرئية غير متاحين بعد."))
                    .font(.callout).foregroundStyle(.secondary)
                Button(t("Ask with one photo · online", "اسأل بصورة واحدة · عبر الإنترنت")) { uploadConfirmed = true }
                    .controlSize(.large).frame(minHeight: 52)
                    .disabled(model.busy || model.simulation || !model.running || model.offlineOnly)
                    .accessibilityIdentifier("cloud-answer")
                Text(t("For directions to a destination, use Routes. Descriptions cover the current camera view; turn the camera only while stationary to examine another area.", "للاتجاهات إلى وجهة استخدم المسارات. الوصف يغطي مجال الكاميرا الحالي؛ غيّر اتجاهها أثناء الوقوف فقط لفحص منطقة أخرى."))
            }
            Section(t("Answer", "الإجابة")) {
                if model.busy { ProgressView(t("Reading scene…", "جارٍ قراءة المشهد…")) }
                if !model.message.isEmpty { Text(model.message).font(.callout) }
                Text(model.sceneAnswer.isEmpty ? t("Your answer appears here.", "تظهر الإجابة هنا.") : model.sceneAnswer).textSelection(.enabled)
                    .accessibilityIdentifier("assistant-answer")
                Button(t("Repeat answer", "تكرار الإجابة")) {
                    if model.detection.hazard == .observing { model.feedback.speak(model.sceneAnswer) }
                }.disabled(model.sceneAnswer.isEmpty).controlSize(.large)
                Button(t("Stop descriptions · keep hazard alerts", "إيقاف الوصف مع إبقاء تنبيهات المخاطر")) { model.stopDescriptions() }
                    .controlSize(.large)
                    .accessibilityIdentifier("stop-descriptions")
            }
        }
        .confirmationDialog(t("Send this photo, question, goal, saved interests, up to six conversation turns, four recent description attempts and the matched room's saved inventory to the configured scene service?", "هل تريد إرسال الصورة والسؤال والهدف والاهتمامات المحفوظة وما يصل إلى ست رسائل وأربع محاولات وصف حديثة وعناصر الغرفة المطابقة المحفوظة إلى خدمة المشهد؟"),
                            isPresented: $uploadConfirmed, titleVisibility: .visible) {
            Button(t("Send photo and question", "إرسال الصورة والسؤال")) {
                model.readScene(cloud: true, question: sceneQuestion, focus: focus)
            }
        }
    }
    private var sceneQuestion: String {
        let question = model.assistantQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        return question.isEmpty ? (model.arabic ? "صف \(focus) في مجال الكاميرا الحالي." : "Describe \(focus) in the current camera view.") : question
    }
    private var places: some View {
        List {
            Section {
                NavigationLink(t("Community maps · download and preview", "خرائط المجتمع · التنزيل والمعاينة")) { CommunityMapsView(model: model) }
                    .accessibilityIdentifier("community-maps")
            }
            Section(t("Private 3D map", "الخريطة الثلاثية الأبعاد الخاصة")) {
                NavigationLink(t("Walk-through mapping progress", "تقدم رسم الخريطة أثناء التجول")) { SurveyProgressView(model: model) }
                Text(model.mapping.status)
                if let url = model.mapping.exportURL {
                    ShareLink(t("Export private map", "تصدير الخريطة الخاصة"), item: url)
                    Button(t("Delete private map", "حذف الخريطة الخاصة"), role: .destructive) { deletePrivateMap = true }
                }
            }
            Section(t("Private journey history", "سجل الرحلات الخاص")) {
                Text(String(format: model.arabic ? "المسافة المسجلة: %.1f متر" : "Recorded distance: %.1f m", model.journeys.distance))
                ForEach(model.journeys.saved, id: \.id) { journey in
                    VStack(alignment: .leading) {
                        Text(journey.createdAt, style: .date)
                        Text(String(format: "%.1f m", journey.distance))
                        ShareLink(t("Export journey", "تصدير الرحلة"), item: model.journeys.url(for: journey))
                    }
                }.onDelete { offsets in offsets.map { model.journeys.saved[$0] }.forEach { model.journeys.delete($0) } }
                if !model.journeys.message.isEmpty { Text(model.journeys.message) }
            }
            Section(t("Scan a place", "مسح مكان")) {
                Text(model.mapping.status)
                TextField(t("Place name", "اسم المكان"), text: $placeName)
                if model.places.scanning {
                    Text(model.places.message)
                    Button(t("Finish scan", "إنهاء المسح")) { model.places.finishScan() }
                        .disabled(model.places.finishing)
                } else {
                    Button(t("Start room scan", "بدء مسح الغرفة")) { model.scanPlace(name: placeName) }
                        .disabled(!model.running || model.simulation)
                }
            }
            Section(t("Saved places", "الأماكن المحفوظة")) {
                if !model.placeRecoveryQuestion.isEmpty { Text(model.placeRecoveryQuestion) }
                if model.recognizedPlace == nil { Text(t("Current place has not been established.", "لم يتم تحديد المكان الحالي.")) }
                Button(t("Continue with place unknown", "المتابعة دون تحديد المكان")) { model.continueWithoutPlaceMatch() }
                    .disabled(!model.running || model.simulation || model.places.scanning)
                if model.places.needsDeletionCleanup {
                    Button(t("Retry deleted-file cleanup", "إعادة محاولة إزالة الملفات المحذوفة")) { model.places.retryDeletionCleanup() }
                }
                if model.places.places.isEmpty { Text(t("No places saved yet.", "لا توجد أماكن محفوظة بعد.")) }
                ForEach(model.places.places) { place in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name).font(.headline)
                        Text("\(place.objects.count) " + t("mapped objects", "عناصر مرسومة")).foregroundStyle(.secondary)
                        NavigationLink(t("Room map, labels & photo", "خريطة الغرفة والتسميات والصورة")) {
                            RoomDetailView(model: model, place: place)
                        }
                        Button(t("Recognize this place", "التعرف على هذا المكان")) { model.recognize(place) }
                    }
                }.onDelete { offsets in
                    let selected = offsets.map { model.places.places[$0] }
                    selected.forEach { model.places.delete($0) }
                }
            }
            if let place = model.recognizedPlace {
                Section(t("Compare a new scan", "مقارنة مسح جديد")) {
                    Text(place.name)
                    Button(t("Scan for possible changes", "المسح للبحث عن تغييرات محتملة")) { model.scanPlace(name: place.name, compare: true) }
                        .disabled(model.places.scanning)
                }
            }
            if !model.places.message.isEmpty { Section { Text(model.places.message) } }
        }
        .confirmationDialog(t("Delete the saved private 3D map?", "حذف الخريطة الثلاثية الأبعاد المحفوظة؟"), isPresented: $deletePrivateMap) {
            Button(t("Delete map", "حذف الخريطة"), role: .destructive) { model.mapping.deleteMap() }
        }
    }
    private var routes: some View {
        List {
            Section(t("Indoor landmarks", "معالم داخلية")) {
                Toggle(t("Phone is fixed facing with my body", "الهاتف مثبت باتجاه جسمي"), isOn: $model.fixedBodyMount)
                    .disabled(!model.running || model.simulation)
                Text(t("Confirm only with a fixed mount. Turn this off before holding or turning the phone separately. Camera direction alone does not establish body direction.", "أكد فقط عند استخدام حامل ثابت. ألغِ التأكيد قبل حمل الهاتف أو تدويره بشكل مستقل. اتجاه الكاميرا وحده لا يحدد اتجاه الجسم."))
                Button(t("Import indoor route JSON", "استيراد ملف المسار الداخلي")) { importing = true }
                Text(model.indoor.message)
                if let map = model.indoor.map {
                    if let revision = map.packageRevision {
                        Text(t("Source package revision: ", "مراجعة الحزمة الأصلية: ") + revision)
                        if map.packageModified == true {
                            Text(t("This route copy has local keep-out edits. It is not the unchanged community revision.", "تحتوي نسخة المسار على تعديلات محلية للمناطق المحظورة. وهي تختلف عن مراجعة المجتمع الأصلية."))
                        }
                    }
                    if let suggested = model.indoor.suggestedDestination {
                        Button(t("Use suggested destination", "استخدام الوجهة المقترحة") + ": " + suggested.localizedName(arabic: model.arabic)) { destinationNode = suggested.id }
                    }
                    Text(map.surfaces == nil ? t("Authored route graph; no collision surface supplied.", "مسارات محددة دون طبقة تصادم.") : t("Route checks include stored body and head clearance. Live monitoring is still required.", "يشمل فحص المسار عرض الجسم وارتفاع الرأس المسجلين. يلزم الرصد المباشر أيضاً."))
                    if let url = model.indoor.exportURL { ShareLink(t("Export route map", "تصدير خريطة المسار"), item: url) }
                    NavigationLink(t("Manage keep-out areas", "إدارة المناطق المحظورة")) {
                        KeepOutZonesView(indoor: model.indoor, arabic: model.arabic)
                    }
                    Picker(t("Known starting landmark", "نقطة البداية المعروفة"), selection: $startNode) {
                        Text(t("Select", "اختر")).tag("")
                        ForEach(map.nodes, id: \.id) { Text($0.localizedName(arabic: model.arabic)).tag($0.id) }
                    }
                    Picker(t("Destination", "الوجهة"), selection: $destinationNode) {
                        Text(t("Select", "اختر")).tag("")
                        ForEach(map.nodes, id: \.id) { Text($0.localizedName(arabic: model.arabic)).tag($0.id) }
                    }
                    Button(t("Plan accessible route", "تخطيط مسار قابل للوصول")) {
                        do { try model.indoor.plan(from: startNode, to: destinationNode) }
                        catch { importError = t("No accessible route found.", "لم يتم العثور على مسار مناسب.") }
                    }
                    Button(t("At confirmed landmark, facing next: align", "عند المعلم المؤكد وباتجاه التالي: محاذاة")) { model.alignIndoor() }
                    Button(t("Hear next landmark", "سماع المعلم التالي")) { model.indoorBeacon() }
                    Button(t("Confirm arrival at landmark", "تأكيد الوصول إلى المعلم")) { model.indoor.confirmArrival() }
                    Button(t("Next leg blocked · plan an alternative", "المقطع التالي مغلق · تخطيط بديل")) { model.indoor.blockNextLeg() }
                }
                if !importError.isEmpty { Text(importError).foregroundStyle(.red) }
            }
            Section(t("Outdoor destinations", "وجهات خارجية")) {
                TextField(t("Search nearby places", "البحث عن أماكن قريبة"), text: $outdoorQuery)
                Button(t("Search", "بحث")) { model.outdoor.search(outdoorQuery) }
                Text(model.outdoor.message)
                ForEach(Array(model.outdoor.results.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name ?? t("Place", "مكان"))
                        Button(t("Load walking directions", "تحميل اتجاهات المشي")) { model.outdoor.plan(to: item) }
                        Button(t("Open walking route in Google Maps", "فتح مسار المشي في خرائط جوجل")) {
                            var url = URLComponents(string: "https://www.google.com/maps/dir/")!
                            let c = item.placemark.coordinate
                            url.queryItems = [URLQueryItem(name: "api", value: "1"),
                                URLQueryItem(name: "destination", value: "\(c.latitude),\(c.longitude)"),
                                URLQueryItem(name: "travelmode", value: "walking")]
                            if let url = url.url { openURL(url) }
                        }.disabled(model.offlineOnly)
                        Button(t("Hear direction", "سماع الاتجاه")) {
                            if model.running, model.detection.hazard == .observing, let cue = model.outdoor.bearing(to: item) {
                                model.feedback.beacon(sector: cue.sector, distance: min(10, cue.distance))
                                model.feedback.speak(item.name ?? "Destination")
                            }
                        }
                    }
                }
                ForEach(Array(model.outdoor.routeSteps.enumerated()), id: \.offset) { _, step in
                    Button(step.instructions) { model.feedback.speak(step.instructions) }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard (values.fileSize ?? 0) <= 2_000_000 else { throw MapError.invalid }
                try model.indoor.load(Data(contentsOf: url)); importError = ""
            } catch { importError = t("Could not import this route map.", "تعذر استيراد خريطة المسار.") }
        }
    }
    private var settings: some View {
        Form {
            Section(t("Language & detail", "اللغة والتفاصيل")) {
                NavigationLink(t("Interests and preferences", "الاهتمامات والتفضيلات")) { AssistantPreferencesView(model: model) }
                    .accessibilityIdentifier("assistant-preferences")
                NavigationLink(t("Recent descriptions", "الأوصاف الأخيرة")) { NarrationHistoryView(model: model) }
                    .accessibilityIdentifier("narration-history")
                Toggle(t("Build private 3D map on next start", "بناء خريطة ثلاثية الأبعاد عند البدء التالي"), isOn: $model.buildPrivateMap)
                    .disabled(model.running || !model.mapping.available)
                if !model.mapping.available { Text(t("Install the native mapping build to enable 3D mapping.", "ثبّت إصدار الخرائط الأصلي لتفعيل الخرائط الثلاثية الأبعاد.")) }
                Toggle(t("Offline only · keep data on this phone", "دون إنترنت · إبقاء البيانات على الهاتف"), isOn: $model.offlineOnly)
                Toggle(t("Automatic surroundings descriptions", "وصف المحيط تلقائياً"), isOn: $model.ambientDescriptions)
                Picker(t("New rooms", "الغرف الجديدة"), selection: $model.firstVisitRooms) {
                    Text(t("Ask before describing", "اسأل قبل الوصف")).tag(FirstVisitMode.offer)
                    Text(t("Describe the first time", "صف في المرة الأولى")).tag(FirstVisitMode.describe)
                    Text(t("Only when I ask", "فقط عندما أطلب")).tag(FirstVisitMode.never)
                }
                Button(t("Repeat the last description", "تكرار الوصف الأخير")) { model.repeatDescription() }
                Text(t("Voice questions are answered locally after you finish speaking. Say quiet, resume, repeat, more detail, less detail, more information or less information. Short descriptions can also be automatic.", "تُجاب الأسئلة الصوتية على الهاتف بعد انتهاء الكلام. قل: أوقف الوصف، استأنف، كرر، تفاصيل أكثر، تفاصيل أقل، معلومات أكثر أو معلومات أقل. يمكن تفعيل الأوصاف القصيرة تلقائياً أيضاً."))
                Text(t("Descriptions use VoiceOver automatically when enabled. You control speech speed in VoiceOver; these settings control information amount and frequency. Danger and necessary mobility cues take priority.", "يُقرأ الوصف تلقائياً بالتعليق الصوتي عند تفعيله. اضبط سرعة النطق في التعليق الصوتي، وكمية المعلومات وتكرارها هنا. تتقدم تنبيهات الخطر وإرشادات الحركة الضرورية."))
                Stepper(t("Words per minute: ", "الكلمات في الدقيقة: ") + "\(model.wordsPerMinute)", value: $model.wordsPerMinute, in: 30...1800, step: 30)
                Stepper(t("Minimum seconds between descriptions: ", "أقل عدد ثوانٍ بين الأوصاف: ") + "\(model.narrationInterval)", value: $model.narrationInterval, in: 5...60, step: 5)
                Toggle("العربية · Arabic", isOn: $model.arabic)
                Picker(t("Description detail", "تفاصيل الوصف"), selection: $model.detail) {
                    Text(t("Important information only", "المعلومات المهمة فقط")).tag(DetailLevel.minimal)
                    Text(t("Balanced", "متوازن")).tag(DetailLevel.balanced)
                    Text(t("Detailed", "مفصل")).tag(DetailLevel.detailed)
                }
                Button(t("Test voice and vibration", "اختبار الصوت والاهتزاز")) { model.feedback.alert(Detection(.obstacle)) }
            }
            Section(t("Optional scene service", "خدمة المشهد الاختيارية")) {
                Text(LocalImageAssistant.status(arabic: model.arabic))
                if !model.localImageStatus.isEmpty { Text(model.localImageStatus) }
                Text(OfflineSummary.status(arabic: model.arabic))
                TextField("https://your-service.example", text: $model.serviceURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel(t("Scene service HTTPS address", "عنوان خدمة المشهد"))
                SecureField(t("Service access token", "رمز الوصول للخدمة"), text: $relayToken)
                Button(t("Save access token", "حفظ رمز الوصول")) { TokenStore.save(relayToken) }
                Button(t("Check connection · no photo", "فحص الاتصال دون صورة")) { model.checkSceneConnection() }.disabled(model.offlineOnly)
                if !model.serviceStatus.isEmpty { Text(model.serviceStatus) }
                Text(t("Only the service access token belongs here. Provider API credentials stay on the server.",
                       "أدخل رمز الوصول للخدمة فقط. تبقى مفاتيح مزود الذكاء الاصطناعي على الخادم."))
            }
            Section(t("Testing", "الاختبار")) {
                Text(t("Phone vibration may be hard to feel in a harness. Confirm alerts with your chosen headphones and belt.",
                       "قد يصعب الشعور باهتزاز الهاتف في الحامل. تحقق من التنبيهات بالسماعات والحزام."))
                Text(t("Arabic text recognition depends on the installed iOS Vision language support.",
                       "يعتمد التعرف على النص العربي على دعم اللغة في إصدار iOS المثبت."))
            }
        }
    }
}
