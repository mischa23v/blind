#include "../OpenCVRuntime.hpp"
// API/pipeline: OpenCV 4.14.0 samples/dnn/face_detect.cpp (Apache-2.0).
// Local adaptation: CGImage input, bounded resize, error translation, one-face gate.
#import "BAFaceEngine.h"
#include "BAFaceBatchSchedule.hpp"
#include <opencv2/core.hpp>
#include <opencv2/core/version.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/objdetect/face.hpp>
#include <cmath>
#include <stdexcept>
#include <chrono>
#include <numeric>
#include <vector>
#include <algorithm>
#if CV_VERSION_MAJOR != 4 || CV_VERSION_MINOR != 14 || CV_VERSION_REVISION != 0
#error Familiar people experiment requires reviewed OpenCV 4.14.0
#endif
@implementation BAFaceResult
@end
@implementation BAFaceBatch
@end
static void failure(NSError **error) {
    // Do not log biometric input, names, features, or local paths.
    if (error) *error = [NSError errorWithDomain:@"BlindAssist.FamiliarFaces" code:1
        userInfo:@{NSLocalizedDescriptionKey: @"Local face comparison unavailable."}];
}
static cv::Mat vectorFrom(NSArray<NSNumber *> *values, int dimension) {
    if (values.count != dimension) throw std::runtime_error("feature dimensions");
    cv::Mat feature(1, dimension, CV_32F);
    for (int i = 0; i < dimension; ++i) {
        float value = values[i].floatValue;
        if (!std::isfinite(value)) throw std::runtime_error("feature invalid");
        feature.at<float>(0, i) = value;
    }
    if (cv::norm(feature) < 1e-12) throw std::runtime_error("zero feature");
    return feature;
}
static cv::Mat imageBGR(CGImageRef image) {
        const size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        if (width == 0 || height == 0 || width > 8192 || height > 8192) throw std::runtime_error("image size");
        cv::Mat rgba((int)height, (int)width, CV_8UC4);
        CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(rgba.data, width, height, 8, rgba.step[0], color,
            kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(color);
        if (!context) throw std::runtime_error("image conversion");
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextRelease(context);
        cv::Mat bgr;
        cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);
        const double scale = std::min(1.0, 1024.0 / std::max(width, height));
        if (scale < 1.0) cv::resize(bgr, bgr, cv::Size((int)std::round(width * scale), (int)std::round(height * scale)));
    return bgr;
}
static void extractFace(const cv::Mat &bgr, const cv::Mat &faces, int row,
    const cv::Ptr<cv::FaceRecognizerSF> &recognizer, bool auraFace, int dimension,
    BOOL includeAlignedFace, BAFaceResult *result) {
        if (faces.cols != 15 || !cv::checkRange(faces.row(row))) throw std::runtime_error("invalid detection");
        const float *box = faces.ptr<float>(row);
        if (box[0] < 0 || box[1] < 0 || box[2] <= 0 || box[3] <= 0 ||
            box[0] + box[2] > bgr.cols || box[1] + box[3] > bgr.rows) throw std::runtime_error("clipped face");
        result.faceWidth = box[2]; result.faceHeight = box[3];
        result.normalizedBounds = CGRectMake(box[0] / bgr.cols, box[1] / bgr.rows, box[2] / bgr.cols, box[3] / bgr.rows);
        // All five landmarks must belong to this detection and image. Never apply
        // another row's landmarks to a cropped or shifted coordinate system.
        for (int landmark = 4; landmark < 14; landmark += 2) {
            if (box[landmark] < box[0] || box[landmark] > box[0] + box[2] ||
                box[landmark + 1] < box[1] || box[landmark + 1] > box[1] + box[3])
                throw std::runtime_error("landmark outside face");
        }
        cv::Mat aligned, feature;
        recognizer->alignCrop(bgr, faces.row(row), aligned);
        if (includeAlignedFace) {
            if (aligned.rows != 112 || aligned.cols != 112 || aligned.type() != CV_8UC3)
                throw std::runtime_error("aligned crop contract");
            cv::Mat rgb;
            cv::cvtColor(aligned, rgb, cv::COLOR_BGR2RGB);
            if (!rgb.isContinuous()) rgb = rgb.clone();
            result.alignedRGB = [NSData dataWithBytes:rgb.data length:112 * 112 * 3];
        }
        // Preserve the exact uint8 aligned RGB crop above for optional Vision matching.
        // FaceRecognizerSF 4.14 swaps BGR to RGB internally, with scale=1/mean=0.
        // AuraFace requires RGB float [-1,1]; never normalize SFace's uint8 input.
        if (auraFace) {
            cv::Mat normalized;
            aligned.convertTo(normalized, CV_32FC3);
            normalized -= cv::Scalar(127.5, 127.5, 127.5);
            normalized *= 1.0 / 127.5;
            recognizer->feature(normalized, feature);
        } else {
            recognizer->feature(aligned, feature);
        }
        if (feature.total() != (size_t)dimension || feature.type() != CV_32F || !cv::checkRange(feature) || cv::norm(feature) < 1e-12)
            throw std::runtime_error("invalid feature");
        feature = feature.reshape(1, 1);
        NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:dimension];
        for (int i = 0; i < dimension; ++i) [values addObject:@(feature.at<float>(0, i))];
        result.feature = values; result.centerX = (box[0] + box[2] / 2.0) / bgr.cols;
}
@implementation BAFaceEngine {
    int _dimension;
    BOOL _auraFace;
    cv::Ptr<cv::FaceDetectorYN> _detector;
    cv::Ptr<cv::FaceRecognizerSF> _recognizer;
}
- (nullable instancetype)initWithDetectorPath:(NSString *)detectorPath recognizerPath:(NSString *)recognizerPath error:(NSError **)error {
    return [self initWithDetectorPath:detectorPath recognizerPath:recognizerPath backendKind:@"sface" error:error];
}
- (nullable instancetype)initWithDetectorPath:(NSString *)detectorPath recognizerPath:(NSString *)recognizerPath backendKind:(NSString *)backendKind error:(NSError **)error {
    self = [super init];
    if (self) {
        try {
            if (![backendKind isEqualToString:@"sface"] && ![backendKind isEqualToString:@"auraface"])
                throw std::runtime_error("unknown backend");
            _auraFace = [backendKind isEqualToString:@"auraface"];
            _dimension = _auraFace ? 512 : 128;
            ba_runtime::configureOpenCVOnce();
            _detector = cv::FaceDetectorYN::create(detectorPath.UTF8String, "", cv::Size(320, 320), 0.9f, 0.3f, 5000);
            _recognizer = cv::FaceRecognizerSF::create(recognizerPath.UTF8String, "");
        } catch (const std::exception &) { failure(error); return nil; }
    }
    return self;
}
- (nullable BAFaceResult *)inspectImage:(CGImageRef)image includeAlignedFace:(BOOL)includeAlignedFace error:(NSError **)error {
    try {
        cv::Mat bgr = imageBGR(image);
        _detector->setInputSize(bgr.size());
        cv::Mat faces;
        _detector->detect(bgr, faces);
        BAFaceResult *result = [BAFaceResult new];
        result.faceCount = faces.rows; result.feature = @[]; result.alignedRGB = [NSData data]; result.centerX = 0.5;
        if (faces.rows != 1) return result; // Enrollment never selects a person out of a group.
        result.attempted = YES; result.detectionIndex = 0;
        extractFace(bgr, faces, 0, _recognizer, _auraFace, _dimension, includeAlignedFace, result);
        return result;
    } catch (const std::exception &) { failure(error); return nil; }
}
- (nullable BAFaceBatch *)inspectFacesInImage:(CGImageRef)image includeAlignedFace:(BOOL)includeAlignedFace startOffset:(NSInteger)startOffset error:(NSError **)error {
    try {
        const auto began = std::chrono::steady_clock::now();
        cv::Mat bgr = imageBGR(image), faces;
        _detector->setInputSize(bgr.size());
        _detector->detect(bgr, faces);
        BAFaceBatch *batch = [BAFaceBatch new];
        batch.faceCount = faces.rows; batch.faces = @[]; batch.nextOffset = 0;
        // Explicit crowd bound, not "all people identified". Never silently choose
        // the nearest/largest person or report an over-capacity frame as empty.
        batch.overCapacity = faces.rows > 32;
        if (faces.rows == 0 || batch.overCapacity) return batch;
        if (faces.cols != 15 || !cv::checkRange(faces)) throw std::runtime_error("invalid detections");
        std::vector<int> order(faces.rows);
        std::iota(order.begin(), order.end(), 0);
        std::stable_sort(order.begin(), order.end(), [&](int a, int b) {
            const float *x = faces.ptr<float>(a), *y = faces.ptr<float>(b);
            const float centerA = x[0] + x[2] / 2, centerB = y[0] + y[2] / 2;
            return centerA == centerB ? x[1] < y[1] : centerA < centerB;
        });
        NSMutableArray<BAFaceResult *> *values = [NSMutableArray arrayWithCapacity:faces.rows];
        for (int row : order) {
            BAFaceResult *value = [BAFaceResult new];
            const float *box = faces.ptr<float>(row);
            value.faceCount = 1; value.detectionIndex = row; value.feature = @[]; value.alignedRGB = [NSData data];
            value.faceWidth = box[2]; value.faceHeight = box[3];
            value.normalizedBounds = CGRectMake(box[0] / bgr.cols, box[1] / bgr.rows, box[2] / bgr.cols, box[3] / bgr.rows);
            value.centerX = (box[0] + box[2] / 2) / bgr.cols;
            [values addObject:value];
        }
        const NSInteger offset = std::max((NSInteger)0, startOffset) % faces.rows;
        batch.nextOffset = offset;
        for (int slot : ba_face::slots(faces.rows, offset)) {
            // A native inference cannot be preempted. Late results are discarded by
            // Swift's capture/pose gate; no backlog of old frames is accumulated.
            if (std::chrono::duration<double>(std::chrono::steady_clock::now() - began).count() >= 0.8) break;
            BAFaceResult *value = values[slot]; value.attempted = YES;
            batch.nextOffset = (slot + 1) % faces.rows;
            try {
                if (value.faceWidth < 80 || value.faceHeight < 80) continue;
                extractFace(bgr, faces, order[slot], _recognizer, _auraFace, _dimension, includeAlignedFace, value);
            } catch (const std::exception &) {
                value.feature = @[]; value.alignedRGB = [NSData data]; // Unknown, not another face's identity.
            }
        }
        batch.faces = values;
        return batch;
    } catch (const std::exception &) { failure(error); return nil; }
}
- (nullable NSArray<NSNumber *> *)scoresForFeature:(NSArray<NSNumber *> *)feature gallery:(NSArray<NSArray<NSNumber *> *> *)gallery error:(NSError **)error {
    try {
        if (gallery.count > 20) throw std::runtime_error("gallery size");
        cv::Mat probe = vectorFrom(feature, _dimension);
        NSMutableArray<NSNumber *> *scores = [NSMutableArray arrayWithCapacity:gallery.count];
        for (NSArray<NSNumber *> *values in gallery) {
            // OpenCV match normalizes its operands in place. Always use fresh clones.
            const double score = _recognizer->match(probe.clone(), vectorFrom(values, _dimension), cv::FaceRecognizerSF::FR_COSINE);
            if (!std::isfinite(score)) throw std::runtime_error("invalid score");
            [scores addObject:@(std::max(-1.0, std::min(1.0, score)))];
        }
        return scores;
    } catch (const std::exception &) { failure(error); return nil; }
}
@end
