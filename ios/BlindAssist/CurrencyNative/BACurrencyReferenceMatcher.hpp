#pragma once
// OpenCV 4.14.0, Apache-2.0: feature matching + findHomography APIs.
// Port of tools/currency-reference/reference_match.py / prepare_reference.py.
// No learned weights, OCR, nearest-wins classification, networking or persistence.
// These experimental metrics are not probabilities and cannot authorize cash speech.
#include <opencv2/core.hpp>
#include <opencv2/core/version.hpp>
#include "../OpenCVRuntime.hpp"
#include <opencv2/features2d.hpp>
#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <map>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>
#if CV_VERSION_MAJOR != 4 || CV_VERSION_MINOR != 14 || CV_VERSION_REVISION != 0
#error Currency reference adapter requires reviewed OpenCV 4.14.0
#endif
namespace ba_currency {
constexpr int maxFeatures = 1800, maxReferences = 48, maxQuerySide = 1200, maxReferenceSide = 800;
struct Settings {
    double ratioTest = .72, ransacError = 3;
    int ransacIterations = 1500, minimumGridCells = 5;
    double minimumArea=.04, maximumArea=.90, minimumAngle=25, maximumAngle=155;
    double maximumEdgeRatio=6, maximumOppositeEdgeRatio=3, maximumProjectiveRatio=3;
    double minimumReferenceSpread=.20, minimumQuerySpread=.20, maximumMedianError=2.5;
};
struct Candidate {
    std::string id;
    int label = 0, region = 0, ratioMatches = 0, inliers = 0, gridCells = 0;
    double inlierRatio = 0, score = 0, areaFraction = 0, referenceSpread = 0, querySpread = 0;
    double edgeRatio = 0, oppositeEdgeRatio = 0, projectiveRatio = 0, medianError = 0, minimumEdge = 0;
    std::vector<double> angles;
    std::vector<cv::Point2f> quad;
    bool finiteHomography = false, convex = false, fullyInFrame = false;
};
struct Reference {
    std::string id;
    int label;
    cv::Size size;
    std::vector<cv::KeyPoint> points;
    cv::Mat descriptors;
};
struct Evidence {
    int width = 0, height = 0;
    std::vector<Candidate> candidates;
    std::vector<double> overlaps;
};
inline bool finitePoint(const cv::Point2f &p) { return std::isfinite(p.x) && std::isfinite(p.y); }
inline cv::Ptr<cv::Feature2D> detector(const std::string &algorithm) {
    if (algorithm == "sift") return cv::SIFT::create(maxFeatures, 3, .04, 10, 1.6, false);
    if (algorithm == "orb") return cv::ORB::create(maxFeatures, 1.2f, 8, 31, 0, 2, cv::ORB::HARRIS_SCORE, 31, 20);
    if (algorithm == "akaze") return cv::AKAZE::create(cv::AKAZE::DESCRIPTOR_MLDB, 0, 3, .001f, 4, 4, cv::KAZE::DIFF_PM_G2, maxFeatures);
    throw std::runtime_error("unsupported algorithm");
}
inline void features(const cv::Ptr<cv::Feature2D> &d, const cv::Mat &gray,
                     std::vector<cv::KeyPoint> &points, cv::Mat &descriptors) {
    d->detectAndCompute(gray, cv::noArray(), points, descriptors);
    // SIFT can retain tied responses over nfeatures; deterministic bounded truncation
    // is an explicit adapter difference and must be covered by device parity tests.
    if (points.size() > maxFeatures) {
        points.resize(maxFeatures); descriptors = descriptors.rowRange(0, maxFeatures).clone();
    }
    if (!descriptors.empty() && (descriptors.rows != (int)points.size() || !cv::checkRange(descriptors)))
        throw std::runtime_error("descriptor contract");
}
inline cv::Mat prepare(const cv::Mat &gray, const std::vector<cv::Point2f> &corners) {
    if (gray.type() != CV_8UC1 || gray.cols < 32 || gray.rows < 32 || gray.cols > 4096 || gray.rows > 4096 ||
        gray.total() > 8000000 || corners.size() != 4) throw std::runtime_error("reference bounds");
    std::array<double, 4> lengths;
    for (int i = 0; i < 4; ++i) {
        const auto p = corners[i];
        if (!finitePoint(p) || p.x < 0 || p.y < 0 || p.x > gray.cols-1 || p.y > gray.rows-1)
            throw std::runtime_error("reference corners");
        const auto a = corners[(i+1)%4]-p, b = corners[(i+2)%4]-corners[(i+1)%4];
        if (a.cross(b) <= 0) throw std::runtime_error("reference corner order");
        lengths[i] = cv::norm(a);
    }
    if (!cv::isContourConvex(corners) || *std::min_element(lengths.begin(), lengths.end()) < 32 ||
        std::abs(cv::contourArea(corners)) < .10*gray.total() ||
        std::max(lengths[0], lengths[2])/std::min(lengths[0], lengths[2]) > 3 ||
        std::max(lengths[1], lengths[3])/std::min(lengths[1], lengths[3]) > 3)
        throw std::runtime_error("reference boundary support");
    const double w = (lengths[0]+lengths[2])/2, h = (lengths[1]+lengths[3])/2;
    const double scale = std::min(1., maxReferenceSide/std::max(w,h));
    const int width = std::max(32, (int)std::nearbyint(w*scale)), height = std::max(32, (int)std::nearbyint(h*scale));
    const std::vector<cv::Point2f> destination = {{0,0}, {(float)(width-1),0}, {(float)(width-1),(float)(height-1)}, {0,(float)(height-1)}};
    cv::Mat hmat = cv::getPerspectiveTransform(corners, destination), output;
    if (!cv::checkRange(hmat) || std::abs(cv::determinant(hmat)) < 1e-12) throw std::runtime_error("reference transform");
    cv::warpPerspective(gray, output, hmat, {width,height}, cv::INTER_LINEAR);
    return output;
}
inline double area(const std::vector<cv::Point2f> &points) { return std::abs(cv::contourArea(points)); }
inline void geometry(Candidate &c, const cv::Mat &h, const std::vector<cv::Point2f> &source,
                     const std::vector<cv::Point2f> &target, const cv::Size &referenceSize, const cv::Size &querySize) {
    const int rw = referenceSize.width, rh = referenceSize.height, qw = querySize.width, qh = querySize.height;
    const std::vector<cv::Point2f> corners = {{0,0}, {(float)(rw-1),0}, {(float)(rw-1),(float)(rh-1)}, {0,(float)(rh-1)}};
    if (h.rows != 3 || h.cols != 3 || h.type() != CV_64F || !cv::checkRange(h)) return;
    std::array<double,4> denominators;
    for (int i=0; i<4; ++i) denominators[i] = h.at<double>(2,0)*corners[i].x + h.at<double>(2,1)*corners[i].y + h.at<double>(2,2);
    auto range = std::minmax_element(denominators.begin(), denominators.end());
    if (*range.first * *range.second <= 0) return;
    for (double &d : denominators) { if (!std::isfinite(d) || std::abs(d) < 1e-8) return; d=std::abs(d); }
    cv::perspectiveTransform(corners, c.quad, h);
    if (!std::all_of(c.quad.begin(), c.quad.end(), finitePoint)) { c.quad.clear(); return; }
    c.finiteHomography = true; c.convex = cv::isContourConvex(c.quad);
    c.fullyInFrame = std::all_of(c.quad.begin(), c.quad.end(), [qw,qh](const cv::Point2f &p) {
        return p.x>=0 && p.y>=0 && p.x<=qw-1 && p.y<=qh-1;
    });
    const double quadArea = area(c.quad);
    c.areaFraction = quadArea / ((double)qw*qh);
    std::array<cv::Point2f,4> edges;
    std::array<double,4> lengths;
    for (int i=0;i<4;++i) { edges[i] = c.quad[(i+1)%4]-c.quad[i]; lengths[i] = cv::norm(edges[i]); }
    c.minimumEdge = *std::min_element(lengths.begin(),lengths.end());
    for (double &l:lengths) l=std::max(l,1e-8);
    c.edgeRatio = *std::max_element(lengths.begin(),lengths.end()) / *std::min_element(lengths.begin(),lengths.end());
    c.oppositeEdgeRatio = std::max({lengths[0]/lengths[2],lengths[2]/lengths[0],lengths[1]/lengths[3],lengths[3]/lengths[1]});
    for (int i=0;i<4;++i) {
        const auto a=-edges[(i+3)%4], b=edges[i];
        const double cosine=a.dot(b)/(cv::norm(a)*cv::norm(b)+1e-8);
        c.angles.push_back(std::acos(std::max(-1.,std::min(1.,cosine)))*180/CV_PI);
    }
    range=std::minmax_element(denominators.begin(),denominators.end());
    c.projectiveRatio=*range.second / *range.first;
    std::vector<cv::Point2f> hull;
    cv::convexHull(source,hull); c.referenceSpread=area(hull)/((double)rw*rh);
    cv::convexHull(target,hull); c.querySpread=area(hull)/std::max(quadArea,1e-8);
    std::set<std::pair<int,int>> cells;
    for (auto p:source) cells.emplace(std::clamp((int)std::floor(p.x/rw*3),0,2),std::clamp((int)std::floor(p.y/rh*3),0,2));
    c.gridCells=(int)cells.size();
    std::vector<cv::Point2f> projected;
    cv::perspectiveTransform(source,projected,h);
    std::vector<double> errors;
    for (size_t i=0;i<source.size();++i) errors.push_back(cv::norm(projected[i]-target[i]));
    std::sort(errors.begin(),errors.end());
    c.medianError=errors.size()%2 ? errors[errors.size()/2] : (errors[errors.size()/2-1]+errors[errors.size()/2])/2;
}
// Exact prototype geometry gates control region removal; never monetary acceptance.
inline bool prototypeGeometryPass(const Candidate &c, const Settings &s) {
    return c.finiteHomography && c.convex && c.fullyInFrame && c.areaFraction>=s.minimumArea && c.areaFraction<=s.maximumArea
        && c.minimumEdge>=8 && c.edgeRatio<=s.maximumEdgeRatio && c.oppositeEdgeRatio<=s.maximumOppositeEdgeRatio && c.projectiveRatio<=s.maximumProjectiveRatio
        && c.referenceSpread>=s.minimumReferenceSpread && c.querySpread>=s.minimumQuerySpread && c.gridCells>=s.minimumGridCells && c.medianError<=s.maximumMedianError
        && c.angles.size()==4 && std::all_of(c.angles.begin(),c.angles.end(),[&s](double a){return a>=s.minimumAngle && a<=s.maximumAngle;});
}
class Matcher {
    cv::Ptr<cv::Feature2D> detector_;
    Settings settings_;
    int norm_;
    std::vector<Reference> references_;
public:
    Matcher(const std::string &algorithm, Settings settings) : settings_(settings), norm_(algorithm=="sift"?cv::NORM_L2:cv::NORM_HAMMING) {
        ba_runtime::configureOpenCVOnce();
        if (!std::isfinite(settings.ratioTest) || settings.ratioTest<=0 || settings.ratioTest>=1 ||
            !std::isfinite(settings.ransacError) || settings.ransacError<=0 || settings.ransacError>20 ||
            settings.ransacIterations<1 || settings.ransacIterations>5000) throw std::runtime_error("settings");
        const std::vector<double> bounds={settings.minimumArea,settings.maximumArea,settings.minimumAngle,settings.maximumAngle,
            settings.maximumEdgeRatio,settings.maximumOppositeEdgeRatio,settings.maximumProjectiveRatio,
            settings.minimumReferenceSpread,settings.minimumQuerySpread,settings.maximumMedianError};
        if (!std::all_of(bounds.begin(),bounds.end(),[](double value){return std::isfinite(value) && value>0;}) ||
            settings.minimumArea>=settings.maximumArea || settings.maximumArea>=1 || settings.minimumAngle>=settings.maximumAngle ||
            settings.maximumAngle>=180 || settings.maximumEdgeRatio<1 || settings.maximumOppositeEdgeRatio<1 ||
            settings.maximumProjectiveRatio<1 || settings.minimumReferenceSpread>1 || settings.minimumQuerySpread>1 ||
            settings.minimumGridCells<1 || settings.minimumGridCells>9) throw std::runtime_error("geometry settings");
        // Mat inputs use the CPU path. Do not mutate global OpenCL state here.
        detector_=detector(algorithm);
    }
    void add(const std::string &id, int label, const cv::Mat &gray, const std::vector<cv::Point2f> &boundary) {
        const std::set<int> labels={1,5,10,20,50,100,200,500};
        if (references_.size()>=maxReferences || id.empty() || id.size()>1024 || !labels.count(label) ||
            std::any_of(references_.begin(),references_.end(),[&id](const Reference &r){return r.id==id;})) throw std::runtime_error("reference identity");
        cv::Mat prepared=prepare(gray,boundary);
        Reference r; r.id=id; r.label=label; r.size=prepared.size();
        features(detector_,prepared,r.points,r.descriptors);
        references_.push_back(std::move(r)); // Only descriptors/keypoints kept in RAM.
    }
    Evidence inspect(const cv::Mat &query) {
        if (references_.empty() || query.type()!=CV_8UC1 || query.cols<32 || query.rows<32 ||
            query.cols>maxQuerySide || query.rows>maxQuerySide) throw std::runtime_error("query bounds");
        Evidence result; result.width=query.cols; result.height=query.rows;
        std::vector<cv::KeyPoint> points; cv::Mat descriptors;
        features(detector_,query,points,descriptors);
        for (const auto &r:references_) {
            Candidate base; base.id=r.id; base.label=r.label;
            if (descriptors.empty() || r.descriptors.rows<2) {result.candidates.push_back(base); continue;}
            std::vector<std::vector<cv::DMatch>> pairs;
            cv::BFMatcher(norm_,false).knnMatch(descriptors,r.descriptors,pairs,2);
            std::vector<cv::DMatch> matches;
            for (const auto &pair:pairs) if (pair.size()==2 && pair[0].distance<settings_.ratioTest*pair[1].distance) matches.push_back(pair[0]);
            for (int region=0;region<2;++region) {
                Candidate c=base; c.region=region; c.ratioMatches=(int)matches.size();
                if (matches.size()<4) {if (region==0) result.candidates.push_back(c); break;}
                std::vector<cv::Point2f> src,dst;
                for (auto m:matches) {src.push_back(r.points[m.trainIdx].pt);dst.push_back(points[m.queryIdx].pt);}
                cv::Mat mask; cv::setRNGSeed(12345+region);
                cv::Mat homography=cv::findHomography(src,dst,cv::RANSAC,settings_.ransacError,mask,settings_.ransacIterations,.995);
                if (homography.empty() || mask.empty()) {result.candidates.push_back(c);break;}
                std::map<int,int> selected;
                for (int i=0;i<(int)matches.size();++i) if (mask.at<unsigned char>(i)) {
                    auto it=selected.find(matches[i].trainIdx);
                    if (it==selected.end() || matches[i].distance<matches[it->second].distance) selected[matches[i].trainIdx]=i;
                }
                c.inliers=(int)selected.size(); c.inlierRatio=(double)c.inliers/matches.size();
                if (selected.size()<4) {result.candidates.push_back(c);break;}
                std::vector<int> indices;for (auto pair:selected) indices.push_back(pair.second); std::sort(indices.begin(),indices.end());
                std::vector<cv::Point2f> source,target;for (int i:indices){source.push_back(src[i]);target.push_back(dst[i]);}
                geometry(c,homography,source,target,r.size,query.size());
                c.score=c.inliers*c.inlierRatio*std::sqrt(std::max(0.,std::min({c.referenceSpread,c.querySpread,1.})));
                result.candidates.push_back(c);
                if (!prototypeGeometryPass(c,settings_)) break;
                auto end=std::remove_if(matches.begin(),matches.end(),[&](const cv::DMatch &m){return cv::pointPolygonTest(c.quad,points[m.queryIdx].pt,false)>=0;});
                if (end==matches.end()) break;
                matches.erase(end,matches.end());
            }
        }
        const size_t count=result.candidates.size();result.overlaps.assign(count*count,0);
        for (size_t i=0;i<count;++i) {
            result.overlaps[i*count+i]=1;
            for (size_t j=i+1;j<count;++j) {
                const auto &a=result.candidates[i], &b=result.candidates[j];
                if (!a.convex || !b.convex || a.quad.size()!=4 || b.quad.size()!=4) continue;
                std::vector<cv::Point2f> intersection;
                double overlap=cv::intersectConvexConvex(a.quad,b.quad,intersection)/std::max(std::min(area(a.quad),area(b.quad)),1e-8);
                if (!std::isfinite(overlap)) throw std::runtime_error("overlap invalid");
                result.overlaps[i*count+j]=result.overlaps[j*count+i]=std::clamp(overlap,0.,1.);
            }
        }
        return result;
    }
};
} // namespace ba_currency
