import SwiftUI
import UniformTypeIdentifiers
import BlindCore

@MainActor struct CommunityMapsView: View {
    @ObservedObject var model: NavigationModel
    @StateObject private var library = CommunityLibrary()
    @State private var repository = ""
    @State private var filter = ""
    @State private var importing = false
    @State private var author = ""
    @State private var license = ""
    @State private var exportURL: URL?
    @State private var preparingExport = false
    @State private var exportReview = false
    @State private var publicReview = false
    @State private var deleteCandidate: InstalledPlacePackage?
    @State private var damagedCandidate: CommunityFileIssue?
    @State private var error = ""
    @State private var venueType = ""
    @State private var venuePermission = false
    @State private var confirmRouteReplace = false
    private let venueTypes = ["mall", "restaurant", "coffee shop", "park", "zoo", "museum", "family entertainment venue", "other public place"]
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    var body: some View {
        List {
            Section {
                if library.installed.isEmpty { Text(t("No public maps saved yet.", "لا توجد خرائط عامة محفوظة بعد.")) }
                ForEach(library.installed.filter { filter.isEmpty || $0.package.name.localizedCaseInsensitiveContains(filter) }) { item in
                    let name = item.package.localizedName(arabic: model.arabic)
                    VStack(alignment: .leading) {
                        Button(t("Open ", "افتح ") + name) { exportURL = nil; library.review(item) }
                        Button(t("Remove ", "أزل ") + name, role: .destructive) { deleteCandidate = item }
                            .disabled(library.busy)
                    }
                }
                Button(t("Refresh saved maps", "حدّث الخرائط المحفوظة")) { library.reload() }.disabled(library.busy)
                ForEach(library.fileIssues) { issue in
                    VStack(alignment: .leading) {
                        Text(t("A saved file is damaged and was left out: ", "ملف محفوظ تالف وتم استبعاده: ") + issue.message)
                        if issue.removable {
                            Button(t("Remove damaged file", "إزالة الملف التالف"), role: .destructive) { damagedCandidate = issue }.disabled(library.busy)
                        }
                    }
                }
            } header: { Text(t("Saved public maps", "الخرائط العامة المحفوظة")) } footer: {
                Text(t("Saved maps work offline. A map does not tell me where you are.", "الخرائط المحفوظة تعمل دون إنترنت. الخريطة لا تخبرني بمكانك."))
            }
            Section {
                Button(t("Import a place package from Files", "استيراد حزمة مكان من الملفات")) { importing = true }.disabled(library.busy)
                    .accessibilityIdentifier("community-import")
                TextField(t("Map library address (owner/name)", "عنوان مكتبة الخرائط (المالك/الاسم)"), text: $repository)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(t("Find public maps online", "ابحث عن خرائط عامة عبر الإنترنت")) { library.search(repository: repository) }
                    .disabled(model.offlineOnly || library.busy)
                    .accessibilityIdentifier("community-search")
                if library.hasNextPage {
                    Button(t("More results", "نتائج أكثر")) { library.search(repository: repository, more: true) }
                        .disabled(model.offlineOnly || library.busy)
                }
                TextField(t("Filter maps", "صفِّ الخرائط"), text: $filter)
                ForEach(library.releases.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.tag.localizedCaseInsensitiveContains(filter) }) { release in
                    Button(t("Download ", "نزّل ") + release.name + ", " + ByteCountFormatter.string(fromByteCount: Int64(release.bytes), countStyle: .file)) {
                        exportURL = nil; library.download(release)
                    }
                    .disabled(model.offlineOnly || library.busy)
                }
                if library.busy { ProgressView(t("Working…", "جارٍ العمل…")); Button(t("Cancel", "إلغاء")) { library.cancel() } }
                if model.offlineOnly { Text(t("Online search is off. Turn off \"Offline only\" in Settings to search.", "البحث عبر الإنترنت متوقف. أوقف «دون إنترنت فقط» في الإعدادات للبحث.")) }
                if !library.status.isEmpty { Text(StatusText.localized(library.status, arabic: model.arabic)) }
                if !error.isEmpty { Text(error) }
            } header: { Text(t("Get a map", "احصل على خريطة")) }
            if let package = library.preview {
                Section(t("Review this package", "مراجعة الحزمة")) {
                    Text(package.localizedName(arabic: model.arabic)).font(.headline)
                    Text(t("Revision: ", "المراجعة: ") + package.revision)
                    Text(t("Contributor: ", "المساهم: ") + package.author)
                    Text(t("License: ", "الترخيص: ") + package.license)
                    Text(t("Visibility: ", "المشاركة: ") + package.visibility)
                    Text(t("Source: ", "المصدر: ") + package.provenance)
                    Text(package.description)
                    Text(t("Last surveyed: ", "آخر مسح: ") + (package.surveyedAt ?? t("Not supplied", "غير مذكور")))
                    ForEach(package.coverageGaps, id: \.self) { Text(t("Coverage gap: ", "نقص في التغطية: ") + $0) }
                    Text(t("A valid file does not prove the place is right or the way is clear.", "الملف السليم لا يثبت صحة المكان أو خلو الطريق."))
                    Button(t("Save this revision offline", "حفظ هذه المراجعة دون إنترنت")) { library.savePreview() }.disabled(library.busy)
                    if package.routeMap != nil && package.localization == "manual-landmarks" {
                        // The companion is always on, so the route map is replaced with a confirmation
                        // instead of stopping monitoring; position must then be lined up again.
                        Button(t("Use this map in Routes", "استخدم هذه الخريطة في المسارات")) { confirmRouteReplace = true }
                            .disabled(library.busy || preparingExport)
                    }
                    Button(t("Review export and sharing", "مراجعة التصدير والمشاركة")) { exportReview = true }.disabled(preparingExport)
                    if package.visibility == "private" {
                        Button(t("Prepare a public-sharing copy", "إعداد نسخة للمشاركة العامة")) { publicReview = true }
                            .disabled(library.busy || preparingExport || venueType.isEmpty || !venuePermission)
                        if venueType.isEmpty || !venuePermission {
                            Text(t("To share publicly, choose the kind of public place and confirm the venue's permission below.", "للمشاركة العامة، اختر نوع المكان العام وأكد إذن المكان أدناه."))
                        }
                    }
                    if let exportURL { ShareLink(t("Share reviewed package", "مشاركة الحزمة المراجعة"), item: exportURL) }
                }
                Section(t("Floors and rooms", "الطوابق والغرف")) {
                    ForEach(package.floors) { floor in
                        VStack(alignment: .leading) {
                            Text(floor.name).font(.headline)
                            ForEach(package.rooms.filter { $0.floorID == floor.id }) { room in
                                Text(model.arabic ? (room.nameArabic ?? room.name) : room.name)
                                if !room.description.isEmpty { Text(room.description) }
                            }
                        }
                    }
                    if let map = package.routeMap {
                        ForEach(map.nodes, id: \.id) { node in
                            Text(node.localizedName(arabic: model.arabic) + " · " + node.level)
                        }
                    }
                }
                Section(t("Mapped connections", "الوصلات المرسومة")) {
                    if package.connections.isEmpty { Text(t("No room connections supplied. Adjacency is not inferred.", "لم تُرفق وصلات بين الغرف. لا يُفترض اتصال الغرف تلقائياً.")) }
                    ForEach(package.connections) { connection in
                        let from = package.rooms.first { $0.id == connection.fromRoomID }?.name ?? connection.fromRoomID
                        let to = package.rooms.first { $0.id == connection.toRoomID }?.name ?? connection.toRoomID
                        Text(t("\(from) to \(to): \(connection.kind), \(connection.state)", "من \(from) إلى \(to): \(connection.kind)، \(connection.state)"))
                    }
                }
                Section(t("Contributor review claims", "ادعاءات مراجعة المساهمين")) {
                    if package.reviews.isEmpty { Text(t("No review claims supplied for this revision.", "لم تُرفق مراجعات لهذه النسخة.")) }
                    ForEach(package.reviews) { review in
                        VStack(alignment: .leading) {
                            Text("\(review.reviewer) · \(review.scope) · \(review.date)")
                            Text(review.method); Text(review.limitations)
                            // Downloaded packages are untrusted: only https links, with the site named.
                            if let value = review.evidenceURL, let url = URL(string: value), url.scheme == "https", let host = url.host {
                                Link(t("Open review evidence on ", "افتح أدلة المراجعة على ") + host, destination: url)
                            }
                        }
                    }
                    Text(t("These are unsigned contributor statements. Popularity and star counts are not evidence of navigation safety.", "هذه أقوال غير موقعة من المساهمين. الشهرة وعدد النجوم ليسا دليلاً على سلامة التنقل."))
                }
            }
            Section(t("Prepare a contribution", "إعداد مساهمة")) {
                TextField(t("Contributor name", "اسم المساهم"), text: $author)
                TextField(t("Data license or permission statement", "ترخيص البيانات أو بيان الإذن"), text: $license)
                // Public library: public places only, with the venue's permission (never homes).
                Picker(t("Kind of public place", "نوع المكان العام"), selection: $venueType) {
                    Text(t("Choose", "اختر")).tag("")
                    ForEach(venueTypes, id: \.self) { Text($0).tag($0) }
                }
                Toggle(t("The venue gave permission, and this is not a home", "المكان أعطى الإذن، وليس منزلاً"), isOn: $venuePermission)
                Button(t("Draft package from loaded route map", "إعداد حزمة من خريطة المسارات الحالية")) {
                    guard let map = model.indoor.map else { return }
                    exportURL = nil
                    library.draft(map: map, author: author, license: license + " · Public venue (\(venueType)); venue permission confirmed by contributor.")
                }.disabled(model.indoor.map == nil || author.isEmpty || license.isEmpty || venueType.isEmpty || !venuePermission || library.busy)
                Text(t("Only the map and what you type here. No photos or personal memory.", "الخريطة وما تكتبه هنا فقط. لا صور ولا ذاكرة شخصية."))
            }
        }
        .navigationTitle(t("Community maps", "خرائط المجتمع"))
        .onAppear { library.networkAllowed = !model.offlineOnly }
        .onChange(of: model.offlineOnly) { _, value in library.networkAllowed = !value }
        .onDisappear { library.cancel() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result { case let .success(url): exportURL = nil; library.importFile(url); case let .failure(error): self.error = error.localizedDescription }
        }
        .confirmationDialog(t("Share the entire reviewed package, including room names and geometry? Only share places you have permission to disclose.", "هل تريد مشاركة الحزمة المراجعة كاملة، بما فيها أسماء الغرف وقياساتها؟ شارك الأماكن التي لديك إذن بالكشف عنها فقط."), isPresented: $exportReview, titleVisibility: .visible) {
            Button(t("Prepare reviewed export", "إعداد التصدير المراجع")) {
                preparingExport = true
                let id = library.preview?.id, revision = library.preview?.revision
                Task { @MainActor in
                    defer { preparingExport = false }
                    do {
                        let url = try await library.exportedPreview()
                        guard library.preview?.id == id, library.preview?.revision == revision else { return }
                        exportURL = url
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
        .confirmationDialog(t("Create a public-sharing draft? Confirm permission to disclose every name, description and coordinate in this package. Nothing is published automatically.", "إنشاء مسودة مشاركة عامة؟ أكد إذنك بالكشف عن جميع الأسماء والأوصاف والإحداثيات. لا يُنشر شيء تلقائياً."), isPresented: $publicReview, titleVisibility: .visible) {
            Button(t("Create public draft for review", "إنشاء مسودة عامة للمراجعة")) { exportURL = nil; library.preparePublicCopy() }
        }
        .confirmationDialog(t("Replace the route map? You will need to line up at a landmark again.", "استبدال خريطة المسار؟ ستحتاج إلى المحاذاة عند معلم مجدداً."), isPresented: $confirmRouteReplace, titleVisibility: .visible) {
            Button(t("Replace route map", "استبدل خريطة المسار")) {
                guard let package = library.preview else { return }
                preparingExport = true
                Task { @MainActor in
                    defer { preparingExport = false }
                    do {
                        _ = try await CommunityPackageStorage().install(package)
                        library.reload()
                        model.stopReturn(); model.indoor.invalidatePosition()
                        try model.indoor.loadCommunity(package); error = ""
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
        .confirmationDialog(t("Remove this downloaded revision?", "إزالة هذه المراجعة المحملة؟"), isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
            if let item = deleteCandidate { Button(t("Remove revision", "إزالة المراجعة"), role: .destructive) { library.remove(item); deleteCandidate = nil } }
        }
        .confirmationDialog(t("Remove this damaged file so it can be downloaded again?", "إزالة الملف التالف حتى يمكن تنزيله مجدداً؟"), isPresented: Binding(get: { damagedCandidate != nil }, set: { if !$0 { damagedCandidate = nil } })) {
            if let issue = damagedCandidate { Button(t("Remove damaged file", "إزالة الملف التالف"), role: .destructive) { library.removeDamaged(issue); damagedCandidate = nil } }
        }
    }
}
