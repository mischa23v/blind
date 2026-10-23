#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
/// Small adapter around OpenCV 4.14.0, not Face ID, PAD, or a trust classifier.
@interface BAFaceResult : NSObject
@property(nonatomic) NSInteger faceCount;
@property(nonatomic) double centerX;
@property(nonatomic) double faceWidth;
@property(nonatomic) double faceHeight;
/// Frame-local detector row. Never an identity or a cross-frame tracking identifier.
@property(nonatomic) NSInteger detectionIndex;
/// Normalized top-left-origin bounds in the SAME upright image used for alignment.
@property(nonatomic) CGRect normalizedBounds;
@property(nonatomic) BOOL attempted;
@property(nonatomic, copy) NSArray<NSNumber *> *feature;
/// Ephemeral 112x112 RGB bytes from the exact OpenCV alignCrop output; never persisted.
@property(nonatomic, copy) NSData *alignedRGB;
@end
@interface BAFaceBatch : NSObject
@property(nonatomic) NSInteger faceCount;
@property(nonatomic) NSInteger nextOffset;
@property(nonatomic) BOOL overCapacity;
@property(nonatomic, copy) NSArray<BAFaceResult *> *faces;
@end
@interface BAFaceEngine : NSObject
- (nullable instancetype)initWithDetectorPath:(NSString *)detectorPath
                             recognizerPath:(NSString *)recognizerPath
                                      error:(NSError **)error;
- (nullable instancetype)initWithDetectorPath:(NSString *)detectorPath
                             recognizerPath:(NSString *)recognizerPath
                                backendKind:(NSString *)backendKind
                                      error:(NSError **)error;
- (nullable BAFaceResult *)inspectImage:(CGImageRef)image includeAlignedFace:(BOOL)includeAlignedFace error:(NSError **)error NS_SWIFT_NAME(inspect(image:includeAlignedFace:));
/// Recognition only. Enrollment continues through inspectImage's exact-one-face gate.
/// At most two embeddings per pass; rotate through spatially ordered detections.
/// The deadline is checked between native operations, not a preemptible runtime guarantee.
- (nullable BAFaceBatch *)inspectFacesInImage:(CGImageRef)image
                          includeAlignedFace:(BOOL)includeAlignedFace
                                 startOffset:(NSInteger)startOffset
                                       error:(NSError **)error NS_SWIFT_NAME(inspectFaces(image:includeAlignedFace:startOffset:));
- (nullable NSArray<NSNumber *> *)scoresForFeature:(NSArray<NSNumber *> *)feature
                                          gallery:(NSArray<NSArray<NSNumber *> *> *)gallery
                                            error:(NSError **)error NS_SWIFT_NAME(scores(feature:gallery:));
@end
NS_ASSUME_NONNULL_END
