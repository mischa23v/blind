import XCTest
@testable import BlindCore

final class NavigationTests: XCTestCase {
    func testBlockedLegReplansUsingOnlyAuthoredAccessibleEdges() throws {
        let nodes = (0..<4).map { MapNode(id: String($0), name: String($0), level: "0", position: Point3(Double($0), 0, 0)) }
        let map = IndoorMap(name: "School", nodes: nodes, edges: [MapEdge(from: "0", to: "1", distance: 1),
            MapEdge(from: "1", to: "3", distance: 1), MapEdge(from: "0", to: "2", distance: 2),
            MapEdge(from: "2", to: "3", distance: 2)])
        XCTAssertEqual(try map.route(from: "0", to: "3").map(\.id), ["0", "1", "3"])
        XCTAssertEqual(try map.route(from: "0", to: "3", blocked: [MapConnection("1", "0")]).map(\.id), ["0", "2", "3"])
        XCTAssertThrowsError(try map.route(from: "0", to: "3", blocked: [MapConnection("0", "1"), MapConnection("0", "2")]))
    }
    private func observation(obstacle: Bool = false, unknown: Bool = false) -> Observation {
        var points: [DepthSample] = []
        for x in stride(from: -1.8, to: 1.8, by: 0.04) {
            for ahead in stride(from: 0.1, to: 2.6, by: 0.04) {
                if unknown && ahead > 1 { continue }
                let height = obstacle && ahead > 1 && ahead < 1.4 && abs(x) < 0.3 ? 0.4 : 0.0
                points.append(DepthSample(Point3(x, height, -ahead)))
            }
        }
        return Observation(timestamp: 10, camera: Point3(0, 1.3, 0), forward: Point3(0, 0, -1), samples: points)
    }
    func testKnownFloorProducesCandidateAndUnknownNeverDoes() {
        let planner = LocalPlanner(), target = Point3(0, 0, -3)
        XCTAssertEqual(planner.plan(observation: observation(), floor: 0, target: target, now: 10).state, .candidatePath)
        XCTAssertEqual(planner.plan(observation: observation(unknown: true), floor: 0, target: target, now: 10).state, .unknownTerrain)
        XCTAssertEqual(planner.plan(observation: observation(), floor: 0, target: target, now: 11).state, .needsPosition)
        XCTAssertEqual(planner.plan(observation: observation(), floor: nil, target: target, now: 10).state, .needsCalibration)
    }
    func testPlannerDetoursThroughObservedFloor() {
        let result = LocalPlanner().plan(observation: observation(obstacle: true), floor: 0, target: Point3(0, 0, -3), now: 10)
        XCTAssertEqual(result.state, .candidatePath)
        XCTAssertTrue(result.points.contains { abs($0.x) > 0.4 })
    }
    func testMotionAndInformationBudget() {
        var policy = AttentionPolicy()
        // i / 10 gives exactly 3.9 for the last sample; i * 0.1 would land just after it.
        for i in 0..<40 { policy.observe(camera: Point3(0, 1, 0), at: Double(i) / 10, tracking: true) }
        XCTAssertTrue(policy.stationary)
        XCTAssertTrue(policy.permitsAmbient(detail: .minimal, urgent: false, now: 3.9))
        XCTAssertFalse(policy.permitsAmbient(detail: .detailed, urgent: true, now: 3.9))
        XCTAssertTrue(policy.permitsAmbient(detail: .balanced, urgent: false, now: 3.91))
        XCTAssertEqual(policy.select(text: "Exit", people: 0, labels: ["room"], detail: .balanced, arabic: false, now: 3.91, requested: false), "Exit")
        XCTAssertFalse(policy.permitsAmbient(detail: .balanced, urgent: false, now: 4))
        policy.observe(camera: Point3(0, 1, -0.2), at: 4, tracking: true)
        XCTAssertFalse(policy.stationary)
        XCTAssertNil(policy.select(text: "Another sign", people: 2, labels: [], detail: .detailed, arabic: false, now: 4, requested: false))
        XCTAssertNotNil(policy.select(text: "Requested sign", people: 0, labels: [], detail: .minimal, arabic: false, now: 4, requested: true))
    }
    func testVenueSelectionDoesNotGuessThroughBadGPSOrAmbiguity() throws {
        let venue = Venue(id: "mall", name: "Mall", latitude: 24.7, longitude: 46.7, radiusMeters: 100, mapFile: "mall.json")
        let catalog = VenueCatalog(venues: [venue]); try catalog.validate()
        XCTAssertEqual(catalog.candidates(latitude: 24.7, longitude: 46.7, accuracy: 10, age: 1), [venue])
        XCTAssertEqual(catalog.candidates(latitude: 24.7, longitude: 46.7, accuracy: 90, age: 1), [])
        XCTAssertEqual(catalog.candidates(latitude: 24.7, longitude: 46.7, accuracy: 10, age: 11), [])
        var unsafe = venue; unsafe.mapFile = "../secret.json"
        XCTAssertThrowsError(try VenueCatalog(venues: [unsafe]).validate())
    }
    func testJourneyDoesNotJoinTrackingGapsOrCoordinateJumps() throws {
        var recorder = JourneyRecorder()
        for i in 0..<10 { recorder.observe(camera: Point3(0, 0, Double(i) * 0.1), time: Double(i) * 0.1, tracking: true) }
        let distance = recorder.journey.distance
        recorder.observe(camera: Point3(100, 0, 0), time: 2, tracking: true)
        XCTAssertEqual(recorder.journey.distance, distance)
        XCTAssertEqual(recorder.journey.points.last?.segment, 1)
        recorder.observe(camera: Point3(100, 0, 0), time: 2.1, tracking: false)
        recorder.observe(camera: Point3(200, 0, 0), time: 2.2, tracking: true)
        XCTAssertEqual(recorder.journey.points.last?.segment, 2)
        let decoded = try JSONDecoder().decode(Journey.self, from: JSONEncoder().encode(recorder.journey))
        XCTAssertEqual(decoded.points, recorder.journey.points)
    }
}
