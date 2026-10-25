import XCTest
import UIKit

// One opt-in diagnostic. Copied setup/navigation/evidence contracts are checked
// against LaunchTests; the only Camera audit factor is .dynamicType vs default .all.
final class CameraAuditScopeTests: XCTestCase {
    private var app: XCUIApplication!
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable)
    }
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BLIND_AUDIT_SCOPE_CONTROL"] == "1",
                          "Diagnostic-only scope control; not ordinary UI acceptance")
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-background-conversation", "NO", "-camera-awareness", "NO"]
        app.launch()
    }
    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
    private func openSettingsPage(_ identifier: String) {
        openTab("Settings")
        for _ in 0..<8 {
            if app.buttons["settings-details"].exists { break }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let landing = ["conversation-controls", "settings-reading", "settings-details", "settings-map-tools"]
        if !landing.contains(identifier) { app.buttons["settings-details"].tap() }
        let page = app.buttons[identifier]
        reveal(page); page.tap()
    }
    @MainActor
    private func recordFullAuditEvidence(_ phase: String, _ point: String) {
        // Only the existing synthetic --ui-testing launch, never production user content.
        XCTAssertTrue(app.launchArguments.contains("--ui-testing"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "full-audit-\(phase)-\(point)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("ACCESSIBILITY_AUDIT_EVIDENCE phase=\(phase) point=\(point) category=\(UIApplication.shared.preferredContentSizeCategory.rawValue) window=\(app.windows.firstMatch.frame)")
        let controls: [(String, XCUIElement)] = [
            ("navigation", app.navigationBars.firstMatch),
            ("tabs", app.tabBars.firstMatch),
            ("monitor", app.buttons["monitor-toggle"]),
            ("return", app.buttons["retrace-session"]),
            ("practice", app.buttons["start-simulation"]),
            ("practice-header", app.staticTexts.matching(NSPredicate(format: "label == %@", "Practice")).firstMatch),
            ("practice-footer", app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice pauses live sensors and ends by itself after two minutes.")).firstMatch),
            ("local-answer", app.buttons["local-answer"]),
            ("voice-question", app.buttons["voice-question"])
        ]
        for (role, element) in controls {
            if element.exists {
                print("ACCESSIBILITY_AUDIT_FRAME phase=\(phase) point=\(point) role=\(role) exists=true frame=\(element.frame) hittable=\(element.isHittable) enabled=\(element.isEnabled) label=\(element.label.prefix(512))")
            } else {
                print("ACCESSIBILITY_AUDIT_FRAME phase=\(phase) point=\(point) role=\(role) exists=false")
            }
        }
    }

    @MainActor
    private func auditDynamicTypeDestination(_ phase: String, title: String, requiredControl: String) throws {
        defer { recordFullAuditEvidence(phase, "after") }
        // Required destination UI, not a sleep, scroll, altered state or audit exemption.
        let titleReady = app.navigationBars[title].waitForExistence(timeout: 10)
        let controlReady = app.buttons[requiredControl].waitForExistence(timeout: 10)
        print("ACCESSIBILITY_AUDIT_READINESS phase=\(phase) titleReady=\(titleReady) controlReady=\(controlReady)")
        recordFullAuditEvidence(phase, "before")
        XCTAssertTrue(titleReady, "Expected destination navigation title")
        XCTAssertTrue(controlReady, "Expected destination control")
        try app.performAccessibilityAudit(for: .dynamicType) { issue in
            print("ACCESSIBILITY_AUDIT=type:\(issue.auditType),phase:\(phase),compact:\(issue.compactDescription.prefix(2048)),detailed:\(issue.detailedDescription.prefix(4096)),element:\(String((issue.element?.debugDescription ?? "unidentified").prefix(1200)).replacingOccurrences(of: "\n", with: " | "))")
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
    }

    @MainActor
    func testCameraDynamicTypeOnly() throws {
        openSettingsPage("camera-screen")
        try auditDynamicTypeDestination("camera", title: "Camera and safety", requiredControl: "monitor-toggle")
    }
}
