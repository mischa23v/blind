import XCTest
@testable import BlindCore

/// Synthetic policy/math checks only. NOT camera/fabric accuracy validation.
final class ClothingColorTests: XCTestCase {
    private func solid(_ rgb: ClothingColor.RGB) -> [ClothingColor.RGB] { Array(repeating: rgb, count: 100) }
    func testStandardSRGBLabReferenceValues() throws {
        // Standard D65/sRGB reference values, with rounding tolerance for matrix conventions.
        let red = try XCTUnwrap(ClothingColor.lab(.init(1,0,0)))
        XCTAssertEqual(red.l,53.2408,accuracy:0.002); XCTAssertEqual(red.a,80.0925,accuracy:0.002); XCTAssertEqual(red.b,67.2032,accuracy:0.002)
        let white = try XCTUnwrap(ClothingColor.lab(.init(1,1,1)))
        XCTAssertEqual(white.l,100,accuracy:0.002); XCTAssertEqual(white.a,0,accuracy:0.002); XCTAssertEqual(white.b,0,accuracy:0.002)
        let black = try XCTUnwrap(ClothingColor.lab(.init(0,0,0)))
        XCTAssertEqual(black,.init(0,0,0))
        XCTAssertEqual(ClothingColor.deltaE76(.init(50,2.5,0),.init(50,0,-2.5)),sqrt(12.5),accuracy:1e-12)
    }
    func testInvalidPixelsNeverProduceName() {
        for bad in [ClothingColor.RGB(.nan,0,0),.init(.infinity,0,0),.init(-0.1,0,0),.init(1.1,0,0)] {
            XCTAssertNil(ClothingColor.lab(bad)); XCTAssertEqual(ClothingColor.evaluate(solid(bad)),.insufficientPixels)
        }
        XCTAssertEqual(ClothingColor.evaluate([]),.insufficientPixels)
        XCTAssertEqual(ClothingColor.evaluate(Array(repeating:.init(0.8,0.1,0.1),count:63)),.insufficientPixels)
    }
    func testUnknownIlluminationNeverCertifiesWhiteGrayOrCream() {
        for sample in [ClothingColor.RGB(0.95,0.95,0.95),.init(0.8,0.8,0.8),.init(0.94,0.91,0.82),.init(0.9,0.92,0.96)] {
            XCTAssertEqual(ClothingColor.evaluate(solid(sample)),.nearNeutral)
        }
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(0.4,0.4,0.4))),.darkNeutral)
        let speech = ClothingColor.Result.nearNeutral.speech(arabic:false)
        XCTAssertTrue(speech.contains("can't confirm white")); XCTAssertTrue(speech.contains("Don't rely"))
    }
    func testClippedOrDarkCaptureRejected() {
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(1,1,1))),.insufficientPixels)
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(0,0,0))),.insufficientPixels)
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(0.99,0.99,0.99))),.insufficientPixels)
    }
    func testBroadAppearanceCandidatesAreNotCertifications() {
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(0.83,0.18,0.18))),.appearance(.red))
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(0.10,0.46,0.82))),.appearance(.blue))
        XCTAssertEqual(ClothingColor.evaluate(solid(.init(0.55,0.28,0.12))),.appearance(.brown))
        XCTAssertTrue(ClothingColor.Result.appearance(.blue).speech(arabic:false).contains("estimate"))
        XCTAssertFalse(ClothingColor.Result.appearance(.blue).speech(arabic:true).isEmpty)
    }
    func testMixedPatternDoesNotBecomeSingleColor() {
        let pixels = Array(solid(.init(0.83,0.18,0.18)).prefix(50)) + Array(solid(.init(0.10,0.46,0.82)).prefix(50))
        XCTAssertEqual(ClothingColor.evaluate(pixels),.mixedOrUncertain)
        let whitePattern = Array(solid(.init(0.83,0.18,0.18)).prefix(75)) + Array(solid(.init(0.9,0.9,0.9)).prefix(25))
        XCTAssertEqual(ClothingColor.evaluate(whitePattern),.mixedOrUncertain)
        let clippedPattern = Array(solid(.init(0.83,0.18,0.18)).prefix(70)) + Array(solid(.init(1,1,1)).prefix(30))
        XCTAssertEqual(ClothingColor.evaluate(clippedPattern),.insufficientPixels)
    }
    func testCommandEnglishArabic() {
        for command in ["What colour is this shirt?", "Check the color", "Is this white?", "ما لون هذا القميص", "هل هذا أبيض", "هل هذه بيضاء؟", "وش لونها؟", "Is this light gray?", "Does this look white?", "Can you please check the colour", "هل هذا أَبْيَض؟", "Is this white enough for school?", "Is this really white for my uniform?", "Can I use this as my white school uniform?"] { XCTAssertTrue(ClothingColorCommand.matches(command), command) }
        for unrelated in ["Find my brother", "Read this banknote", "Stop", "colourful music", "Do not check the color", "Don't check the colour", "The color is red", "My shirt looks white", "هذا القميص أبيض", "لا تفحص اللون", "Find my white shirt", "Read the word color", "Check color settings", "هل هذا ابيضاض العين", "ما لونه المفضل؟"] { XCTAssertFalse(ClothingColorCommand.matches(unrelated), unrelated) }
    }
    func testWhiteRequestCannotBeCertifiedUnderColoredLighting() {
        XCTAssertTrue(ClothingColorCommand.requiresNeutralVerification("Is this white?"))
        XCTAssertTrue(ClothingColorCommand.requiresNeutralVerification("What colour is this uniform?"))
        XCTAssertTrue(ClothingColorCommand.requiresNeutralVerification("هل هذه بيضاء؟"))
        XCTAssertTrue(ClothingColorCommand.requiresNeutralVerification("ما لون القميص الأبيض؟"))
        XCTAssertTrue(ClothingColorCommand.requiresNeutralVerification("هل هذا أَبْيَض؟"))
        XCTAssertFalse(ClothingColorCommand.requiresNeutralVerification("What color is this shirt?"))
    }
    func testFreshCaptureNeverAcceptsFutureStaleOrInvalidTime() {
        XCTAssertTrue(ClothingColorCapturePolicy.fresh(capturedAt:100,now:103))
        XCTAssertTrue(ClothingColorCapturePolicy.fresh(capturedAt:100,now:104))
        for now in [99.0,104.001,Double.nan,Double.infinity] { XCTAssertFalse(ClothingColorCapturePolicy.fresh(capturedAt:100,now:now)) }
        XCTAssertFalse(ClothingColorCapturePolicy.fresh(capturedAt: -1,now:0))
    }
    func testOpenCV414IndependentLabFixtures() throws {
        // Generated using already installed OpenCV 4.14.0 cvtColor float32 RGB2Lab.
        // OpenCV interpolates its transfer tables: allow 0.25 Lab unit, not exact equality.
        let fixtures: [(ClothingColor.RGB, ClothingColor.Lab)] = [
            (.init(0,1,0),.init(87.738037,-86.1875,83.171875)),
            (.init(0,0,1),.init(32.293701,79.1875,-107.859375)),
            (.init(0.5,0.5,0.5),.init(53.387451,0,0)),
            (.init(0.1,0.2,0.3),.init(20.410156,-0.578125,-18.53125)),
            (.init(0.8,0.7,0.6),.init(74.230957,5.21875,16.359375)),
            (.init(0.04,0.03,0.02),.init(2.160645,0.375,1.203125)),
            (.init(0.95,0.91,0.82),.init(92.120361,-0.203125,12.421875))
        ]
        for (rgb, expected) in fixtures {
            let actual = try XCTUnwrap(ClothingColor.lab(rgb))
            XCTAssertEqual(actual.l,expected.l,accuracy:0.25)
            XCTAssertEqual(actual.a,expected.a,accuracy:0.25)
            XCTAssertEqual(actual.b,expected.b,accuracy:0.25)
        }
    }

    func testModelColorClaimsCannotBypassDedicatedPath() {
        for text in ["It is a white shirt.", "The fabric is ivory.", "القميص الأبيض", "القماش رمادي", "قماش أَبْيَض"] {
            XCTAssertTrue(ClothingColorCommand.containsUnverifiedColorClaim(text),text)
        }
        XCTAssertFalse(ClothingColorCommand.containsUnverifiedColorClaim("There is a shirt on a hanger."))
        XCTAssertFalse(ClothingColorCommand.containsUnverifiedColorClaim("The whiteboard has writing."))
    }

    func testCloseObjectPoseGateRejectsTranslationYawAndPitch() {
        let origin = Point3(0,0,0), forward = Point3(0,0,-1)
        XCTAssertTrue(ClothingColorCapturePolicy.poseStable(origin:origin,current:origin,originForward:forward,currentForward:forward))
        XCTAssertFalse(ClothingColorCapturePolicy.poseStable(origin:origin,current:.init(0.1,0,0),originForward:forward,currentForward:forward))
        let angle = Double.pi/9
        XCTAssertFalse(ClothingColorCapturePolicy.poseStable(origin:origin,current:origin,originForward:forward,currentForward:.init(sin(angle),0,-cos(angle))))
        XCTAssertFalse(ClothingColorCapturePolicy.poseStable(origin:origin,current:origin,originForward:forward,currentForward:.init(0,sin(angle),-cos(angle))))
        XCTAssertFalse(ClothingColorCapturePolicy.poseStable(origin:origin,current:origin,originForward:forward,currentForward:.init(0,0,0)))
        XCTAssertFalse(ClothingColorCapturePolicy.poseStable(origin:origin,current:origin,originForward:forward,currentForward:.init(.nan,0,-1)))
    }

}
