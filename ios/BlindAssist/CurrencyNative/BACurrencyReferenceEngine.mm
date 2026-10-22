#import "BACurrencyReferenceEngine.h"
#import <ImageIO/ImageIO.h>
#include "BACurrencyReferenceMatcher.hpp"
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgcodecs/ios.h>
#include <memory>
@implementation BACurrencyReferenceInput
@end
@implementation BACurrencyReferenceCandidate
@end
@implementation BACurrencyReferenceEvidence
@end
static void BACurrencyFailure(NSError **error) {
    // No source paths, input images, descriptors or private metadata in errors/logs.
    if (error) *error=[NSError errorWithDomain:@"BlindAssist.CurrencyReferences" code:1
        userInfo:@{NSLocalizedDescriptionKey:@"Local banknote reference comparison unavailable."}];
}
static double setting(NSDictionary<NSString *,NSNumber *> *settings, NSString *key) {
    id value=settings[key];
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID() ||
        !std::isfinite([value doubleValue])) throw std::runtime_error("configuration");
    return [value doubleValue];
}
static cv::Mat referenceGray(BACurrencyReferenceInput *reference) {
    NSData *data=reference.encodedImage;
    if (!data || data.length==0 || data.length>8*1024*1024) throw std::runtime_error("reference bytes");
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,nullptr);
    if (!source) throw std::runtime_error("reference header");
    CFStringRef type=CGImageSourceGetType(source);
    const bool allowed=type && (CFEqual(type,CFSTR("public.png")) || CFEqual(type,CFSTR("public.jpeg")));
    const size_t count=CGImageSourceGetCount(source);
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,nullptr));
    CGImageSourceStatus status=CGImageSourceGetStatus(source);
    CFRelease(source);
    NSInteger width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] integerValue];
    NSInteger height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] integerValue];
    NSNumber *orientation=properties[(__bridge NSString *)kCGImagePropertyOrientation];
    if (!allowed || count!=1 || status!=kCGImageStatusComplete || (orientation && orientation.integerValue!=1) ||
        width<32 || height<32 || width>4096 || height>4096 || width*height>8000000 ||
        width!=reference.sourceWidth || height!=reference.sourceHeight) throw std::runtime_error("reference dimensions");
    const cv::Mat encoded(1,(int)data.length,CV_8U,const_cast<void *>(data.bytes));
    cv::Mat gray=cv::imdecode(encoded,cv::IMREAD_GRAYSCALE | cv::IMREAD_IGNORE_ORIENTATION);
    if (gray.empty() || gray.type()!=CV_8UC1 || gray.cols!=width || gray.rows!=height) throw std::runtime_error("reference decode");
    return gray;
}
static cv::Mat queryGray(CGImageRef image) {
    if (!image) throw std::runtime_error("query image");
    const size_t width=CGImageGetWidth(image),height=CGImageGetHeight(image);
    if (width<32 || height<32 || width>4096 || height>4096 || width*height>8000000) throw std::runtime_error("query dimensions");
    cv::Mat rgba,gray;
    // Reuse OpenCV's official CoreGraphics adapter rather than invent a raster flip.
    CGImageToMat(image,rgba,false);
    if (rgba.type()==CV_8UC4) cv::cvtColor(rgba,gray,cv::COLOR_RGBA2GRAY);
    else if (rgba.type()==CV_8UC3) cv::cvtColor(rgba,gray,cv::COLOR_RGB2GRAY);
    else if (rgba.type()==CV_8UC1) gray=rgba;
    else throw std::runtime_error("query pixel format");
    const double scale=std::min(1.,1200./std::max(width,height));
    if (scale<1) cv::resize(gray,gray,cv::Size((int)std::nearbyint(width*scale),(int)std::nearbyint(height*scale)),0,0,cv::INTER_AREA);
    return gray;
}
static NSArray<NSNumber *> *numbers(const std::vector<double> &values) {
    NSMutableArray<NSNumber *> *array=[NSMutableArray arrayWithCapacity:values.size()];
    for (double value:values) {if (!std::isfinite(value)) throw std::runtime_error("nonfinite evidence");[array addObject:@(value)];}
    return array;
}
@implementation BACurrencyReferenceEngine {
    std::unique_ptr<ba_currency::Matcher> _matcher;
}
- (nullable instancetype)initWithReferences:(NSArray<BACurrencyReferenceInput *> *)references algorithm:(NSString *)algorithm
                                  settings:(NSDictionary<NSString *,NSNumber *> *)settings error:(NSError **)error {
    self=[super init];
    if (self) {
        try {
            if (references.count<1 || references.count>48 || settings.count!=14) throw std::runtime_error("reference count/settings");
            ba_currency::Settings options;
            options.ratioTest=setting(settings,@"ratio_test");options.ransacError=setting(settings,@"ransac_error_px");
            const double iterations=setting(settings,@"ransac_iterations");
            if (iterations<1 || iterations>5000 || std::floor(iterations)!=iterations) throw std::runtime_error("iteration bounds");
            options.ransacIterations=(int)iterations;
            options.minimumArea=setting(settings,@"minimum_area");options.maximumArea=setting(settings,@"maximum_area");
            options.minimumAngle=setting(settings,@"minimum_angle");options.maximumAngle=setting(settings,@"maximum_angle");
            options.maximumEdgeRatio=setting(settings,@"maximum_edge_ratio");
            options.maximumOppositeEdgeRatio=setting(settings,@"maximum_opposite_edge_ratio");
            options.maximumProjectiveRatio=setting(settings,@"maximum_projective_ratio");
            options.minimumReferenceSpread=setting(settings,@"minimum_reference_spread");
            options.minimumQuerySpread=setting(settings,@"minimum_query_spread");
            options.maximumMedianError=setting(settings,@"maximum_median_error");
            const double cells=setting(settings,@"minimum_grid_cells");
            if (cells<1 || cells>9 || std::floor(cells)!=cells) throw std::runtime_error("grid bounds");
            options.minimumGridCells=(int)cells;
            _matcher=std::make_unique<ba_currency::Matcher>(algorithm.UTF8String,options);
            NSUInteger total=0;
            for (BACurrencyReferenceInput *r in references) {
                total+=r.encodedImage.length;if (total>96*1024*1024 || r.boundary.count!=8) throw std::runtime_error("reference bounds");
                std::vector<cv::Point2f> corners;
                for (int i=0;i<8;i+=2) {
                    double x=r.boundary[i].doubleValue,y=r.boundary[i+1].doubleValue;
                    if (!std::isfinite(x) || !std::isfinite(y)) throw std::runtime_error("boundary");
                    corners.emplace_back((float)x,(float)y);
                }
                _matcher->add(r.identifier.UTF8String,(int)r.label,referenceGray(r),corners);
            }
        } catch (const std::exception &) {BACurrencyFailure(error);return nil;}
    }
    return self;
}
- (nullable BACurrencyReferenceEvidence *)inspectImage:(CGImageRef)image error:(NSError **)error {
    try {
        if (!_matcher) throw std::runtime_error("unavailable");
        const auto evidence=_matcher->inspect(queryGray(image));
        BACurrencyReferenceEvidence *result=[BACurrencyReferenceEvidence new];
        result.queryWidth=evidence.width;result.queryHeight=evidence.height;result.overlaps=numbers(evidence.overlaps);
        NSMutableArray<BACurrencyReferenceCandidate *> *candidates=[NSMutableArray arrayWithCapacity:evidence.candidates.size()];
        for (const auto &c:evidence.candidates) {
            BACurrencyReferenceCandidate *output=[BACurrencyReferenceCandidate new];
            output.referenceID=[NSString stringWithUTF8String:c.id.c_str()];output.label=c.label;output.regionIndex=c.region;
            output.ratioMatches=c.ratioMatches;output.inliers=c.inliers;output.gridCells=c.gridCells;
            output.inlierRatio=c.inlierRatio;output.score=c.score;output.areaFraction=c.areaFraction;
            output.referenceSpread=c.referenceSpread;output.querySpread=c.querySpread;output.edgeRatio=c.edgeRatio;
            output.oppositeEdgeRatio=c.oppositeEdgeRatio;output.projectiveRatio=c.projectiveRatio;
            output.medianError=c.medianError;output.minimumEdge=c.minimumEdge;output.angles=numbers(c.angles);
            output.finiteHomography=c.finiteHomography;output.convex=c.convex;output.fullyInFrame=c.fullyInFrame;
            std::vector<double> quad;for (const auto &point:c.quad) {quad.push_back(point.x);quad.push_back(point.y);}
            output.quad=numbers(quad);[candidates addObject:output];
        }
        result.candidates=candidates;return result;
    } catch (const std::exception &) {BACurrencyFailure(error);return nil;}
}
@end
