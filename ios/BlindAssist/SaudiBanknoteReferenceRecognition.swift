import Foundation
import CoreImage
import CoreVideo
import CryptoKit
import ImageIO
import Vision
import BlindCore

/// Build-time selection only: no remote config or query-driven threshold fitting.
/// All three algorithms are available, but no production algorithm/profile is chosen.
struct SaudiBanknoteReferenceProfile: Sendable {
    let algorithm: SaudiBanknoteReferencePolicy.Algorithm
    let manifestSHA256: String
    let thresholds: SaudiBanknoteReferencePolicy.Thresholds
    let approval: SaudiBanknoteReferencePolicy.ReleaseApproval
    static let selected: SaudiBanknoteReferenceProfile? = nil
    var valid: Bool {
        SaudiBanknoteReferencePolicy.validSHA(manifestSHA256) && thresholds.valid && approval.valid
            && approval.referencePackSHA256 == manifestSHA256
    }
}

/// Offline reference matching adapter, not an Apple/LLM currency recognizer.
/// No query pixels, descriptors, metadata or outputs are written to disk or sent.
/// Vision rectangles are a conservative veto, not a single-note proof. Same-design,
/// overlapping, hidden, folded and unknown notes can evade both detectors. This
/// source is not release-ready, and the selected profile deliberately remains nil.
actor SaudiBanknoteReferenceRecognition {
    enum Failure: Error { case unavailable, incompatible }
    nonisolated static var isAvailable: Bool {
        #if BLIND_CURRENCY_REFERENCE
        return SaudiBanknoteReferenceProfile.selected?.valid == true
        #else
        return false
        #endif
    }
    private let profile: SaudiBanknoteReferenceProfile?
    private let context = CIContext(options: [.cacheIntermediates: false])
    #if BLIND_CURRENCY_REFERENCE
    private var loaded: BACurrencyReferenceEngine?
    private var labelsByReference: [String: Int] = [:]
    #endif
    init(profile: SaudiBanknoteReferenceProfile? = SaudiBanknoteReferenceProfile.selected) { self.profile = profile }

    func inspect(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> SaudiBanknotePolicy.Result {
        try Task.checkCancellation()
        #if BLIND_CURRENCY_REFERENCE
        guard let profile, profile.valid else { throw Failure.unavailable }
        let engine = try engine(profile: profile)
        try Task.checkCancellation()
        // Reject oversized buffers before rendering. Never crop the full query: that
        // can conceal the other half of a composite or an unrecognized second note.
        let width = CVPixelBufferGetWidth(image), height = CVPixelBufferGetHeight(image)
        guard (32...4096).contains(width), (32...4096).contains(height), width * height <= 8_000_000 else { return .unknown }
        let upright = CIImage(cvPixelBuffer: image).oriented(orientation)
        let extent = upright.extent
        guard !extent.isEmpty, !extent.isInfinite,
              [extent.minX, extent.minY, extent.width, extent.height].allSatisfy(\.isFinite),
              let cg = context.createCGImage(upright, from: extent, format: .RGBA8,
                  colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else { return .unknown }
        try Task.checkCancellation()
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 32
        rectangles.minimumConfidence = 0.3
        rectangles.minimumSize = 0.05
        rectangles.minimumAspectRatio = 0.2
        rectangles.maximumAspectRatio = 1.0
        try VNImageRequestHandler(cgImage: cg, orientation: .up).perform([rectangles])
        try Task.checkCancellation()
        guard let proposals = rectangles.results, !proposals.isEmpty else { return .unknown }
        guard proposals.count == 1 else { return .multiple }
        let native = try engine.inspect(image: cg)
        try Task.checkCancellation()
        guard Set(native.candidates.map(\.referenceID)) == Set(labelsByReference.keys),
              native.candidates.allSatisfy({ labelsByReference[$0.referenceID] == $0.label }) else { throw Failure.incompatible }
        let candidates = try native.candidates.map { c -> SaudiBanknoteReferencePolicy.Candidate in
            guard c.quad.count == 0 || c.quad.count == 8 else { throw Failure.incompatible }
            let quad = stride(from: 0, to: c.quad.count, by: 2).map { i in
                SaudiBanknoteReferencePolicy.Point(x: c.quad[i].doubleValue, y: c.quad[i+1].doubleValue)
            }
            return .init(referenceID: c.referenceID, label: c.label, regionIndex: c.regionIndex,
                ratioMatches: c.ratioMatches, inliers: c.inliers, gridCells: c.gridCells,
                inlierRatio: c.inlierRatio, score: c.score, areaFraction: c.areaFraction,
                referenceSpread: c.referenceSpread, querySpread: c.querySpread, edgeRatio: c.edgeRatio,
                oppositeEdgeRatio: c.oppositeEdgeRatio, projectiveRatio: c.projectiveRatio,
                medianError: c.medianError, minimumEdge: c.minimumEdge, angles: c.angles.map(\.doubleValue),
                quad: quad, finiteHomography: c.finiteHomography, convex: c.convex, fullyInFrame: c.fullyInFrame)
        }
        let frameProposals = proposals.map { observation -> SaudiBanknoteReferencePolicy.FrameProposal in
            // Preserve perspective corners, not just the bounding box: a tilted
            // inner note and an outer composite can have the same axis-aligned box.
            let points = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
            return .init(corners: points.map { .init(x: $0.x, y: 1-$0.y) })
        }
        let evidence = SaudiBanknoteReferencePolicy.Evidence(candidates: candidates,
            overlaps: native.overlaps.map(\.doubleValue), queryWidth: native.queryWidth, queryHeight: native.queryHeight,
            frameProposals: frameProposals)
        try Task.checkCancellation()
        return SaudiBanknoteReferencePolicy.decide(evidence, thresholds: profile.thresholds, approval: profile.approval)
        #else
        throw Failure.unavailable
        #endif
    }
    #if BLIND_CURRENCY_REFERENCE
    private func engine(profile: SaudiBanknoteReferenceProfile) throws -> BACurrencyReferenceEngine {
        if let loaded { return loaded }
        guard let resources = Bundle.main.resourceURL else { throw Failure.unavailable }
        let root = resources.appendingPathComponent("SaudiBanknoteReferences", isDirectory: true)
        let bytes = try boundedFile(root: root, relativePath: "manifest.json", limit: SaudiBanknoteReferencePolicy.Limits.manifestBytes)
        guard digest(bytes) == profile.manifestSHA256 else { throw Failure.incompatible }
        let pack = try SaudiBanknoteReferencePack.parse(bytes)
        guard pack.allHumanReviewed, pack.minimumCoverage else { throw Failure.unavailable }
        var inputs: [BACurrencyReferenceInput] = [], totalBytes = 0
        for reference in pack.references {
            try Task.checkCancellation()
            let data = try boundedFile(root: root, relativePath: reference.path, limit: SaudiBanknoteReferencePolicy.Limits.imageBytes)
            totalBytes += data.count
            guard totalBytes <= SaudiBanknoteReferencePolicy.Limits.totalReferenceBytes,
                  digest(data) == reference.sha256 else { throw Failure.incompatible }
            let input = BACurrencyReferenceInput()
            input.identifier = reference.id; input.label = reference.label; input.encodedImage = data
            input.sourceWidth = reference.sourceWidth; input.sourceHeight = reference.sourceHeight
            input.boundary = reference.boundary.flatMap { [NSNumber(value: $0.x), NSNumber(value: $0.y)] }
            inputs.append(input)
        }
        let t = profile.thresholds
        let engine = try BACurrencyReferenceEngine(references: inputs, algorithm: profile.algorithm.rawValue,
            settings: ["ratio_test": NSNumber(value: t.ratioTest), "ransac_error_px": NSNumber(value: t.ransacError),
                       "ransac_iterations": NSNumber(value: t.ransacIterations),
                       "minimum_area": NSNumber(value: t.minimumArea), "maximum_area": NSNumber(value: t.maximumArea),
                       "minimum_angle": NSNumber(value: t.minimumAngle), "maximum_angle": NSNumber(value: t.maximumAngle),
                       "maximum_edge_ratio": NSNumber(value: t.maximumEdgeRatio),
                       "maximum_opposite_edge_ratio": NSNumber(value: t.maximumOppositeEdgeRatio),
                       "maximum_projective_ratio": NSNumber(value: t.maximumProjectiveRatio),
                       "minimum_reference_spread": NSNumber(value: t.minimumReferenceSpread),
                       "minimum_query_spread": NSNumber(value: t.minimumQuerySpread),
                       "maximum_median_error": NSNumber(value: t.maximumMedianError),
                       "minimum_grid_cells": NSNumber(value: t.minimumGridCells)])
        try Task.checkCancellation()
        labelsByReference = Dictionary(uniqueKeysWithValues: pack.references.map { ($0.id, $0.label) })
        loaded = engine
        return engine
    }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func boundedFile(root: URL, relativePath: String, limit: Int) throws -> Data {
        guard root.isFileURL, SaudiBanknoteReferencePack.safeRelativePath(relativePath) else { throw Failure.incompatible }
        let realRoot = root.resolvingSymlinksInPath().standardizedFileURL
        guard try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
              try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw Failure.incompatible }
        var file = root
        for component in relativePath.split(separator: "/") {
            file.appendPathComponent(String(component))
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw Failure.incompatible }
        }
        file = file.resolvingSymlinksInPath().standardizedFileURL
        guard file.path.hasPrefix(realRoot.path + "/") else { throw Failure.incompatible }
        let properties = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard properties.isRegularFile == true, let size = properties.fileSize, size > 0, size <= limit else { throw Failure.incompatible }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= limit {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: min(64 * 1024, limit + 1 - data.count)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard !data.isEmpty, data.count <= limit, data.count == size else { throw Failure.incompatible }
        return data
    }
    #endif
}
