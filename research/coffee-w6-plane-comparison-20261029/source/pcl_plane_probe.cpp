// Research-only local-plane hypothesis. No map mutation, support admission or routes.
// Uses released PCL1.15 SACSegmentation, not a new plane-fitting algorithm.
#include <pcl/point_types.h>
#include <pcl/point_cloud.h>
#include <pcl/segmentation/sac_segmentation.h>
#include <pcl/pcl_config.h>
#include <Eigen/Core>
#include <link.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>
struct Point { std::uint32_t id; float x,y,z; };
struct Fit { bool accepted=false; std::string reason; std::vector<float> coefficient; std::vector<std::uint32_t> ids; };
static void require(bool ok,const char* why){if(!ok)throw std::runtime_error(why);}
static std::string quoted(const std::string& s){std::string r="\"";for(unsigned char c:s){if(c=='\\'||c=='\"'){r+='\\';r+=c;}else if(c<32)throw std::runtime_error("control byte in JSON string");else r+=c;}return r+'\"';}
static int loaded(struct dl_phdr_info* info,size_t,void* data){if(info->dlpi_name&&*info->dlpi_name)static_cast<std::vector<std::string>*>(data)->emplace_back(info->dlpi_name);return 0;}
static void objects(){std::vector<std::string> paths;dl_iterate_phdr(loaded,&paths);std::sort(paths.begin(),paths.end());std::cout<<"[";for(size_t i=0;i<paths.size();++i){if(i)std::cout<<",";std::cout<<quoted(paths[i]);}std::cout<<"]";}
static Fit fit(const std::vector<Point>& points){
    Fit r; if(points.size()<3||points.size()>8192){r.reason="point_count_refused";return r;}
    pcl::PointCloud<pcl::PointXYZ>::Ptr cloud(new pcl::PointCloud<pcl::PointXYZ>);
    cloud->reserve(points.size());
    for(const auto& p:points){if(!std::isfinite(p.x)||!std::isfinite(p.y)||!std::isfinite(p.z)){r.reason="nonfinite_refused";return r;}cloud->emplace_back(p.x,p.y,p.z);}
    pcl::SACSegmentation<pcl::PointXYZ> seg(false); // PCL documented fixed RNG seed12345.
    seg.setOptimizeCoefficients(true);seg.setModelType(pcl::SACMODEL_PERPENDICULAR_PLANE);
    seg.setMethodType(pcl::SAC_RANSAC);seg.setDistanceThreshold(.02);seg.setMaxIterations(128);
    seg.setProbability(.99);seg.setAxis(Eigen::Vector3f(0.f,0.f,1.f));
    seg.setEpsAngle(15.*3.14159265358979323846/180.);seg.setNumberOfThreads(-1);seg.setInputCloud(cloud);
    pcl::PointIndices indices;pcl::ModelCoefficients coefficients;seg.segment(indices,coefficients);
    if(coefficients.values.size()!=4||indices.indices.size()<3){r.reason="no_constrained_model";return r;}
    for(float x:coefficients.values)if(!std::isfinite(x)){r.reason="nonfinite_coefficient";return r;}
    double norm=std::sqrt(double(coefficients.values[0])*coefficients.values[0]+double(coefficients.values[1])*coefficients.values[1]+double(coefficients.values[2])*coefficients.values[2]);
    if(!(norm>1e-12)){r.reason="degenerate_normal";return r;}
    double nz=std::abs(double(coefficients.values[2]))/norm;
    if(nz<std::cos(15.*3.14159265358979323846/180.)){r.reason="optimized_axis_constraint_refused";return r;}
    const double sign=coefficients.values[2]<0?-1.:1.;
    for(float x:coefficients.values)r.coefficient.push_back(float(sign*x/norm));
    std::set<int> unique;
    for(int index:indices.indices){require(index>=0&&size_t(index)<points.size()&&unique.insert(index).second,"invalid or duplicate PCL inlier index");r.ids.push_back(points[index].id);}
    std::sort(r.ids.begin(),r.ids.end());r.accepted=true;r.reason="local_plane_hypothesis_only";return r;
}
static void printFit(const Fit& f){std::cout<<"{\"accepted\":"<<(f.accepted?"true":"false")<<",\"reason\":"<<quoted(f.reason)<<",\"normalizedPlaneDatasetP\":";if(!f.accepted)std::cout<<"null";else{std::cout<<"[";for(size_t i=0;i<f.coefficient.size();++i){if(i)std::cout<<",";std::cout<<f.coefficient[i];}std::cout<<"]";}std::cout<<",\"inlierOriginalVertexIDs\":[";for(size_t i=0;i<f.ids.size();++i){if(i)std::cout<<",";std::cout<<f.ids[i];}std::cout<<"]}";}
static void selfTest(){
    std::vector<Point> points;for(int y=-4;y<=4;++y)for(int x=-4;x<=4;++x)points.push_back({std::uint32_t(points.size()),x*.05f,y*.05f,.125f});
    points.push_back({81,0.f,0.f,.265f});points.push_back({82,0.f,0.f,-.125f});
    points.push_back({83,.1f,.1f,.135f}); // A1cm raised return may fit: inlier is NOT a free/ground label.
    const auto original=points;auto first=fit(points),second=fit(points);
    require(first.accepted&&second.accepted&&first.ids==second.ids,"flat deterministic fixture");
    require(first.coefficient==second.coefficient,"fixed-seed coefficient repeatability");
    require(std::abs(first.coefficient[3]+.125f)<.003f,"known plane height");
    require(!std::binary_search(first.ids.begin(),first.ids.end(),81)&&!std::binary_search(first.ids.begin(),first.ids.end(),82),"raised/drop outliers");
    require(std::binary_search(first.ids.begin(),first.ids.end(),83),"low-height inlier ambiguity witness");
    for(size_t i=0;i<points.size();++i)require(points[i].id==original[i].id&&points[i].x==original[i].x&&points[i].y==original[i].y&&points[i].z==original[i].z,"source point mutated");
    std::vector<Point> wall;for(int z=-3;z<=3;++z)for(int y=-3;y<=3;++y)wall.push_back({std::uint32_t(wall.size()),0.f,y*.05f,z*.05f});require(!fit(wall).accepted,"axis constraint inactive");
    require(!fit({}).accepted,"empty refusal");auto nonfinite=points;nonfinite[0].z=std::numeric_limits<float>::quiet_NaN();require(!fit(nonfinite).accepted,"nonfinite refusal");
    std::cout<<"{\"schema\":1,\"mode\":\"self_test\",\"PCLVersion\":"<<quoted(PCL_VERSION_PRETTY)<<",\"fixturesPassed\":[\"deterministic_flat_plane\",\"positive_axis_constraint\",\"raised_and_drop_outliers_retained\",\"one_centimetre_inlier_is_not_clear\",\"source_points_unchanged\",\"empty_and_nonfinite_refused\"],\"loadedObjects\":";objects();std::cout<<",\"physicalAuthority\":false}\n";
}
int main(int argc,char**argv){try{
    std::cout<<std::setprecision(17);require(argc==2,"one mode required");const std::string mode=argv[1];
    if(mode=="--self-test"){selfTest();return 0;}require(mode=="--fit-once","unknown mode");
    std::string magic;size_t n=0;require(bool(std::cin>>magic>>n)&&magic=="W6_PCL_POINTS_V1"&&n>=3&&n<=8192,"bounded input header");
    std::vector<Point> points;points.reserve(n);for(size_t i=0;i<n;++i){std::uint64_t id;double x,y,z;require(bool(std::cin>>id>>x>>y>>z)&&id<=136846&&std::isfinite(x)&&std::isfinite(y)&&std::isfinite(z)&&std::abs(x)<10000&&std::abs(y)<10000&&std::abs(z)<10000,"invalid source point");require(!i||id>points.back().id,"source IDs not strictly increasing");points.push_back({std::uint32_t(id),float(x),float(y),float(z)});}std::string trailing;require(!(std::cin>>trailing),"trailing input");
    auto result=fit(points);std::cout<<"{\"schema\":1,\"mode\":\"fit_once\",\"PCLVersion\":"<<quoted(PCL_VERSION_PRETTY)<<",\"inputFloat32Bits\":[";
    for(size_t i=0;i<points.size();++i){if(i)std::cout<<",";std::uint32_t b[3];std::memcpy(&b[0],&points[i].x,4);std::memcpy(&b[1],&points[i].y,4);std::memcpy(&b[2],&points[i].z,4);std::cout<<"["<<points[i].id<<","<<b[0]<<","<<b[1]<<","<<b[2]<<"]";}
    std::cout<<"],\"fit\":";printFit(result);std::cout<<",\"loadedObjects\":";objects();std::cout<<",\"sourceGeometryMutated\":false,\"physicalAuthority\":false}\n";return 0;
}catch(const std::exception& e){std::cerr<<"REFUSED "<<e.what()<<"\n";return 1;}catch(...){std::cerr<<"REFUSED unknown native exception\n";return 1;}}
