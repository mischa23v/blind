import XCTest
@testable import BlindCore

/// Walking scenarios on the sourced OAS apartment plan (rooms, walls and door connections from the
/// pinned example in Fixtures). The person's position and facing change step by step; the room is
/// worked out from clues (map match at start, simulated picture/furniture matches with realistic
/// scores, a look-alike room, the person's answer) — never from the answer key. Orientation
/// (BodyHeadingEstimator), room decisions (RoomRecognizer), speech gating (CompanionAttention) and
/// measured wording (SpatialFacts) are the real BlindCore code. Every line the app would say is
/// written to artifacts/windows-stage/home-walk-transcript.txt.
/// Limits: camera and LiDAR are simulated; doorways sit at the middle of each shared wall (the source
/// gives connections, not door positions); the fridge, front door and chair are test landmarks.
final class HomeWalkScenarioTests: XCTestCase {
    struct Target { let label: String; let point: Point3 }
    static let doorBedroom = Target(label: "Door to Living Room / Kitchen", point: Point3(7, 0, 1.75))
    static let doorBedroomFromLiving = Target(label: "Door to Bedroom", point: Point3(7, 0, 1.75))
    static let doorEntry = Target(label: "Door to Entry Hall", point: Point3(2, 0, 1))
    static let frontDoor = Target(label: "Front door", point: Point3(0, 0, 1))      // test landmark
    static let fridge = Target(label: "Fridge", point: Point3(6.4, 0, 4.6))        // test landmark
    static let chair = Point3(4.5, 0, 1.75)                                         // test obstacle

