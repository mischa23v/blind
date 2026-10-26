import Foundation

/// Fixed mobility phrases do not depend on a language model or a network.
public enum GuidanceText {
    public static func detection(_ detection: Detection, arabic: Bool) -> String {
        if detection.hazard.isUrgent && detection.reason == .visualStairs {
            return arabic ? "توقف. قد توجد درجات في صورة الكاميرا. لم تتأكد المسافة." : "Stop. Possible stairs in the camera view. Distance is unconfirmed."
        }
        if detection.hazard.isUrgent && detection.reason == .bodyEnvelope {
            return arabic ? "توقف. رصدت الكاميرا عائقاً محتملاً قريباً من جسمك أو أغراضك." : "Stop. The camera detected a possible obstacle near your body or equipment."
        }
        guard detection.hazard == .uncertain, let reason = detection.reason else {
            return hazard(detection.hazard, arabic: arabic)
        }
        switch reason {
        case .trackingUnavailable, .localizing:
            return arabic ? "توقف. موقع الهاتف غير مؤكد. أبقِ الهاتف ثابتاً." : "Stop. Phone position is uncertain. Keep the phone steady."
        case .depthUnavailable:
            return arabic ? "توقف. قياس المسافة غير متاح. اطلب مساعدة لفحص الكاميرا." : "Stop. Depth readings are unavailable. Ask for help checking the camera."
        case .cameraOrientation:
            return arabic ? "توقف. وجّه الكاميرا الخلفية إلى الأمام وإلى أسفل قليلاً وأنت ثابت." : "Stop. While standing still, point the rear camera forward and slightly down."
        case .cameraHeight:
            return arabic ? "توقف. ارتفاع الهاتف خارج نطاق المعايرة. اطلب مساعدة لضبطه." : "Stop. Phone height is outside the calibrated range. Ask for help adjusting it."
        case .groundNeedsRecheck:
            return arabic ? "توقف. أحتاج إلى فحص الأرض مرة أخرى. ابقَ ثابتاً." : "Stop. I need to check the ground again. Keep still."
        case .groundCoverage:
            return arabic ? "توقف. لا أرى ما يكفي من الأرض. ابقَ ثابتاً." : "Stop. I cannot see enough ground. Keep still."
        case .frameUnavailable, .invalidGeometry, .visualStairs, .bodyEnvelope:
            return arabic ? "توقف. رصد الكاميرا غير متاح. ابقَ ثابتاً واطلب المساعدة." : "Stop. Camera monitoring is unavailable. Keep still and ask for help."
        }
    }
    public static func hazard(_ hazard: Hazard, arabic: Bool) -> String {
        switch hazard {
        case .drop: return arabic ? "توقف. قد يكون هناك انخفاض في الأرض أمامك." : "Stop. Possible floor drop ahead."
        case .obstacle: return arabic ? "توقف. يوجد عائق قريب." : "Stop. Obstacle nearby."
        case .overhead: return arabic ? "توقف. يوجد عائق فوقك." : "Stop. Overhead obstacle."
        case .uncertain: return arabic ? "توقف. لا أستطيع التحقق من الطريق الآن." : "Stop. I cannot check the path now."
        case .needsCalibration: return arabic ? "توقف واضبط قياس الأرض قبل الإرشاد." : "Stop and calibrate the floor before guidance."
        case .calibrating: return arabic ? "ابق ثابتاً أثناء ضبط قياس الأرض." : "Hold still while calibrating."
        case .observing: return arabic ? "الرصد يعمل." : "Monitoring active."
        case .stopped: return arabic ? "الرصد متوقف." : "Monitoring stopped."
        }
    }
    public static func noDestination(arabic: Bool) -> String {
        arabic ? "لم أجد وجهة محددة. اختر وجهة من المسارات." : "No unique destination found. Choose a named destination in Routes."
    }
    public static func noRoute(arabic: Bool) -> String {
        arabic ? "لا يوجد مسار مناسب في الخريطة. توقف الإرشاد." : "No accessible authored route found. Guidance stopped."
    }
    public static func unknownPosition(arabic: Bool) -> String {
        arabic ? "موقعك غير مؤكد. حدد مكانك قبل بدء الإرشاد." : "Position is uncertain. Confirm your location before route guidance."
    }
}
