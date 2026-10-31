import XCTest
@testable import PaperStairReference

// Analytic hit tuples, NOT raycasts from a real sensor/mesh or physical trials.
final class ReferenceTests: XCTestCase {
    func core() -> ReferenceCore {
        ReferenceCore(interpretation: Interpretation(down2Floor:.namedFirstToSecond,
            forwardLower:.namedFirstToSecond,down1Down2:.namedFirstToSecond))
    }
    let drop: [Ray:Vector] = [.down1:Vector(3,2,0),.down2:Vector(2,0,0),
        .floorDetector:Vector(1,-2,0),.forward:Vector(2,2,0),.lower:Vector(1,0,0),.up:Vector(3,4,0)]
    func frame(_ i: Int, points: [Ray:Vector], time: Double?=nil, valid: Bool=true,
               coordinate: String="fixture", tracking: Tracking = .normal,
               gravity: Vector=Vector(0,-1,0), origin: Vector=Vector(0,0,0)) -> Frame {
        let t=time ?? Double(i)/60
        let hits=points.mapValues { Hit(position:$0,surface:.floor,frameIndex:i,timestamp:t,coordinateFrame:coordinate) }
        return Frame(index:i,timestamp:t,coordinateFrame:coordinate,tracking:tracking,
            poseAccepted:valid,origin:origin,forward:Vector(1,0,0),gravity:gravity,hits:hits)
    }
    func points(lower: Double, upper: Double) -> [Ray:Vector] {
        let a=lower * .pi/180, b=upper * .pi/180
        let l=Vector(0,0,0), f=Vector(sin(a),cos(a),0)
        return [.lower:l,.forward:f,.up:Vector(f.x+sin(b),f.y+cos(b),0),
                .down1:Vector(2,-1,0),.down2:Vector(1,-1,0),.floorDetector:Vector(0,-1,0)]
    }
    func kind(_ o: Output, file: StaticString=#filePath, line: UInt=#line) -> AscendingKind? {
        if case .observed(let a)=o.ascending { return a.kind }
        XCTFail("expected geometry evidence",file:file,line:line); return nil
    }
    func testAscendingStepStaircaseAndWallFirst() {
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:90)))),.trippingHazard)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:34,upper:34)))),.staircase)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:20,upper:20)))),.wall)
    }
    func testFlatAndRampCounterexample() {
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:90,upper:90)))),.noCandidateInSuppliedRays)
        // Collinear steep ramp satisfies published angular staircase rule. Preserve limitation.
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:30)))),.staircase)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:80,upper:80)))),.noCandidateInSuppliedRays)
    }
    func testAngleBoundaryNeighborhoods() {
        let e=0.000001
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:25-e)))),.wall)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:25+e)))),.staircase)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:65-e)))),.noCandidateInSuppliedRays)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:65+e)))),.trippingHazard)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:10-e,upper:90)))),.noCandidateInSuppliedRays)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:10+e,upper:90)))),.trippingHazard)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:50-e,upper:90)))),.trippingHazard)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:50+e,upper:90)))),.noCandidateInSuppliedRays)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:45-e)))),.staircase)
        XCTAssertEqual(kind(core().process(frame(0,points:points(lower:30,upper:45+e)))),.noCandidateInSuppliedRays)
    }
    func testDescendingDropFourFrames() {
        let c=core()
        for i in 0..<3 { XCTAssertFalse(c.process(frame(i,points:drop)).descendingResearchMarker) }
        XCTAssertTrue(c.process(frame(3,points:drop)).descendingResearchMarker)
    }
    func testCooldown179180BoundaryWithAccumulation() {
        let c=core()
        for i in 0...3 { _=c.process(frame(i,points:drop)) }
        for i in 4...182 { XCTAssertFalse(c.process(frame(i,points:drop)).descendingResearchMarker) }
        XCTAssertTrue(c.process(frame(183,points:drop)).descendingResearchMarker)
    }
    func testMissingFloorOcclusionAndUnknownDoNotCount() {
        let c=core()
        for i in 0..<3 { _=c.process(frame(i,points:drop)) }
        var missing=drop; missing.removeValue(forKey:.floorDetector)
        let o=c.process(frame(3,points:missing))
        XCTAssertNotNil(o.incompleteReason); XCTAssertFalse(o.descendingResearchMarker)
        if case .unknown = o.descending {} else { XCTFail("missing floor must be unknown") }
        for i in 4...6 { XCTAssertFalse(c.process(frame(i,points:drop)).descendingResearchMarker) }
        XCTAssertTrue(c.process(frame(7,points:drop)).descendingResearchMarker)
        missing=drop; missing.removeValue(forKey:.up)
        if case .unknown = core().process(frame(0,points:missing)).ascending {} else { XCTFail("occluded Up") }
    }
    func testGapReplayAndPoseJitterReset() {
        let c=core()
        for i in 0..<3 { _=c.process(frame(i,points:drop)) }
        XCTAssertFalse(c.process(frame(4,points:drop)).descendingResearchMarker)
        XCTAssertEqual(c.process(frame(4,points:drop)).persistenceFrames,0)
        XCTAssertEqual(c.process(frame(5,points:drop,valid:false)).persistenceFrames,0)
        XCTAssertEqual(c.process(frame(6,points:drop,tracking:.limited)).persistenceFrames,0)
        XCTAssertEqual(c.process(frame(7,points:drop)).persistenceFrames,1)
    }
    func testInvalidGravityFrameAndDegenerateSegments() {
        XCTAssertNotNil(core().process(frame(0,points:drop,gravity:Vector(0,0,0))).incompleteReason)
        XCTAssertNotNil(core().process(frame(0,points:drop,time:.nan)).incompleteReason)
        var p=drop; p[.up]=p[.forward]
        if case .unknown = core().process(frame(0,points:p)).ascending {} else { XCTFail("zero segment") }
        p=drop; p[.lower]=Vector(.infinity,0,0)
        XCTAssertNotNil(core().process(frame(0,points:p)).incompleteReason)
        let c=core(); _=c.process(frame(0,points:drop))
        XCTAssertNotNil(c.process(frame(1,points:drop,coordinate:"new")).incompleteReason)
    }
    func testFloorMedianWindowAndFixedWorldOrigin() {
        let c=core()
        for i in 0..<30 {
            _=c.process(frame(i,points:[.floorDetector:Vector(0,Double(i),0)],origin:Vector(Double(i),20,0)))
        }
        let o=c.process(frame(30,points:[.floorDetector:Vector(0,30,0)],origin:Vector(30,100,0)))
        let floor=o.floor.first { $0.ray == .floorDetector }
        XCTAssertEqual(floor?.count,30)
        XCTAssertEqual(floor?.median,15.5) // samples1...30, not camera-relative height
        let missing=c.process(frame(31,points:[:]))
        XCTAssertEqual(missing.floor.first?.count,29) // missing frame occupies window slot
        XCTAssertNotNil(missing.incompleteReason)
    }
    func testPairTiltAndSpanBoundaryNeighborhoods() {
        for (angle,span,expected) in [(4.999999,0.1,false),(5.000001,0.1,true),
            (49.999999,0.1,true),(50.000001,0.1,false),(30.0,0.039999,false),(30.0,0.04,true)] {
            var p=drop
            p[.down2]=Vector(0,0,0)
            p[.floorDetector]=Vector(-span*tan(angle * .pi/180),-span,0)
            let o=core().process(frame(0,points:p))
            if case .observed(let d)=o.descending {
                XCTAssertEqual(d.pairs.first?.qualifiesUnderExperimentalRules,expected)
            } else { XCTFail("expected pair evidence") }
        }
    }
    func testEndpointConventionIsExplicitAndChangesResult() {
        let reversed=ReferenceCore(interpretation:Interpretation(down2Floor:.namedSecondToFirst,
            forwardLower:.namedSecondToFirst,down1Down2:.namedSecondToFirst))
        if case .observed(let d)=reversed.process(frame(0,points:drop)).descending { XCTAssertFalse(d.candidate) }
        else { XCTFail("expected evidence") }
    }
    func testAscendingIsRawNoInheritedTemporalMarker() {
        let c=core()
        for i in 0..<10 {
            let o=c.process(frame(i,points:points(lower:30,upper:90)))
            XCTAssertEqual(kind(o),.trippingHazard)
            XCTAssertFalse(o.descendingResearchMarker)
        }
    }
    func testMismatchedHitIdentityCannotBecomeObserved() {
        let base=frame(0,points:drop)
        var hits=base.hits
        hits[.floorDetector]=Hit(position:Vector(1,-2,0),surface:.floor,
            frameIndex:1,timestamp:0,coordinateFrame:"fixture")
        let wrong=Frame(index:0,timestamp:0,coordinateFrame:"fixture",tracking:.normal,
            poseAccepted:true,origin:Vector(0,0,0),forward:Vector(1,0,0),
            gravity:Vector(0,-1,0),hits:hits)
        let output=core().process(wrong)
        if case .unknown = output.descending {} else { XCTFail("foreign frame hit") }
        XCTAssertFalse(output.descendingResearchMarker)
        XCTAssertNotNil(output.incompleteReason)
    }

    func testCadenceDiagnosticNominalDifferentAndUnknown() {
        let c=core()
        XCTAssertEqual(c.process(frame(0,points:drop)).cadence,.unknown)
        XCTAssertEqual(c.process(frame(1,points:drop)).cadence,.nominal60HzWithinExperimentalTolerance)
        XCTAssertEqual(c.process(frame(2,points:drop,time:1.0/60+1)).cadence,.differentObservedCadence)
        XCTAssertEqual(c.process(frame(2,points:drop,time:1.0/60+1)).cadence,.unknown) // replay
        XCTAssertEqual(c.process(frame(3,points:drop,time:.infinity)).cadence,.unknown)
        XCTAssertEqual(c.process(frame(4,points:drop,time:2)).cadence,.unknown) // index gap
        let overflow=core()
        _=overflow.process(frame(0,points:drop,time:-Double.greatestFiniteMagnitude))
        let o=overflow.process(frame(1,points:drop,time:Double.greatestFiniteMagnitude))
        XCTAssertEqual(o.cadence,.unknown)
        XCTAssertNil(o.frameIntervalSeconds)
        XCTAssertNotNil(o.incompleteReason)
    }
    func testCadenceToleranceIsExperimentalAndCounterNotTimeNormalized() {
        let close=core(); _=close.process(frame(0,points:drop,time:0))
        XCTAssertEqual(close.process(frame(1,points:drop,time:1.0/60+0.0000005)).cadence,
                       .nominal60HzWithinExperimentalTolerance)
        let outside=core(); _=outside.process(frame(0,points:drop,time:0))
        XCTAssertEqual(outside.process(frame(1,points:drop,time:1.0/60+0.000002)).cadence,
                       .differentObservedCadence)
        let slow=core()
        for i in 0...3 { _=slow.process(frame(i,points:drop,time:Double(i))) }
        for i in 4...182 {
            let o=slow.process(frame(i,points:drop,time:Double(i)))
            XCTAssertEqual(o.cadence,.differentObservedCadence)
            XCTAssertFalse(o.descendingResearchMarker)
        }
        let o=slow.process(frame(183,points:drop,time:183))
        XCTAssertTrue(o.descendingResearchMarker)
        XCTAssertEqual(o.secondsSinceLastMarker,180) // seconds, NOT 3s at 1Hz
    }
    func testFiniteExtremeFloorMeanOverflowIsExplicitUnknown() {
        let c=core()
        _=c.process(frame(0,points:[.floorDetector:Vector(0,1e308,0)]))
        let o=c.process(frame(1,points:[.floorDetector:Vector(0,1e308,0)]))
        XCTAssertEqual(o.floorIncompleteReason,"nonfinite derived floor statistics")
        XCTAssertEqual(o.incompleteReason,o.floorIncompleteReason)
        XCTAssertTrue(o.floor.isEmpty)
        XCTAssertFalse(o.descendingResearchMarker)
        XCTAssertEqual(o.persistenceFrames,0)
        // Rejected numeric state is cleared; normal data recovers without inherited infinity.
        let recovered=c.process(frame(2,points:[.floorDetector:Vector(0,1,0)]))
        XCTAssertNil(recovered.floorIncompleteReason)
        XCTAssertEqual(recovered.floor.first?.count,1)
        XCTAssertEqual(recovered.floor.first?.median,1)
    }
    func testFiniteExtremeFloorVarianceAndProjectionOverflowAreUnknown() {
        let c=core()
        _=c.process(frame(0,points:[.floorDetector:Vector(0,1e200,0)]))
        let o=c.process(frame(1,points:[.floorDetector:Vector(0,-1e200,0)]))
        XCTAssertEqual(o.floorIncompleteReason,"nonfinite derived floor statistics")
        XCTAssertTrue(o.floor.isEmpty)
        let projected=core().process(frame(0,points:[.floorDetector:Vector(1.7e308,1.7e308,1.7e308)],
            gravity:Vector(-1,-1,-1)))
        XCTAssertEqual(projected.floorIncompleteReason,"nonfinite derived floor projection")
        XCTAssertTrue(projected.floor.isEmpty)
    }

}
