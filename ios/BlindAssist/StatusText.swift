import Foundation

/// Arabic for the status lines set by helpers that work in English (wearables, outdoor search,
/// the private 3D map and the community map library). Translated where the line is shown, so a
/// language change applies at once. Unknown lines (system errors) are shown unchanged.
enum StatusText {
    private static let arabic: [String: String] = [
        // Wearables (BeltLink).
        "Disconnected": "غير متصل",
        "Connecting to wearable": "جارٍ الاتصال بالجهاز القابل للارتداء",
        "Looking for belt and wristband": "أبحث عن الحزام والسوار",
        "Bluetooth permission denied": "لم يُسمح باستخدام البلوتوث",
        "Bluetooth is off": "البلوتوث متوقف",
        "Bluetooth unavailable": "البلوتوث غير متاح",
        "Connection failed": "فشل الاتصال",
        "Wearable disconnected": "انقطع اتصال الجهاز القابل للارتداء",
        "Service discovery failed": "تعذر العثور على خدمة الجهاز",
        "Characteristic discovery failed": "تعذر العثور على قنوات الجهاز",
        "Wearable sensor subscription unavailable": "تعذر الاشتراك في حساسات الجهاز",
        "Wearable reading unavailable; check pairing": "تعذرت قراءة الجهاز؛ تحقق من الاقتران",
        "A device with this role is already connected": "جهاز بهذا الدور متصل بالفعل",
        "Connected": "متصل",
        "Wearable command failed": "فشل أمر الجهاز القابل للارتداء",
        // Outdoor search and routes (OutdoorNavigator).
        "Choose an outdoor destination.": "اختر وجهة خارجية.",
        "Outdoor search needs internet access enabled in Settings.": "البحث الخارجي يحتاج تفعيل الإنترنت في الإعدادات.",
        "Searching…": "جارٍ البحث…",
        "Select a destination.": "اختر وجهة.",
        "Destination search unavailable.": "البحث عن الوجهة غير متاح.",
        "New outdoor routes need internet access enabled in Settings.": "المسارات الخارجية الجديدة تحتاج تفعيل الإنترنت في الإعدادات.",
        "An accurate current GPS fix is required.": "يلزم تحديد دقيق وحديث للموقع.",
        "Walking route loaded. Confirm crossings independently.": "حُمّل مسار المشي. تأكد من المعابر بنفسك.",
        "Route unavailable.": "المسار غير متاح.",
        "Location unavailable.": "الموقع غير متاح.",
        "Location permission denied.": "لم يُسمح بتحديد الموقع.",
        // Private 3D map (NativeMapping).
        "Native RTAB-Map build required for growing 3D maps.": "تحتاج الخرائط الثلاثية الأبعاد المتنامية إلى إصدار RTAB-Map الأصلي.",
        "Private 3D map deleted.": "حُذفت الخريطة الثلاثية الأبعاد الخاصة.",
        "Could not delete the private map.": "تعذر حذف الخريطة الخاصة.",
        "Building your private 3D map on this phone.": "أبني خريطتك الثلاثية الأبعاد الخاصة على هذا الهاتف.",
        "Private 3D map saved on this phone.": "حُفظت الخريطة الثلاثية الأبعاد الخاصة على هذا الهاتف.",
        // Community map library (CommunityLibrary, CommunityError).
        "No compatible map assets on this release page. You can check the next page.": "لا توجد خرائط متوافقة في هذه الصفحة. يمكنك فتح الصفحة التالية.",
        "Choose a package to download and review. GitHub stars do not verify its map.": "اختر حزمة لتنزيلها ومراجعتها. نجوم GitHub لا تثبت صحة الخريطة.",
        "Downloaded for review. Publisher checksum was not supplied; source identity and review claims remain unverified.": "نُزّلت للمراجعة. لم يقدّم الناشر رمز التحقق؛ مصدرها وتقييماتها غير مؤكدة.",
        "Download checksum matched. Review claims and physical layout still require verification.": "تطابق رمز التحقق. ما زالت التقييمات والتخطيط الفعلي بحاجة إلى تحقق.",
        "Imported for review. Not activated as your current location.": "استوردت للمراجعة. لم تُعتمد موقعاً حالياً لك.",
        "Offline saved revision. This is a place preview, not your current location.": "مراجعة محفوظة دون إنترنت. هذه معاينة للمكان وليست موقعك الحالي.",
        "Saved for offline use. Active route unchanged.": "حُفظت للاستخدام دون إنترنت. المسار الحالي لم يتغير.",
        "Offline revision removed. Any separately loaded route remains unchanged.": "حُذفت المراجعة المحفوظة. أي مسار محمّل بشكل منفصل لم يتغير.",
        "Damaged file removed. You can import or download that revision again.": "حُذف الملف التالف. يمكنك استيراد تلك المراجعة أو تنزيلها مجدداً.",
        "Private draft. Review names, geometry, ownership and license before sharing.": "مسودة خاصة. راجع الأسماء والشكل والملكية والترخيص قبل المشاركة.",
        "Public-sharing draft only. Previous review claims were removed because this is a new revision. Review before exporting; nothing is published.": "مسودة للمشاركة العامة فقط. أُزيلت التقييمات السابقة لأنها مراجعة جديدة. راجعها قبل التصدير؛ لم يُنشر شيء.",
        "The map package or repository address is unsupported.": "حزمة الخريطة أو عنوان المستودع غير مدعوم.",
        "Offline mode is enabled. Downloaded maps remain available.": "وضع عدم الاتصال مفعّل. الخرائط المنزّلة ما زالت متاحة.",
        "This package exceeds the download size limit.": "هذه الحزمة أكبر من حد التنزيل.",
        "The download checksum does not match. Nothing was installed.": "رمز التحقق لا يطابق. لم يُثبَّت شيء.",
        "This revision already exists with different contents. Ask the contributor for a new revision.": "هذه المراجعة موجودة بمحتوى مختلف. اطلب من المساهم مراجعة جديدة.",
        "The offline library is full. Remove an unused revision before downloading more.": "المكتبة المحفوظة ممتلئة. احذف مراجعة غير مستخدمة قبل تنزيل المزيد.",
        "This map revision is no longer available locally.": "مراجعة الخريطة هذه لم تعد متاحة على الهاتف.",
        // Indoor routes (IndoorNavigator's first prompt).
        "Import an authored indoor route map.": "استورد خريطة مسار داخلية معدّة."
    ]

    static func localized(_ english: String, arabic useArabic: Bool) -> String {
        guard useArabic else { return english }
        if let translated = arabic[english] { return translated }
        if english.hasPrefix("The map service returned HTTP ") {
            let code = english.dropFirst("The map service returned HTTP ".count).prefix { $0.isNumber }
            return "أعادت خدمة الخرائط الرمز \(code). أعد المحاولة لاحقاً."
        }
        if english.hasPrefix("Local mapping could not start") { return "تعذر بدء رسم الخريطة على الهاتف." }
        return english
    }
}
