import SwiftUI
import UniformTypeIdentifiers
import MapKit
import BlindCore

struct DashboardView: View {
    @ObservedObject var model: NavigationModel
    var body: some View { AssistantToolsView(model: model, initialTab: "companion") }
}

/// The main screen holds the assistant's current reply, a row of reading tools, and the bottom tab
/// buttons, so VoiceOver reads the reply first and nothing else in between (user, 2026-10-22). Speech already
/// announces each new reply; Yes/No, Repeat and Write are VoiceOver actions on the reply (and a
/// long-press menu), or are said aloud.
private struct CompanionHomeView: View {
    @ObservedObject var model: NavigationModel
    @State private var typedMessage = ""
    @State private var writing = false
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }

    private var reply: String {
        if !model.currentReply.isEmpty { return model.currentReply }
        return model.companionGreeting.isEmpty ? model.homePrompt : model.companionGreeting
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(reply)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .accessibilityIdentifier("companion-reply")
                    .accessibilityHint(t("Swipe up or down for options.", "اسحب للأعلى أو الأسفل للخيارات."))
                    .accessibilityActions { actions }
                    .contextMenu { actions }
            }
            // Seeing AI-style tools, just above the bottom tab buttons (user, 2026-10-22).
            HomeToolButtons(model: model)
            // Developer typing tests only (--text-only); not part of the everyday screen.
            if model.textOnly {
                Button(t("Write a message", "اكتب رسالة")) { writing = true }
                    .buttonStyle(.bordered).padding(.bottom, 16).accessibilityIdentifier("write-message")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityAction(.magicTap) { model.repeatHomeInformation() }
        .sheet(isPresented: $writing) {
            NavigationStack {
                Form {
                    TextField(t("Your message", "رسالتك"), text: $typedMessage, axis: .vertical)
                        .accessibilityIdentifier("companion-message")
                    Button(t("Send", "إرسال")) {
                        model.receiveCompanionUtterance(typedMessage)
                        typedMessage = ""; writing = false
                    }
                    .disabled(typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("send-companion-message")
                }
                .navigationTitle(t("Write a message", "اكتب رسالة"))
                .toolbar { Button(t("Done", "تم")) { writing = false } }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        if model.companionOffer != nil {
            Button(t("Yes", "نعم")) { model.answerCompanionOffer(.yes) }
            Button(t("No", "لا")) { model.answerCompanionOffer(.no) }
        }
        Button(t("Repeat", "كرر")) { model.repeatHomeInformation() }
        Button(t("Quiet descriptions (alerts and listening stay on)", "أوقف الأوصاف (التنبيهات والاستماع مستمرة)")) { model.stopDescriptions() }
        if model.readingTool != nil {
            Button(t("Stop reading tool", "أوقف أداة القراءة")) { model.stopReadingTool(announce: true) }
        }
        if model.simulation {
            Button(t("End practice", "أنهِ التدريب")) { model.endPractice() }
        }
        Button(model.running ? t("Restart camera and sensors", "أعد تشغيل الكاميرا والحساسات") : t("Start camera and sensors", "شغّل الكاميرا والحساسات")) {
            if model.running { model.restartSensors() } else { model.startExperience() }
        }
        Button(t("Write a message", "اكتب رسالة")) { writing = true }
    }
}

/// Large tool buttons above the tab bar. A running tool's button stops it.
private struct HomeToolButtons: View {
    @ObservedObject var model: NavigationModel
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    private func tool(_ kind: ReadingTool, _ title: String, _ stopTitle: String, _ symbol: String, _ id: String) -> some View {
        let active = model.readingTool == kind
        return Button {
            if active { model.stopReadingTool(announce: true) } else { model.startReadingTool(kind) }
        } label: {
            label(active ? stopTitle : title, symbol: active ? "stop.circle.fill" : symbol, active: active)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private func label(_ title: String, symbol: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title2).accessibilityHidden(true)
            Text(title).font(.callout.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(8)
        .foregroundStyle(active ? Color.black : Color.white)
        .background(active ? Color.yellow : Color(white: 0.18), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            tool(.liveText, t("Read text", "اقرأ النص"), t("Stop reading", "أوقف القراءة"), "text.viewfinder", "tool-read-text")
            tool(.document, t("Read page", "اقرأ صفحة"), t("Stop page", "أوقف الصفحة"), "doc.text.viewfinder", "tool-read-page")
            tool(.barcode, t("Scan code", "امسح رمزاً"), t("Stop scan", "أوقف المسح"), "barcode.viewfinder", "tool-scan-code")
            tool(.light, t("Light", "الضوء"), t("Stop light", "أوقف الضوء"), "lightbulb", "tool-light")
            NavigationLink { ExplorePictureView(model: model) } label: {
                label(t("Explore picture", "استكشف صورة"), symbol: "hand.point.up.left", active: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tool-explore")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct AssistantToolsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var model: NavigationModel
    @State private var preferredNameDraft = ""
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
    @State private var confirmForgetName = false
    @State private var confirmClearConversation = false
    @State private var placesToDelete: [SavedPlace] = []
    @State private var journeysToDelete: [Journey] = []
    @State private var confirmRouteImport = false
    @State private var confirmRouteDelete = false
    @State private var shareJourney: Journey?
    @State private var shareRouteMap = false
    @State private var selectedTab: String
    init(model: NavigationModel, initialTab: String = "settings") {
        self.model = model
        _selectedTab = State(initialValue: initialTab)
    }
    private let accent = Color(red: 1, green: 0.8, blue: 0.33)
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { CompanionHomeView(model: model) }
                .tabItem { Label(t("Assistant", "المساعد"), systemImage: "bubble.left.and.bubble.right") }
                .tag("companion")
            NavigationStack { places.navigationTitle(t("Familiar places", "الأماكن المألوفة")) }
                .tabItem { Label(t("Places", "الأماكن"), systemImage: "house") }
                .tag("places")
            NavigationStack { routes.navigationTitle(t("Routes", "المسارات")) }
                .tabItem { Label(t("Routes", "المسارات"), systemImage: "map") }
                .tag("routes")
            #if BLIND_FAMILIAR_PEOPLE
            NavigationStack { FamiliarPeopleView(model: model, experiment: model.familiarPeople) }
                .tabItem { Label(t("People", "الأشخاص"), systemImage: "person.2") }
                .tag("people")
            #endif
            NavigationStack { settings.navigationTitle(t("Settings", "الإعدادات")) }
                .tabItem { Label(t("Settings", "الإعدادات"), systemImage: "gearshape") }
                .tag("settings")
        }
        .tint(accent)
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, model.arabic ? .rightToLeft : .leftToRight)
        #if BLIND_FAMILIAR_PEOPLE
        .sheet(isPresented: $model.showFamiliarPeople) {
            NavigationStack { FamiliarPeopleView(model: model, experiment: model.familiarPeople) }
        }
        #endif
        .onAppear { relayToken = TokenStore.read() }
    }
    // Screens below follow one pattern (2026-10-22): a short header per section, the most-used
    // action first, one line of status, no repeated controls, short sentences VoiceOver can read
    // quickly, and a confirmation before anything is deleted. Every earlier function is kept.

    /// Camera and safety: live monitoring status, calibration, return guidance and practice.
    private var monitor: some View {
        Form {
            Section {
                if model.simulation {
                    Text(t("SIMULATION · generated readings", "محاكاة · قراءات مولدة"))
                        .font(.headline).foregroundStyle(accent)
                }
                Text(GuidanceText.detection(model.detection, arabic: model.arabic))
                    .font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                if let distance = model.detection.distance {
                    Text(t("Measured distance", "المسافة المقاسة") + " " + String(format: model.arabic ? "%.1f متر" : "%.1f metres", distance))
                }
                // No off switch: the companion is always on. Restart only pauses for a moment.
                Button(model.running ? t("Restart camera and sensors", "أعد تشغيل الكاميرا والحساسات") : t("Start camera and sensors", "شغّل الكاميرا والحساسات")) {
                    if model.running { model.restartSensors() } else { model.startExperience() }
                }
                .font(.headline)
                .accessibilityIdentifier("monitor-toggle")
                if model.running && !model.places.scanning {
                    Button(t("Repeat status", "كرر الحالة")) { model.repeatMonitoringStatus() }
                        .accessibilityIdentifier("repeat-monitoring-status")
                    Button(t("Calibrate on level ground", "المعايرة على أرض مستوية")) { model.calibrate() }
                    if model.detection.hazard == .calibrating {
                        ProgressView(value: model.calibrationProgress)
                            .accessibilityLabel(t("Floor calibration", "معايرة الأرض"))
                            .accessibilityValue("\(Int(model.calibrationProgress * 100))%")
                    }
                }
                Button(t("Stop descriptions, keep alerts", "أوقف الوصف وأبقِ التنبيهات")) { model.stopDescriptions() }
                if !model.message.isEmpty { Text(model.message) }
                if model.running && !model.simulation { Text(model.visualStairs.status(arabic: model.arabic)) }
            } header: { Text(t("Safety alerts", "تنبيهات السلامة")) }
            Section {
                Button(model.returning ? t("Stop return guidance", "إيقاف إرشاد العودة") : t("Guide me back to where I started", "أرشدني إلى نقطة البداية")) {
                    if model.returning { model.stopReturn() } else { model.startReturn() }
                }
                .disabled(!model.running || model.simulation)
                .accessibilityIdentifier("retrace-session")
                if model.returning { Button(t("Repeat direction", "كرر الاتجاه")) { model.speakReturnCue() } }
                if !model.returnStatus.isEmpty { Text(model.returnStatus) }
            } header: { Text(t("Return to start", "العودة إلى البداية")) }
            Section {
                if model.simulation {
                    Button(t("End practice, back to live sensors", "أنهِ التدريب وعد إلى الحساسات")) { model.endPractice() }
                        .accessibilityIdentifier("end-practice")
                } else {
                    Button(t("Try practice (2 minutes)", "جرب التدريب (دقيقتان)")) { model.startSimulation() }
                        .accessibilityIdentifier("start-simulation")
                }
                if model.simulation {
                    ForEach([Hazard.observing, .drop, .obstacle, .overhead, .uncertain], id: \.self) { hazard in
                        Button(t("Practice: ", "تدريب: ") + model.feedback.message(for: hazard)) { model.simulate(hazard) }
                    }
                }
            } header: { Text(t("Practice", "التدريب")) } footer: {
                Text(t("Practice pauses live sensors and ends by itself after two minutes. Test version: keep using your cane or guide dog.", "التدريب يوقف الحساسات الحقيقية وينتهي وحده بعد دقيقتين. نسخة تجريبية: واصل استخدام العصا أو كلب الإرشاد."))
            }
        }
        .navigationTitle(t("Camera and safety", "الكاميرا والسلامة"))
    }

    /// Ask about the camera view, hear the answer, and set an ongoing goal.
    private var assistant: some View {
        Form {
            if let offer = model.companionOffer {
                // The same answer can be spoken: say yes or no.
                Section {
                    Text(offer.prompt)
                    Button(t("Yes", "نعم")) { model.answerCompanionOffer(.yes) }.accessibilityIdentifier("offer-yes")
                    Button(t("No", "لا")) { model.answerCompanionOffer(.no) }.accessibilityIdentifier("offer-no")
                } header: { Text(t("The assistant asked", "سؤال من المساعد")) }
            }
            Section {
                TextField(t("Your question", "سؤالك"), text: $model.assistantQuestion, axis: .vertical)
                    .accessibilityLabel(t("Question or target", "السؤال أو الهدف"))
                Picker(t("Look at", "انظر إلى"), selection: $focus) {
                    Text(t("Everything in view", "كل ما في الصورة")).tag("surroundings")
                    Text(t("Room layout", "تخطيط الغرفة")).tag("room")
                    Text(t("People", "الأشخاص")).tag("people")
                    Text(t("One object", "غرض واحد")).tag("object")
                    Text(t("Path features", "معالم المسار")).tag("path")
                    Text(t("Read text", "قراءة النص")).tag("text")
                }
                Button(t("Ask about the camera view", "اسأل عن صورة الكاميرا")) {
                    model.readScene(cloud: false, question: sceneQuestion, focus: focus)
                }
                .font(.headline)
                .disabled(model.busy || model.simulation || !model.running)
                .accessibilityIdentifier("local-answer")
                Button(model.voice.listening ? t("Finish question", "إنهاء السؤال") : t("Talk", "تحدث")) {
                    if model.voice.listening { model.voice.finish() } else { model.startVoiceQuestion() }
                }
                .accessibilityIdentifier("voice-question")
                if model.voice.listening { Text(model.voice.transcript) }
                if !model.voice.message.isEmpty { Text(model.voice.message) }
                #if BLIND_DEVELOPER_CLOUD
                // Developer comparison builds only. The app build never sends a camera picture off the phone.
                Button(t("Ask with one photo · online", "اسأل بصورة واحدة · عبر الإنترنت")) { uploadConfirmed = true }
                    .disabled(model.busy || model.simulation || !model.running || model.offlineOnly)
                    .accessibilityIdentifier("cloud-answer")
                #endif
            } header: { Text(t("Ask", "اسأل")) }
            Section {
                if model.busy { ProgressView(t("Looking…", "أنظر…")) }
                if !model.message.isEmpty { Text(model.message) }
                Text(model.sceneAnswer.isEmpty ? t("No answer yet.", "لا توجد إجابة بعد.") : model.sceneAnswer)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("assistant-answer")
                // The speech gate already holds this back during urgent hazards.
                Button(t("Repeat answer", "كرر الإجابة")) { model.speakRequested(model.sceneAnswer) }
                    .disabled(model.sceneAnswer.isEmpty)
                Button(t("Stop descriptions, keep alerts", "أوقف الوصف وأبقِ التنبيهات")) { model.stopDescriptions() }
                    .accessibilityIdentifier("stop-descriptions")
            } header: { Text(t("Answer", "الإجابة")) }
            Section {
                Button(t("Read text as it appears", "اقرأ النص عند ظهوره")) { model.startReadingTool(.liveText) }
                Button(t("Read a whole page", "اقرأ صفحة كاملة")) { model.startReadingTool(.document) }
                Button(t("Scan a barcode or QR code", "امسح باركود أو رمز QR")) { model.startReadingTool(.barcode) }
                Button(t("Light detector", "كاشف الضوء")) { model.startReadingTool(.light) }
                NavigationLink(t("Explore a picture by touch", "استكشف صورة باللمس")) { ExplorePictureView(model: model) }
                    .accessibilityIdentifier("explore-picture")
                if model.readingTool != nil {
                    Button(t("Stop reading tool", "أوقف أداة القراءة")) { model.stopReadingTool(announce: true) }
                }
            } header: { Text(t("Reading tools", "أدوات القراءة")) }
            Section {
                if !model.assistantDialogue.goal.isEmpty { Text(t("Current goal: ", "الهدف الحالي: ") + model.assistantDialogue.goal) }
                TextField(t("New goal, for example: the bathroom", "هدف جديد، مثلاً: الحمام"), text: $model.objectiveDraft, axis: .vertical)
                    .accessibilityLabel(t("New goal", "هدف جديد"))
                Button(t("Set goal", "حدد الهدف")) { model.setAssistantObjective() }
                Button(t("Find my question on the saved map", "ابحث عن سؤالي في الخريطة المحفوظة")) { model.findMapDestination() }
                    .disabled(model.busy || model.indoor.map == nil || model.assistantQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("map-destination")
                Button(t("Clear goal and conversation", "امسح الهدف والمحادثة"), role: .destructive) { confirmClearConversation = true }
            } header: { Text(t("Goal", "الهدف")) } footer: {
                Text(t("Answers cover what the camera sees now. For directions, use Routes.", "الإجابات عما تراه الكاميرا الآن. للاتجاهات استخدم المسارات."))
            }
        }
        .navigationTitle(t("Ask and goals", "الأسئلة والأهداف"))
        .confirmationDialog(t("Clear the goal and recent conversation?", "مسح الهدف والمحادثة الأخيرة؟"), isPresented: $confirmClearConversation, titleVisibility: .visible) {
            Button(t("Clear", "امسح"), role: .destructive) { model.clearAssistantConversation() }
        }
        #if BLIND_DEVELOPER_CLOUD
        .confirmationDialog(t("Send this photo, question, goal, saved interests, up to six conversation turns, four recent description attempts and the matched room's saved inventory to the configured scene service?", "هل تريد إرسال الصورة والسؤال والهدف والاهتمامات المحفوظة وما يصل إلى ست رسائل وأربع محاولات وصف حديثة وعناصر الغرفة المطابقة المحفوظة إلى خدمة المشهد؟"),
                            isPresented: $uploadConfirmed, titleVisibility: .visible) {
            Button(t("Send photo and question", "إرسال الصورة والسؤال")) {
                model.readScene(cloud: true, question: sceneQuestion, focus: focus)
            }
        }
        #endif
    }
    private var sceneQuestion: String {
        let question = model.assistantQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty else { return question }
        let english = ["surroundings": "what is around me", "room": "the room layout", "people": "the people", "object": "the object in front of me", "path": "the path features", "text": "the text"]
        let arabic = ["surroundings": "ما حولي", "room": "تخطيط الغرفة", "people": "الأشخاص", "object": "الغرض أمامي", "path": "معالم المسار", "text": "النص"]
        return model.arabic ? "صف \(arabic[focus] ?? "ما حولي") في مجال الكاميرا الحالي." : "Describe \(english[focus] ?? "what is around me") in the current camera view."
    }

    /// Where am I, saved places, scanning, community maps and private maps.
    private var places: some View {
        List {
            Section {
                if let place = model.recognizedPlace {
                    Text(t("You are in: ", "أنت في: ") + place.name)
                    Button(t("Check this place for changes", "افحص هذا المكان بحثاً عن تغييرات")) { model.scanPlace(name: place.name, compare: true) }
                        .disabled(model.places.scanning)
                } else {
                    Text(t("Not sure where you are yet.", "لم أتأكد من مكانك بعد."))
                }
                if !model.placeRecoveryQuestion.isEmpty { Text(model.placeRecoveryQuestion) }
                Button(t("Continue without a place", "تابع دون تحديد المكان")) { model.continueWithoutPlaceMatch() }
                    .disabled(!model.running || model.simulation || model.places.scanning)
            } header: { Text(t("This place", "هذا المكان")) }
            Section {
                if model.places.places.isEmpty { Text(t("No places saved yet.", "لا توجد أماكن محفوظة بعد.")) }
                ForEach(model.places.places) { place in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name + ", " + "\(place.objects.count) " + t("things mapped", "أشياء مرسومة")).font(.headline)
                        NavigationLink(t("Room map and labels for ", "خريطة وتسميات ") + place.name) {
                            RoomDetailView(model: model, place: place)
                        }
                        Button(t("Recognize ", "تعرّف على ") + place.name) { model.recognize(place) }
                        Button(t("Delete ", "احذف ") + place.name, role: .destructive) { placesToDelete = [place] }
                    }
                }
                .onDelete { offsets in placesToDelete = offsets.map { model.places.places[$0] } }
            } header: { Text(t("Saved places", "الأماكن المحفوظة")) }
            Section {
                TextField(t("Place name", "اسم المكان"), text: $placeName)
                if model.places.scanning {
                    Text(model.places.message)
                    Button(t("Finish scan", "إنهاء المسح")) { model.places.finishScan() }
                        .disabled(model.places.finishing)
                } else {
                    Button(t("Start room scan", "ابدأ مسح الغرفة")) { model.scanPlace(name: placeName) }
                        .disabled(!model.running || model.simulation)
                }
            } header: { Text(t("Scan a place", "مسح مكان")) }
            Section {
                NavigationLink(t("Community maps", "خرائط المجتمع")) { CommunityMapsView(model: model) }
                    .accessibilityIdentifier("community-maps")
            } header: { Text(t("Public places", "الأماكن العامة")) }
            Section {
                Text(StatusText.localized(model.mapping.status, arabic: model.arabic))
                NavigationLink(t("Mapping progress", "تقدم رسم الخريطة")) { SurveyProgressView(model: model) }
                // No export: the 3D map database can hold camera pictures of the home (privacy rule).
                if model.mapping.exportURL != nil {
                    Button(t("Delete private map", "حذف الخريطة الخاصة"), role: .destructive) { deletePrivateMap = true }
                }
            } header: { Text(t("Private 3D map", "الخريطة الثلاثية الأبعاد الخاصة")) }
            Section {
                Text(String(format: model.arabic ? "المسافة المسجلة: %.1f متر" : "Recorded distance: %.1f metres", model.journeys.distance))
                ForEach(model.journeys.saved, id: \.id) { journey in
                    let title = journey.createdAt.formatted(date: .abbreviated, time: .shortened) + ", " + String(format: model.arabic ? "%.1f متر" : "%.1f metres", journey.distance)
                    VStack(alignment: .leading) {
                        Text(title)
                        // A journey is a trail of where the child walked: a helper confirms before sharing.
                        if shareJourney?.id == journey.id {
                            ShareLink(t("Share journey ", "شارك الرحلة ") + title, item: model.journeys.url(for: journey))
                        } else {
                            Button(t("Export journey ", "صدّر الرحلة ") + title) { shareJourney = journey }
                        }
                    }
                }
                .onDelete { offsets in journeysToDelete = offsets.map { model.journeys.saved[$0] } }
                if !model.journeys.message.isEmpty { Text(model.journeys.message) }
            } header: { Text(t("Journey history", "سجل الرحلات")) }
            if model.places.needsDeletionCleanup || !model.places.message.isEmpty {
                Section {
                    if model.places.needsDeletionCleanup {
                        Button(t("Retry removing deleted files", "أعد محاولة إزالة الملفات المحذوفة")) { model.places.retryDeletionCleanup() }
                    }
                    if !model.places.message.isEmpty && !model.places.scanning { Text(model.places.message) }
                }
            }
        }
        .confirmationDialog(t("Delete the saved private 3D map?", "حذف الخريطة الثلاثية الأبعاد المحفوظة؟"), isPresented: $deletePrivateMap, titleVisibility: .visible) {
            Button(t("Delete map", "حذف الخريطة"), role: .destructive) { model.mapping.deleteMap() }
        }
        .confirmationDialog(t("Delete this saved place and its pictures?", "حذف هذا المكان المحفوظ وصوره؟"),
                            isPresented: Binding(get: { !placesToDelete.isEmpty }, set: { if !$0 { placesToDelete = [] } }), titleVisibility: .visible) {
            Button(t("Delete place", "حذف المكان"), role: .destructive) { placesToDelete.forEach { model.deletePlace($0) }; placesToDelete = [] }
        }
        .confirmationDialog(t("Delete this journey?", "حذف هذه الرحلة؟"),
                            isPresented: Binding(get: { !journeysToDelete.isEmpty }, set: { if !$0 { journeysToDelete = [] } }), titleVisibility: .visible) {
            Button(t("Delete journey", "حذف الرحلة"), role: .destructive) { journeysToDelete.forEach { model.journeys.delete($0) }; journeysToDelete = [] }
        }
    }

    /// Indoor routes on a saved map (most-used steps first), body mount, and outdoor destinations.
    private var routes: some View {
        List {
            Section {
                if let map = model.indoor.map {
                    if let suggested = model.indoor.suggestedDestination {
                        Button(t("Use suggested destination", "استخدم الوجهة المقترحة") + ": " + suggested.localizedName(arabic: model.arabic)) { destinationNode = suggested.id }
                    }
                    Picker(t("Destination", "الوجهة"), selection: $destinationNode) {
                        Text(t("Select", "اختر")).tag("")
                        ForEach(map.nodes, id: \.id) { Text($0.localizedName(arabic: model.arabic)).tag($0.id) }
                    }
                    Picker(t("Starting landmark", "نقطة البداية"), selection: $startNode) {
                        Text(t("Select", "اختر")).tag("")
                        ForEach(map.nodes, id: \.id) { Text($0.localizedName(arabic: model.arabic)).tag($0.id) }
                    }
                    Button(t("Plan route", "خطط المسار")) {
                        do { try model.indoor.plan(from: startNode, to: destinationNode); importError = "" }
                        catch { importError = t("No accessible route found.", "لم يتم العثور على مسار مناسب.") }
                    }
                    .font(.headline)
                    .disabled(startNode.isEmpty || destinationNode.isEmpty)
                    Button(t("Hear next landmark", "اسمع المعلم التالي")) { model.indoorBeacon() }
                    Button(t("I'm at the landmark", "وصلت إلى المعلم")) { model.indoor.confirmArrival() }
                    Button(t("At the landmark, facing the next one: line up", "عند المعلم وباتجاه التالي: محاذاة")) { model.alignIndoor() }
                    Button(t("Way blocked, find another route", "الطريق مغلق، ابحث عن مسار آخر")) { model.indoor.blockNextLeg() }
                } else {
                    Text(t("No route map yet.", "لا توجد خريطة مسار بعد."))
                }
                if !model.indoor.message.isEmpty { Text(StatusText.localized(model.indoor.message, arabic: model.arabic)) }
                if !importError.isEmpty { Text(importError).foregroundStyle(.red) }
            } header: { Text(t("Indoor route", "مسار داخلي")) }
            Section {
                Toggle(t("Phone is fixed to my body, facing forward", "الهاتف مثبت على جسمي باتجاه الأمام"), isOn: $model.fixedBodyMount)
                    .disabled(!model.running || model.simulation)
            } header: { Text(t("Phone position", "وضع الهاتف")) } footer: {
                Text(t("Turn this off before holding the phone in your hand.", "أوقف هذا قبل حمل الهاتف بيدك."))
            }
            Section {
                TextField(t("Search nearby places", "ابحث عن أماكن قريبة"), text: $outdoorQuery)
                Button(t("Search", "بحث")) { model.outdoor.search(outdoorQuery) }
                    .disabled(outdoorQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !model.outdoor.message.isEmpty { Text(StatusText.localized(model.outdoor.message, arabic: model.arabic)) }
                ForEach(Array(model.outdoor.results.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name ?? t("Place", "مكان")).font(.headline).accessibilityAddTraits(.isHeader)
                        Button(t("Hear direction", "اسمع الاتجاه")) {
                            if model.running, model.detection.hazard == .observing, let cue = model.outdoor.bearing(to: item) {
                                model.feedback.beacon(sector: cue.sector, distance: min(10, cue.distance))
                                model.speakRequested(item.name ?? t("Destination", "الوجهة"))
                            } else {
                                model.speakRequested(t("I can't point the way yet. The camera and sensors need to be running and set up.", "لا أستطيع الإشارة إلى الطريق بعد. يجب تشغيل الكاميرا والحساسات وإعدادها."))
                            }
                        }
                        Button(t("Load walking directions", "حمّل اتجاهات المشي")) { model.outdoor.plan(to: item) }
                        Button(t("Open in Google Maps", "افتح في خرائط جوجل")) {
                            var url = URLComponents(string: "https://www.google.com/maps/dir/")!
                            let c = item.placemark.coordinate
                            url.queryItems = [URLQueryItem(name: "api", value: "1"),
                                URLQueryItem(name: "destination", value: "\(c.latitude),\(c.longitude)"),
                                URLQueryItem(name: "travelmode", value: "walking")]
                            if let url = url.url { openURL(url) }
                        }.disabled(model.offlineOnly)
                    }
                }
                ForEach(Array(model.outdoor.routeSteps.enumerated()), id: \.offset) { index, step in
                    Button(t("Step ", "الخطوة ") + "\(index + 1): " + step.instructions) { model.speakRequested(step.instructions) }
                }
            } header: { Text(t("Outdoor", "في الخارج")) }
            Section {
                Button(t("Import indoor route JSON", "استيراد ملف المسار الداخلي")) {
                    // Replacing a map loses its keep-out areas: confirm first.
                    if model.indoor.map != nil { confirmRouteImport = true } else { importing = true }
                }
                if let map = model.indoor.map {
                    NavigationLink(t("Keep-out areas", "المناطق المحظورة")) {
                        KeepOutZonesView(indoor: model.indoor, arabic: model.arabic)
                    }
                    if let url = model.indoor.exportURL {
                        if shareRouteMap { ShareLink(t("Share route map", "شارك خريطة المسار"), item: url) }
                        else { Button(t("Export route map", "صدّر خريطة المسار")) { shareRouteMap = true } }
                    }
                    Button(t("Delete route map", "احذف خريطة المسار"), role: .destructive) { confirmRouteDelete = true }
                    Text(map.surfaces == nil ? t("Route lines only; no wall or furniture shapes.", "خطوط المسار فقط دون أشكال الجدران والأثاث.") : t("Includes body and head clearance. Live alerts still needed.", "يشمل خلوص الجسم والرأس. التنبيهات المباشرة ما زالت لازمة."))
                    if let revision = map.packageRevision {
                        Text(t("Map version: ", "إصدار الخريطة: ") + revision)
                        if map.packageModified == true {
                            Text(t("Changed on this phone with keep-out areas.", "عُدّلت على هذا الهاتف بمناطق محظورة."))
                        }
                    }
                }
            } header: { Text(t("Route map", "خريطة المسار")) }
        }
        .confirmationDialog(t("Replace the route map? Its keep-out areas will be lost.", "استبدال خريطة المسار؟ ستُفقد المناطق المحظورة فيها."), isPresented: $confirmRouteImport, titleVisibility: .visible) {
            Button(t("Choose a new route map", "اختر خريطة مسار جديدة")) { importing = true }
        }
        .confirmationDialog(t("Delete the route map from this phone?", "حذف خريطة المسار من هذا الهاتف؟"), isPresented: $confirmRouteDelete, titleVisibility: .visible) {
            Button(t("Delete route map", "احذف خريطة المسار"), role: .destructive) { model.stopReturn(); model.indoor.deleteMap() }
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

    /// Settings, most-used first: how the assistant talks, asking and safety, you, devices, privacy.
    private var settings: some View {
        Form {
            Section {
                Picker(t("Detail", "التفاصيل"), selection: $model.detail) {
                    Text(t("Important only", "المهم فقط")).tag(DetailLevel.minimal)
                    Text(t("Balanced", "متوازن")).tag(DetailLevel.balanced)
                    Text(t("Detailed", "مفصل")).tag(DetailLevel.detailed)
                }
                Toggle(t("Describe surroundings automatically", "صف المحيط تلقائياً"), isOn: $model.ambientDescriptions)
                Picker(t("New rooms", "الغرف الجديدة"), selection: $model.firstVisitRooms) {
                    Text(t("Ask first", "اسأل أولاً")).tag(FirstVisitMode.offer)
                    Text(t("Describe the first time", "صف في المرة الأولى")).tag(FirstVisitMode.describe)
                    Text(t("Only when I ask", "فقط عندما أطلب")).tag(FirstVisitMode.never)
                }
                Stepper(t("Words per minute: ", "الكلمات في الدقيقة: ") + "\(model.wordsPerMinute)", value: $model.wordsPerMinute, in: 30...1800, step: 30)
                Stepper(t("Seconds between descriptions: ", "ثوانٍ بين الأوصاف: ") + "\(model.narrationInterval)", value: $model.narrationInterval, in: 5...60, step: 5)
                Toggle(t("Listen for yes or no after a question", "استمع لنعم أو لا بعد السؤال"), isOn: $model.listenAfterQuestions)
                Toggle("العربية · Arabic", isOn: $model.arabic)
                Button(t("Repeat the last description", "كرر الوصف الأخير")) { model.repeatDescription() }
            } header: { Text(t("How I talk", "طريقة كلامي")) } footer: {
                Text(t("VoiceOver sets the speaking speed. Danger alerts always come first.", "التعليق الصوتي يحدد سرعة الكلام. تنبيهات الخطر تأتي أولاً دائماً."))
            }
            Section {
                NavigationLink(t("Ask and goals", "الأسئلة والأهداف")) { assistant }
                    .accessibilityIdentifier("ask-screen")
                NavigationLink(t("Camera and safety", "الكاميرا والسلامة")) { monitor }
                    .accessibilityIdentifier("camera-screen")
                Button(t("Try practice (2 minutes)", "جرب التدريب (دقيقتان)")) { model.startSimulation(); selectedTab = "companion" }
                    .accessibilityIdentifier("home-practice")
            } header: { Text(t("Ask and safety", "الأسئلة والسلامة")) }
            Section {
                TextField(t("Your name", "اسمك"), text: $preferredNameDraft)
                    .accessibilityIdentifier("preferred-name")
                    .onAppear { preferredNameDraft = model.preferredName }
                Button(t("Save name", "احفظ الاسم")) { model.savePreferredName(preferredNameDraft) }
                    .accessibilityIdentifier("save-preferred-name")
                if !model.preferredName.isEmpty {
                    Button(t("Forget my name", "انسَ اسمي"), role: .destructive) { confirmForgetName = true }
                }
                if !model.profileStatus.isEmpty { Text(model.profileStatus) }
                NavigationLink(t("Interests", "الاهتمامات")) { AssistantPreferencesView(model: model) }
                    .accessibilityIdentifier("assistant-preferences")
                #if BLIND_FAMILIAR_PEOPLE
                NavigationLink(t("Familiar people (test)", "الأشخاص المألوفون (تجربة)")) { FamiliarPeopleView(model: model, experiment: model.familiarPeople) }
                    .accessibilityIdentifier("familiar-people")
                #endif
                NavigationLink(t("Saved memory", "الذاكرة المحفوظة")) { SavedMemoryView(model: model) }
                    .accessibilityIdentifier("saved-memory")
                NavigationLink(t("Recent descriptions", "الأوصاف الأخيرة")) { NarrationHistoryView(model: model) }
                    .accessibilityIdentifier("narration-history")
            } header: { Text(t("About you", "عنك")) }
            Section {
                NavigationLink(t("Belt and wristband", "الحزام والسوار")) { WearableSetupView(model: model) }
                    .accessibilityIdentifier("wearable-setup")
                Button(t("Reconnect microphone", "أعد توصيل الميكروفون")) { model.reconnectListening() }
                    .accessibilityIdentifier("reconnect-microphone")
                Button(t("Test voice and vibration", "اختبر الصوت والاهتزاز")) { model.testFeedback() }
            } header: { Text(t("Devices", "الأجهزة")) } footer: {
                Text(t("Vibration can be hard to feel in a harness. Check alerts with your headphones and belt.", "قد يصعب الشعور بالاهتزاز في الحامل. تحقق من التنبيهات بالسماعات والحزام."))
            }
            Section {
                Toggle(t("Offline only (no map downloads or outdoor search)", "دون إنترنت فقط (بلا تنزيل خرائط أو بحث خارجي)"), isOn: $model.offlineOnly)
                Toggle(t("Build private 3D map on next start", "ابنِ خريطة ثلاثية الأبعاد عند البدء التالي"), isOn: $model.buildPrivateMap)
                    .disabled(model.running || !model.mapping.available)
                if !model.mapping.available { Text(t("3D mapping needs the mapping build.", "الخرائط الثلاثية الأبعاد تحتاج إصدار الخرائط.")) }
            } header: { Text(t("Privacy and maps", "الخصوصية والخرائط")) } footer: {
                Text(t("Camera pictures, room pictures and saved items stay on this phone.", "تبقى صور الكاميرا وصور الغرف والأغراض المحفوظة على هذا الهاتف."))
            }
            Section {
                NavigationLink(t("Voice commands", "الأوامر الصوتية")) { voiceHelp }
                Text(LocalImageAssistant.status(arabic: model.arabic))
                if !model.localImageStatus.isEmpty { Text(model.localImageStatus) }
                Text(OfflineSummary.status(arabic: model.arabic))
                #if BLIND_DEVELOPER_CLOUD
                TextField("https://your-service.example", text: $model.serviceURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel(t("Scene service HTTPS address", "عنوان خدمة المشهد"))
                SecureField(t("Service access token", "رمز الوصول للخدمة"), text: $relayToken)
                Button(t("Save access token", "حفظ رمز الوصول")) { TokenStore.save(relayToken) }
                Button(t("Check connection · no photo", "فحص الاتصال دون صورة")) { model.checkSceneConnection() }.disabled(model.offlineOnly)
                if !model.serviceStatus.isEmpty { Text(model.serviceStatus) }
                Text(t("Only the service access token belongs here. Provider API credentials stay on the server.",
                       "أدخل رمز الوصول للخدمة فقط. تبقى مفاتيح مزود الذكاء الاصطناعي على الخادم."))
                #endif
            } header: { Text(t("Help and status", "المساعدة والحالة")) }
        }
        .confirmationDialog(t("Forget your saved name?", "نسيان اسمك المحفوظ؟"), isPresented: $confirmForgetName, titleVisibility: .visible) {
            Button(t("Forget name", "انسَ الاسم"), role: .destructive) { model.savePreferredName(""); preferredNameDraft = model.preferredName }
        }
    }

    /// One place for the spoken commands, instead of long paragraphs on the Settings screen.
    private var voiceHelp: some View {
        List {
            Section {
                Text(t("Help me find my cup.", "ساعدني ألاقي كوبي."))
                Text(t("I left my cup on the kitchen table.", "تركت كوبي على طاولة المطبخ."))
                Text(t("Remember my book here.", "تذكر كتابي هنا."))
                Text(t("This is my cup. (Hold it and turn it slowly.)", "هذا كوبي. (أمسكه وأدره ببطء.)"))
                Text(t("Where is the exit sign?", "أين لافتة الخروج؟"))
                Text(t("What colour is this shirt?", "ما لون هذا القميص؟"))
            } header: { Text(t("Finding things", "البحث عن الأشياء")) }
            Section {
                Text(t("Read text.", "اقرأ النص."))
                Text(t("Read the page.", "اقرأ الصفحة."))
                Text(t("Scan the barcode. Then: call this apple juice.", "امسح الباركود. ثم: سمّه عصير تفاح."))
                Text(t("Is the light on?", "هل النور مضاء؟"))
                Text(t("Stop reading.", "أوقف القراءة."))
            } header: { Text(t("Reading", "القراءة")) }
            Section {
                Text(t("Quiet", "أوقف الوصف"))
                Text(t("Resume", "استأنف"))
                Text(t("Repeat", "كرر"))
                Text(t("More detail, or less detail", "تفاصيل أكثر، أو تفاصيل أقل"))
                Text(t("More information, or less information", "معلومات أكثر، أو معلومات أقل"))
            } header: { Text(t("Descriptions", "الأوصاف")) }
            Section {
                Text(t("Take me to the kitchen.", "خذني إلى المطبخ."))
                Text(t("I'm standing on a level floor.", "أنا واقف على أرض مستوية."))
            } header: { Text(t("Moving", "الحركة")) } footer: {
                Text(t("Arabic text reading depends on the iPhone's language support.", "قراءة النص العربي تعتمد على دعم اللغة في الآيفون."))
            }
        }
        .navigationTitle(t("Voice commands", "الأوامر الصوتية"))
    }
}

private struct WearableSetupView: View {
    @ObservedObject var model: NavigationModel
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    var body: some View {
        Form {
            Section {
                Text(StatusText.localized(model.wearableStatus, arabic: model.arabic))
                Text(t("Sensors sending readings: ", "حساسات ترسل قراءات: ") + "\(model.wearables.freshSensorCount)")
            } header: { Text(t("Status", "الحالة")) }
            Section {
                Button(t("Connect belt & wristband", "توصيل الحزام والسوار")) { model.connectWearables() }
                ForEach(model.wearables.discovered, id: \.identifier) { peripheral in
                    Button(t("Pair ", "اقتران ") + (peripheral.name ?? t("unnamed device", "جهاز دون اسم"))) {
                        model.wearables.select(peripheral)
                    }
                }
                // Reconnect instead of a plain disconnect: the belt must not be left off.
                Button(t("Reconnect belt and wristband", "أعد توصيل الحزام والسوار")) { model.wearables.disconnect(); model.connectWearables() }
            } header: { Text(t("Connect", "التوصيل")) }
            Section {
                Button(t("Calibrate belt", "معايرة الحزام")) { model.calibrateBelt() }
                Button(t("Make the belt buzz to find it", "اجعل الحزام يهتز لتجده")) { model.identifyBelt() }
            } header: { Text(t("Belt", "الحزام")) }
            if let distance = model.wearables.wristDistance {
                Section {
                    Text(t("Pointing distance: ", "مسافة الإشارة: ") + String(format: model.arabic ? "%.2f متر" : "%.2f metres", distance))
                    Button(t("Say pointing distance", "انطق مسافة الإشارة")) {
                        model.speakRequested(String(format: model.arabic ? "المسافة %.2f متر" : "Distance %.2f metres", distance))
                    }
                } header: { Text(t("Wristband", "السوار")) }
            }
        }
        .navigationTitle(t("Belt and wristband", "الحزام والسوار"))
    }
}
