import Foundation

/// A build-selected, immutable embedding profile. Galleries must match the full profile.
/// Changing backends requires fresh enrollment; embeddings are not interchangeable.
struct FamiliarModelConfiguration {
    let backendKind: String
    let detectorFilename: String
    let recognizerFilename: String
    let detectorIdentifier: String
    let recognizerIdentifier: String
    let detectorSHA256: String
    let recognizerSHA256: String
    let embeddingDimension: Int
    // Dataset-calibrated experimental starting points, not validated app accuracy.
    // Separate from embedding identity: policy changes do not reinterpret vectors.
    let cosineThreshold: Double
    let minimumMargin: Double
    let policyIdentifier: String

    static let selected: FamiliarModelConfiguration = {
        #if BLIND_FAMILIAR_AURAFACE
        return FamiliarModelConfiguration(
            backendKind: "auraface",
            detectorFilename: "face_detection_yunet_2023mar.onnx",
            recognizerFilename: "glintr100.onnx",
            detectorIdentifier: "yunet-2023mar",
            recognizerIdentifier: "auraface-v1-af6d057c9b0ec4071d4c49c80e3539258798b609-rgb-minus1-plus1",
            detectorSHA256: "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
            recognizerSHA256: "a7933ea5330113b01c9b60351d8f4c33003f145d8470ac5f0e52ee2effe25c60",
            embeddingDimension: 512,
            cosineThreshold: 0.5,
            minimumMargin: 0.2,
            policyIdentifier: "aberdeen-calibration-20261022-auraface-cosine050-margin020-v1")
        #else
        return FamiliarModelConfiguration(
            backendKind: "sface",
            detectorFilename: "face_detection_yunet_2023mar.onnx",
            recognizerFilename: "face_recognition_sface_2021dec.onnx",
            detectorIdentifier: "yunet-2023mar",
            recognizerIdentifier: "sface-2021dec",
            detectorSHA256: "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
            recognizerSHA256: "0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79",
            embeddingDimension: 128,
            cosineThreshold: 0.7,
            minimumMargin: 0.2,
            policyIdentifier: "aberdeen-calibration-20261022-sface-cosine070-margin020-v1")
        #endif
    }()
}