    private var package: PlacePackage!
    private var transcript: [String] = []

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "oas-apartment", withExtension: "blindplace.json", subdirectory: "Fixtures"))
        package = try JSONDecoder().decode(PlacePackage.self, from: Data(contentsOf: url))
    }

    // MARK: - Helpers

    private func room(at p: Point3) -> String? {
        for room in package.rooms {
            guard let b = room.boundary, b.count >= 3 else { continue }
            var inside = false, j = b.count - 1
            for i in 0..<b.count {
                if (b[i].z > p.z) != (b[j].z > p.z),
                   p.x < (b[j].x - b[i].x) * (p.z - b[i].z) / (b[j].z - b[i].z) + b[i].x { inside.toggle() }
                j = i
            }
            if inside { return room.id }
        }
        return nil
    }

    private func name(_ id: String) -> String {
        id == "brothers_room" ? "Brother's room" : (package.rooms.first { $0.id == id }?.name ?? id)
    }

    /// Positions every 0.25 s walking at 1 m/s along the path, with the walking direction.
    private func walk(_ path: [Point3]) -> [(Point3, Point3)] {
        var steps: [(Point3, Point3)] = []
        for (a, b) in zip(path, path.dropFirst()) {
            let length = a.distance(to: b)
            guard length > 0 else { continue }
            let dir = Point3((b.x - a.x) / length, 0, (b.z - a.z) / length)
            var d = 0.0
            while d < length { steps.append((Point3(a.x + dir.x * d, 0, a.z + dir.z * d), dir)); d += 0.25 }
        }
        if let last = path.last, let dir = steps.last?.1 { steps.append((last, dir)) }
        return steps
    }

    private func log(_ t: Double, _ room: String?, _ kind: String, _ text: String) {
        transcript.append(String(format: "%6.2fs  %-24@  %-6@ %@", t, (room.map(name) ?? "room unknown") as NSString, kind as NSString, text as NSString))
    }

    struct Options {
        var startEstablished = true
        var familiar = true
        var lookAlike = false
        var unknownFor = 0.0
        var obstacle: Point3? = nil
        var goalChange: (at: Double, via: [Target], target: Target)? = nil
        var stationaryEnd = 0.0
    }

    /// Runs one walk and returns what was said.
    @discardableResult
    private func scenario(_ title: String, path: [Point3], via: [Target], target: Target, _ options: Options = Options()) -> [String] {
        transcript.append("")
        transcript.append("=== \(title) ===")
        var memory = CompanionMemory()
        if options.familiar { for r in package.rooms { memory.rooms[r.id] = RoomRecord(); memory.rooms[r.id]?.visits = 50 } }
        var engine = CompanionAttention(memory: memory)
        var recognizer = RoomRecognizer()
        var heading = BodyHeadingEstimator()
        let settings = CompanionSettings(minimumGap: 0, wordsPerMinute: 400, offerWindow: 14)
        var via = via, target = target, goalActive = true, arrived = false, confirmed: String?, pendingConfirm: String?
        var cadence = GuidanceCadence(), cameraNoted = false
        var lastHazardBucket = -1, established: String?, roomOffer: InformationCandidate?, said = 0
        var steps = walk(path)
        if options.stationaryEnd > 0, let last = steps.last {
            for _ in 0..<Int(options.stationaryEnd / 0.25) { steps.append(last) }
        }
        for (index, step) in steps.enumerated() {
            let t = Double(index) * 0.25, (pos, dir) = step
            let stationary = index > 0 && steps[index - 1].0.distance(to: pos) < 0.01
            heading.observe(camera: Point3(pos.x, 1.3, pos.z), cameraForward: dir, at: t, tracking: true)
            if let change = options.goalChange, abs(t - change.at) < 0.125 {
                via = change.via; target = change.target
                transcript.append(String(format: "%6.2fs  (person says: take me to the %@ instead)", t, change.target.label as NSString))
            }
            // Clues — from the simulated sensors and the person, never from the answer key.
            let truth = room(at: pos)
            var clues: [RoomEvidence] = []
            if options.startEstablished && t < 0.5, let truth { clues.append(.worldMapMatched(roomID: truth)) }
            if t >= options.unknownFor, let truth {
                clues.append(.imageSimilarity(roomID: truth, score: 0.86))
                clues.append(.furnitureSignature(roomID: truth, overlap: 0.7))
                if options.lookAlike && truth == "bedroom" && confirmed == nil {
                    clues.append(.imageSimilarity(roomID: "brothers_room", score: 0.85))
                    clues.append(.furnitureSignature(roomID: "brothers_room", overlap: 0.7))
                }
            }
            // The person's answer is used once, as in the app.
            if let pending = pendingConfirm { clues.append(.userConfirmed(roomID: pending)); pendingConfirm = nil }
            var candidates: [InformationCandidate] = []
            switch recognizer.decide(clues, at: t) {
            case .established(let id, _):
                if id != established {
                    established = id
                    log(t, id, "ROOM", "established")
                }
            case .askWhich(let ids) where engine.pendingOffer == nil && confirmed == nil:
                let names = ids.prefix(2).map(name)
                let prompt = names.count == 2 ? "Is this your \(names[0]) or your \(names[1])? Say yes if it is your \(names[0])." : "Is this your \(names[0])?"
                candidates.append(InformationCandidate(key: "identity:\(ids[0])", kind: .offer, text: prompt, words: 14, createdAt: t, expiresAt: t + 30, room: ids[0], offerKind: .confirmRoom))
            default: break
            }
            if let established, let entry = engine.observeRoom(established, established: true, now: t, settleTime: 0.5), entry == .firstVisit {
                roomOffer = InformationCandidate(key: "room:\(established):offer", kind: .offer, text: "New room, \(name(established)). Want a description?", words: 7, createdAt: t, expiresAt: t + 120, room: established, offerKind: .describeRoom)
            }
            if let roomOffer { candidates.append(roomOffer) }
            // Hazard from the (simulated) depth sensor: an obstacle ahead within 1.6 m.
            if let obstacle = options.obstacle, let rel = SpatialFacts.relation(from: pos, facing: dir, to: obstacle),
               rel.distance < 1.6, abs(rel.angleDegrees) < 30 {
                let bucket = Int(rel.distance * 2)
                if bucket != lastHazardBucket {
                    lastHazardBucket = bucket
                    candidates.append(InformationCandidate(key: "hazard:chair", kind: .hazard, text: "Stop. " + SpatialFacts.phrase(label: "Chair", relation: rel, arabic: false, inView: true), words: 7, createdAt: t, expiresAt: t + 1))
                }
            }
            // Guidance: only once the room is established; measured relative to the body heading.
            if !arrived, established != nil {
                while let next = via.first, pos.distance(to: next.point) < 0.5 { via.removeFirst() }
                let waypoint = via.first ?? target
                let body = heading.heading(at: t, declaredFixedMount: false)
                let facing = body.isKnown ? body.forward : dir
                if let rel = SpatialFacts.relation(from: pos, facing: facing, to: waypoint.point) {
                    if waypoint.label == target.label && rel.distance < 0.65 {
                        arrived = true; goalActive = false
                        candidates.append(InformationCandidate(key: "route:arrived", kind: .mobility, text: SpatialFacts.phrase(label: waypoint.label, relation: rel, arabic: false, inView: true) + " You have arrived.", words: 8, createdAt: t, expiresAt: t + 2))
                    } else if let label = cadence.label(target: waypoint.label, short: waypoint.label.hasPrefix("Door to") ? "Door" : waypoint.label,
                                                        relation: rel, now: t) {
                        // Directions are from the camera until walking gives a body heading; say so once.
                        let prefix = !body.isKnown && !cameraNoted ? "From the camera: " : ""
                        if !body.isKnown { cameraNoted = true }
                        candidates.append(InformationCandidate(key: "route:\(waypoint.label):\(t)", kind: .mobility,
                                                               text: prefix + SpatialFacts.phrase(label: label, relation: rel, arabic: false, inView: nil),
                                                               words: 6, createdAt: t, expiresAt: t + 1))
                    }
                }
            } else if established == nil, index == Int(1 / 0.25) {
                log(t, nil, "STATUS", "Not sure where we are yet. Directions wait until the room is known.")
            }
            let moment = CompanionMoment(now: t, goalActive: goalActive, activity: stationary ? .stationary : .moving)
            for decision in engine.decide(candidates, moment: moment, settings: settings) {
                switch decision {
                case .say(let item, _):
                    log(t, established, item.kind == .hazard ? "HAZARD" : "SAY", item.text); said += 1
                case .offer(let offer, _):
                    log(t, established, "ASK", offer.prompt)
                    if offer.kind == .describeRoom { roomOffer = nil }
                    if offer.kind == .confirmRoom {
                        // The person answers yes; the answer is a clue, not geometry.
                        _ = engine.answerOffer(.yes); confirmed = offer.subject; pendingConfirm = offer.subject
                        transcript.append(String(format: "%6.2fs  (person answers: yes)", t))
                    }
                case .drop(let key, _) where key == roomOffer?.key:
                    roomOffer = nil
                default: break
                }
            }
        }
        transcript.append("--- \(said) spoken lines")
        return transcript
    }

    private func flush() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let out = root.appendingPathComponent("artifacts/windows-stage", isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let file = out.appendingPathComponent("home-walk-transcript-\(name.split(separator: " ").last?.dropLast() ?? "run").txt")
        try transcript.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        print(transcript.joined(separator: "\n"))
    }

    private func lines(_ kind: String) -> [String] { transcript.filter { $0.contains(" \(kind) ") } }

    // MARK: - Scenarios

    func testBedroomToKitchenFridge() throws {
        scenario("Morning: bedroom to the fridge (own home, familiar rooms)",
                 path: [Point3(9, 0, 1.75), Point3(7.2, 0, 1.75), Point3(6.6, 0, 2.4), Point3(6.4, 0, 4.0)],
                 via: [Self.doorBedroom], target: Self.fridge)
        try flush()
        XCTAssertTrue(lines("SAY").first?.contains("Door to Living Room / Kitchen") == true, "first cue is the bedroom door")
        XCTAssertTrue(lines("SAY").contains { $0.contains("You have arrived") }, "arrives at the fridge")
        XCTAssertTrue(lines("ASK").isEmpty, "familiar rooms: no room tours or offers")
        XCTAssertTrue(lines("ROOM").contains { $0.contains("Living Room / Kitchen") }, "recognises the room change")
    }

    func testLeaveHouseAroundChair() throws {
        var options = Options(); options.obstacle = Self.chair
        scenario("Leaving the house: bedroom to the front door, chair in the way",
                 path: [Point3(9, 0, 1.75), Point3(7, 0, 1.75), Point3(5.9, 0, 1.75), Point3(5.2, 0, 2.9), Point3(3.8, 0, 2.9),
                        Point3(2.6, 0, 1.3), Point3(2, 0, 1), Point3(0.6, 0, 1)],
                 via: [Self.doorBedroom, Self.doorEntry], target: Self.frontDoor, options)
        try flush()
        let hazard = try XCTUnwrap(transcript.firstIndex { $0.contains(" HAZARD ") }, "the chair is announced")
        XCTAssertTrue(transcript[hazard].contains("Stop. Chair"))
        XCTAssertTrue(lines("SAY").contains { $0.contains("Door to Entry Hall") })
        XCTAssertTrue(lines("SAY").contains { $0.contains("Front door") && $0.contains("You have arrived") })
        XCTAssertTrue(lines("ASK").isEmpty)
    }

    func testChangeOfMindTurnsAround() throws {
        var options = Options()
        options.goalChange = (at: 1.5, via: [Self.doorEntry], target: Self.frontDoor)
        scenario("Change of mind: heading to the bedroom, then the front door (turns around)",
                 path: [Point3(3.5, 0, 3.3), Point3(5.3, 0, 2.6), Point3(5.3, 0, 2.6), Point3(2.6, 0, 1.3), Point3(2, 0, 1), Point3(0.6, 0, 1)],
                 via: [Self.doorBedroomFromLiving], target: Target(label: "Bedroom", point: Point3(8.5, 0, 1.75)), options)
        try flush()
        let afterChange = transcript.drop { !$0.contains("instead") }.filter { $0.contains(" SAY ") && $0.contains("Door") }
        XCTAssertTrue(afterChange.first?.contains("Door to Entry Hall: behind you") == true, "right after the change, the entry door is behind")
        XCTAssertTrue(afterChange.contains { $0.contains("Door: ahead") }, "after turning, it is ahead (short name after the first mention)")
    }

    func testRestartInUnknownRoomWaitsForClues() throws {
        var options = Options(); options.startEstablished = false; options.unknownFor = 3
        scenario("Restart: the app does not know the room at first",
                 path: [Point3(0.8, 0, 4.4), Point3(4.0, 0, 4.4), Point3(6.3, 0, 4.1)],
                 via: [], target: Self.fridge, options)
        try flush()
        let firstRoom = try XCTUnwrap(transcript.firstIndex { $0.contains(" ROOM ") })
        XCTAssertFalse(transcript[..<firstRoom].contains { $0.contains(" SAY ") }, "no directions before the room is known")
        XCTAssertTrue(transcript.contains { $0.contains(" STATUS ") })
    }

    func testLookAlikeRoomAsksInsteadOfGuessing() throws {
        var options = Options(); options.startEstablished = false; options.familiar = true; options.lookAlike = true
        scenario("Look-alike rooms: his bedroom or his brother's?",
                 path: [Point3(9, 0, 1.75), Point3(7.2, 0, 1.75), Point3(6.6, 0, 2.4), Point3(6.4, 0, 4.0)],
                 via: [Self.doorBedroom], target: Self.fridge, options)
        try flush()
        let ask = try XCTUnwrap(transcript.first { $0.contains(" ASK ") })
        XCTAssertTrue(ask.contains("Brother's room"))
        let askIndex = try XCTUnwrap(transcript.firstIndex(of: ask))
        XCTAssertFalse(transcript[..<askIndex].contains { $0.contains(" SAY ") }, "no directions while the room is in doubt")
    }

    func testFirstVisitOffersDescriptionWhenStill() throws {
        var options = Options(); options.familiar = false; options.stationaryEnd = 3
        scenario("First visit (e.g. grandma's flat): offer a description only once standing still",
                 path: [Point3(1, 0, 1), Point3(2, 0, 1), Point3(4.5, 0, 3.5), Point3(6.3, 0, 4.1)],
                 via: [Self.doorEntry.flippedForLiving], target: Self.fridge, options)
        try flush()
        let ask = try XCTUnwrap(transcript.first { $0.contains(" ASK ") && $0.contains("Want a description") })
        let arrived = try XCTUnwrap(transcript.firstIndex { $0.contains("You have arrived") })
        XCTAssertGreaterThan(try XCTUnwrap(transcript.firstIndex(of: ask)), arrived, "the offer waits until the goal is reached and the person is still")
    }
    // MARK: - Finding his own things and orientation from furniture

    /// "Where is my cup?" in the kitchen. Whether a seen cup IS his is decided by image-comparison
    /// distances (simulated here) with a margin over his brother's similar cup; LiDAR (simulated)
    /// measures where it is. The model never decides identity.
    func testFindMyCupAmongLookAlikes() throws {
        transcript.append("")
        transcript.append("=== Finding his cup in the kitchen (his brother has a similar cup) ===")
        var memory = ItemMemory()
        memory.remember(name: "cup", roomName: "Living Room / Kitchen", at: Date(timeIntervalSince1970: 0))
        memory.describe("cup", as: "Blue mug with a white handle and a small chip on the rim.")
        memory.remember(name: "Ahmed's cup", roomName: "Living Room / Kitchen", at: Date(timeIntervalSince1970: 0))
        let person = Point3(5.5, 0, 3.6), facing = Point3(0, 0, 1)   // standing in the kitchen, facing the counter
        func answer(_ when: String, _ distances: [String: Float], cupAt: Point3?) {
            transcript.append("  (\(when))")
            transcript.append("  person: Where is my cup?")
            let result = ItemAppearanceMatch.decide(distances)
            let place = cupAt.flatMap { SpatialFacts.relation(from: person, facing: facing, to: $0) }
            switch result {
            case .same(let key) where key == "cup":
                transcript.append("  SAY  " + (place.map { SpatialFacts.phrase(label: "Your cup", relation: $0, arabic: false, inView: true) } ?? "Your cup is in the camera view."))
            case .similar(let key) where key == "cup":
                let at = place.map { " " + SpatialFacts.phrase(label: "The similar one", relation: $0, arabic: false, inView: true) } ?? ""
                transcript.append("  SAY  I see something like your cup, but I can't be sure it's yours." + at + " If you can reach it, hold it up and turn it so I can check.")
            default:
                let item = memory.find("cup")
                transcript.append("  SAY  " + ItemMemory.answer(for: item, asked: "cup", now: Date(timeIntervalSince1970: 7200), sameFrame: false, measuredRelation: nil, arabic: false)
                                  + (item?.description.map { " It looks like this: \($0)" } ?? ""))
            }
        }
        answer("his cup is on the counter to his right; Ahmed's cup is further along", ["cup": 0.24, "ahmed's cup": 0.52], cupAt: Point3(4.7, 0, 4.2))
        answer("only one blue cup in view, side-on, close to both saved cups", ["cup": 0.36, "ahmed's cup": 0.40], cupAt: Point3(5.2, 0, 4.4))
        transcript.append("  (he picks it up and turns it; the chipped rim shows)")
        transcript.append("  person: Is this my cup?")
        let turned = ItemAppearanceMatch.decide(["cup": 0.21, "ahmed's cup": 0.49])
        transcript.append("  SAY  " + (turned == .same("cup") ? "Yes, this is your cup." : "It looks like your cup, but I can't be sure. Turn it slowly."))
        answer("no cup in view at all", ["cup": 0.9, "ahmed's cup": 0.95], cupAt: nil)
        try flush()
        XCTAssertTrue(transcript.contains { $0.contains("Your cup: ahead, slightly right") || $0.contains("Your cup: on your right") })
        XCTAssertTrue(transcript.contains { $0.contains("can't be sure it's yours") })
        XCTAssertTrue(transcript.contains { $0.contains("Yes, this is your cup.") })
        XCTAssertTrue(transcript.contains { $0.contains("Its current position is not confirmed") && $0.contains("Blue mug") })
    }

    /// Standing still in the bedroom with no walking heading yet: the bed and wardrobe as seen now
    /// (simulated LiDAR, with small noise) give position and facing, then the door direction follows.
    func testOrientationFromFurniture() throws {
        transcript.append("")
        transcript.append("=== Orientation from furniture: which way am I facing? ===")
        let bed = Point3(9.2, 0, 2.6), wardrobe = Point3(8.0, 0, 0.3), lamp = Point3(9.7, 0, 0.6)   // test landmarks
        let truePosition = Point3(8.3, 0, 1.6)
        let trueForward = Point3(sin(1.1), 0, -cos(1.1))   // turned about 63 degrees from the plan's axes
        let view = Observation(timestamp: 0, camera: truePosition, forward: trueForward, samples: [])
        let noise: [(Double, Double)] = [(0.04, -0.03), (-0.05, 0.02), (0.03, 0.05)]
        let sightings = zip([bed, wardrobe, lamp], noise).map { landmark, n -> LandmarkSighting in
            let seen = view.coordinates(landmark)
            return LandmarkSighting(mapPosition: landmark, relative: Point3(seen.side + n.0, 0, seen.ahead + n.1))
        }
        for (label, landmark) in [("Bed", bed), ("Wardrobe", wardrobe), ("Lamp", lamp)] {
            if let rel = SpatialFacts.relation(from: truePosition, facing: trueForward, to: landmark) {
                transcript.append("  (sensors see) " + SpatialFacts.phrase(label: label, relation: rel, arabic: false, inView: true))
            }
        }
        let estimate = try XCTUnwrap(LandmarkPose.solve(sightings))
        let headingError = acos(max(-1, min(1, estimate.forward.x * trueForward.x + estimate.forward.z * trueForward.z))) * 180 / .pi
        transcript.append(String(format: "  (pose from furniture: %.2f m from the true position, heading off by %.1f degrees, fit %.2f m)",
                                 estimate.position.distance(to: Point3(truePosition.x, 0, truePosition.z)), headingError, estimate.residualMetres))
        if let rel = SpatialFacts.relation(from: estimate.position, facing: estimate.forward, to: Self.doorBedroom.point),
           let truth = SpatialFacts.relation(from: truePosition, facing: trueForward, to: Self.doorBedroom.point) {
            transcript.append("  SAY  " + SpatialFacts.phrase(label: Self.doorBedroom.label, relation: rel, arabic: false, inView: nil))
            transcript.append("  (true answer) " + SpatialFacts.phrase(label: Self.doorBedroom.label, relation: truth, arabic: false, inView: nil))
            XCTAssertEqual(rel.sector, truth.sector, "the spoken direction matches the true one")
        }
        try flush()
        XCTAssertLessThan(estimate.position.distance(to: Point3(truePosition.x, 0, truePosition.z)), 0.2)
        XCTAssertLessThan(headingError, 10)
    }
}

private extension HomeWalkScenarioTests.Target {
    var flippedForLiving: HomeWalkScenarioTests.Target { .init(label: "Door to Living Room / Kitchen", point: point) }
}
