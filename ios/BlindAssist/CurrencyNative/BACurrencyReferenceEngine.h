#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
/// Private source bytes whose SHA and metadata were checked by the Swift loader.
/// Coordinates are TL/TR/BR/BL source pixels, flattened x,y pairs. Not descriptors.
@interface BACurrencyReferenceInput : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic) NSInteger label;
@property(nonatomic, copy) NSData *encodedImage;
@property(nonatomic) NSInteger sourceWidth;
@property(nonatomic) NSInteger sourceHeight;
@property(nonatomic, copy) NSArray<NSNumber *> *boundary;
@end
/// Raw geometric measurements, never calibrated probabilities or spoken values.
@interface BACurrencyReferenceCandidate : NSObject
@property(nonatomic, copy) NSString *referenceID;
@property(nonatomic) NSInteger label, regionIndex, ratioMatches, inliers, gridCells;
@property(nonatomic) double inlierRatio, score, areaFraction, referenceSpread, querySpread;
@property(nonatomic) double edgeRatio, oppositeEdgeRatio, projectiveRatio, medianError, minimumEdge;
@property(nonatomic, copy) NSArray<NSNumber *> *angles;
@property(nonatomic, copy) NSArray<NSNumber *> *quad;
@property(nonatomic) BOOL finiteHomography, convex, fullyInFrame;
@end
@interface BACurrencyReferenceEvidence : NSObject
@property(nonatomic, copy) NSArray<BACurrencyReferenceCandidate *> *candidates;
@property(nonatomic, copy) NSArray<NSNumber *> *overlaps;
@property(nonatomic) NSInteger queryWidth, queryHeight;
@end
/// Actor-owned adapter around OpenCV 4.14.0 SIFT/ORB/AKAZE + BFMatcher + RANSAC.
/// No pixels/descriptors leave RAM. Does not independently prove a single-note scene.
@interface BACurrencyReferenceEngine : NSObject
- (nullable instancetype)initWithReferences:(NSArray<BACurrencyReferenceInput *> *)references
                                 algorithm:(NSString *)algorithm
                                  settings:(NSDictionary<NSString *, NSNumber *> *)settings
                                     error:(NSError **)error;
- (nullable BACurrencyReferenceEvidence *)inspectImage:(CGImageRef)image
                                               error:(NSError **)error NS_SWIFT_NAME(inspect(image:));
@end
NS_ASSUME_NONNULL_END
