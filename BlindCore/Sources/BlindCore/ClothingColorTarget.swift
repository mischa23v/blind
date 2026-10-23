import Foundation

/// Portable mask-selection policy around Apple's foreground-instance output. It does not
/// recognise an item, establish that it is held, or resolve what a person means by "this".
/// Thresholds are conservative product policy, not measured native accuracy/confidence.
public enum ClothingColorTarget {
    public struct Region: Equatable, Sendable {
        /// Upright-image coordinates, origin at the top left, each dimension in 0...1.
        public let x: Double, y: Double, width: Double, height: Double
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x; self.y = y; self.width = width; self.height = height
        }
        public var isValid: Bool {
            [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
                width > 0 && height > 0 && x + width <= 1 && y + height <= 1
        }
        private var right: Double { x + width }
        private var bottom: Double { y + height }
        fileprivate func overlaps(_ other: Region) -> Bool {
            max(x, other.x) < min(right, other.right) && max(y, other.y) < min(bottom, other.bottom)
        }
    }

    public enum Unresolved: String, Error, Equatable, Sendable {
        case invalidMask, noForeground, multipleForegroundItems, personOverlap, insufficientInterior

        /// Failure describes the available evidence, never a command to handle an
        /// unknown object or a claim that the frame contains clothing/a particular item.
        public func speech(arabic: Bool) -> String {
            switch self {
            case .invalidMask:
                return arabic ? "تعذر التحقق من المنطقة المختارة في هذه اللقطة." : "I couldn't verify the sampled area in this view."
            case .noForeground:
                return arabic ? "لم أتمكن من عزل غرض لفحص لونه في هذه اللقطة." : "I couldn't isolate an item for a colour check in this view."
            case .multipleForegroundItems:
                return arabic ? "ظهر أكثر من غرض محتمل، ولم أحدد أيها تقصد." : "There are multiple possible items in the captured view; I haven't established which one you mean."
            case .personOverlap:
                return arabic ? "لم أستطع فصل منطقة الغرض عن الشخص في هذه اللقطة." : "I couldn't separate the item's sampled area from the person in this view."
            case .insufficientInterior:
                return arabic ? "لم تتوفر منطقة واضحة كافية لتقدير اللون في هذه اللقطة." : "There wasn't enough clear area for a colour estimate in this view."
            }
        }
    }

    public struct Sample: Equatable, Sendable {
        public let x: Int, y: Int
        fileprivate init(x: Int, y: Int) { self.x = x; self.y = y }
    }

    /// Only anonymous appearance authority. This is deliberately not a target ID, a garment
    /// identity, or permission to label the result as the requested "this"/pot/outfit.
    public struct AnonymousSelection: Equatable, Sendable {
        public let instance: Int
        public let bounds: Region
        public let samplePixels: [Sample]
        fileprivate init(instance: Int, bounds: Region, samplePixels: [Sample]) {
            self.instance = instance; self.bounds = bounds; self.samplePixels = samplePixels
        }
    }
    public enum Decision: Equatable, Sendable {
        case anonymous(AnonymousSelection)
        case unresolved(Unresolved)
    }

    /// Select the ONLY visible foreground instance, including when it is off-centre.
    /// No central/largest/nearest fallback exists when several foreground instances appear.
    /// UInt8 labels and top-left rows follow Apple's instance-mask format. `people` must be
    /// same-frame upright rectangles converted from Vision's bottom-left convention.
    public static func select(labels: [UInt8], maskWidth: Int, maskHeight: Int, bytesPerRow: Int,
                              validInstances: Set<Int>, imageWidth: Int, imageHeight: Int,
                              people: [Region]) -> Decision {
        guard (9...1024).contains(maskWidth), (9...1024).contains(maskHeight),
              (maskWidth...4096).contains(bytesPerRow), labels.count == bytesPerRow * maskHeight,
              (1...256).contains(imageWidth), (1...256).contains(imageHeight),
              validInstances.allSatisfy({ (1...255).contains($0) }) else { return .unresolved(.invalidMask) }
        var instances: Set<Int> = []
        var minX = maskWidth, minY = maskHeight, maxX = -1, maxY = -1
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let label = Int(labels[y * bytesPerRow + x])
                guard label != 0 else { continue }
                guard validInstances.contains(label) else { return .unresolved(.invalidMask) }
                instances.insert(label)
                if instances.count > 1 { return .unresolved(.multipleForegroundItems) }
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard let instance = instances.first else { return .unresolved(.noForeground) }
        let bounds = Region(x: Double(minX) / Double(maskWidth), y: Double(minY) / Double(maskHeight),
            width: Double(maxX - minX + 1) / Double(maskWidth), height: Double(maxY - minY + 1) / Double(maskHeight))
        // A person rectangle crossing any part of the selected object is ambiguous: a person
        // mask can contain clothing, skin and hair. Centre-only person rejection is insufficient.
        guard people.allSatisfy({ $0.isValid && !bounds.overlaps($0) }) else { return .unresolved(.personOverlap) }
        let startX = Int(ceil((bounds.x + bounds.width * 0.3) * Double(imageWidth)))
        let endX = Int(floor((bounds.x + bounds.width * 0.7) * Double(imageWidth)))
        let startY = Int(ceil((bounds.y + bounds.height * 0.3) * Double(imageHeight)))
        let endY = Int(floor((bounds.y + bounds.height * 0.7) * Double(imageHeight)))
        guard startX < endX, startY < endY else { return .unresolved(.insufficientInterior) }
        let candidates = (endX - startX) * (endY - startY)
        guard candidates >= 64 else { return .unresolved(.insufficientInterior) }
        var samples: [Sample] = []
        let offsets = [-2, 0, 2]
        for y in startY..<endY {
            for x in startX..<endX {
                let mx = x * maskWidth / imageWidth, my = y * maskHeight / imageHeight
                // Never clamp an erosion sample back into the object at an image edge.
                guard mx >= 2, my >= 2, mx + 2 < maskWidth, my + 2 < maskHeight else { continue }
                guard offsets.allSatisfy({ dx in offsets.allSatisfy { dy in
                    Int(labels[(my + dy) * bytesPerRow + mx + dx]) == instance
                } }) else { continue }
                samples.append(Sample(x: x, y: y))
            }
        }
        guard samples.count >= 64, Double(samples.count) / Double(candidates) >= 0.8 else {
            return .unresolved(.insufficientInterior)
        }
        return .anonymous(AnonymousSelection(instance: instance, bounds: bounds, samplePixels: samples))
    }
}
