import XCTest
import UIKit

final class ComparisonTests: XCTestCase {
    override func setUpWithError() throws {
        // Retain evidence after failures; no audit finding is filtered or suppressed.
        continueAfterFailure = true
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let elements: [(String, XCUIElement)] = [
            ("button", app.buttons["start-simulation"]),
            ("header", app.staticTexts["practice-header"]),
            ("footer", app.staticTexts["practice-footer"])
        ]
        print("COMPARISON capture=\(name) window=\(app.windows.firstMatch.frame) runnerCategory=\(UIApplication.shared.preferredContentSizeCategory.rawValue)")
        for (role, element) in elements {
            if element.exists {
                print("COMPARISON role=\(role) exists=true frame=\(element.frame) hittable=\(element.isHittable) label=\(element.label.prefix(512))")
            } else {
                print("COMPARISON role=\(role) exists=false")
            }
        }
        // Only this static synthetic host is launched; no production/user hierarchy.
        print("COMPARISON hierarchy=\(app.debugDescription.prefix(12000))")
    }

    @MainActor
    private func launch(_ variant: String, category: UIContentSizeCategory) -> XCUIApplication {
        XCTAssertEqual(UIApplication.shared.preferredContentSizeCategory, category)
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["COMPARISON_VARIANT"] = variant
        app.launchEnvironment["COMPARISON_CATEGORY"] = category.rawValue
        app.launch()
        XCTAssertTrue(app.navigationBars["Camera and safety"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["start-simulation"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["start-simulation"].label, "Try practice (2 minutes)")
        return app
    }

    @MainActor
    private func audit(_ variant: String, type: XCUIAccessibilityAuditType, kind: String, repetition: Int) throws {
        let app = launch(variant, category: .large)
        let prefix = "comparison-\(variant)-\(kind)-\(repetition)"
        defer {
            capture(app, prefix + "-after")
            app.terminate()
        }
        capture(app, prefix + "-before")
        try app.performAccessibilityAudit(for: type) { issue in
            print("COMPARISON issue variant=\(variant) kind=\(kind) repetition=\(repetition) type=\(issue.auditType.rawValue) compact=\(issue.compactDescription.prefix(2048)) detailed=\(issue.detailedDescription.prefix(4096)) element=\(issue.element?.debugDescription.prefix(2048) ?? "unidentified")")
            return false
        }
    }

    @MainActor
    private func endpoint(_ variant: String) {
        let app = launch(variant, category: .accessibilityExtraExtraExtraLarge)
        let prefix = "comparison-\(variant)-endpoint"
        defer {
            capture(app, prefix + "-after")
            app.terminate()
        }
        capture(app, prefix + "-before")
        let footer = app.staticTexts["practice-footer"]
        let expected = "Practice pauses live sensors and ends by itself after two minutes. Live monitoring resumes only if the camera control is on, and requires calibration. Keep using your cane or guide dog."
        // Single direction, bounded small gestures: do not overshoot then reverse back to the top.
        // This tests endpoint exposure, not whether the entire large footer fits at once.
        func visibleEnd() -> Bool {
            guard footer.exists else { return false }
            let bottom = footer.frame.maxY
            return bottom > app.navigationBars.firstMatch.frame.maxY &&
                bottom <= app.windows.firstMatch.frame.maxY - 34
        }
        for step in 0..<8 {
            let exists = footer.exists
            print("COMPARISON endpoint step=\(step) footerExists=\(exists) frame=\(exists ? String(describing: footer.frame) : "unavailable")")
            if visibleEnd() { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(footer.exists)
        if footer.exists {
            XCTAssertEqual(footer.label, expected)
            XCTAssertTrue(footer.isHittable)
        }
        let endpointVisible = visibleEnd()
        print("COMPARISON endpoint variant=\(variant) endVisible=\(endpointVisible)")
        XCTAssertTrue(endpointVisible, "Footer end was not exposed by the fixed bounded gestures")
    }
    @MainActor func testA_DynamicType_1() throws { try audit("A", type: .dynamicType, kind: "dynamicType", repetition: 1) }
    @MainActor func testA_DynamicType_2() throws { try audit("A", type: .dynamicType, kind: "dynamicType", repetition: 2) }
    @MainActor func testA_HitRegion_1() throws { try audit("A", type: .hitRegion, kind: "hitRegion", repetition: 1) }
    @MainActor func testA_HitRegion_2() throws { try audit("A", type: .hitRegion, kind: "hitRegion", repetition: 2) }
    @MainActor func testA_Endpoint() { endpoint("A") }
    @MainActor func testB_DynamicType_1() throws { try audit("B", type: .dynamicType, kind: "dynamicType", repetition: 1) }
    @MainActor func testB_DynamicType_2() throws { try audit("B", type: .dynamicType, kind: "dynamicType", repetition: 2) }
    @MainActor func testB_HitRegion_1() throws { try audit("B", type: .hitRegion, kind: "hitRegion", repetition: 1) }
    @MainActor func testB_HitRegion_2() throws { try audit("B", type: .hitRegion, kind: "hitRegion", repetition: 2) }
    @MainActor func testB_Endpoint() { endpoint("B") }
    @MainActor func testC_DynamicType_1() throws { try audit("C", type: .dynamicType, kind: "dynamicType", repetition: 1) }
    @MainActor func testC_DynamicType_2() throws { try audit("C", type: .dynamicType, kind: "dynamicType", repetition: 2) }
    @MainActor func testC_HitRegion_1() throws { try audit("C", type: .hitRegion, kind: "hitRegion", repetition: 1) }
    @MainActor func testC_HitRegion_2() throws { try audit("C", type: .hitRegion, kind: "hitRegion", repetition: 2) }
    @MainActor func testC_Endpoint() { endpoint("C") }
}
