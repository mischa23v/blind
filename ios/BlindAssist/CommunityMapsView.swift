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
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    var body: some View {
        List {
            Section(t("Download community maps", "تنزيل خرائط المجتمع")) {
                Text(t("Download before a visit and preview rooms, entrances and coverage offline. A saved map does not establish your current position.", "نزّل الخريطة قبل الزيارة وراجع الغرف والمداخل والتغطية دون إنترنت. الخريطة المحفوظة لا تثبت موقعك الحالي."))
                TextField(t("GitHub repository: owner/repository", "مستودع GitHub: المالك/المستودع"), text: $repository)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(t("Find public map releases", "البحث عن إصدارات الخرائط العامة")) { library.search(repository: repository) }
                    .disabled(model.offlineOnly || library.busy)
                    .accessibilityIdentifier("community-search")
                if library.hasNextPage {
                    Button(t("Load next release page", "تحميل صفحة الإصدارات التالية")) { library.search(repository: repository, more: true) }
                        .disabled(model.offlineOnly || library.busy)
                }
                TextField(t("Filter downloaded and listed maps", "تصفية الخرائط المحفوظة والمدرجة"), text: $filter)
                ForEach(library.releases.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.tag.localizedCaseInsensitiveContains(filter) }) { release in
                    VStack(alignment: .leading) {
                        Text(release.name).font(.headline)
                        Text("\(release.tag) · \(ByteCountFormatter.string(fromByteCount: Int64(release.bytes), countStyle: .file))")
                        Button(t("Download for review", "تنزيل للمراجعة")) { exportURL = nil; library.download(release) }
                            .disabled(model.offlineOnly || library.busy)
                    }
                }
                if library.busy { ProgressView(t("Working…", "جارٍ العمل…")); Button(t("Cancel", "إلغاء")) { library.cancel() } }
                if model.offlineOnly { Text(t("Enable network access in Settings to search or download. Local import and saved maps work offline.", "فعّل الاتصال في الإعدادات للبحث أو التنزيل. الاستيراد المحلي والخرائط المحفوظة يعملان دون إنترنت.")) }
                Button(t("Import a place package from Files", "استيراد حزمة مكان من الملفات")) { importing = true }.disabled(library.busy)
                    .accessibilityIdentifier("community-import")
                if !library.status.isEmpty { Text(library.status) }
                if !error.isEmpty { Text(error) }
            }
            Section(t("Offline revisions", "المراجعات المحفوظة")) {
                Button(t("Refresh offline library", "تحديث المكتبة المحفوظة")) { library.reload() }.disabled(library.busy)
                if library.installed.isEmpty { Text(t("No community maps saved yet.", "لا توجد خرائط مجتمع محفوظة بعد.")) }
                ForEach(library.installed.filter { filter.isEmpty || $0.package.name.localizedCaseInsensitiveContains(filter) }) { item in
                    VStack(alignment: .leading) {
                        Button(item.package.localizedName(arabic: model.arabic)) { exportURL = nil; library.review(item) }
                        Text(t("Revision: ", "المراجعة: ") + item.package.revision).font(.caption)
                        Button(t("Remove this offline revision", "إزالة هذه المراجعة المحفوظة"), role: .destructive) { deleteCandidate = item }
                            .disabled(library.busy)
                    }
                }
                ForEach(library.fileIssues) { issue in
                    VStack(alignment: .leading) {
                        Text(t("A saved file could not be verified and was excluded. Other valid maps remain available.", "تعذر التحقق من ملف محفوظ فتم استبعاده. تبقى الخرائط السليمة متاحة."))
                        Text(issue.message)
                        if issue.removable {
                            Button(t("Remove damaged file", "إزالة الملف التالف"), role: .destructive) { damagedCandidate = issue }.disabled(library.busy)
                        }
                    }
                }
            }
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
                    Text(t("Format and checksum checks do not verify the place, contributor identity or current clearance.", "فحص التنسيق والبصمة لا يتحقق من المكان أو هوية المساهم أو خلو المسار حالياً."))
                    Button(t("Save this revision offline", "حفظ هذه المراجعة دون إنترنت")) { library.savePreview() }.disabled(library.busy)
                    if package.routeMap != nil && package.localization == "manual-landmarks" {
                        Button(t("Use this revision in Routes", "استخدام هذه المراجعة في المسارات")) {
                            preparingExport = true
                            Task { @MainActor in
                                defer { preparingExport = false }
                                do {
                                    guard !model.running else { throw CommunityError.conflict }
                                    _ = try await CommunityPackageStorage().install(package)
                                    guard !model.running else { throw CommunityError.conflict }
                                    try model.indoor.loadCommunity(package); error = ""
                                } catch { self.error = error.localizedDescription }
                            }
                        }.disabled(model.running || library.busy || preparingExport)
                        Text(t("Stop monitoring before replacing route data. Downloading or saving never changes an active route; alignment must be established separately.", "أوقف الرصد قبل استبدال بيانات المسار. التنزيل والحفظ لا يغيران المسار النشط؛ يجب تحديد المحاذاة بشكل مستقل."))
                    }
                    Button(t("Review export and sharing", "مراجعة التصدير والمشاركة")) { exportReview = true }.disabled(preparingExport)
                    if package.visibility == "private" {
                        Button(t("Prepare a public-sharing copy", "إعداد نسخة للمشاركة العامة")) { publicReview = true }
                            .disabled(library.busy || preparingExport)
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
                        Text("\(from) → \(to): \(connection.kind), \(connection.state)")
                    }
                }
                Section(t("Contributor review claims", "ادعاءات مراجعة المساهمين")) {
                    if package.reviews.isEmpty { Text(t("No review claims supplied for this revision.", "لم تُرفق مراجعات لهذه النسخة.")) }
                    ForEach(package.reviews) { review in
                        VStack(alignment: .leading) {
                            Text("\(review.reviewer) · \(review.scope) · \(review.date)")
                            Text(review.method); Text(review.limitations)
                            if let value = review.evidenceURL, let url = URL(string: value) { Link(t("Open review evidence", "فتح أدلة المراجعة"), destination: url) }
                        }
                    }
                    Text(t("These are unsigned contributor statements. Popularity and star counts are not evidence of navigation safety.", "هذه أقوال غير موقعة من المساهمين. الشهرة وعدد النجوم ليسا دليلاً على سلامة التنقل."))
                }
            }
            Section(t("Prepare a contribution", "إعداد مساهمة")) {
                TextField(t("Contributor name", "اسم المساهم"), text: $author)
                TextField(t("Data license or permission statement", "ترخيص البيانات أو بيان الإذن"), text: $license)
                Button(t("Draft package from loaded route map", "إعداد حزمة من خريطة المسارات الحالية")) {
                    guard let map = model.indoor.map else { return }
                    exportURL = nil; library.draft(map: map, author: author, license: license)
                }.disabled(model.indoor.map == nil || author.isEmpty || license.isEmpty || library.busy)
                Text(t("The draft includes only the loaded map and information entered here. Review every place name and coordinate before sharing. Personal memory, photos and conversation are not collected by this exporter.", "تشمل المسودة الخريطة الحالية والمعلومات المدخلة هنا فقط. راجع أسماء الأماكن والإحداثيات قبل المشاركة. لا يجمع التصدير الذاكرة الشخصية أو الصور أو المحادثة."))
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
        .confirmationDialog(t("Remove this downloaded revision?", "إزالة هذه المراجعة المحملة؟"), isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
            if let item = deleteCandidate { Button(t("Remove revision", "إزالة المراجعة"), role: .destructive) { library.remove(item); deleteCandidate = nil } }
        }
        .confirmationDialog(t("Remove this damaged file so it can be downloaded again?", "إزالة الملف التالف حتى يمكن تنزيله مجدداً؟"), isPresented: Binding(get: { damagedCandidate != nil }, set: { if !$0 { damagedCandidate = nil } })) {
            if let issue = damagedCandidate { Button(t("Remove damaged file", "إزالة الملف التالف"), role: .destructive) { library.removeDamaged(issue); damagedCandidate = nil } }
        }
    }
}
